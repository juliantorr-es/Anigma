//
//  ArtifactStoreIntegration.swift
//  PolytroposModule
//
//  Integration layer between PolytroposModule and ArtifactStoreModule.
//

import AnigmaCore
import Foundation
import ArtifactStoreModule
import DatabaseCore

// MARK: - PolytroposArtifactStoreAdapter
public actor PolytroposArtifactStoreAdapter: ArtifactStoreAdapter {
    // MARK: - Properties

    private let artifactStore: ArtifactStoreModule
    private let mediaType = "video/polytropos-asset"
    private let sourceType = "polytropos_ingestion"

    // MARK: - Initialization

    public init(artifactStore: ArtifactStoreModule) {
        self.artifactStore = artifactStore
    }

    // MARK: - ArtifactStoreAdapter Conformance

    /// Persist a VideoAsset to the ArtifactStoreModule.
    public func persistVideoAsset(_ asset: VideoAsset) async throws -> String {
        // Serialize the asset to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let assetData = try encoder.encode(asset)

        // Create artifact source
        let source = ArtifactSource(
            type: sourceType,
            identifier: asset.fileReference.path
        )

        // Build metadata
        var metadata: [String: String] = [
            "asset_id": asset.id.uuidString,
            "filename": asset.fileReference.filename,
            "duration": String(format: "%.2f", asset.metadata.duration),
            "resolution": asset.metadata.resolution.descriptionString,
            "codec": asset.metadata.codec.identifier,
            "frame_count": String(asset.frameFingerprints.count),
            "status": asset.status.rawValue
        ]

        if let captureDate = asset.metadata.captureDate {
            metadata["capture_date"] = ISO8601DateFormatter().string(from: captureDate)
        }

        // Commit to artifact store
        let receipt = try await artifactStore.commit(
            content: assetData,
            mediaType: mediaType,
            source: source,
            metadata: metadata,
            receiptID: "polytropos_\(asset.id.uuidString)",
            evidenceHeadHash: nil
        )

        return receipt.artifactID
    }

    /// Retrieve a VideoAsset from the ArtifactStoreModule.
    public func retrieveVideoAsset(artifactID: String) async throws -> VideoAsset? {
        let retrieved = try await artifactStore.retrieve(artifactID: artifactID)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let asset = try decoder.decode(VideoAsset.self, from: retrieved.content)
            return asset
        } catch {
            await PlatformLogger.shared.error(
                "Failed to decode VideoAsset from artifact \(artifactID): \(error)",
                category: "Polytropos.ArtifactStore"
            )
            return nil
        }
    }

    /// Check if an artifact exists in the store.
    public func artifactExists(artifactID: String) async throws -> Bool {
        do {
            let result = try await artifactStore.verify(artifactID: artifactID)
            return result.status == .valid
        } catch ArtifactStoreError.notFound {
            return false
        }
    }

    // MARK: - Additional Methods

    /// List all Polytropos video assets in the artifact store.
    public func listVideoAssets(limit: Int = 100) async throws -> [StoredArtifact] {
        try await artifactStore.listArtifacts(
            mediaType: mediaType,
            trustTier: nil,
            limit: limit
        )
    }

    /// Verify integrity of a stored VideoAsset.
    /// Returns a verification result from ArtifactStoreModule
    public func verifyAsset(artifactID: String) async throws -> Any {
        try await artifactStore.verify(artifactID: artifactID)
    }
}

// MARK: - PolytroposArtifactStoreFactory

/// Factory for creating ArtifactStoreModule integration.
public enum PolytroposArtifactStoreFactory {
    /// Create a PolytroposArtifactStoreAdapter from runtime components.
    public static func createAdapter(
        artifactAuthority: any ArtifactAuthority,
        storageRoot: URL,
        database: ArtifactStoreDatabase
    ) -> PolytroposArtifactStoreAdapter {
        let artifactStore = ArtifactStoreModule(
            artifactAuthority: artifactAuthority,
            storageRoot: storageRoot,
            database: database,
            eventSink: nil
        )
        return PolytroposArtifactStoreAdapter(artifactStore: artifactStore)
    }
}

// MARK: - VideoAsset Extension for Persistence

extension VideoAsset {
    /// Create a VideoAsset from a StoredArtifact.
    public static func from(artifact: StoredArtifact, content: Data) throws -> VideoAsset {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var asset = try decoder.decode(VideoAsset.self, from: content)
        asset.artifactID = artifact.artifactID
        return asset
    }
}

// MARK: - Polytropos Database Integration

