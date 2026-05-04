import Foundation

/// anigma.test.receipt.v1 — Deterministic, agent-readable JSON receipt emitted by Swift Testing tests.
///
/// Each migrated test source file generates one receipt per test run.
/// Receipts follow a stable JSON schema for machine readability and CI/CD triage.
public struct TestReceipt: Codable {
    /// Fixed schema version identifier.
    public let schema: String = "anigma.test.receipt.v1"

    /// Target name (e.g., "SaturationInferenceCoreTests").
    public let testTarget: String

    /// Source filename without path (e.g., "SaturationInferenceCoreTests.swift").
    public let sourceFile: String

    /// Relative path to the generated receipt file.
    public let artifactFile: String

    /// Test execution status: "passed", "failed", "error", or "skipped".
    public let status: TestStatus

    /// Human-readable summary of test execution (e.g., "5 test(s) executed, 0 failed").
    public let summary: String

    /// List of validated behaviors (sorted alphabetically).
    public let validatedBehaviors: [String]

    /// Stable debugging hints for agent triage (sorted alphabetically).
    public let debugHintsForAgents: [String]

    /// List of related source files under test (sorted alphabetically).
    public let relatedFiles: [String]

    /// Test execution metrics (counts, duration).
    public let diagnostics: TestDiagnostics

    /// Promotion metadata for archival to curated Docs/proofs.
    public let canonicalPromotion: PromotionMetadata

    // MARK: - Initialization

    public init(
        testTarget: String,
        sourceFile: String,
        artifactFile: String,
        status: TestStatus,
        summary: String,
        validatedBehaviors: [String],
        debugHintsForAgents: [String],
        relatedFiles: [String],
        diagnostics: TestDiagnostics,
        canonicalPromotion: PromotionMetadata
    ) {
        self.testTarget = testTarget
        self.sourceFile = sourceFile
        self.artifactFile = artifactFile
        self.status = status
        self.summary = summary
        // Sort all arrays for determinism
        self.validatedBehaviors = validatedBehaviors.sorted()
        self.debugHintsForAgents = debugHintsForAgents.sorted()
        self.relatedFiles = relatedFiles.sorted()
        self.diagnostics = diagnostics
        self.canonicalPromotion = canonicalPromotion
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case schema
        case testTarget
        case sourceFile
        case artifactFile
        case status
        case summary
        case validatedBehaviors
        case debugHintsForAgents
        case relatedFiles
        case diagnostics
        case canonicalPromotion
    }
}

/// Test execution status enumeration.
public enum TestStatus: String, Codable {
    case passed
    case failed
    case error
    case skipped
}

/// Test execution diagnostics and metrics.
public struct TestDiagnostics: Codable {
    /// Total number of test cases.
    public let testCount: Int

    /// Number of passed test cases.
    public let passed: Int

    /// Number of failed test cases.
    public let failed: Int

    /// Number of skipped test cases.
    public let skipped: Int

    /// Total execution duration in seconds (no wall-clock time).
    public let durationSeconds: Double

    public init(
        testCount: Int,
        passed: Int,
        failed: Int,
        skipped: Int,
        durationSeconds: Double
    ) {
        self.testCount = testCount
        self.passed = passed
        self.failed = failed
        self.skipped = skipped
        self.durationSeconds = durationSeconds
    }
}

/// Promotion metadata for archival to curated Docs/proofs.
public struct PromotionMetadata: Codable {
    /// Whether this receipt is eligible for promotion to canonical proofs.
    public let eligible: Bool

    /// Absolute or relative path if promoted; nil otherwise.
    public let promotedTo: String?

    /// Promotion gate type: "manual_review", "ci_gate", or "blocked".
    public let promotionGate: String

    public init(
        eligible: Bool,
        promotedTo: String? = nil,
        promotionGate: String = "manual_review"
    ) {
        self.eligible = eligible
        self.promotedTo = promotedTo
        self.promotionGate = promotionGate
    }
}
