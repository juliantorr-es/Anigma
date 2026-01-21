//
//  main.swift
//  Swift6Harness
//
//  [Brief description of file purpose]
//

#!/usr/bin/env swift

import Foundation
import SQLite3

// Minimal Swift 6 migration harness
// Bypasses broken CLI and modules, runs governance experiment directly

@main
struct Swift6Harness {
    static func main() async throws {
        print("🚀 Swift 6 Migration Harness")
        print("============================")
        print("Date: \(Date())")
        print("Database: ./harmonia_harness.sqlite")
        print()

        // Check database exists
        let dbPath = "./harmonia_harness.sqlite"
        guard FileManager.default.fileExists(atPath: dbPath) else {
            print("❌ Database not found at \(dbPath)")
            print("Run prepare_trust_experiment.sh first")
            exit(1)
        }

        // Open database
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to open database: \(errMsg)")
            exit(1)
        }
        defer { sqlite3_close(db) }

        // 1. Check trust state
        print("📊 Current Trust State")
        print("---------------------")
        let trustQuery = """
        SELECT 
            subject_id,
            subject_kind,
            trust_score,
            current_trust_tier,
            trust_calculated_at,
            changed_by,
            reason
        FROM trust_state
        ORDER BY trust_score DESC
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, trustQuery, -1, &stmt, nil) == SQLITE_OK {
            print("Subject ID           | Kind          | Score | Tier    | Changed By")
            print("---------------------|---------------|-------|---------|-----------")
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let subjectId = String(cString: sqlite3_column_text(stmt, 0))
                let subjectKind = String(cString: sqlite3_column_text(stmt, 1))
                let trustScore = sqlite3_column_int(stmt, 2)
                let trustTier = String(cString: sqlite3_column_text(stmt, 3))
                let changedBy = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? "system"
                
                print(String(format: "%-20s | %-13s | %5d | %-7s | %@", 
                    subjectId, subjectKind, trustScore, trustTier, changedBy))
            }
            sqlite3_finalize(stmt)
        }

        print()

        // 2. Check governance mode
        print("⚖️  Governance Mode")
        print("------------------")
        let modeQuery = "SELECT mode, changed_at, changed_by, reason FROM governance_mode ORDER BY changed_at DESC LIMIT 1"
        if sqlite3_prepare_v2(db, modeQuery, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                let mode = String(cString: sqlite3_column_text(stmt, 0))
                let changedAt = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? "unknown"
                let changedBy = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? "system"
                let reason = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? "no reason"
                
                print("Mode: \(mode)")
                print("Changed at: \(changedAt)")
                print("Changed by: \(changedBy)")
                print("Reason: \(reason)")
                
                if mode != "governed" {
                    print("⚠️  WARNING: Not in 'governed' mode. Trust clamping may not be active.")
                }
            } else {
                print("No governance mode set (defaulting to 'governed')")
            }
            sqlite3_finalize(stmt)
        }

        print()

        // 3. Check migration tasks
        print("🔧 Migration Tasks")
        print("-----------------")
        let taskQuery = """
        SELECT 
            id,
            feature_category,
            status,
            priority,
            created_at
        FROM migration_tasks 
        WHERE feature_category = 'swift6-migration'
        ORDER BY created_at DESC
        LIMIT 5
        """

        if sqlite3_prepare_v2(db, taskQuery, -1, &stmt, nil) == SQLITE_OK {
            var taskCount = 0
            print("Task ID              | Category        | Status   | Priority")
            print("---------------------|-----------------|----------|---------")
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                taskCount += 1
                let taskId = String(cString: sqlite3_column_text(stmt, 0))
                let category = String(cString: sqlite3_column_text(stmt, 1))
                let status = String(cString: sqlite3_column_text(stmt, 2))
                let priority = sqlite3_column_int(stmt, 3)
                
                print(String(format: "%-20s | %-15s | %-8s | %8d", 
                    String(taskId.prefix(20)), category, status, priority))
            }
            sqlite3_finalize(stmt)
            
            if taskCount == 0 {
                print("No Swift 6 migration tasks found.")
                print("Run: harmonia scout run swift6 --create-tasks")
                print("(Or create tasks manually in database)")
            }
        }

        print()

        // 4. Security events (last 5)
        print("🔒 Recent Security Events")
        print("------------------------")
        let securityQuery = """
        SELECT 
            event_type,
            subject_id,
            subject_kind,
            severity,
            recorded_at,
            details
        FROM security_events
        ORDER BY recorded_at DESC
        LIMIT 5
        """

        if sqlite3_prepare_v2(db, securityQuery, -1, &stmt, nil) == SQLITE_OK {
            var eventCount = 0
            print("Event Type           | Subject ID       | Severity | Recorded At")
            print("---------------------|------------------|----------|------------")
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                eventCount += 1
                let eventType = String(cString: sqlite3_column_text(stmt, 0))
                let subjectId = String(cString: sqlite3_column_text(stmt, 1))
                let subjectKind = String(cString: sqlite3_column_text(stmt, 2))
                let severity = String(cString: sqlite3_column_text(stmt, 3))
                let recordedAt = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? "unknown"
                
                print(String(format: "%-20s | %-16s | %-8s | %@", 
                    String(eventType.prefix(20)), 
                    String(subjectId.prefix(16)), 
                    severity, 
                    String(recordedAt.prefix(19))))
            }
            sqlite3_finalize(stmt)
            
            if eventCount == 0 {
                print("No security events recorded yet.")
            }
        }

        print()
        print("✅ Harness ready for Phase 4C experiment")
        print()
        print("Next steps:")
        print("1. Create Swift 6 migration tasks (if none exist)")
        print("2. Run migration through security-wrapped engine")
        print("3. Monitor trust score changes")
        print("4. Check CCTV (security_events table) for governance decisions")
        print()
        print("The trust nervous system is operational. The cathedral is watching.")
    }
}