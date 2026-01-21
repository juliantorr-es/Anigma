//
//  ModeCommand.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Security
//
//  CLI command for governance mode management.
//

import Foundation
import ArgumentParser
import SQLite3
import HarmoniaModule

/// CLI commands for governance mode management.
public struct ModeCommands {
    private let dbPath: String

    public init(dbPath: String = "./harmonia_harness.sqlite") {
        self.dbPath = dbPath
    }

    /// Show current governance mode.
    public func status() throws {
        print("🏛️  Governance Mode")
        print("==================")

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

        let mode = try getGovernanceMode(db: db)
        let updatedAt = try getModeUpdatedAt(db: db)
        let updatedBy = try getModeUpdatedBy(db: db)

        print("Current mode: \(mode)")
        print("Last updated: \(updatedAt)")
        if let updatedBy = updatedBy {
            print("Updated by: \(updatedBy)")
        }

        print("\n📋 Mode Description:")
        switch mode {
        case "personal":
            print("""
            • Trust bounds: bronze ↔ platinum
            • Security posture: Minimal restrictions
            • Use case: Personal projects, experimentation
            • Default trust: bronze (lowest)
            • Blocking rate: Low (only critical violations)
            """)
        case "governed":
            print("""
            • Trust bounds: silver ↔ gold
            • Security posture: Balanced restrictions (default)
            • Use case: Team projects, production code
            • Default trust: silver (moderate)
            • Blocking rate: Medium (doctrine & capability violations)
            """)
        case "paranoid":
            print("""
            • Trust bounds: gold ↔ silver (inverted)
            • Security posture: Maximum restrictions
            • Use case: Security-critical, compliance
            • Default trust: gold (high)
            • Blocking rate: High (all violations blocked)
            """)
        default:
            print("Unknown mode")
        }

        // Show trust bounds
        let trustBounds = getTrustBounds(for: mode)
        print("\n🤝 Trust Bounds:")
        print("  • Minimum: \(trustBounds.min)")
        print("  • Maximum: \(trustBounds.max)")

        // Show mode impact
        print("\n⚡ Mode Impact:")
        let impact = getModeImpact(for: mode)
        for (area, description) in impact {
            print("  • \(area): \(description)")
        }
    }

    /// Set governance mode.
    public func set(mode: String, updatedBy: String? = nil) throws {
        guard ["personal", "governed", "paranoid"].contains(mode) else {
            print("❌ Invalid mode. Must be one of: personal, governed, paranoid")
            return
        }

        print("⚙️  Setting governance mode to: \(mode)")

        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to open database: \(errMsg)")
            return
        }
        defer { sqlite3_close(db) }

