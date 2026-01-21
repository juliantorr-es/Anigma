//
//  AttestationArtifacts.swift
//  ContractsCore
//
//  Contract definition for AttestationArtifacts in ContractsCore.
//

import Foundation

/// Stable attestation artifact for hardening runs.
public struct HardeningAttestation: Codable, Sendable, Hashable {
    public let version: Int
    public let commitHash: String
    public let testCommitHash: String
    public let testTreeIsDirty: Bool
    public let pipelineSchemaVersions: [String: Int]
    public let testReceiptHashes: [String]
    public let enduranceReceiptHashes: [String]
    public let migrationVersion: String
    public let environment: [String: String]

    public init(
        version: Int = 1,
        commitHash: String,
        testCommitHash: String,
        testTreeIsDirty: Bool,
        pipelineSchemaVersions: [String: Int],
        testReceiptHashes: [String],
        enduranceReceiptHashes: [String],
        migrationVersion: String,
        environment: [String: String]
    ) {
        self.version = version
        self.commitHash = commitHash
        self.testCommitHash = testCommitHash
        self.testTreeIsDirty = testTreeIsDirty
        self.pipelineSchemaVersions = pipelineSchemaVersions
        self.testReceiptHashes = testReceiptHashes
        self.enduranceReceiptHashes = enduranceReceiptHashes
        self.migrationVersion = migrationVersion
        self.environment = environment
    }
}
