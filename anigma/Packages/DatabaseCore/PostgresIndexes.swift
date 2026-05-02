//
//  PostgresIndexes.swift
//  DatabaseCore
//
//  PostgreSQL index management and optimization.
//
//  See td-18fed9: Create index advisor for query patterns
//  See td-dee103: Implement partial indexes for common filtered queries
//  See td-ee96df: Add BRIN indexes for time-series data
//  See td-916342: Implement generated columns for computed values
//  See td-b3b58d: Create index usage monitoring
//  See td-ad6d52: Optimize JSONB query patterns with GIN
//  See td-89a996: PostgreSQL First-Class Implementation Epic
//

import Foundation

// MARK: - Index Type

/// PostgreSQL index types
public enum PostgresIndexType: String, Sendable, Codable, CaseIterable {
    case btree
    case hash
    case gin
    case gist
    case brin
    case spgist
}

/// Index column definition
public struct PostgresIndexColumn: Sendable, Codable {
    public let column: String
    public let `operator`: String?
    public let collation: String?
    public let order: String? // ASC, DESC, USING
    public let nulls: String? // FIRST, LAST
    
    public init(
        column: String,
        operator: String? = nil,
        collation: String? = nil,
        order: String? = nil,
        nulls: String? = nil
    ) {
        self.column = column
        self.operator = `operator`
        self.collation = collation
        self.order = order
        self.nulls = nulls
    }
    
    public func toSQL() -> String {
        var parts = [column]
        if let op = `operator` { parts.append("\(op)") }
        if let coll = collation { parts.append("COLLATE \(coll)") }
        if let ord = order { parts.append(ord) }
        if let nul = nulls { parts.append(nul) }
        return parts.joined(separator: " ")
    }
}

/// Index options
public struct PostgresIndexOptions: Sendable, Codable {
    public var unique: Bool
    public var concurrent: Bool
    public var ifNotExists: Bool
    public var include: [String]?
    public var whereClause: String?
    public var with: [String: String]?
    public var tablespace: String?
    public var fillfactor: Int?
    
    public init(
        unique: Bool = false,
        concurrent: Bool = false,
        ifNotExists: Bool = true,
        include: [String]? = nil,
        whereClause: String? = nil,
        with: [String: String]? = nil,
        tablespace: String? = nil,
        fillfactor: Int? = nil
    ) {
        self.unique = unique
        self.concurrent = concurrent
        self.ifNotExists = ifNotExists
        self.include = include
        self.whereClause = whereClause
        self.with = with
        self.tablespace = tablespace
        self.fillfactor = fillfactor
    }
}

/// Index definition
public struct PostgresIndexDefinition: Sendable, Codable {
    public let name: String
    public let table: String
    public let type: PostgresIndexType
    public let columns: [PostgresIndexColumn]
    public let options: PostgresIndexOptions
    
    public init(
        name: String,
        table: String,
        type: PostgresIndexType = .btree,
        columns: [PostgresIndexColumn],
        options: PostgresIndexOptions = PostgresIndexOptions()
    ) {
        self.name = name
        self.table = table
        self.type = type
        self.columns = columns
        self.options = options
    }
    
    public var createSQL: String {
        var sql = "CREATE "
        if options.unique { sql += "UNIQUE " }
        sql += "INDEX "
        if options.concurrent { sql += "CONCURRENTLY " }
        if options.ifNotExists { sql += "IF NOT EXISTS " }
        
        sql += "\(name) ON \(table) USING \(type) ("
        sql += columns.map { $0.toSQL() }.joined(separator: ", ")
        sql += ")"
        
        if let include = options.include, !include.isEmpty {
            sql += " INCLUDE (\(include))"
        }
        
        if let whereClause = options.whereClause {
            sql += " WHERE \(whereClause)"
        }
        
        if let `with` = options.`with`, !`with`.isEmpty {
            let withParts = `with`.map { "\($0.key) = \($0.value)" }
            sql += " WITH (\(withParts))"
        }
        
        if let tablespace = options.tablespace {
            sql += " TABLESPACE \(tablespace)"
        }
        
        return sql
    }
    
    public var dropSQL: String {
        "DROP INDEX IF EXISTS \(name) ON \(table)"
    }
    
    public var existsSQL: String {
        "SELECT 1 FROM pg_indexes WHERE schemaname = current_schema() AND tablename = '\(table)' AND indexname = '\(name)'"
    }
}

// MARK: - Index Advisor

/// Analyzes query patterns and recommends indexes
public final class PostgresIndexAdvisor: Sendable {
    private let database: any DatabaseExecutor
    
    public init(database: any DatabaseExecutor) {
        self.database = database
    }
    
