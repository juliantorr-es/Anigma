//
//  DoctrineCommand.swift
//  HarmoniaCLI
//
//  Consolidated doctrine debt observability commands backed by DatabaseCore.
//

import ArgumentParser
import DatabaseCore
import Foundation

// MARK: - Doctrine Command

struct Doctrine: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctrine",
        abstract: "Doctrine debt observability and management",
        subcommands: [
            DoctrineStatus.self,
            DoctrineViolations.self,
            DoctrineRules.self,
            DoctrineResolve.self
        ]
    )
}

// MARK: - Subcommands

struct DoctrineStatus: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show doctrine debt status"
    )

    @Option(name: .shortAndLong, help: "Path to PostgreSQL database")
    var dbPath: String = DatabaseConfiguration.defaultDatabasePath()

    func run() async throws {
        let commands = DoctrineCommands(dbPath: dbPath)
        try await commands.status()
    }
}

struct DoctrineViolations: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "violations",
        abstract: "Show doctrine violations"
    )

    @Option(name: .shortAndLong, help: "Path to PostgreSQL database")
    var dbPath: String = DatabaseConfiguration.defaultDatabasePath()

    @Option(name: .shortAndLong, help: "Maximum number of violations to show")
    var limit: Int = 20

    @Option(name: .shortAndLong, help: "Filter by resolution status")
    var resolved: Bool?

    @Option(name: .shortAndLong, help: "Filter by severity")
    var severity: String?

    @Option(name: .shortAndLong, help: "Filter by rule ID")
    var ruleId: String?

    func run() async throws {
        let commands = DoctrineCommands(dbPath: dbPath)
        try await commands.violations(limit: limit, resolved: resolved, severity: severity, ruleId: ruleId)
    }
}

struct DoctrineRules: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rules",
        abstract: "Show rule statistics"
    )

    @Option(name: .shortAndLong, help: "Path to PostgreSQL database")
    var dbPath: String = DatabaseConfiguration.defaultDatabasePath()

    func run() async throws {
        let commands = DoctrineCommands(dbPath: dbPath)
        try await commands.rules()
    }
}

struct DoctrineResolve: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "resolve",
        abstract: "Mark a violation as resolved"
    )

    @Argument(help: "Violation ID to resolve")
    var violationId: String

    @Argument(help: "Resolution description")
    var resolution: String

    @Option(name: .shortAndLong, help: "Path to PostgreSQL database")
    var dbPath: String = DatabaseConfiguration.defaultDatabasePath()

    func run() async throws {
        let commands = DoctrineCommands(dbPath: dbPath)
        try await commands.resolve(violationId: violationId, resolution: resolution)
    }
}

// MARK: - Core Implementation

/// CLI commands for doctrine debt observability.
struct DoctrineCommands {
    private let db: any DatabaseExecutor

    /// Initializes with a DatabaseExecutor (dependency injection)
    /// Use this from feature modules - composition roots should create the executor and pass it in.
    init(database: any DatabaseExecutor) {
        self.db = database
    }

    /// Legacy initializer for backward compatibility during transition
    /// This should only be used by composition roots.
    @available(*, deprecated, message: "Use init(database:) with DatabaseExecutor from composition root")
    init(dbPath: String = DatabaseConfiguration.defaultDatabasePath()) {
        self.db = DatabaseActor(path: dbPath)
    }

