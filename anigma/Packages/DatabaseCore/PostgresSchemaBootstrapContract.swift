import Foundation

public struct PostgresMigrationStep: Sendable, Codable, Equatable {
    public let version: Int
    public let identifier: String
    public let module: String
    public let requiredExtensions: [String]
    public let requiredTables: [String]
    public let applySQL: String
    public let rollbackSQL: String?
    public let rollbackExpectation: String

    public init(
        version: Int,
        identifier: String,
        module: String,
        requiredExtensions: [String] = [],
        requiredTables: [String] = [],
        applySQL: String,
        rollbackSQL: String? = nil,
        rollbackExpectation: String
    ) {
        self.version = version
        self.identifier = identifier
        self.module = module
        self.requiredExtensions = requiredExtensions
        self.requiredTables = requiredTables
        self.applySQL = applySQL
        self.rollbackSQL = rollbackSQL
        self.rollbackExpectation = rollbackExpectation
    }
}

public struct PostgresSchemaValidationReport: Sendable, Codable, Equatable {
    public let expectedVersion: Int
    public let appliedVersion: Int
    public let missingExtensions: [String]
    public let missingTables: [String]
    public let validatedAt: Date

    public init(
        expectedVersion: Int,
        appliedVersion: Int,
        missingExtensions: [String],
        missingTables: [String],
        validatedAt: Date = Date()
    ) {
        self.expectedVersion = expectedVersion
        self.appliedVersion = appliedVersion
        self.missingExtensions = missingExtensions
        self.missingTables = missingTables
        self.validatedAt = validatedAt
    }

    public var isSatisfied: Bool {
        appliedVersion >= expectedVersion && missingExtensions.isEmpty && missingTables.isEmpty
    }
}

public enum PostgresSchemaBootstrapError: Error, CustomStringConvertible, Equatable {
    case emptyPlan
    case nonContiguousVersion(expected: Int, actual: Int)
    case duplicateIdentifier(String)
    case missingRollbackExpectation(String)
    case liveValidationFailed(PostgresSchemaValidationReport)

    public var description: String {
        switch self {
        case .emptyPlan:
            return "PostgreSQL schema bootstrap plan must contain at least one migration."
        case let .nonContiguousVersion(expected, actual):
            return "PostgreSQL migration versions must be contiguous; expected \(expected), got \(actual)."
        case let .duplicateIdentifier(identifier):
            return "Duplicate PostgreSQL migration identifier: \(identifier)."
        case let .missingRollbackExpectation(identifier):
            return "PostgreSQL migration '\(identifier)' must declare rollback or recovery expectations."
        case let .liveValidationFailed(report):
            return "PostgreSQL schema validation failed: missing tables \(report.missingTables), missing extensions \(report.missingExtensions), applied version \(report.appliedVersion), expected \(report.expectedVersion)."
        }
    }
}

public struct PostgresSchemaBootstrapContract: Sendable, Codable, Equatable {
    public let contractID: String
    public let expectedVersion: Int
    public let migrations: [PostgresMigrationStep]
    public let requiredExtensions: [String]
    public let requiredTables: [String]

    public init(
        contractID: String = "postgres.schema.bootstrap.v1",
        migrations: [PostgresMigrationStep]
    ) throws {
        self.contractID = contractID
        self.migrations = migrations.sorted { $0.version < $1.version }
        self.expectedVersion = self.migrations.last?.version ?? 0
        self.requiredExtensions = Array(Set(self.migrations.flatMap(\.requiredExtensions))).sorted()
        self.requiredTables = Array(Set(self.migrations.flatMap(\.requiredTables))).sorted()
        try Self.validate(migrations: self.migrations)
    }

    public static func validate(migrations: [PostgresMigrationStep]) throws {
        guard !migrations.isEmpty else {
            throw PostgresSchemaBootstrapError.emptyPlan
        }

        var identifiers = Set<String>()
        for (offset, migration) in migrations.sorted(by: { $0.version < $1.version }).enumerated() {
            let expectedVersion = offset + 1
            guard migration.version == expectedVersion else {
                throw PostgresSchemaBootstrapError.nonContiguousVersion(
                    expected: expectedVersion,
                    actual: migration.version
                )
            }
            guard identifiers.insert(migration.identifier).inserted else {
                throw PostgresSchemaBootstrapError.duplicateIdentifier(migration.identifier)
            }
            guard !migration.rollbackExpectation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw PostgresSchemaBootstrapError.missingRollbackExpectation(migration.identifier)
            }
        }
    }

    public static func canonical() throws -> PostgresSchemaBootstrapContract {
        try PostgresSchemaBootstrapContract(migrations: [
            PostgresMigrationStep(
                version: 1,
                identifier: "postgres.schema.registry",
                module: "DatabaseCore",
                requiredTables: ["schema_registry"],
                applySQL: """
                    CREATE TABLE IF NOT EXISTS schema_registry (
                        name TEXT PRIMARY KEY,
                        module TEXT NOT NULL,
                        version INTEGER NOT NULL,
                        migrated_at INTEGER NOT NULL
                    );
                    """,
                rollbackSQL: "DROP TABLE IF EXISTS schema_registry;",
                rollbackExpectation: "Allowed only before runtime tables are bootstrapped."
            ),
            PostgresMigrationStep(
                version: 2,
                identifier: "postgres.runtime.jobs",
                module: "DatabaseCore",
                requiredTables: ["contract_jobs", "refinement_jobs", "contract_receipts"],
                applySQL: "SELECT 'runtime jobs migrated';",
                rollbackExpectation: "Forward-fix preferred; restore from latest verified backup for production rollback."
            ),
            PostgresMigrationStep(
                version: 3,
                identifier: "postgres.runtime.artifacts",
                module: "DatabaseCore",
                requiredTables: ["artifacts", "vault_artifacts", "vault_edges", "vault_access_log"],
                applySQL: "SELECT 'runtime artifacts migrated';",
                rollbackExpectation: "Forward-fix preferred; artifact metadata rollback requires receipt-preserving backup restore."
            )
        ])
    }

    public func validateLiveCatalog(using db: any DatabaseExecutor) async throws -> PostgresSchemaValidationReport {
        let versionRows = try await db.query(
            "SELECT version FROM schema_registry WHERE name = ?",
            parameters: [.text(contractID)]
        )
        let appliedVersion = versionRows.first?.int(for: "version") ?? 0

        let tableRows = try await db.query(
            """
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = current_schema()
            """
        )
        let liveTables = Set(tableRows.compactMap { $0.string(for: "table_name") })

        let extensionRows = try await db.query("SELECT extname FROM pg_extension")
        let liveExtensions = Set(extensionRows.compactMap { $0.string(for: "extname") })

        let report = PostgresSchemaValidationReport(
            expectedVersion: expectedVersion,
            appliedVersion: appliedVersion,
            missingExtensions: requiredExtensions.filter { !liveExtensions.contains($0) },
            missingTables: requiredTables.filter { !liveTables.contains($0) }
        )

        guard report.isSatisfied else {
            throw PostgresSchemaBootstrapError.liveValidationFailed(report)
        }
        return report
    }
}

