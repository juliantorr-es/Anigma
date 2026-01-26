//
//  DaemonServer.swift
//  AnigmaDaemonCore
//
//  Main daemon server coordinator (refactored).
//

import AnigmaCore
import AnigmaMCPModule
import AnigmaASTServices
import DatabaseCore
import ExecutionCore
import Foundation
import GovernanceCore
import MCP
import StorageCore
import TelemetryCore
import CathedralModule
import ModelRegistryModule
import ModelRegistry
import VectorumModule
import DataEngine
import ExportCore
import AnigmaAgents
import ContextumModule
import ContractsCore
import AnigmaSystemSpine
import CodexModule
import TranscriptumModule
import DataCore
import InferenceCore

/// Main daemon server actor (coordinator)
public actor DaemonServer {
    internal let configuration: DaemonConfiguration
    internal let telemetry: TelemetryClient
    internal let tokenManager: CapabilityTokenManager
    internal let apiKeyManager: APIKeyManager
    internal let jobQueue: JobQueue
    internal let httpServer: HTTPServerManager
    internal let vault: VaultAuthority
    internal let jobRegistry: JobRegistry
    internal let workerPool: WorkerPool
    internal let receiptEngine: ReceiptEngine
    internal let jobEvents: JobEventHub
    internal let database: DatabaseActor
    internal let rateLimiter: RateLimiter
    internal let signalManager: SignalManager
    internal let healthManager: HealthManager
    internal let resourceMonitor: ResourceMonitor
    internal let mcpServer: AnigmaMCPServer
    internal let vfsWatcher: VFSWatcherService
    internal let oAuthManager: OAuthManager
    internal let antigravityAuthManager: AntigravityAuthManager
    internal let antigravityService: AntigravityService
    internal let sessionManager: SessionManager
    internal let inferencePlane: InferencePlane
    
    // Platform Runtime
    internal let runtime: PlatformRuntime

    // Integrated Services

    internal let modelRegistry: ModelRegistryProtocol
    internal let hfAdapter: HuggingFaceAdapter
    internal let cathedralCoordinator: CathedralCoordinator
    internal let evidenceSubstrate: EvidenceSubstrate
    internal let planCompiler: PlanCompiler
    internal let mlServiceRouter: MLServiceRouter
    internal let agentOrchestrator: AgentOrchestrator
    internal let dataEngine: DataEngine
    internal let exportEngine: ExportEngine
    internal let contextumDatabase: ContextumDatabase
    internal let searchSystem: SemanticSearchSystem
    
    // New Implementation Services
    internal let codexService: CodexService
    internal let transcriptumService: TranscriptumService

    internal var isRunning: Bool = false
    internal var startTime: Date?
    internal var jobProcessingTask: Task<Void, Never>?
    internal var vaultSizeCache: (bytes: UInt64, updatedAt: Date)?
    internal let vaultSizeCacheTTL: TimeInterval = 10

    // API version for contract compliance
    internal let apiVersion = "1.0.0"
    internal let daemonVersion = "0.1.0"
    internal let buildHash = "dev"

    public init(configuration: DaemonConfiguration) async throws {
        self.configuration = configuration

        let vaultURL = URL(fileURLWithPath: (configuration.vault.rootPath as NSString).expandingTildeInPath)
        try? FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true, attributes: nil)

        let logDir = vaultURL.appendingPathComponent("logs")
        var sinks: [TelemetrySink] = [ConsoleTelemetrySink()]
        if let fileSink = try? RotatingFileTelemetrySink(logDirectory: logDir) {
            sinks.append(fileSink)
        }
        self.telemetry = TelemetryClient(sinks: sinks)

        self.tokenManager = CapabilityTokenManager()
        let dbPath = vaultURL.appendingPathComponent("vault.db").path
        self.database = DatabaseActor(dbPath: dbPath)
        try await self.database.open()

        self.apiKeyManager = APIKeyManager(database: self.database, tokenManager: self.tokenManager)
        if configuration.daemon.apiKeysEnabled {
            try await self.apiKeyManager.initializeStorage()
        }

        let persistence = SQLiteJobPersistence(database: self.database)
        try await persistence.initializeSchema()

        self.jobQueue = JobQueue(maxConcurrentJobs: configuration.resources.maxConcurrentJobs, persistence: persistence)
        self.httpServer = HTTPServerManager()

        self.jobRegistry = JobRegistry()
        await registerDefaultWorkers()

        self.workerPool = WorkerPool(maxConcurrentJobs: configuration.resources.maxConcurrentJobs, resourceLimits: (configuration.resources.maxMemoryMB, 60))

        self.vault = try await VaultAuthority(rootURL: vaultURL, database: self.database, keyProvider: DefaultVaultKeyProvider.make())

        let receiptStore: ExecutionCore.ReceiptStore = switch configuration.governance.receiptStoreMode {
        case .vault: VaultReceiptStore(vault: vault)
        case .inMemory: InMemoryReceiptStore()
        }

        self.receiptEngine = ReceiptEngine(signer: DefaultReceiptSigner(), store: receiptStore, telemetry: self.telemetry)
        self.jobEvents = JobEventHub()
        self.rateLimiter = RateLimiter(capacity: 100, refillRate: 10.0)
        
        self.signalManager = SignalManager()
        self.healthManager = HealthManager(daemonStartTime: Date())
        self.mcpServer = AnigmaMCPServer()
        self.vfsWatcher = VFSWatcherService()
        self.resourceMonitor = ResourceMonitor(thresholds: ResourceThresholds(maxMemoryMB: configuration.resources.maxMemoryMB, maxCPUPercent: 80.0, maxDiskUsagePercent: 90.0))
        self.oAuthManager = OAuthManager(database: database)
        try await self.oAuthManager.initialize()
        self.antigravityAuthManager = AntigravityAuthManager(
            database: database,
            redirectBaseURL: "http://\(configuration.daemon.bindHost):\(configuration.antigravity.redirectPort)"
        )
        try await self.antigravityAuthManager.initialize()
        self.antigravityService = AntigravityService(authManager: self.antigravityAuthManager)
        self.sessionManager = SessionManager()
        self.inferencePlane = AntigravityInferenceAdapter(service: self.antigravityService)
        
        // Create PlatformRuntime with Antigravity inference plane
        let runtimeConfig = RuntimeConfiguration.daemon
        self.runtime = try await PlatformRuntime(config: runtimeConfig, inferencePlane: self.inferencePlane)
        try await self.runtime.initialize()

        // Services
        let modelRegistryPath = vaultURL.appendingPathComponent("models/registry.db")
        try? FileManager.default.createDirectory(at: modelRegistryPath.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        self.modelRegistry = try await ModelRegistryStore(storagePath: modelRegistryPath.path)
        self.hfAdapter = try HuggingFaceAdapter(cacheDir: vaultURL.appendingPathComponent("models/cache").path)
        self.evidenceSubstrate = try await EvidenceSubstrate(dbActor: database)
        self.planCompiler = PlanCompiler(dbActor: database, evidenceSubstrate: evidenceSubstrate)

        // Use runtime's governance instead of creating a new one
        let databaseAuthority = DatabaseAuthorityImpl(databaseActor: self.database, governance: runtime.governance, evidenceAuthority: nil)
        let databaseAdapter = DatabaseAuthorityAdapter(databaseAuthority: databaseAuthority)
        self.contextumDatabase = ContextumDatabase(dbActor: databaseAdapter)

        let embeddingComputing = DeterministicEmbeddingComputer()
        let embeddingService = EmbeddingMLService(embeddingComputing: embeddingComputing, modelRegistry: modelRegistry)
        self.searchSystem = SemanticSearchSystem(embeddingService: embeddingService, database: contextumDatabase)
        let retrievalService = RetrievalMLService(searchSystem: searchSystem, embeddingComputing: embeddingComputing, modelRegistry: modelRegistry, database: contextumDatabase)
        self.mlServiceRouter = MLServiceRouter(embeddingService: embeddingService, retrievalService: retrievalService, generationService: GenerationMLService(), classificationService: ClassificationMLService())

        self.cathedralCoordinator = await CathedralModule.createFacade(database: database, mlService: mlServiceRouter)
        self.dataEngine = DataEngine()

        let registryURL = vaultURL.appendingPathComponent("agents/registry")
        try? FileManager.default.createDirectory(at: registryURL, withIntermediateDirectories: true)
        let aiRegistry = AIRegistry(storageURL: registryURL)
        let jobEngine = try JobEngine(directoryURL: vaultURL.appendingPathComponent("agent_jobs"))
        self.agentOrchestrator = AgentOrchestrator(jobEngine: jobEngine, dataEngine: self.dataEngine, registry: aiRegistry)
        
        // Register default agents
        await registerDefaultAgents()
        
        self.exportEngine = ExportEngine(jobEngine: self)
        
        // Initialize Codex and Transcriptum using the PlatformRuntime
        // Get world and governance from runtime
        let world = runtime.getWorld()
        let runtimeGovernance = runtime.governance
        
        let securedWorld = SecuredWorld(world: world, governance: runtimeGovernance, security: await SecurityModule.initialize(auditLog: runtimeGovernance.auditLog))
        let syncManager = SyncManager(world: world)
        let systemPrincipal = AccessPrincipal(
            id: "system",
            type: .system,
            module: "Daemon",
            roles: ["admin", "processor"],
            attributes: ["project_id": "anigma-core"]
        )
        
        self.codexService = CodexService(world: world, governance: runtimeGovernance)
        self.transcriptumService = TranscriptumService(
            world: securedWorld,
            syncManager: syncManager,
            principal: systemPrincipal
        )

        await setupResourceHandlers()
        await setupSignalHandlers()
    }

    private func registerDefaultWorkers() async {
        let artifactAuthority = DaemonArtifactAuthority(vault: vault)
        let evidenceAuthority = DaemonEvidenceAuthority(receiptEngine: receiptEngine)

        await jobRegistry.register(worker: ArtifactCopyWorker())
        await jobRegistry.register(worker: MemoryLeakWorker())
        await jobRegistry.register(worker: CPUBurnWorker())
        await jobRegistry.register(worker: PDFWorker())
        await jobRegistry.register(worker: LaTeXWorker())
        await jobRegistry.register(worker: TextChunkingWorker())
        await jobRegistry.register(worker: SemanticChunkingWorker())
        await jobRegistry.register(worker: CodeGenerationWorker())
        await jobRegistry.register(worker: ASTAnalysisWorker())
        await jobRegistry.register(worker: ASTTransformWorker())
        await jobRegistry.register(worker: CodeSearchWorker())
        await jobRegistry.register(worker: IndexingWorker(database: self.database))
        await jobRegistry.register(worker: TechDebtWorker())
        await jobRegistry.register(worker: AccessumWorker())
        await jobRegistry.register(worker: DiaplasionWorker())
        await jobRegistry.register(worker: WorktreeWorker())
        await jobRegistry.register(worker: GovernanceWorker())
        await jobRegistry.register(worker: MLInferWorker())
        await jobRegistry.register(worker: FFmpegWorker())
        await jobRegistry.register(worker: PandocWorker())
        await jobRegistry.register(worker: GnuPGWorker())
        await jobRegistry.register(worker: ImageMagickWorker())
        await jobRegistry.register(worker: TesseractWorker())
        await jobRegistry.register(worker: LibassWorker())
        await jobRegistry.register(worker: BiberWorker())
        await jobRegistry.register(worker: InkscapeWorker())
        await jobRegistry.register(worker: CtagsWorker())
        await jobRegistry.register(worker: NoOpWorker())
        await jobRegistry.register(worker: HarmoniaWorker(
            artifactAuthority: artifactAuthority,
            evidenceAuthority: evidenceAuthority
        ))
    }

    private func registerDefaultAgents() async {
        let agents = [
            // Register a default code assistant agent
            CodeAssistantAgent(inferencePlane: inferencePlane),
            // Register a default data analysis agent  
            DataAnalysisAgent(inferencePlane: inferencePlane),
            // Register a document analysis agent
            DocumentAnalysisAgent(inferencePlane: inferencePlane),
            // Register an image processing agent
            ImageProcessingAgent(inferencePlane: inferencePlane),
            // Register a research assistant agent
            ResearchAssistantAgent(inferencePlane: inferencePlane)
        ]
        
        for agent in agents {
            agentOrchestrator.register(agent: agent)
            
            // Save agent configuration to registry
            let aiAgent = AIAgent(
                id: agent.id,
                name: agent.name,
                description: agent.description,
                capabilities: agent.capabilities,
                isEnabled: true,
                createdAt: Date(),
                lastUsed: nil,
                config: ["type": "builtin", "inference_plane": "antigravity"]
            )
            
            do {
                try await aiRegistry?.save(agent: aiAgent)
                logInfo("Saved agent to registry: \(agent.id)", category: "Agents")
            } catch {
                logInfo("Failed to save agent \(agent.id) to registry: \(error)", category: "Agents")
            }
        }
        
        let agentIds = agents.map { $0.id }.joined(separator: ", ")
        logInfo("Registered default agents: \(agentIds)", category: "Agents")
    }

    private func setupResourceHandlers() async {
        await resourceMonitor.registerEventHandler { [weak self] event in
            await self?.handleResourceEvent(event)
        }
    }
}

