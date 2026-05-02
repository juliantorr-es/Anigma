//
//  PDFDocument+Sidecar.swift
//  SidecarPDFService (to be used in PDFCapsule)
//
//  Client for communicating with PDF sidecar process via Unix socket.
//  Handles graceful crash recovery and content-addressed requests/responses.
//

import Foundation
import Darwin

public enum PDFSidecarClientError: LocalizedError {
    case documentCorrupted(String)
    case pageNotFound(Int)
    case outOfMemory
    case internalError(String)

    public var errorDescription: String? {
        switch self {
        case .documentCorrupted(let msg): return "Document corrupted: \(msg)"
        case .pageNotFound(let page): return "Page \(page) not found"
        case .outOfMemory: return "Out of memory"
        case .internalError(let msg): return "Internal error: \(msg)"
        }
    }
}

// MARK: - Sidecar Process Manager

public class PDFSidecarProcessManager {
    public static let shared = PDFSidecarProcessManager()
    
    private var process: Process?
    private var socketPath: String
    private var lock = NSLock()
    private var lastHealthCheck = Date.distantPast
    private let healthCheckInterval: TimeInterval = 30.0
    private var sidecarStartTime = Date.distantPast
    
    private init() {
        let tmpDir = NSTemporaryDirectory()
        self.socketPath = tmpDir.appending("anigma-pdf-sidecar.sock")
    }
    
    /// Ensure sidecar process is running
    public func ensureSidecarRunning() throws {
        lock.lock()
        defer { lock.unlock() }
        
        // Check if process is still alive
        if let proc = process, proc.isRunning {
            // Perform periodic health check
            if Date().timeIntervalSince(lastHealthCheck) > healthCheckInterval {
                lastHealthCheck = Date()
                do {
                    _ = try healthCheck()
                    return
                } catch {
                    NSLog("Health check failed, restarting sidecar: \(error)")
                    stopSidecar()
                }
            } else {
                return
            }
        }
        
        try startSidecar()
    }
    
    /// Start the PDF sidecar process
    private func startSidecar() throws {
        NSLog("Starting PDF sidecar process...")
        
        // Clean up old socket
        try? FileManager.default.removeItem(atPath: socketPath)
        
        // Find sidecar executable (should be in same directory as main executable)
        let executablePath = CommandLine.arguments[0]
        let executableDir = (executablePath as NSString).deletingLastPathComponent
        let sidecarPath = (executableDir as NSString).appendingPathComponent("pdf-sidecar")
        
        guard FileManager.default.fileExists(atPath: sidecarPath) else {
            throw PDFSidecarClientError.internalError("PDF sidecar executable not found at \(sidecarPath)")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: sidecarPath)
        process.arguments = ["--socket", socketPath]
        
        try process.run()
        self.process = process
        self.sidecarStartTime = Date()
        
        // Wait for socket to be ready (max 5 seconds)
        let deadline = Date().addingTimeInterval(5.0)
        while !FileManager.default.fileExists(atPath: socketPath) && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        guard FileManager.default.fileExists(atPath: socketPath) else {
            throw PDFSidecarClientError.internalError("PDF sidecar socket did not appear")
        }
        
        NSLog("PDF sidecar started successfully")
    }
    
    /// Stop the sidecar process
    private func stopSidecar() {
        process?.terminate()
        process = nil
        try? FileManager.default.removeItem(atPath: socketPath)
    }
    
    /// Health check request to sidecar
    private func healthCheck() throws {
        let request = PDFSidecarRequest(operation: .health)
        let response = try sendRequest(request, timeout: 5.0)
        if case .healthResult(let result) = response.payload {
            NSLog("Sidecar health check passed - PID: \(result.processID), uptime: \(result.uptimeSeconds)s")
        }
    }
    
