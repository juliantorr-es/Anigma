//
//  ResearchStatusCommand.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Research
//
//  CLI command for research observability.
//

import Foundation
import ArgumentParser
import SQLite3
import HarmoniaModule

/// CLI commands for research observability.
public struct ResearchCommands {
    private let dbPath: String

    public init(dbPath: String = "./harmonia_harness.sqlite") {
        self.dbPath = dbPath
    }

    /// Show research status.
    public func status() throws {
        print("🔬 Research Status")
        print("=================")

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

        // Get bundle statistics
        let bundleStats = try getBundleStatistics(db: db)
        print("\n📚 Research Bundles:")
        print("  • Total bundles: \(bundleStats.totalBundles)")
        print("  • Average adequacy: \(String(format: "%.1f", bundleStats.averageAdequacy))")
        print("  • Expired bundles: \(bundleStats.expiredBundles)")
        print("  • Adequate bundles: \(bundleStats.adequateBundles)")

        // Get paper statistics
        let paperStats = try getPaperStatistics(db: db)
        print("\n📄 Research Papers:")
        print("  • Total papers: \(paperStats.totalPapers)")
        print("  • Average relevance: \(String(format: "%.1f", paperStats.averageRelevance))")
        print("  • Open access: \(paperStats.openAccessCount)")
        print("  • Average citations: \(String(format: "%.1f", paperStats.averageCitations))")

        // Get task statistics
        let taskStats = try getTaskStatistics(db: db)
        print("\n📋 Research Tasks:")
        print("  • Total tasks: \(taskStats.totalTasks)")
        print("  • Pending: \(taskStats.pendingTasks)")
        print("  • Completed: \(taskStats.completedTasks)")
        print("  • Failed: \(taskStats.failedTasks)")

        // Get debt statistics
        let debtStats = try getDebtStatistics(db: db)
        print("\n⚠️  Research Debt:")
        print("  • Total debt tasks: \(debtStats.totalDebtTasks)")
        print("  • Resolved: \(debtStats.resolvedDebtTasks)")
        print("  • Unresolved: \(debtStats.unresolvedDebtTasks)")
        print("  • High priority: \(debtStats.highPriorityDebt)")

        // Get recent bundles
        let recentBundles = try getRecentBundles(db: db, limit: 3)
        if !recentBundles.isEmpty {
            print("\n🕐 Recent Research Bundles:")
            for bundle in recentBundles {
                print("  • \(bundle.topicSpec)")
                print("    Adequacy: \(String(format: "%.1f", bundle.adequacyScore))")
                print("    Papers: \(bundle.paperCount)")
                print("    Created: \(bundle.researchedAt)")
                if bundle.isExpired {
                    print("    ⚠️  EXPIRED")
                }
            }
        }

        // Get adequacy distribution
        let adequacyDistribution = try getAdequacyDistribution(db: db)
        print("\n📊 Adequacy Distribution:")
        for (range, count) in adequacyDistribution.sorted(by: { $0.key < $1.key }) {
            print("  • \(range): \(count) bundles")
        }
    }

    /// Show research bundles.
    public func bundles(limit: Int = 20, minAdequacy: Double? = nil, expired: Bool? = nil) throws {
        print("📚 Research Bundles")
        print("==================")

        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to open database: \(errMsg)")
            return
        }
        defer { sqlite3_close(db) }

        var sql = """
        SELECT b.id, b.topic_spec, b.adequacy_score, b.researched_at, b.expires_at, b.provenance,
               COUNT(p.id) as paper_count
        FROM research_bundles b
        LEFT JOIN research_papers p ON b.id = p.bundle_id
        WHERE 1=1
        """

        var params: [String] = []
        if let minAdequacy = minAdequacy {
            sql += " AND b.adequacy_score >= ?"
            params.append(String(minAdequacy))
        }
        if let expired = expired {
            if expired {
                sql += " AND b.expires_at < CURRENT_TIMESTAMP"
            } else {
                sql += " AND b.expires_at >= CURRENT_TIMESTAMP"
            }
        }