private struct DocumentAnalysisAgent: Agent {
    let id = "document-analyst"
    let name = "Document Analyst"
    let description = "Analyzes, summarizes, and extracts insights from documents"
    let capabilities: [AgentCapability] = [.dataAnalysis]
    
    private let inferencePlane: any InferencePlane
    
    init(inferencePlane: any InferencePlane) {
        self.inferencePlane = inferencePlane
    }
    
    func execute(instruction: String, context: AgentContext) async throws -> AgentResult {
        do {
            let request = InferenceRequest(
                task: .chat,
                input: "As a document analyst, please analyze: \(instruction)\n\nProvide summary, key points, and insights.",
                modelID: "gemini-2.0-flash",
                options: ["temperature": .number(0.3)]
            )
            
            let response = try await inferencePlane.perform(request)
            
            return AgentResult(
                output: "📄 **Document Analysis Report**\n\n\(response.output)\n\n---\n*Analyzed using AI*",
                artifacts: [],
                receipt: Receipt(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    actor: id,
                    action: "document_analysis",
                    status: .success,
                    details: [
                        "instruction_length": instruction.count,
                        "model_used": "gemini-2.0-flash",
                        "ai_generated": true
                    ]
                )
            )
        } catch {
            return AgentResult(
                output: "Document analyst received: \(instruction.prefix(100))...\n\n⚠️ AI analysis failed: \(error.localizedDescription)",
                artifacts: [],
                receipt: Receipt(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    actor: id,
                    action: "document_analysis",
                    status: .partialSuccess,
                    details: [
                        "instruction_length": instruction.count,
                        "error": error.localizedDescription,
                        "ai_generated": false
                    ]
                )
            )
        }
    }
}