        let sql = """
        INSERT OR REPLACE INTO governance_mode (id, mode, updated_by)
        VALUES (1, ?, ?)
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to prepare query: \(errMsg)")
            return
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, mode, -1, SQLITE_TRANSIENT)
        if let updatedBy = updatedBy {
            sqlite3_bind_text(stmt, 2, updatedBy, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 2)
        }

        if sqlite3_step(stmt) != SQLITE_DONE {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to set governance mode: \(errMsg)")
            return
        }

        print("✅ Governance mode set to '\(mode)'")

        // Log security event
        try logModeChangeEvent(db: db, mode: mode, updatedBy: updatedBy)

        // Show new status
        try status()
    }

    /// Show mode history.
    public func history(limit: Int = 10) throws {
        print("📜 Governance Mode History")
        print("=========================")

        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to open database: \(errMsg)")
            return
        }
        defer { sqlite3_close(db) }

        // Get mode changes from security events
        let sql = """
        SELECT id, engine_id, operation, severity, details, created_at
        FROM security_events
        WHERE event_type = 'governance_mode_changed'
        ORDER BY created_at DESC
        LIMIT ?
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to prepare query: \(errMsg)")
            return
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, Int64(limit))

        var changes: [ModeChange] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(stmt, 0))
            let engineId = sqlite3_column_text(stmt, 1).map { String(cString: $0) }
            let operation = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
            let severity = String(cString: sqlite3_column_text(stmt, 3))
            let details = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
            let timestamp = String(cString: sqlite3_column_text(stmt, 5))

            changes.append(ModeChange(
                id: id,
                engineId: engineId,
                operation: operation,
                severity: severity,
                details: details,
                timestamp: timestamp
            ))
        }

        if changes.isEmpty {
            print("📭 No mode change history found")
            return
        }

        print("Found \(changes.count) mode changes:")
        for change in changes {
            print("\n---")
            print("Time: \(change.timestamp)")
            print("Severity: \(change.severity)")
            if let engineId = change.engineId {
                print("Changed by: \(engineId)")
            }
            if let operation = change.operation {
                print("Operation: \(operation)")
            }
            if let details = change.details {
                print("Details: \(details)")
            }
        }
    }

    /// Show mode comparison.
    public func compare() throws {
        print("📊 Governance Mode Comparison")
        print("============================")

        let modes = ["personal", "governed", "paranoid"]

        print("\nMode | Trust Bounds | Security | Default Trust | Blocking")
        print("-----|--------------|----------|---------------|----------")

        for mode in modes {
            let bounds = getTrustBounds(for: mode)
            let security = getSecurityLevel(for: mode)
            let defaultTrust = getDefaultTrust(for: mode)
            let blocking = getBlockingLevel(for: mode)

            print("\(mode.padding(toLength: 7, withPad: " ", startingAt: 0)) | \(bounds.min)-\(bounds.max) | \(security.padding(toLength: 8, withPad: " ", startingAt: 0)) | \(defaultTrust.padding(toLength: 13, withPad: " ", startingAt: 0)) | \(blocking)")
        }

        print("\n🔍 Detailed Comparison:")
        for mode in modes {
            print("\n\(mode.uppercased()):")
            let impact = getModeImpact(for: mode)
            for (area, description) in impact {
                print("  • \(area): \(description)")
            }
        }

        print("\n💡 Recommendations:")
        print("""
        • personal: Use for experimentation, personal projects, learning
        • governed: Default for team projects, production code (balanced)
        • paranoid: Use for security-critical systems, compliance requirements
        """)
    }

    // MARK: - Helper Methods

    private func getGovernanceMode(db: OpaquePointer?) throws -> String {
        let sql = "SELECT mode FROM governance_mode WHERE id = 1"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "ModeCommands", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get governance mode: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            return String(cString: sqlite3_column_text(stmt, 0))
        }

        return "governed" // Default
    }

    private func getModeUpdatedAt(db: OpaquePointer?) throws -> String {
        let sql = "SELECT updated_at FROM governance_mode WHERE id = 1"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "ModeCommands", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get mode updated at: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            return String(cString: sqlite3_column_text(stmt, 0))
        }

        return "unknown"
    }

    private func getModeUpdatedBy(db: OpaquePointer?) throws -> String? {
        let sql = "SELECT updated_by FROM governance_mode WHERE id = 1"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "ModeCommands", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to get mode updated by: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            if let text = sqlite3_column_text(stmt, 0) {
                return String(cString: text)
            }
        }

        return nil
    }

    private func getTrustBounds(for mode: String) -> (min: String, max: String) {
        switch mode {
        case "personal":
            return ("bronze", "platinum")
        case "governed":
            return ("silver", "gold")
        case "paranoid":
            return ("gold", "silver") // Inverted - gold is minimum
        default:
            return ("bronze", "platinum")
        }
    }

    private func getSecurityLevel(for mode: String) -> String {
        switch mode {
        case "personal": return "low"
        case "governed": return "medium"
        case "paranoid": return "high"
        default: return "medium"
        }
    }

    private func getDefaultTrust(for mode: String) -> String {
        switch mode {
        case "personal": return "bronze"
        case "governed": return "silver"
        case "paranoid": return "gold"
        default: return "silver"
        }
    }

    private func getBlockingLevel(for mode: String) -> String {
        switch mode {
        case "personal": return "low"
        case "governed": return "medium"
        case "paranoid": return "high"
        default: return "medium"
        }
    }

    private func getModeImpact(for mode: String) -> [(String, String)] {
        switch mode {
        case "personal":
            return [
                ("Capabilities", "Most capabilities allowed"),
                ("Doctrine", "Only critical violations blocked"),
                ("Research", "Minimal adequacy requirements"),
                ("Trust", "Easy to gain, hard to lose trust"),
                ("Audit", "Basic logging only")
            ]
        case "governed":
            return [
                ("Capabilities", "Restricted based on trust tier"),
                ("Doctrine", "All violations tracked, some blocked"),
                ("Research", "Adequacy requirements enforced"),
                ("Trust", "Balanced promotion/degradation"),
                ("Audit", "Comprehensive logging")
            ]
        case "paranoid":
            return [
                ("Capabilities", "Highly restricted, require justification"),
                ("Doctrine", "All violations blocked immediately"),
                ("Research", "Strict adequacy requirements"),
                ("Trust", "Hard to gain, easy to lose trust"),
                ("Audit", "Full audit trail with signatures")
            ]
        default:
            return []
        }
    }

    private func logModeChangeEvent(db: OpaquePointer?, mode: String, updatedBy: String?) throws {
        let eventId = UUID().uuidString
        let eventType = "governance_mode_changed"
        let severity = "medium"
        let details = "{\"new_mode\": \"\(mode)\", \"updated_by\": \"\(updatedBy ?? "system")\"}"

        let sql = """
        INSERT INTO security_events (id, event_type, severity, details)
        VALUES (?, ?, ?, ?)
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, eventId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, eventType, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, severity, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, details, -1, SQLITE_TRANSIENT)

        _ = sqlite3_step(stmt)
    }
}

// MARK: - Data Structures

private struct ModeChange {
    let id: String
    let engineId: String?
    let operation: String?
    let severity: String
    let details: String?
    let timestamp: String
}

// MARK: - Argument Parser

@main
public struct ModeCLI: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "harmonia-mode",
        abstract: "Governance mode management",
        subcommands: [
            StatusCommand.self,
            SetCommand.self,
            HistoryCommand.self,
            CompareCommand.self
        ]
    )

    public init() {}
}

// MARK: - Subcommands

struct StatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show current governance mode"
    )

    @Option(name: .shortAndLong, help: "Path to database file")
    var dbPath: String = "./harmonia_harness.sqlite"

    func run() throws {
        let commands = ModeCommands(dbPath: dbPath)
        try commands.status()
    }
}

struct SetCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Set governance mode"
    )

    @Argument(help: "Mode to set (personal, governed, paranoid)")
    var mode: String

    @Option(name: .shortAndLong, help: "Who changed the mode")
    var updatedBy: String?

    @Option(name: .shortAndLong, help: "Path to database file")
    var dbPath: String = "./harmonia_harness.sqlite"

    func run() throws {
        let commands = ModeCommands(dbPath: dbPath)
        try commands.set(mode: mode, updatedBy: updatedBy)
    }
}

struct HistoryCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "history",
        abstract: "Show mode change history"
    )

    @Option(name: .shortAndLong, help: "Path to database file")
    var dbPath: String = "./harmonia_harness.sqlite"

    @Option(name: .shortAndLong, help: "Maximum number of changes to show")
    var limit: Int = 10

    func run() throws {
        let commands = ModeCommands(dbPath: dbPath)
        try commands.history(limit: limit)
    }
}

struct CompareCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "compare",
        abstract: "Compare governance modes"
    )

    @Option(name: .shortAndLong, help: "Path to database file")
    var dbPath: String = "./harmonia_harness.sqlite"

    func run() throws {
        let commands = ModeCommands(dbPath: dbPath)
        try commands.compare()
    }
}