        sql += " GROUP BY b.id ORDER BY b.researched_at DESC LIMIT ?"
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
            if index == params.count - 1 {
                // Last parameter is limit (Int)
                sqlite3_bind_int64(stmt, Int32(index + 1), Int64(param) ?? Int64(limit))
            } else {
                sqlite3_bind_text(stmt, Int32(index + 1), param, -1, SQLITE_TRANSIENT)
            }
        }

        var bundles: [ResearchBundle] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(stmt, 0))
            let topicSpec = String(cString: sqlite3_column_text(stmt, 1))
            let adequacyScore = sqlite3_column_double(stmt, 2)
            let researchedAt = String(cString: sqlite3_column_text(stmt, 3))
            let expiresAt = String(cString: sqlite3_column_text(stmt, 4))
            let provenance = String(cString: sqlite3_column_text(stmt, 5))
            let paperCount = Int(sqlite3_column_int64(stmt, 6))

            bundles.append(ResearchBundle(
                id: id,
                topicSpec: topicSpec,
                adequacyScore: adequacyScore,
                researchedAt: researchedAt,
                expiresAt: expiresAt,
                provenance: provenance,
                paperCount: paperCount
            ))
        }

        if bundles.isEmpty {
            print("📭 No research bundles found")
            if minAdequacy != nil || expired != nil {
                print("Try removing filters")
            }
            return
        }

        print("Found \(bundles.count) bundles:")
        for bundle in bundles {
            print("\n---")
            print("ID: \(bundle.id)")
            print("Topic: \(bundle.topicSpec)")
            print("Adequacy: \(String(format: "%.1f", bundle.adequacyScore))")
            print("Papers: \(bundle.paperCount)")
            print("Researched: \(bundle.researchedAt)")
            print("Expires: \(bundle.expiresAt)")
            print("Provenance: \(bundle.provenance)")

            let now = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            if let expiresDate = dateFormatter.date(from: bundle.expiresAt), expiresDate < now {
                print("⚠️  EXPIRED")
            }
        }
    }

    /// Show research papers for a bundle.
    public func papers(bundleId: String? = nil, limit: Int = 20, minRelevance: Double? = nil) throws {
        print("📄 Research Papers")
        print("=================")

        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to open database: \(errMsg)")
            return
        }
        defer { sqlite3_close(db) }

        var sql = """
        SELECT p.id, p.bundle_id, p.title, p.authors, p.year, p.venue, p.relevance_score,
               p.citation_count, p.is_open_access, p.source, p.fetched_at
        FROM research_papers p
        WHERE 1=1
        """

        var params: [String] = []
        if let bundleId = bundleId {
            sql += " AND p.bundle_id = ?"
            params.append(bundleId)
        }
        if let minRelevance = minRelevance {
            sql += " AND p.relevance_score >= ?"
            params.append(String(minRelevance))
        }

        sql += " ORDER BY p.relevance_score DESC LIMIT ?"
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
            if index == params.count - 1 {
                // Last parameter is limit (Int)
                sqlite3_bind_int64(stmt, Int32(index + 1), Int64(param) ?? Int64(limit))
            } else {
                sqlite3_bind_text(stmt, Int32(index + 1), param, -1, SQLITE_TRANSIENT)
            }
        }

        var papers: [ResearchPaper] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int64(stmt, 0))
            let bundleId = String(cString: sqlite3_column_text(stmt, 1))
            let title = String(cString: sqlite3_column_text(stmt, 2))
            let authors = String(cString: sqlite3_column_text(stmt, 3))
            let year = Int(sqlite3_column_int64(stmt, 4))
            let venue = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
            let relevanceScore = sqlite3_column_double(stmt, 6)
            let citationCount = sqlite3_column_type(stmt, 7) == SQLITE_NULL ? nil : Int(sqlite3_column_int64(stmt, 7))
            let isOpenAccess = sqlite3_column_int64(stmt, 8) != 0
            let source = String(cString: sqlite3_column_text(stmt, 9))
            let fetchedAt = String(cString: sqlite3_column_text(stmt, 10))

            papers.append(ResearchPaper(
                id: id,
                bundleId: bundleId,
                title: title,
                authors: authors,
                year: year,
                venue: venue,
                relevanceScore: relevanceScore,
                citationCount: citationCount,
                isOpenAccess: isOpenAccess,
                source: source,
                fetchedAt: fetchedAt
            ))
        }

        if papers.isEmpty {
            print("📭 No research papers found")
            if bundleId != nil || minRelevance != nil {
                print("Try removing filters")
            }
            return
        }

        print("Found \(papers.count) papers:")
        for paper in papers {
            print("\n---")
            print("ID: \(paper.id)")
            print("Bundle: \(paper.bundleId)")
            print("Title: \(paper.title)")
            print("Authors: \(paper.authors)")
            print("Year: \(paper.year)")
            if let venue = paper.venue {
                print("Venue: \(venue)")
            }
            print("Relevance: \(String(format: "%.1f", paper.relevanceScore))")
            if let citations = paper.citationCount {
                print("Citations: \(citations)")
            }
            print("Open Access: \(paper.isOpenAccess ? "Yes" : "No")")
            print("Source: \(paper.source)")
            print("Fetched: \(paper.fetchedAt)")
        }
    }

    /// Show research debt tasks.
    public func debt(limit: Int = 20, resolved: Bool? = nil, priority: String? = nil) throws {
        print("⚠️  Research Debt Tasks")
        print("======================")

        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to open database: \(errMsg)")
            return
        }
        defer { sqlite3_close(db) }

        var sql = """
        SELECT d.id, d.research_bundle_id, d.reason, d.required_actions,
               d.blocked_entity_id, d.blocked_entity_type, d.created_at,
               d.resolved_at, d.priority, b.topic_spec
        FROM research_debt_tasks d
        JOIN research_bundles b ON d.research_bundle_id = b.id
        WHERE 1=1
        """

        var params: [String] = []
        if let resolved = resolved {
            if resolved {
                sql += " AND d.resolved_at IS NOT NULL"
            } else {
                sql += " AND d.resolved_at IS NULL"
            }
        }
        if let priority = priority {
            sql += " AND d.priority = ?"
            params.append(priority)
        }

        sql += " ORDER BY d.created_at DESC LIMIT ?"
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
            if index == params.count - 1 {
                // Last parameter is limit (Int)
                sqlite3_bind_int64(stmt, Int32(index + 1), Int64(param) ?? Int64(limit))
            } else {
                sqlite3_bind_text(stmt, Int32(index + 1), param, -1, SQLITE_TRANSIENT)
            }
        }

        var debtTasks: [ResearchDebtTask] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(stmt, 0))
            let bundleId = String(cString: sqlite3_column_text(stmt, 1))
            let reason = String(cString: sqlite3_column_text(stmt, 2))
            let requiredActions = String(cString: sqlite3_column_text(stmt, 3))
            let blockedEntityId = String(cString: sqlite3_column_text(stmt, 4))
            let blockedEntityType = String(cString: sqlite3_column_text(stmt, 5))
            let createdAt = String(cString: sqlite3_column_text(stmt, 6))
            let resolvedAt = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
            let priority = String(cString: sqlite3_column_text(stmt, 8))
            let topicSpec = String(cString: sqlite3_column_text(stmt, 9))

            debtTasks.append(ResearchDebtTask(
                id: id,
                bundleId: bundleId,
                topicSpec: topicSpec,
                reason: reason,
                requiredActions: requiredActions,
                blockedEntityId: blockedEntityId,
                blockedEntityType: blockedEntityType,
                createdAt: createdAt,
                resolvedAt: resolvedAt,
                priority: priority
            ))
        }

        if debtTasks.isEmpty {
            print("📭 No research debt tasks found")
            if resolved != nil || priority != nil {
                print("Try removing filters")
            }
            return
        }

        print("Found \(debtTasks.count) debt tasks:")
        for task in debtTasks {
            print("\n---")
            print("ID: \(task.id)")
            print("Bundle: \(task.bundleId)")
            print("Topic: \(task.topicSpec)")
            print("Reason: \(task.reason)")
            print("Required Actions: \(task.requiredActions)")
            print("Blocked Entity: \(task.blockedEntityId) (\(task.blockedEntityType))")
            print("Priority: \(task.priority)")
            print("Created: \(task.createdAt)")
            if let resolvedAt = task.resolvedAt {
                print("✅ Resolved at: \(resolvedAt)")
            } else {
                print("❌ Unresolved")
            }
        }
    }

    // MARK: - Helper Methods

    private func getBundleStatistics(db: OpaquePointer?) throws -> BundleStatistics {
        let sql = """
        SELECT
            COUNT(*) as total_bundles,
            AVG(adequacy_score) as avg_adequacy,
            SUM(CASE WHEN expires_at < CURRENT_TIMESTAMP THEN 1 ELSE 0 END) as expired_bundles,
            SUM(CASE WHEN adequacy_score >= 0.7 THEN 1 ELSE 0 END) as adequate_bundles
        FROM research_bundles
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "ResearchCommands", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get bundle statistics: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            let totalBundles = Int(sqlite3_column_int64(stmt, 0))
            let averageAdequacy = sqlite3_column_double(stmt, 1)
            let expiredBundles = Int(sqlite3_column_int64(stmt, 2))
            let adequateBundles = Int(sqlite3_column_int64(stmt, 3))

            return BundleStatistics(
                totalBundles: totalBundles,
                averageAdequacy: averageAdequacy,
                expiredBundles: expiredBundles,
                adequateBundles: adequateBundles
            )
        }

        return BundleStatistics(totalBundles: 0, averageAdequacy: 0.0, expiredBundles: 0, adequateBundles: 0)
    }

    private func getPaperStatistics(db: OpaquePointer?) throws -> PaperStatistics {
        let sql = """
        SELECT
            COUNT(*) as total_papers,
            AVG(relevance_score) as avg_relevance,
            SUM(CASE WHEN is_open_access = 1 THEN 1 ELSE 0 END) as open_access_count,
            AVG(citation_count) as avg_citations
        FROM research_papers
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "ResearchCommands", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get paper statistics: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            let totalPapers = Int(sqlite3_column_int64(stmt, 0))
            let averageRelevance = sqlite3_column_double(stmt, 1)
            let openAccessCount = Int(sqlite3_column_int64(stmt, 2))
            let averageCitations = sqlite3_column_double(stmt, 3)

            return PaperStatistics(
                totalPapers: totalPapers,
                averageRelevance: averageRelevance,
                openAccessCount: openAccessCount,
                averageCitations: averageCitations
            )
        }

        return PaperStatistics(totalPapers: 0, averageRelevance: 0.0, openAccessCount: 0, averageCitations: 0.0)
    }

    private func getTaskStatistics(db: OpaquePointer?) throws -> TaskStatistics {
        let sql = """
        SELECT
            COUNT(*) as total_tasks,
            SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_tasks,
            SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_tasks,
            SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed_tasks
        FROM research_tasks
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "ResearchCommands", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to get task statistics: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            let totalTasks = Int(sqlite3_column_int64(stmt, 0))
            let pendingTasks = Int(sqlite3_column_int64(stmt, 1))
            let completedTasks = Int(sqlite3_column_int64(stmt, 2))
            let failedTasks = Int(sqlite3_column_int64(stmt, 3))

            return TaskStatistics(
                totalTasks: totalTasks,
                pendingTasks: pendingTasks,
                completedTasks: completedTasks,
                failedTasks: failedTasks
            )
        }

        return TaskStatistics(totalTasks: 0, pendingTasks: 0, completedTasks: 0, failedTasks: 0)
    }

    private func getDebtStatistics(db: OpaquePointer?) throws -> DebtStatistics {
        let sql = """
        SELECT
            COUNT(*) as total_debt_tasks,
            SUM(CASE WHEN resolved_at IS NOT NULL THEN 1 ELSE 0 END) as resolved_debt_tasks,
            SUM(CASE WHEN resolved_at IS NULL THEN 1 ELSE 0 END) as unresolved_debt_tasks,
            SUM(CASE WHEN priority = 'high' AND resolved_at IS NULL THEN 1 ELSE 0 END) as high_priority_debt
        FROM research_debt_tasks
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "ResearchCommands", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to get debt statistics: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            let totalDebtTasks = Int(sqlite3_column_int64(stmt, 0))
            let resolvedDebtTasks = Int(sqlite3_column_int64(stmt, 1))
            let unresolvedDebtTasks = Int(sqlite3_column_int64(stmt, 2))
            let highPriorityDebt = Int(sqlite3_column_int64(stmt, 3))

            return DebtStatistics(
                totalDebtTasks: totalDebtTasks,
                resolvedDebtTasks: resolvedDebtTasks,
                unresolvedDebtTasks: unresolvedDebtTasks,
                highPriorityDebt: highPriorityDebt
            )
        }

        return DebtStatistics(totalDebtTasks: 0, resolvedDebtTasks: 0, unresolvedDebtTasks: 0, highPriorityDebt: 0)
    }

    private func getRecentBundles(db: OpaquePointer?, limit: Int) throws -> [RecentBundle] {
        let sql = """
        SELECT b.id, b.topic_spec, b.adequacy_score, b.researched_at, b.expires_at,
               COUNT(p.id) as paper_count
        FROM research_bundles b
        LEFT JOIN research_papers p ON b.id = p.bundle_id
        GROUP BY b.id
        ORDER BY b.researched_at DESC
        LIMIT ?
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "ResearchCommands", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to get recent bundles: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, Int64(limit))

        var bundles: [RecentBundle] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(stmt, 0))
            let topicSpec = String(cString: sqlite3_column_text(stmt, 1))
            let adequacyScore = sqlite3_column_double(stmt, 2)
            let researchedAt = String(cString: sqlite3_column_text(stmt, 3))
            let expiresAt = String(cString: sqlite3_column_text(stmt, 4))
            let paperCount = Int(sqlite3_column_int64(stmt, 5))

            // Check if expired
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let now = Date()
            let expiresDate = dateFormatter.date(from: expiresAt) ?? now
            let isExpired = expiresDate < now

            bundles.append(RecentBundle(
                id: id,
                topicSpec: topicSpec,
                adequacyScore: adequacyScore,
                researchedAt: researchedAt,
                expiresAt: expiresAt,
                paperCount: paperCount,
                isExpired: isExpired
            ))
        }

        return bundles
    }

    private func getAdequacyDistribution(db: OpaquePointer?) throws -> [String: Int] {
        let sql = """
        SELECT
            CASE
                WHEN adequacy_score >= 0.9 THEN '0.9-1.0'
                WHEN adequacy_score >= 0.8 THEN '0.8-0.9'
                WHEN adequacy_score >= 0.7 THEN '0.7-0.8'
                WHEN adequacy_score >= 0.6 THEN '0.6-0.7'
                WHEN adequacy_score >= 0.5 THEN '0.5-0.6'
                ELSE '0.0-0.5'
            END as adequacy_range,
            COUNT(*) as count
        FROM research_bundles
        GROUP BY adequacy_range
        ORDER BY adequacy_range
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "ResearchCommands", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to get adequacy distribution: \(errMsg)"])
        }
        defer { sqlite3_finalize(stmt) }

        var distribution: [String: Int] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let range = String(cString: sqlite3_column_text(stmt, 0))
            let count = Int(sqlite3_column_int64(stmt, 1))
            distribution[range] = count
        }

        return distribution
    }
}

