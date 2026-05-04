//
//  Evidence.swift
//  CathedralModule
//
//  Core evidence types for Cathedral coordination
//

import Foundation
import ContractsCore
import CryptoKit
import AnigmaPrimitives

// MARK: - Evidence Record

/// Core evidence artifact for Cathedral coordination
public struct Evidence: Sendable, Codable, Hashable {
    public let id: String
    public let type: EvidenceType
    public let sessionId: String
    public let agentId: String
    public let timestamp: Date
    public let contentHash: String
    public let metadata: EvidenceMetadata
    public let previousHash: String?

    public init(
        id: String = UUID().uuidString,
        type: EvidenceType,
        sessionId: String,
        agentId: String,
        timestamp: Date = Date(),
        contentHash: String,
        metadata: EvidenceMetadata,
        previousHash: String? = nil
    ) {
        self.id = id
        self.type = type
        self.sessionId = sessionId
        self.agentId = agentId
        self.timestamp = timestamp
        self.contentHash = contentHash
        self.metadata = metadata
        self.previousHash = previousHash
    }

    /// Compute cryptographic hash of this evidence
    public func computeHash() -> String {
        let hashInput = "\(id)|\(type.rawValue)|\(sessionId)|\(agentId)|\(timestamp.timeIntervalSince1970)|\(contentHash)|\(previousHash ?? "genesis")"
        return hashInput.blake3Hash
    }
}

// MARK: - Evidence Type

public enum EvidenceType: String, Sendable, Codable, CaseIterable {
    case documentAcquisition = "document_acquisition"
    case documentTransformation = "document_transformation"
    case queryExecution = "query_execution"
    case retrievalResult = "retrieval_result"
    case planGeneration = "plan_generation"
    case operationExecution = "operation_execution"
    case validationCheck = "validation_check"
    case violationDetection = "violation_detection"
}

// MARK: - Evidence Metadata

public struct EvidenceMetadata: Sendable, Codable, Hashable {
    public let source: String
    public let operation: String
    public let parameters: [String: String]
    public let quality: EvidenceQuality
    public let expiryTime: Date?

    public init(
        source: String,
        operation: String,
        parameters: [String: String] = [:],
        quality: EvidenceQuality = .adequate,
        expiryTime: Date? = nil
    ) {
        self.source = source
        self.operation = operation
        self.parameters = parameters
        self.quality = quality
        self.expiryTime = expiryTime
    }
}

// MARK: - Evidence Quality

public enum EvidenceQuality: String, Sendable, Codable, CaseIterable {
    case none = "none"
    case weak = "weak"
    case adequate = "adequate"
    case strong = "strong"
    case verified = "verified"

    public var confidence: Double {
        switch self {
        case .none: return 0.0
        case .weak: return 0.25
        case .adequate: return 0.5
        case .strong: return 0.75
        case .verified: return 1.0
        }
    }

    public func meetsRequirement(_ requirement: EvidenceRequirement) -> Bool {
        return confidence >= requirementToConfidence(requirement)
    }

    private func requirementToConfidence(_ requirement: EvidenceRequirement) -> Double {
        switch requirement {
        case .none: return 0.0
        case .low: return 0.25
        case .moderate: return 0.5
        case .high: return 0.75
        case .strict: return 1.0
        }
    }
}

// MARK: - String Hashing Extension

extension String {
    /// Compute BLAKE3 hash using AnigmaPrimitives (Saturated Architecture)
    var blake3Hash: String {
        return BLAKE3Digest.hex(of: self)
    }
}

extension Data {
    /// Compute BLAKE3 hash using AnigmaPrimitives (Saturated Architecture)
    var blake3Hex: String {
        return BLAKE3Digest.hex(of: self)
    }
}
