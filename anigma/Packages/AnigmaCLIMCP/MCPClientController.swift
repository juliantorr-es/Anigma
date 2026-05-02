//
//  MCPClientController.swift
//  AnigmaCLIMCP
//
//  Launches and manages a local anigma-mcp process and MCP client connection.
//

import AnigmaCLIEventing
import Foundation
import MCP

#if canImport(System)
import System
#else
@preconcurrency import SystemPackage
#endif

public enum MCPClientControllerError: LocalizedError {
    case processLaunchFailed(String)
    case notConnected

    public var errorDescription: String? {
        switch self {
        case .processLaunchFailed(let message):
            return message
        case .notConnected:
            return "MCP client not connected."
        }
    }
}

public actor MCPClientController {
    private let executableURL: URL
    private let workingDirectory: URL
    private let eventStream: CLIEventStream?
    private let client: Client
    private var process: Process?
    private var stderrTask: Task<Void, Never>?
    private var connected: Bool = false

    public init(
        executableURL: URL,
        workingDirectory: URL,
        eventStream: CLIEventStream? = nil
    ) {
        self.executableURL = executableURL
        self.workingDirectory = workingDirectory
        self.eventStream = eventStream
        self.client = Client(name: "anigma-cli", version: "0.1.0")
    }

    public func connect() async throws {
        if connected {
            return
        }

        let process = Process()
        process.executableURL = executableURL
        process.currentDirectoryURL = workingDirectory
        process.environment = ProcessInfo.processInfo.environment
        process.arguments = executableURL.lastPathComponent == "anigmad" ? ["--mcp"] : []

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw MCPClientControllerError.processLaunchFailed("Failed to launch daemon-backed MCP bridge: \(error)")
        }

        self.process = process
        startStderrCapture(handle: stderrPipe.fileHandleForReading)

        let inputFD = FileDescriptor(rawValue: stdoutPipe.fileHandleForReading.fileDescriptor)
        let outputFD = FileDescriptor(rawValue: stdinPipe.fileHandleForWriting.fileDescriptor)
        let transport = StdioTransport(input: inputFD, output: outputFD)

        await client.onNotification(MCPProgressNotification.self) { [eventStream] notification in
            let params = notification.params
            let update = params.update
            let message = "\(params.toolName): \(update.message)"
            let metadata: [String: String] = [
                "phase": update.phase,
                "progress": "\(update.progress)"
            ]
            await eventStream?.emit(
                CLIEvent(
                    kind: .progress,
                    message: message,
                    metadata: metadata
                )
            )
        }

        try await client.connect(transport: transport)
        connected = true

        await eventStream?.emit(
            CLIEvent(
                kind: .info,
                message: "Connected to daemon-backed MCP bridge.",
                metadata: ["path": executableURL.path]
            )
        )
    }

    public func callTool(
        name: String,
        arguments: [String: Value]? = nil
    ) async throws -> (content: [Tool.Content], isError: Bool?) {
        guard connected else {
            throw MCPClientControllerError.notConnected
        }

        return try await client.callTool(name: name, arguments: arguments)
    }

    public func disconnect() async {
        if connected {
            await client.disconnect()
        }

        connected = false
        stderrTask?.cancel()
        stderrTask = nil

        if let process, process.isRunning {
            process.terminate()
        }
    }

    private func startStderrCapture(handle: FileHandle) {
        stderrTask = Task.detached { [eventStream] in
            while true {
                let data = handle.availableData
                if data.isEmpty {
                    break
                }

                let text = String(decoding: data, as: UTF8.self)
                let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
                for line in lines {
                    await eventStream?.emit(
                        CLIEvent(
                            kind: .info,
                            message: String(line),
                            metadata: ["source": "mcp"]
                        )
                    )
                }
            }
        }
    }
}
