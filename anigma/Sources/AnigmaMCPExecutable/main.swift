import Foundation
import MCP
import AnigmaMCPModule

// Initialize transport using standard input/output
let transport = StdioTransport()

// Initialize the Anigma MCP Server
let server = AnigmaMCPServer()

// Run the server
do {
    try await server.run(transport: transport)
} catch {
    // Log error to stderr to avoid corrupting JSON-RPC on stdout
    fputs("Error running MCP Server: \(error)\n", stderr)
    exit(1)
}
