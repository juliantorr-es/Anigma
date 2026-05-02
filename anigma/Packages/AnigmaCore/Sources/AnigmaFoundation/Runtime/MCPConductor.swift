//
//  MCPConductor.swift
//  AnigmaCore
//
//  Manages Model Context Protocol (MCP) clients and servers.
//  Enables Anigma to consume external tools and expose its own.
//

import FoundationContracts
import GovernanceContracts
import EvidenceContracts
import IntelligenceContracts
import Foundation
import AnigmaPrimitives

public actor MCPConductor {
    private var clients: [String: MCPClient] = [:]
    private var activeTransports: [String: any MCPTransport] = [:]
    private var pendingRequests: [String: CheckedContinuation<String, Error>] = [:]

    public init() {}

    public func connect(serverId: String, executablePath: String, arguments: [String]) async throws {
        let transport = StdioMCPTransport(executablePath: executablePath, arguments: arguments)
        try transport.start()
        activeTransports[serverId] = transport

        // Listen for responses in a background task
        Task {
            for await message in transport.receive() {
                await handleIncomingMessage(message)
            }
        }

        clients[serverId] = MCPClient(id: serverId, capabilities: ["tools", "resources"])
    }

    private func handleIncomingMessage(_ message: String) async {
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String else { return }

        if let continuation = pendingRequests.removeValue(forKey: id) {
            if let result = json["result"] as? [String: Any],
               let resultData = try? JSONSerialization.data(withJSONObject: result),
               let resultString = String(data: resultData, encoding: .utf8) {
                continuation.resume(returning: resultString)
            } else if let error = json["error"] as? [String: Any] {
                let message = (error["message"] as? String) ?? "Unknown MCP error"
                continuation.resume(throwing: RuntimeInitializationError.executionFailed(message))
            }
        }
    }

    public func executeTool(serverId: String, name: String, arguments: [String: AnyCodable]) async throws -> String {
        guard let transport = activeTransports[serverId] else {
            throw RuntimeInitializationError.executionFailed("MCP Server \(serverId) not connected")
        }

        let requestId = UUID().uuidString
        let request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": requestId,
            "method": "tools/call",
            "params": [
                "name": name,
                "arguments": arguments
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: request)
        guard let message = String(data: data, encoding: .utf8) else {
            fatalError("Failed to unwrap message")
        }

        return try await withCheckedThrowingContinuation { continuation in
            Task {
                self.pendingRequests[requestId] = continuation
                do {
                    try await transport.send(message)
                } catch {
                    self.pendingRequests.removeValue(forKey: requestId)
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

/// Transport implementation using Standard I/O for local MCP servers.
public final class StdioMCPTransport: MCPTransport {
    private let process = Process()
    private let inputPipe = Pipe()
    private let outputPipe = Pipe()

    public init(executablePath: String, arguments: [String]) {
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
    }

    public func start() throws {
        try process.run()
    }

    public func send(_ message: String) async throws {
        guard let data = (message + "\n").data(using: .utf8) else {
            fatalError("Failed to unwrap data")
        }
        try inputPipe.fileHandleForReading.write(contentsOf: data)
    }

    public func receive() -> AsyncStream<String> {
        AsyncStream { continuation in
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if let str = String(data: data, encoding: .utf8) {
                    continuation.yield(str)
                }
            }
        }
    }
}

public struct MCPClient: Sendable {
    public let id: String
    public let capabilities: [String]
}