private struct ImageProcessingAgent: Agent {
    let id = "image-processor"
    let name = "Image Processor"
    let description = "Analyzes images, describes content, and extracts visual information"
    let capabilities: [AgentCapability] = [.dataAnalysis]
    
    private let inferencePlane: any InferencePlane
    
    init(inferencePlane: any InferencePlane) {
        self.inferencePlane = inferencePlane
    }
    
    func execute(instruction: String, context: AgentContext) async throws -> AgentResult {
        do {
            let request = InferenceRequest(
                task: .chat,
                input: "As an image analysis expert, please help with: \(instruction)\n\nDescribe images, analyze visual content, or provide image-related insights.",
                modelID: "gemini-2.0-flash",
                options: ["temperature": .number(0.4)]
            )
            
            let response = try await inferencePlane.perform(request)
            
            return AgentResult(
                output: "🖼️ **Image Analysis Report**\n\n\(response.output)\n\n---\n*Processed using AI*",
                artifacts: [],
                receipt: Receipt(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    actor: id,
                    action: "image_processing",
                    status: .success,
                    details: [
                        "instruction_length": instruction.count,
                        "model_used": "gemini-2.0-flash",
                        "ai_generated": true
                    ]
                )
            )
        } catch {
            return AgentResult(
                output: "Image processor received: \(instruction.prefix(100))...\n\n⚠️ AI processing failed: \(error.localizedDescription)",
                artifacts: [],
                receipt: Receipt(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    actor: id,
                    action: "image_processing",
                    status: .partialSuccess,
                    details: [
                        "instruction_length": instruction.count,
                        "error": error.localizedDescription,
                        "ai_generated": false
                    ]
                )
            )
        }
    }
}