    /// Analyze a query and recommend indexes
    public func recommendIndexes(forQuery query: String) async throws -> [PostgresIndexDefinition] {
        // Parse the query to identify WHERE, JOIN, ORDER BY clauses
        let recommendations = analyzeQuery(query)
        return recommendations
    }
    
    /// Analyze a set of queries and recommend indexes
    public func recommendIndexes(forQueries queries: [String]) async throws -> [PostgresIndexDefinition] {
        var allRecommendations: [PostgresIndexDefinition] = []
        for query in queries {
            let recommendations = try await recommendIndexes(forQuery: query)
            allRecommendations.append(contentsOf: recommendations)
        }
        // Deduplicate by index signature
        return deduplicateIndexes(allRecommendations)
    }
    
    /// Get existing indexes for a table
    public func getExistingIndexes(forTable table: String) async throws -> [PostgresIndexDefinition] {
        _ = try await database.query("""
            SELECT 
                indexname as name,
                tablename as table,
                indexdef as definition
            FROM pg_indexes 
            WHERE tablename = $1 AND schemaname = current_schema()
            ORDER BY indexname
        """, parameters: [.text(table)])
        
        // In a real implementation, parse indexdef to reconstruct PostgresIndexDefinition
        return []
    }
    
    /// Get unused indexes
    public func getUnusedIndexes(minScans: Int = 0) async throws -> [PostgresIndexDefinition] {
        let rows = try await database.query("""
            SELECT 
                schemaname as schema,
                relname as table,
                indexrelname as index_name,
                idx_scan as scans
            FROM pg_stat_user_indexes 
            WHERE idx_scan <= $1
            ORDER BY schemaname, relname, indexrelname
        """, parameters: [.int(minScans)])
        
        // Parse and convert to PostgresIndexDefinition
        var unused: [PostgresIndexDefinition] = []
        for row in rows {
            let schema = row.string(for: "schema") ?? ""
            let table = row.string(for: "table") ?? ""
            let indexName = row.string(for: "index_name") ?? ""
            
            // Simplified - in real implementation we'd get the full definition
            unused.append(PostgresIndexDefinition(
                name: indexName,
                table: schema + "." + table,
                type: .btree,
                columns: [],
                options: PostgresIndexOptions()
            ))
        }
        
        return unused
    }
    
    /// Get duplicate indexes
    public func getDuplicateIndexes() async throws -> [[PostgresIndexDefinition]] {
        let rows = try await database.query("""
            SELECT 
                schemaname as schema,
                relname as table,
                indexrelname as index_name,
                indexdef as definition
            FROM pg_indexes
            WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
            ORDER BY schemaname, relname, indexrelname
        """)
        
        // Group by index definition similarity
        var duplicates: [[PostgresIndexDefinition]] = []
        var seenDefinitions: [String: [PostgresIndexDefinition]] = [:]
        
        for row in rows {
            let definition = row.string(for: "definition") ?? ""
            let schema = row.string(for: "schema") ?? ""
            let table = row.string(for: "table") ?? ""
            let indexName = row.string(for: "index_name") ?? ""
            
            if seenDefinitions[definition] == nil {
                seenDefinitions[definition] = []
            }
            seenDefinitions[definition]?.append(PostgresIndexDefinition(
                name: indexName,
                table: schema + "." + table,
                type: .btree,
                columns: [],
                options: PostgresIndexOptions()
            ))
        }
        
        for (_, indexes) in seenDefinitions where indexes.count > 1 {
            duplicates.append(indexes)
        }
        
        return duplicates
    }
    
    // MARK: - Private
    
    private func analyzeQuery(_ query: String) -> [PostgresIndexDefinition] {
        let recommendations: [PostgresIndexDefinition] = []
        let upperQuery = query.uppercased()
        
        // Simple pattern matching - in real implementation use proper SQL parser
        
        // Check for WHERE clauses
        if upperQuery.contains(" WHERE ") {
            // Look for equality conditions
            // Look for LIKE conditions
            // Look for range conditions
        }
        
        // Check for JOIN clauses
        if upperQuery.contains(" JOIN ") {
            // Recommend indexes on join columns
        }
        
        // Check for ORDER BY
        if upperQuery.contains(" ORDER BY ") {
            // Recommend indexes matching ORDER BY columns
        }
        
        return recommendations
    }
    
    private func deduplicateIndexes(_ indexes: [PostgresIndexDefinition]) -> [PostgresIndexDefinition] {
        var seen: Set<String> = []
        var unique: [PostgresIndexDefinition] = []
        
        for index in indexes {
            let signature = "\(index.name).\(index.table).\(index.columns.count)"
            if !seen.contains(signature) {
                seen.insert(signature)
                unique.append(index)
            }
        }
        
        return unique
    }
}

// MARK: - Partial Index

