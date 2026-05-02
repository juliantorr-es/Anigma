//
//  IndexingGovernanceTests.swift
//  GovernanceTests
//
//  Tests ensuring indexing respects governance modes.
//

import XCTest
import HarmoniaV2Surface
import HarmoniaV2Contracts
import GovernanceCore
import AnigmaCore
import AnigmaJobs

/// Actor to ensure mode flip happens exactly once (not vulnerable to race conditions)
fileprivate actor FlipGate {
    private var didFlip = false
    
    func tryFlipNow() -> Bool {
        guard !didFlip else { return false }
        didFlip = true
        return true
    }
}

final class IndexingGovernanceTests: XCTestCase {
    
    var tempDir: URL!
    var dbPath: String!
    var folderToIndex: URL!
    
    override func setUp() async throws {
        // Create temp dirs
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        dbPath = tempDir.appendingPathComponent("test.sqlite").path
        folderToIndex = tempDir.appendingPathComponent("Content")
        try FileManager.default.createDirectory(at: folderToIndex, withIntermediateDirectories: true)
        
        // Create dummy files
        for i in 0..<10 {
            let fileURL = folderToIndex.appendingPathComponent("file_\(i).txt")
            try "Content \(i)".write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    func testIndexingStopsOnDenial() async throws {
        // 1. Setup Client
        let client = LocalAppClient(databasePath: dbPath)
        try await client.bootstrap()
        
        let principal = Principal(id: "tester", displayName: "Tester")
        let adminPrincipal = Principal(id: "test-admin", displayName: "Test Admin")
        
        // Create Project
        let projectId = "proj-1"
        try await client.createProject(id: projectId, name: "Test Project", embeddingModel: "dummy", principal: principal)
        
        // Set mode to normal (allowed) - use admin principal for governance operations
        // Using HarmoniaV2Contracts.OperatingMode cases
        try await client.setMode(.normal, for: projectId, principal: adminPrincipal)
        
        // 2. Start Indexing
        // We use a stream wrapper to allow us to intervene
        let stream = try await client.index(folder: folderToIndex, projectId: projectId, principal: principal, dryRun: false)
        
        var chunksWritten = 0
        var denied = false
        var failureMessage: String?
        var capturedViolation: HarmoniaV2Contracts.GovernanceViolation?
        let flipGate = FlipGate()
        
        var iterator = stream.makeAsyncIterator()
        
        // Consume first few events
        while let event = await iterator.next() {
            if event.chunksWritten > 0 {
                chunksWritten = event.chunksWritten
            }
            
            // Once we have processed a few chunks, flip the switch (exactly once!)
            if chunksWritten >= 2 {
                let shouldFlip = await flipGate.tryFlipNow()
                if shouldFlip {
                    // FLIP TO RESTRICTED - use admin principal for governance operations
                    // Using HarmoniaV2Contracts.OperatingMode cases
                    try await client.setMode(.restricted, for: projectId, principal: adminPrincipal)
                    
                    // Verify mode changed
                    let status = try await client.getStatus(projectId: projectId)
                    XCTAssertEqual(status.operatingMode, .restricted, "Mode flip failed!")
                }
            }
            
            // Check for failure/denial in event
            if let error = event.error {
                failureMessage = error
                if error.contains("Denied") || event.phase == "Failed" {
                    denied = true
                    capturedViolation = event.violation
                    break // Stream should end or we break
                }
            }
            
            if event.isComplete {
                break
            }
        }
        
        // 3. Assertions
        XCTAssertTrue(denied, "Indexing should have been denied after mode flip")
        XCTAssertNotNil(failureMessage)
        XCTAssertTrue(failureMessage?.contains("Denied") == true, "Error should mention Denial")
        
        // Verify structured violation is present
        XCTAssertNotNil(capturedViolation, "Structured violation should be present")
        if let violation = capturedViolation {
            XCTAssertFalse(violation.failedChecks.isEmpty, "Violation should list failed checks")
            XCTAssertEqual(violation.failedChecks.first?.checkId, "operating-mode", "Should fail on operating-mode check")
        }
        
        // Verify we didn't process ALL files (we had 10, flipped after ~2)
        // Note: exact count depends on concurrency/buffering, but should not be 10.
        // Actually, LocalAppClient is serial.
        XCTAssertLessThan(chunksWritten, 10, "Should have stopped before processing all files")
    }
}
