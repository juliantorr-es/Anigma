//
//  UnixDomainSocketIPC.swift
//  SubprocessPooling
//
//  Created as part of P0 Epic: Unify Under anigmad with Warm Subprocess Pooling (td-12f9d2)
//  Phase 5: On-Demand Subprocesses for PDFium isolation (td-73aea8)
//

import Foundation
import System
import OSLog

private let logger = Logger(subsystem: "com.anigma.subprocess", category: "UnixDomainSocketIPC")

/// Errors for Unix domain socket IPC
public enum UnixDomainSocketError: Error, Sendable {
    case socketCreationFailed(reason: String)
    case bindFailed(path: String, reason: String)
    case listenFailed(reason: String)
    case connectFailed(path: String, reason: String)
    case acceptFailed(reason: String)
    case readFailed(reason: String)
    case writeFailed(reason: String)
    case invalidMessage(reason: String)
    case connectionClosed
    case timeout
}

/// Unix domain socket client for IPC communication
public actor UnixDomainSocketClient {
    private let socketPath: String
    private var clientSocket: Int32? = nil
    private let timeout: TimeInterval
    
    /// Initialize a Unix domain socket client
    /// - Parameter self.socketPath: Path to the Unix domain socket
    /// - Parameter timeout: Connection/read/write timeout in seconds
    public init(socketPath: String, timeout: TimeInterval = 30.0) {
        self.socketPath = socketPath
        self.timeout = timeout
    }
    
    deinit {
        closeSocket()
    }
    
    /// Connect to the server socket
    public func connect() throws {
        guard clientSocket == nil else {
            logger.debug("Already connected to socket: \(self.socketPath)")
            return
        }
        
        let socketFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketFD >= 0 else {
            throw UnixDomainSocketError.socketCreationFailed(
                reason: String(cString: strerror(errno))
            )
        }
        
        var serverAddr = sockaddr_un()
        serverAddr.sun_family = sa_family_t(AF_UNIX)
        
        let pathBytes = self.socketPath.utf8CString
        _ = withUnsafeMutableBytes(of: &serverAddr.sun_path) { buffer in
            pathBytes.withUnsafeBytes { path in
                memcpy(buffer.baseAddress!, path.baseAddress!, min(path.count, buffer.count))
            }
        }
        
        // Set timeout for connect
        var connectTimeout = timeval()
        connectTimeout.tv_sec = Int(timeout)
        connectTimeout.tv_usec = 0
        setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, &connectTimeout, socklen_t(MemoryLayout<timeval>.stride))
        setsockopt(socketFD, SOL_SOCKET, SO_SNDTIMEO, &connectTimeout, socklen_t(MemoryLayout<timeval>.stride))
        
        let connectResult = withUnsafeBytes(of: &serverAddr) { raw in
            Darwin.connect(
                socketFD,
                raw.baseAddress!.assumingMemoryBound(to: sockaddr.self),
                socklen_t(MemoryLayout<sockaddr_un>.size)
            )
        }
        
        guard connectResult == 0 else {
            close(socketFD)
            throw UnixDomainSocketError.connectFailed(
                path: self.socketPath,
                reason: String(cString: strerror(errno))
            )
        }
        
        clientSocket = socketFD
        logger.info("Connected to Unix domain socket: \(self.socketPath)")
    }
    
    /// Disconnect from the server
    public func closeSocket() {
        if let fd = clientSocket {
            Darwin.close(fd)
            clientSocket = nil
            logger.info("Disconnected from Unix domain socket: \(self.socketPath)")
        }
    }
    
    /// Send data to the server
    /// - Parameter data: Data to send
    public func send(_ data: Data) throws {
        guard let fd = clientSocket else {
            throw UnixDomainSocketError.connectionClosed
        }
        
        var totalSent = 0
        let bytes = [UInt8](data)
        
        while totalSent < bytes.count {
            let sent = bytes.withUnsafeBytes { buffer in
                Darwin.write(fd, buffer.baseAddress! + totalSent, bytes.count - totalSent)
            }
            guard sent > 0 else {
                throw UnixDomainSocketError.writeFailed(
                    reason: String(cString: strerror(errno))
                )
            }
            totalSent += sent
        }
    }
    
    /// Receive data from the server
    /// - Returns: Received data
    public func receive() throws -> Data {
        guard let fd = clientSocket else {
            throw UnixDomainSocketError.connectionClosed
        }
        
        // First read 4 bytes for the length (big-endian)
        var lengthBytes = [UInt8](repeating: 0, count: 4)
        let bytesRead = Darwin.read(fd, &lengthBytes, 4)
        
        guard bytesRead == 4 else {
            if bytesRead == 0 {
                throw UnixDomainSocketError.connectionClosed
            }
            throw UnixDomainSocketError.readFailed(
                reason: "Expected 4 bytes for length, got \(bytesRead)"
            )
        }
        
        // Convert to message length
        let messageLength = UInt32(
            (UInt32(lengthBytes[0]) << 24) |
            (UInt32(lengthBytes[1]) << 16) |
            (UInt32(lengthBytes[2]) << 8) |
            UInt32(lengthBytes[3])
        ).bigEndian
        
        guard messageLength > 0 else {
            throw UnixDomainSocketError.invalidMessage(reason: "Zero length message")
        }
        
        // Read the actual message
        var messageData = Data(count: Int(messageLength))
        let totalRead = try messageData.withUnsafeMutableBytes { buffer in
            var remaining = Int(messageLength)
            var offset = 0
            
            while remaining > 0 {
                let read = Darwin.read(fd, buffer.baseAddress! + offset, remaining)
                guard read > 0 else {
                    if read == 0 {
                        throw UnixDomainSocketError.connectionClosed
                    }
                    throw UnixDomainSocketError.readFailed(
                        reason: String(cString: strerror(errno))
                    )
                }
                offset += read
                remaining -= read
            }
            
            return Int(messageLength)
        }
        
        guard totalRead == Int(messageLength) else {
            throw UnixDomainSocketError.readFailed(
                reason: "Expected \(messageLength) bytes, got \(totalRead)"
            )
        }
        
        return messageData
    }
    
    /// Send data and receive response
    /// - Parameter data: Data to send
    /// - Returns: Response data
    public func sendAndReceive(_ data: Data) throws -> Data {
        try connect()
        defer { closeSocket() }
        try send(data)
        return try receive()
    }
}