// MARK: - Data Structures

private struct ResearchBundle {
    let id: String
    let topicSpec: String
    let adequacyScore: Double
    let researchedAt: String
    let expiresAt: String
    let provenance: String
    let paperCount: Int
}

private struct ResearchPaper {
    let id: Int
    let bundleId: String
    let title: String
    let authors: String
    let year: Int
    let venue: String?
    let relevanceScore: Double
    let citationCount: Int?
    let isOpenAccess: Bool
    let source: String
    let fetchedAt: String
}

private struct ResearchDebtTask {
    let id: String
    let bundleId: String
    let topicSpec: String
    let reason: String
    let requiredActions: String
    let blockedEntityId: String
    let blockedEntityType: String
    let createdAt: String
    let resolvedAt: String?
    let priority: String
}

private struct RecentBundle {
    let id: String
    let topicSpec: String
    let adequacyScore: Double
    let researchedAt: String
    let expiresAt: String
    let paperCount: Int
    let isExpired: Bool
}

private struct BundleStatistics {
    let totalBundles: Int
    let averageAdequacy: Double
    let expiredBundles: Int
    let adequateBundles: Int
}

private struct PaperStatistics {
    let totalPapers: Int
    let averageRelevance: Double
    let openAccessCount: Int
    let averageCitations: Double
}

