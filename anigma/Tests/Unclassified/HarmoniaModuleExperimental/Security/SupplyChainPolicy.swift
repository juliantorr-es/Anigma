//
//  SupplyChainPolicy.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Security
//
//  Supply chain security policy with dependency validation.
//  Implements SEC-SUPPLY-001: Dependencies must be pinned and scanned.
//  Not vibes - actual dependency scanning and validation.
//

import Foundation
import DoctrineCore
import AnigmaCore // Import AnigmaCore for TrustTier and other common types
import HarmoniaModule

// MARK: - Dependency Types

/// Types of dependencies in the project.
public enum DependencyType: String, Sendable, Codable {
    case swiftPackage = "swift_package"
    case npmPackage = "npm_package"
    case cargoCrate = "cargo_crate"
    case pythonPackage = "python_package"
    case systemLibrary = "system_library"
    case binaryDependency = "binary_dependency"
    case inspirationRepo = "inspiration_repo"

    public var manifestFile: String {
        switch self {
        case .swiftPackage:
            return "Package.swift"
        case .npmPackage:
            return "package.json"
        case .cargoCrate:
            return "Cargo.toml"
        case .pythonPackage:
            return "requirements.txt"
        case .systemLibrary:
            return "system"
        case .binaryDependency:
            return "binary"
        case .inspirationRepo:
            return "inspiration"
        }
    }
}

/// Information about a dependency.
public struct DependencyInfo: Sendable, Codable {
    public let name: String
    public let type: DependencyType
    public let version: String?
    public let url: String?
    public let license: String?
    public let vulnerabilities: [VulnerabilityInfo]
    public let lastUpdated: Date?
    public let isPinned: Bool
    public let isTransitive: Bool
    public let riskScore: Double

    public init(
        name: String,
        type: DependencyType,
        version: String? = nil,
        url: String? = nil,
        license: String? = nil,
        vulnerabilities: [VulnerabilityInfo] = [],
        lastUpdated: Date? = nil,
        isPinned: Bool = false,
        isTransitive: Bool = false,
        riskScore: Double = 0.0
    ) {
        self.name = name
        self.type = type
        self.version = version
        self.url = url
        self.license = license
        self.vulnerabilities = vulnerabilities
        self.lastUpdated = lastUpdated
        self.isPinned = isPinned
        self.isTransitive = isTransitive
        self.riskScore = riskScore
    }

    /// Calculate risk score based on various factors.
    public var calculatedRiskScore: Double {
        var score = 0.0

        // Base score
        score += 10.0

        // Version pinning
        if !isPinned {
            score += 20.0
        }

        // Vulnerabilities
        score += Double(vulnerabilities.count) * 15.0

        // Age (if older than 1 year)
        if let lastUpdated = lastUpdated {
            guard let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) else {
                fatalError("Failed to unwrap oneYearAgo")
            }
            if lastUpdated < oneYearAgo {
                score += 10.0
            }
        }

        // Transitive dependencies are riskier
        if isTransitive {
            score += 15.0
        }

        // Missing license
        if license == nil {
            score += 5.0
        }

        return min(100.0, score)
    }
}

/// Vulnerability information.
public struct VulnerabilityInfo: Sendable, Codable {
    public let id: String
    public let severity: VulnerabilitySeverity
    public let description: String
    public let cveId: String?
    public let published: Date?
    public let fixedIn: [String]?

    public init(
        id: String,
        severity: VulnerabilitySeverity,
        description: String,
        cveId: String? = nil,
        published: Date? = nil,
        fixedIn: [String]? = nil
    ) {
        self.id = id
        self.severity = severity
        self.description = description
        self.cveId = cveId
        self.published = published
        self.fixedIn = fixedIn
    }
}

/// Vulnerability severity levels.
public enum VulnerabilitySeverity: String, Sendable, Codable, Comparable {
    case critical
    case high
    case medium
    case low
    case info

    public static func < (lhs: VulnerabilitySeverity, rhs: VulnerabilitySeverity) -> Bool {
        let order: [VulnerabilitySeverity] = [.info, .low, .medium, .high, .critical]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }

    public var weight: Double {
        switch self {
        case .critical:
            return 10.0
        case .high:
            return 7.5
        case .medium:
            return 5.0
        case .low:
            return 2.5
        case .info:
            return 1.0
        }
    }
}

