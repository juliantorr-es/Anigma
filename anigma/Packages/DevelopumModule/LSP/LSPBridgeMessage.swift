//
//  LSPBridgeMessage.swift
//  DevelopumModule
//
//  Bridge message for Anigma ↔ LSP communication.
//  Extracted from DevelopumLSPBridge.swift
//

import Foundation

/// Bridge message for Anigma ↔ LSP communication.
public struct LSPBridgeMessage: Codable, Sendable {
    public let version: DevelopumBridgeVersion
    public let type: DevelopumMessageType
    public let messageId: String
    public let sessionId: String
    public let repoId: String?
    public let timestampMs: Int64
    public let payload: LSPBridgePayload

    public init(
        version: DevelopumBridgeVersion = .v1,
        type: DevelopumMessageType,
        messageId: String = UUID().uuidString,
        sessionId: String,
        repoId: String? = nil,
        timestampMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        payload: LSPBridgePayload
    ) {
        self.version = version
        self.type = type
        self.messageId = messageId
        self.sessionId = sessionId
        self.repoId = repoId
        self.timestampMs = timestampMs
        self.payload = payload
    }
}

public enum LSPBridgePayload: Codable, Sendable {
    case lspRequest(LSPRequestPayload)
    case lspResponse(LSPResponsePayload)
    case lspNotification(LSPNotificationPayload)
    case lspError(LSPErrorPayload)
    case connectionState(ConnectionStatePayload)
    case serverCapabilities(ServerCapabilitiesPayload)

    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "lspRequest":
            let payload = try container.decode(LSPRequestPayload.self, forKey: .payload)
            self = .lspRequest(payload)
        case "lspResponse":
            let payload = try container.decode(LSPResponsePayload.self, forKey: .payload)
            self = .lspResponse(payload)
        case "lspNotification":
            let payload = try container.decode(LSPNotificationPayload.self, forKey: .payload)
            self = .lspNotification(payload)
        case "lspError":
            let payload = try container.decode(LSPErrorPayload.self, forKey: .payload)
            self = .lspError(payload)
        case "connectionState":
            let payload = try container.decode(ConnectionStatePayload.self, forKey: .payload)
            self = .connectionState(payload)
        case "serverCapabilities":
            let payload = try container.decode(ServerCapabilitiesPayload.self, forKey: .payload)
            self = .serverCapabilities(payload)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown payload type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .lspRequest(let payload):
            try container.encode("lspRequest", forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .lspResponse(let payload):
            try container.encode("lspResponse", forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .lspNotification(let payload):
            try container.encode("lspNotification", forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .lspError(let payload):
            try container.encode("lspError", forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .connectionState(let payload):
            try container.encode("connectionState", forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .serverCapabilities(let payload):
            try container.encode("serverCapabilities", forKey: .type)
            try container.encode(payload, forKey: .payload)
        }
    }
}

public struct LSPRequestPayload: Codable, Sendable {
    public let lspMethod: LSPMethod
    public let lspId: String
    public let lspParams: Data

    public init(lspMethod: LSPMethod, lspId: String, lspParams: Data) {
        self.lspMethod = lspMethod
        self.lspId = lspId
        self.lspParams = lspParams
    }
}

public struct LSPResponsePayload: Codable, Sendable {
    public let lspId: String
    public let lspResult: Data?
    public let lspError: String?

    public init(lspId: String, lspResult: Data?, lspError: String? = nil) {
        self.lspId = lspId
        self.lspResult = lspResult
        self.lspError = lspError
    }
}

public struct LSPNotificationPayload: Codable, Sendable {
    public let lspMethod: LSPMethod
    public let lspParams: Data

    public init(lspMethod: LSPMethod, lspParams: Data) {
        self.lspMethod = lspMethod
        self.lspParams = lspParams
    }
}

public struct LSPErrorPayload: Codable, Sendable {
    public let code: LSPCode
    public let message: String
    public let data: String?

    public init(code: LSPCode, message: String, data: String? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

public struct ConnectionStatePayload: Codable, Sendable {
    public let state: ConnectionState
    public let serverName: String?
    public let errorMessage: String?

    public init(state: ConnectionState, serverName: String? = nil, errorMessage: String? = nil) {
        self.state = state
        self.serverName = serverName
        self.errorMessage = errorMessage
    }
}

public enum ConnectionState: String, Codable, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case error
}

public struct ServerCapabilitiesPayload: Codable, Sendable {
    public let capabilities: ServerCapabilities
    public let serverInfo: ServerInfo?

    public init(capabilities: ServerCapabilities, serverInfo: ServerInfo? = nil) {
        self.capabilities = capabilities
        self.serverInfo = serverInfo
    }
}
