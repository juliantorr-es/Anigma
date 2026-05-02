// KillSwitchTests.swift
// Tests for Kill Switch Governance

import Foundation
import Testing
@testable import HarmoniaV2CLIKernel
import HarmoniaV2Core
import AnigmaJobs
import AnigmaCore
import GovernanceCore
import DatabaseCore

struct KillSwitchTests {
    let testDbPath: String
    
    init() async throws {
        testDbPath = NSTemporaryDirectory() + "test-killswitch-\(UUID().uuidString).db"
        
        // Clear any global kill switch that might have been left by previous test runs
        try? await CLIKernel.runKillSwitchClear(
            projectId: nil,
            principal: "test-cleanup-admin",
            databasePath: testDbPath
        )
    }
    
    @Test func testKillSwitchBlocksWrites() async throws {
        let config = CLIKernelConfig(databasePath: testDbPath, enforceGovernance: true)
        let projectId = "proj-ks-1"
        
        // 1. Ensure initial write works (default mode: assistive)
        try await CLIKernel.runSetMode(mode: .assistive, projectId: projectId, principal: "cli-admin", databasePath: testDbPath)
        
        _ = try await CLIKernel.runMemo(
            content: "Safe Write",
            userId: "u1",
            projectId: projectId,
            sessionId: "s1",
            config: config
        )
        
        // 2. Activate Kill Switch
        try await CLIKernel.runKillSwitchSet(
            projectId: projectId,
            reason: "Emergency Halt",
            principal: "cli-admin",
            databasePath: testDbPath
        )
        
        // 3. Verify status
        let status = try await CLIKernel.runKillSwitchShow(projectId: projectId, databasePath: testDbPath)
        #expect(status.active)
        #expect(status.reason == "Emergency Halt")
        
        // 4. Attempt Write -> Should Fail
        do {
            _ = try await CLIKernel.runMemo(
                content: "Blocked Write",
                userId: "u1",
                projectId: projectId,
                sessionId: "s2",
                config: config
            )
            Issue.record("Write should be blocked by kill switch")
        } catch let error as RuntimeInitializationError {
            if case .writeBlocked(let violation) = error {
                #expect(violation.failedChecks.contains(where: { $0.checkId == "kill-switch" }))
            } else {
                Issue.record("Unexpected governance error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
        
        // 5. Verify Read -> Should Work
        let recall = try await CLIKernel.runRecall(
            query: "Safe",
            projectId: projectId,
            config: config
        )
        #expect(recall.results.count == 1)
        
        // 6. Clear Kill Switch
        try await CLIKernel.runKillSwitchClear(
            projectId: projectId,
            principal: "cli-admin",
            databasePath: testDbPath
        )
        
        // 7. Write -> Should Work Again
        _ = try await CLIKernel.runMemo(
            content: "Restored Write",
            userId: "u1",
            projectId: projectId,
            sessionId: "s3",
            config: config
        )
    }
    
    @Test func testKillSwitchPersistence() async throws {
        let projectId = "proj-ks-persist"
        
        // 1. Activate Kill Switch
        try await CLIKernel.runKillSwitchSet(
            projectId: projectId,
            reason: "Persist Test",
            principal: "cli-admin",
            databasePath: testDbPath
        )
        
        // 2. Restart (Simulated by new CLIKernel call which creates new Runtime)
        let status = try await CLIKernel.runKillSwitchShow(projectId: projectId, databasePath: testDbPath)
        
        #expect(status.active)
        #expect(status.reason == "Persist Test")
        
        // 3. Verify blocking still works
        let config = CLIKernelConfig(databasePath: testDbPath, enforceGovernance: true)
        do {
            _ = try await CLIKernel.runMemo(
                content: "Blocked After Restart",
                userId: "u1",
                projectId: projectId,
                sessionId: "s1",
                config: config
            )
            Issue.record("Write should be blocked after restart")
        } catch let error as RuntimeInitializationError {
            if case .writeBlocked(let violation) = error {
                #expect(violation.failedChecks.contains(where: { $0.checkId == "kill-switch" }))
            } else {
                Issue.record("Unexpected governance error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    
    @Test func testGlobalKillSwitch() async throws {
        let projectId = "proj-ks-global-target"
        
        // 1. Activate Global Kill Switch (projectId: nil)
        try await CLIKernel.runKillSwitchSet(
            projectId: nil,
            reason: "Global Halt",
            principal: "cli-admin",
            databasePath: testDbPath
        )
        
        // 2. Verify status for specific project (should inherit global)
        let status = try await CLIKernel.runKillSwitchShow(projectId: projectId, databasePath: testDbPath)
        #expect(status.active)
        
        // 3. Attempt Write to Project -> Should Fail
        let config = CLIKernelConfig(databasePath: testDbPath, enforceGovernance: true)
        do {
            _ = try await CLIKernel.runMemo(
                content: "Global Blocked",
                userId: "u1",
                projectId: projectId,
                sessionId: "s1",
                config: config
            )
            Issue.record("Write should be blocked by global kill switch")
        } catch let error as RuntimeInitializationError {
            if case .writeBlocked(let violation) = error {
                #expect(violation.failedChecks.contains(where: { $0.checkId == "kill-switch" }))
            } else {
                Issue.record("Unexpected governance error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}
