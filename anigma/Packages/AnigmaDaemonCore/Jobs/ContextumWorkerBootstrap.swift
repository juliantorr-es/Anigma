import Foundation
import AnigmaCore
import DatabaseCore
import ContextumModule

enum ContextumWorkerBootstrap {
    // PostgreSQL is now the first-class database - SQLite is deprecated
    // These legacy paths are kept for historical reference only
    @available(*, deprecated, message: "SQLite is deprecated. Use PostgreSQL connection strings instead.")
    private static let canonicalDatabaseFilename = "platform_runtime.db"
    @available(*, deprecated, message: "SQLite is deprecated. Use PostgreSQL connection strings instead.")
    private static let legacyDatabaseRelativePath = ".anigma/anigma.db"

    static func openDatabase() async throws -> ContextumDatabase {
        try await openDatabase(pathOverride: nil)
    }

    static func openDatabase(at dbPath: String) async throws -> ContextumDatabase {
        try await openDatabase(pathOverride: dbPath)
    }

    static func openDatabase(pathOverride: String?) async throws -> ContextumDatabase {
        let resolvedPath = try resolveDatabasePath(pathOverride: pathOverride)
        // PostgreSQL is now the first-class database - legacy SQLite migration is deprecated
        // try migrateLegacyDatabaseIfNeeded(canonicalPath: resolvedPath)

        let dbActor = DatabaseActor(path: resolvedPath)
        try await dbActor.open()

        let governance = GovernanceController()
        await governance.initialize()

        let databaseAuthority = DatabaseAuthorityImpl(
            databaseActor: dbActor,
            governance: governance,
            evidenceAuthority: nil
        )
        let contextumDatabase = ContextumDatabase(databaseAuthority: databaseAuthority)
        await contextumDatabase.setDatabasePath(resolvedPath)

        try await contextumDatabase.migrate()
        return contextumDatabase
    }

    private static func resolveDatabasePath(pathOverride: String?) throws -> String {
        // PostgreSQL is now the first-class database - always use connection string
        if let explicitPath = pathOverride?.trimmingCharacters(in: .whitespacesAndNewlines),
           !explicitPath.isEmpty {
            return explicitPath
        }

        let environment = ProcessInfo.processInfo.environment
        if let contextumPath = environment["ANIGMA_CONTEXTUM_DB_PATH"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !contextumPath.isEmpty {
            return contextumPath
        }

        if let runtimePath = environment["ANIGMA_DB_PATH"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !runtimePath.isEmpty {
            return runtimePath
        }

        // Default to PostgreSQL connection string
        return DatabaseConfiguration.defaultDatabasePath()
    }

    @available(*, deprecated, message: "SQLite is deprecated. Use PostgreSQL connection strings instead.")
    private static func migrateLegacyDatabaseIfNeeded(canonicalPath: String) throws {
        let legacyPath = normalizedPath((NSHomeDirectory() as NSString).appendingPathComponent(legacyDatabaseRelativePath))
        let targetPath = normalizedPath(canonicalPath)
        guard legacyPath != targetPath else { return }

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: legacyPath),
              !fileManager.fileExists(atPath: targetPath) else { return }

        let destinationDirectory = URL(fileURLWithPath: targetPath).deletingLastPathComponent()
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        try copyDatabaseFileFamily(from: legacyPath, to: targetPath)
    }

    @available(*, deprecated, message: "SQLite is deprecated. Use PostgreSQL connection strings instead.")
    private static func copyDatabaseFileFamily(from sourceBasePath: String, to destinationBasePath: String) throws {
        let fileManager = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let sourcePath = sourceBasePath + suffix
            guard fileManager.fileExists(atPath: sourcePath) else { continue }
            let destinationPath = destinationBasePath + suffix
            guard !fileManager.fileExists(atPath: destinationPath) else { continue }
            try fileManager.copyItem(atPath: sourcePath, toPath: destinationPath)
        }
    }

    private static func normalizedPath(_ rawPath: String) -> String {
        let expanded = (rawPath as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") || expanded.hasPrefix(":") {
            return (expanded as NSString).standardizingPath
        }

        let absolute = (FileManager.default.currentDirectoryPath as NSString).appendingPathComponent(expanded)
        return (absolute as NSString).standardizingPath
    }
}
