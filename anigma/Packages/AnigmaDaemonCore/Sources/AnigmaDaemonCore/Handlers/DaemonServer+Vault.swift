//
//  DaemonServer+Vault.swift
//  AnigmaDaemonCore
//

import Foundation
import AnigmaPrimitives
import ContractsCore
import StorageCore

extension DaemonServer {
    func handleIngestArtifact(config: AnigmaIngestArtifactRequest) async throws -> AnigmaIngestArtifactResponse {
        if await !rateLimiter.allow(clientId: config.ctx.clientId) {
            throw DaemonError.rateLimitExceeded
        }
        
        _ = try await tokenManager.validateToken(config.ctx.capabilityToken, requiredScope: "vault.write")
        
        let vKind = StorageCore.VaultArtifactKind(rawValue: config.kind) ?? .original
        let ref = try await vault.ingest(data: config.data, kind: vKind, mime: config.mediaType)
        let receipt = try await receiptEngine.recordActionExecution(
            actionName: "vault.ingest",
            authority: "anigmad",
            decision: .allowed,
            reasonCode: "INGESTED",
            inputs: [
                "hash": ref.hashHex,
                "mime": config.mediaType,
                "kind": ref.kind.rawValue,
                "bytes": config.data.count,
                "plaintext_hash": config.plaintextHash,
                "filename_hint": config.filenameHint ?? "none"
            ]
        )
        
        return AnigmaIngestArtifactResponse(
            artifact: AnigmaArtifactRef(
                hash: ref.hashHex,
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
            Self.logger.error("CoreReceipt warning: failed to record ingest chunk receipt: \(error.localizedDescription, privacy: .public)")
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
                Self.logger.error("CoreReceipt warning: failed to record retrieve receipt: \(error.localizedDescription, privacy: .public)")
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
        let sorted = vaultArtifacts.sorted { $0.hashHex < $1.hashHex }
        let size = max(1, min(pageSize ?? 100, 1000))
        var startIndex = 0

        if let token = pageToken, !token.isEmpty {
            guard let tokenIndex = sorted.firstIndex(where: { $0.hashHex == token }) else {
                throw DaemonError.invalidPageToken(token)
            }
            startIndex = tokenIndex + 1
        }

        let endIndex = min(startIndex + size, sorted.count)
        let page = sorted[startIndex..<endIndex]
        let nextToken = endIndex < sorted.count ? page.last?.hashHex : nil

        let artifacts = page.map { ref in
            ArtifactRef(
                hash: ref.hashHex,
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
                Self.logger.error("failed to record list receipt: \(error.localizedDescription, privacy: .public)")
            }
        }
        return (artifacts, nextToken)
    }

    // STUB_TRACK: daemon-vault-size-calculation – Vault size calculation not implemented
    func resolveVaultSizeBytes() async throws -> UInt64 {
        Self.logger.warning("STUB INVOKED: DaemonServer.resolveVaultSizeBytes()")
        Self.logger.error("DaemonServer.resolveVaultSizeBytes() is not implemented; refusing to report placeholder vault size")
        throw DaemonError.configurationError("Vault size calculation is not implemented - requires metadata index scan")
    }
}
