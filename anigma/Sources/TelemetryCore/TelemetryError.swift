//
//  TelemetryError.swift
//  TelemetryCore
//
//  Errors that can occur when creating telemetry payloads.
//

/// Errors that can occur when creating telemetry payloads.
public enum TelemetryError: Error, Sendable {
    case invalidPayloadKey(String)
    case invalidPayloadValue(String)
    case validationFailed(String)
    case tagTooLong
    case tagNotAllowed
    case invalidHash

    public var localizedDescription: String {
        switch self {
        case .invalidPayloadKey(let key):
            return "Invalid payload key: \(key). Keys must be alphanumeric and <= 64 characters."
        case .invalidPayloadValue(let key):
            return "Invalid payload value for key: \(key). Values must be safe telemetry types."
        case .validationFailed(let reason):
            return "Payload validation failed: \(reason)"
        case .tagTooLong:
            return "Tag exceeds maximum length"
        case .tagNotAllowed:
            return "Tag not in allowed whitelist"
        case .invalidHash:
            return "Invalid hash format"
        }
    }
}

// MARK: - Codable Wire Support
extension TelemetryError: Codable {
    private enum Kind: String, Codable {
        case invalidPayloadKey, invalidPayloadValue, validationFailed, tagTooLong, tagNotAllowed, invalidHash
    }

    private enum CodingKeys: String, CodingKey {
        case kind, key, reason
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        let key = try container.decodeIfPresent(String.self, forKey: .key)
        let reason = try container.decodeIfPresent(String.self, forKey: .reason)

        switch kind {
        case .invalidPayloadKey:
            self = .invalidPayloadKey(key ?? "unknown")
        case .invalidPayloadValue:
            self = .invalidPayloadValue(key ?? "unknown")
        case .validationFailed:
            self = .validationFailed(reason ?? "unknown")
        case .tagTooLong:
            self = .tagTooLong
        case .tagNotAllowed:
            self = .tagNotAllowed
        case .invalidHash:
            self = .invalidHash
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .invalidPayloadKey(let key):
            try container.encode(Kind.invalidPayloadKey, forKey: .kind)
            try container.encode(key, forKey: .key)
        case .invalidPayloadValue(let key):
            try container.encode(Kind.invalidPayloadValue, forKey: .kind)
            try container.encode(key, forKey: .key)
        case .validationFailed(let reason):
            try container.encode(Kind.validationFailed, forKey: .kind)
            try container.encode(reason, forKey: .reason)
        case .tagTooLong:
            try container.encode(Kind.tagTooLong, forKey: .kind)
        case .tagNotAllowed:
            try container.encode(Kind.tagNotAllowed, forKey: .kind)
        case .invalidHash:
            try container.encode(Kind.invalidHash, forKey: .kind)
        }
    }
}
