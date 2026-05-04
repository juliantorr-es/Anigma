//
//  GovernanceIndexLoader.swift
//  AnigmaDaemon
//
//  Loads and provides access to the governance runtime index.
//

import Foundation
import AnigmaCore

/// Governance runtime index loaded from the generated JSON artifact.
public struct GovernanceRuntimeIndex: Sendable, Codable {
    public let version: String
    public let generatedAt: Date
    public let sourceCommit: SourceCommit
    public let sourceFiles: SourceFiles
    public let governancePolicies: [GovernancePolicy]
    public let tdTasks: [TDTask]
    public let validationResults: ValidationResults
    public let metadata: Metadata
    
    public init(
        version: String,
        generatedAt: Date,
        sourceCommit: SourceCommit,
        sourceFiles: SourceFiles,
        governancePolicies: [GovernancePolicy],
        tdTasks: [TDTask],
        validationResults: ValidationResults,
        metadata: Metadata
    ) {
        self.version = version
        self.generatedAt = generatedAt
        self.sourceCommit = sourceCommit
        self.sourceFiles = sourceFiles
        self.governancePolicies = governancePolicies
        self.tdTasks = tdTasks
        self.validationResults = validationResults
        self.metadata = metadata
    }
    
    /// Find a TD task by ID
    public func findTask(byId id: String) -> TDTask? {
        return tdTasks.first { $0.id == id }
    }
    
    /// Find governance policy by ID
    public func findPolicy(byId id: String) -> GovernancePolicy? {
        return governancePolicies.first { $0.id == id }
    }
    
    /// Get all tasks for a specific lane
    public func tasksForLane(_ lane: String) -> [TDTask] {
        return tdTasks.filter { $0.lane == lane }
    }
    
    /// Get all tasks with a specific priority
    public func tasksWithPriority(_ priority: String) -> [TDTask] {
        return tdTasks.filter { $0.priority == priority }
    }
    
    /// Check if the index is valid
    public var isValid: Bool {
        return validationResults.isValid
    }
}

/// Source commit information
public struct SourceCommit: Sendable, Codable {
    public let hash: String
    public let timestamp: Date
    public let message: String
    
    public init(hash: String, timestamp: Date, message: String) {
        self.hash = hash
        self.timestamp = timestamp
        self.message = message
    }
}

/// Source files used to generate the index
public struct SourceFiles: Sendable, Codable {
    public let tdRegistry: String
    public let governanceDocs: [String]
    public let schemas: [String]
    public let manifests: [String]
    
    public init(tdRegistry: String, governanceDocs: [String], schemas: [String], manifests: [String]) {
        self.tdRegistry = tdRegistry
        self.governanceDocs = governanceDocs
        self.schemas = schemas
        self.manifests = manifests
    }
}

/// Governance policy extracted from documentation
public struct GovernancePolicy: Sendable, Codable {
    public let id: String
    public let title: String
    public let description: String
    public let sourceFile: String
    public let validationRules: [ValidationRule]
    
    public init(id: String, title: String, description: String, sourceFile: String, validationRules: [ValidationRule]) {
        self.id = id
        self.title = title
        self.description = description
        self.sourceFile = sourceFile
        self.validationRules = validationRules
    }
}

/// Validation rule defined by a governance policy
public struct ValidationRule: Sendable, Codable {
    public let id: String
    public let name: String
    public let severity: String
    public let description: String
    
    public init(id: String, name: String, severity: String, description: String) {
        self.id = id
        self.name = name
        self.severity = severity
        self.description = description
    }
}

/// TD task from the registry
public struct TDTask: Sendable, Codable {
    public let id: String
    public let title: String
    public let priority: String
    public let type: String
    public let lane: String
    public let status: String
    public let description: String
    public let sourceDocs: [String]
    public let acceptance: [String]
    public let proof: [String]
    public let parent: String?
    public let children: [String]
    public let nonGoals: [String]
    
    public init(
        id: String,
        title: String,
        priority: String,
        type: String,
        lane: String,
        status: String,
        description: String,
        sourceDocs: [String],
        acceptance: [String],
        proof: [String],
        parent: String?,
        children: [String],
        nonGoals: [String]
    ) {
        self.id = id
        self.title = title
        self.priority = priority
        self.type = type
        self.lane = lane
        self.status = status
        self.description = description
        self.sourceDocs = sourceDocs
        self.acceptance = acceptance
        self.proof = proof
        self.parent = parent
        self.children = children
        self.nonGoals = nonGoals
    }
    
    /// Check if task is complete
    public var isComplete: Bool {
        return status == "complete"
    }
    
    /// Check if task is in progress
    public var isInProgress: Bool {
        return status == "in_progress" || status == "in_review"
    }
    
    /// Check if task is blocked
    public var isBlocked: Bool {
        return status == "blocked"
    }
}

/// Validation results for the index
public struct ValidationResults: Sendable, Codable {
    public let isValid: Bool
    public let timestamp: Date
    public let validatorVersion: String
    public let warnings: [ValidationIssue]
    public let errors: [ValidationIssue]
    
