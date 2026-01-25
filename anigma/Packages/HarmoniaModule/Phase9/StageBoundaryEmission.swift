//
//  StageBoundaryEmission.swift
//  HarmoniaModule
//
//  Protocol and implementation for stage boundary artifact emission.
//  Ensures exactly one artifact per stage with deterministic sequence numbers.
//

@preconcurrency import Foundation
import AnigmaPrimitives
import DatabaseCore
import StorageCore
import AnigmaCore
@preconcurrency import Crypto

/// Protocol for emitting stage boundary artifacts.
/// Ensures consistent artifact recording across different components.
@preconcurrency
public protocol StageBoundaryEmitter {
    /// Emit a stage boundary artifact with canonical payload
    func emitStageBoundary(
        stageNumber: Int,
        stageName: String,
        payload: Data,
        encoder: CanonicalJSONEncoder
    ) throws -> StageArtifact

    /// Record artifact for persistence
    func recordArtifact(_ type: String, data: Data) async throws
}

/// Implementation of stage boundary emission with validation.
public final class StandardStageBoundaryEmitter: StageBoundaryEmitter {
    private var emittedStages: Set<Int> = []
    private var artifacts: [Int: StageArtifact] = [:]
    private var boundaryDigests: [Int: String] = [:]
    private let database: DatabaseActor?
    private let artifactAuthority: (any ArtifactAuthority)?

    public init(database: DatabaseActor? = nil) {
        self.database = database
        self.artifactAuthority = nil
    }
    
    public init(artifactAuthority: any ArtifactAuthority, database: DatabaseActor? = nil) {
        self.artifactAuthority = artifactAuthority
        self.database = database
    }

    /// Emit a stage boundary artifact with validation
    public func emitStageBoundary(
        stageNumber: Int,
        stageName: String,
        payload: Data,
        encoder: CanonicalJSONEncoder
    ) throws -> StageArtifact {
        // Validate deterministic sequence
        let expectedStage = emittedStages.count
        guard stageNumber == expectedStage else {
            throw StageBoundaryError.invalidSequence(
                expected: expectedStage,
                actual: stageNumber
            )
        }

        // Prevent duplicates
        guard !emittedStages.contains(stageNumber) else {
            throw StageBoundaryError.duplicateStage(stageNumber)
        }

        // Create digest for payload
        let hash = BLAKE3Digest.hex(of: payload)

        // Create artifact
        let artifact = StageArtifact(
            stageNumber: stageNumber,
            stageName: stageName,
            canonicalPayload: payload,
            digest: hash,
            evidenceId: "stage-\(stageNumber)-\(UUID().uuidString.prefix(8))"
        )

        // Record emission
        emittedStages.insert(stageNumber)
        artifacts[stageNumber] = artifact

        return artifact
    }

    /// Record artifact for persistence
    public func recordArtifact(_ type: String, data: Data) async throws {
        if let artifactAuthority = artifactAuthority {
            // Use ArtifactAuthority (three-tier architecture)
            let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            let artifact = Artifact(
                id: ArtifactID(hash: hash),
                mimeType: "application/octet-stream",
                size: Int64(data.count),
                createdAt: Date(),
                tags: ["stage-boundary", type],
                metadata: ["type": type],
                content: data
            )
            let systemContext = ExecutionContext(principal: .system)
            do {
                _ = try await artifactAuthority.store(artifact, context: systemContext)
            } catch {
                fputs("[StageBoundaryEmitter] Warning: failed to persist artifact via ArtifactAuthority (\(type)): \(error)\n", stderr)
            }
        } else {
            // Legacy path using VaultAuthority
            let db = database ?? DatabaseActor()
            do {
                try await db.open()
                let rootURL = VaultConfiguration.defaultVaultRoot()
                let vault = try await VaultAuthority(
                    rootURL: rootURL,
                    database: db,
                    keyProvider: DefaultVaultKeyProvider.make(),
                    receiptWriter: VaultFileReceiptWriter(rootURL: rootURL)
                )
                _ = try await vault.ingest(
                    data: data,
                    kind: .derived,
                    mime: "application/octet-stream"
                )
            } catch {
                fputs("[StageBoundaryEmitter] Warning: failed to persist artifact (\(type)): \(error)\n", stderr)
            }
        }
    }

    /// Get all emitted artifacts
    public func getArtifacts() -> [StageArtifact] {
        return Array(artifacts.values).sorted { $0.stageNumber < $1.stageNumber }
    }

    /// Get emitted stages
    public var emittedStageNumbers: [Int] {
        return Array(emittedStages).sorted()
    }

    /// Get stored boundary digest for a stage
    public func getBoundaryDigest(for stage: Int) -> String? {
        return boundaryDigests[stage]
    }

    /// Set boundary digest for a stage
    public func setBoundaryDigest(_ digest: String, for stage: Int) {
        boundaryDigests[stage] = digest
    }
}

/// Errors that can occur during stage boundary emission
public enum StageBoundaryError: Error, LocalizedError {
    case invalidSequence(expected: Int, actual: Int)
    case duplicateStage(Int)
    case missingStage(Int)
    case invalidPayload(String)
    case determinismViolation(stage: Int, expected: String, actual: String)

    public var errorDescription: String? {
        switch self {
        case .invalidSequence(let expected, let actual):
            return "Invalid stage sequence: expected \(expected), got \(actual)"
        case .duplicateStage(let stage):
            return "Duplicate stage boundary emission for stage \(stage)"
        case .missingStage(let stage):
            return "Missing stage boundary for stage \(stage)"
        case .invalidPayload(let reason):
            return "Invalid stage payload: \(reason)"
        case .determinismViolation(let stage, let expected, let actual):
            return "Determinism violation at stage \(stage): expected digest \(expected), got \(actual)"
        }
    }
}

/// Utility for ensuring stage boundary integrity
public struct StageBoundaryValidator {

    /// Validate that stage boundaries follow all rules
    public static func validate(_ artifacts: [StageArtifact]) throws {
        // Check for correct sequence
        let stages = Set(artifacts.map { $0.stageNumber })

        // Should have exactly 8 stages
        guard stages.count == 8 else {
            throw StageBoundaryError.invalidSequence(expected: 8, actual: stages.count)
        }

        // Should have stages 0-7 exactly
        let expectedStages = Set(0...7)
        guard stages == expectedStages else {
            throw StageBoundaryError.invalidSequence(expected: 8, actual: stages.count)
        }

        // Check for duplicates
        let stageNumbers = artifacts.map { $0.stageNumber }
        if Set(stageNumbers).count != stageNumbers.count {
            throw StageBoundaryError.duplicateStage(0)
        }

        // Validate each artifact has required data
        for artifact in artifacts {
            if artifact.canonicalPayload.isEmpty {
                throw StageBoundaryError.invalidPayload("Empty canonical payload")
            }

            if artifact.digest.isEmpty {
                throw StageBoundaryError.invalidPayload("Empty digest")
            }

            if artifact.evidenceId.isEmpty {
                throw StageBoundaryError.invalidPayload("Empty evidence ID")
            }
        }
    }

    /// Verify each stage boundary was emitted exactly once
    public static func verifyEmission(emitter: StandardStageBoundaryEmitter) throws {
        let artifacts = emitter.getArtifacts()

        // Use standard validation
        try validate(artifacts)

        // Verify count exactly matches stages
        if emitter.emittedStageNumbers.count != 8 {
            throw StageBoundaryError.invalidSequence(
                expected: 8,
                actual: emitter.emittedStageNumbers.count
            )
        }
    }
}
