// HarmoniaSurface - Public API Façade
// The ONLY module that client applications should import

import Foundation
import AnigmaCore
import HarmoniaV2Core
import HarmoniaV2Inference
import HarmoniaV2Memory
@_exported import HarmoniaV2Orchestration
import HarmoniaV2Contracts
import InferenceCore
import AnigmaFoundation
import DatabaseCore
import ContractsCore
import AnigmaPrimitives
import AnigmaEvents
import TelemetryCore

// MARK: - Public Surface

/// Unified Harmonia service providing all capabilities
public actor HarmoniaService {
    private let registry: ModuleRegistry
    private let inference: InferenceEngine
    private let memory: MemoryManager
    private let conductor: HarmoniaConductor
    private let toolGateway: HarmoniaToolGateway
    private let toolExecutionEngine: GovernedToolExecutionEngine
    private let configuredMemoryStore: (any AnigmaFoundation.MemoryStore)?
    private var fallbackMemoryManager: MemoryManager?
    private var fallbackMemoryStore: (any AnigmaFoundation.MemoryStore)?
    
    public init(memoryStore: (any AnigmaFoundation.MemoryStore)? = nil) {
        self.registry = ModuleRegistry()
        self.inference = InferenceEngine(registry: registry)
        self.memory = MemoryManager(registry: registry, store: memoryStore)
        self.configuredMemoryStore = memoryStore
        self.conductor = HarmoniaConductor(
            registry: registry,
            inference: inference,
            memory: memory,
            documentAnalysisLane: FunctionalDocumentAnalysisLane(),
            policyEvaluationLane: FunctionalPolicyEvaluationLane()
        )
        self.toolGateway = HarmoniaToolGateway()
        self.toolExecutionEngine = GovernedToolExecutionEngine(gateway: toolGateway)
    }

    @discardableResult
    public func remember(
        content: String,
        userId: String? = nil,
        source: String = "harmonia",
        metadata: [String: String] = [:]
    ) async throws -> String {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            throw MemoryStoreError.invalidArgument("Cannot store empty Harmonia memory content")
        }

        let context = ExecutionContext(sessionId: UUID().uuidString, userId: userId, timestamp: Date())
        let embeddingBackend = DeterministicEmbeddingBackend()
        let inference = InferenceEngine(embeddingBackend: embeddingBackend)
        let embedding = try await inference.embed(text: trimmedContent, context: context)
        let store = try await ensureMemoryStore()
        return try await store.store(
            content: trimmedContent,
            metadata: metadata.merging([
                "projectId": userId ?? "global",
                "tenantId": userId ?? "global",
                "sessionId": context.sessionId,
                "source": source,
                "embeddingModel": embedding.modelName
            ]) { current, _ in current },
            embedding: embedding.vector
        )
    }
    
    // MARK: - High-Level API
    
    /// Execute a query with full Harmonia pipeline
    public func query(_ text: String, userId: String? = nil) async throws -> QueryResponse {
        let context = ExecutionContext(sessionId: UUID().uuidString, userId: userId, timestamp: Date())
        let embeddingBackend = DeterministicEmbeddingBackend()
        let inference = InferenceEngine(embeddingBackend: embeddingBackend)
        let embedding = try await inference.embed(text: text, context: context)
        let reasoning = try await inference.reasonStructured(
            input: StructuredReasoningInput(
                query: text,
                context: [
                    "route": "HarmoniaRuntime.query",
                    "userId": userId ?? "global"
                ],
                requiredConstraints: [
                    "query_not_empty",
                    "governed_runtime_route"
                ]
            ),
            context: context
        )
        let memoryManager = try await ensureMemoryManager()
        let memoryHits = try await memoryManager.searchSimilar(
            to: embedding.vector,
            embeddingModel: embedding.modelName,
            projectId: userId ?? "global",
            limit: 5,
            threshold: -1.0,
            scanLimit: 50
        )

        let provenance = memoryHits.map { hit in
            QueryProvenance(
                memoryId: hit.item.id,
                source: hit.item.metadata["source"] ?? "memory",
                projectId: hit.item.metadata["projectId"] ?? userId,
                sessionId: hit.item.metadata["sessionId"],
                similarity: hit.similarity,
                rank: hit.rank
            )
        }

        let response = QueryResponse(
            answer: makeAnswer(query: text, provenance: provenance, reasoning: reasoning),
            sources: provenance.map { $0.source },
            confidence: reasoning.confidence,
            provenance: provenance
        )
        let trace = agentTraceID(
            action: "query.execution",
            actor: userId ?? "system",
            policyContext: "harmonia.surface.query",
            evidenceReference: response.provenance.first?.memoryId
        )
        await publishAgentEvidence(
            action: "query.execution",
            outcome: "allowed",
            traceID: trace.traceID,
            spanID: trace.spanID,
            runID: context.sessionId,
            sessionID: context.sessionId,
            toolID: "query",
            payloadArtifactReferences: response.provenance.map {
                AgentEvidenceArtifactReference(
                    artifactID: $0.memoryId,
                    role: "retrieved_provenance",
                    metadata: [
                        "source": $0.source,
                        "rank": "\($0.rank)",
                        "similarity": "\($0.similarity)"
                    ]
                )
            },
            metadata: [
                "source_count": "\(response.sources.count)",
                "confidence": "\(response.confidence)",
                "inference_tier": reasoning.dominantTier.rawValue,
                "symbolic_satisfied_count": "\(reasoning.symbolicResult?.satisfiedConstraints.count ?? 0)",
                "symbolic_violation_count": "\(reasoning.symbolicResult?.violatedConstraints.count ?? 0)"
            ]
        )
        return response
    }

    private func makeAnswer(
        query: String,
        provenance: [QueryProvenance],
        reasoning: HarmoniaV2Core.TwoTierResult
    ) -> String {
        let tier = reasoning.dominantTier.rawValue
        let reasoningSummary: String
        if let symbolic = reasoning.symbolicResult, symbolic.isValid {
            reasoningSummary = "Symbolic inference satisfied \(symbolic.satisfiedConstraints.count) constraint(s)"
        } else if let neural = reasoning.neuralResult {
            reasoningSummary = "Fallback inference used \(neural.modelUsed ?? "unconfigured-model")"
        } else {
            reasoningSummary = "Inference completed"
        }

        guard let topHit = provenance.first else {
            return "\(reasoningSummary) for '\(query)' via \(tier) tier."
        }
        return "\(reasoningSummary) for '\(query)' via \(tier) tier. Matched \(provenance.count) memory record(s). Top source: \(topHit.source)."
    }

    private func ensureMemoryManager() async throws -> MemoryManager {
        if await memory.isConfigured {
            return memory
        }

        if let fallbackMemoryManager {
            return fallbackMemoryManager
        }

        let store = try await ensureMemoryStore()
        let manager = MemoryManager(registry: registry, store: store)
        fallbackMemoryManager = manager
        return manager
    }

    private func ensureMemoryStore() async throws -> any AnigmaFoundation.MemoryStore {
        if let configuredMemoryStore {
            return configuredMemoryStore
        }
        if let fallbackMemoryStore {
            return fallbackMemoryStore
        }
        let store = try await HarmoniaFileMemoryStore.defaultStore()
        fallbackMemoryStore = store
        return store
    }

    private static func defaultMemoryDatabasePath() -> String {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("harmonia-service")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("harmonia-memory.db").path
    }
    
    /// Execute the canonical document-analysis route.
    public func executeDocumentAnalysis(
        objective: String,
        userId: String? = nil,
        policyContext: String? = nil
    ) async throws -> HarmoniaConductorLaneResult {
        let result = try await conductor.executeDocumentAnalysis(
            objective: objective,
            userId: userId,
            policyContext: policyContext
        )
        let trace = agentTraceID(
            action: "document.analysis",
            actor: userId ?? "system",
            policyContext: policyContext ?? "harmonia.surface.document-analysis",
            evidenceReference: result.runIdentity.runID
        )
        await publishAgentEvidence(
            action: "document.analysis",
            outcome: result.disposition == .failed ? "failed" : "allowed",
            traceID: trace.traceID,
            spanID: trace.spanID,
            parentSpanID: result.runIdentity.runID,
            runID: result.runIdentity.runID,
            sessionID: result.runIdentity.sessionID,
            receiptID: result.runIdentity.runID,
            metadata: [
                "lane_name": result.laneName,
                "policy_context": policyContext ?? "harmonia.surface.document-analysis",
                "reason_code": result.reasonCode.rawValue,
                "disposition": result.disposition.rawValue
            ]
        )
        return result
    }

    /// Execute the canonical policy-evaluation route.
    public func executePolicyEvaluation(
        principal: String,
        resource: String,
        action: String,
        policyContext: String? = nil,
        attributes: [String: String] = [:]
    ) async throws -> HarmoniaConductorLaneResult {
        let result = try await conductor.executePolicyEvaluation(
            principal: principal,
            resource: resource,
            action: action,
            policyContext: policyContext,
            attributes: attributes
        )
        let trace = agentTraceID(
            action: "policy.evaluation",
            actor: principal,
            policyContext: policyContext ?? "harmonia.surface.policy",
            evidenceReference: result.runIdentity.runID
        )
        await publishAgentEvidence(
            action: "policy.evaluation",
            outcome: result.disposition == .failed ? "failed" : "allowed",
            traceID: trace.traceID,
            spanID: trace.spanID,
            parentSpanID: result.runIdentity.runID,
            runID: result.runIdentity.runID,
            sessionID: result.runIdentity.sessionID,
            receiptID: result.runIdentity.runID,
            metadata: [
                "principal": principal,
                "resource": resource,
                "action": action,
                "policy_context": policyContext ?? "harmonia.surface.policy",
                "reason_code": result.reasonCode.rawValue,
                "disposition": result.disposition.rawValue
            ]
        )
        return result
    }

    /// List the active conductor lanes.
    public func listLanes() async -> [String] {
        await conductor.listLanes()
    }

    /// Execute a governed tool dispatch through the conductor.
    public func executeTool(
        name: String,
        arguments: [String: Any],
        userId: String? = nil,
        policyContext: String? = nil
    ) async throws -> HarmoniaToolResult {
        let context = ExecutionContext(sessionId: UUID().uuidString, userId: userId, timestamp: Date())
        let result = try await toolExecutionEngine.execute(
            name: name,
            arguments: arguments,
            context: context,
            policyContext: policyContext
        )
        let trace = agentTraceID(
            action: "tool.execution",
            actor: userId ?? "system",
            policyContext: policyContext ?? "harmonia.surface.tool",
            evidenceReference: result.toolName
        )
        await publishAgentEvidence(
            action: "tool.execution",
            outcome: result.success ? "allowed" : "denied",
            traceID: trace.traceID,
            spanID: trace.spanID,
            runID: context.sessionId,
            sessionID: context.sessionId,
            toolID: result.toolName,
            metadata: [
                "policy_context": policyContext ?? "harmonia.surface.tool",
                "success": String(result.success),
                "error": result.error ?? "",
                "output": result.output
            ]
        )
        return result
    }

    /// Return the governed tool execution receipt journal.
    public func toolExecutionReceipts() async -> [ToolExecutionReceipt] {
        await toolExecutionEngine.receipts()
    }
    
    /// Execute speculative tree verification (Phase 4 API)
    public func verifySpeculativeTree(
        draftTokens: [String],
        verifierModelID: String
    ) async throws -> SpeculativeVerificationResult {
        return try await inference.verifySpeculativeTree(
            draftTokens: draftTokens,
            verifierModelID: verifierModelID
        )
    }

    /// Execute Phase9 agent loop
    public func executeAgent(config: AgentConfig, userId: String? = nil) async throws -> AgentExecutionResult {
        let result = try await executeDocumentAnalysis(
            objective: config.name,
            userId: userId,
            policyContext: "agent.\(config.name)"
        )
        return AgentExecutionResult(
            outcome: result.summary,
            iterations: 0,
            observations: result.nextActions
        )
    }

    private func agentTraceID(
        action: String,
        actor: String,
        policyContext: String,
        evidenceReference: String? = nil
    ) -> (traceID: String, spanID: String) {
        let traceID = TelemetryHash(
            input: "\(action)|\(actor)|\(policyContext)|\(evidenceReference ?? "-")"
        ).hex
        let spanID = TelemetryHash(
            input: "\(action)|\(policyContext)|span|\(evidenceReference ?? "-")"
        ).hex
        return (traceID, spanID)
    }

    private func publishAgentEvidence(
        action: String,
        outcome: String,
        traceID: String,
        spanID: String? = nil,
        parentSpanID: String? = nil,
        runID: String? = nil,
        sessionID: String? = nil,
        jobID: String? = nil,
        toolID: String? = nil,
        requestID: String? = nil,
        receiptID: String? = nil,
        payloadArtifactReferences: [AgentEvidenceArtifactReference] = [],
        metadata: [String: String] = [:]
    ) async {
        let event = AgentEvidenceEvent(
            source: "HarmoniaSurface",
            category: "harmonia.surface",
            action: action,
            outcome: outcome,
            traceID: traceID,
            spanID: spanID,
            parentSpanID: parentSpanID,
            runID: runID,
            sessionID: sessionID,
            jobID: jobID,
            toolID: toolID,
            requestID: requestID,
            receiptID: receiptID,
            payloadArtifactReferences: payloadArtifactReferences,
            metadata: metadata.isEmpty ? nil : metadata
        )
        _ = await sharedEventBus.publishWithLogging(event, source: event.source)
    }

}

