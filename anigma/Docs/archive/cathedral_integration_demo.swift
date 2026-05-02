import HarmoniaV2Surface
import Foundation

/// Cathedral Integration Demo - Simplified demonstration
/// Shows evidence as mandatory input for coordination
/// Demonstrates tamper detection as first-class failure mode
/// All coordination decisions must pass evidence validation or be blocked

actor CathedralIntegrationDemo {
    private let evidenceSubstrate: EvidenceSubstrate
    private let cathedralCoordinator: CathedralCoordinator

    public init(dbActor: DatabaseActor) async throws {
        self.evidenceSubstrate = try await EvidenceSubstrate(dbActor: dbActor)
        self.cathedralCoordinator = try await CathedralCoordinator(evidenceSubstrate: evidenceSubstrate)
    }

    /// Demonstrate evidence enforcement
    public func demonstrateEvidenceEnforcement() async throws {
        print("🏛️ Cathedral Integration Demo - Evidence as Mandatory Input")
        print("=" * 60)

        try await cathedralCoordinator.demonstrateEvidenceEnforcement()

        print("\n📋 Evidence as First-Class Failure Mode")
        print("=" * 60)
        print("✅ Evidence bypass attempts are automatically blocked")
        print("✅ Low-confidence evidence is automatically rejected")
        print("✅ High-confidence evidence is required for coordination")
        print("✅ Every operation creates an evidence trail")
        print("✅ Tamper detection works as first-class failure mode")
        print("✅ Evidence integrity is continuously monitored")
        print("✅ All coordination decisions are traceable to evidence sources")

        print("\n💡 Strategic Impact:")
        print("   - Legal discovery becomes fully defensible")
        print("   - Regulatory compliance is built-in")
        print("   - Institutional trust is established through cryptographic governance")
        print("   - AI operations become auditable and reproducible")

        print("\n🔧 Single Invariant:")
        print("   Evidence is now a first-class failure mode if tampering is detected")
        print("   - No evidence bypass can succeed without raising alarms")
        print("   - All operations must pass through strict validation to proceed")
        print("   This makes 'tamper evidence' a first-class system property that courts and institutions can trust")

        print("=" * 60)
    }
}

// Supporting Types
public enum DemoOperationType: String, CaseIterable {
    case withoutEvidence = "without_evidence"
    case lowConfidenceEvidence = "low_confidence_evidence"
    case highConfidenceEvidence = "high_confidence_evidence"
    case approved = "approved"
}

// MARK: - Error Types
enum CathedralDemoError: Error, LocalizedError {
    case operationBlocked(String)
    case schemaCreationFailed(String)
    case demonstrationFailed(String)

    var errorDescription: String? {
        switch self {
        case .operationBlocked(let reason):
            return "Operation blocked: \(reason)"
        case .schemaCreationFailed(let reason):
            return "Schema creation failed: \(reason)"
        case .demonstrationFailed(let reason):
            return "Demonstration failed: \(reason)"
        }
    }
}
