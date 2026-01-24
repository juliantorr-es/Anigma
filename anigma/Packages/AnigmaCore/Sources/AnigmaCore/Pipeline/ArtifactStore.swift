//
//  ArtifactStore.swift
//  AnigmaCore
//
//  [Brief description of file purpose]
//

import ContractsCore
import DatabaseCore
import Foundation
import StorageCore

/// Storage boundary for contract artifacts (runner-facing abstraction).
public protocol PipelineArtifactStore: Sendable {
    func store<Payload: Codable>(_ envelope: ArtifactEnvelope<Payload>) async throws -> String
    func store<Payload: Codable>(_ envelope: ArtifactEnvelope<Payload>, with id: String) async throws
    func storeRaw(_ data: Data, typeName: String, preferredID: String?) async throws -> String
    func load<Payload: Codable>(_ id: String, as type: Payload.Type) async throws -> ArtifactEnvelope<Payload>
    func contains(_ id: String) async -> Bool
    func loadRaw(_ id: String) async throws -> (data: Data, typeName: String)
    func loadEnvelopeData(_ id: String) async throws -> Data
    func storeEnvelopeData(
        _ envelopeData: Data,
        schemaVersion: Int,
        contractID: String,
        sessionID: String,
        artifactKey: String,
        payloadData: Data,
        evidenceData: Data,
        metricsData: Data,
        receiptData: Data
    ) async throws
}

public struct StoreEnvelopeDataConfiguration: Sendable {
    public let envelopeData: Data
    public let schemaVersion: String
    public let contractID: String
    public let sessionID: String
    public let artifactKey: String
    public let payloadData: Data
    public let evidenceData: Data
    public let metricsData: Data
    public let receiptData: Data
}

/// In-memory artifact store for pipelines and tests.
public actor InMemoryPipelineArtifactStore: PipelineArtifactStore {
    private struct StoredArtifact: Sendable {
        let typeName: String
        let data: Data
    }

    private var storage: [String: StoredArtifact] = [:]
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let idGenerator: () -> String

    public init(
        idGenerator: @escaping () -> String = { UUID().uuidString },
        dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .iso8601,
        dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .iso8601
    ) {
        self.idGenerator = idGenerator
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = dateEncodingStrategy
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = dateDecodingStrategy
        self.decoder = decoder
    }

    public func store<Payload: Codable>(_ envelope: ArtifactEnvelope<Payload>) async throws -> String {
        let id = idGenerator()
        let data = try encoder.encode(envelope)
        storage[id] = StoredArtifact(typeName: String(describing: Payload.self), data: data)
        return id
    }

    public func store<Payload: Codable>(_ envelope: ArtifactEnvelope<Payload>, with id: String) async throws {
        let data = try encoder.encode(envelope)
        storage[id] = StoredArtifact(typeName: String(describing: Payload.self), data: data)
    }

    public func storeRaw(_ data: Data, typeName: String, preferredID: String?) async throws -> String {
        let id = preferredID ?? idGenerator()
        storage[id] = StoredArtifact(typeName: typeName, data: data)
        return id
    }

    public func load<Payload: Codable>(_ id: String, as type: Payload.Type) async throws -> ArtifactEnvelope<Payload> {
        guard let stored = storage[id] else {
            throw ContractExecutionError.underlying(
                code: "artifact.not_found",
                message: "Artifact \(id) not found"
            )
        }
        guard stored.typeName == String(describing: Payload.self) else {
            throw ContractExecutionError.underlying(
                code: "artifact.type_mismatch",
                message: "Artifact \(id) is \(stored.typeName), expected \(Payload.self)"
            )
        }
        return try decoder.decode(ArtifactEnvelope<Payload>.self, from: stored.data)
    }

    public func contains(_ id: String) async -> Bool {
        storage[id] != nil
    }

    public func loadRaw(_ id: String) async throws -> (data: Data, typeName: String) {
        guard let stored = storage[id] else {
            throw ContractExecutionError.underlying(
                code: "artifact.not_found",
                message: "Artifact \(id) not found"
            )
        }
        return (data: stored.data, typeName: stored.typeName)
    }

    public func loadEnvelopeData(_ id: String) async throws -> Data {
        guard let stored = storage[id] else {
            throw ContractExecutionError.underlying(
                code: "artifact.not_found",
                message: "Artifact \(id) not found"
            )
        }
        return stored.data
    }
    
    public func storeEnvelopeData(
        _ envelopeData: Data,
        schemaVersion: Int,
        contractID: String,
        sessionID: String,
        artifactKey: String,
        payloadData: Data,
        evidenceData: Data,
        metricsData: Data,
        receiptData: Data
    ) async throws {
        let config = StoreEnvelopeDataConfiguration(
            envelopeData: envelopeData,
            schemaVersion: String(schemaVersion),
            contractID: contractID,
            sessionID: sessionID,
            artifactKey: artifactKey,
            payloadData: payloadData,
            evidenceData: evidenceData,
            metricsData: metricsData,
            receiptData: receiptData
        )
        try await storeEnvelopeData(config: config)
    }

    func storeEnvelopeData(config: StoreEnvelopeDataConfiguration) async throws {
        storage[config.artifactKey] = StoredArtifact(typeName: "", data: config.envelopeData)
    }
}