    public init(
        isValid: Bool,
        timestamp: Date,
        validatorVersion: String,
        warnings: [ValidationIssue],
        errors: [ValidationIssue]
    ) {
        self.isValid = isValid
        self.timestamp = timestamp
        self.validatorVersion = validatorVersion
        self.warnings = warnings
        self.errors = errors
    }
}

/// Validation issue (warning or error)
public struct ValidationIssue: Sendable, Codable {
    public let code: String
    public let message: String
    public let severity: String
    public let details: [String: String]?
    
    public init(code: String, message: String, severity: String, details: [String: String]? = nil) {
        self.code = code
        self.message = message
        self.severity = severity
        self.details = details
    }
}

/// Additional metadata about index generation
public struct Metadata: Sendable, Codable {
    public let generatorVersion: String
    public let generatorTimestamp: Date
    public let repository: String
    public let additionalNotes: String
    
    public init(
        generatorVersion: String,
        generatorTimestamp: Date,
        repository: String,
        additionalNotes: String
    ) {
        self.generatorVersion = generatorVersion
        self.generatorTimestamp = generatorTimestamp
        self.repository = repository
        self.additionalNotes = additionalNotes
    }
}

/// Loader for governance runtime index
public actor GovernanceIndexLoader {
    private var index: GovernanceRuntimeIndex?
    private let indexPath: String
    private let logger: Logger
    
    public init(indexPath: String = ".build/governance-runtime-index.json") {
        self.indexPath = indexPath
        self.logger = Logger(subsystem: "com.anigma.daemon", category: "governance")
    }
    
    /// Load the governance index from file
    public func load() async throws -> GovernanceRuntimeIndex {
        if let cachedIndex = index {
            return cachedIndex
        }
        
        let fileURL = URL(fileURLWithPath: indexPath)
        logger.info("Loading governance index from: \\{private}", fileURL.path)
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            
            // Configure date decoding
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            
            let loadedIndex = try decoder.decode(GovernanceRuntimeIndex.self, from: data)
            
            if !loadedIndex.isValid {
                logger.warning("Loaded governance index has validation issues")
                for error in loadedIndex.validationResults.errors {
                    logger.warning("Validation error: \\{private}", error.message)
                }
            }
            
            index = loadedIndex
            logger.info("Successfully loaded governance index with \\{private} tasks and \\{private} policies",
                       loadedIndex.tdTasks.count, loadedIndex.governancePolicies.count)
            
            return loadedIndex
        } catch {
            logger.error("Failed to load governance index: \\{private}", error.localizedDescription)
            throw GovernanceIndexError.loadFailed(error)
        }
    }
    
    /// Reload the governance index
    public func reload() async throws -> GovernanceRuntimeIndex {
        index = nil
        return try await load()
    }
    
    /// Get the current governance policy for a specific check
    public func governancePolicy(forCheckId checkId: String) -> GovernancePolicy? {
        guard let currentIndex = index else { return nil }
        
        for policy in currentIndex.governancePolicies {
            if policy.validationRules.contains(where: { $0.id == checkId }) {
                return policy
            }
        }
        return nil
    }
}

/// Governance index errors
public enum GovernanceIndexError: Error {
    case loadFailed(Error)
    case notLoaded
    case invalidIndex
    
    public var localizedDescription: String {
        switch self {
        case .loadFailed(let error):
            return "Failed to load governance index: \(error.localizedDescription)"
        case .notLoaded:
            return "Governance index not loaded"
        case .invalidIndex:
            return "Governance index is invalid"
        }
    }
}

// MARK: - Date Coding

extension GovernanceRuntimeIndex {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        version = try container.decode(String.self, forKey: .version)
        
        let generatedAtString = try container.decode(String.self, forKey: .generatedAt)
        if let date = GovernanceRuntimeIndex.dateFormatter.date(from: generatedAtString) {
            generatedAt = date
        } else {
            throw DecodingError.dataCorruptedError(forKey: .generatedAt, in: container, debugDescription: "Invalid date format")
        }
        
        sourceCommit = try container.decode(SourceCommit.self, forKey: .sourceCommit)
        sourceFiles = try container.decode(SourceFiles.self, forKey: .sourceFiles)
        governancePolicies = try container.decode([GovernancePolicy].self, forKey: .governancePolicies)
        tdTasks = try container.decode([TDTask].self, forKey: .tdTasks)
        validationResults = try container.decode(ValidationResults.self, forKey: .validationResults)
        metadata = try container.decode(Metadata.self, forKey: .metadata)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(version, forKey: .version)
        try container.encode(GovernanceRuntimeIndex.dateFormatter.string(from: generatedAt), forKey: .generatedAt)
        try container.encode(sourceCommit, forKey: .sourceCommit)
        try container.encode(sourceFiles, forKey: .sourceFiles)
        try container.encode(governancePolicies, forKey: .governancePolicies)
        try container.encode(tdTasks, forKey: .tdTasks)
        try container.encode(validationResults, forKey: .validationResults)
        try container.encode(metadata, forKey: .metadata)
    }
}