private struct ResearchAssistantAgent: Agent {
    let id = "research-assistant"
    let name = "Research Assistant"
    let description = "Conducts research, gathers information, and provides comprehensive answers"
    let capabilities: [AgentCapability] = [.dataAnalysis, .educationIntegration]
    
    private let inferencePlane: any InferencePlane
    
    init(inferencePlane: any InferencePlane) {
        self.inferencePlane = inferencePlane
    }
    
    func execute(instruction: String, context: AgentContext) async throws -> AgentResult {
        do {
            let request = InferenceRequest(
                task: .chat,
                input: "As a research assistant, please research: \(instruction)\n\nProvide comprehensive information, sources, and insights.",
                modelID: "gemini-2.0-flash",
                options: ["temperature": .number(0.6)]
            )
            
            let response = try await inferencePlane.perform(request)
            
            return AgentResult(
                output: "🔍 **Research Report**\n\n\(response.output)\n\n---\n*Researched using AI*",
                artifacts: [],
                receipt: Receipt(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    actor: id,
                    action: "research_assistance",
                    status: .success,
                    details: [
                        "instruction_length": instruction.count,
                        "model_used": "gemini-2.0-flash",
                        "ai_generated": true
                    ]
                )
            )
        } catch {
            return AgentResult(
                output: "Research assistant received: \(instruction.prefix(100))...\n\n⚠️ AI research failed: \(error.localizedDescription)",
                artifacts: [],
                receipt: Receipt(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    actor: id,
                    action: "research_assistance",
                    status: .partialSuccess,
                    details: [
                        "instruction_length": instruction.count,
                        "error": error.localizedDescription,
                        "ai_generated": false
                    ]
                )
            )
        }
    }
}

    public func start() async throws {
        guard !isRunning else { throw DaemonError.alreadyRunning }
        isRunning = true
        startTime = Date()
        await resourceMonitor.startMonitoring()
        await vfsWatcher.onFileChange { [weak self] path in Task { await self?.handleFileChange(path: path) } }
        try await httpServer.start(configuration: configuration.daemon, daemon: self)
        await jobQueue.restore()
        jobProcessingTask = Task { await runJobProcessingLoop() }
        _ = await telemetry.emit(category: .system, name: "daemon_started", values: ["api_version": .hashedToken(TelemetryHash(input: apiVersion)), "tcp_enabled": .boolean(configuration.daemon.tcpEnabled), "restored_jobs": .boolean(true)])
        logInfo("anigmad started", category: "Daemon")
    }

    public func stop() async { await performShutdown() }

    private func handleGracefulShutdown() async {
        print("Initiating graceful shutdown...")
        await performShutdown()
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        exit(0)
    }

    private func handleConfigurationReload() async {
        print("Configuration reload requested...")
    }

    private func performShutdown() async {
        guard isRunning else { return }
        isRunning = false
        await jobQueue.pause()
        if let jobTask = jobProcessingTask {
            jobTask.cancel()
            let timeout = Task { try? await Task.sleep(nanoseconds: 30_000_000_000) }
            _ = await withTaskGroup(of: Void.self) { group in
                group.addTask { await jobTask.value }
                group.addTask { await timeout.value }
            }
        }
        await httpServer.stop()
        await workerPool.stop()
        await resourceMonitor.stopMonitoring()
        await signalManager.cleanup()
        _ = await telemetry.emit(category: .system, name: "daemon_stopped", values: ["uptime": Date().timeIntervalSince(startTime ?? Date()), "jobs_processed": jobQueue.processedJobCount])
        logInfo("anigmad stopped gracefully", category: "Daemon")
    }

    internal func logInfo(_ message: String, category: String) {
        Task {
            _ = await telemetry.emit(category: .system, name: "log_info", values: ["message": .hashedToken(TelemetryHash(input: message)), "category": .hashedToken(TelemetryHash(input: category))])
            print("[\(category)] \(message)")
        }
    }
}

