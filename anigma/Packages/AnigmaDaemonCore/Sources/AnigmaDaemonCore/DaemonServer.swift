//
//  DaemonServer.swift
//  AnigmaDaemonCore
//
//  Main daemon server coordinator (refactored).
//

import AnigmaCore
import AnigmaMCPModule
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
import OSLog
import VectorumModule

private func daemonStartupCheckpoint(_ message: String) {
    logInfo(message, category: "DaemonServer")
}

private func resolveMLWorkerPath(configuration: DaemonConfiguration) -> String {
    if let configPath = configuration.daemon.mlWorkerPath, !configPath.isEmpty {
        return configPath
    }

    // Alignment: Use governed runtime authority for paths
    let currentDir = RuntimeAuthority.shared.workingDirectory
    return "\(currentDir)/.build/debug/ml-worker"
}

private struct AcceleratedContextumEmbeddingComputing: ContextumModule.EmbeddingComputing {
    private let backend: AnigmaCore.MLWorkerEmbeddingComputer

    init(backend: AnigmaCore.MLWorkerEmbeddingComputer) {
        self.backend = backend
    }

    func computeEmbeddings(
        modelID: String,
        modelVersion: String?,
        inputs: [String],
        normalize: Bool
    ) async throws -> ContextumModule.EmbeddingComputeResult {
        let result = try await backend.computeEmbeddings(
            modelID: modelID,
            modelVersion: modelVersion,
            inputs: inputs,
            normalize: normalize
        )

        return ContextumModule.EmbeddingComputeResult(
            vectors: result.vectors,
            dimension: result.dimension,
            inputHashes: result.inputHashes
        )
    }
}

