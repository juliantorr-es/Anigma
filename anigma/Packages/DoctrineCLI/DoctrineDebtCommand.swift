//
//  DoctrineDebtCommand.swift
//  DoctrineCLI
//
//  HarmoniaModule/Doctrine
//
//  CLI command for doctrine debt observability.
//

import Foundation
import ArgumentParser
import SQLite3
import HarmoniaModule

/// CLI commands for doctrine debt observability.
public struct DoctrineCommands {
    private let dbPath: String

    public init(dbPath: String = "./harmonia_harness.sqlite") {
        self.dbPath = dbPath
    }

    /// Show doctrine debt status.
    public func status() throws {
        print("📜 Doctrine Debt Status")
        print("======================")

        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to open database: \(errMsg)")
            return
        }
        defer { sqlite3_close(db) }

        // Check if database is initialized
        if !DatabaseInitializer.isDatabaseInitialized(at: dbPath) {
            print("📭 Database not initialized. Run 'harmonia security init' first.")
            return
        }

        // Get violation counts
        let violationCounts = try getViolationCounts(db: db)
        print("\n🚫 Doctrine Violations:")
        for (ruleId, count) in violationCounts.sorted(by: { $0.value > $1.value }) {
            print("  • \(ruleId): \(count)")
        }

        // Get severity breakdown
        let severityCounts = try getSeverityCounts(db: db)
        print("\n⚠️  Violation Severity:")
        for (severity, count) in severityCounts.sorted(by: { $0.value > $1.value }) {
            print("  • \(severity): \(count)")
        }

        // Get resolution rate
        let resolutionRate = try getResolutionRate(db: db)
        print("\n✅ Resolution Rate: \(String(format: "%.1f", resolutionRate * 100))%")

        // Get recent violations
        let recentViolations = try getRecentViolations(db: db, limit: 5)
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

        // Get top violating files
        let topFiles = try getTopViolatingFiles(db: db, limit: 5)
        if !topFiles.isEmpty {
            print("\n📁 Top Violating Files:")
            for file in topFiles {
                print("  • \(file.filePath): \(file.violationCount) violations")
            }
        }