// MARK: - Default Agent Implementations

private struct CodeAssistantAgent: Agent {
    let id = "code-assistant"
    let name = "Code Assistant"
    let description = "Assists with code generation, analysis, and refactoring using AI"
    let capabilities: [AgentCapability] = [.codeModification, .dataAnalysis]
    
    private let inferencePlane: any InferencePlane
    
    init(inferencePlane: any InferencePlane) {
        self.inferencePlane = inferencePlane
    }
    
    func execute(instruction: String, context: AgentContext) async throws -> AgentResult {
        do {
            // Use the inference plane to generate code
            let request = InferenceRequest(
                task: .chat,
                input: "As a code assistant, please help with: \(instruction)\n\nProvide code solutions with explanations.",
                modelID: "gemini-2.0-flash", // Default model
                options: ["temperature": .number(0.7)]
            )
            
            let response = try await inferencePlane.perform(request)
            let aiResponse = response.output
            
            return AgentResult(
                output: "🤖 **Code Assistant Response**\n\n\(aiResponse)\n\n---\n*Generated using AI inference plane*",
                artifacts: [],
                receipt: Receipt(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    actor: id,
                    action: "code_assistance",
                    status: .success,
                    details: [
                        "instruction_length": instruction.count,
                        "model_used": "gemini-2.0-flash",
                        "ai_generated": true
                    ]
                )
            )
        } catch {
            // Fallback if AI fails
            return AgentResult(
                output: "Code assistant received instruction: \(instruction.prefix(100))...\n\n⚠️ AI inference failed: \(error.localizedDescription)\n\nPlease try again or check the AI service connection.",
                artifacts: [],
                receipt: Receipt(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    actor: id,
                    action: "code_assistance",
                    status: .partialSuccess,
                    details: [
                        "instruction_length": instruction.count,
                        "error": error.localizedDescription,
                        "ai_generated": false
                    ]
                )
            )
        }
    }
}

