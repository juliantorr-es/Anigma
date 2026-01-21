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

struct AnigmaMCPServerCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "mcp-server",
            abstract: "Run embedded MCP server (stdio transport)."
        )
    }

    mutating func run() async throws {
        fputs("[anigma-cli] Starting embedded MCP server...\n", stderr)

        // Initialize transport using standard input/output
        let transport = StdioTransport()

        // Initialize the Anigma MCP Server
        let server = AnigmaMCPServer()

        // Run the server (blocks until terminated)
        try await server.run(transport: transport)
    }
}