        // Get rule statistics
        let ruleStats = try getRuleStatistics(db: db)
        print("\n📊 Rule Statistics:")
        print("  • Total rules: \(ruleStats.totalRules)")
        print("  • Active violations: \(ruleStats.activeViolations)")
        print("  • Resolved violations: \(ruleStats.resolvedViolations)")
        print("  • Most violated rule: \(ruleStats.mostViolatedRule)")
    }

    /// Show detailed violation list.
    public func violations(limit: Int = 20, resolved: Bool? = nil, severity: String? = nil, ruleId: String? = nil) throws {
        print("📋 Doctrine Violations")
        print("=====================")

        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to open database: \(errMsg)")
            return
        }
        defer { sqlite3_close(db) }

        var sql = """
        SELECT id, rule_id, file_path, line_number, context, severity, detected_at, metadata, resolved_at, resolution
        FROM doctrine_violations
        WHERE 1=1
        """

        var params: [String] = []
        if let resolved = resolved {
            if resolved {
                sql += " AND resolved_at IS NOT NULL"
            } else {
                sql += " AND resolved_at IS NULL"
            }
        }
        if let severity = severity {
            sql += " AND severity = ?"
            params.append(severity)
        }
        if let ruleId = ruleId {
            sql += " AND rule_id = ?"
            params.append(ruleId)
        }

        sql += " ORDER BY detected_at DESC LIMIT ?"
        params.append(String(limit))

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to prepare query: \(errMsg)")
            return
        }
        defer { sqlite3_finalize(stmt) }

        // Bind parameters
        for (index, param) in params.enumerated() {
            sqlite3_bind_text(stmt, Int32(index + 1), param, -1, sqliteTransientDestructor)
        }

        var violations: [DoctrineViolation] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(stmt, 0))
            let ruleId = String(cString: sqlite3_column_text(stmt, 1))
            let filePath = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
            let lineNumber = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil : Int(sqlite3_column_int64(stmt, 3))
            let context = String(cString: sqlite3_column_text(stmt, 4))
            let severity = String(cString: sqlite3_column_text(stmt, 5))
            let detectedAt = String(cString: sqlite3_column_text(stmt, 6))
            let metadata = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
            let resolvedAt = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
            let resolution = sqlite3_column_text(stmt, 9).map { String(cString: $0) }

            violations.append(DoctrineViolation(
                id: id,
                ruleId: ruleId,
                filePath: filePath,
                lineNumber: lineNumber,
                context: context,
                severity: severity,
                detectedAt: detectedAt,
                metadata: metadata,
                resolvedAt: resolvedAt,
                resolution: resolution
            ))
        }

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
    public func rules() throws {
        print("📊 Doctrine Rule Statistics")
        print("==========================")

        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to open database: \(errMsg)")
            return
        }
        defer { sqlite3_close(db) }

        let sql = """
        SELECT rule_id, violation_count, last_violation, first_violation, resolved_count
        FROM doctrine_rule_stats
        ORDER BY violation_count DESC
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to prepare query: \(errMsg)")
            return
        }
        defer { sqlite3_finalize(stmt) }

        var rules: [RuleStat] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let ruleId = String(cString: sqlite3_column_text(stmt, 0))
            let violationCount = Int(sqlite3_column_int64(stmt, 1))
            let lastViolation = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
            let firstViolation = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
            let resolvedCount = Int(sqlite3_column_int64(stmt, 4))

            rules.append(RuleStat(
                ruleId: ruleId,
                violationCount: violationCount,
                resolvedCount: resolvedCount,
                lastViolation: lastViolation,
                firstViolation: firstViolation
            ))
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
    public func resolve(violationId: String, resolution: String) throws {
        print("✅ Resolving violation: \(violationId)")

        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to open database: \(errMsg)")
            return
        }
        defer { sqlite3_close(db) }

        let sql = """
        UPDATE doctrine_violations
        SET resolved_at = CURRENT_TIMESTAMP, resolution = ?
        WHERE id = ? AND resolved_at IS NULL
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to prepare query: \(errMsg)")
            return
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, resolution, -1, sqliteTransientDestructor)
        sqlite3_bind_text(stmt, 2, violationId, -1, sqliteTransientDestructor)

        if sqlite3_step(stmt) != SQLITE_DONE {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to resolve violation: \(errMsg)")
            return
        }

        let changes = sqlite3_changes(db)
        if changes > 0 {
            print("✅ Violation resolved successfully")

            // Update rule stats
            try updateRuleStats(db: db, for: violationId)
        } else {
            print("⚠️  Violation not found or already resolved")
        }
    }

    // MARK: - Helper Methods

    private func getViolationCounts(db: OpaquePointer?) throws -> [String: Int] {
        let sql = """
        SELECT rule_id, COUNT(*) as count
        FROM doctrine_violations
        WHERE resolved_at IS NULL
        GROUP BY rule_id
        ORDER BY count DESC
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "DoctrineCommands", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get violation counts: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        var counts: [String: Int] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let ruleId = String(cString: sqlite3_column_text(stmt, 0))
            let count = Int(sqlite3_column_int64(stmt, 1))
            counts[ruleId] = count
        }

        return counts
    }

    private func getSeverityCounts(db: OpaquePointer?) throws -> [String: Int] {
        let sql = """
        SELECT severity, COUNT(*) as count
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
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "DoctrineCommands", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get severity counts: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        var counts: [String: Int] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let severity = String(cString: sqlite3_column_text(stmt, 0))
            let count = Int(sqlite3_column_int64(stmt, 1))
            counts[severity] = count
        }

        return counts
    }

    private func getResolutionRate(db: OpaquePointer?) throws -> Double {
        let sql = """
        SELECT
            COUNT(*) as total,
            SUM(CASE WHEN resolved_at IS NOT NULL THEN 1 ELSE 0 END) as resolved
        FROM doctrine_violations
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "DoctrineCommands", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to get resolution rate: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            let total = Double(sqlite3_column_int64(stmt, 0))
            let resolved = Double(sqlite3_column_int64(stmt, 1))

            if total > 0 {
                return resolved / total
            }
        }

        return 0.0
    }

    private func getRecentViolations(db: OpaquePointer?, limit: Int) throws -> [DoctrineViolation] {
        let sql = """
        SELECT id, rule_id, file_path, line_number, severity, detected_at, resolved_at
        FROM doctrine_violations
        ORDER BY detected_at DESC
        LIMIT ?
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "DoctrineCommands", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to get recent violations: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, Int64(limit))

        var violations: [DoctrineViolation] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(stmt, 0))
            let ruleId = String(cString: sqlite3_column_text(stmt, 1))
            let filePath = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
            let lineNumber = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil : Int(sqlite3_column_int64(stmt, 3))
            let severity = String(cString: sqlite3_column_text(stmt, 4))
            let detectedAt = String(cString: sqlite3_column_text(stmt, 5))
            let resolvedAt = sqlite3_column_text(stmt, 6).map { String(cString: $0) }

            violations.append(DoctrineViolation(
                id: id,
                ruleId: ruleId,
                filePath: filePath,
                lineNumber: lineNumber,
                context: "",
                severity: severity,
                detectedAt: detectedAt,
                metadata: nil,
                resolvedAt: resolvedAt,
                resolution: nil
            ))
        }

        return violations
    }

    private func getTopViolatingFiles(db: OpaquePointer?, limit: Int) throws -> [ViolatingFile] {
        let sql = """
        SELECT file_path, COUNT(*) as violation_count
        FROM doctrine_violations
        WHERE file_path IS NOT NULL AND resolved_at IS NULL
        GROUP BY file_path
        ORDER BY violation_count DESC
        LIMIT ?
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "DoctrineCommands", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to get top violating files: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, Int64(limit))

        var files: [ViolatingFile] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let filePath = String(cString: sqlite3_column_text(stmt, 0))
            let violationCount = Int(sqlite3_column_int64(stmt, 1))

            files.append(ViolatingFile(
                filePath: filePath,
                violationCount: violationCount
            ))
        }

        return files
    }

    private func getRuleStatistics(db: OpaquePointer?) throws -> RuleStatistics {
        let sql = """
        SELECT
            COUNT(DISTINCT rule_id) as total_rules,
            SUM(CASE WHEN resolved_at IS NULL THEN 1 ELSE 0 END) as active_violations,
            SUM(CASE WHEN resolved_at IS NOT NULL THEN 1 ELSE 0 END) as resolved_violations,
            (
                SELECT rule_id
                FROM doctrine_violations
                WHERE resolved_at IS NULL
                GROUP BY rule_id
                ORDER BY COUNT(*) DESC
                LIMIT 1
            ) as most_violated_rule
        FROM doctrine_violations
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "DoctrineCommands", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to get rule statistics: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            let totalRules = Int(sqlite3_column_int64(stmt, 0))
            let activeViolations = Int(sqlite3_column_int64(stmt, 1))
            let resolvedViolations = Int(sqlite3_column_int64(stmt, 2))
            let mostViolatedRule = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? "none"

            return RuleStatistics(
                totalRules: totalRules,
                activeViolations: activeViolations,
                resolvedViolations: resolvedViolations,
                mostViolatedRule: mostViolatedRule
            )
        }

        return RuleStatistics(totalRules: 0, activeViolations: 0, resolvedViolations: 0, mostViolatedRule: "none")
    }

    private func updateRuleStats(db: OpaquePointer?, for violationId: String) throws {
        // Get the rule ID for this violation
        let getRuleSql = "SELECT rule_id FROM doctrine_violations WHERE id = ?"
        var getRuleStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, getRuleSql, -1, &getRuleStmt, nil) == SQLITE_OK else {
            return
        }
        defer { sqlite3_finalize(getRuleStmt) }

        sqlite3_bind_text(getRuleStmt, 1, violationId, -1, sqliteTransientDestructor)

        guard sqlite3_step(getRuleStmt) == SQLITE_ROW else {
            return
        }

        let ruleId = String(cString: sqlite3_column_text(getRuleStmt, 0))

        // Update rule stats
        let updateSql = """
        INSERT OR REPLACE INTO doctrine_rule_stats (rule_id, violation_count, resolved_count, last_violation, first_violation)
        SELECT
            ?,
            COUNT(*) as violation_count,
            SUM(CASE WHEN resolved_at IS NOT NULL THEN 1 ELSE 0 END) as resolved_count,
            MAX(detected_at) as last_violation,
            MIN(detected_at) as first_violation
        FROM doctrine_violations
        WHERE rule_id = ?
        """

        var updateStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, updateSql, -1, &updateStmt, nil) == SQLITE_OK else {
            return
        }
        defer { sqlite3_finalize(updateStmt) }

        sqlite3_bind_text(updateStmt, 1, ruleId, -1, sqliteTransientDestructor)
        sqlite3_bind_text(updateStmt, 2, ruleId, -1, sqliteTransientDestructor)

        _ = sqlite3_step(updateStmt)
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

