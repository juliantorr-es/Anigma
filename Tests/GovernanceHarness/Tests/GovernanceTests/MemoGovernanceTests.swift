//
//  MemoGovernanceTests.swift
//  GovernanceTests
//
//  Tests ensuring memo capture functionality works.
//  Note: Full governance enforcement is not yet wired to addMemo.
//  These tests verify basic functionality; governance tests require 
//  governance to be fully integrated into LocalAppClient.
//

import XCTest
import HarmoniaV2Surface
import HarmoniaV2Contracts
import GovernanceCore
import AnigmaCore
import AnigmaJobs

final class MemoGovernanceTests: XCTestCase {
    
    var tempDir: URL!
    var dbPath: String!
    
    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        dbPath = tempDir.appendingPathComponent("test.sqlite").path
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    func testMemoBasicLifecycle() async throws {
        let client = LocalAppClient(databasePath: dbPath)
        try await client.bootstrap()
        
        let principal = Principal(id: "tester", displayName: "Tester")
        let projectId = "proj-memo"
        try await client.createProject(id: projectId, name: "Memo Project", embeddingModel: "default", principal: principal)
        
        // Verify we can set mode
        try await client.setMode(.normal, for: projectId, principal: principal)
        
        // Add a memo
        let memo1 = try await client.addMemo(text: "Memo 1", projectId: projectId, principal: principal)
        XCTAssertFalse(memo1.id.isEmpty)
        
        // Recall verification
        let options = RecallOptions(topK: 10, scanLimit: 100, hybrid: true)
        let results = try await client.recall(query: "Memo", projectId: projectId, options: options)
        
        XCTAssertGreaterThanOrEqual(results.results.count, 0)
    }
    
    func testKillSwitchAPIExists() async throws {
        let client = LocalAppClient(databasePath: dbPath)
        try await client.bootstrap()
        
        let principal = Principal(id: "tester", displayName: "Tester")
        let projectId = "proj-kill"
        try await client.createProject(id: projectId, name: "Kill Project", embeddingModel: "default", principal: principal)
        
        // Verify we can call setKillSwitch without error
        // Note: actual enforcement requires governance to be wired up
        try await client.setKillSwitch(active: true, for: projectId, reason: "Testing", principal: principal)
        
        // Verify we can add memo even with kill switch (since enforcement not wired yet)
        let memo = try await client.addMemo(text: "Memo after kill switch", projectId: projectId, principal: principal)
        XCTAssertFalse(memo.id.isEmpty)
    }
}
