import Foundation

public enum PostgresCompositionRoot: String, Sendable, Codable, CaseIterable {
    case anigmaDaemon
    case anigmaApp
    case commandLineTool
    case mcpServer
    case platformRuntime
    case testHarness

    /// Module name prefixes that correspond to this composition root.
    /// Used for runtime contract enforcement in DatabaseActor (see td-317bbb).
    /// 
    /// These prefixes are matched against the calling module name extracted from the stack trace.
    public var modulePrefixes: [String] {
        switch self {
        case .anigmaDaemon:
            return ["AnigmaDaemonCore", "AnigmaDaemon"]
        case .anigmaApp:
            return ["AnigmaAppMac"]
        case .commandLineTool:
            return ["HarmoniaCLI", "AnigmaCLI", "AccessumFlow"]
        case .mcpServer:
            return ["AnigmaMCP"]
        case .platformRuntime:
            return ["AnigmaCore"] // PlatformRuntime in AnigmaCore package
        case .testHarness:
            return ["Test", "DatabaseCore"] // DatabaseCore for PostgresCutoverUtility
        }
    }

    /// All approved module prefixes across all composition roots.
    /// Used by DatabaseActor to enforce the contract at runtime.
    /// 
    /// See ADR-0018: PostgreSQL Connection and Transaction Contract
    /// See td-317bbb: Enforce PostgresConnectionContract at composition roots
    public static var allApprovedModulePrefixes: Set<String> {
        Set(allCases.flatMap { $0.modulePrefixes })
    }
}

public enum PostgresQueryIntent: String, Sendable, Codable, CaseIterable {
    case read
    case write
    case schema
    case maintenance
}

public enum PostgresTransactionIsolation: String, Sendable, Codable, CaseIterable {
    case readCommitted
    case repeatableRead
    case serializable
}

public enum PostgresRetryClass: String, Sendable, Codable, CaseIterable {
    case none
    case transientConnection
    case serializationFailure
    case deadlock
}

public struct PostgresRetryPolicy: Sendable, Codable, Equatable {
    public let maxAttempts: Int
    public let initialBackoffMilliseconds: Int
    public let maximumBackoffMilliseconds: Int
    public let retryableClasses: Set<PostgresRetryClass>

    public init(
        maxAttempts: Int,
        initialBackoffMilliseconds: Int,
        maximumBackoffMilliseconds: Int,
        retryableClasses: Set<PostgresRetryClass>
    ) {
        self.maxAttempts = maxAttempts
        self.initialBackoffMilliseconds = initialBackoffMilliseconds
        self.maximumBackoffMilliseconds = maximumBackoffMilliseconds
        self.retryableClasses = retryableClasses
    }

    public static let canonical = PostgresRetryPolicy(
        maxAttempts: 3,
        initialBackoffMilliseconds: 100,
        maximumBackoffMilliseconds: 1_000,
        retryableClasses: [.transientConnection, .serializationFailure, .deadlock]
    )
}

public struct PostgresQueryShape: Sendable, Codable, Equatable {
    public let intent: PostgresQueryIntent
    public let requiresParameters: Bool
    public let allowsRawSQL: Bool
    public let allowedThroughExecutor: Bool

    public init(
        intent: PostgresQueryIntent,
        requiresParameters: Bool,
        allowsRawSQL: Bool,
        allowedThroughExecutor: Bool
    ) {
        self.intent = intent
        self.requiresParameters = requiresParameters
        self.allowsRawSQL = allowsRawSQL
        self.allowedThroughExecutor = allowedThroughExecutor
    }
}

public struct PostgresTransactionRule: Sendable, Codable, Equatable {
    public let isolation: PostgresTransactionIsolation
    public let readOnly: Bool
    public let savepointsRequiredForNestedWork: Bool
    public let retryPolicy: PostgresRetryPolicy

    public init(
        isolation: PostgresTransactionIsolation,
        readOnly: Bool,
        savepointsRequiredForNestedWork: Bool,
        retryPolicy: PostgresRetryPolicy
    ) {
        self.isolation = isolation
        self.readOnly = readOnly
        self.savepointsRequiredForNestedWork = savepointsRequiredForNestedWork
        self.retryPolicy = retryPolicy
    }
}