/// Unix domain socket server for IPC communication
public actor UnixDomainSocketServer {
    private let socketPath: String
    private var serverSocket: Int32? = nil
    private var isRunning: Bool = false
    private var onRequest: ((Data) async throws -> Data)? = nil
    
    /// Initialize a Unix domain socket server
    /// - Parameter self.socketPath: Path to the Unix domain socket
    public init(socketPath: String) {
        self.socketPath = socketPath
    }
    
    deinit {
        stop()
    }
    
    /// Set the request handler
    /// - Parameter handler: Async closure to handle incoming requests
    public func setRequestHandler(_ handler: @escaping (Data) async throws -> Data) {
        onRequest = handler
    }
    
    /// Start the server
    public func start() throws {
        guard !isRunning else { return }
        
        // Remove existing socket file if present
        try? FileManager.default.removeItem(atPath: self.socketPath)
        
        let socketFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketFD >= 0 else {
            throw UnixDomainSocketError.socketCreationFailed(
                reason: String(cString: strerror(errno))
            )
        }
        
        var serverAddr = sockaddr_un()
        serverAddr.sun_family = sa_family_t(AF_UNIX)
        
        let pathBytes = self.socketPath.utf8CString
        _ = withUnsafeMutableBytes(of: &serverAddr.sun_path) { buffer in
            pathBytes.withUnsafeBytes { path in
                memcpy(buffer.baseAddress!, path.baseAddress!, min(path.count, buffer.count))
            }
        }
        
        let bindResult = withUnsafeBytes(of: &serverAddr) { raw in
            Darwin.bind(
                socketFD,
                raw.baseAddress!.assumingMemoryBound(to: sockaddr.self),
                socklen_t(MemoryLayout<sockaddr_un>.size)
            )
        }
        
        guard bindResult == 0 else {
            Darwin.close(socketFD)
            throw UnixDomainSocketError.bindFailed(
                path: self.socketPath,
                reason: String(cString: strerror(errno))
            )
        }
        
        guard listen(socketFD, 16) == 0 else {
            Darwin.close(socketFD)
            throw UnixDomainSocketError.listenFailed(
                reason: String(cString: strerror(errno))
            )
        }
        
        serverSocket = socketFD
        isRunning = true
        
        logger.info("Unix domain socket server started at: \(self.socketPath)")
    }
    
    /// Stop the server
    public func stop() {
        guard isRunning else { return }
        
        if let fd = serverSocket {
            Darwin.close(fd)
            serverSocket = nil
        }
        
        // Remove socket file
        try? FileManager.default.removeItem(atPath: self.socketPath)
        
        isRunning = false
        logger.info("Unix domain socket server stopped: \(self.socketPath)")
    }
    
    /// Accept a connection and handle the request
    public func acceptConnection() async throws -> Bool {
        guard let fd = serverSocket else {
            throw UnixDomainSocketError.socketCreationFailed(reason: "Server not started")
        }
        
        let clientFD = accept(fd, nil, nil)
        guard clientFD >= 0 else {
            if errno == EWOULDBLOCK || errno == EAGAIN {
                return false
            }
            throw UnixDomainSocketError.acceptFailed(
                reason: String(cString: strerror(errno))
            )
        }
        
        // Handle the request in a separate task
        Task {
            await handleClientConnection(clientFD)
            Darwin.close(clientFD)
        }
        
        return true
    }
    
    /// Handle a client connection
    private func handleClientConnection(_ clientFD: Int32) async {
        do {
            // Read the request
            let requestData = try receiveData(from: clientFD)
            
            // Process the request
            guard let onRequest = onRequest else {
                logger.error("No request handler configured")
                return
            }
            
            let responseData = try await onRequest(requestData)
            
            // Send the response
            try sendData(responseData, to: clientFD)
        } catch {
            logger.error("Error handling client connection: \(error)")
        }
    }
    
    /// Receive data from a client socket (with length prefix)
    private func receiveData(from fd: Int32) throws -> Data {
        // Read 4 bytes for the length
        var lengthBytes = [UInt8](repeating: 0, count: 4)
        let bytesRead = Darwin.read(fd, &lengthBytes, 4)
        
        guard bytesRead == 4 else {
            throw UnixDomainSocketError.readFailed(
                reason: "Expected 4 bytes for length"
            )
        }
        
        let messageLength = UInt32(
            (UInt32(lengthBytes[0]) << 24) |
            (UInt32(lengthBytes[1]) << 16) |
            (UInt32(lengthBytes[2]) << 8) |
            UInt32(lengthBytes[3])
        ).bigEndian
        
        guard messageLength > 0 else {
            throw UnixDomainSocketError.invalidMessage(reason: "Zero length message")
        }
        
        // Read the actual message
        var messageData = Data(count: Int(messageLength))
        let totalRead = try messageData.withUnsafeMutableBytes { buffer in
            var remaining = Int(messageLength)
            var offset = 0
            
            while remaining > 0 {
                let read = Darwin.read(fd, buffer.baseAddress! + offset, remaining)
                guard read > 0 else {
                    throw UnixDomainSocketError.readFailed(
                        reason: String(cString: strerror(errno))
                    )
                }
                offset += read
                remaining -= read
            }
            
            return Int(messageLength)
        }
        
        return messageData
    }
    
    /// Send data to a client socket (with length prefix)
    private func sendData(_ data: Data, to fd: Int32) throws {
        // Send length first (4 bytes, big-endian)
        let length = UInt32(data.count).bigEndian
        let lengthBytes = [UInt8](withUnsafeBytes(of: length) { Data($0) })
        
        var totalSent = 0
        let allBytes: [UInt8] = lengthBytes + [UInt8](data)
        
        while totalSent < allBytes.count {
            let sent = allBytes.withUnsafeBytes { buffer in
                Darwin.write(fd, buffer.baseAddress! + totalSent, allBytes.count - totalSent)
            }
            guard sent > 0 else {
                throw UnixDomainSocketError.writeFailed(
                    reason: String(cString: strerror(errno))
                )
            }
            totalSent += sent
        }
    }
}