/// Database adapter for storing Polytropos-specific metadata.
public actor PolytroposDatabase {
    private let dbExecutor: any DatabaseExecutor

    public init(dbExecutor: any DatabaseExecutor) async throws {
        self.dbExecutor = dbExecutor
        try await executeMigrations()
    }

    private func executeMigrations() async throws {
        _ = try await dbExecutor.executeAsync("""
            CREATE TABLE IF NOT EXISTS polytropos_video_assets (
                id TEXT PRIMARY KEY,
                artifact_id TEXT,
                file_path TEXT NOT NULL,
                filename TEXT NOT NULL,
                duration REAL NOT NULL,
                width INTEGER NOT NULL,
                height INTEGER NOT NULL,
                codec TEXT NOT NULL,
                frame_rate REAL NOT NULL,
                frame_count INTEGER NOT NULL,
                status TEXT NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            );
            """, parameters: [])

        _ = try await dbExecutor.executeAsync(
            "CREATE INDEX IF NOT EXISTS idx_polytropos_assets_status ON polytropos_video_assets(status);",
            parameters: []
        )

        _ = try await dbExecutor.executeAsync(
            "CREATE INDEX IF NOT EXISTS idx_polytropos_assets_artifact ON polytropos_video_assets(artifact_id);",
            parameters: []
        )
    }

    /// Insert or update a VideoAsset record.
    public func upsertAsset(_ asset: VideoAsset) async throws {
        _ = try await dbExecutor.executeAsync("""
            INSERT OR REPLACE INTO polytropos_video_assets (
                id, artifact_id, file_path, filename, duration, width, height,
                codec, frame_rate, frame_count, status, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, parameters: [
                DatabaseParameter.text(asset.id.uuidString),
                asset.artifactID.map { DatabaseParameter.text($0) } ?? DatabaseParameter.null,
                DatabaseParameter.text(asset.fileReference.path),
                DatabaseParameter.text(asset.fileReference.filename),
                DatabaseParameter.double(asset.metadata.duration),
                DatabaseParameter.int(asset.metadata.resolution.width),
                DatabaseParameter.int(asset.metadata.resolution.height),
                DatabaseParameter.text(asset.metadata.codec.identifier),
                DatabaseParameter.double(asset.metadata.frameRate),
                DatabaseParameter.int(asset.frameFingerprints.count),
                DatabaseParameter.text(asset.status.rawValue),
                DatabaseParameter.double(asset.createdAt.timeIntervalSince1970),
                DatabaseParameter.double(asset.updatedAt.timeIntervalSince1970)
            ])
    }

    /// Fetch an asset by ID.
    public func fetchAsset(id: UUID) async throws -> VideoAssetRow? {
        let rows = try await dbExecutor.query("""
            SELECT * FROM polytropos_video_assets WHERE id = ? LIMIT 1
            """, parameters: [DatabaseParameter.text(id.uuidString)])

        guard let row = rows.first else { return nil }
        return parseAssetRow(row)
    }

    /// List assets by status.
    public func listAssets(status: VideoAssetStatus? = nil, limit: Int = 100) async throws -> [VideoAssetRow] {
        var sql = "SELECT * FROM polytropos_video_assets"
        var parameters: [DatabaseParameter] = []

        if let status = status {
            sql += " WHERE status = ?"
            parameters.append(DatabaseParameter.text(status.rawValue))
        }

        sql += " ORDER BY updated_at DESC LIMIT ?"
        parameters.append(DatabaseParameter.int(limit))

        let rows = try await dbExecutor.query(sql, parameters: parameters)
        return rows.compactMap { parseAssetRow($0) }
    }

    private func parseAssetRow(_ row: DatabaseRow) -> VideoAssetRow? {
        guard
            let id = row.string(for: "id"),
            let filePath = row.string(for: "file_path"),
            let filename = row.string(for: "filename"),
            let duration = row.double(for: "duration"),
            let width = row.int(for: "width"),
            let height = row.int(for: "height"),
            let codec = row.string(for: "codec"),
            let frameRate = row.double(for: "frame_rate"),
            let frameCount = row.int(for: "frame_count"),
            let status = row.string(for: "status"),
            let createdAt = row.double(for: "created_at"),
            let updatedAt = row.double(for: "updated_at")
        else {
            return nil
        }

        return VideoAssetRow(
            id: UUID(uuidString: id) ?? UUID(),
            artifactID: row.string(for: "artifact_id"),
            filePath: filePath,
            filename: filename,
            duration: duration,
            width: width,
            height: height,
            codec: codec,
            frameRate: frameRate,
            frameCount: frameCount,
            status: VideoAssetStatus(rawValue: status) ?? .pending,
            createdAt: Date(timeIntervalSince1970: createdAt),
            updatedAt: Date(timeIntervalSince1970: updatedAt)
        )
    }
}

/// Lightweight row representation for database queries.
public struct VideoAssetRow: Sendable {
    public let id: UUID
    public let artifactID: String?
    public let filePath: String
    public let filename: String
    public let duration: TimeInterval
    public let width: Int
    public let height: Int
    public let codec: String
    public let frameRate: Double
    public let frameCount: Int
    public let status: VideoAssetStatus
    public let createdAt: Date
    public let updatedAt: Date
}
