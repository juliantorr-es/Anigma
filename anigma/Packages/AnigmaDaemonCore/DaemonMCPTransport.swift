//
//  DaemonMCPTransport.swift
//  AnigmaDaemonCore
//
//  Transport implementation for bridging HTTP/Unix streams to the internal MCP server.
//

import Foundation
import MCP

/// A transport that bridges between external streams (e.g. HTTP body) and the MCP server.
public final class DaemonMCPTransport: Transport, Sendable {
    private let incomingStream: AsyncStream<String>
    private let outgoingContinuation: AsyncStream<String>.Continuation
    private let outgoingStream: AsyncStream<String>

    public init(incomingStream: AsyncStream<String>) {
        self.incomingStream = incomingStream
        let (stream, continuation) = AsyncStream<String>.makeStream()
        self.outgoingStream = stream
        self.outgoingContinuation = continuation
    }

    public func send(_ message: String) async throws {
        outgoingContinuation.yield(message)
    }

    public func receive() -> AsyncStream<String> {
        return incomingStream
    }

    /// Returns the stream of messages from the server to the client.
    public var serverToClientStream: AsyncStream<String> {
        return outgoingStream
    }
}