/// Helper for creating partial indexes
public final class PostgresPartialIndexBuilder {
    private let table: String
    private var name: String
    private var columns: [PostgresIndexColumn] = []
    private var type: PostgresIndexType = .btree
    private var options: PostgresIndexOptions = PostgresIndexOptions()
    
    public init(table: String) {
        self.table = table
        self.name = "idx_\(table)_\(UUID().uuidString.prefix(8))"
    }
    
    public func name(_ name: String) -> Self {
        self.name = name
        return self
    }
    
    public func type(_ type: PostgresIndexType) -> Self {
        self.type = type
        return self
    }
    
    public func column(_ column: String, desc: Bool = false, nullsFirst: Bool = false) -> Self {
        self.columns.append(PostgresIndexColumn(
            column: column,
            order: desc ? "DESC" : "ASC",
            nulls: nullsFirst ? "FIRST" : "LAST"
        ))
        return self
    }
    
    public func unique() -> Self {
        self.options.unique = true
        return self
    }
    
    public func concurrent() -> Self {
        self.options.concurrent = true
        return self
    }
    
    public func `where`(_ condition: String) -> Self {
        self.options.whereClause = condition
        return self
    }
    
    public func include(_ columns: String...) -> Self {
        self.options.include = columns
        return self
    }
    
    public func build() -> PostgresIndexDefinition {
        PostgresIndexDefinition(
            name: name,
            table: table,
            type: type,
            columns: columns,
            options: options
        )
    }
}

// MARK: - BRIN Index Helper

/// Helper for creating BRIN indexes (Block Range INdex) for time-series data
public final class PostgresBRINIndexBuilder {
    private let table: String
    private var name: String
    private var columns: [PostgresIndexColumn] = []
    private var type: PostgresIndexType = .brin
    private var options: PostgresIndexOptions = PostgresIndexOptions()
    
    public init(table: String) {
        self.table = table
        self.name = "brin_\(table)_\(UUID().uuidString.prefix(8))"
    }
    
    public func name(_ name: String) -> Self {
        self.name = name
        return self
    }
    
    public func column(_ column: String) -> Self {
        self.columns.append(PostgresIndexColumn(column: column))
        return self
    }
    
    public func pagesPerRange(_ count: Int) -> Self {
        self.options.`with` = ["pages_per_range": String(count)]
        return self
    }
    
    public func autovacuumEnabled(_ enabled: Bool) -> Self {
        var newWith = self.options.`with` ?? [:]
        newWith["autovacuum_enabled"] = String(enabled)
        self.options.`with` = newWith
        return self
    }
    
    public func build() -> PostgresIndexDefinition {
        PostgresIndexDefinition(
            name: name,
            table: table,
            type: type,
            columns: columns,
            options: options
        )
    }
    
    /// Create a BRIN index for time-series patterns
    public static func timeSeriesIndex(
        table: String,
        timeColumn: String,
        name: String? = nil
    ) -> PostgresIndexDefinition {
        let builder = PostgresBRINIndexBuilder(table: table)
        if let name { builder.name(name) }
        builder.column(timeColumn)
        return builder.build()
    }
}

// MARK: - Generated Column

/// Helper for creating generated columns
public final class PostgresGeneratedColumnBuilder {
    private let table: String
    private var name: String
    private var expression: String
    private var type: String?
    private var stored: Bool = false
    
    public init(table: String) {
        self.table = table
        self.name = ""
        self.expression = ""
    }
    
    public func column(_ name: String) -> Self {
        self.name = name
        return self
    }
    
    public func expression(_ expression: String) -> Self {
        self.expression = expression
        return self
    }
    
    public func type(_ type: String) -> Self {
        self.type = type
        return self
    }
    
    public func stored(_ stored: Bool = true) -> Self {
        self.stored = stored
        return self
    }
    
    public var addColumnSQL: String {
        let typeClause = type.map { " \($0)" } ?? ""
        let storedClause = stored ? " STORED" : ""
        return "ALTER TABLE \(table) ADD COLUMN IF NOT EXISTS \(name)\(typeClause) GENERATED ALWAYS AS (\(expression))\(storedClause)"
    }
    
    public var createIndexSQL: String {
        "CREATE INDEX IF NOT EXISTS idx_\(table)_\(name) ON \(table) (\(name))"
    }
}

// MARK: - JSONB Index Helper

/// Helper for creating GIN indexes on JSONB columns
public final class PostgresJSONBIndexBuilder {
    private let table: String
    private var name: String
    private var jsonbColumn: String
    private var path: String?
    private var type: PostgresIndexType = .gin
    private var options: PostgresIndexOptions = PostgresIndexOptions()
    