public actor DatabaseBackedPipelineArtifactStore: PipelineArtifactStore {
    private let store: DatabaseArtifactStore
    private let database: DatabaseActor?
    private var vault: VaultAuthority?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(store: DatabaseArtifactStore, database: DatabaseActor? = nil) {
        self.store = store
        self.database = database
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func store<Payload: Codable>(_ envelope: ArtifactEnvelope<Payload>) async throws -> String {
        let key = envelope.receipt.outputRefs.first ?? UUID().uuidString
        try await store(envelope, with: key)
        return key
    }

    public func store<Payload: Codable>(_ envelope: ArtifactEnvelope<Payload>, with id: String) async throws {
        let envelopeData = try encoder.encode(envelope)
        let artifact = PersistedArtifact(
            artifactID: id,
            sessionID: envelope.receipt.sessionID,
            contractID: envelope.receipt.contractID,
            schemaVersion: envelope.schemaVersion,
            artifactKey: id,
            payloadJSON: try encoder.encode(envelope.payload),
            evidenceJSON: try encoder.encode(envelope.evidenceRefs),
            metricsJSON: try encoder.encode(envelope.metrics),
            envelopeJSON: envelopeData,
            receiptJSON: try encoder.encode(envelope.receipt),
            createdAt: envelope.receipt.endedAt
        )
        try await store.putArtifactIdempotent(artifact)
        try await storeEnvelopeInVault(envelopeData, kind: .derived, mime: "application/json")
    }

    public func storeRaw(_ data: Data, typeName: String, preferredID: String?) async throws -> String {
        let id = preferredID ?? UUID().uuidString
        try await store.putArtifactIdempotent(
            PersistedArtifact(
                artifactID: id,
                sessionID: "",
                contractID: ContractID(name: "unknown", major: 1, minor: 0, schemaHash: "v1.0"),
                schemaVersion: 0,
                artifactKey: id,
                payloadJSON: data,
                evidenceJSON: Data(),
                metricsJSON: Data(),
                envelopeJSON: data,
                receiptJSON: Data(),
                createdAt: Date()
            )
        )
        try await storeEnvelopeInVault(data, kind: .derived, mime: "application/octet-stream")
        return id
    }

    public func load<Payload: Codable>(_ id: String, as type: Payload.Type) async throws -> ArtifactEnvelope<Payload> {
        guard let persisted = try await store.fetchArtifact(byKey: id) else {
            throw ContractExecutionError.underlying(code: "artifact.not_found", message: "Artifact \(id) not found")
        }
        return try decoder.decode(ArtifactEnvelope<Payload>.self, from: persisted.envelopeJSON)
    }

    public func contains(_ id: String) async -> Bool {
        (try? await store.fetchArtifact(byKey: id)) != nil
    }

    public func loadRaw(_ id: String) async throws -> (data: Data, typeName: String) {
        guard let persisted = try await store.fetchArtifact(byKey: id) else {
            throw ContractExecutionError.underlying(code: "artifact.not_found", message: "Artifact \(id) not found")
        }
        return (data: persisted.envelopeJSON, typeName: "")
    }

    public func loadEnvelopeData(_ id: String) async throws -> Data {
        guard let persisted = try await store.fetchArtifact(byKey: id) else {
            throw ContractExecutionError.underlying(code: "artifact.not_found", message: "Artifact \(id) not found")
        }
        return persisted.envelopeJSON
    }

    public func storeEnvelopeData(
        _ envelopeData: Data,
        schemaVersion: Int,
        contractID: String,
        sessionID: String,
        artifactKey: String,
        payloadData: Data,
        evidenceData: Data,
        metricsData: Data,
        receiptData: Data
    ) async throws {
        let config = StoreEnvelopeDataConfiguration(
            envelopeData: envelopeData,
            schemaVersion: String(schemaVersion),
            contractID: contractID,
            sessionID: sessionID,
            artifactKey: artifactKey,
            payloadData: payloadData,
            evidenceData: evidenceData,
            metricsData: metricsData,
            receiptData: receiptData
        )
        try await storeEnvelopeData(config: config)
    }

    func storeEnvelopeData(config: StoreEnvelopeDataConfiguration) async throws {
        let artifact = PersistedArtifact(
            artifactID: config.artifactKey,
            sessionID: config.sessionID,
            contractID: ContractID(name: config.contractID, major: 1, minor: 0, schemaHash: "v1.0"),
            schemaVersion: Int(config.schemaVersion) ?? 0,
            artifactKey: config.artifactKey,
            payloadJSON: config.payloadData,
            evidenceJSON: config.evidenceData,
            metricsJSON: config.metricsData,
            envelopeJSON: config.envelopeData,
            receiptJSON: config.receiptData,
            createdAt: Date()
        )
        _ = try await store.putArtifactIdempotent(artifact)
    }

    private func storeEnvelopeInVault(
        _ data: Data,
        kind: VaultArtifactKind,
        mime: String
    ) async throws {
        let vault = try await loadVault()
        _ = try await vault.ingest(data: data, kind: kind, mime: mime)
    }

    private func loadVault() async throws -> VaultAuthority {
        if let vault {
            return vault
        }
        let db = database ?? DatabaseActor()
        try await db.open()
        let rootURL = VaultConfiguration.defaultVaultRoot()
        let vault = try await VaultAuthority(
            rootURL: rootURL,
            database: db,
            keyProvider: DefaultVaultKeyProvider.make(),
            receiptWriter: VaultFileReceiptWriter(rootURL: rootURL)
        )
        self.vault = vault
        return vault
    }
}
