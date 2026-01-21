import Foundation
import DatabaseCore

/// Analyzes codebase maturity and generates improvement suggestions
actor MaturityAnalyzer {
    private let database: CLIDatabase
    private let codeDigestResult: CodebaseDigestResult

    init(database: CLIDatabase, codeDigestResult: CodebaseDigestResult) {
        self.database = database
        self.codeDigestResult = codeDigestResult
    }

    /// Perform comprehensive maturity assessment across all modules
    func analyzeMaturity() async throws -> [MaturityAssessment] {
        var assessments: [MaturityAssessment] = []

        // Assess each key module
        for module in codeDigestResult.keyModules {
            let assessment = try await assessModule(module)
            assessments.append(assessment)
            try await storeAssessment(assessment)
        }

        return assessments
    }

    private func assessModule(_ module: ModuleInfo) async throws -> MaturityAssessment {
        // Gather all dimension assessments
        let dimensions = try await assessAllDimensions(module)

        // Extract build issues
        let warnings = try await getBuildWarnings(module)
        let errors = try await getBuildErrors(module)

        // Calculate overall maturity
        let overallMaturity = calculateOverallMaturity(dimensions)
        let targetMaturity: MaturityLevel = .production

        // Generate improvements
        let improvements = try await generateImprovements(
            module: module,
            dimensions: dimensions,
            warnings: warnings,
            errors: errors
        )

        let summary = generateSummary(
            module: module,
            maturity: overallMaturity,
            improvements: improvements
        )

        return MaturityAssessment(
            module: module.name,
            timestamp: Date(),
            overallMaturity: overallMaturity,
            targetMaturity: targetMaturity,
            dimensions: dimensions,
            improvements: improvements,
            buildWarnings: warnings,
            buildErrors: errors,
            summary: summary
        )
    }

    private func assessAllDimensions(_ module: ModuleInfo) async throws -> [DimensionAssessment] {
        var assessments: [DimensionAssessment] = []

        for dimension in QualityDimension.allCases {
            let assessment = try await assessDimension(dimension, for: module)
            assessments.append(assessment)
        }

        return assessments
    }

    private func assessDimension(_ dimension: QualityDimension, for module: ModuleInfo) async throws -> DimensionAssessment {
        switch dimension {
        case .security:
            return try await assessSecurity(module)
        case .debuggability:
            return try await assessDebuggability(module)
        case .auditability:
            return try await assessAuditability(module)
        case .stability:
            return try await assessStability(module)
        case .concurrency:
            return try await assessConcurrency(module)
        case .errorHandling:
            return try await assessErrorHandling(module)
        case .testCoverage:
            return try await assessTestCoverage(module)
        case .documentation:
            return try await assessDocumentation(module)
        case .performance:
            return try await assessPerformance(module)
        case .maintainability:
            return try await assessMaintainability(module)
        }
    }

    private func assessSecurity(_ module: ModuleInfo) async throws -> DimensionAssessment {
        var findings: [String] = []
        var improvements: [Improvement] = []
        var score = 0.5

        // Check for common security issues
        let hasUnsafeCode = try await checkForUnsafeCode(module)
        if hasUnsafeCode {
            findings.append("Contains unsafe Swift code")
            score -= 0.2
            improvements.append(Improvement(
                id: UUID(),
                title: "Review unsafe code blocks",
                description: "Minimize use of unsafe Swift APIs and add safety documentation",
                dimension: .security,
                impact: .high,
                effort: .medium,
                priority: calculatePriority(impact: .high, effort: .medium),
                codeLocations: [],
                suggestedChanges: [
                    "Replace unsafe pointers with safer alternatives",
                    "Add preconditions and bounds checks",
                    "Document why unsafe code is necessary"
                ],
                dependencies: [],
                status: .suggested
            ))
        }

        let hasInputValidation = try await checkInputValidation(module)
        if !hasInputValidation {
            findings.append("Limited input validation")
            score -= 0.15
            improvements.append(Improvement(
                id: UUID(),
                title: "Add comprehensive input validation",
                description: "Validate all external inputs including file paths, user data, and API responses",
                dimension: .security,
                impact: .high,
                effort: .medium,
                priority: calculatePriority(impact: .high, effort: .medium),
                codeLocations: [],
                suggestedChanges: [
                    "Add validation for file path traversal",
                    "Sanitize user inputs",
                    "Validate API response schemas"
                ],
                dependencies: [],
                status: .suggested
            ))
        }

        let currentLevel = scoreToMaturityLevel(score)

        return DimensionAssessment(
            dimension: .security,
            score: score,
            currentLevel: currentLevel,
            targetLevel: .production,
            findings: findings,
            improvements: improvements
        )
    }

    private func assessErrorHandling(_ module: ModuleInfo) async throws -> DimensionAssessment {
        var findings: [String] = []
        var improvements: [Improvement] = []
        var score = 0.6

        let hasProperErrorTypes = try await checkErrorTypes(module)
        if !hasProperErrorTypes {
            findings.append("Limited custom error types")
            score -= 0.2
            improvements.append(Improvement(
                id: UUID(),
                title: "Define structured error types",
                description: "Create comprehensive error enums for better error handling",
                dimension: .errorHandling,
                impact: .medium,
                effort: .low,
                priority: calculatePriority(impact: .medium, effort: .low),
                codeLocations: [],
                suggestedChanges: [
                    "Create module-specific error enum",
                    "Add context information to errors",
                    "Implement proper error propagation"
                ],
                dependencies: [],
                status: .suggested
            ))
        }

        let hasRecoveryStrategies = try await checkRecoveryStrategies(module)
        if !hasRecoveryStrategies {
            findings.append("No error recovery strategies")
            score -= 0.15
        }

        return DimensionAssessment(
            dimension: .errorHandling,
            score: score,
            currentLevel: scoreToMaturityLevel(score),
            targetLevel: .production,
            findings: findings,
            improvements: improvements
        )
    }

    private func assessTestCoverage(_ module: ModuleInfo) async throws -> DimensionAssessment {
        var findings: [String] = []
        var improvements: [Improvement] = []

        let coverage = module.testCoverage ?? 0.0
        var score = coverage

        if coverage < 0.7 {
            findings.append("Test coverage below 70%: \(String(format: "%.1f%%", coverage * 100))")
            improvements.append(Improvement(
                id: UUID(),
                title: "Increase test coverage",
                description: "Add unit tests to reach at least 70% coverage",
                dimension: .testCoverage,
                impact: .high,
                effort: .high,
                priority: calculatePriority(impact: .high, effort: .high),
                codeLocations: [],
                suggestedChanges: [
                    "Add tests for edge cases",
                    "Test error paths",
                    "Add integration tests"
                ],
                dependencies: [],
                status: .suggested
            ))
        }

        let hasIntegrationTests = module.hasIntegrationTests ?? false
        if !hasIntegrationTests {
            findings.append("No integration tests")
            score -= 0.1
        }

        return DimensionAssessment(
            dimension: .testCoverage,
            score: score,
            currentLevel: scoreToMaturityLevel(score),
            targetLevel: .production,
            findings: findings,
            improvements: improvements
        )
    }

    private func assessConcurrency(_ module: ModuleInfo) async throws -> DimensionAssessment {
        var findings: [String] = []
        var improvements: [Improvement] = []
        var score = 0.7

        let usesModernConcurrency = try await checkSwiftConcurrency(module)
        if !usesModernConcurrency {
            findings.append("Not using Swift concurrency (async/await, actors)")
            score -= 0.2
            improvements.append(Improvement(
                id: UUID(),
                title: "Adopt Swift concurrency",
                description: "Migrate to async/await and actors for better concurrency safety",
                dimension: .concurrency,
                impact: .medium,
                effort: .high,
                priority: calculatePriority(impact: .medium, effort: .high),
                codeLocations: [],
                suggestedChanges: [
                    "Replace DispatchQueue with async/await",
                    "Use actors for shared mutable state",
                    "Add @Sendable conformance where needed"
                ],
                dependencies: [],
                status: .suggested
            ))
        }

        let hasDataRaces = try await checkPotentialDataRaces(module)
        if hasDataRaces {
            findings.append("Potential data race conditions detected")
            score -= 0.3
            improvements.append(Improvement(
                id: UUID(),
                title: "Eliminate data races",
                description: "Fix shared mutable state access issues",
                dimension: .concurrency,
                impact: .critical,
                effort: .medium,
                priority: calculatePriority(impact: .critical, effort: .medium),
                codeLocations: [],
                suggestedChanges: [
                    "Protect shared state with actors",
                    "Use @MainActor for UI updates",
                    "Enable strict concurrency checking"
                ],
                dependencies: [],
                status: .suggested
            ))
        }

        return DimensionAssessment(
            dimension: .concurrency,
            score: score,
            currentLevel: scoreToMaturityLevel(score),
            targetLevel: .production,
            findings: findings,
            improvements: improvements
        )
    }

    private func assessDebuggability(_ module: ModuleInfo) async throws -> DimensionAssessment {
        var findings: [String] = []
        var improvements: [Improvement] = []
        var score = 0.6

        let hasLogging = try await checkLogging(module)
        if !hasLogging {
            findings.append("Insufficient logging")
            score -= 0.2
            improvements.append(Improvement(
                id: UUID(),
                title: "Add structured logging",
                description: "Implement comprehensive logging for debugging",
                dimension: .debuggability,
                impact: .medium,
                effort: .low,
                priority: calculatePriority(impact: .medium, effort: .low),
                codeLocations: [],
                suggestedChanges: [
                    "Use OSLog or similar logging framework",
                    "Log entry/exit of critical paths",
                    "Include context in log messages"
                ],
                dependencies: [],
                status: .suggested
            ))
        }

        return DimensionAssessment(
            dimension: .debuggability,
            score: score,
            currentLevel: scoreToMaturityLevel(score),
            targetLevel: .production,
            findings: findings,
            improvements: improvements
        )
    }

    private func assessAuditability(_ module: ModuleInfo) async throws -> DimensionAssessment {
        var findings: [String] = []
        var improvements: [Improvement] = []
        var score = 0.5

        let hasAuditTrail = try await checkAuditTrail(module)
        if !hasAuditTrail && module.requiresAudit {
            findings.append("No audit trail for sensitive operations")
            score -= 0.3
            improvements.append(Improvement(
                id: UUID(),
                title: "Implement audit logging",
                description: "Track all state changes and security-sensitive operations",
                dimension: .auditability,
                impact: .high,
                effort: .medium,
                priority: calculatePriority(impact: .high, effort: .medium),
                codeLocations: [],
                suggestedChanges: [
                    "Add event logging to database",
                    "Record user actions and timestamps",
                    "Implement tamper-proof audit log"
                ],
                dependencies: [],
                status: .suggested
            ))
        }

        return DimensionAssessment(
            dimension: .auditability,
            score: score,
            currentLevel: scoreToMaturityLevel(score),
            targetLevel: .production,
            findings: findings,
            improvements: improvements
        )
    }

    private func assessStability(_ module: ModuleInfo) async throws -> DimensionAssessment {
        let crashCount = module.knownCrashes ?? 0
        let score = max(0.0, 1.0 - Double(crashCount) * 0.1)

        var findings: [String] = []
        if crashCount > 0 {
            findings.append("\(crashCount) known crash scenarios")
        }

        return DimensionAssessment(
            dimension: .stability,
            score: score,
            currentLevel: scoreToMaturityLevel(score),
            targetLevel: .production,
            findings: findings,
            improvements: []
        )
    }

    private func assessDocumentation(_ module: ModuleInfo) async throws -> DimensionAssessment {
        let coverage = module.documentationCoverage ?? 0.0

        var findings: [String] = []
        var improvements: [Improvement] = []

        if coverage < 0.8 {
            findings.append("Documentation coverage: \(String(format: "%.1f%%", coverage * 100))")
            improvements.append(Improvement(
                id: UUID(),
                title: "Improve documentation",
                description: "Add documentation for public APIs",
                dimension: .documentation,
                impact: .low,
                effort: .medium,
                priority: calculatePriority(impact: .low, effort: .medium),
                codeLocations: [],
                suggestedChanges: [
                    "Document all public functions",
                    "Add usage examples",
                    "Document edge cases and caveats"
                ],
                dependencies: [],
                status: .suggested
            ))
        }

        return DimensionAssessment(
            dimension: .documentation,
            score: coverage,
            currentLevel: scoreToMaturityLevel(coverage),
            targetLevel: .production,
            findings: findings,
            improvements: improvements
        )
    }

    private func assessPerformance(_ module: ModuleInfo) async throws -> DimensionAssessment {
        // Placeholder - would need performance benchmarks
        return DimensionAssessment(
            dimension: .performance,
            score: 0.7,
            currentLevel: .functional,
            targetLevel: .production,
            findings: [],
            improvements: []
        )
    }

    private func assessMaintainability(_ module: ModuleInfo) async throws -> DimensionAssessment {
        let avgFileSize = module.averageFileSize ?? 500
        var score = 0.7

        var findings: [String] = []
        if avgFileSize > 1000 {
            findings.append("Large average file size: \(avgFileSize) lines")
            score -= 0.2
        }

        return DimensionAssessment(
            dimension: .maintainability,
            score: score,
            currentLevel: scoreToMaturityLevel(score),
            targetLevel: .production,
            findings: findings,
            improvements: []
        )
    }

    private func generateImprovements(
        module: ModuleInfo,
        dimensions: [DimensionAssessment],
        warnings: [BuildWarning],
        errors: [BuildError]
    ) async throws -> [Improvement] {
        var allImprovements: [Improvement] = []

        // Collect improvements from all dimensions
        for dimension in dimensions {
            allImprovements.append(contentsOf: dimension.improvements)
        }

        // Generate improvements for build warnings
        for warning in warnings {
            if let improvement = try await improvementFromWarning(warning) {
                allImprovements.append(improvement)
            }
        }

        // Generate improvements for build errors
        for error in errors {
            if let improvement = try await improvementFromError(error) {
                allImprovements.append(improvement)
            }
        }

        // Sort by priority
        return allImprovements.sorted { $0.priority > $1.priority }
    }

    private func improvementFromWarning(_ warning: BuildWarning) async throws -> Improvement? {
        Improvement(
            id: UUID(),
            title: "Fix build warning",
            description: warning.message,
            dimension: .maintainability,
            impact: .low,
            effort: .minimal,
            priority: calculatePriority(impact: .low, effort: .minimal),
            codeLocations: [
                CodeLocation(
                    file: warning.file ?? "",
                    line: warning.line,
                    column: nil,
                    snippet: nil
                )
            ],
            suggestedChanges: warning.suggestedFix.map { [$0] } ?? [],
            dependencies: [],
            status: .suggested
        )
    }

    private func improvementFromError(_ error: BuildError) async throws -> Improvement? {
        Improvement(
            id: UUID(),
            title: "Fix build error",
            description: error.message,
            dimension: .stability,
            impact: .critical,
            effort: .medium,
            priority: calculatePriority(impact: .critical, effort: .medium),
            codeLocations: [
                CodeLocation(
                    file: error.file ?? "",
                    line: error.line,
                    column: nil,
                    snippet: nil
                )
            ],
            suggestedChanges: error.suggestedFix.map { [$0] } ?? [],
            dependencies: [],
            status: .suggested
        )
    }

    private func calculatePriority(impact: ImpactLevel, effort: EffortLevel) -> Int {
        let impactScore: Int = {
            switch impact {
            case .low: return 1
            case .medium: return 3
            case .high: return 5
            case .critical: return 10
            }
        }()

        let effortPenalty: Int = {
            switch effort {
            case .minimal: return 0
            case .low: return 1
            case .medium: return 2
            case .high: return 3
            case .extensive: return 5
            }
        }()

        return impactScore * 10 - effortPenalty
    }

    private func calculateOverallMaturity(_ dimensions: [DimensionAssessment]) -> MaturityLevel {
        let weightedSum = dimensions.reduce(0.0) { sum, dim in
            sum + (dim.score * dim.dimension.weight)
        }
        let totalWeight = dimensions.reduce(0.0) { sum, dim in
            sum + dim.dimension.weight
        }
        let averageScore = weightedSum / totalWeight

        return scoreToMaturityLevel(averageScore)
    }

    private func scoreToMaturityLevel(_ score: Double) -> MaturityLevel {
        switch score {
        case 0..<0.3: return .prototype
        case 0.3..<0.5: return .experimental
        case 0.5..<0.7: return .functional
        case 0.7..<0.85: return .stable
        case 0.85..<0.95: return .production
        default: return .hardened
        }
    }

    private func generateSummary(module: ModuleInfo, maturity: MaturityLevel, improvements: [Improvement]) -> String {
        let criticalCount = improvements.filter { $0.impact == .critical }.count
        let highCount = improvements.filter { $0.impact == .high }.count

        return """
        Module '\(module.name)' is at \(maturity.rawValue) maturity level.
        Found \(improvements.count) improvement suggestions (\(criticalCount) critical, \(highCount) high priority).
        Focus areas: \(improvements.prefix(3).map { $0.dimension.rawValue }.joined(separator: ", "))
        """
    }

    private func getBuildWarnings(_ module: ModuleInfo) async throws -> [BuildWarning] {
        // Would parse from build logs
        return []
    }

    private func getBuildErrors(_ module: ModuleInfo) async throws -> [BuildError] {
        // Would parse from build logs
        return []
    }

    private func storeAssessment(_ assessment: MaturityAssessment) async throws {
        // Store in database for tracking over time
        try await database.storeMaturityAssessment(assessment)
    }

    // Helper checks
    private func checkForUnsafeCode(_ module: ModuleInfo) async throws -> Bool {
        // Would scan for unsafe code patterns
        return false
    }

    private func checkInputValidation(_ module: ModuleInfo) async throws -> Bool {
        return module.hasInputValidation ?? false
    }

    private func checkErrorTypes(_ module: ModuleInfo) async throws -> Bool {
        return module.hasCustomErrorTypes ?? true
    }

    private func checkRecoveryStrategies(_ module: ModuleInfo) async throws -> Bool {
        return false
    }

    private func checkSwiftConcurrency(_ module: ModuleInfo) async throws -> Bool {
        return module.usesSwiftConcurrency ?? false
    }

    private func checkPotentialDataRaces(_ module: ModuleInfo) async throws -> Bool {
        return false
    }

    private func checkLogging(_ module: ModuleInfo) async throws -> Bool {
        return module.hasLogging ?? false
    }

    private func checkAuditTrail(_ module: ModuleInfo) async throws -> Bool {
        return false
    }
}

// Extensions to support maturity analysis
extension ModuleInfo {
    var testCoverage: Double? { nil }
    var hasIntegrationTests: Bool? { nil }
    var requiresAudit: Bool { true }
    var knownCrashes: Int? { nil }
    var documentationCoverage: Double? { nil }
    var averageFileSize: Int? { nil }
    var hasInputValidation: Bool? { nil }
    var hasCustomErrorTypes: Bool? { nil }
    var usesSwiftConcurrency: Bool? { nil }
    var hasLogging: Bool? { nil }
}
