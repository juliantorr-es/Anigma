import Foundation
import XCTest

import TelemetryCore

@testable import AnigmaDaemonCore

final class TelemetryStreamTests: XCTestCase {
    func testTelemetryStreamAcceptsValidPayload() async throws {
        let (daemon, root) = try await makeDaemon()
        defer { try? FileManager.default.removeItem(at: root) }
        let payload = TelemetryEvent(
            category: .system,
            name: "streamed",
            privacyClassification: .restricted,
            values: ["source": .hashedToken(TelemetryHash(input: "test"))]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payloadJson = String(data: try encoder.encode(payload), encoding: .utf8) ?? "{}"

        var event = AnigmaTelemetryEvent()
        event.type = "system"
        event.payloadJson = payloadJson
        event.atUnixMs = UInt64(Date().timeIntervalSince1970 * 1000)

        let ctx = try await makeContext(daemon: daemon)
        let result = await daemon.handleTelemetryEvent(ctx: ctx, event: event)
        XCTAssertTrue(result.accepted)
        if let error = result.error {
            XCTFail("Expected success, got error: \(error)")
        }
    }

    func testTelemetryStreamRejectsInvalidPayload() async throws {
        let (daemon, root) = try await makeDaemon()
        defer { try? FileManager.default.removeItem(at: root) }
        var event = AnigmaTelemetryEvent()
        event.type = "system"
        event.payloadJson = "{not json"
        event.atUnixMs = UInt64(Date().timeIntervalSince1970 * 1000)

        let ctx = try await makeContext(daemon: daemon)
        let result = await daemon.handleTelemetryEvent(ctx: ctx, event: event)
        XCTAssertFalse(result.accepted)
    }

    private func makeDaemon() async throws -> (DaemonServer, URL) {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("anigma-telemetry-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let vaultRoot = tempRoot.appendingPathComponent("vault", isDirectory: true)

        let config = DaemonConfiguration(
            daemon: DaemonConfig(
                unixSocket: tempRoot.appendingPathComponent("anigmad.sock").path,
                tcpEnabled: false
            ),
            vault: VaultConfig(rootPath: vaultRoot.path, maxSizeGB: 1, encryptionEnabled: true),
            governance: GovernanceConfig(strictMode: false, auditAllOperations: false, receiptStoreMode: .inMemory),
            resources: ResourceConfig(maxConcurrentJobs: 1, workerProcesses: 1),
            telemetry: TelemetryConfig(enabled: true)
        )

        let daemon = try await DaemonServer(configuration: config)
        return (daemon, tempRoot)
    }

    private func makeContext(daemon: DaemonServer) async throws -> RequestContext {
        let session = await daemon.handleOpenSession(
            requestedClientName: "telemetry-test",
            requestedScopes: ["telemetry.write"]
        )
        return RequestContext(
            clientId: session.clientId,
            capabilityToken: session.capabilityToken,
            nonce: UUID().uuidString
        )
    }
}