private struct DataAnalysisAgent: Agent {
    let id = "data-analyst"
    let name = "Data Analyst"
    let description = "Analyzes data, generates insights, and creates reports using AI"
    let capabilities: [AgentCapability] = [.dataAnalysis]
    
    private let inferencePlane: any InferencePlane
    
    init(inferencePlane: any InferencePlane) {
        self.inferencePlane = inferencePlane
    }
    
    func execute(instruction: String, context: AgentContext) async throws -> AgentResult {
        do {
            // Use the inference plane for data analysis
            let request = InferenceRequest(
                task: .chat,
                input: "As a data analyst, please analyze: \(instruction)\n\nProvide insights, patterns, and recommendations.",
                modelID: "gemini-2.0-flash", // Default model
                options: ["temperature": .number(0.5)]
            )
            
            let response = try await inferencePlane.perform(request)
            let aiResponse = response.output
            
            return AgentResult(
                output: "📊 **Data Analysis Report**\n\n\(aiResponse)\n\n---\n*Generated using AI inference plane*",
                artifacts: [],
                receipt: Receipt(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    actor: id,
                    action: "data_analysis",
                    status: .success,
                    details: [
                        "instruction_length": instruction.count,
                        "model_used": "gemini-2.0-flash",
                        "ai_generated": true
                    ]
                )
            )
        } catch {
            // Fallback if AI fails
            return AgentResult(
                output: "Data analyst received instruction: \(instruction.prefix(100))...\n\n⚠️ AI inference failed: \(error.localizedDescription)\n\nPlease try again or check the AI service connection.",
                artifacts: [],
                receipt: Receipt(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    actor: id,
                    action: "data_analysis",
                    status: .partialSuccess,
                    details: [
                        "instruction_length": instruction.count,
                        "error": error.localizedDescription,
                        "ai_generated": false
                    ]
                )
            )
        }
    }
}