    /// Show doctrine debt status.
    func status() async throws {
        print("📜 Doctrine Debt Status")
        print("======================")

        guard try await Self.isDatabaseInitialized(db) else {
            print("📭 Database not initialized. Run the migration/bootstrapping path first.")
            return
        }

        let violationCounts = try await getViolationCounts()
        print("\n🚫 Doctrine Violations:")
        for (ruleId, count) in violationCounts.sorted(by: { $0.value > $1.value }) {
            print("  • \(ruleId): \(count)")
        }

        let severityCounts = try await getSeverityCounts()
        print("\n⚠️  Violation Severity:")
        for (severity, count) in severityCounts.sorted(by: { $0.value > $1.value }) {
            print("  • \(severity): \(count)")
        }

        let resolutionRate = try await getResolutionRate()
        print("\n✅ Resolution Rate: \(String(format: "%.1f", resolutionRate * 100))%")

        let recentViolations = try await getRecentViolations(limit: 5)
        if !recentViolations.isEmpty {
            print("\n🕐 Recent Violations:")
            for violation in recentViolations {
                print("  • [\(violation.detectedAt)] \(violation.ruleId) - \(violation.severity)")
                if let filePath = violation.filePath {
                    print("    File: \(filePath)")
                }
                if let lineNumber = violation.lineNumber {
                    print("    Line: \(lineNumber)")
                }
                if violation.resolvedAt != nil {
                    print("    ✅ Resolved")
                }
            }
        }

        let topFiles = try await getTopViolatingFiles(limit: 5)
        if !topFiles.isEmpty {
            print("\n📁 Top Violating Files:")
            for file in topFiles {
                print("  • \(file.filePath): \(file.violationCount) violations")
            }
        }

        let ruleStats = try await getRuleStatistics()
        print("\n📊 Rule Statistics:")
        print("  • Total rules: \(ruleStats.totalRules)")
        print("  • Active violations: \(ruleStats.activeViolations)")
        print("  • Resolved violations: \(ruleStats.resolvedViolations)")
        print("  • Most violated rule: \(ruleStats.mostViolatedRule)")
    }

    /// Show detailed violation list.
    func violations(limit: Int = 20, resolved: Bool? = nil, severity: String? = nil, ruleId: String? = nil) async throws {
        print("📋 Doctrine Violations")
        print("=====================")

        var sql = """
        SELECT id, rule_id, file_path, line_number, context, severity, detected_at, metadata, resolved_at, resolution
        FROM doctrine_violations
        WHERE 1=1
        """

        var params: [DatabaseParameter] = []
        if let resolved = resolved {
            sql += resolved ? " AND resolved_at IS NOT NULL" : " AND resolved_at IS NULL"
        }
        if let severity = severity {
            sql += " AND severity = ?"
            params.append(.text(severity))
        }
        if let ruleId = ruleId {
            sql += " AND rule_id = ?"
            params.append(.text(ruleId))
        }

        sql += " ORDER BY detected_at DESC LIMIT ?"
        params.append(.int(limit))

        let rows = try await db.query(sql, parameters: params)
        let violations = rows.map(Self.makeViolation)

        if violations.isEmpty {
            print("📭 No doctrine violations found")
            if resolved != nil || severity != nil || ruleId != nil {
                print("Try removing filters")
            }
            return
        }

        print("Found \(violations.count) violations:")
        for violation in violations {
            print("\n---")
            print("ID: \(violation.id)")
            print("Rule: \(violation.ruleId)")
            print("Severity: \(violation.severity)")
            print("Detected: \(violation.detectedAt)")
            if let filePath = violation.filePath {
                print("File: \(filePath)")
            }
            if let lineNumber = violation.lineNumber {
                print("Line: \(lineNumber)")
            }
            print("Context: \(violation.context)")
            if let metadata = violation.metadata {
                print("Metadata: \(metadata)")
            }
            if let resolvedAt = violation.resolvedAt {
                print("✅ Resolved at: \(resolvedAt)")
                if let resolution = violation.resolution {
                    print("Resolution: \(resolution)")
                }
            } else {
                print("❌ Unresolved")
            }
        }
    }

    /// Show rule statistics.
    func rules() async throws {
        print("📊 Doctrine Rule Statistics")
        print("==========================")

        let rows = try await db.query("""
            SELECT rule_id, violation_count, last_violation, first_violation, resolved_count
            FROM doctrine_rule_stats
            ORDER BY violation_count DESC
            """)

        let rules = rows.map { row in
            RuleStat(
                ruleId: row.string(for: "rule_id") ?? "unknown",
                violationCount: row.int(for: "violation_count") ?? 0,
                resolvedCount: row.int(for: "resolved_count") ?? 0,
                lastViolation: row.string(for: "last_violation"),
                firstViolation: row.string(for: "first_violation")
            )
        }

        if rules.isEmpty {
            print("📭 No rule statistics found")
            return
        }

        print("Rule Statistics:")
        for rule in rules {
            print("\n• \(rule.ruleId):")
            print("  Total violations: \(rule.violationCount)")
            print("  Resolved: \(rule.resolvedCount)")
            print("  Active: \(rule.violationCount - rule.resolvedCount)")
            if let first = rule.firstViolation {
                print("  First violation: \(first)")
            }
            if let last = rule.lastViolation {
                print("  Last violation: \(last)")
            }
        }
    }