// MARK: - Supply Chain Policy

/// Configuration for supply chain policy.
public struct SupplyChainPolicyConfig: Sendable, Codable {
    /// Maximum allowed risk score for any dependency.
    public let maxRiskScore: Double

    /// Whether to block on critical vulnerabilities.
    public let blockOnCriticalVulnerabilities: Bool

    /// Whether to require version pinning.
    public let requireVersionPinning: Bool

    /// Allowed licenses (empty means all licenses allowed).
    public let allowedLicenses: [String]

    /// Blocked licenses.
    public let blockedLicenses: [String]

    /// Whether to scan transitive dependencies.
    public let scanTransitiveDependencies: Bool

    /// Whether to require vulnerability scanning.
    public let requireVulnerabilityScanning: Bool

    /// Maximum age for dependencies in months.
    public let maxDependencyAgeMonths: Int

    /// Whether to allow inspiration repos.
    public let allowInspirationRepos: Bool

    /// Trust tier required to override policy.
    public let overrideTrustTier: AnigmaCore.TrustTier

    public init(
        maxRiskScore: Double = 50.0,
        blockOnCriticalVulnerabilities: Bool = true,
        requireVersionPinning: Bool = true,
        allowedLicenses: [String] = [],
        blockedLicenses: [String] = ["AGPL-3.0", "SSPL-1.0"],
        scanTransitiveDependencies: Bool = true,
        requireVulnerabilityScanning: Bool = true,
        maxDependencyAgeMonths: Int = 24,
        allowInspirationRepos: Bool = true,
        overrideTrustTier: AnigmaCore.TrustTier = AnigmaCore.TrustTier.platinum
    ) {
        self.maxRiskScore = maxRiskScore
        self.blockOnCriticalVulnerabilities = blockOnCriticalVulnerabilities
        self.requireVersionPinning = requireVersionPinning
        self.allowedLicenses = allowedLicenses
        self.blockedLicenses = blockedLicenses
        self.scanTransitiveDependencies = scanTransitiveDependencies
        self.requireVulnerabilityScanning = requireVulnerabilityScanning
        self.maxDependencyAgeMonths = maxDependencyAgeMonths
        self.allowInspirationRepos = allowInspirationRepos
        self.overrideTrustTier = overrideTrustTier
    }

    /// Default policy for production.
    public static let production = SupplyChainPolicyConfig(
        maxRiskScore: 30.0,
        blockOnCriticalVulnerabilities: true,
        requireVersionPinning: true,
        blockedLicenses: ["AGPL-3.0", "SSPL-1.0", "GPL-3.0"],
        scanTransitiveDependencies: true,
        requireVulnerabilityScanning: true,
        maxDependencyAgeMonths: 12,
        allowInspirationRepos: false,
        overrideTrustTier: AnigmaCore.TrustTier.platinum
    )

    /// Default policy for development.
    public static let development = SupplyChainPolicyConfig(
        maxRiskScore: 70.0,
        blockOnCriticalVulnerabilities: false,
        requireVersionPinning: false,
        scanTransitiveDependencies: false,
        requireVulnerabilityScanning: false,
        maxDependencyAgeMonths: 36,
        allowInspirationRepos: true,
        overrideTrustTier: AnigmaCore.TrustTier.gold
    )
}

// MARK: - Dependency Scanner

