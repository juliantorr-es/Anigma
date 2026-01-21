//
//  DevelopumArtifactService.swift
//  DevelopumModule
//
//  Service for managing file artifacts with immutable storage.
//  All file saves create immutable artifacts first, then optionally mirror to working tree.
//

import AnigmaCore
import AnigmaPrimitives
import CryptoKit
import Foundation

public actor DevelopumArtifactService {
    private let artifactAuthority: any ArtifactAuthority
    private let databaseService: DevelopumDatabaseService

    private let defaultMimeType = "text/plain"

    public init(
        artifactAuthority: any ArtifactAuthority,
        databaseService: DevelopumDatabaseService
    ) {
        self.artifactAuthority = artifactAuthority
        self.databaseService = databaseService
    }

    @discardableResult
    public func storeFile(
        repoId: UUID,
        filePath: String,
        content: String,
        mimeType: String? = nil
    ) async throws -> (hash: String, artifactId: ArtifactID) {
        let contentData = content.data(using: .utf8)!
        let hash = SHA256.hash(data: contentData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()

        let artifactId = ArtifactID(hash: hashString)
        let artifact = Artifact(
            id: artifactId,
            mimeType: mimeType ?? detectMimeType(for: filePath),
            size: Int64(contentData.count),
            createdAt: Date(),
            tags: ["developum", "file", "repo:\(repoId.uuidString)"],
            metadata: [
                "filePath": filePath,
                "repoId": repoId.uuidString,
                "originalName": (filePath as NSString).lastPathComponent
            ],
            content: contentData
        )

        let context = ExecutionContext(principal: .system)
        let (_, _) = try await artifactAuthority.store(artifact, context: context)

        let messageBody = """
        {"filePath":"\(filePath)","hash":"\(hashString)"}
        """.data(using: .utf8)!

        try? await databaseService.recordBridgeEvent(
            repoId: repoId,
            sessionId: repoId.uuidString,
            messageType: "saveFile",
            messageHash: hashString,
            messageBody: messageBody,
            receiptHash: artifactId.hash,
            artifactHash: nil as String?
        )

        logInfo("Stored artifact for \(filePath): \(artifactId.hash.prefix(8))...", category: "DevelopumArtifactService")

        return (hashString, artifactId)
    }

    public func retrieveFile(hash: String) async throws -> String {
        let artifactId = ArtifactID(hash: hash)
        let artifact = try await artifactAuthority.retrieve(artifactId, principal: .system)

        guard let content = artifact.content else {
            throw DevelopumArtifactError.artifactNotFound(hash: hash)
        }

        guard let contentString = String(data: content, encoding: .utf8) else {
            throw DevelopumArtifactError.invalidContent(hash: hash)
        }

        return contentString
    }

    public func mirrorToWorkingTree(
        repoPath: String,
        filePath: String,
        content: String
    ) async throws {
        let fullPath = "\(repoPath)/\(filePath)"
        let fileURL = URL(fileURLWithPath: fullPath)

        let parentDir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        logInfo("Mirrored to working tree: \(fullPath)", category: "DevelopumArtifactService")
    }

    public func computeHash(content: String) -> String {
        let contentData = content.data(using: .utf8)!
        let hash = SHA256.hash(data: contentData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    public func verifyArtifact(hash: String) async throws -> Bool {
        let artifactId = ArtifactID(hash: hash)
        let artifact = try await artifactAuthority.retrieve(artifactId, principal: .system)

        guard let content = artifact.content else {
            return false
        }

        let computedHash = SHA256.hash(data: content)
        let computedHashString = computedHash.compactMap { String(format: "%02x", $0) }.joined()

        return computedHashString == hash
    }

    public func listArtifacts(repoId: UUID) async throws -> [DevelopumArtifactInfo] {
        return []
    }

    public func deleteArtifact(hash: String) async throws {
        let artifactId = ArtifactID(hash: hash)
        logInfo("Artifact marked for deletion: \(hash.prefix(8))...", category: "DevelopumArtifactService")
    }

    private func detectMimeType(for path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()

        let mimeTypes: [String: String] = [
            "swift": "text/x-swift",
            "js": "text/javascript",
            "ts": "text/typescript",
            "py": "text/x-python",
            "rs": "text/x-rust",
            "go": "text/x-go",
            "java": "text/x-java",
            "json": "application/json",
            "xml": "text/xml",
            "html": "text/html",
            "css": "text/css",
            "md": "text/markdown",
            "txt": "text/plain"
        ]

        return mimeTypes[ext] ?? defaultMimeType
    }
}

public enum DevelopumArtifactError: Error, LocalizedError {
    case artifactNotFound(hash: String)
    case invalidContent(hash: String)
    case storageFailed(Error)
    case retrievalFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .artifactNotFound(let hash):
            return "Artifact not found: \(hash)"
        case .invalidContent(let hash):
            return "Artifact content is not valid UTF-8: \(hash)"
        case .storageFailed(let error):
            return "Failed to store artifact: \(error.localizedDescription)"
        case .retrievalFailed(let error):
            return "Failed to retrieve artifact: \(error.localizedDescription)"
        }
    }
}

public struct DevelopumArtifactInfo: Codable, Sendable {
    public let hash: String
    public let filePath: String
    public let size: Int64
    public let createdAt: Date
    public let mimeType: String

    public init(hash: String, filePath: String, size: Int64, createdAt: Date, mimeType: String) {
        self.hash = hash
        self.filePath = filePath
        self.size = size
        self.createdAt = createdAt
        self.mimeType = mimeType
    }
}