// MARK: - Response Types

public struct QueryResponse: Sendable {
    public let answer: String
    public let sources: [String]
    public let confidence: Double
    public let provenance: [QueryProvenance]
    
    public init(answer: String, sources: [String], confidence: Double, provenance: [QueryProvenance] = []) {
        self.answer = answer
        self.sources = sources
        self.confidence = confidence
        self.provenance = provenance
    }
}

public struct QueryProvenance: Sendable {
    public let memoryId: String
    public let source: String
    public let projectId: String?
    public let sessionId: String?
    public let similarity: Float
    public let rank: Int

    public init(
        memoryId: String,
        source: String,
        projectId: String?,
        sessionId: String?,
        similarity: Float,
        rank: Int
    ) {
        self.memoryId = memoryId
        self.source = source
        self.projectId = projectId
        self.sessionId = sessionId
        self.similarity = similarity
        self.rank = rank
    }
}

public struct AgentExecutionResult: Sendable {
    public let outcome: String
    public let iterations: Int
    public let observations: [String]
    
    public init(outcome: String, iterations: Int, observations: [String]) {
        self.outcome = outcome
        self.iterations = iterations
        self.observations = observations
    }
}

// MARK: - Re-exports

// Re-export key types from modules so clients can use them
public typealias HarmoniaExecutionContext = HarmoniaV2Core.ExecutionContext
public typealias HarmoniaMemoryItem = MemoryItem
public typealias HarmoniaMemoryTier = MemoryTier
public typealias HarmoniaAgentConfig = AgentConfig
public typealias HarmoniaToolResult = HarmoniaV2Orchestration.ToolResult
public typealias HarmoniaSpeculativeConfiguration = InferenceCore.SpeculativeConfiguration
public typealias HarmoniaSpeculativeTreeVerificationResult = InferenceCore.SpeculativeVerificationResult

