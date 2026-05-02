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