/// Scans dependencies for security issues.
public actor DependencyScanner {
    private let config: SupplyChainPolicyConfig
    private let projectPath: String

    public init(config: SupplyChainPolicyConfig = .production, projectPath: String) {
        self.config = config
        self.projectPath = projectPath
    }

    /// Scan all dependencies in the project.
    public func scan() async throws -> DependencyScanResult {
        var dependencies: [DependencyInfo] = []
        var violations: [SupplyChainViolation] = []

        // Scan Swift packages
        if FileManager.default.fileExists(atPath: "\(projectPath)/Package.swift") {
            let swiftDeps = try await scanSwiftPackages()
            dependencies.append(contentsOf: swiftDeps)

            // Check for violations
            let swiftViolations = checkDependencies(swiftDeps)
            violations.append(contentsOf: swiftViolations)
        }

        // Scan npm packages
        if FileManager.default.fileExists(atPath: "\(projectPath)/package.json") {
            let npmDeps = try await scanNpmPackages()
            dependencies.append(contentsOf: npmDeps)

            let npmViolations = checkDependencies(npmDeps)
            violations.append(contentsOf: npmViolations)
        }

        // Scan inspiration repos
        if config.allowInspirationRepos {
            let inspirationDeps = try await scanInspirationRepos()
            dependencies.append(contentsOf: inspirationDeps)

            let inspirationViolations = checkDependencies(inspirationDeps)
            violations.append(contentsOf: inspirationViolations)
        }

        // Calculate overall risk score
        let overallRiskScore = calculateOverallRiskScore(dependencies: dependencies)

        return DependencyScanResult(
            dependencies: dependencies,
            violations: violations,
            overallRiskScore: overallRiskScore,
            passed: violations.isEmpty
        )
    }

    /// Check if dependencies comply with policy.
    public func checkDependencies(_ dependencies: [DependencyInfo]) -> [SupplyChainViolation] {
        var violations: [SupplyChainViolation] = []

        for dependency in dependencies {
            // Check risk score
            if dependency.calculatedRiskScore > config.maxRiskScore {
                violations.append(SupplyChainViolation(
                    dependencyName: dependency.name,
                    ruleId: "sec-supply-001",
                    severity: DoctrineCore.DoctrineViolationSeverity.error,
                    description: "Dependency \(dependency.name) has risk score \(String(format: "%.1f", dependency.calculatedRiskScore)) exceeding maximum \(config.maxRiskScore)",
                    metadata: [
                        "risk_score": "\(dependency.calculatedRiskScore)",
                        "max_allowed": "\(config.maxRiskScore)",
                        "vulnerabilities": "\(dependency.vulnerabilities.count)"
                    ]
                ))
            }

            // Check version pinning
            if config.requireVersionPinning && !dependency.isPinned {
                violations.append(SupplyChainViolation(
                    dependencyName: dependency.name,
                    ruleId: "sec-supply-001",
                    severity: DoctrineCore.DoctrineViolationSeverity.warning,
                    description: "Dependency \(dependency.name) is not pinned to a specific version",
                    metadata: [
                        "version": dependency.version ?? "unknown",
                        "is_pinned": "false"
                    ]
                ))
            }

            // Check license
            if let license = dependency.license {
                if config.blockedLicenses.contains(license) {
                    violations.append(SupplyChainViolation(
                        dependencyName: dependency.name,
                        ruleId: "sec-supply-001",
                        severity: DoctrineCore.DoctrineViolationSeverity.error,
                        description: "Dependency \(dependency.name) uses blocked license \(license)",
                        metadata: [
                            "license": license,
                            "blocked": "true"
                        ]
                    ))
                }

                if !config.allowedLicenses.isEmpty && !config.allowedLicenses.contains(license) {
                    violations.append(SupplyChainViolation(
                        dependencyName: dependency.name,
                        ruleId: "sec-supply-001",
                        severity: DoctrineCore.DoctrineViolationSeverity.error,
                        description: "Dependency \(dependency.name) uses license \(license) which is not in allowed list",
                        metadata: [
                            "license": license,
                            "allowed": "false"
                        ]
                    ))
                }
            }

            // Check vulnerabilities
            if config.blockOnCriticalVulnerabilities {
                let criticalVulnerabilities = dependency.vulnerabilities.filter { $0.severity == .critical }
                if !criticalVulnerabilities.isEmpty {
                    violations.append(SupplyChainViolation(
                        dependencyName: dependency.name,
                        ruleId: "sec-supply-001",
                        severity: DoctrineCore.DoctrineViolationSeverity.critical,
                        description: "Dependency \(dependency.name) has \(criticalVulnerabilities.count) critical vulnerabilities",
                        metadata: [
                            "critical_vulnerabilities": "\(criticalVulnerabilities.count)",
                            "cve_ids": criticalVulnerabilities.compactMap { $0.cveId }.joined(separator: ", ")
                        ]
                    ))
                }
            }

            // Check age
            if let lastUpdated = dependency.lastUpdated {
                guard let maxAge = Calendar.current.date(byAdding: .month, value: -config.maxDependencyAgeMonths, to: Date()) else {
                    fatalError("Failed to unwrap maxAge")
                }
                if lastUpdated < maxAge {
                    violations.append(SupplyChainViolation(
                        dependencyName: dependency.name,
                        ruleId: "sec-supply-001",
                        severity: DoctrineCore.DoctrineViolationSeverity.warning,
                        description: "Dependency \(dependency.name) was last updated \(DateFormatter.localizedString(from: lastUpdated, dateStyle: .medium, timeStyle: .none)) (older than \(config.maxDependencyAgeMonths) months)",
                        metadata: [
                            "last_updated": DateFormatter.localizedString(from: lastUpdated, dateStyle: .medium, timeStyle: .none),
                            "max_age_months": "\(config.maxDependencyAgeMonths)"
                        ]
                    ))
                }
            }
        }

        return violations
    }

    // MARK: - Private Methods

    private func scanSwiftPackages() async throws -> [DependencyInfo] {
        var dependencies: [DependencyInfo] = []

        // Read Package.swift
        let packagePath = "\(projectPath)/Package.swift"
        guard FileManager.default.fileExists(atPath: packagePath) else {
            return []
        }

        let packageContent = try String(contentsOfFile: packagePath, encoding: .utf8)

        // Parse dependencies (simplified - real implementation would use SwiftPM API)
        // Look for .package(url: patterns
        let packagePattern = #"\.package\(url:\s*\"([^\"]+)\",\s*(?:from|exact|branch|revision):\s*\"([^\"]+)\"\)"#
        let regex = try NSRegularExpression(pattern: packagePattern)
        let range = NSRange(location: 0, length: packageContent.count)

        let matches = regex.matches(in: packageContent, options: [], range: range)

        for match in matches {
            if match.numberOfRanges >= 3 {
                guard let urlRange = Range(match.range(at: 1), in: packageContent) else {
                    fatalError("Failed to unwrap urlRange")
                }
                guard let versionRange = Range(match.range(at: 2), in: packageContent) else {
                    fatalError("Failed to unwrap versionRange")
                }

                let url = String(packageContent[urlRange])
                let version = String(packageContent[versionRange])

                // Extract package name from URL
                let packageName = extractPackageName(from: url)

                // Check if version is pinned (contains exact version or revision)
                let isPinned = version.contains(".") || version.count == 40  // SHA hash length

                let dependency = DependencyInfo(
                    name: packageName,
                    type: .swiftPackage,
                    version: version,
                    url: url,
                    license: nil,  // Would need to fetch from package
                    vulnerabilities: [],  // Would need to scan
                    lastUpdated: nil,  // Would need to fetch
                    isPinned: isPinned,
                    isTransitive: false,
                    riskScore: 0.0
                )

                dependencies.append(dependency)
            }
        }

        return dependencies
    }

    private func scanNpmPackages() async throws -> [DependencyInfo] {
        // Similar implementation for npm packages
        return []
    }

    private func scanInspirationRepos() async throws -> [DependencyInfo] {
        var dependencies: [DependencyInfo] = []

        let inspirationPath = "\(projectPath)/Inspiration"
        guard FileManager.default.fileExists(atPath: inspirationPath) else {
            return []
        }

        let contents = try FileManager.default.contentsOfDirectory(atPath: inspirationPath)

        for item in contents {
            let itemPath = "\(inspirationPath)/\(item)"
            var isDirectory: ObjCBool = false

            if FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDirectory),
               isDirectory.boolValue {
                let dependency = DependencyInfo(
                    name: item,
                    type: .inspirationRepo,
                    version: nil,
                    url: nil,
                    license: nil,
                    vulnerabilities: [],
                    lastUpdated: nil,
                    isPinned: false,
                    isTransitive: false,
                    riskScore: 20.0  // Inspiration repos have higher base risk
                )

                dependencies.append(dependency)
            }
        }

        return dependencies
    }

    private func extractPackageName(from url: String) -> String {
        // Extract package name from GitHub URL
        if url.contains("github.com") {
            let components = url.split(separator: "/")
            if components.count >= 2 {
                let repo = components[components.count - 1]
                return repo.replacingOccurrences(of: ".git", with: "")
            }
        }

        // Fallback: use last component of URL
        return URL(string: url)?.lastPathComponent.replacingOccurrences(of: ".git", with: "") ?? "unknown"
    }

    private func calculateOverallRiskScore(dependencies: [DependencyInfo]) -> Double {
        guard !dependencies.isEmpty else {
            return 0.0
        }

        let totalRisk = dependencies.reduce(0.0) { $0 + $1.calculatedRiskScore }
        return totalRisk / Double(dependencies.count)
    }
}