/// Main daemon server actor (coordinator)
public actor DaemonServer {
    static let logger = Logger(subsystem: "com.anigma.AnigmaDaemonCore", category: "DaemonServer")

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
    internal let aiRegistry: AIRegistry
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

    internal let modelRegistry: ModelRegistryStore
    internal let hfAdapter: ModelRegistry.HuggingFaceAdapter
    internal let cathedralCoordinator: CathedralFacade
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
    
    // AST Services (daemon-owned, in-process)
    internal let astAuthority: DaemonASTAuthority

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
        daemonStartupCheckpoint("vault ready at \(vaultURL.path)")

        let logDir = vaultURL.appendingPathComponent("logs")
        var sinks: [TelemetrySink] = [ConsoleTelemetrySink()]
        if let fileSink = try? RotatingFileTelemetrySink(logDirectory: logDir) {
            sinks.append(fileSink)
        }
        self.telemetry = TelemetryClient(sinks: sinks)

        self.tokenManager = CapabilityTokenManager()
        // PostgreSQL is now the first-class database - SQLite is deprecated
        let dbConnectionString = DatabaseConfiguration.defaultDatabasePath()
        self.database = DatabaseActor(path: dbConnectionString)
        try await self.database.open()
        daemonStartupCheckpoint("primary PostgreSQL database opened")

        // Run schema migrations to ensure database is at expected version
        let migrationRunner = SchemaMigrationRunner(database: self.database)
        let migrationResult = try await migrationRunner.runMigrations()
        if !migrationResult.isSuccessful {
            daemonStartupCheckpoint("WARNING: Schema migration had issues: \\(migrationResult.failedCount) failed, \\(migrationResult.missingExtensions.count) missing extensions")
        } else {
            daemonStartupCheckpoint("schema migrations applied: \\(migrationResult.appliedCount) applied, \\(migrationResult.skippedCount) skipped")
        }

        self.apiKeyManager = APIKeyManager(database: self.database, tokenManager: self.tokenManager)
        if configuration.daemon.apiKeysEnabled {
            try await self.apiKeyManager.initializeStorage()
        }

        self.jobQueue = try JobQueue(directoryURL: vaultURL.appendingPathComponent("job-queue"))
        self.httpServer = HTTPServerManager()

        self.jobRegistry = JobRegistry()

        self.workerPool = WorkerPool(maxConcurrentJobs: configuration.resources.maxConcurrentJobs, resourceLimits: (configuration.resources.maxMemoryMB, 60))

        self.vault = try await VaultAuthority(rootURL: vaultURL, database: self.database, keyProvider: DefaultVaultKeyProvider.make())
        daemonStartupCheckpoint("vault authority initialized")

        let receiptStore: ExecutionCore.ReceiptStore = switch configuration.governance.receiptStoreMode {
        case .vault: VaultReceiptStore(vault: vault)
        case .inMemory: InMemoryReceiptStore()
        }

        self.receiptEngine = ReceiptEngine(signer: DefaultReceiptSigner(), store: receiptStore, telemetry: self.telemetry)
        self.jobEvents = JobEventHub()
        self.rateLimiter = RateLimiter(capacity: 100, refillRate: 10.0)
        
        self.signalManager = SignalManager()
        self.mcpServer = AnigmaMCPServer(autoInitialize: false)
        self.vfsWatcher = VFSWatcherService()
        self.resourceMonitor = ResourceMonitor(thresholds: ResourceThresholds(maxMemoryMB: configuration.resources.maxMemoryMB, maxCPUPercent: 80.0, maxDiskUsagePercent: 90.0))
        self.oAuthManager = OAuthManager(database: database)
        try await self.oAuthManager.initialize()
        daemonStartupCheckpoint("oauth manager initialized")
        self.antigravityAuthManager = AntigravityAuthManager(
            database: database,
            redirectBaseURL: "http://\(configuration.daemon.bindHost):\(configuration.antigravity.redirectPort)"
        )
        try await self.antigravityAuthManager.initialize()
        daemonStartupCheckpoint("antigravity auth initialized")
        self.antigravityService = AntigravityService(authManager: self.antigravityAuthManager)
        self.sessionManager = SessionManager()
        self.inferencePlane = AntigravityInferenceAdapter(service: self.antigravityService)
        
        // Create PlatformRuntime with Antigravity inference plane
        // PostgreSQL is now the first-class database - SQLite is deprecated
        let runtimeConfig = RuntimeConfiguration(
            mode: .local,
            databasePath: dbConnectionString,
            daemonURL: nil,
            enforceGovernance: RuntimeConfiguration.daemon.enforceGovernance,
            recordEvidence: RuntimeConfiguration.daemon.recordEvidence,
            maxConcurrentJobs: RuntimeConfiguration.daemon.maxConcurrentJobs
        )
        let runtimeGovernance = GovernanceController()
        await runtimeGovernance.initialize()
        self.runtime = try await PlatformRuntime(
            config: runtimeConfig,
            governance: runtimeGovernance,
            inferencePlane: self.inferencePlane
        )
        try await self.runtime.initialize()
        daemonStartupCheckpoint("platform runtime initialized")

        // Services
        // PostgreSQL is now the first-class database - SQLite is deprecated
        // Model registry uses the same PostgreSQL database with a dedicated schema
        let modelRegistryConnectionString = DatabaseConfiguration.defaultDatabasePath()
        self.modelRegistry = try await ModelRegistryStore(storagePath: modelRegistryConnectionString)
        daemonStartupCheckpoint("model registry store initialized with PostgreSQL")
        self.hfAdapter = ModelRegistry.HuggingFaceAdapter(artifactStore: vaultURL.appendingPathComponent("models/cache"))
        let tamperSystem = TamperEvidenceSystem(database: self.database)
        self.evidenceSubstrate = EvidenceSubstrate(tamperSystem: tamperSystem, config: CathedralConfig())

        // Use the runtime governance controller directly so the daemon stays on one governed path.
        let runtimeArtifactAuthority = await runtime.artifacts
        let planCompilerDatabase = DatabaseAuthorityAdapter(databaseAuthority: runtime.database)
        self.planCompiler = PlanCompiler(dbActor: planCompilerDatabase, evidenceSubstrate: evidenceSubstrate)
        self.contextumDatabase = ContextumDatabase(
            databaseAuthority: runtime.database,
            artifactAuthority: runtimeArtifactAuthority
        )
        try await self.contextumDatabase.migrate()
        daemonStartupCheckpoint("contextum database initialized")

        let embeddingComputing = AcceleratedContextumEmbeddingComputing(
            backend: AnigmaCore.MLWorkerEmbeddingComputer(
                mlWorkerPath: resolveMLWorkerPath(configuration: configuration)
            )
        )
        let contextumModelRegistry = ConcreteModelRegistry(registry: modelRegistry)
        let embeddingService = EmbeddingMLService(embeddingComputing: embeddingComputing, modelRegistry: contextumModelRegistry)
        self.searchSystem = SemanticSearchSystem()
        let retrievalService = RetrievalMLService(searchSystem: searchSystem, embeddingComputing: embeddingComputing, modelRegistry: contextumModelRegistry, database: contextumDatabase)
        self.mlServiceRouter = MLServiceRouter(embeddingService: embeddingService, retrievalService: retrievalService, generationService: GenerationMLService(), classificationService: ClassificationMLService())
        daemonStartupCheckpoint("ml service router initialized")

        self.cathedralCoordinator = await CathedralModule.createFacade(database: database, mlService: mlServiceRouter)
        daemonStartupCheckpoint("cathedral facade initialized")
        self.dataEngine = DataEngine()

        let registryURL = vaultURL.appendingPathComponent("agents/registry")
        try? FileManager.default.createDirectory(at: registryURL, withIntermediateDirectories: true)
        self.aiRegistry = AIRegistry(storageURL: registryURL)
        let jobEngine = try JobEngine(directoryURL: vaultURL.appendingPathComponent("agent_jobs"))
        self.agentOrchestrator = AgentOrchestrator(jobEngine: jobEngine, dataEngine: self.dataEngine, registry: self.aiRegistry)
        daemonStartupCheckpoint("agent orchestrator initialized")
        
        self.exportEngine = ExportEngine(jobEngine: jobEngine)
        
        // Initialize Codex and Transcriptum using the PlatformRuntime
        // Get world and governance from runtime
        let world = await runtime.getWorld()
        let auditLog = await runtimeGovernance.auditLog
        let security = await SecurityModule.initialize(auditLog: auditLog)
        let securedWorld = SecuredWorld(
            world: world,
            governance: runtimeGovernance,
            security: SecurityInfrastructureBridge(base: security)
        )
        
        let syncManager = SyncManager()
        self.healthManager = HealthManager(syncManager: syncManager)
        let systemPrincipal = AccessPrincipal.system("system", module: "Daemon", roles: Set(["admin", "processor"]))
        
        self.codexService = CodexService(world: world, governance: runtimeGovernance)
        self.transcriptumService = TranscriptumService(
            world: securedWorld,
            syncManager: syncManager,
            principal: systemPrincipal
        )
        daemonStartupCheckpoint("codex/transcriptum initialized")
        
        // Initialize AST authority (in-process, daemon-owned)
        self.astAuthority = DaemonASTAuthority(
            cacheEnabled: configuration.daemon.cacheEnabled ?? true,
            maxFileSize: configuration.resources.maxFileSizeMB * 1024 * 1024,
            cacheSizeLimit: configuration.resources.cacheSizeLimitMB * 1024 * 1024,
            timeoutSeconds: configuration.resources.timeoutSeconds ?? 60,
            enableMetrics: true
        )

        await setupResourceHandlers()
        await setupSignalHandlers()
        await registerDefaultWorkers()
        await registerDefaultAgents()
        daemonStartupCheckpoint("daemon server init complete")
    }

    private func registerDefaultWorkers() async {
        let artifactAuthority = DaemonArtifactAuthority(vault: vault)
        let evidenceAuthority = DaemonEvidenceAuthority(receiptEngine: receiptEngine)
        let parityReport = await DaemonWorkerRegistry.registerCanonicalWorkers(
            on: jobRegistry,
            database: database,
            artifactAuthority: runtimeArtifactAuthority,
            evidenceAuthority: evidenceAuthority,
            configuration: configuration
        )

        precondition(
            parityReport.isInParity,
            "Worker registry drift detected in DaemonServer. Missing: \(parityReport.missingKinds). Extra: \(parityReport.extraKinds)"
        )
    }

    private func registerDefaultAgents() async {
        let agents = [
            // Register a document analysis agent
            DocumentAnalysisAgent(inferencePlane: inferencePlane) as any Agent,
            // Register an image processing agent
            ImageProcessingAgent(inferencePlane: inferencePlane) as any Agent,
            // Register a research assistant agent
            ResearchAssistantAgent(inferencePlane: inferencePlane) as any Agent
        ]
        
        for agent in agents {
            await agentOrchestrator.register(agent: agent)
            
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
                try await aiRegistry.save(agent: aiAgent)
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

    private func setupSignalHandlers() async {
    }

    private func handleResourceEvent(_ event: ResourceMonitorEvent) async {
        _ = event
    }

    private func handleFileChange(path: String) async {
        _ = path
    }
}

private struct DocumentAnalysisAgent: Agent {
    let id = "document-analyst"
    let name = "Document Analyst"
    let description = "Analyzes, summarizes, and extracts insights from documents"
    let capabilities: [AnigmaAgents.AgentCapability] = [AnigmaAgents.AgentCapability.dataAnalysis]
    
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
                    receipt: CoreReceipt(
                        id: UUID().uuidString,
                        timestamp: Date(),
                        action: "document_analysis",
                        actor: id,
                        surface: "daemon-agent",
                        details: "instruction_length=\(instruction.count), model_used=gemini-2.0-flash, ai_generated=true"
                    )
                )
        } catch {
            return AgentResult(
                output: "Document analyst received: \(instruction.prefix(100))...\n\n⚠️ AI analysis failed: \(error.localizedDescription)",
                artifacts: [],
                receipt: CoreReceipt(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    action: "document_analysis",
                    actor: id,
                    surface: "daemon-agent",
                    details: "instruction_length=\(instruction.count), error=\(error.localizedDescription), ai_generated=false"
                )
            )
        }
    }
}

