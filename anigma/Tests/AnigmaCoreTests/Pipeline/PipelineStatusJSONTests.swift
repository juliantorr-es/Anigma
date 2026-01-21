//
//  PipelineStatusJSONTests.swift
//  AnigmaCoreTests
//
//  Unit tests for AnigmaCoreTests.
//

import XCTest
@testable import AnigmaCore
@testable import ContractsCore
@testable import DatabaseCore

final class PipelineStatusJSONTests: XCTestCase {
    func testStatusSnapshotIsStableJSON() async throws {
        let contractA = ContractID(name: "A", major: 1, minor: 0, schemaHash: "v1")
        let contractC = ContractID(name: "C", major: 1, minor: 0, schemaHash: "v1")
        let status = PipelineStatus(
            statusSchemaVersion: 1,
            sessionID: "sess-json",
            nextEligible: ["A", "B"],
            blocked: [BlockedContractStatus(contractID: contractC, upstreamStatuses: [contractA: .quarantined])],
            quarantined: [],
            pendingJobs: [
                RunContractJobRecord(
                    id: "job-1",
                    payload: RunContractJobPayload(contractID: contractA, sessionID: "sess-json", inputArtifactIDs: [], inputKey: "key"),
                    queueKey: "q",
                    status: .pending,
                    attempts: 0,
                    createdAt: Date(timeIntervalSince1970: 0),
                    updatedAt: Date(timeIntervalSince1970: 0)
                )
            ],
            runningJobs: []
        )
        let json = try PipelineStatusSerializer.encode(status: status)
        let decoded = try PipelineStatusSerializer.decode(data: json)
        XCTAssertEqual(decoded.sessionID, status.sessionID)
        XCTAssertEqual(decoded.nextEligible, ["A", "B"])
        XCTAssertEqual(decoded.blocked.first?.contractID, contractC)
    }

    func testStatusSnapshotMatchesFixture() throws {
        let status = PipelineStatus(
            statusSchemaVersion: 1,
            sessionID: "sess-fixture",
            nextEligible: [],
            blocked: [],
            quarantined: [],
            pendingJobs: [],
            runningJobs: []
        )
        let data = try PipelineStatusSerializer.encode(status: status)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            fatalError("Failed to unwrap jsonString")
        }
        let expected = #"{"blocked":[],"nextEligible":[],"pendingJobs":[],"quarantined":[],"runningJobs":[],"sessionID":"sess-fixture","statusSchemaVersion":1}"#
        XCTAssertEqual(jsonString, expected)
    }
}
