//
//  MCPTransport.swift
//  AnigmaPrimitives
//
//  Shared interface for Model Context Protocol (MCP) transports.
//

import Foundation

/// Protocol defining a transport layer for MCP communication.
public protocol MCPTransport: Sendable {
    /// Sends a message through the transport.
    func send(_ message: String) async throws

    /// Returns an async stream of incoming messages.
    func receive() -> AsyncStream<String>
}