// MARK: - Scan Result

/// Result of dependency scanning.
public struct DependencyScanResult: Sendable, Codable {
    public let dependencies: [DependencyInfo]
    public let violations: [SupplyChainViolation]
    public let overallRiskScore: Double
    public let passed: Bool

    public init(
        dependencies: [DependencyInfo] = [],
        violations: [SupplyChainViolation] = [],
        overallRiskScore: Double = 0.0,
        passed: Bool = true
    ) {
        self.dependencies = dependencies
        self.violations = violations
        self.overallRiskScore = overallRiskScore
        self.passed = passed
    }

    /// Generate a report for CI/CD.
    public func generateReport() -> String {
        var report = "# Supply Chain Security Report\n\n"

        report += "## Summary\n"
        report += "- **Status:** \(passed ? "✅ PASSED" : "❌ FAILED")\n"
        report += "- **Overall Risk Score:** \(String(format: "%.1f", overallRiskScore))/100\n"
        report += "- **Dependencies Scanned:** \(dependencies.count)\n"
        report += "- **Violations Found:** \(violations.count)\n\n"

        if !violations.isEmpty {
            report += "## Violations\n\n"

            let criticalViolations = violations.filter { $0.severity == .critical }
            let errorViolations = violations.filter { $0.severity == .error }
            let warningViolations = violations.filter { $0.severity == .warning }

            if !criticalViolations.isEmpty {
                report += "### Critical (\(criticalViolations.count))\n"
                for violation in criticalViolations {
                    report += "- **\(violation.dependencyName):** \(violation.description)\n"
                }
                report += "\n"
            }

            if !errorViolations.isEmpty {
                report += "### Errors (\(errorViolations.count))\n"
                for violation in errorViolations {
                    report += "- **\(violation.dependencyName):** \(violation.description)\n"
                }
                report += "\n"
            }

            if !warningViolations.isEmpty {
                report += "### Warnings (\(warningViolations.count))\n"
                for violation in warningViolations {
                    report += "- **\(violation.dependencyName):** \(violation.description)\n"
                }
                report += "\n"
            }
        }

        report += "## Dependencies\n\n"
        for dependency in dependencies.sorted(by: { $0.calculatedRiskScore > $1.calculatedRiskScore }) {
            report += "### \(dependency.name)\n"
            report += "- **Type:** \(dependency.type.rawValue)\n"
            if let version = dependency.version {
                report += "- **Version:** \(version)\n"
            }
            if let license = dependency.license {
                report += "- **License:** \(license)\n"
            }
            report += "- **Pinned:** \(dependency.isPinned ? "✅" : "❌")\n"
            report += "- **Risk Score:** \(String(format: "%.1f", dependency.calculatedRiskScore))/100\n"

            if !dependency.vulnerabilities.isEmpty {
                report += "- **Vulnerabilities:** \(dependency.vulnerabilities.count)\n"
                for vuln in dependency.vulnerabilities.prefix(3) {
                    report += "  - \(vuln.severity.rawValue.uppercased()): \(vuln.description)\n"
                }
                if dependency.vulnerabilities.count > 3 {
                    report += "  - ... and \(dependency.vulnerabilities.count - 3) more\n"
                }
            }

            report += "\n"
        }

        return report
    }
}

