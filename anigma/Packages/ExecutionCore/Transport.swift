//
//  Transport.swift
//  ExecutionCore
//
//  Transport and RPC abstractions for ExecutionCore.
//  No policy logic - pure message passing infrastructure.
//

import Foundation
import TelemetryCore

// MARK: - Transport Message Types

/// Wire format for transport messages.
/// Base message type for all transport communications.
public struct TransportMessage: Codable, Sendable {
    /// Unique message identifier
    public let messageID: String

    /// Message type discriminator
    public let messageType: String

    /// Sender identifier
    public let sender: String

    /// Intended recipient (empty for broadcast)
    public let recipient: String?

    /// Deterministic timestamp
    public let timestampMs: Int64

    /// Message payload (structured data)
    public let payload: [String: TelemetryValue]

    /// Optional message correlation for request/response
    public let correlationID: String?

    public init(
        messageID: String,
        messageType: String,
        sender: String,
        recipient: String? = nil,
        timestampMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        payload: [String: TelemetryValue] = [:],
        correlationID: String? = nil
    ) {
        self.messageID = messageID
        self.messageType = messageType
        self.sender = sender
        self.recipient = recipient
        self.timestampMs = timestampMs
        self.payload = payload
        self.correlationID = correlationID
    }
}

/// Response message for request/response patterns
public struct TransportResponse: Codable, Sendable {
    /// Corresponding request message ID
    public let requestMessageID: String

    /// Response outcome
    public let outcome: TransportOutcome

    /// Response payload (if successful)
    public let payload: [String: TelemetryValue]?

    /// Error details (if failed)
    public let error: TransportError?

    /// Deterministic timestamp
    public let timestampMs: Int64

    public init(
        requestMessageID: String,
        outcome: TransportOutcome,
        payload: [String: TelemetryValue]? = nil,
        error: TransportError? = nil,
        timestampMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.requestMessageID = requestMessageID
        self.outcome = outcome
        self.payload = payload
        self.error = error
        self.timestampMs = timestampMs
    }
}

/// Transport outcome enumeration
public enum TransportOutcome: String, Sendable, Codable {
    case success = "success"
    case error = "error"
    case timeout = "timeout"
    case rejected = "rejected"

    public var description: String {
        switch self {
        case .success: return "Transport succeeded"
        case .error: return "Transport failed with error"
        case .timeout: return "Transport timed out"
        case .rejected: return "Transport rejected"
        }
    }
}

/// Transport error information
public struct TransportError: Codable, Sendable {
    /// Error code (machine-readable)
    public let code: String

    /// Human-readable error message
    public let message: String

    /// Error category
    public let category: TransportErrorCategory

    public init(code: String, message: String, category: TransportErrorCategory) {
        self.code = code
        self.message = message
        self.category = category
    }
}

/// Transport error categories
public enum TransportErrorCategory: String, Sendable, Codable {
    case protocolLevel = "protocol"
    case network = "network"
    case authentication = "authentication"
    case authorization = "authorization"
    case validation = "validation"
    case internalError = "internal"

    public var description: String {
        switch self {
        case .protocolLevel: return "Protocol-level error"
        case .network: return "Network-level error"
        case .authentication: return "Authentication error"
        case .authorization: return "Authorization error"
        case .validation: return "Validation error"
        case .internalError: return "Internal error"
        }
    }
}

// MARK: - Transport Protocol

/// Protocol for transport implementations.
/// Defines pure message passing without policy logic.
public protocol TransportProtocol: Sendable {
    /// Unique identifier for this transport instance
    var transportID: String { get }

    /// Transport type for identification
    var transportType: TransportType { get }

    /// Whether transport is currently connected/available
    var isConnected: Bool { get }

    /// Sends a message through the transport
    func send(_ message: TransportMessage) async throws -> String

    /// Receives a message from the transport
    func receive(timeoutMs: Int64?) async throws -> TransportMessage?

    /// Sends a request and waits for response
    func request(_ message: TransportMessage, timeoutMs: Int64?) async throws -> TransportResponse

    /// Starts the transport (if needed)
    func start() async throws

    /// Stops the transport (if needed)
    func stop() async throws
}

/// Transport types for identification
public enum TransportType: String, Sendable, Codable {
    case inMemory = "in_memory"
    case file = "file"
    case http = "http"
    case websocket = "websocket"
    case grpc = "grpc"
    case custom = "custom"

    public var description: String {
        switch self {
        case .inMemory: return "In-memory transport"
        case .file: return "File-based transport"
        case .http: return "HTTP transport"
        case .websocket: return "WebSocket transport"
        case .grpc: return "gRPC transport"
        case .custom: return "Custom transport"
        }
    }
}

// MARK: - Transport Registry

/// Registry for managing multiple transport instances
public actor TransportRegistry {
    private var transports: [String: any TransportProtocol] = [:]

    public init() {}

    /// Registers a transport instance
    public func register(_ transport: any TransportProtocol) {
        transports[transport.transportID] = transport
    }

    /// Unregisters a transport instance
    public func unregister(transportID: String) {
        transports.removeValue(forKey: transportID)
    }

    /// Gets a transport by ID
    public func getTransport(transportID: String) -> (any TransportProtocol)? {
        return transports[transportID]
    }

    /// Lists all registered transports
    public func listTransports() -> [(String, any TransportProtocol)] {
        return transports.map { id, transport in (id, transport) }
    }

    /// Gets transports by type
    public func getTransports(byType type: TransportType) -> [(String, any TransportProtocol)] {
        return transports.filter { _, transport in
            transport.transportType == type
        }.map { id, transport in (id, transport) }
    }

    /// Starts all registered transports
    public func startAll() async throws {
        for (_, transport) in transports {
            try await transport.start()
        }
    }

    /// Stops all registered transports
    public func stopAll() async throws {
        for (_, transport) in transports {
            try await transport.stop()
        }
    }
}

// MARK: - Deterministic Encoding Support

extension TransportMessage {
    /// Creates deterministic JSON representation
    public func deterministicJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return try encoder.encode(self)
    }

    /// Computes deterministic hash of this message
    public func contentHash() throws -> TelemetryHash {
        let data = try deterministicJSON()
        return TelemetryHash(input: String(data: data, encoding: .utf8) ?? "")
    }
}

extension TransportResponse {
    /// Creates deterministic JSON representation
    public func deterministicJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return try encoder.encode(self)
    }
}