    /// Send request to sidecar and get response
    public func sendRequest(_ request: PDFSidecarRequest, timeout: TimeInterval = 30.0) throws -> PDFSidecarResponse {
        try ensureSidecarRunning()
        
        let requestData = try request.toJSON()
        let responseData = try sendToSocket(requestData, timeout: timeout)
        let response = try PDFSidecarResponse.fromJSON(responseData)
        
        guard response.requestID == request.requestID else {
            throw PDFSidecarClientError.internalError("Response request ID mismatch")
        }
        
        switch response.status {
        case .success:
            return response
        case .internalError:
            throw PDFSidecarClientError.internalError("Sidecar internal error")
        case .documentCorrupted:
            throw PDFSidecarClientError.documentCorrupted("Sidecar reported corruption")
        case .pageNotFound:
            throw PDFSidecarClientError.pageNotFound(0)
        case .outOfMemory:
            throw PDFSidecarClientError.outOfMemory
        case .sidecarCrashed, .timeout, .invalidRequest:
            throw PDFSidecarClientError.internalError("Sidecar error: \(response.status)")
        }
    }
    
    /// Send data to socket and receive response
    private func sendToSocket(_ data: Data, timeout: TimeInterval) throws -> Data {
        let sock = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sock >= 0 else {
            throw PDFSidecarClientError.internalError("Failed to create socket")
        }
        defer { Darwin.close(sock) }
        
        // Set socket timeout
        var tv = timeval()
        tv.tv_sec = time_t(timeout)
        tv.tv_usec = Int32((timeout.truncatingRemainder(dividingBy: 1.0)) * 1_000_000)
        _ = setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        _ = setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        // Connect to sidecar socket
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        withUnsafeMutableBytes(of: &addr.sun_path) { buffer in
            pathBytes.withUnsafeBytes { pathBuffer in
                memcpy(buffer.baseAddress!, pathBuffer.baseAddress!, min(pathBuffer.count, buffer.count))
            }
        }
        
        let connectResult = withUnsafeBytes(of: &addr) { addrBuffer in
            Darwin.connect(sock, addrBuffer.baseAddress!.assumingMemoryBound(to: sockaddr.self), socklen_t(MemoryLayout<sockaddr_un>.size))
        }
        
        guard connectResult >= 0 else {
            throw PDFSidecarClientError.internalError("Failed to connect to sidecar socket: errno=\(errno)")
        }
        
        // Send message with length prefix (4 bytes, big-endian)
        var length = UInt32(data.count).bigEndian
        let lengthData = Data(bytes: &length, count: 4)
        let fullMessage = lengthData + data
        
        let sent = fullMessage.withUnsafeBytes { buffer in
            Darwin.write(sock, buffer.baseAddress!, buffer.count)
        }
        
        guard sent == fullMessage.count else {
            throw PDFSidecarClientError.internalError("Failed to send complete message to socket")
        }
        
        // Receive response length (4 bytes)
        var responseLengthBytes = [UInt8](repeating: 0, count: 4)
        let lengthRead = Darwin.read(sock, &responseLengthBytes, 4)
        guard lengthRead == 4 else {
            throw PDFSidecarClientError.internalError("Failed to read response length: got \(lengthRead) bytes")
        }
        
        let responseLength = UInt32(bytes: (responseLengthBytes[0], responseLengthBytes[1], responseLengthBytes[2], responseLengthBytes[3]))
        let expectedSize = Int(UInt32(bigEndian: responseLength))
        
        guard expectedSize > 0 && expectedSize < 100_000_000 else {
            throw PDFSidecarClientError.internalError("Invalid response size: \(expectedSize)")
        }
        
        // Receive response data
        var responseBuffer = [UInt8](repeating: 0, count: expectedSize)
        let bytesRead = Darwin.read(sock, &responseBuffer, expectedSize)
        guard bytesRead > 0 else {
            throw PDFSidecarClientError.internalError("Failed to read response data")
        }
        
        return Data(responseBuffer.prefix(bytesRead))
    }
}

// MARK: - Helper Extensions

extension UInt32 {
    init(bytes: (UInt8, UInt8, UInt8, UInt8)) {
        self = (UInt32(bytes.0) << 24) | (UInt32(bytes.1) << 16) | (UInt32(bytes.2) << 8) | UInt32(bytes.3)
    }
}
