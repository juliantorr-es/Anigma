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
            abstract: "Run embedded MCP server with daemon-first execution."
        )
    }

    @OptionGroup var daemonOptions: DaemonOptions
    
    @Option(name: .long, help: "Path to configuration file")
    var config: String?

    mutating func run() async throws {
        if daemonOptions.daemon && !daemonOptions.local {
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
         
         // Use socket path from daemon options or default
         let config = daemonOptions.toConfig()
         let socketPath = config.socketPath ?? SidecarConfig.defaultUnixSocketPath()
         
         guard FileManager.default.fileExists(atPath: socketPath) else {
             fputs("Error: Daemon socket not found at \(socketPath)\n", stderr)
             fputs("Hint: Start the daemon with 'anigmad' or check ANIGMA_SOCKET environment variable\n", stderr)
             throw ExitCode.failure
         }
         
         let bridge = try await SidecarBridge.create(
            socketPath: socketPath,
            clientName: "anigma-cli-mcp",
            scopes: ["system.read", "mcp.execute"]
         )
         
          let stdio = StdioTransport()
          let incomingData = await stdio.receive()
          let incoming = AsyncStream<String> { continuation in
              Task {
                  do {
                      for try await chunk in incomingData {
                          continuation.yield(String(decoding: chunk, as: UTF8.self))
                      }
                      continuation.finish()
                  } catch {
                      continuation.finish()
                  }
              }
          }
         
         do {
              let outgoing = try await bridge.bridgeMCP(inputStream: incoming)
              
              for try await message in outgoing {
                  try await stdio.send(Data(message.utf8))
              }
         } catch {
             fputs("Bridge error: \(error)\n", stderr)
             throw ExitCode.failure
         }
    }
}