private struct ImageProcessingAgent: Agent {
    let id = "image-processor"
    let name = "Image Processor"
    let description = "Analyzes images, describes content, and extracts visual information"
    let capabilities: [AnigmaAgents.AgentCapability] = [AnigmaAgents.AgentCapability.dataAnalysis]
    
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
                    receipt: CoreReceipt(
                        id: UUID().uuidString,
                        timestamp: Date(),
                        action: "image_processing",
                        actor: id,
                        surface: "daemon-agent",
                        details: "instruction_length=\(instruction.count), model_used=gemini-2.0-flash, ai_generated=true"
                    )
                )
        } catch {
            return AgentResult(
                output: "Image processor received: \(instruction.prefix(100))...\n\n⚠️ AI processing failed: \(error.localizedDescription)",
                artifacts: [],
                receipt: CoreReceipt(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    action: "image_processing",
                    actor: id,
                    surface: "daemon-agent",
                    details: "instruction_length=\(instruction.count), error=\(error.localizedDescription), ai_generated=false"
                )
            )
        }
    }
}

private struct ResearchAssistantAgent: Agent {
    let id = "research-assistant"
    let name = "Research Assistant"
    let description = "Conducts research, gathers information, and provides comprehensive answers"
    let capabilities: [AnigmaAgents.AgentCapability] = [AnigmaAgents.AgentCapability.dataAnalysis, AnigmaAgents.AgentCapability.educationIntegration]
    
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
                    receipt: CoreReceipt(
                        id: UUID().uuidString,
                        timestamp: Date(),
                        action: "research_assistance",
                        actor: id,
                        surface: "daemon-agent",
                        details: "instruction_length=\(instruction.count), model_used=gemini-2.0-flash, ai_generated=true"
                    )
                )
        } catch {
            return AgentResult(
                output: "Research assistant received: \(instruction.prefix(100))...\n\n⚠️ AI research failed: \(error.localizedDescription)",
                artifacts: [],
                receipt: CoreReceipt(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    action: "research_assistance",
                    actor: id,
                    surface: "daemon-agent",
                    details: "instruction_length=\(instruction.count), error=\(error.localizedDescription), ai_generated=false"
                )
            )
        }
    }
}

extension DaemonServer {
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
        Self.logger.info("Initiating graceful shutdown")
        await performShutdown()
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        // Alignment: Controlled shutdown via authority
        RuntimeAuthority.shared.shutdown(exitCode: 0)
    }

    private func handleConfigurationReload() async {
        Self.logger.info("Configuration reload requested")
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
        await resourceMonitor.stopMonitoring()
        await signalManager.cleanup()
        _ = await telemetry.emit(category: .system, name: "daemon_stopped", values: ["uptime": .double(Date().timeIntervalSince(startTime ?? Date())), "jobs_processed": .integer(jobQueue.processedJobCount)])
        logInfo("anigmad stopped gracefully", category: "Daemon")
    }

    internal func logInfo(_ message: String, category: String) {
        Task {
            _ = await telemetry.emit(category: .system, name: "log_info", values: ["message": .hashedToken(TelemetryHash(input: message)), "category": .hashedToken(TelemetryHash(input: category))])
            Self.logger.info("[\(category, privacy: .public)] \(message, privacy: .public)")
        }
    }
}

// MARK: - Default Agent Implementations (disabled for now)

// NOTE: Agent implementations are temporarily disabled to reduce daemon surface
// while we stabilize core job/receipt semantics.
