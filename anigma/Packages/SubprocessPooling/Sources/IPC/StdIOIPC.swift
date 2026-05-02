//
//  StdIOIPC.swift
//  SubprocessPooling
//
//  Created as part of P0 Epic: Unify Under anigmad with Warm Subprocess Pooling (td-12f9d2)
//  Phase 5: On-Demand Subprocesses (td-73aea8)
//

import Foundation
import System
import OSLog

private let logger = Logger(subsystem: "com.anigma.subprocess", category: "StdIOIPC")

/// Errors for stdin/stdout IPC
public enum StdIOError: Error, Sendable {
    case processSpawnFailed(path: String, reason: String)
    case processNotRunning
    case writeFailed(reason: String)
    case readFailed(reason: String)
    case timeout
    case invalidJSON
    case processExitedEarly(code: Int32)
}

// Import AnyCodable from Utilities

/// JSON-RPC request structure
public struct JSONRPCRequest: Codable, Sendable {
    public let jsonrpc: String
    public let id: String
    public let method: String
    public let params: [String: AnyCodable]?
    
    public init(jsonrpc: String = "2.0", id: String, method: String, params: [String: AnyCodable]? = nil) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.method = method
        self.params = params
    }
    
    public func toData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}

/// JSON-RPC response structure
public struct JSONRPCResponse: Codable, Sendable {
    public let jsonrpc: String
    public let id: String
    public let result: AnyCodable?
    public let error: JSONRPCError?
    
    public init(jsonrpc: String = "2.0", id: String, result: AnyCodable? = nil, error: JSONRPCError? = nil) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.result = result
        self.error = error
    }
}

/// JSON-RPC error structure
public struct JSONRPCError: Codable, Sendable {
    public let code: Int
    public let message: String
    public let data: AnyCodable?
    
    public init(code: Int, message: String, data: AnyCodable? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

/// Stdin/stdout IPC client for JSON-RPC communication
final class StdIOIPCClient {
    private let executablePath: String
    private let arguments: [String]
    private let timeout: TimeInterval
    private let lock = NSLock()
    
    private var process: Process? = nil
    private var stdinPipe: Pipe? = nil
    private var stdoutPipe: Pipe? = nil
    private var stderrPipe: Pipe? = nil
    
    /// Initialize a stdin/stdout IPC client
    /// - Parameter executablePath: Path to the executable
    /// - Parameter arguments: Arguments to pass to the executable
    /// - Parameter timeout: Timeout for operations in seconds
    public init(executablePath: String, arguments: [String] = [], timeout: TimeInterval = 30.0) {
        self.executablePath = executablePath
        self.arguments = arguments
        self.timeout = timeout
    }
    
    deinit {
        terminateProcess()
    }
    
    /// Spawn the process
    public func spawn() throws {
        lock.lock()
        defer { lock.unlock() }
        
        guard process == nil else {
            logger.debug("Process already spawned: \(self.executablePath)")
            return
        }
        
        let newProcess = Process()
        newProcess.executableURL = URL(fileURLWithPath: self.executablePath)
        newProcess.arguments = self.arguments
        
        let newStdinPipe = Pipe()
        let newStdoutPipe = Pipe()
        let newStderrPipe = Pipe()
        
        newProcess.standardInput = newStdinPipe
        newProcess.standardOutput = newStdoutPipe
        newProcess.standardError = newStderrPipe
        
        do {
            try newProcess.run()
        } catch {
            throw StdIOError.processSpawnFailed(
                path: self.executablePath,
                reason: error.localizedDescription
            )
        }
        
        self.process = newProcess
        self.stdinPipe = newStdinPipe
        self.stdoutPipe = newStdoutPipe
        self.stderrPipe = newStderrPipe
        
        logger.info("Spawned process: \(self.executablePath) with PID: \(newProcess.processIdentifier)")
    }
    
    /// Terminate the process
    public func terminateProcess() {
        lock.lock()
        defer { lock.unlock() }
        
        if let process = self.process {
            if process.isRunning {
                process.terminate()
                logger.info("Terminated process: \(self.executablePath) with PID: \(process.processIdentifier)")
            }
            self.process = nil
        }
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
    }
    
    /// Send a JSON-RPC request and receive the response
    /// - Parameter request: JSON-RPC request to send
    /// - Returns: JSON-RPC response
    public func sendRequest(_ request: JSONRPCRequest) async throws -> JSONRPCResponse {
        try spawn()
        
        let requestData = try request.toData()
        
        // Add newline delimiter
        var requestWithNewline = requestData
        requestWithNewline.append(contentsOf: [UInt8(ascii: "\n")])
        
        guard let stdin = stdinPipe?.fileHandleForWriting else {
            throw StdIOError.processNotRunning
        }
        
        // Write request
        try await writeData(requestWithNewline, to: stdin)
        
        // Read response
        guard let stdout = stdoutPipe?.fileHandleForReading else {
            throw StdIOError.processNotRunning
        }
        
        let responseData = try await readLine(from: stdout)
        let response = try JSONDecoder().decode(JSONRPCResponse.self, from: responseData)
        
        return response
    }
    
    /// Send raw data and receive raw response
    /// - Parameter data: Data to send
    /// - Returns: Response data
    public func sendData(_ data: Data) async throws -> Data {
        try spawn()
        
        var dataWithNewline = data
        dataWithNewline.append(contentsOf: [UInt8(ascii: "\n")])
        
        guard let stdin = stdinPipe?.fileHandleForWriting else {
            throw StdIOError.processNotRunning
        }
        
        try await writeData(dataWithNewline, to: stdin)
        
        guard let stdout = stdoutPipe?.fileHandleForReading else {
            throw StdIOError.processNotRunning
        }
        
        return try await readLine(from: stdout)
    }
    
    /// Write data to a file handle
    private func writeData(_ data: Data, to handle: FileHandle) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            handle.writeabilityHandler = { handle in
                handle.write(data)
                handle.writeabilityHandler = nil
                continuation.resume()
            }
        }
    }
    
