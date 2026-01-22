//
//  MCPServerCommand.swift
//  AnigmaCLIExecutable
//
//  Embedded MCP server command - runs the full MCP server inside anigma-cli.
//  This allows anigma-cli to act as both a CLI tool and an MCP server.
//

import Foundation
import ArgumentParser
import AnigmaMCPModule
import MCP
import AnigmaSidecar
import AnigmaPrimitives

struct AnigmaMCPServerCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "mcp-server",
            abstract: "Run embedded MCP server (stdio transport)."
        )
    }

    @Flag(name: .long, help: "Use daemon for MCP execution")
    var daemon: Bool = false
    
    @Option(name: .long, help: "Path to configuration file")
    var config: String?

    mutating func run() async throws {
        if daemon {
            try await runDaemonBridge()
        } else {
            try await runEmbedded()
        }
    }
    
    private func runEmbedded() async throws {
        fputs("[anigma-cli] Starting embedded MCP server...\n", stderr)

        // Initialize transport using standard input/output
        let transport = StdioTransport()

        // Initialize the Anigma MCP Server
        let server = AnigmaMCPServer()

        // Run the server (blocks until terminated)
        try await server.run(transport: transport)
    }
    
    private func runDaemonBridge() async throws {
         fputs("[anigma-cli] Bridging to daemon MCP server...\n", stderr)
         
         // Load config to find socket
         var configuration = DaemonConfiguration.default
         if let configPath = config {
             let url = URL(fileURLWithPath: configPath)
             let data = try Data(contentsOf: url)
             configuration = try JSONDecoder().decode(DaemonConfiguration.self, from: data)
         }
         
         let socketPath = (configuration.daemon.unixSocket as NSString).expandingTildeInPath
         guard FileManager.default.fileExists(atPath: socketPath) else {
             fputs("Error: Daemon socket not found at \(socketPath)\n", stderr)
             throw ExitCode.failure
         }
         
         let bridge = try await SidecarBridge.create(
            socketPath: socketPath,
            clientName: "anigma-cli-mcp",
            scopes: ["system.read", "mcp.execute"]
         )
         
         let stdio = StdioTransport()
         let incoming = stdio.receive()
         
         do {
             let outgoing = try await bridge.bridgeMCP(inputStream: incoming)
             
             for try await message in outgoing {
                 try await stdio.send(message)
             }
         } catch {
             fputs("Bridge error: \(error)\n", stderr)
             throw ExitCode.failure
         }
    }
}
