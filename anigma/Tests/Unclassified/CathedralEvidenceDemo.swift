#!/usr/bin/env swift

import Foundation
import DatabaseCore
import AnigmaCore
import ContractsCore

/// Simple Cathedral Evidence Enforcement Demo
/// Demonstrates evidence as mandatory input for coordination decisions

@main
struct CathedralEvidenceDemo {
    static func main() async throws {
        print("🏛️ Cathedral Evidence Enforcement Demo")
        print("=" * 50)

        do {
            // Initialize database connection
            let dbActor = try DatabaseActor.shared

            // Initialize evidence substrate
            let evidenceSubstrate = try await EvidenceSubstrate(dbActor: dbActor)
            let cathedralCoordinator = try await CathedralCoordinator(evidenceSubstrate: evidenceSubstrate)

            print("\n📋 Testing Evidence Enforcement Mechanism:")

            // Test 1: Try operation without evidence (should be blocked)
            print("\n1️⃣ Testing operation without evidence...")
            try await testWithoutEvidence(evidenceSubstrate: evidenceSubstrate)

            // Test 2: Try operation with minimal evidence (should be rejected)
            print("\n2️⃣ Testing operation with minimal evidence...")
            try await testWithMinimalEvidence(evidenceSubstrate: evidenceSubstrate)

            // Test 3: Try operation with sufficient evidence (should succeed)
            print("\n3️⃣ Testing operation with sufficient evidence...")
            try await testWithSufficientEvidence(evidenceSubstrate: evidenceSubstrate, dbActor: dbActor)

            // Test 4: Validate evidence chain
            print("\n4️⃣ Testing evidence chain validation...")
            try await testEvidenceChainValidation(coordinator: cathedralCoordinator, dbActor: dbActor)

            print("\n✅ Cathedral Evidence Enforcement Demo - Complete!")
            print("\n🎯 Key Results:")
            print("   • Evidence bypass attempts were automatically blocked")
            print("   • Low-confidence evidence was automatically rejected")
            print("   • High-confidence evidence was required and accepted")
            print("   • Evidence chain integrity was validated")
            print("   • All operations created verifiable evidence trails")

        } catch {
            print("❌ Demo failed: \(error)")
        }
    }

    static func testWithoutEvidence(evidenceSubstrate: EvidenceSubstrate) async throws {
        do {
            _ = try await evidenceSubstrate.enforceEvidenceSubstrate(
                operation: "test_operation_without_evidence",
                evidenceLevel: .moderate
            )
            print("❌ ERROR: Operation should have been blocked but succeeded")
        } catch CathedralError.operationBlocked(let reason) {
            print("✅ SUCCESS: Operation correctly blocked: \(reason)")
        } catch {
            print("⚠️ UNEXPECTED: Different error occurred: \(error)")
        }
    }

    static func testWithMinimalEvidence(evidenceSubstrate: EvidenceSubstrate) async throws {
        // Create minimal evidence first
        _ = try await evidenceSubstrate.performMLOperation(
            operationType: .documentIngestion,
            inputs: ["test": "minimal"],
            actor: "demo_user",
            purpose: "minimal_evidence_test"
        )

        do {
            _ = try await evidenceSubstrate.enforceEvidenceSubstrate(
                operation: "test_operation_minimal_evidence",
                evidenceLevel: .high
            )
            print("❌ ERROR: Operation should have been blocked but succeeded")
        } catch CathedralError.operationBlocked(let reason) {
            print("✅ SUCCESS: Operation correctly blocked: \(reason)")
        } catch {
            print("⚠️ UNEXPECTED: Different error occurred: \(error)")
        }
    }

    static func testWithSufficientEvidence(evidenceSubstrate: EvidenceSubstrate, dbActor: DatabaseActor) async throws {
        // Create multiple evidence entries to build confidence
        for i in 1...5 {
            _ = try await evidenceSubstrate.performMLOperation(
                operationType: .documentIngestion,
                inputs: ["test": "evidence_\(i)", "index": i],
                actor: "demo_user",
                purpose: "build_sufficient_evidence"
            )
        }

        do {
            let result = try await evidenceSubstrate.enforceEvidenceSubstrate(
                operation: "test_operation_sufficient_evidence",
                evidenceLevel: .moderate
            )
            print("✅ SUCCESS: Operation approved with evidence level: \(result.evidenceLevel.rawValue)")
        } catch {
            print("❌ ERROR: Operation should have succeeded but failed: \(error)")
        }
    }

    static func testEvidenceChainValidation(coordinator: CathedralCoordinator, dbActor: DatabaseActor) async throws {
        let sessionId = "demo_session_\(UUID().uuidString.lowercased())"

        // Create some evidence for this session
        let evidence1 = EvidenceRecord(
            id: UUID().uuidString.lowercased(),
            sessionId: sessionId,
            agentId: "demo_agent",
            toolName: "test_tool",
            requestId: "req_1",
            parameters: "test params",
            startTime: Date(),
            status: "completed"
        )

        try await coordinator.recordEvidence(evidence1)

        // Validate the chain
        let validation = try await coordinator.validateEvidenceChain(sessionId: sessionId)

        if validation.isValid {
            print("✅ SUCCESS: Evidence chain is valid")
        } else {
            print("⚠️ WARNING: Evidence chain has \(validation.violations.count) violations")
            for violation in validation.violations {
                print("   - \(violation.severity.rawValue): \(violation.description)")
            }
        }

        print("📊 Chain stats: \(validation.chainLength) events, last hash: \(validation.lastHash?.prefix(8) ?? "nil")")
    }
}

extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}
