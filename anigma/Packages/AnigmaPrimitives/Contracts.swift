//
//  Contracts.swift
//  AnigmaPrimitives
//
//  Contract definition for Contracts in AnigmaPrimitives.
//

import Foundation

/// Governance modes that control trust tier clamps.
public enum GovernanceMode: String, Sendable, Codable, CaseIterable {
    case personal
    case governed
    case paranoid
}

/// Trust tiers that describe capability level of an operator.
public enum TrustTier: String, Sendable, Codable, Comparable, CaseIterable {
    case bronze
    case silver
    case gold
    case platinum
    case trusted

    public static func < (lhs: TrustTier, rhs: TrustTier) -> Bool {
        let order: [TrustTier] = [.bronze, .silver, .gold, .platinum, .trusted]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }

    public static func minimum(for mode: GovernanceMode) -> TrustTier {
        switch mode {
        case .personal: return .bronze
        case .governed: return .silver
        case .paranoid: return .gold
        }
    }

    public static func maximum(for mode: GovernanceMode) -> TrustTier {
        switch mode {
        case .personal: return .silver
        case .governed: return .gold
        case .paranoid: return .platinum
        }
    }
}

/// Risk levels for operations and changes
public enum RiskLevel: String, Sendable, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

/// Represents an anchor point in an AST for precise location and verification
public struct AstAnchor: Sendable, Codable, Equatable {
    public let filePath: String
    public let contentHash: String
    public let startOffset: Int
    public let endOffset: Int
    public let nodeKind: String
    public let contextFingerprint: String

    public init(
        filePath: String,
        contentHash: String,
        startOffset: Int,
        endOffset: Int,
        nodeKind: String,
        contextFingerprint: String
    ) {
        self.filePath = filePath
        self.contentHash = contentHash
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.nodeKind = nodeKind
        self.contextFingerprint = contextFingerprint
    }

    /// Legacy initializer for compatibility with existing code
    public init(
        filePath: String,
        contentHash: String,
        startOffset: Int,
        endOffset: Int,
        nodeKind: String,
        contextSnapshot: String
    ) {
        self.init(
            filePath: filePath,
            contentHash: contentHash,
            startOffset: startOffset,
            endOffset: endOffset,
            nodeKind: nodeKind,
            contextFingerprint: contextSnapshot
        )
    }
}

public extension AstAnchor {
    /// Generate a fingerprint for a given source text range
    static func fingerprint(sourceText: String, startOffset: Int, endOffset: Int) -> String {
        let startIndex = sourceText.index(sourceText.startIndex, offsetBy: startOffset)
        let endIndex = sourceText.index(sourceText.startIndex, offsetBy: min(endOffset, sourceText.count))
        let range = startIndex..<endIndex
        let substring = String(sourceText[range])
        return substring.data(using: .utf8)?.base64EncodedString() ?? ""
    }

    /// Convert to JSON string for storage
    func jsonString() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    /// Decode from JSON string
    static func decode(from jsonString: String?) -> AstAnchor? {
        guard let jsonString = jsonString,
              let data = jsonString.data(using: .utf8) else {
            return nil
        }
        let decoder = JSONDecoder()
        return try? decoder.decode(AstAnchor.self, from: data)
    }
}

// MARK: - AnyCodable

/// Type-erased Codable value
public struct AnyCodable: Codable, @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode AnyCodable"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if value is NSNull {
            try container.encodeNil()
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else if let array = value as? [Any] {
            try container.encode(array.map { AnyCodable($0) })
        } else if let dictionary = value as? [String: Any] {
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        } else if let codable = value as? AnyCodable {
             try codable.encode(to: encoder)
        } else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable cannot encode value"))
        }
    }
}

