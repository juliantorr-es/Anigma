//
//  HardeningAttestationContract.swift
//  AnigmaCore
//
//  Contract definition for HardeningAttestationContract in AnigmaCore.
//

import ContractsCore
import Foundation

/// Input metadata required to generate a hardening attestation.
public struct HardeningAttestationInput: Codable, Sendable {
    public let commitHash: String
    public let testCommitHash: String
    public let testTreeIsDirty: Bool
    public let pipelineSchemaVersions: [String: Int]
    public let testReceiptHashes: [String]
    public let enduranceReceiptHashes: [String]
    public let migrationVersion: String
    public let environment: [String: String]

    public init(
        commitHash: String,
        testCommitHash: String,
        testTreeIsDirty: Bool,
        pipelineSchemaVersions: [String: Int],
        testReceiptHashes: [String],
        enduranceReceiptHashes: [String],
        migrationVersion: String,
        environment: [String: String]
    ) {
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

/// Contract that produces a HardeningAttestation artifact once prerequisites are met.
public enum HardeningAttestationContract: ContractSpec {
    public static let id = ContractID(name: "pipeline.attestation.hardening", major: 1, minor: 0, schemaHash: "v1.0")
    public static let inputSchemaVersion = 1
    public static let outputSchemaVersion = 1

    public static func validate(output: ArtifactEnvelope<HardeningAttestation>) throws {
        guard !output.payload.commitHash.isEmpty else {
            throw ContractValidationError.missingField(
                code: "attestation.commit.empty",
                message: "Commit hash is required"
            )
        }
        guard !output.payload.testReceiptHashes.isEmpty else {
            throw ContractValidationError.missingField(
                code: "attestation.tests.missing",
                message: "At least one test receipt is required"
            )
        }
        guard !output.payload.enduranceReceiptHashes.isEmpty else {
            throw ContractValidationError.missingField(
                code: "attestation.endurance.missing",
                message: "At least one endurance receipt is required"
            )
        }
        guard output.payload.commitHash == output.payload.testCommitHash else {
            throw ContractValidationError.invalidSchema(
                code: "attestation.commit.mismatch",
                message: "Test commit hash does not match attested commit hash"
            )
        }
    }

    public static func execute(
        input: ArtifactEnvelope<HardeningAttestationInput>,
        ctx: ContractContext
    ) async throws -> ArtifactEnvelope<HardeningAttestation> {
        let payload = HardeningAttestation(
            version: 1,
            commitHash: input.payload.commitHash,
            testCommitHash: input.payload.testCommitHash,
            testTreeIsDirty: input.payload.testTreeIsDirty,
            pipelineSchemaVersions: input.payload.pipelineSchemaVersions,
            testReceiptHashes: input.payload.testReceiptHashes,
            enduranceReceiptHashes: input.payload.enduranceReceiptHashes,
            migrationVersion: input.payload.migrationVersion,
            environment: input.payload.environment
        )
        let metrics = ExecutionMetrics(
            wallTimeMs: 0,
            toolCallCount: 0,
            retryCount: 0,
            executor: ctx.executorIdentity,
            cacheHit: false
        )
        let receipt = ContractReceipt.placeholder(
            contractID: Self.id,
            runID: ctx.runID,
            sessionID: ctx.sessionID,
            status: .satisfied,
            startedAt: Date(),
            endedAt: Date(),
            metrics: metrics
        )
        return ArtifactEnvelope(
            schemaVersion: outputSchemaVersion,
            payload: payload,
            evidenceRefs: [],
            metrics: metrics,
            receipt: receipt
        )
    }
}
