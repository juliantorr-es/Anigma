import Foundation
import MCP
import AnigmaCore
import HarmoniaModule
import AccessumModule
import DiaplasionModule
import OutlineumModule
import PolytroposModule
import AnigmaPrimitives
import ContractsCore
import CryptoKit
import ContextumModule
import ArtifactStoreModule
import MLWorkerCommon
import ModelRegistry
import ModelRegistryModule
import ObservatoriumModule
import CathedralModule
import DatabaseCore

internal typealias WorkerArtifact = MLWorkerCommon.MLWorkerArtifact
internal typealias WorkerEngine = ContractsCore.MLWorkerEngine
internal typealias WorkerInput = MLWorkerCommon.MLArtifactRef
internal typealias WorkerMetrics = MLWorkerCommon.MLWorkerMetrics
internal typealias WorkerOptions = ContractsCore.MLTaskOptions
internal typealias WorkerRequest = MLWorkerCommon.MLWorkerRequest
internal typealias WorkerResponse = MLWorkerCommon.MLWorkerResponse
internal typealias WorkerTask = ContractsCore.MLWorkerTask

/// The Anigma MCP Server implementation.
/// Exposes Harmonia tools, Contextum, ArtifactStore, ModelRegistry, Observatorium, and Cathedral capabilities via the Model Context Protocol.
public actor AnigmaMCPServer {
    internal let server: Server
    internal let toolRegistry: ToolRegistry
    internal var runtime: PlatformRuntime?
    internal var contextum: Contextum?
    internal var artifactStore: ArtifactStoreModule?
    internal var modelRegistry: (any ContractsCore.ModelRegistryProtocol)?
    internal var modelDownloader: AnigmaCore.HuggingFaceAdapter?
    internal var observatorium: ObservatoriumService?
    internal var cathedral: any CathedralCoordinator?

    // Scaling and Lifecycle infrastructure
    internal let moduleInitializer = MCPModuleInitializer()
    internal let timeoutConfig = ToolTimeoutConfig()

    public init() {
        self.server = Server(
            name: "Anigma",
            version: "1.0.0",
            capabilities: Server.Capabilities(
                tools: Server.Capabilities.Tools(listChanged: true)
            )
        )
        self.toolRegistry = ToolRegistry.shared

        // Register initial tool contracts
        registerDefaultTools()

        // Initialize Modules asynchronously (non-blocking)
        Task { [weak self] in
            guard let self = self else { return }
            await self.initializeModules()
        }
    }

    private func initializeModules() async {
        // Step 1: Initialize the Platform Runtime (Core infrastructure)
        await moduleInitializer.initializeModule(name: "runtime", timeout: 10) { @Sendable in
            try await self.initializeRuntime()
        }

        do {
            // Wait for runtime to be fully initialized before proceeding
            try await moduleInitializer.waitForModule("runtime")

            // Step 2: Initialize other modules sequentially to ensure deterministic startup
            try await self.initializeContextum()
            await moduleInitializer.markAsReady(name: "contextum")

            try await self.initializeArtifactStore()
            await moduleInitializer.markAsReady(name: "artifactStore")

            try await self.initializeModelRegistry()
            await moduleInitializer.markAsReady(name: "modelRegistry")

            try await self.initializeObservatorium()
            await moduleInitializer.markAsReady(name: "observatorium")

            try await self.initializeCathedral()
            await moduleInitializer.markAsReady(name: "cathedral")
        } catch {
            fputs("[anigma-mcp] CRITICAL ERROR during sequential initialization: \(error)\n", stderr)
        }

        // Log final status
        let statuses = await moduleInitializer.getModuleStatuses()
        for (_, info) in statuses.sorted(by: { $0.key < $1.key }) {
            if let error = info.error {
                fputs(" - ERROR: \(error)", stderr)
            }
        }
    }

    internal func initializeRuntime() async throws {
        do {
            guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                fatalError("Failed to unwrap appSupport")
            }
            let anigmaDir = appSupport.appendingPathComponent("Anigma")
            try? FileManager.default.createDirectory(at: anigmaDir, withIntermediateDirectories: true)

            let dbPath = anigmaDir.appendingPathComponent("platform_runtime.sqlite").path

            let runtime = try await PlatformRuntime(config: RuntimeConfiguration(databasePath: dbPath))
            try await runtime.initialize()
            try await runtime.registerModule(HarmoniaModule.self)
            try await runtime.registerModule(AccessumModule.self)
            try await runtime.registerModule(DiaplasionModule.self)
            try await runtime.registerModule(OutlineumModule.self)
            try await runtime.registerModule(PolytroposModule.self)
            try await runtime.registerModule(ContextumModule.self)
            try await runtime.registerModule(ArtifactStoreModule.self)
            try await runtime.registerModule(ModelRegistryModule.self)
            try await runtime.registerModule(CathedralModule.self)
            self.runtime = runtime
        } catch {
            fputs("[anigma-mcp] Runtime initialization failed: \(error)\n", stderr)
            throw error
        }
    }

    internal func initializeContextum() async throws {
        guard let runtime = runtime else {
            throw RuntimeError.notInitialized
        }

        let databaseAdapter = DatabaseAuthorityAdapter(databaseAuthority: await runtime.database)
        let contextum = try await Contextum(dbActor: databaseAdapter)
        self.contextum = contextum
    }

    internal func initializeArtifactStore() async throws {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Failed to unwrap appSupport")
        }
        let anigmaDir = appSupport.appendingPathComponent("Anigma")
        let artifactsDir = anigmaDir.appendingPathComponent("artifacts")
        try? FileManager.default.createDirectory(at: artifactsDir, withIntermediateDirectories: true)

        guard let runtime = runtime else {
            throw RuntimeError.notInitialized
        }

        let databaseAuthority = await runtime.database
        let databaseAdapter = DatabaseAuthorityAdapter(databaseAuthority: databaseAuthority)
        let artifactDb = try await ArtifactStoreDatabase(dbActor: databaseAdapter as! any DatabaseCore.DatabaseExecutor)
        let artifactAuthority = await runtime.artifacts
        let artifactStore = ArtifactStoreModule(artifactAuthority: artifactAuthority, storageRoot: artifactsDir, database: artifactDb)
        self.artifactStore = artifactStore
    }

    internal func initializeModelRegistry() async throws {
        guard let runtime = runtime else {
            throw RuntimeError.notInitialized
        }

        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Failed to unwrap appSupport")
        }
        let anigmaDir = appSupport.appendingPathComponent("Anigma")
        try? FileManager.default.createDirectory(at: anigmaDir, withIntermediateDirectories: true)

        let registryDbActor = try await runtime.legacyDatabaseActor()
        let registry = try await RuntimeModelRegistryStore(dbActor: registryDbActor)
        self.modelRegistry = registry

        let cacheDir = anigmaDir.appendingPathComponent("ModelCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        self.modelDownloader = HuggingFaceAdapter(artifactStore: cacheDir)
    }

    internal func initializeObservatorium() async throws {
        // Wait for runtime to be ready if it's not yet
        try await moduleInitializer.waitForModule("runtime")

        guard let runtime = self.runtime else {
            throw NSError(domain: "ModuleInit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Runtime missing"])
        }

        let world = await runtime.getWorld()
        let governance = await runtime.governance
        let observatorium = ObservatoriumService(world: world, governance: governance)
        self.observatorium = observatorium
    }

    internal func initializeCathedral() async throws {
        let coordinator = try await CathedralModule.create(
            config: CathedralConfig()
        )
        self.cathedral = coordinator
    }

    // MARK: - Gemini Bridge Support

    /// List all tools in Gemini-compatible format.
    public func listToolsForGemini() async throws -> [String: AnigmaCore.AnyCodable] {
        let tools = getTools()
        var functionDeclarations: [[String: AnigmaCore.AnyCodable]] = []

        for tool in tools {
            functionDeclarations.append([
                "name": AnigmaCore.AnyCodable(tool.name),
                "description": AnigmaCore.AnyCodable(tool.description ?? ""),
                "parameters": AnigmaCore.AnyCodable(tool.inputSchema)
            ])
        }

        return ["function_declarations": AnigmaCore.AnyCodable(functionDeclarations)]
    }

    /// Call a tool using Gemini-compatible parameters.
    public func callToolForGemini(name: String, arguments: [String: AnigmaCore.AnyCodable]) async throws -> [String: AnigmaCore.AnyCodable] {
        // Convert [String: AnyCodable] to [String: Value] for MCP
        var mcpArgs: [String: Value] = [:]
        for (key, val) in arguments {
            if let mcpVal = convertToValue(val.value) {
                mcpArgs[key] = mcpVal
            }
        }

        let result = await callTool(name: name, arguments: mcpArgs)
        
        // Convert MCP result to Gemini format
        var content = ""
        for item in result.content {
            if case .text(let text) = item {
                content += text
            }
        }

        return [
            "name": AnyCodable(name),
            "response": AnyCodable([
                "content": content,
                "success": !(result.isError ?? false)
            ])
        ]
    }

    private func setupHandlers() async {
        await server.withMethodHandler(ListTools.self) { [weak self] _ in
            guard let self = self else { throw MCPError.internalError("Deallocated") }
            let tools = await self.getTools()
            return ListTools.Result(tools: tools)
        }

        await server.withMethodHandler(CallTool.self) { [weak self] request in
            guard let self = self else { throw MCPError.internalError("Deallocated") }
            return await self.callTool(name: request.name, arguments: request.arguments)
        }
    }

    public func run(transport: any Transport) async throws {
        await setupHandlers()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }

    internal func getToolsInternal() -> [MCP.Tool] {
        return getTools()
    }

    internal func callTool(name: String, arguments: [String: Value]?) async -> CallTool.Result {
        guard let _ = toolRegistry.contract(for: name) else {
            return CallTool.Result(content: [.text("Tool not found: \(name)")], isError: true)
        }

        let tracker = ProgressTracker()
        await tracker.onProgress { [weak self] update in
            guard let self = self else { return }
            try? await self.server.notify(
                MCPProgressNotification.message(
                    .init(toolName: name, update: update)
                )
            )
        }
        await tracker.startPhase(.initializing, message: "Starting \(name)")

        do {
            let result = try await executeToolWithTimeout(toolName: name, config: timeoutConfig) {
                switch name {
                case "read_file": return await self.handleReadFile(arguments: arguments, progress: tracker)
                case "chat": return await self.handleChat(arguments: arguments)
                case "swift_build": return await self.handleSwiftBuild(arguments: arguments, progress: tracker)
                case "apply_patch": return await self.handleApplyPatch(arguments: arguments, progress: tracker)
                case "git_diff": return await self.handleGitDiff(arguments: arguments, progress: tracker)
                case "swift_test": return await self.handleSwiftTest(arguments: arguments, progress: tracker)
                case "trace_query": return await self.handleTraceQuery(arguments: arguments, progress: tracker)
                case "context_search": return await self.handleContextSearch(arguments: arguments, progress: tracker)
                case "list_artifacts": return await self.handleListArtifacts(arguments: arguments, progress: tracker)
                case "list_models": return await self.handleListModels(arguments: arguments, progress: tracker)
                case "download_model": return await self.handleDownloadModel(arguments: arguments, progress: tracker)
                case "import_local_model": return await self.handleImportLocalModel(arguments: arguments, progress: tracker)
                case "delete_model": return await self.handleDeleteModel(arguments: arguments, progress: tracker)
                case "verify_model": return await self.handleVerifyModel(arguments: arguments, progress: tracker)
                case "run_model": return await self.handleRunModel(arguments: arguments, progress: tracker)
                case "run_embedding": return await self.handleRunEmbedding(arguments: arguments, progress: tracker)
                case "digest_codebase": return await self.handleDigestCodebase(arguments: arguments, progress: tracker)
                case "codebase_index_purge": return await self.handleCodebaseIndexPurge(arguments: arguments, progress: tracker)
                case "context_purge": return await self.handleContextPurge(progress: tracker)
                case "get_system_health": return await self.handleGetSystemHealth(progress: tracker)
                case "list_active_alerts": return await self.handleListActiveAlerts(progress: tracker)
                case "database_query": return await self.handleDatabaseQuery(arguments: arguments, progress: tracker)
                case "create_tool_contract": return await self.handleCreateToolContract(arguments: arguments, progress: tracker)
                case "verify_evidence_chain": return await self.handleVerifyEvidenceChain(arguments: arguments, progress: tracker)
                case "get_module_status": return await self.handleGetModuleStatus(progress: tracker)
                case "delegate": return await self.handleDelegate(arguments: arguments, progress: tracker)
                default:
                    return CallTool.Result(content: [.text("Implementation pending for \(name)")])
                }
            }
            if result.isError == true {
                await tracker.error("Tool reported error.")
            } else {
                await tracker.completePhase(message: "Completed \(name)")
            }
            return result
        } catch {
            await tracker.error("Tool execution error: \(error)")
            return CallTool.Result(content: [.text("Tool execution error: \(error)")], isError: true)
        }
    }
}