    /// Mark a violation as resolved.
    func resolve(violationId: String, resolution: String) async throws {
        print("✅ Resolving violation: \(violationId)")

        let updateRows = try await db.query(
            """
            UPDATE doctrine_violations
            SET resolved_at = CURRENT_TIMESTAMP, resolution = ?
            WHERE id = ? AND resolved_at IS NULL
            RETURNING id
            """,
            parameters: [.text(resolution), .text(violationId)]
        )

        if updateRows.isEmpty {
            print("⚠️  Violation not found or already resolved")
            return
        }

        print("✅ Violation resolved successfully")
        try await updateRuleStats(for: violationId)
    }

    /// Get summary counts for all violations.
    func getSummaryCounts() async throws -> (severity: [String: Int], rules: [String: Int]) {
        let severity = try await getSeverityCounts()
        let rules = try await getViolationCounts()
        return (severity, rules)
    }

    // MARK: - Helper Methods

    func getViolationCounts() async throws -> [String: Int] {
        let rows = try await db.query("""
            SELECT rule_id, COUNT(*)::int AS count
            FROM doctrine_violations
            WHERE resolved_at IS NULL
            GROUP BY rule_id
            ORDER BY count DESC
            """)

        var counts: [String: Int] = [:]
        for row in rows {
            if let ruleId = row.string(for: "rule_id") {
                counts[ruleId] = row.int(for: "count") ?? 0
            }
        }
        return counts
    }

    func getSeverityCounts() async throws -> [String: Int] {
        let rows = try await db.query("""
            SELECT severity, COUNT(*)::int AS count
            FROM doctrine_violations
            WHERE resolved_at IS NULL
            GROUP BY severity
            ORDER BY
                CASE severity
                    WHEN 'critical' THEN 1
                    WHEN 'high' THEN 2
                    WHEN 'medium' THEN 3
                    WHEN 'low' THEN 4
                    ELSE 5
                END
            """)

        var counts: [String: Int] = [:]
        for row in rows {
            if let severity = row.string(for: "severity") {
                counts[severity] = row.int(for: "count") ?? 0
            }
        }
        return counts
    }

    private func getResolutionRate() async throws -> Double {
        let rows = try await db.query("""
            SELECT
                COUNT(*)::int AS total,
                SUM(CASE WHEN resolved_at IS NOT NULL THEN 1 ELSE 0 END)::int AS resolved
            FROM doctrine_violations
            """)

        guard let row = rows.first else {
            return 0
        }

        let total = Double(row.int(for: "total") ?? 0)
        let resolved = Double(row.int(for: "resolved") ?? 0)
        return total > 0 ? resolved / total : 0
    }

    private func getRecentViolations(limit: Int) async throws -> [DoctrineViolation] {
        let rows = try await db.query(
            """
            SELECT id, rule_id, file_path, line_number, context, severity, detected_at, metadata, resolved_at, resolution
            FROM doctrine_violations
            ORDER BY detected_at DESC
            LIMIT ?
            """,
            parameters: [.int(limit)]
        )
        return rows.map(Self.makeViolation)
    }

    private func getTopViolatingFiles(limit: Int) async throws -> [ViolatingFile] {
        let rows = try await db.query(
            """
            SELECT file_path, COUNT(*)::int AS violation_count
            FROM doctrine_violations
            WHERE file_path IS NOT NULL AND resolved_at IS NULL
            GROUP BY file_path
            ORDER BY violation_count DESC
            LIMIT ?
            """,
            parameters: [.int(limit)]
        )

        return rows.compactMap { row in
            guard let filePath = row.string(for: "file_path") else { return nil }
            return ViolatingFile(
                filePath: filePath,
                violationCount: row.int(for: "violation_count") ?? 0
            )
        }
    }