public struct PostgresConnectionContract: Sendable, Codable, Equatable {
    public let contractID: String
    public let supportedCompositionRoots: Set<PostgresCompositionRoot>
    public let queryShapes: [PostgresQueryShape]
    public let defaultTransactionRule: PostgresTransactionRule
    public let lowLevelActorIsCompositionRootOnly: Bool
    public let featureModulesConsumeDatabaseExecutor: Bool

    public init(
        contractID: String = "postgres.connection.transaction.v1",
        supportedCompositionRoots: Set<PostgresCompositionRoot>,
        queryShapes: [PostgresQueryShape],
        defaultTransactionRule: PostgresTransactionRule,
        lowLevelActorIsCompositionRootOnly: Bool,
        featureModulesConsumeDatabaseExecutor: Bool
    ) throws {
        self.contractID = contractID
        self.supportedCompositionRoots = supportedCompositionRoots
        self.queryShapes = queryShapes
        self.defaultTransactionRule = defaultTransactionRule
        self.lowLevelActorIsCompositionRootOnly = lowLevelActorIsCompositionRootOnly
        self.featureModulesConsumeDatabaseExecutor = featureModulesConsumeDatabaseExecutor
        try Self.validate(self)
    }

    public static func canonical() throws -> PostgresConnectionContract {
        try PostgresConnectionContract(
            supportedCompositionRoots: [.anigmaDaemon, .anigmaApp, .commandLineTool, .mcpServer, .platformRuntime, .testHarness],
            queryShapes: [
                PostgresQueryShape(
                    intent: .read,
                    requiresParameters: true,
                    allowsRawSQL: false,
                    allowedThroughExecutor: true
                ),
                PostgresQueryShape(
                    intent: .write,
                    requiresParameters: true,
                    allowsRawSQL: false,
                    allowedThroughExecutor: true
                ),
                PostgresQueryShape(
                    intent: .schema,
                    requiresParameters: false,
                    allowsRawSQL: true,
                    allowedThroughExecutor: true
                ),
                PostgresQueryShape(
                    intent: .maintenance,
                    requiresParameters: false,
                    allowsRawSQL: true,
                    allowedThroughExecutor: true
                )
            ],
            defaultTransactionRule: PostgresTransactionRule(
                isolation: .readCommitted,
                readOnly: false,
                savepointsRequiredForNestedWork: true,
                retryPolicy: .canonical
            ),
            lowLevelActorIsCompositionRootOnly: true,
            featureModulesConsumeDatabaseExecutor: true
        )
    }

    public static func validate(_ contract: PostgresConnectionContract) throws {
        guard !contract.supportedCompositionRoots.isEmpty else {
            throw PostgresConnectionContractError.missingCompositionRoot
        }
        guard Set(contract.queryShapes.map(\.intent)) == Set(PostgresQueryIntent.allCases) else {
            throw PostgresConnectionContractError.incompleteQueryShapeCoverage
        }
        guard contract.lowLevelActorIsCompositionRootOnly else {
            throw PostgresConnectionContractError.lowLevelActorBoundaryOpen
        }
        guard contract.featureModulesConsumeDatabaseExecutor else {
            throw PostgresConnectionContractError.featureModuleBypassAllowed
        }
        guard contract.defaultTransactionRule.savepointsRequiredForNestedWork else {
            throw PostgresConnectionContractError.missingSavepointRequirement
        }
        guard contract.defaultTransactionRule.retryPolicy.maxAttempts >= 1 else {
            throw PostgresConnectionContractError.invalidRetryPolicy
        }
    }
}

public enum PostgresConnectionContractError: Error, CustomStringConvertible, Equatable {
    case missingCompositionRoot
    case incompleteQueryShapeCoverage
    case lowLevelActorBoundaryOpen
    case featureModuleBypassAllowed
    case missingSavepointRequirement
    case invalidRetryPolicy

    public var description: String {
        switch self {
        case .missingCompositionRoot:
            return "PostgreSQL contract must declare at least one approved composition root."
        case .incompleteQueryShapeCoverage:
            return "PostgreSQL contract must define read, write, schema, and maintenance query shapes."
        case .lowLevelActorBoundaryOpen:
            return "PostgreSQL low-level actor construction must stay composition-root-only."
        case .featureModuleBypassAllowed:
            return "Feature modules must consume DatabaseExecutor instead of bypassing the contract."
        case .missingSavepointRequirement:
            return "Nested PostgreSQL transactional work must require savepoints."
        case .invalidRetryPolicy:
            return "PostgreSQL retry policy must allow at least one attempt."
        }
    }
}