    public init(table: String, jsonbColumn: String) {
        self.table = table
        self.jsonbColumn = jsonbColumn
        self.name = "idx_\(table)_\(jsonbColumn)_\(UUID().uuidString.prefix(8))"
    }
    
    public func name(_ name: String) -> Self {
        self.name = name
        return self
    }
    
    public func path(_ path: String) -> Self {
        self.path = path
        return self
    }
    
    public func include(_ columns: String...) -> Self {
        self.options.include = columns
        return self
    }
    
    public func build() -> PostgresIndexDefinition {
        var columns = [PostgresIndexColumn(column: jsonbColumn)]
        
        if let path {
            // For JSONB path indexing, we use the expression directly
            columns = [PostgresIndexColumn(column: "(\(jsonbColumn) ->> '\(path)')")]
        }
        
        return PostgresIndexDefinition(
            name: name,
            table: table,
            type: type,
            columns: columns,
            options: options
        )
    }
    
    /// Create a GIN index on a JSONB column for full JSONB search
    public static func ginIndex(
        table: String,
        jsonbColumn: String,
        name: String? = nil
    ) -> PostgresIndexDefinition {
        let builder = PostgresJSONBIndexBuilder(table: table, jsonbColumn: jsonbColumn)
        if let name { builder.name(name) }
        return builder.build()
    }
    
    /// Create a GIN index on a JSONB array column
    public static func ginArrayIndex(
        table: String,
        jsonbColumn: String,
        path: String? = nil,
        name: String? = nil
    ) -> PostgresIndexDefinition {
        let builder = PostgresJSONBIndexBuilder(table: table, jsonbColumn: jsonbColumn)
        if let name { builder.name(name) }
        if let path { builder.path(path) }
        return builder.build()
    }
}

// MARK: - Index Usage Monitor

/// Monitors index usage statistics
public final class PostgresIndexUsageMonitor: Sendable {
    private let database: any DatabaseExecutor
    
    public init(database: any DatabaseExecutor) {
        self.database = database
    }
    
    /// Get index usage statistics
    public func getIndexUsageStats() async throws -> [PostgresIndexUsageStat] {
        let rows = try await database.query("""
            SELECT 
                schemaname as schema_name,
                relname as table_name,
                indexrelname as index_name,
                idx_scan as scans,
                idx_tup_read as tuples_read,
                idx_tup_fetch as tuples_fetched,
                n_live_tup as live_tuples,
                n_dead_tup as dead_tuples
            FROM pg_stat_user_indexes
            ORDER BY schemaname, relname, indexrelname
        """)
        
        return rows.compactMap { row in
            PostgresIndexUsageStat(
                schema: row.string(for: "schema_name") ?? "",
                table: row.string(for: "table_name") ?? "",
                index: row.string(for: "index_name") ?? "",
                scans: row.int64(for: "scans") ?? 0,
                tuplesRead: row.int64(for: "tuples_read") ?? 0,
                tuplesFetched: row.int64(for: "tuples_fetched") ?? 0,
                liveTuples: row.int64(for: "live_tuples") ?? 0,
                deadTuples: row.int64(for: "dead_tuples") ?? 0
            )
        }
    }
    
    /// Get unused indexes (never scanned)
    public func getUnusedIndexes() async throws -> [PostgresIndexUsageStat] {
        let stats = try await getIndexUsageStats()
        return stats.filter { $0.scans == 0 }
    }
    
    /// Get underutilized indexes (few scans relative to table size)
    public func getUnderutilizedIndexes(scanThreshold: Int64 = 10) async throws -> [PostgresIndexUsageStat] {
        let stats = try await getIndexUsageStats()
        return stats.filter { $0.scans < scanThreshold && $0.scans > 0 }
    }
    
    /// Reset index statistics
    public func resetStats() async throws {
        _ = try await database.execute("SELECT pg_stat_reset()")
    }
}

/// Index usage statistics
public struct PostgresIndexUsageStat: Sendable, Codable {
    public let schema: String
    public let table: String
    public let index: String
    public let scans: Int64
    public let tuplesRead: Int64
    public let tuplesFetched: Int64
    public let liveTuples: Int64
    public let deadTuples: Int64
    
    public var usageRatio: Double {
        guard liveTuples > 0 else { return 0 }
        return Double(scans) / Double(liveTuples)
    }
    
    public var isUnused: Bool { scans == 0 }
    
    public init(
        schema: String,
        table: String,
        index: String,
        scans: Int64,
        tuplesRead: Int64,
        tuplesFetched: Int64,
        liveTuples: Int64,
        deadTuples: Int64
    ) {
        self.schema = schema
        self.table = table
        self.index = index
        self.scans = scans
        self.tuplesRead = tuplesRead
        self.tuplesFetched = tuplesFetched
        self.liveTuples = liveTuples
        self.deadTuples = deadTuples
    }
}
