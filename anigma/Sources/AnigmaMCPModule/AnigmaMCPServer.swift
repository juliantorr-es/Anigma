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

private typealias WorkerArtifact = MLWorkerCommon.MLWorkerArtifact
private typealias WorkerEngine = ContractsCore.MLWorkerEngine
private typealias WorkerInput = MLWorkerCommon.MLArtifactRef
private typealias WorkerMetrics = MLWorkerCommon.MLWorkerMetrics
private typealias WorkerOptions = ContractsCore.MLTaskOptions
private typealias WorkerRequest = MLWorkerCommon.MLWorkerRequest
private typealias WorkerResponse = MLWorkerCommon.MLWorkerResponse
private typealias WorkerTask = ContractsCore.MLWorkerTask

/// The Anigma MCP Server implementation.
/// Exposes Harmonia tools, Contextum, ArtifactStore, ModelRegistry, Observatorium, and Cathedral capabilities via the Model Context Protocol.
public actor AnigmaMCPServer {
    private let server: Server
    private let toolRegistry: ToolRegistry
    private var runtime: PlatformRuntime?
    private var contextum: Contextum?
    private var artifactStore: ArtifactStoreModule?
    private var modelRegistry: (any ContractsCore.ModelRegistryProtocol)?
    private var modelDownloader: HuggingFaceAdapter?
    private var observatorium: ObservatoriumService?
    private var cathedral: CathedralCoordinator?

    // Scaling and Lifecycle infrastructure
    private let moduleInitializer = MCPModuleInitializer()
    private let timeoutConfig = ToolTimeoutConfig()

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
        // fputs("[anigma-mcp] Starting module initialization...\n", stderr)

        // Step 1: Initialize the Platform Runtime (Core infrastructure)
        await moduleInitializer.initializeModule(name: "runtime", timeout: 10) { @Sendable in
            try await self.initializeRuntime()
        }

        do {
            // Wait for runtime to be fully initialized before proceeding
            try await moduleInitializer.waitForModule("runtime")

            // Step 2: Initialize other modules sequentially to ensure deterministic startup
            // fputs("[anigma-mcp] Starting sequential module initialization...\n", stderr)

            // fputs("[anigma-mcp] Initializing Contextum...\n", stderr)
            try await self.initializeContextum()
            await moduleInitializer.markAsReady(name: "contextum")
            // fputs("[anigma-mcp] Contextum initialized successfully\n", stderr)

            // fputs("[anigma-mcp] Initializing ArtifactStore...\n", stderr)
            try await self.initializeArtifactStore()
            await moduleInitializer.markAsReady(name: "artifactStore")
            // fputs("[anigma-mcp] ArtifactStore initialized successfully\n", stderr)

            // fputs("[anigma-mcp] Initializing ModelRegistry...\n", stderr)
            try await self.initializeModelRegistry()
            await moduleInitializer.markAsReady(name: "modelRegistry")
            // fputs("[anigma-mcp] ModelRegistry initialized successfully\n", stderr)

            // fputs("[anigma-mcp] Initializing Observatorium...\n", stderr)
            try await self.initializeObservatorium()
            await moduleInitializer.markAsReady(name: "observatorium")
            // fputs("[anigma-mcp] Observatorium initialized successfully\n", stderr)

            // fputs("[anigma-mcp] Initializing Cathedral...\n", stderr)
            try await self.initializeCathedral()
            await moduleInitializer.markAsReady(name: "cathedral")
            // fputs("[anigma-mcp] Cathedral initialized successfully\n", stderr)
        } catch {
            fputs("[anigma-mcp] CRITICAL ERROR during sequential initialization: \(error)\n", stderr)
        }

        // fputs("[anigma-mcp] All module initializations completed\n", stderr)

        // Log final status
        let statuses = await moduleInitializer.getModuleStatuses()
        // fputs("[anigma-mcp] Module initialization complete:\n", stderr)
        for (_, info) in statuses.sorted(by: { $0.key < $1.key }) {
            // fputs("[anigma-mcp]   \(name): \(info.status)", stderr)
            if let error = info.error {
                fputs(" - ERROR: \(error)", stderr)
            }
            // fputs("\n", stderr)
        }
    }

    private func initializeRuntime() async throws {
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

    private func initializeContextum() async throws {
        guard let runtime = runtime else {
            throw RuntimeError.notInitialized
        }

        let databaseAdapter = DatabaseAuthorityAdapter(databaseAuthority: await runtime.database)
        // fputs("[anigma-mcp] Initializing Contextum with runtime database\n", stderr)
        let contextum = try await Contextum(dbActor: databaseAdapter)
        self.contextum = contextum
        // fputs("[anigma-mcp] Contextum initialized successfully\n", stderr)
    }

    private func initializeArtifactStore() async throws {
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
        let artifactDb = try await ArtifactStoreDatabase(dbActor: databaseAdapter)
        let artifactAuthority = await runtime.artifacts
        let artifactStore = ArtifactStoreModule(artifactAuthority: artifactAuthority, storageRoot: artifactsDir, database: artifactDb)
        self.artifactStore = artifactStore
    }

    private func initializeModelRegistry() async throws {
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

    private func initializeObservatorium() async throws {
        // Wait for runtime to be ready if it's not yet
        try await moduleInitializer.waitForModule("runtime")

        guard let runtime = self.runtime else {
            throw NSError(domain: "ModuleInit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Runtime missing"])
        }

        // fputs("[anigma-mcp] Initializing Observatorium...\n", stderr)
        let world = await runtime.getWorld()
        let governance = await runtime.governance
        let observatorium = ObservatoriumService(world: world, governance: governance)
        self.observatorium = observatorium
    }

    private func initializeCathedral() async throws {
        let coordinator = CathedralModule.create(
            config: CathedralConfig()
        )
        self.cathedral = coordinator
    }

    // MARK: - Gemini Bridge Support

    /// List all tools in Gemini-compatible format.
    public func listToolsForGemini() async throws -> [String: AnyCodable] {
        let tools = getTools()
        var functionDeclarations: [[String: AnyCodable]] = []

        for tool in tools {
            // MCP Tool inputSchema is already close to Gemini's parameters
            // We might need to transform it if Gemini expects specific format
            functionDeclarations.append([
                "name": AnyCodable(tool.name),
                "description": AnyCodable(tool.description ?? ""),
                "parameters": AnyCodable(tool.inputSchema)
            ])
        }

        return ["function_declarations": AnyCodable(functionDeclarations)]
    }

    /// Call a tool using Gemini-compatible parameters.
    public func callToolForGemini(name: String, arguments: [String: AnyCodable]) async throws -> [String: AnyCodable] {
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

    private func convertToValue(_ any: Any) -> Value? {
        if let s = any as? String { return .string(s) }
        if let i = any as? Int { return .number(Double(i)) }
        if let d = any as? Double { return .number(d) }
        if let b = any as? Bool { return .bool(b) }
        // Handle nested arrays/dicts if needed
        return nil
    }

    private nonisolated func registerDefaultTools() {
        // 1. read_file
        toolRegistry.register(contract: ToolContract(
            toolName: "read_file",
            toolDescription: "Securely reads the content of a file within the project directory.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "file_path": { "type": "string", "description": "Relative path to the file to read" },
                    "cache": { "type": "boolean", "description": "Use cached content when available", "default": true }
                },
                "required": ["file_path"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["filesystem"]
        ))

        // 1.1 chat
        toolRegistry.register(contract: ToolContract(
            toolName: "chat",
            toolDescription: "Interact with local frontier ML models (Llama 3.1, Qwen 2.5, Phi-3.5).",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "message": { "type": "string", "description": "Message to send to the model" },
                    "model_id": {
                        "type": "string",
                        "description": "Model to use",
                        "enum": ["llama-3.1-8b-instruct-4bit", "qwen-2.5-7b-coder-4bit", "phi-3.5-mini-instruct-4bit"],
                        "default": "llama-3.1-8b-instruct-4bit"
                    },
                    "max_tokens": { "type": "integer", "default": 512 },
                    "temperature": { "type": "number", "default": 0.7 }
                },
                "required": ["message"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["models", "inference"]
        ))

        // 2. swift_build
        toolRegistry.register(contract: ToolContract(
            toolName: "swift_build",
            toolDescription: "Triggers a deterministic build of a Swift package.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "package_path": { "type": "string", "description": "Path to the directory containing Package.swift" },
                    "target": { "type": "string", "description": "Optional target name to build" },
                    "configuration": { "type": "string", "enum": ["debug", "release"], "default": "debug" }
                }
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["shell", "build"]
        ))

        // 3. apply_patch
        toolRegistry.register(contract: ToolContract(
            toolName: "apply_patch",
            toolDescription: "Applies a unified diff patch with pre-flight validation for Swift concurrency, Sendable conformance, data races, and best practices.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "patch": { "type": "string", "description": "The unified diff patch content to apply" },
                    "target_files": { "type": "array", "items": { "type": "string" }, "description": "Optional allowlist of files to verify/apply" },
                    "rollback_on_failure": { "type": "boolean", "default": true, "description": "Rollback changes if verification or validation fails" },
                    "skip_validation": { "type": "boolean", "default": false, "description": "Skip Swift code validation (strict concurrency, Sendable, best practices)" }
                },
                "required": ["patch"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["filesystem", "write"],
            modifiesSystem: true
        ))

        // 4. git_diff
        toolRegistry.register(contract: ToolContract(
            toolName: "git_diff",
            toolDescription: "Inspects current changes in the repository.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "path": { "type": "string", "description": "Optional path filter" }
                }
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["shell", "git"]
        ))

        // 5. swift_test
        toolRegistry.register(contract: ToolContract(
            toolName: "swift_test",
            toolDescription: "Executes the project test suite.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "filter": { "type": "string", "description": "Specific test pattern to run" },
                    "verbose": { "type": "boolean", "description": "Enable verbose output", "default": false }
                }
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["shell", "test"]
        ))

        // 6. trace_query
        toolRegistry.register(contract: ToolContract(
            toolName: "trace_query",
            toolDescription: "Queries the system's execution history.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "taskId": { "type": "string" },
                    "limit": { "type": "integer", "default": 10 },
                    "offset": { "type": "integer", "default": 0 }
                }
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["database", "trace"]
        ))

        // 7. context_search
        toolRegistry.register(contract: ToolContract(
            toolName: "context_search",
            toolDescription: "Semantic and full-text search across project context.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "query": { "type": "string" },
                    "limit": { "type": "integer", "default": 10 }
                },
                "required": ["query"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["context", "search"]
        ))

        // 8. list_artifacts
        toolRegistry.register(contract: ToolContract(
            toolName: "list_artifacts",
            toolDescription: "Lists items in the project's artifact repository.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "media_type": { "type": "string" },
                    "limit": { "type": "integer", "default": 50 }
                }
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["artifacts", "read"]
        ))

        // 9. list_models
        toolRegistry.register(contract: ToolContract(
            toolName: "list_models",
            toolDescription: "Lists all registered local ML models.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "task": { "type": "string", "enum": ["inference", "embedding", "transcription", "classification", "image_generation", "speech_synthesis"] }
                }
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["models", "read"]
        ))

        // 9.1 download_model
        toolRegistry.register(contract: ToolContract(
            toolName: "download_model",
            toolDescription: "Downloads a HuggingFace model into the local registry.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "repo": { "type": "string", "description": "HuggingFace repo id" },
                    "revision": { "type": "string", "description": "Repo revision", "default": "main" }
                },
                "required": ["repo"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["models", "write"]
        ))

        // 9.2 import_local_model
        toolRegistry.register(contract: ToolContract(
            toolName: "import_local_model",
            toolDescription: "Registers a local model path into the registry.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "path": { "type": "string", "description": "Local file or directory path" },
                    "model_id": { "type": "string", "description": "Explicit model id" },
                    "task": { "type": "string", "enum": ["inference", "embedding", "transcription", "classification", "image_generation", "speech_synthesis"] },
                    "backend": { "type": "string", "enum": ["mlx", "gguf", "coreml"] },
                    "trust_tier": { "type": "string", "enum": ["first_class", "compatible", "experimental", "quarantined"] },
                    "license": { "type": "string", "description": "Declared license string" }
                },
                "required": ["path"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["models", "write"]
        ))

        // 9.3 delete_model
        toolRegistry.register(contract: ToolContract(
            toolName: "delete_model",
            toolDescription: "Deletes a model from the registry (optionally deletes files).",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "model_id": { "type": "string" },
                    "delete_files": { "type": "boolean", "default": false }
                },
                "required": ["model_id"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["models", "write"]
        ))

        // 9.4 verify_model
        toolRegistry.register(contract: ToolContract(
            toolName: "verify_model",
            toolDescription: "Verifies model integrity against stored hashes.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "model_id": { "type": "string" }
                },
                "required": ["model_id"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["models", "read"]
        ))

        // 9.5 run_model
        toolRegistry.register(contract: ToolContract(
            toolName: "run_model",
            toolDescription: "Runs a model inference task using ml-worker.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "model_id": { "type": "string" },
                    "task": { "type": "string", "enum": ["chat", "summarize", "classify", "transcribe"], "default": "chat" },
                    "prompt": { "type": "string" },
                    "input_path": { "type": "string" },
                    "seed": { "type": "integer", "default": 42 },
                    "max_tokens": { "type": "integer" },
                    "temperature": { "type": "number" },
                    "top_p": { "type": "number" },
                    "output_dir": { "type": "string" },
                    "output_path": { "type": "string" }
                },
                "required": ["model_id"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["models", "inference"]
        ))

        // 9.6 run_embedding
        toolRegistry.register(contract: ToolContract(
            toolName: "run_embedding",
            toolDescription: "Generates embeddings using a registered model.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "model_id": { "type": "string" },
                    "text": { "type": "string" },
                    "input_path": { "type": "string" },
                    "seed": { "type": "integer", "default": 42 },
                    "output_dir": { "type": "string" }
                },
                "required": ["model_id"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["models", "embedding"]
        ))

        // 10. digest_codebase
        toolRegistry.register(contract: ToolContract(
            toolName: "digest_codebase",
            toolDescription: "Crawls and indexes the entire project for searchable knowledge.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "path": { "type": "string" }
                }
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["context", "indexing"]
        ))

        // 10.1 codebase_index_purge
        toolRegistry.register(contract: ToolContract(
            toolName: "codebase_index_purge",
            toolDescription: "Clears the codebase index and optional search history.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "include_search_history": { "type": "boolean", "default": false }
                }
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["context", "administrative"]
        ))

        // 11. context_purge
        toolRegistry.register(contract: ToolContract(
            toolName: "context_purge",
            toolDescription: "Clears the search index.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: "{\"type\": \"object\", \"properties\": {}}",
            outputSchema: "{}",
            requiredCapabilities: ["context", "administrative"]
        ))

        // 12. get_system_health
        toolRegistry.register(contract: ToolContract(
            toolName: "get_system_health",
            toolDescription: "Retrieves overall system health summary.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: "{\"type\": \"object\", \"properties\": {}}",
            outputSchema: "{}",
            requiredCapabilities: ["observability", "health"]
        ))

        // 13. list_active_alerts
        toolRegistry.register(contract: ToolContract(
            toolName: "list_active_alerts",
            toolDescription: "Lists active system alerts.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: "{\"type\": \"object\", \"properties\": {}}",
            outputSchema: "{}",
            requiredCapabilities: ["observability", "alerts"]
        ))

        // 14. database_query
        toolRegistry.register(contract: ToolContract(
            toolName: "database_query",
            toolDescription: "Executes read-only SQL query against project database.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "sql": { "type": "string" },
                    "parameters": { "type": "object", "additionalProperties": { "type": "string" } }
                },
                "required": ["sql"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["database", "read"]
        ))

        // 15. create_tool_contract
        toolRegistry.register(contract: ToolContract(
            toolName: "create_tool_contract",
            toolDescription: "Dynamically registers a new tool capability.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "name": { "type": "string" },
                    "description": { "type": "string" },
                    "input_schema_json": { "type": "string" },
                    "capabilities": { "type": "array", "items": { "type": "string" } }
                },
                "required": ["name", "description", "input_schema_json"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["governance", "registration"]
        ))

        // 16. verify_evidence_chain
        toolRegistry.register(contract: ToolContract(
            toolName: "verify_evidence_chain",
            toolDescription: "Verifies integrity of operation history for a session.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "session_id": { "type": "string" }
                },
                "required": ["session_id"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["governance", "verification"]
        ))

        // 17. get_module_status
        toolRegistry.register(contract: ToolContract(
            toolName: "get_module_status",
            toolDescription: "Returns initialization status of MCP server modules.",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: "{\"type\": \"object\", \"properties\": {}}",
            outputSchema: "{}",
            requiredCapabilities: ["mcp", "status"]
        ))

        // 18. delegate
        toolRegistry.register(contract: ToolContract(
            toolName: "delegate",
            toolDescription: "Delegates a task to a specialized sub-agent (CLI wrapper or cloud API).",
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: """
            {
                "type": "object",
                "properties": {
                    "summary": { "type": "string", "description": "Short summary of the task to delegate" },
                    "details": { "type": "string", "description": "Detailed instructions for the sub-agent" },
                    "providerId": { "type": "string", "description": "Optional: force a specific provider (e.g. 'cloud-deepseek')" },
                    "requiredCapabilities": {
                        "type": "array",
                        "items": { "type": "string" },
                        "description": "Optional: capabilities required (e.g. ['chat', 'tools'])"
                    }
                },
                "required": ["summary"]
            }
            """,
            outputSchema: "{}",
            requiredCapabilities: ["orchestration", "delegation"]
        ))
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

    private func getTools() -> [MCP.Tool] {
        return AnigmaMCPBridge().getTools()
    }

    private func callTool(name: String, arguments: [String: Value]?) async -> CallTool.Result {
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

        // Core tools like read_file, swift_build, apply_patch, git_diff and swift_test send per-stage updates below.

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

    // MARK: - Handlers

    private func handleChat(arguments: [String: Value]?) async -> CallTool.Result {
        guard let message = arguments?["message"]?.stringValue else { return CallTool.Result(content: [.text("Missing message")], isError: true) }
        let modelID = arguments?["model_id"]?.stringValue ?? "llama-3.1-8b-instruct-4bit"
        let maxTokens = arguments?["max_tokens"]?.intValue ?? 512
        let temp = arguments?["temperature"]?.doubleValue ?? 0.7

        do {
            let input = try makeInputFromPrompt(message)
            defer {
                if input.isTemporary { try? FileManager.default.removeItem(atPath: input.path) }
            }

            let runtime: ModelRuntimeConfig
            if let registry = modelRegistry, let entry = try await registry.find(id: modelID) {
                runtime = try resolveRuntime(for: entry, task: .chat)
            } else {
                runtime = fallbackRuntime(for: modelID, task: .chat)
            }

            let request = WorkerRequest(
                requestId: UUID().uuidString,
                runId: UUID().uuidString,
                stepId: UUID().uuidString,
                engine: runtime.engine,
                task: .chat,
                inputs: [WorkerInput(path: input.path, hash: input.hash)],
                options: WorkerOptions(
                    seed: 42,
                    maxTokens: maxTokens,
                    temperature: temp,
                    topP: nil,
                    outputDirectory: nil
                )
            )

            let response = try runWorker(request: request, environment: runtime.environment)
            if response.status == .failed {
                return CallTool.Result(content: [.text(response.errorMessage ?? "Execution failed")], isError: true)
            }
            guard let output = response.outputs.first else {
                return CallTool.Result(content: [.text("No output artifact")], isError: true)
            }
            let responseText = try String(contentsOfFile: output.path, encoding: .utf8)
            return CallTool.Result(content: [.text(responseText)])
        } catch {
            return CallTool.Result(content: [.text("Chat execution error: \(error)")], isError: true)
        }
    }

    private func handleGetModuleStatus(progress: ProgressTracker?) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Gathering module status")
        let statuses = await moduleInitializer.getModuleStatuses()
        var text = "## Module Status\n\n"
        for (name, info) in statuses.sorted(by: { $0.key < $1.key }) {
            text += "### \(name)\n- Status: \(info.status)\n"
            if let err = info.error { text += "- Error: \(err)\n" }
        }
        await progress?.updateProgress(itemsProcessed: 1, totalItems: 1, currentItem: "Module status ready")
        return CallTool.Result(content: [.text(text)])
    }

    private func handleDelegate(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Delegating task")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 2, currentItem: "Preparing delegation payload")
        guard let summary = arguments?["summary"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing 'summary' parameter")], isError: true)
        }

        var params: [String: Any] = ["summary": summary]
        if let details = arguments?["details"]?.stringValue {
            params["details"] = details
        }
        if let providerId = arguments?["providerId"]?.stringValue {
            params["providerId"] = providerId
        }
        if let caps = arguments?["requiredCapabilities"]?.arrayValue?.compactMap({ $0.stringValue }) {
            params["requiredCapabilities"] = caps
        }

        let paramsData = (try? JSONSerialization.data(withJSONObject: params)) ?? Data("{}".utf8)
        let paramsString = String(data: paramsData, encoding: .utf8) ?? "{}"

        let tool = DelegateTool()
        let result = await tool.execute(
            ToolCallRequest(toolName: "delegate", sessionId: "mcp", parameters: paramsString),
            session: SessionContext(sessionId: "mcp", agentId: "mcp", permissions: Set(Permission.allCases))
        )
        await progress?.updateProgress(itemsProcessed: 2, totalItems: 2, currentItem: "Delegation complete")
        return result.mcpResult
    }

    private func handleContextSearch(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        guard let query = arguments?["query"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing query")], isError: true)
        }
        let limit = arguments?["limit"]?.intValue ?? 10

        let params: [String: Any] = [
            "query": query,
            "limit": limit
        ]
        let paramsData = (try? JSONSerialization.data(withJSONObject: params))
            ?? Data("{}".utf8)
        let paramsString = String(data: paramsData, encoding: .utf8) ?? "{}"

        await progress?.startPhase(.processing, message: "Running context search")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 2, currentItem: "Preparing search")
        let tool = ContextSearchTool()
        let result = await tool.execute(
            ToolCallRequest(toolName: "context_search", sessionId: "mcp", parameters: paramsString),
            session: SessionContext(sessionId: "mcp", agentId: "mcp", permissions: Set(Permission.allCases))
        )
        await progress?.updateProgress(itemsProcessed: 2, totalItems: 2, currentItem: "Context search ready")
        return result.mcpResult
    }

    private func handleListArtifacts(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Listing artifacts")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 1, currentItem: "Fetching artifacts")
        guard let artifactStore = artifactStore else {
            return CallTool.Result(content: [.text("ArtifactStore pending")], isError: true)
        }
        let mediaType = arguments?["media_type"]?.stringValue
        let limit = arguments?["limit"]?.intValue ?? 50
        do {
            let artifacts = try await artifactStore.listArtifacts(mediaType: mediaType, limit: limit)
            let text = artifacts.map { "ID: \($0.artifactID)\nType: \($0.mediaType)\nHash: \($0.contentHash)\n" }.joined(separator: "\n---\n\n")
            await progress?.updateProgress(itemsProcessed: 1, totalItems: 1, currentItem: "Artifacts ready")
            return CallTool.Result(content: [.text(text.isEmpty ? "None" : text)])
        } catch {
            return CallTool.Result(content: [.text("Error: \(error)")], isError: true)
        }
    }

    private func handleListModels(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Listing models")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 1, currentItem: "Querying registry")
        guard let modelRegistry = modelRegistry else {
            return CallTool.Result(content: [.text("ModelRegistry pending")], isError: true)
        }
        let taskRaw = arguments?["task"]?.stringValue
        do {
            let taskKind = try taskRaw.map { try parseModelTaskKind($0) }
            let models = try await modelRegistry.query(ModelQuery(taskKind: taskKind))
            let text = models.map {
                [
                    "ID: \($0.id)",
                    "Task: \($0.spec.task.rawValue)",
                    "Backend: \($0.spec.backend.rawValue)",
                    "Trust: \($0.spec.trustTier.rawValue)",
                    "Status: \($0.status.rawValue)",
                    "Source: \($0.spec.source.identifier)",
                    "Install: \($0.installPath)"
                ].joined(separator: "\n")
            }.joined(separator: "\n---\n\n")
            await progress?.updateProgress(itemsProcessed: 1, totalItems: 1, currentItem: "Models ready")
            return CallTool.Result(content: [.text(text.isEmpty ? "None" : text)])
        } catch {
            return CallTool.Result(content: [.text("Error: \(error)")], isError: true)
        }
    }

    private func handleDownloadModel(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Downloading model")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 3, currentItem: "Checking configuration")
        guard let modelRegistry = modelRegistry else {
            return CallTool.Result(content: [.text("ModelRegistry pending")], isError: true)
        }
        guard let modelDownloader = modelDownloader else {
            return CallTool.Result(content: [.text("Model downloader pending")], isError: true)
        }
        guard let repo = arguments?["repo"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing repo")], isError: true)
        }
        let revision = arguments?["revision"]?.stringValue ?? "main"

        do {
            await progress?.updateProgress(itemsProcessed: 1, totalItems: 3, currentItem: "Downloading and verifying")
            let result = try await modelDownloader.fetchAndVerify(repo: repo, revision: revision)
            let spec = try updateStorageBytes(spec: result.spec, installPath: result.installPath)
            let entry = try await modelRegistry.register(spec, installPath: result.installPath)
            var text = "Model ID: \(entry.id)\nInstall: \(entry.installPath)\nTrust: \(entry.spec.trustTier.rawValue)"
            if result.conversionNeeded {
                text += "\nConversion: required"
            }
            if !result.warnings.isEmpty {
                text += "\nWarnings: \(result.warnings.joined(separator: "; "))"
            }
            await progress?.updateProgress(itemsProcessed: 3, totalItems: 3, currentItem: "Download complete")
            return CallTool.Result(content: [.text(text)])
        } catch {
            return CallTool.Result(content: [.text("Error: \(error)")], isError: true)
        }
    }

    private func handleImportLocalModel(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Importing local model")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 3, currentItem: "Validating inputs")
        guard let modelRegistry = modelRegistry else {
            return CallTool.Result(content: [.text("ModelRegistry pending")], isError: true)
        }
        guard let path = arguments?["path"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing path")], isError: true)
        }

        do {
            await progress?.updateProgress(itemsProcessed: 1, totalItems: 3, currentItem: "Building artifact metadata")
            let url = URL(fileURLWithPath: path).standardizedFileURL
            let (installPath, hashes, bytes) = try buildArtifactHashes(for: url)

            let modelId = arguments?["model_id"]?.stringValue ?? defaultModelId(for: url)
            let taskKind = try arguments?["task"]?.stringValue.map { try parseModelTaskKind($0) } ?? .inference
            let backend = try arguments?["backend"]?.stringValue.map { try parseBackend($0) } ?? inferBackend(for: url)
            let trustTier = try arguments?["trust_tier"]?.stringValue.map { try parseTrustTier($0) } ?? .compatible

            var metadata: [String: String] = [:]
            if url.pathExtension.lowercased() == "gguf" {
                metadata["model_file"] = url.lastPathComponent
            }

            let license = arguments?["license"]?.stringValue ?? "local"
            let licenseDecision = LicenseDecision(
                declared: license,
                allowed: true,
                reason: "Local import",
                timestamp: Date()
            )

            let spec = ModelSpec(
                id: modelId,
                source: .localPath(url.path),
                task: taskKind,
                backend: backend,
                trustTier: trustTier,
                license: licenseDecision,
                artifactHashes: hashes,
                tokenizerHash: nil,
                conversionReceipt: nil,
                metadata: metadata,
                registeredAt: Date(),
                verifiedAt: Date(),
                storageBytes: bytes
            )

            let entry = try await modelRegistry.register(spec, installPath: installPath)
            await progress?.updateProgress(itemsProcessed: 2, totalItems: 3, currentItem: "Registering model")
            let text = "Model ID: \(entry.id)\nInstall: \(entry.installPath)\nTrust: \(entry.spec.trustTier.rawValue)"
            await progress?.updateProgress(itemsProcessed: 3, totalItems: 3, currentItem: "Model import complete")
            return CallTool.Result(content: [.text(text)])
        } catch {
            return CallTool.Result(content: [.text("Error: \(error)")], isError: true)
        }
    }

    private func handleDeleteModel(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Deleting model")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 2, currentItem: "Locating model")
        guard let modelRegistry = modelRegistry else {
            return CallTool.Result(content: [.text("ModelRegistry pending")], isError: true)
        }
        guard let modelId = arguments?["model_id"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing model_id")], isError: true)
        }
        let deleteFiles = arguments?["delete_files"]?.boolValue ?? false

        do {
            guard let entry = try await modelRegistry.find(id: modelId) else {
                return CallTool.Result(content: [.text("Model not found: \(modelId)")], isError: true)
            }
            if deleteFiles && !entry.installPath.isEmpty {
                let url = URL(fileURLWithPath: entry.installPath)
                if url.path.count > 1, FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
            }
            try await modelRegistry.delete(modelId)
            await progress?.updateProgress(itemsProcessed: 2, totalItems: 2, currentItem: "Delete complete")
            return CallTool.Result(content: [.text("Deleted \(modelId)")])
        } catch {
            return CallTool.Result(content: [.text("Error: \(error)")], isError: true)
        }
    }

    private func handleVerifyModel(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Verifying model integrity")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 1, currentItem: "Checking registry")
        guard let modelRegistry = modelRegistry else {
            return CallTool.Result(content: [.text("ModelRegistry pending")], isError: true)
        }
        guard let modelId = arguments?["model_id"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing model_id")], isError: true)
        }
        do {
            let valid = try await modelRegistry.verifyIntegrity(modelId)
            await progress?.updateProgress(itemsProcessed: 1, totalItems: 1, currentItem: "Integrity check complete")
            return CallTool.Result(content: [.text("Model \(modelId) integrity: \(valid ? "valid" : "invalid")")])
        } catch {
            return CallTool.Result(content: [.text("Error: \(error)")], isError: true)
        }
    }

    private func handleRunModel(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Running model")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 3, currentItem: "Resolving model")
        guard let modelRegistry = modelRegistry else {
            return CallTool.Result(content: [.text("ModelRegistry pending")], isError: true)
        }
        guard let modelId = arguments?["model_id"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing model_id")], isError: true)
        }

        let taskRaw = arguments?["task"]?.stringValue ?? "chat"
        let prompt = arguments?["prompt"]?.stringValue
        let inputPath = arguments?["input_path"]?.stringValue
        let seed = arguments?["seed"]?.intValue ?? 42
        let maxTokens = arguments?["max_tokens"]?.intValue
        let temperature = arguments?["temperature"]?.doubleValue
        let topP = arguments?["top_p"]?.doubleValue
        let outputDir = arguments?["output_dir"]?.stringValue
        let outputPath = arguments?["output_path"]?.stringValue

        do {
            guard let entry = try await modelRegistry.find(id: modelId) else {
                return CallTool.Result(content: [.text("Model not found: \(modelId)")], isError: true)
            }
            await progress?.updateProgress(itemsProcessed: 1, totalItems: 3, currentItem: "Preparing worker")
            let workerTask = try parseWorkerTask(taskRaw)
            let runtime = try resolveRuntime(for: entry, task: workerTask)
            let input = try resolveInput(prompt: prompt, inputPath: inputPath)

            defer {
                if input.isTemporary { try? FileManager.default.removeItem(atPath: input.path) }
            }

            let request = WorkerRequest(
                requestId: UUID().uuidString,
                runId: UUID().uuidString,
                stepId: UUID().uuidString,
                engine: runtime.engine,
                task: workerTask,
                inputs: [WorkerInput(path: input.path, hash: input.hash)],
                options: WorkerOptions(
                    seed: seed,
                    maxTokens: maxTokens,
                    temperature: temperature,
                    topP: topP,
                    outputDirectory: outputDir
                )
            )

            let response = try runWorker(request: request, environment: runtime.environment)
            await progress?.updateProgress(itemsProcessed: 2, totalItems: 3, currentItem: "Processing output")
            if response.status == MLWorkerCommon.MLWorkerResponse.Status.failed {
                return CallTool.Result(content: [.text(response.errorMessage ?? "Execution failed")], isError: true)
            }
            guard let output = response.outputs.first else {
                return CallTool.Result(content: [.text("No output artifact")], isError: true)
            }

            let outputText = try String(contentsOfFile: output.path, encoding: String.Encoding.utf8)
            if let outputPath {
                let outURL = URL(fileURLWithPath: outputPath)
                try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try outputText.write(to: outURL, atomically: true, encoding: String.Encoding.utf8)
            }

            let text = "Output:\n\(outputText)\n\nArtifact: \(output.path)\nHash: \(output.hash)"
            await progress?.updateProgress(itemsProcessed: 3, totalItems: 3, currentItem: "Model run complete")
            return CallTool.Result(content: [.text(text)])
        } catch {
            return CallTool.Result(content: [.text("Error: \(error)")], isError: true)
        }
    }

    private func handleRunEmbedding(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Running embedding")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 3, currentItem: "Resolving model")
        guard let modelRegistry = modelRegistry else {
            return CallTool.Result(content: [.text("ModelRegistry pending")], isError: true)
        }
        guard let modelId = arguments?["model_id"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing model_id")], isError: true)
        }

        let text = arguments?["text"]?.stringValue
        let inputPath = arguments?["input_path"]?.stringValue
        let seed = arguments?["seed"]?.intValue ?? 42
        let outputDir = arguments?["output_dir"]?.stringValue

        do {
            await progress?.updateProgress(itemsProcessed: 1, totalItems: 3, currentItem: "Preparing runtime")
            guard let entry = try await modelRegistry.find(id: modelId) else {
                return CallTool.Result(content: [.text("Model not found: \(modelId)")], isError: true)
            }

            let runtime = try resolveRuntime(for: entry, task: .embed)
            let input = try resolveInput(prompt: text, inputPath: inputPath)

            defer {
                if input.isTemporary { try? FileManager.default.removeItem(atPath: input.path) }
            }

            let request = WorkerRequest(
                requestId: UUID().uuidString,
                runId: UUID().uuidString,
                stepId: UUID().uuidString,
                engine: runtime.engine,
                task: .embed,
                inputs: [WorkerInput(path: input.path, hash: input.hash)],
                options: WorkerOptions(
                    seed: seed,
                    maxTokens: nil,
                    temperature: nil,
                    topP: nil,
                    outputDirectory: outputDir
                )
            )

            let response = try runWorker(request: request, environment: runtime.environment)
            await progress?.updateProgress(itemsProcessed: 2, totalItems: 3, currentItem: "Processing embedding")
            if response.status == MLWorkerCommon.MLWorkerResponse.Status.failed {
                return CallTool.Result(content: [.text(response.errorMessage ?? "Execution failed")], isError: true)
            }
            guard let output = response.outputs.first else {
                return CallTool.Result(content: [.text("No output artifact")], isError: true)
            }

            let summary = "Embedding artifact: \(output.path)\nHash: \(output.hash)"
            await progress?.updateProgress(itemsProcessed: 3, totalItems: 3, currentItem: "Embedding complete")
            return CallTool.Result(content: [.text(summary)])
        } catch {
            return CallTool.Result(content: [.text("Error: \(error)")], isError: true)
        }
    }

    private func handleDigestCodebase(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        let rootPath = arguments?["path"]?.stringValue ?? FileManager.default.currentDirectoryPath
        await progress?.startPhase(.indexing, message: "Digesting codebase")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 2, currentItem: "Discovering sources")
        let tool = EnhancedDigestCodebaseTool(workingDirectory: URL(fileURLWithPath: rootPath))
        let result = await tool.execute(
            ToolCallRequest(toolName: "digest_codebase", sessionId: "mcp", parameters: "{}"),
            session: SessionContext(sessionId: "mcp", agentId: "mcp", permissions: Set(Permission.allCases))
        )
        await progress?.updateProgress(itemsProcessed: 2, totalItems: 2, currentItem: "Digest complete")
        return result.mcpResult
    }

    private func handleCodebaseIndexPurge(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Purging codebase index")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 2, currentItem: "Clearing index tables")
        let includeSearchHistory = arguments?["include_search_history"]?.boolValue ?? false
        let dbPath = codebaseDatabasePath()
        let db = DatabaseActor(dbPath: dbPath)

        do {
            try await db.open()
            try await CodebaseIndexSchema.apply(using: db)
            try await SearchSchema.apply(using: db)

            try await db.execute("DELETE FROM code_symbols")
            try await db.execute("DELETE FROM indexed_files")
            try await db.execute("DELETE FROM content_embeddings")

            if includeSearchHistory {
                try await db.execute("DELETE FROM search_clicks")
                try await db.execute("DELETE FROM search_feedback")
                try await db.execute("DELETE FROM search_queries")
                try await db.execute("DELETE FROM search_sessions")
                try await db.execute("DELETE FROM term_mappings")
            }

            let message = includeSearchHistory
                ? "Purged codebase index and search history."
                : "Purged codebase index."
            await progress?.updateProgress(itemsProcessed: 2, totalItems: 2, currentItem: "Purge complete")
            return CallTool.Result(content: [.text(message)])
        } catch {
            return CallTool.Result(content: [.text("Error: \(error)")], isError: true)
        }
    }

    private func handleContextPurge(progress: ProgressTracker?) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Purging context database")
        guard let contextum = contextum else {
            return CallTool.Result(content: [.text("Contextum pending")], isError: true)
        }
        try? await contextum.database.clearAll()
        await progress?.updateProgress(itemsProcessed: 1, totalItems: 1, currentItem: "Context purge complete")
        return CallTool.Result(content: [.text("Purged")])
    }

    private func handleGetSystemHealth(progress: ProgressTracker?) async -> CallTool.Result {
        await progress?.startPhase(.analyzing, message: "Gathering system health")
        guard let observatorium = observatorium else {
            return CallTool.Result(content: [.text("Observatorium pending")], isError: true)
        }
        let summary = await observatorium.getHealthSummary()
        await progress?.updateProgress(itemsProcessed: 1, totalItems: 1, currentItem: "System health ready")
        return CallTool.Result(content: [.text("Status: \(summary.status.rawValue)\nAlerts: \(summary.activeAlerts)\nErrors: \(summary.recentErrors)")])
    }

    private func handleListActiveAlerts(progress: ProgressTracker?) async -> CallTool.Result {
        await progress?.startPhase(.analyzing, message: "Listing active alerts")
        guard let observatorium = observatorium else {
            return CallTool.Result(content: [.text("Observatorium pending")], isError: true)
        }
        let alerts = await observatorium.alerts.getActiveAlerts()
        await progress?.updateProgress(itemsProcessed: 1, totalItems: 1, currentItem: "Alerts ready")
        let text = alerts.map { "[\($0.severity.rawValue)] \($0.title)\n\($0.message)\n" }.joined(separator: "\n---\n\n")
        return CallTool.Result(content: [.text(text.isEmpty ? "None" : text)])
    }

    private func handleDatabaseQuery(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.processing, message: "Executing database query")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 1, currentItem: "Running SQL")
        guard let runtime = runtime else {
            return CallTool.Result(content: [.text("Runtime pending")], isError: true)
        }
        guard let sql = arguments?["sql"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing SQL")], isError: true)
        }
        let params = arguments?["parameters"]?.objectValue?.compactMapValues { $0.stringValue } ?? [:]
        do {
            let rows = try await runtime.database.query(sql, parameters: params)
            let text: String = rows.enumerated().map { offset, row in
                let rowText = row.values
                    .sorted { $0.key < $1.key }
                    .map { "\($0.key): \(formatDatabaseValue($0.value))" }
                    .joined(separator: "\n")
                return "Row \(offset + 1):\n\(rowText)"
            }.joined(separator: "\n---\n\n")
            await progress?.updateProgress(itemsProcessed: 1, totalItems: 1, currentItem: "Query complete")
            return CallTool.Result(content: [.text(text.isEmpty ? "No rows" : text)])
        } catch {
            return CallTool.Result(content: [.text("Error: \(error)")], isError: true)
        }
    }

    private func codebaseDatabasePath() -> String {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Failed to unwrap appSupport")
        }
        let anigmaDir = appSupport.appendingPathComponent("Anigma", isDirectory: true)
        return anigmaDir.appendingPathComponent("codebase.sqlite").path
    }

    private enum ModelToolError: Error, CustomStringConvertible {
        case invalidArgument(String)
        case unsupportedBackend(String)
        case workerNotFound
        case workerFailed(String)

        var description: String {
            switch self {
            case .invalidArgument(let message):
                return message
            case .unsupportedBackend(let backend):
                return "Backend not supported: \(backend)"
            case .workerNotFound:
                return "ml-worker binary not found"
            case .workerFailed(let message):
                return "ml-worker failed: \(message)"
            }
        }
    }

    private struct ModelRuntimeConfig {
        let engine: WorkerEngine
        let environment: [String: String]
    }

    private struct ModelInput {
        let path: String
        let hash: String
        let isTemporary: Bool
    }

    private func parseModelTaskKind(_ raw: String) throws -> ModelTaskKind {
        guard let task = ModelTaskKind(rawValue: raw) else {
            throw ModelToolError.invalidArgument("Unknown task: \(raw)")
        }
        return task
    }

    private func parseBackend(_ raw: String) throws -> MLBackend {
        guard let backend = MLBackend(rawValue: raw) else {
            throw ModelToolError.invalidArgument("Unknown backend: \(raw)")
        }
        return backend
    }

    private func parseTrustTier(_ raw: String) throws -> ModelTrustTier {
        guard let tier = ModelTrustTier(rawValue: raw) else {
            throw ModelToolError.invalidArgument("Unknown trust tier: \(raw)")
        }
        return tier
    }

    private func parseWorkerTask(_ raw: String) throws -> WorkerTask {
        guard let task = WorkerTask(rawValue: raw) else {
            throw ModelToolError.invalidArgument("Unknown worker task: \(raw)")
        }
        return task
    }

    private func resolveRuntime(for entry: ContractsCore.ModelRegistryEntry, task: WorkerTask) throws -> ModelRuntimeConfig {
        switch entry.spec.backend {
        case .mlx:
            var env = ProcessInfo.processInfo.environment
            let identifier = mlxIdentifier(for: entry.spec)
            env["MLX_MODEL_ID"] = identifier
            if task == .embed {
                env["MLX_MODEL_ID_EMBED"] = identifier
            } else {
                env["MLX_MODEL_ID_CHAT"] = identifier
            }
            if !entry.installPath.isEmpty {
                env["MLX_MODEL_PATH"] = entry.installPath
            }
            return ModelRuntimeConfig(engine: .mlx, environment: env)
        case .gguf:
            var env = ProcessInfo.processInfo.environment
            let modelPath = try resolveGGUFModelPath(entry: entry)
            env["LLAMA_MODEL_PATH"] = modelPath
            return ModelRuntimeConfig(engine: .llama, environment: env)
        case .coreml:
            throw ModelToolError.unsupportedBackend(entry.spec.backend.rawValue)
        }
    }

    private func fallbackRuntime(for modelId: String, task: WorkerTask) -> ModelRuntimeConfig {
        var env = ProcessInfo.processInfo.environment
        env["MLX_MODEL_ID"] = modelId
        if task == .embed {
            env["MLX_MODEL_ID_EMBED"] = modelId
        } else {
            env["MLX_MODEL_ID_CHAT"] = modelId
        }
        return ModelRuntimeConfig(engine: .mlx, environment: env)
    }

    private func mlxIdentifier(for spec: ModelSpec) -> String {
        switch spec.source {
        case .huggingFace(let repo, _):
            return repo
        case .localPath(let path):
            return path
        case .bundled(let name):
            return name
        }
    }

    private func resolveGGUFModelPath(entry: ContractsCore.ModelRegistryEntry) throws -> String {
        if let file = entry.spec.metadata["model_file"] {
            return URL(fileURLWithPath: entry.installPath).appendingPathComponent(file).path
        }

        let baseURL = URL(fileURLWithPath: entry.installPath)
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: baseURL.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            return baseURL.path
        }

        let files = try FileManager.default.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil)
        if let gguf = files.first(where: { $0.pathExtension.lowercased() == "gguf" }) {
            return gguf.path
        }

        throw ModelToolError.invalidArgument("No .gguf file found in \(entry.installPath)")
    }

    private func resolveWorkerPath() -> String? {
        let env = ProcessInfo.processInfo.environment
        if let override = env["ML_WORKER_PATH"], FileManager.default.isExecutableFile(atPath: override) {
            return override
        }

        let cwd = FileManager.default.currentDirectoryPath
        let candidates = [
            "\(cwd)/.build/arm64-apple-macosx/release/ml-worker",
            "\(cwd)/.build/arm64-apple-macosx/debug/ml-worker",
            "\(cwd)/.build/release/ml-worker",
            "\(cwd)/.build/debug/ml-worker",
            "/usr/local/bin/ml-worker"
        ]

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private func runWorker(request: WorkerRequest, environment: [String: String]) throws -> WorkerResponse {
        guard let workerPath = resolveWorkerPath() else {
            throw ModelToolError.workerNotFound
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: workerPath)
        process.arguments = ["--engine", request.engine.rawValue]
        process.environment = environment

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let payload = try encoder.encode(request)
        inputPipe.fileHandleForWriting.write(payload + Data("\n".utf8))
        try inputPipe.fileHandleForWriting.close()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorText = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ModelToolError.workerFailed(errorText)
        }

        let responseLine = outputData
            .split(separator: UInt8(ascii: "\n"))
            .first { !$0.isEmpty }
        guard let responseLine else {
            throw ModelToolError.workerFailed("No response from worker")
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(WorkerResponse.self, from: Data(responseLine))
        } catch {
            let errorText = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ModelToolError.workerFailed("Decode failed: \(error). stderr: \(errorText)")
        }
    }

    private func resolveInput(prompt: String?, inputPath: String?) throws -> ModelInput {
        if let inputPath {
            return try makeInputFromFile(inputPath)
        }
        guard let prompt, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ModelToolError.invalidArgument("Provide prompt or input_path")
        }
        return try makeInputFromPrompt(prompt)
    }

    private func makeInputFromPrompt(_ prompt: String) throws -> ModelInput {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcp_prompt_\(UUID().uuidString).txt")
        try prompt.write(to: tempFile, atomically: true, encoding: .utf8)
        let hash = MLWorkerHasher.hashData(Data(prompt.utf8))
        return ModelInput(path: tempFile.path, hash: hash, isTemporary: true)
    }

    private func makeInputFromFile(_ path: String) throws -> ModelInput {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let hash = MLWorkerHasher.hashData(data)
        return ModelInput(path: url.path, hash: hash, isTemporary: false)
    }

    private func sha256Hex(url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 1024 * 1024) ?? Data()
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        let digest = hasher.finalize()
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func buildArtifactHashes(for path: URL) throws -> (installPath: String, hashes: [String: String], bytes: Int64) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path.path, isDirectory: &isDirectory) else {
            throw ModelToolError.invalidArgument("Path does not exist: \(path.path)")
        }

        if !isDirectory.boolValue {
            let hash = try sha256Hex(url: path)
            let parent = path.deletingLastPathComponent()
            let size = try path.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            return (parent.path, [path.lastPathComponent: hash], Int64(size))
        }

        let basePath = path.path
        let enumerator = FileManager.default.enumerator(
            at: path,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        var hashes: [String: String] = [:]
        var bytes: Int64 = 0

        while let fileURL = enumerator?.nextObject() as? URL {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true else { continue }
            let relativePath = fileURL.path.replacingOccurrences(of: basePath + "/", with: "")
            let hash = try sha256Hex(url: fileURL)
            hashes[relativePath] = hash
            bytes += Int64(values.fileSize ?? 0)
        }

        return (basePath, hashes, bytes)
    }

    private func inferBackend(for path: URL) throws -> MLBackend {
        let ext = path.pathExtension.lowercased()
        if ext == "gguf" { return .gguf }
        if ext == "mlmodel" || ext == "mlpackage" { return .coreml }

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: path.path, isDirectory: &isDirectory), isDirectory.boolValue {
            let enumerator = FileManager.default.enumerator(at: path, includingPropertiesForKeys: nil)
            while let fileURL = enumerator?.nextObject() as? URL {
                let ext = fileURL.pathExtension.lowercased()
                if ext == "gguf" { return .gguf }
                if ext == "mlmodel" || ext == "mlpackage" { return .coreml }
                if ext == "safetensors" { return .mlx }
            }
        }

        return .mlx
    }

    private func defaultModelId(for path: URL) -> String {
        let base = path.deletingPathExtension().lastPathComponent
        return base.isEmpty ? "local-model-\(UUID().uuidString)" : base
    }

    private func updateStorageBytes(spec: ModelSpec, installPath: String) throws -> ModelSpec {
        guard !installPath.isEmpty else { return spec }
        let url = URL(fileURLWithPath: installPath)
        var bytes: Int64 = 0

        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard values.isRegularFile == true else { continue }
                bytes += Int64(values.fileSize ?? 0)
            }
        }

        return ModelSpec(
            id: spec.id,
            source: spec.source,
            task: spec.task,
            backend: spec.backend,
            trustTier: spec.trustTier,
            license: spec.license,
            artifactHashes: spec.artifactHashes,
            tokenizerHash: spec.tokenizerHash,
            conversionReceipt: spec.conversionReceipt,
            metadata: spec.metadata,
            registeredAt: spec.registeredAt,
            verifiedAt: spec.verifiedAt,
            storageBytes: bytes
        )
    }

    private func formatDatabaseValue(_ value: DatabaseValue) -> String {
        switch value {
        case .text(let text):
            return text
        case .int(let int):
            return String(int)
        case .double(let double):
            return String(double)
        case .blob(let data):
            return "<blob \(data.count) bytes>"
        case .null:
            return "null"
        }
    }

    private func handleCreateToolContract(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.initializing, message: "Creating tool contract")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 2, currentItem: "Validating parameters")
        guard let name = arguments?["name"]?.stringValue,
              let desc = arguments?["description"]?.stringValue,
              let schema = arguments?["input_schema_json"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing params")], isError: true)
        }
        let caps = arguments?["capabilities"]?.arrayValue?.compactMap { $0.stringValue } ?? ["custom"]
        await progress?.updateProgress(itemsProcessed: 1, totalItems: 2, currentItem: "Registering contract")
        let contract = ToolContract(
            toolName: name,
            toolDescription: desc,
            contractVersion: ToolContractVersion(major: 1, minor: 0, patch: 0),
            inputSchema: schema,
            outputSchema: "{}",
            requiredCapabilities: caps
        )
        toolRegistry.register(contract: contract)
        await progress?.updateProgress(itemsProcessed: 2, totalItems: 2, currentItem: "Contract ready")
        return CallTool.Result(content: [.text("Registered \(name)")])
    }

    private func handleVerifyEvidenceChain(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        await progress?.startPhase(.analyzing, message: "Verifying evidence chain")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 1, currentItem: "Checking Cathedral context")
        guard let ctx = self.cathedral else {
            return CallTool.Result(content: [.text("Cathedral pending")], isError: true)
        }
        guard let sid = arguments?["session_id"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing session_id")], isError: true)
        }
        do {
            let val = try await ctx.validateEvidenceChain(sessionId: sid)
            let hashStr = val.lastHash ?? "N/A"
            await progress?.updateProgress(itemsProcessed: 1, totalItems: 1, currentItem: "Evidence chain verified")
            return CallTool.Result(content: [.text("Valid: \(val.isValid)\nLength: \(val.chainLength)\nHash: \(hashStr)")], isError: false)
        } catch {
            return CallTool.Result(content: [.text("Error: \(error)")], isError: true)
        }
    }

    private func handleReadFile(arguments: [String: Value]?, progress: ProgressTracker? = nil) async -> CallTool.Result {
        guard let path = arguments?["file_path"]?.stringValue else {
            return CallTool.Result(content: [.text("Missing path")], isError: true)
        }

        var params: [String: Any] = ["file_path": path]
        if let cache = arguments?["cache"]?.boolValue {
            params["cache"] = cache
        }

        await progress?.startPhase(.processing, message: "Reading \(path)")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 1, currentItem: path)

        let paramsData = (try? JSONSerialization.data(withJSONObject: params))
            ?? Data("{}".utf8)
        let paramsString = String(data: paramsData, encoding: .utf8) ?? "{}"

        let tool = ReadFileTool()
        let result = await tool.execute(
            ToolCallRequest(toolName: "read_file", sessionId: "mcp", parameters: paramsString),
            session: SessionContext(
                sessionId: "mcp",
                agentId: "mcp",
                permissions: Set(Permission.allCases)
            )
        )
        await progress?.updateProgress(itemsProcessed: 1, totalItems: 1, currentItem: path)
        return result.mcpResult
    }

    private func handleSwiftBuild(arguments: [String: Value]?, progress: ProgressTracker? = nil) async -> CallTool.Result {
        let path = arguments?["package_path"]?.stringValue ?? FileManager.default.currentDirectoryPath
        let target = arguments?["target"]?.stringValue
        let configuration = arguments?["configuration"]?.stringValue

        var params: [String: Any] = ["package_path": path]
        if let target = target { params["target"] = target }
        if let configuration = configuration { params["configuration"] = configuration }
        let paramsData = (try? JSONSerialization.data(withJSONObject: params))
            ?? Data("{}".utf8)
        let paramsString = String(data: paramsData, encoding: .utf8) ?? "{}"

        let trackerRef = progress
        let progressCallback: ToolProgressCallback? = if trackerRef == nil {
            nil
        } else {
            { processed, total, message in
                guard let tracker = trackerRef else { return }
                await tracker.updateProgress(itemsProcessed: processed, totalItems: total, currentItem: message)
            }
        }
        let tool = SwiftBuildTool(progressCallback: progressCallback)
        let result = await tool.execute(
            ToolCallRequest(toolName: "swift_build", sessionId: "mcp", parameters: paramsString),
            session: SessionContext(
                sessionId: "mcp",
                agentId: "mcp",
                permissions: Set(Permission.allCases),
                allowGovernedBuild: true
            )
        )
        return result.mcpResult
    }

    private func handleApplyPatch(arguments: [String: Value]?, progress: ProgressTracker? = nil) async -> CallTool.Result {
        guard let patch = arguments?["patch"]?.stringValue else { return CallTool.Result(content: [.text("Missing patch")], isError: true) }
        let trackerRef = progress
        let progressCallback: ToolProgressCallback? = if trackerRef == nil {
            nil
        } else {
            { processed, total, message in
                guard let tracker = trackerRef else { return }
                await tracker.updateProgress(itemsProcessed: processed, totalItems: total, currentItem: message)
            }
        }
        let tool = ApplyPatchTool(progressCallback: progressCallback)
        var params: [String: Any] = ["patch": patch]
        if let targetFiles = arguments?["target_files"]?.arrayValue?.compactMap({ $0.stringValue }),
           !targetFiles.isEmpty {
            params["target_files"] = targetFiles
        }
        if let rollback = arguments?["rollback_on_failure"]?.boolValue {
            params["rollback_on_failure"] = rollback
        }
        let paramsData = (try? JSONSerialization.data(withJSONObject: params))
            ?? Data("{}".utf8)
        let paramsString = String(data: paramsData, encoding: .utf8) ?? "{}"
        let result = await tool.execute(
            ToolCallRequest(toolName: "apply_patch", sessionId: "mcp", parameters: paramsString),
            session: SessionContext(sessionId: "mcp", agentId: "mcp", permissions: Set(Permission.allCases))
        )
        return result.mcpResult
    }

    private func handleGitDiff(arguments: [String: Value]?, progress: ProgressTracker? = nil) async -> CallTool.Result {
        let path = arguments?["path"]?.stringValue ?? ""
        await progress?.startPhase(.analyzing, message: "Computing git diff")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 2, currentItem: "Gathering diff")
        let tool = GitDiffTool()
        let result = await tool.execute(ToolCallRequest(toolName: "git_diff", sessionId: "mcp", parameters: "{\"path\":\"\(path)\"}"), session: SessionContext(sessionId: "mcp", agentId: "mcp", permissions: Set(Permission.allCases)))
        await progress?.updateProgress(itemsProcessed: 1, totalItems: 2, currentItem: "Analyzing diff")
        await progress?.updateProgress(itemsProcessed: 2, totalItems: 2, currentItem: "Diff ready")
        return result.mcpResult
    }

    private func handleSwiftTest(arguments: [String: Value]?, progress: ProgressTracker? = nil) async -> CallTool.Result {
        let filter = arguments?["filter"]?.stringValue ?? ""
        let verbose = arguments?["verbose"]?.boolValue
        var params: [String: Any] = ["filter": filter]
        if let verbose = verbose { params["verbose"] = verbose }
        let paramsData = (try? JSONSerialization.data(withJSONObject: params))
            ?? Data("{}".utf8)
        let paramsString = String(data: paramsData, encoding: .utf8) ?? "{}"

        let tool = SwiftTestTool()
        await progress?.startPhase(.processing, message: "Running Swift tests")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 2, currentItem: "Preparing tests")
        await progress?.updateProgress(itemsProcessed: 1, totalItems: 2, currentItem: "Executing tests")
        let result = await tool.execute(
            ToolCallRequest(toolName: "swift_test", sessionId: "mcp", parameters: paramsString),
            session: SessionContext(
                sessionId: "mcp",
                agentId: "mcp",
                permissions: Set(Permission.allCases),
                allowGovernedBuild: true
            )
        )
        await progress?.updateProgress(itemsProcessed: 2, totalItems: 2, currentItem: "Tests finished")
        return result.mcpResult
    }

    private func handleTraceQuery(
        arguments: [String: Value]?,
        progress: ProgressTracker?
    ) async -> CallTool.Result {
        let tid = arguments?["taskId"]?.stringValue ?? ""
        let limit = arguments?["limit"]?.intValue ?? 10
        let offset = arguments?["offset"]?.intValue ?? 0
        let tool = TraceQueryTool()
        await progress?.startPhase(.processing, message: "Running trace query")
        await progress?.updateProgress(itemsProcessed: 0, totalItems: 2, currentItem: "Preparing query")
        let result = await tool.execute(ToolCallRequest(toolName: "trace_query", sessionId: "mcp", parameters: "{\"taskId\":\"\(tid)\",\"limit\":\(limit),\"offset\":\(offset)}"), session: SessionContext(sessionId: "mcp", agentId: "mcp", permissions: Set(Permission.allCases)))
        await progress?.updateProgress(itemsProcessed: 2, totalItems: 2, currentItem: "Trace query ready")
        return result.mcpResult
    }

    private func valueToAny(_ value: Value) -> Any? {
        switch value {
        case .null: return NSNull()
        case .bool(let b): return b
        case .int(let i): return i
        case .double(let d): return d
        case .string(let s): return s
        case .array(let a): return a.compactMap { valueToAny($0) }
        case .object(let o):
            var dict: [String: Any] = [: ]
            for (k, v) in o {
                if let val = valueToAny(v) { dict[k] = val }
            }
            return dict
        case .data: return nil
        }
    }
}

extension ToolCallResponse {
    var mcpResult: CallTool.Result {
        if let data = result, let str = String(data: data, encoding: .utf8) {
            return CallTool.Result(content: [.text(str)], isError: status == .failed)
        }
        return CallTool.Result(content: [.text(diagnosis ?? "Tool execution status: \(status.rawValue)")], isError: status == .failed)
    }
}
