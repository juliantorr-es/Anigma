import Foundation
import AnigmaCore
import AnigmaPrimitives
import DatabaseCore
import CryptoKit

public struct Contextum: Sendable {
    public let database: ContextumDatabase
    private let ingestSystem: IngestNormalizeSystem
    private let chunkingSystem: ChunkingSystem
    private let searchSystem: HybridSearchSystem
    private let statsSystem: AgentStatsAggregateSystem
    private let ftsSystem: FtsIndexSystem
    private let layoutIndexingSystem: LayoutIndexingSystem
    private let documentTruthLane: DocumentTruthIngestLane
    private let sourceGraphDocumentAdapter: LocalDocumentSourceGraphAdapter
    private let sourceGraphNoteAdapter: LocalNoteSourceGraphAdapter

    public init(
        databaseAuthority: any AnigmaFoundation.DatabaseAuthority,
        artifactAuthority: (any ArtifactAuthority)? = nil,
        preprocessingConfiguration: TextPreprocessingConfiguration = .ingestDefault,
        preprocessingPolicyOptions: TextPreprocessingPolicyOptions? = nil
    ) async throws {
        let effectivePreprocessingConfiguration = try preprocessingPolicyOptions?
            .applying(to: preprocessingConfiguration) ?? preprocessingConfiguration
        self.database = ContextumDatabase(databaseExecutor: DatabaseAuthorityAdapter(databaseAuthority: databaseAuthority), artifactAuthority: artifactAuthority)
        try await database.migrate()

        self.ingestSystem = IngestNormalizeSystem(
            database: database,
            preprocessingConfiguration: effectivePreprocessingConfiguration
        )
        self.chunkingSystem = ChunkingSystem(database: database)
        self.searchSystem = HybridSearchSystem(database: database)
        self.statsSystem = AgentStatsAggregateSystem(database: database)
        self.ftsSystem = FtsIndexSystem(database: database)
        self.layoutIndexingSystem = LayoutIndexingSystem(database: database)
        self.documentTruthLane = DocumentTruthIngestLane(
            database: database,
            preprocessingConfiguration: effectivePreprocessingConfiguration
        )
        self.sourceGraphDocumentAdapter = LocalDocumentSourceGraphAdapter(
            preprocessingConfiguration: effectivePreprocessingConfiguration
        )
        self.sourceGraphNoteAdapter = LocalNoteSourceGraphAdapter(
            documentAdapter: sourceGraphDocumentAdapter
        )
    }

    // MARK: - Job-based API

    public func ingest(source: ContextSourceComponent) async throws {
        try await ingestSystem.process(source: source)
    }

    public func ingestDocumentTruth(
        source: ContextSourceComponent,
        input: DocumentTruthIngestInput
    ) async throws -> DocumentTruthIngestReceipt {
        try await documentTruthLane.ingest(source: source, input: input)
    }

    public func buildSourceGraphDocument(
        source: ContextSourceComponent,
        input: DocumentTruthIngestInput
    ) async throws -> SourceGraphDocument {
        try await sourceGraphDocumentAdapter.buildGraph(from: input, source: source)
    }

    public func buildSourceGraphNote(
        source: ContextSourceComponent,
        note: LocalNoteIngestInput
    ) async throws -> SourceGraphDocument {
        try await sourceGraphNoteAdapter.buildGraph(from: note, source: source)
    }

    public func chunk(sourceId: String, content: String) async throws -> [ChunkComponent] {
        try await chunkingSystem.process(sourceId: sourceId, content: content)
    }

    public func indexPDFLayout(
        sourceId: String,
        layoutOutput: PDFLayoutOutput,
        chunkPrefix: String = "pdf-"
    ) async throws -> [ChunkComponent] {
        try await layoutIndexingSystem.processPDFLayout(
            sourceId: sourceId,
            layoutOutput: layoutOutput,
            chunkPrefix: chunkPrefix
        )
    }

    public func search(request: HybridSearchSystem.SearchRequest) async throws -> HybridSearchSystem.SearchResult {
        let enhancedResult = try await searchSystem.search(request)
        return HybridSearchSystem.SearchResult(
            chunks: enhancedResult.chunks.map {
                HybridSearchSystem.SearchResultChunk(
                    chunkId: $0.chunkId,
                    content: $0.content,
                    sourceId: $0.sourceId,
                    score: $0.score
                )
            },
            totalResults: enhancedResult.totalResults
        )
    }

    public func recordAgentExecution(
        agentId: String,
        taskTaxonomy: String,
        durationMs: Int,
        outcome: TelemetryEventComponent.Outcome,
        errorCode: String? = nil
    ) async throws {
        try await statsSystem.recordExecution(
            agentId: agentId,
            taskTaxonomy: taskTaxonomy,
            durationMs: durationMs,
            outcome: outcome,
            errorCode: errorCode
        )
    }

    public func getAgentStats(agentId: String, taskTaxonomy: String) async throws -> AgentStatsComponent? {
        try await statsSystem.getStats(agentId: agentId, taskTaxonomy: taskTaxonomy)
    }

    // MARK: - Forensics (Phase 4 - Placeholder)

    public func generateFailureReport(
        subjectReceiptID: String,
        subjectRunID: UUID?,
        subjectWorkflowID: UUID?
    ) async throws -> (reportID: UUID, artifactHash: String) {
        let runID = subjectRunID?.uuidString ?? subjectReceiptID
        let report = try await FailureReportWorkflow.execute(
            database: database,
            receiptID: subjectReceiptID,
            runID: runID,
            comparisonCriteria: nil
        )
        
        // Compute artifact hash from report JSON
        let reportJSON = try JSONEncoder().encode(report)
        let artifactHash = BLAKE3Digest.hex(of: reportJSON)
        
        // Insert failure report into database and get generated report ID
        let reportIDString = try await database.insertFailureReport(report)
        guard let reportID = UUID(uuidString: reportIDString) else {
            throw ContextumError.databaseError("Invalid report ID generated")
        }
        
        // Also insert forensics component for compatibility
        let forensicsComponent = ForensicsComponent(
            reportID: reportID,
            subjectReceiptID: subjectReceiptID,
            subjectRunID: subjectRunID,
            subjectWorkflowID: subjectWorkflowID,
            investigationType: .failureReport,
            reportArtifactHash: artifactHash
        )
        try await database.insertForensicsReport(forensicsComponent)
        
        return (reportID, artifactHash)
    }

    public func queryForensicsReport(receiptID: String) async throws -> ForensicsComponent? {
        try await database.queryForensicsReport(receiptID: receiptID)
    }

    @available(*, deprecated, message: "Use databaseAuthority: instead.")
    public init(
        dbActor: DatabaseAuthorityAdapter,
        artifactAuthority: (any ArtifactAuthority)? = nil,
        preprocessingConfiguration: TextPreprocessingConfiguration = .ingestDefault,
        preprocessingPolicyOptions: TextPreprocessingPolicyOptions? = nil
    ) async throws {
        try await self.init(
            databaseAuthority: dbActor,
            artifactAuthority: artifactAuthority,
            preprocessingConfiguration: preprocessingConfiguration,
            preprocessingPolicyOptions: preprocessingPolicyOptions
        )
    }
}

public enum ContextumRuntimeModule: CapabilityModule {
    public static func register(runtime: PlatformRuntime) async throws {
        let database = ContextumDatabase(databaseAuthority: runtime.database as any AnigmaFoundation.DatabaseAuthority, artifactAuthority: await runtime.artifacts)
        try await database.migrate()
    }
}