public actor HarmoniaToolGateway {
    private let registry = SimpleToolRegistry()
    private var isBootstrapped = false

    public init() {
        Self.seedSharedToolContracts()
    }

    public func execute(
        name: String,
        arguments: [String: Any],
        context: HarmoniaV2Core.ExecutionContext,
        policyContext: String?
    ) async throws -> HarmoniaToolResult {
        try await bootstrapIfNeeded()

        let request = ToolRequest(
            name: name,
            arguments: Self.stringArguments(arguments),
            sessionId: context.sessionId,
            projectId: context.userId
        )

        do {
            let response = try await registry.execute(request: request)
            return HarmoniaToolResult(
                toolName: name,
                output: response.output,
                success: response.success,
                error: response.error
            )
        } catch let error as SimpleToolError {
            return HarmoniaToolResult(
                toolName: name,
                output: "",
                success: false,
                error: Self.errorMessage(for: error, policyContext: policyContext)
            )
        } catch {
            return HarmoniaToolResult(
                toolName: name,
                output: "",
                success: false,
                error: "toolExecutionFailed; policyContext=\(policyContext ?? context.userId ?? "global"); error=\(error.localizedDescription)"
            )
        }
    }

    private func bootstrapIfNeeded() async throws {
        guard !isBootstrapped else { return }

        Self.seedSharedToolContracts()

        await registry.register(
            name: "read_file",
            handler: SimpleToolAdapter.adapt(name: "read_file") { request in
                await readFileTool(request: request)
            }
        )

        await registry.register(
            name: "git_diff",
            handler: SimpleToolAdapter.adapt(name: "git_diff") { request in
                await gitDiffTool(request: request)
            }
        )

        await registry.register(
            name: "context_search",
            handler: SimpleToolAdapter.adapt(name: "context_search") { request in
                await contextSearchTool(request: request)
            }
        )

        await registry.register(
            name: "swift_test",
            handler: SimpleToolAdapter.adapt(name: "swift_test") { request in
                await swiftTestTool(request: request)
            }
        )

        isBootstrapped = true
    }

    private static func seedSharedToolContracts() {
        let registry = ToolRegistry.shared
        registry.register(contract: ToolContract(
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

        registry.register(contract: ToolContract(
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

        registry.register(contract: ToolContract(
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

        registry.register(contract: ToolContract(
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
    }

    private static func stringArguments(_ arguments: [String: Any]) -> [String: String] {
        arguments.reduce(into: [:]) { result, element in
            if let value = element.value as? String {
                result[element.key] = value
            } else if let value = element.value as? CustomStringConvertible {
                result[element.key] = value.description
            } else {
                result[element.key] = String(describing: element.value)
            }
        }
    }

    private static func errorMessage(for error: SimpleToolError, policyContext: String?) -> String {
        switch error {
        case .toolNotFound(let name):
            return "toolNotFound; tool=\(name); policyContext=\(policyContext ?? "global")"
        case .executionFailed(let message):
            return "executionFailed; policyContext=\(policyContext ?? "global"); error=\(message)"
        }
    }
}

private func readFileTool(request: ToolRequest) async -> SimpleToolResult {
    guard let path = request.arguments["file_path"], !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return .failure("Missing required argument: file_path")
    }

    let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true).standardizedFileURL
    let candidateURL = URL(fileURLWithPath: path, relativeTo: repoRoot).standardizedFileURL
    guard candidateURL.path.hasPrefix(repoRoot.path) else {
        return .failure("File path must stay within the repository root")
    }

    do {
        let data = try Data(contentsOf: candidateURL)
        let text = String(data: data, encoding: .utf8) ?? data.base64EncodedString()
        return .success(text)
    } catch {
        return .failure("Failed to read file: \(error.localizedDescription)")
    }
}

private func gitDiffTool(request: ToolRequest) async -> SimpleToolResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    var arguments = ["git", "diff", "--no-ext-diff", "--"]
    if let path = request.arguments["path"], !path.isEmpty {
        arguments.append(path)
    }
    process.arguments = arguments
    process.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    do {
        try process.run()
        process.waitUntilExit()
        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""
        if process.terminationStatus == 0 {
            return .success(output.isEmpty ? "No diff output." : output)
        }
        return .failure(error.isEmpty ? "git diff failed with status \(process.terminationStatus)" : error)
    } catch {
        return .failure("Failed to run git diff: \(error.localizedDescription)")
    }
}

private func contextSearchTool(request: ToolRequest) async -> SimpleToolResult {
    guard let query = request.arguments["query"], !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return .failure("Missing required argument: query")
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["rg", "-n", query, "."]
    process.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    do {
        try process.run()
        process.waitUntilExit()
        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""
        if process.terminationStatus == 0 {
            return .success(output.isEmpty ? "No matches." : output)
        }
        if process.terminationStatus == 1, output.isEmpty {
            return .success("No matches.")
        }
        return .failure(error.isEmpty ? "context search failed with status \(process.terminationStatus)" : error)
    } catch {
        return .failure("Failed to run context search: \(error.localizedDescription)")
    }
}

private func swiftTestTool(request: ToolRequest) async -> SimpleToolResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    var arguments = ["swift", "test"]
    if let filter = request.arguments["filter"], !filter.isEmpty {
        arguments += ["--filter", filter]
    }
    if request.arguments["verbose"] == "true" {
        arguments.append("--verbose")
    }
    process.arguments = arguments
    process.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    do {
        try process.run()
        process.waitUntilExit()
        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""
        if process.terminationStatus == 0 {
            return .success(output.isEmpty ? "swift test completed successfully." : output)
        }
        return .failure(error.isEmpty ? "swift test failed with status \(process.terminationStatus)" : error)
    } catch {
        return .failure("Failed to run swift test: \(error.localizedDescription)")
    }
}

private actor HarmoniaFileMemoryStore: AnigmaFoundation.MemoryStore {
    private struct StoredPayload: Codable {
        var records: [AnigmaFoundation.StoredMemoryRecord]
    }

    private let fileURL: URL
    private var records: [AnigmaFoundation.StoredMemoryRecord]

    init(fileURL: URL) async throws {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let payload = try? JSONDecoder().decode(StoredPayload.self, from: data) {
            self.records = payload.records
        } else {
            self.records = []
        }
    }

    static func defaultStore() async throws -> HarmoniaFileMemoryStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("harmonia-service", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try await HarmoniaFileMemoryStore(
            fileURL: directory.appendingPathComponent("harmonia-memory.json")
        )
    }

    func store(content: String, metadata: [String: String], embedding: [Float]?) async throws -> String {
        let id = metadata["id"] ?? UUID().uuidString
        records.removeAll { $0.id == id }
        records.append(
            AnigmaFoundation.StoredMemoryRecord(
                id: id,
                content: content,
                metadata: metadata,
                embedding: embedding,
                embeddingModel: metadata["embeddingModel"],
                createdAt: Date()
            )
        )
        try persist()
        return id
    }

    func retrieve(sessionId: String?, tenantId: String?, limit: Int) async throws -> [AnigmaFoundation.StoredMemoryRecord] {
        Array(records.filter { record in
            if let sessionId, record.metadata["sessionId"] != sessionId {
                return false
            }
            if let tenantId, record.metadata["tenantId"] != tenantId {
                return false
            }
            return true
        }
        .sorted { $0.createdAt > $1.createdAt }
        .prefix(limit))
    }

    func searchSimilar(
        embedding: [Float],
        embeddingModel: String?,
        projectId: String,
        limit: Int,
        threshold: Float?,
        scanLimit: Int?
    ) async throws -> [AnigmaFoundation.SimilarMemoryResult] {
        let candidates = records.prefix(scanLimit ?? records.count).filter { record in
            record.metadata["projectId"] == projectId || record.metadata["tenantId"] == projectId
        }
        let scored = try candidates.compactMap { record -> (AnigmaFoundation.StoredMemoryRecord, Float)? in
            guard let storedEmbedding = record.embedding else {
                return nil
            }
            if let embeddingModel, let storedModel = record.embeddingModel, storedModel != embeddingModel {
                throw MemoryStoreError.embeddingModelMismatch("Expected \(embeddingModel), got \(storedModel)")
            }
            guard storedEmbedding.count == embedding.count else {
                throw MemoryStoreError.embeddingDimensionMismatch(
                    "Expected \(embedding.count), got \(storedEmbedding.count)"
                )
            }
            let similarity = Self.cosineSimilarity(embedding, storedEmbedding)
            if let threshold, similarity < threshold {
                return nil
            }
            return (record, similarity)
        }
        .sorted {
            if abs($0.1 - $1.1) < 0.0001 {
                return $0.0.id < $1.0.id
            }
            return $0.1 > $1.1
        }

        return scored.prefix(limit).enumerated().map { index, result in
            AnigmaFoundation.SimilarMemoryResult(
                record: result.0,
                similarity: result.1,
                rank: index + 1,
                vectorRank: index + 1
            )
        }
    }

    private func persist() throws {
        let data = try JSONEncoder().encode(StoredPayload(records: records))
        try data.write(to: fileURL, options: [.atomic])
    }

    private static func cosineSimilarity(_ lhs: [Float], _ rhs: [Float]) -> Float {
        let dot = zip(lhs, rhs).map(*).reduce(0, +)
        let lhsMagnitude = sqrt(lhs.map { $0 * $0 }.reduce(0, +))
        let rhsMagnitude = sqrt(rhs.map { $0 * $0 }.reduce(0, +))
        guard lhsMagnitude > 0, rhsMagnitude > 0 else {
            return 0
        }
        return dot / (lhsMagnitude * rhsMagnitude)
    }
}