// MARK: - Argument Parser

#if !HARMONIA_MODULE_TESTS
@main
public struct DoctrineCLI: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "harmonia-doctrine",
        abstract: "Doctrine debt observability and management",
        subcommands: [
            DoctrineStatusCommand.self,
            ViolationsCommand.self,
            RulesCommand.self,
            ResolveCommand.self
        ]
    )

    public init() {}
}
#endif

// MARK: - Subcommands

struct DoctrineStatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show doctrine debt status"
    )

    @Option(name: .shortAndLong, help: "Path to database file")
    var dbPath: String = "./harmonia_harness.sqlite"

    func run() throws {
        let commands = DoctrineCommands(dbPath: dbPath)
        try commands.status()
    }
}

struct ViolationsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "violations",
        abstract: "Show doctrine violations"
    )

    @Option(name: .shortAndLong, help: "Path to database file")
    var dbPath: String = "./harmonia_harness.sqlite"

    @Option(name: .shortAndLong, help: "Maximum number of violations to show")
    var limit: Int = 20

    @Option(name: .shortAndLong, help: "Filter by resolution status")
    var resolved: Bool?

    @Option(name: .shortAndLong, help: "Filter by severity")
    var severity: String?

    @Option(name: .shortAndLong, help: "Filter by rule ID")
    var ruleId: String?

    func run() throws {
        let commands = DoctrineCommands(dbPath: dbPath)
        try commands.violations(limit: limit, resolved: resolved, severity: severity, ruleId: ruleId)
    }
}

struct RulesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rules",
        abstract: "Show rule statistics"
    )

    @Option(name: .shortAndLong, help: "Path to database file")
    var dbPath: String = "./harmonia_harness.sqlite"

    func run() throws {
        let commands = DoctrineCommands(dbPath: dbPath)
        try commands.rules()
    }
}

struct ResolveCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "resolve",
        abstract: "Mark a violation as resolved"
    )

    @Argument(help: "Violation ID to resolve")
    var violationId: String

    @Argument(help: "Resolution description")
    var resolution: String

    @Option(name: .shortAndLong, help: "Path to database file")
    var dbPath: String = "./harmonia_harness.sqlite"

    func run() throws {
        let commands = DoctrineCommands(dbPath: dbPath)
        try commands.resolve(violationId: violationId, resolution: resolution)
    }
}