    private func getRuleStatistics() async throws -> RuleStatistics {
        let rows = try await db.query("""
            SELECT
                COUNT(DISTINCT rule_id)::int AS total_rules,
                SUM(CASE WHEN resolved_at IS NULL THEN 1 ELSE 0 END)::int AS active_violations,
                SUM(CASE WHEN resolved_at IS NOT NULL THEN 1 ELSE 0 END)::int AS resolved_violations,
                (
                    SELECT rule_id
                    FROM doctrine_violations
                    WHERE resolved_at IS NULL
                    GROUP BY rule_id
                    ORDER BY COUNT(*) DESC
                    LIMIT 1
                ) AS most_violated_rule
            FROM doctrine_violations
            """)

        guard let row = rows.first else {
            return RuleStatistics(totalRules: 0, activeViolations: 0, resolvedViolations: 0, mostViolatedRule: "none")
        }

        return RuleStatistics(
            totalRules: row.int(for: "total_rules") ?? 0,
            activeViolations: row.int(for: "active_violations") ?? 0,
            resolvedViolations: row.int(for: "resolved_violations") ?? 0,
            mostViolatedRule: row.string(for: "most_violated_rule") ?? "none"
        )
    }

    private func updateRuleStats(for violationId: String) async throws {
        let ruleRows = try await db.query(
            "SELECT rule_id FROM doctrine_violations WHERE id = ?",
            parameters: [.text(violationId)]
        )

        guard let ruleId = ruleRows.first?.string(for: "rule_id") else {
            return
        }

        _ = try await db.executeAsync(
            """
            INSERT INTO doctrine_rule_stats (rule_id, violation_count, resolved_count, last_violation, first_violation)
            SELECT
                ?,
                COUNT(*)::int AS violation_count,
                SUM(CASE WHEN resolved_at IS NOT NULL THEN 1 ELSE 0 END)::int AS resolved_count,
                MAX(detected_at) AS last_violation,
                MIN(detected_at) AS first_violation
            FROM doctrine_violations
            WHERE rule_id = ?
            ON CONFLICT (rule_id) DO UPDATE SET
                violation_count = EXCLUDED.violation_count,
                resolved_count = EXCLUDED.resolved_count,
                last_violation = EXCLUDED.last_violation,
                first_violation = EXCLUDED.first_violation
            """,
            parameters: [.text(ruleId), .text(ruleId)]
        )
    }

    private static func isDatabaseInitialized(_ db: any DatabaseExecutor) async throws -> Bool {
        let rows = try await db.query("""
            SELECT COUNT(*)::int AS count
            FROM information_schema.tables
            WHERE table_name = 'schema_version'
            """)
        return (rows.first?.int(for: "count") ?? 0) > 0
    }

    private static func makeViolation(from row: DatabaseRow) -> DoctrineViolation {
        DoctrineViolation(
            id: row.string(for: "id") ?? "",
            ruleId: row.string(for: "rule_id") ?? "",
            filePath: row.string(for: "file_path"),
            lineNumber: row.int(for: "line_number"),
            context: row.string(for: "context") ?? "",
            severity: row.string(for: "severity") ?? "",
            detectedAt: row.string(for: "detected_at") ?? "",
            metadata: row.string(for: "metadata"),
            resolvedAt: row.string(for: "resolved_at"),
            resolution: row.string(for: "resolution")
        )
    }
}

// MARK: - Data Structures

private struct DoctrineViolation {
    let id: String
    let ruleId: String
    let filePath: String?
    let lineNumber: Int?
    let context: String
    let severity: String
    let detectedAt: String
    let metadata: String?
    let resolvedAt: String?
    let resolution: String?
}

private struct ViolatingFile {
    let filePath: String
    let violationCount: Int
}

private struct RuleStat {
    let ruleId: String
    let violationCount: Int
    let resolvedCount: Int
    let lastViolation: String?
    let firstViolation: String?
}

private struct RuleStatistics {
    let totalRules: Int
    let activeViolations: Int
    let resolvedViolations: Int
    let mostViolatedRule: String
}
