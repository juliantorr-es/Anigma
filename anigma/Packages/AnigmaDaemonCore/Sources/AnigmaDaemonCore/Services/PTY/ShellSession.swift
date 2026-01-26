//
//  ShellSession.swift
//  AnigmaDaemonCore
//
//  Manages a persistent shell process (bash/zsh).
//

import Foundation

public actor ShellSession {
    public let id: String
    public let buffer: RingBuffer
    private let process: Process
    private let stdinPipe: Pipe
    private let outputPipe: Pipe // Shared for stdout/stderr
    private var isRunning: Bool = false
    
    public let createdAt: Date
    public let command: String
    public let workdir: String
    
    public init(
        id: String,
        command: String = "/bin/bash",
        args: [String] = [],
        workdir: String = FileManager.default.currentDirectoryPath,
        env: [String: String] = [:],
        bufferSize: Int = 1024 * 1024
    ) {
        self.id = id
        self.command = command
        self.workdir = workdir
        self.createdAt = Date()
        self.buffer = RingBuffer(capacity: bufferSize)
        
        self.process = Process()
        self.stdinPipe = Pipe()
        self.outputPipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: workdir)
        
        // Merge environment
        var processEnv = ProcessInfo.processInfo.environment
        for (key, value) in env {
            processEnv[key] = value
        }
        // Force unbuffered output for Python/Node if possible
        processEnv["PYTHONUNBUFFERED"] = "1"
        process.environment = processEnv
        
        process.standardInput = stdinPipe
        process.standardOutput = outputPipe
        process.standardError = outputPipe // Merge stderr into stdout for simple terminal emulation
    }
    
    public func start() throws {
        guard !isRunning else { return }
        
        // Handle output reading in background
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            
            Task { [weak self] in
                await self?.buffer.write(data)
            }
        }
        
        process.terminationHandler = { [weak self] _ in
            Task { [weak self] in
                await self?.handleTermination()
            }
        }
        
        try process.run()
        isRunning = true
        
        // Initial banner
        Task {
            let banner = "--- Anigma Persistent Shell [\(id)] Started ---\n".data(using: .utf8)!
            await buffer.write(banner)
        }
    }
    
    public func write(_ input: String) {
        guard isRunning else { return }
        guard let data = input.data(using: .utf8) else { return }
        
        // Write to stdin
        // Note: Writing to fileHandleForWriting can throw if pipe is broken, 
        // need to handle carefully or just try?
        try? stdinPipe.fileHandleForWriting.write(contentsOf: data)
    }
    
    public func resize(cols: Int, rows: Int) {
        // Not supported in standard Process/Pipe (requires true PTY)
        // Stub for future
    }
    
    public func kill() {
        guard isRunning else { return }
        process.terminate()
        // cleanup handled in terminationHandler
    }
    
    private func handleTermination() {
        isRunning = false
        outputPipe.fileHandleForReading.readabilityHandler = nil
        // Write exit message
        let msg = "\n--- Session Exited (Code: \(process.terminationStatus)) ---\n".data(using: .utf8)!
        Task {
            await buffer.write(msg)
        }
    }
    
    public func getInfo() async -> SessionInfo {
        return SessionInfo(
            id: id,
            command: command,
            workdir: workdir,
            isRunning: isRunning,
            pid: process.processIdentifier,
            totalBytes: await buffer.totalBytesWritten
        )
    }
}

public struct SessionInfo: Codable, Sendable {
    public let id: String
    public let command: String
    public let workdir: String
    public let isRunning: Bool
    public let pid: Int32
    public let totalBytes: Int64
}
