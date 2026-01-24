//
//  DaemonServer+Vault.swift
//  AnigmaDaemonCore
//

import Foundation
import ContractsCore
import StorageCore

extension DaemonServer {
    func handleIngestArtifact(config: HandleIngestArtifactConfiguration) async throws -> IngestResult {
        if await !rateLimiter.allow(clientId: config.ctx.clientId) {
            throw DaemonError.rateLimitExceeded
        }
        
        _ = try await tokenManager.validateToken(config.ctx.capabilityToken, requiredScope: "vault.write")
        
        let vKind = StorageCore.VaultArtifactKind(rawValue: config.kind) ?? .original
        let ref = try await vault.ingest(data: config.data, kind: vKind, mime: config.mime)
        let receipt = try await receiptEngine.recordActionExecution(
            actionName: "vault.ingest",
            authority: "anigmad",
            decision: .allowed,
            reasonCode: "INGESTED",
            inputs: [
                "hash": ref.sha256Hex,
                "mime": ref.mime,
                "kind": ref.kind.rawValue,
                "bytes": ref.byteLen,
                "plaintext_sha256": config.plaintextSha256,
                "chunk_count": config.chunkCount,
                "byte_count": config.byteCount,
                "filename_hint": config.filenameHint ?? "none"
            ]
        )
        
        return IngestResult(
            artifact: ArtifactRef(
                hash: ref.sha256Hex,
                mediaType: ref.mime,
                sizeBytes: UInt64(ref.byteLen)
            ),
            receiptHash: receipt.receiptID
        )
    }

    func handleIngestChunk(
        ctx: DaemonRequestContext,
        mime: String,
        filenameHint: String?,
        chunkIndex: Int,
        chunkBytes: Int,
        totalBytes: Int
    ) async -> String? {
        if await !rateLimiter.allow(clientId: ctx.clientId) {
            return nil
        }

        guard configuration.governance.auditAllOperations else { return nil }
        do {
            _ = try await tokenManager.validateToken(
                ctx.capabilityToken, requiredScope: "vault.write")
            let receipt = try await receiptEngine.recordActionExecution(
                actionName: "vault.ingest.chunk",
                authority: "anigmad",
                decision: .allowed,
                reasonCode: "CHUNK_RECEIVED",
                inputs: [
                    "client_id": ctx.clientId,
                    "mime": mime,
                    "filename_hint": filenameHint ?? "none"
                ],
                outputs: [
                    "chunk_index": chunkIndex,
                    "chunk_bytes": chunkBytes,
                    "total_bytes": totalBytes
                ]
            )
            return receipt.receiptID
        } catch {
            print("Receipt warning: failed to record ingest chunk receipt: \(error)")
            return nil
        }
    }

    /// Retrieve an artifact from the vault
    func handleRetrieveArtifact(
        ctx: DaemonRequestContext,
        hash: String
    ) async throws -> (data: Data, receiptHash: String?) {
        if await !rateLimiter.allow(clientId: ctx.clientId) {
            throw DaemonError.rateLimitExceeded
        }

        _ = try await tokenManager.validateToken(
            ctx.capabilityToken, requiredScope: "vault.read")
        let data = try await vault.open(hash: hash)
        var receiptHash: String?
        if configuration.governance.auditAllOperations {
            do {
                let receipt = try await receiptEngine.recordActionExecution(
                    actionName: "vault.retrieve",
                    authority: "anigmad",
                    decision: .allowed,
                    reasonCode: "RETRIEVED",
                    inputs: ["hash": hash],
                    outputs: ["bytes": data.count]
                )
                receiptHash = receipt.receiptID
            } catch {
                print("Receipt warning: failed to record retrieve receipt: \(error)")
            }
        }
        return (data, receiptHash)
    }

    /// List artifacts in the vault
    func handleListArtifacts(
        ctx: DaemonRequestContext,
        pageToken: String?,
        pageSize: Int?
    ) async throws -> (artifacts: [ArtifactRef], nextPageToken: String?) {
        if await !rateLimiter.allow(clientId: ctx.clientId) {
            throw DaemonError.rateLimitExceeded
        }

        _ = try await tokenManager.validateToken(
            ctx.capabilityToken, requiredScope: "vault.read")
        let vaultArtifacts = try await vault.listArtifacts()
        let sorted = vaultArtifacts.sorted { $0.sha256Hex < $1.sha256Hex }
        let size = max(1, min(pageSize ?? 100, 1000))
        var startIndex = 0

        if let token = pageToken, !token.isEmpty {
            guard let tokenIndex = sorted.firstIndex(where: { $0.sha256Hex == token }) else {
                throw DaemonError.invalidPageToken(token)
            }
            startIndex = tokenIndex + 1
        }

        let endIndex = min(startIndex + size, sorted.count)
        let page = sorted[startIndex..<endIndex]
        let nextToken = endIndex < sorted.count ? page.last?.sha256Hex : nil

        let artifacts = page.map { ref in
            ArtifactRef(
                hash: ref.sha256Hex,
                mediaType: ref.mime,
                sizeBytes: UInt64(ref.byteLen)
            )
        }
        if configuration.governance.auditAllOperations {
            do {
                _ = try await receiptEngine.recordActionExecution(
                    actionName: "vault.list",
                    authority: "anigmad",
                    decision: .allowed,
                    reasonCode: "LISTED",
                    inputs: [
                        "page_token": pageToken ?? "none",
                        "page_size": size
                    ],
                    outputs: [
                        "count": artifacts.count,
                        "next_page_token": nextToken ?? "none"
                    ]
                )
            } catch {
                print("failed to record list receipt: \(error)")
            }
        }
        return (artifacts, nextToken)
    }

    func resolveVaultSizeBytes() async -> UInt64 {
        // Implementation logic
        return 0 // Placeholder
    }
}