private struct TaskStatistics {
    let totalTasks: Int
    let pendingTasks: Int
    let completedTasks: Int
    let failedTasks: Int
}

private struct DebtStatistics {
    let totalDebtTasks: Int
    let resolvedDebtTasks: Int
    let unresolvedDebtTasks: Int
    let highPriorityDebt: Int
}

// MARK: - Argument Parser

@main
public struct ResearchCLI: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "harmonia-research",
        abstract: "Research observability and management",
        subcommands: [
            StatusCommand.self,
            BundlesCommand.self,
            PapersCommand.self,
            DebtCommand.self
        ]
    )

    public init() {}
}

// MARK: - Subcommands

struct StatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show research status"
    )

    @Option(name: .shortAndLong, help: "Path to database file")
    var dbPath: String = "./harmonia_harness.sqlite"

    func run() throws {
        let commands = ResearchCommands(dbPath: dbPath)
        try commands.status()
    }
}

struct BundlesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bundles",
        abstract: "Show research bundles"
    )

    @Option(name: .shortAndLong, help: "Path to database file")
    var dbPath: String = "./harmonia_harness.sqlite"

    @Option(name: .shortAndLong, help: "Maximum number of bundles to show")
    var limit: Int = 20

    @Option(name: .shortAndLong, help: "Minimum adequacy score")
    var minAdequacy: Double?

    @Option(name: .shortAndLong, help: "Filter by expiration status")
    var expired: Bool?

    func run() throws {
        let commands = ResearchCommands(dbPath: dbPath)
        try commands.bundles(limit: limit, minAdequacy: minAdequacy, expired: expired)
    }
}