    /// Read a line (delimited by newline) from a file handle
    private func readLine(from handle: FileHandle) async throws -> Data {
        // Use an actor to hold mutable state for the closure (Sendable)
        final actor BufferActor {
            private var data = Data()
            
            func append(_ chunk: Data) {
                data.append(chunk)
            }
            
            var lastByte: UInt8? {
                data.last
            }
            
            func finalize() -> Data {
                if data.last == UInt8(ascii: "\n") && data.count > 1 {
                    data.removeLast()
                }
                return data
            }
        }
        let buffer = BufferActor()
        
        return try await withCheckedThrowingContinuation { continuation in
            handle.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    // Check if process terminated
                    self.lock.lock()
                    let proc = self.process
                    self.lock.unlock()
                    if let process = proc, !process.isRunning {
                        let exitCode = process.terminationStatus
                        handle.readabilityHandler = nil
                        continuation.resume(throwing: StdIOError.processExitedEarly(code: exitCode))
                        return
                    }
                    return
                }
                
                // Append data to buffer (using Task to bridge to actor)
                Task {
                    await buffer.append(chunk)
                    
                    // Check for newline
                    if let lastByte = await buffer.lastByte, lastByte == UInt8(ascii: "\n") {
                        // Remove the newline and get final data
                        let finalData = await buffer.finalize()
                        handle.readabilityHandler = nil
                        continuation.resume(returning: finalData)
                    }
                }
            }
        }
    }
    
    /// Wait for process to exit
    public func waitForExit() async throws -> Int32 {
        guard let process = self.process else {
            throw StdIOError.processNotRunning
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus)
            }
        }
    }
    
    /// Check if process is running
    public var isProcessRunning: Bool {
        return process?.isRunning ?? false
    }
    
    /// Get the process ID
    public var processID: pid_t? {
        return process?.processIdentifier
    }
}