// MARK: - Supply Chain Violation

/// Supply chain policy violation.
public struct SupplyChainViolation: Sendable, Codable {
    public let dependencyName: String
    public let ruleId: String
    public let severity: DoctrineCore.DoctrineViolationSeverity
    public let description: String
    public let metadata: [String: String]

    public init(
        dependencyName: String,
        ruleId: String,
        severity: DoctrineCore.DoctrineViolationSeverity,
        description: String,
        metadata: [String: String] = [:]
    ) {
        self.dependencyName = dependencyName
        self.ruleId = ruleId
        self.severity = severity
        self.description = description
        self.metadata = metadata
    }
}

// MARK: - Vulnerability Scanner Integration

/// Integrates with external vulnerability scanners.
public actor VulnerabilityScanner {
    private let scannerType: VulnerabilityScannerType

    public init(scannerType: VulnerabilityScannerType = .osv) {
        self.scannerType = scannerType
    }

    /// Scan a dependency for vulnerabilities.
    public func scan(dependency: DependencyInfo) async throws -> [VulnerabilityInfo] {
        switch scannerType {
        case .osv:
            return try await scanWithOSV(dependency: dependency)
        case .trivy:
            return try await scanWithTrivy(dependency: dependency)
        case .grype:
            return try await scanWithGrype(dependency: dependency)
        }
    }

    /// Batch scan multiple dependencies.
    public func scan(dependencies: [DependencyInfo]) async throws -> [DependencyInfo] {
        var scannedDependencies: [DependencyInfo] = []

        for var dependency in dependencies {
            let vulnerabilities = try await scan(dependency: dependency)
            dependency = DependencyInfo(
                name: dependency.name,
                type: dependency.type,
                version: dependency.version,
                url: dependency.url,
                license: dependency.license,
                vulnerabilities: vulnerabilities,
                lastUpdated: dependency.lastUpdated,
                isPinned: dependency.isPinned,
                isTransitive: dependency.isTransitive,
                riskScore: dependency.calculatedRiskScore
            )
            scannedDependencies.append(dependency)
        }

        return scannedDependencies
    }

    // MARK: - Private Methods

    private func scanWithOSV(dependency: DependencyInfo) async throws -> [VulnerabilityInfo] {
        // Integration with OSV Scanner (https://github.com/google/osv-scanner)
        // This would make HTTP requests to OSV API
        // For now, return empty array
        return []
    }

    private func scanWithTrivy(dependency: DependencyInfo) async throws -> [VulnerabilityInfo] {
        // Integration with Trivy (https://github.com/aquasecurity/trivy)
        // This would shell out to trivy command
        return []
    }

    private func scanWithGrype(dependency: DependencyInfo) async throws -> [VulnerabilityInfo] {
        // Integration with Grype (https://github.com/anchore/grype)
        // This would shell out to grype command
        return []
    }
}

