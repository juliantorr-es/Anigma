import DatabaseCore
import ExecutionCore
import Foundation
import StorageCore
import XCTest

@testable import AnigmaDaemonCore

final class DaemonInProcessIngestTests: XCTestCase {
    func testInProcessOutputsAreIngested() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("anigma-daemoncore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let vaultRoot = tempRoot.appendingPathComponent("vault", isDirectory: true)
        let config = DaemonConfiguration(
            daemon: DaemonConfig(
                unixSocket: tempRoot.appendingPathComponent("anigmad.sock").path,
                tcpEnabled: false,
                executionMode: .inProcess
            ),
            vault: VaultConfig(rootPath: vaultRoot.path, maxSizeGB: 1, encryptionEnabled: true),
            governance: GovernanceConfig(strictMode: false, auditAllOperations: false, receiptStoreMode: .inMemory),
            resources: ResourceConfig(maxConcurrentJobs: 1, workerProcesses: 1),
            telemetry: TelemetryConfig(enabled: false)
        )

        let daemon = try await DaemonServer(configuration: config)
        await daemon.registerWorker(TestOutputWorker())

        let session = await daemon.handleOpenSession(
            requestedClientName: "test-client",
            requestedScopes: ["vault.write", "vault.read", "job.submit"]
        )
        let ctx = RequestContext(
            clientId: session.clientId,
            capabilityToken: session.capabilityToken,
            nonce: UUID().uuidString
        )

        let input = Data("input".utf8)
        let plaintextHash = "6fc70c62b606c1f1c9c2b03b75c0a4f02eb1d1b2b7340c0cdb4f4b76a50e7d09"
        let ingest = try await daemon.handleIngestArtifact(
            ctx: ctx,
            kind: "original",
            mime: "text/plain",
            data: input,
            plaintextSha256: plaintextHash,
            chunkCount: 1,
            byteCount: input.count,
            filenameHint: nil
        )

        let spec = JobSpec(
            kind: TestOutputWorker.kind,
            configCanonical: Data(),
            inputs: [ingest.artifact]
        )
        let job = Job(id: UUID().uuidString, spec: spec, clientId: "test-client")

        let payloads = try await daemon.executeInProcess(job)
        let outputs = try await daemon.ingestWorkerOutputs(
            payloads,
            inputs: spec.inputs,
            jobId: job.id,
            jobKind: spec.kind
        )

        XCTAssertEqual(outputs.count, 1)
        let retrieveResult = try await daemon.handleRetrieveArtifact(
            ctx: ctx,
            hash: outputs[0].hash
        )
        XCTAssertEqual(retrieveResult.data, Data("derived".utf8))
    }

    func testIngestChunkReceiptsStoredInVault() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("anigma-daemoncore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let vaultRoot = tempRoot.appendingPathComponent("vault", isDirectory: true)
        let config = DaemonConfiguration(
            daemon: DaemonConfig(
                unixSocket: tempRoot.appendingPathComponent("anigmad.sock").path,
                tcpEnabled: false,
                executionMode: .inProcess
            ),
            vault: VaultConfig(rootPath: vaultRoot.path, maxSizeGB: 1, encryptionEnabled: true),
            governance: GovernanceConfig(
                strictMode: false,
                auditAllOperations: true,
                receiptStoreMode: .vault
            ),
            resources: ResourceConfig(maxConcurrentJobs: 1, workerProcesses: 1),
            telemetry: TelemetryConfig(enabled: false)
        )

        let daemon = try await DaemonServer(configuration: config)
        let session = await daemon.handleOpenSession(
            requestedClientName: "test-client",
            requestedScopes: ["vault.write"]
        )
        let ctx = RequestContext(
            clientId: session.clientId,
            capabilityToken: session.capabilityToken,
            nonce: UUID().uuidString
        )

        let input = Data("chunked".utf8)
        let plaintextHash = "59fdd34a0b323f6044e147b843d8ca246a9414d2c7a06c8e95a7e04c3cdaf395"

        let chunkReceipt = await daemon.handleIngestChunk(
            ctx: ctx,
            mime: "text/plain",
            filenameHint: "chunked.txt",
            chunkIndex: 0,
            chunkBytes: input.count,
            totalBytes: input.count
        )
        XCTAssertNotNil(chunkReceipt)

        _ = try await daemon.handleIngestArtifact(
            ctx: ctx,
            kind: "original",
            mime: "text/plain",
            data: input,
            plaintextSha256: plaintextHash,
            chunkCount: 1,
            byteCount: input.count,
            filenameHint: "chunked.txt"
        )

        let dbPath = vaultRoot.appendingPathComponent("vault.db").path
        let dbActor = DatabaseActor(dbPath: dbPath)
        try await dbActor.open()
        let vault = try await VaultAuthority(
            rootURL: vaultRoot,
            database: dbActor,
            keyProvider: DefaultVaultKeyProvider.make()
        )
        let receiptStore = VaultReceiptStore(vault: vault)

        let chunkReceipts = try await receiptStore.list(
            filter: ReceiptFilter(actionName: "vault.ingest.chunk")
        )
        let ingestReceipts = try await receiptStore.list(
            filter: ReceiptFilter(actionName: "vault.ingest")
        )

        XCTAssertFalse(chunkReceipts.isEmpty)
        XCTAssertFalse(ingestReceipts.isEmpty)

        let chunkReceiptId = try XCTUnwrap(chunkReceipts.first?.receiptID)
        XCTAssertTrue(ingestReceipts.contains { $0.previousReceiptHash == chunkReceiptId })
    }
}

private struct TestOutputWorker: JobWorker {
    static let kind = "test.output"

    func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        return [
            JobOutputPayload(
                data: Data("derived".utf8),
                mediaType: "text/plain",
                kind: "derived"
            )
        ]
    }
}
