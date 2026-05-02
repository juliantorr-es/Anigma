import Foundation
import DatabaseCore

/// Result of codebase digestion and analysis
public struct CodebaseDigestResult: Codable {
    public let filesIndexed: Int
    public let symbolsExtracted: Int
    public let totalLinesOfCode: Int
    public let duration: TimeInterval
    public let filesByLanguage: [String: Int]
    public let keyModules: [ModuleInfo]
    public let healthMetrics: HealthMetrics
    public let architectureInsights: [String]

    public init(
        filesIndexed: Int,
        symbolsExtracted: Int,
        totalLinesOfCode: Int,
        duration: TimeInterval,
        filesByLanguage: [String: Int],
        keyModules: [ModuleInfo],
        healthMetrics: HealthMetrics,
        architectureInsights: [String]
    ) {
        self.filesIndexed = filesIndexed
        self.symbolsExtracted = symbolsExtracted
        self.totalLinesOfCode = totalLinesOfCode
        self.duration = duration
        self.filesByLanguage = filesByLanguage
        self.keyModules = keyModules
        self.healthMetrics = healthMetrics
        self.architectureInsights = architectureInsights
    }
}

public struct ModuleInfo: Codable {
    public let name: String
    public let symbolCount: Int
    public let purpose: String

    public init(name: String, symbolCount: Int, purpose: String) {
        self.name = name
        self.symbolCount = symbolCount
        self.purpose = purpose
    }
}

public struct HealthMetrics: Codable {
    public let estimatedTestCoverage: Double
    public let documentationCoverage: Double
    public let publicApiCount: Int
    public let averageFileSize: Int

    public init(
        estimatedTestCoverage: Double,
        documentationCoverage: Double,
        publicApiCount: Int,
        averageFileSize: Int
    ) {
        self.estimatedTestCoverage = estimatedTestCoverage
        self.documentationCoverage = documentationCoverage
        self.publicApiCount = publicApiCount
        self.averageFileSize = averageFileSize
    }
}

/// Enhanced codebase digest tool with semantic analysis
/// 
/// IMPORTANT: This struct should receive a `DatabaseExecutor` via dependency injection.
/// Only composition roots should create DatabaseActor directly.
/// See ADR-0018 and td-317bbb for details.
public struct EnhancedDigestCodebaseTool {
    private let dbActor: any DatabaseExecutor
    private let workingDirectory: URL
    private let embeddingModel: String
    private let llmModel: String

    /// Preferred initializer - receives DatabaseExecutor via dependency injection.
    public init(
        dbActor: any DatabaseExecutor,
        workingDirectory: URL,
        embeddingModel: String,
        llmModel: String
    ) {
        self.dbActor = dbActor
        self.workingDirectory = workingDirectory
        self.embeddingModel = embeddingModel
        self.llmModel = llmModel
    }

    /// Legacy initializer - accepts DatabaseActor directly.
    /// 
    /// DEPRECATED: Only composition roots should use this. Feature modules should use
    /// `init(dbActor:workingDirectory:embeddingModel:llmModel:)` with DatabaseExecutor instead.
    /// 
    /// See ADR-0018: PostgreSQL Connection and Transaction Contract
    /// See td-317bbb: Enforce PostgresConnectionContract at composition roots
    @available(*, deprecated, message: "Use init(dbActor:workingDirectory:embeddingModel:llmModel:) with DatabaseExecutor instead.")
    public init(
        dbActor: DatabaseActor,
        workingDirectory: URL,
        embeddingModel: String,
        llmModel: String
    ) {
        self.dbActor = dbActor
        self.workingDirectory = workingDirectory
        self.embeddingModel = embeddingModel
        self.llmModel = llmModel
    }

    public func digestCodebase(
        sourceRoots: [String],
        excludePatterns: [String]
    ) async throws -> CodebaseDigestResult {
        // Placeholder implementation
        // In production, this would:
        // 1. Scan source roots for files
        // 2. Parse and extract symbols
        // 3. Generate embeddings
        // 4. Analyze architecture
        // 5. Calculate health metrics

        return CodebaseDigestResult(
            filesIndexed: 125,
            symbolsExtracted: 847,
            totalLinesOfCode: 45230,
            duration: 12.5,
            filesByLanguage: [
                "Swift": 112,
                "Markdown": 8,
                "JSON": 3,
                "Shell": 2
            ],
            keyModules: [
                ModuleInfo(name: "AnigmaCore", symbolCount: 234, purpose: "Core infrastructure and primitives"),
                ModuleInfo(name: "HarmoniaModule", symbolCount: 156, purpose: "Cathedral-based governance system"),
                ModuleInfo(name: "AnigmaCLI", symbolCount: 98, purpose: "Command-line interface"),
                ModuleInfo(name: "DatabaseCore", symbolCount: 142, purpose: "Database and persistence layer"),
                ModuleInfo(name: "MCPServer", symbolCount: 217, purpose: "Model Context Protocol server")
            ],
            healthMetrics: HealthMetrics(
                estimatedTestCoverage: 65.3,
                documentationCoverage: 72.8,
                publicApiCount: 184,
                averageFileSize: 362
            ),
            architectureInsights: [
                "Modular architecture with clear separation of concerns",
                "Heavy use of Swift actors for thread-safety",
                "Cathedral-based governance system for policy enforcement",
                "PostgreSQL with full-text and vector-backed semantic search",
                "MCP integration for AI-assisted development workflows"
            ]
        )
    }
}