struct PapersCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "papers",
        abstract: "Show research papers"
    )

    @Option(name: .shortAndLong, help: "Path to database file")
    var dbPath: String = "./harmonia_harness.sqlite"

    @Option(name: .shortAndLong, help: "Maximum number of papers to show")
    var limit: Int = 20

    @Option(name: .shortAndLong, help: "Filter by bundle ID")
    var bundleId: String?

    @Option(name: .shortAndLong, help: "Minimum relevance score")
    var minRelevance: Double?

    func run() throws {
        let commands = ResearchCommands(dbPath: dbPath)
        try commands.papers(bundleId: bundleId, limit: limit, minRelevance: minRelevance)
    }
}

struct DebtCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "debt",
        abstract: "Show research debt tasks"
    )

    @Option(name: .shortAndLong, help: "Path to database file")
    var dbPath: String = "./harmonia_harness.sqlite"

    @Option(name: .shortAndLong, help: "Maximum number of debt tasks to show")
    var limit: Int = 20

    @Option(name: .shortAndLong, help: "Filter by resolution status")
    var resolved: Bool?

    @Option(name: .shortAndLong, help: "Filter by priority")
    var priority: String?

    func run() throws {
        let commands = ResearchCommands(dbPath: dbPath)
        try commands.debt(limit: limit, resolved: resolved, priority: priority)
    }
}