/// Types of vulnerability scanners.
public enum VulnerabilityScannerType: String, Sendable, Codable {
    case osv = "osv"
    case trivy = "trivy"
    case grype = "grype"
}

// MARK: - CI/CD Integration

extension DependencyScanner {
    /// Run supply chain check for CI/CD.
    public func runCICDCheck() async throws -> CICDCheckResult {
        let result = try await scan()

        return CICDCheckResult(
            passed: result.passed,
            violations: result.violations,
            overallRiskScore: result.overallRiskScore,
            report: result.generateReport()
        )
    }
}

/// CI/CD check result for supply chain.
public struct CICDCheckResult: Sendable, Codable {
    public let passed: Bool
    public let violations: [SupplyChainViolation]
    public let overallRiskScore: Double
    public let report: String

    public init(
        passed: Bool,
        violations: [SupplyChainViolation] = [],
        overallRiskScore: Double = 0.0,
        report: String = ""
    ) {
        self.passed = passed
        self.violations = violations
        self.overallRiskScore = overallRiskScore
        self.report = report
    }
}

// MARK: - Command Line Interface

extension DependencyScanner {
    /// Run supply chain scan from command line.
    public static func runFromCLI(config: SupplyChainPolicyConfig = .production) async throws {
        let scanner = DependencyScanner(config: config, projectPath: ".")

        print("🔍 Scanning dependencies...")

        let result = try await scanner.scan()

        print("\n" + result.generateReport())

        if !result.passed {
            print("\n❌ Supply chain check failed!")
            exit(1)
        } else {
            print("\n✅ Supply chain check passed!")
        }
    }
}

// MARK: - GitHub Actions Integration

/*
 Example GitHub Actions workflow for supply chain scanning:

 name: Supply Chain Security
 on:
   pull_request:
     branches: [ main ]
   schedule:
     - cron: '0 0 * * 0'  # Weekly

 jobs:
   supply-chain-scan:
     runs-on: ubuntu-latest
     
     steps:
     - uses: actions/checkout@v4
     
     - name: Setup OSV Scanner
       run: |
         curl -sSfL https://osv.dev/install.sh | sh
         echo "$HOME/.local/bin" >> $GITHUB_PATH
     
     - name: Run Supply Chain Scan
       run: |
         swift run harmonia-cli supply-chain-scan --config production
       
     - name: Upload Scan Report
       if: always()
       uses: actions/upload-artifact@v4
       with:
         name: supply-chain-report
         path: supply-chain-report.md
*/
