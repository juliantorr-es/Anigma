//
//  DatabaseConfiguration.swift
//  DatabaseCore
//
//  Configuration for database connection settings.
//  PostgreSQL is the first-class and ONLY supported database.
//  SQLite is deprecated and no longer supported.
//

import Foundation

public enum DatabaseConfiguration {
    /// Returns the default database connection string.
    /// PostgreSQL is the first-class and ONLY supported database.
    /// SQLite is deprecated and no longer supported.
    ///
    /// Priority:
    /// 1. ANIGMA_DB_URL environment variable (if set) - PostgreSQL connection string
    /// 2. ANIGMA_DB_PATH environment variable (if set) - PostgreSQL connection string
    /// 3. Local default Postgres URL
    ///
    /// Note: SQLite paths (file paths without `://`) are deprecated and will be removed.
    /// All database connections must use PostgreSQL connection strings.
    public static func defaultDatabasePath() -> String {
        if let envURL = ProcessInfo.processInfo.environment["ANIGMA_DB_URL"],
           !envURL.isEmpty {
            // Validate that this is a PostgreSQL connection string
            if envURL.contains("://") {
                return envURL
            }
            // Deprecated: SQLite file path - should be migrated to PostgreSQL
            FileHandle.standardError.write("WARNING: ANIGMA_DB_URL appears to be a file path (SQLite). PostgreSQL connection strings are required. Falling back to default.\n".data(using: .utf8)!)
        }

        if let envPath = ProcessInfo.processInfo.environment["ANIGMA_DB_PATH"],
           !envPath.isEmpty {
            // Validate that this is a PostgreSQL connection string
            if envPath.contains("://") {
                return envPath
            }
            // Deprecated: SQLite file path - should be migrated to PostgreSQL
            FileHandle.standardError.write("WARNING: ANIGMA_DB_PATH appears to be a file path (SQLite). PostgreSQL connection strings are required. Falling back to default.\n".data(using: .utf8)!)
        }

        // PostgreSQL is the only supported database - first-class
        return "postgres://postgres@localhost/postgres"
    }

    /// Validates that a database path is a valid PostgreSQL connection string.
    /// SQLite file paths are deprecated and will generate warnings.
    public static func validatePostgreSQLConnectionString(_ path: String) -> Bool {
        // PostgreSQL connection strings contain ://
        // SQLite paths are file paths without ://
        if path.contains("://") {
            return path.lowercased().hasPrefix("postgres://") || path.lowercased().hasPrefix("postgresql://")
        }
        return false
    }

    /// Prints the database path and detection logic to stderr (for debugging).
    public static func printDatabasePathInfo() {
        let defaultPath = defaultDatabasePath()

        fputs("PostgreSQL Database Connection Resolution:\n", stderr)
        fputs("  ANIGMA_DB_URL: \(ProcessInfo.processInfo.environment["ANIGMA_DB_URL"] ?? "(not set)")\n", stderr)
        fputs("  ANIGMA_DB_PATH: \(ProcessInfo.processInfo.environment["ANIGMA_DB_PATH"] ?? "(not set)")\n", stderr)
        fputs("  Selected PostgreSQL target: \(defaultPath)\n", stderr)
        fputs("  Note: SQLite is deprecated. Only PostgreSQL connection strings are supported.\n", stderr)
    }
}
