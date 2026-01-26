//
//  ToolRouter.swift
//  HarmoniaModule
//
//  Tool router orchestrator with contract validation, loop prevention, and evidence recording.
//  Harmonia is the only subsystem allowed to touch the real world (files, databases, builds).
//

import AnigmaPrimitives
import CryptoKit
import DatabaseCore
import Foundation

/// Tool router orchestrator that coordinates tool execution with strict guarantees.
public actor ToolRouter {
    private let loopBreaker: ToolCallLoopBreaker
    private let policyGate: PolicyGate
    private let evidenceRecorder: any LoopEvidenceRecorder
    private let toolRegistry: ToolRegistry
    private let modernToolRegistry: ModernToolRegistry
    private let repoRoot: URL
    private var middlewares: [any ToolMiddleware] = []

    /// Initialize the tool router with all required components
    public init(
        loopBreaker: ToolCallLoopBreaker,
        policyGate: PolicyGate,
        evidenceRecorder: any LoopEvidenceRecorder,
        toolRegistry: ToolRegistry = .shared,
        modernToolRegistry: ModernToolRegistry = .shared,
        repoRoot: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
        middlewares: [any ToolMiddleware] = []
    ) {
        self.loopBreaker = loopBreaker
        self.policyGate = policyGate
        self.evidenceRecorder = evidenceRecorder
        self.toolRegistry = toolRegistry
        self.modernToolRegistry = modernToolRegistry
        self.repoRoot = repoRoot
        self.middlewares = middlewares
    }

    /// Adds a middleware to the pipeline.
    public func addMiddleware(_ middleware: any ToolMiddleware) {
        middlewares.append(middleware)
    }

    /// Execute a tool with full contract enforcement and evidence recording.
    public func executeToolCall(
        request: ToolCallRequest,
        session: SessionContext
    ) async -> ToolCallResponse {
        let startTime = Date()
        let toolCallId = UUID().uuidString
        let inputHash = SHA256.hash(data: Data(request.fingerprint.utf8)).compactMap {
            String(format: "%02x", $0)
        }.joined()

        let context = HarmoniaToolContext(
            sessionId: request.sessionId,
            agentName: session.agentId,
            metadataHandler: { _ in /* TODO: Hook into event bus */ },
            permissionHandler: { _, _ in /* TODO: Hook into interactive CLI */ }
        )

        // 1. Create primary tool_calls record (Status: started)
        _ = try? await (evidenceRecorder as? DatabaseLoopEvidenceRecorder)?.databaseActor
            .executeAsync(
                """
                INSERT INTO tool_calls (
                    id, session_id, tool_name, started_at, status, input_hash,
                    parameters, file_path
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                parameters: [
                    .text(toolCallId),
                    .text(request.sessionId),
                    .text(request.toolName),
                    .int(Int(startTime.timeIntervalSince1970)),
                    .text("started"),
                    .text(inputHash),
                    .text(request.parameters),
                    .text(request.filePath ?? "")
                ]
            )

        // 2. Validate contract exists
        guard let contract = toolRegistry.contract(for: request.toolName) else {
            let diagnosis = "Tool not registered: \(request.toolName)"
            await finalizeToolCall(id: toolCallId, status: .failed, diagnosis: diagnosis)
            return ToolCallResponse(status: .failed, toolName: request.toolName, evidenceId: toolCallId, diagnosis: diagnosis)
        }

        // 3. Check loop breaker & policy gate
        let loopResult = await loopBreaker.checkCall(request: request, toolCallId: toolCallId)
        if case .blocked(let reason, let recovery) = loopResult {
            let guidance = LoopRecoveryFactory.createGuidance(for: recovery, toolName: request.toolName, lastAttemptDetails: reason)
            await finalizeToolCall(id: toolCallId, status: .blocked, diagnosis: reason)
            return ToolCallResponse(status: .blocked, result: try? JSONEncoder().encode(guidance), toolName: request.toolName, evidenceId: toolCallId, nextAction: guidance.nextActionTemplate, diagnosis: reason, recoveryStrategy: recovery)
        }

        do {
            try await policyGate.validateToolCall(request, session: session)
        } catch {
            let diagnosis = "Policy validation failed: \(error)"
            await finalizeToolCall(id: toolCallId, status: .failed, diagnosis: diagnosis)
            return ToolCallResponse(status: .failed, toolName: request.toolName, evidenceId: toolCallId, diagnosis: diagnosis)
        }

        // 4. Run "Before" Middlewares
        let parametersData = Data(request.parameters.utf8)
        for middleware in middlewares {
            try? await middleware.beforeExecute(toolId: request.toolName, parameters: parametersData, context: context)
        }

        // 5. Execute the tool
        var result: ToolCallResponse
        if let modernTool = await modernToolRegistry.tool(for: request.toolName) {
            do {
                result = try await modernTool.execute(parametersData: parametersData, context: context)
            } catch {
                result = ToolCallResponse(status: .failed, toolName: request.toolName, diagnosis: "Execution failed: \(error.localizedDescription)")
            }
        } else {
            result = await executeSpecificTool(name: request.toolName, request: request, session: session, contract: contract)
        }

        // 6. Automatic Truncation & Artifact Persistence (Internal Middleware)
        if result.status == .success, let payload = result.result {
            if let truncation = try? OutputTruncator.process(output: payload, toolName: request.toolName, sessionId: request.sessionId, repoRoot: repoRoot) {
                if case .truncated(let preview, let artifactPath, _) = truncation {
                    result = ToolCallResponse(status: result.status, result: Data(preview.utf8), toolName: result.toolName, evidenceId: result.evidenceId, nextAction: result.nextAction, diagnosis: (result.diagnosis ?? "") + " (Truncated, full output: \(artifactPath))", recoveryStrategy: result.recoveryStrategy, timestampMs: result.timestampMs)
                }
            }
        }

        // 7. Run "After" Middlewares
        for middleware in middlewares {
            result = (try? await middleware.afterExecute(toolId: request.toolName, result: result, context: context)) ?? result
        }

        // 8. Finalize tool call record
        await finalizeToolCall(id: toolCallId, status: result.status, outputHash: result.result != nil ? SHA256.hash(data: Data(result.result!)).compactMap { String(format: "%02x", $0) }.joined() : nil, diagnosis: result.diagnosis)

        return result
    }

    private func finalizeToolCall(
        id: String,
        status: ToolCallStatus,
        outputHash: String? = nil,
        diagnosis: String? = nil
    ) async {
        _ = try? await (evidenceRecorder as? DatabaseLoopEvidenceRecorder)?.databaseActor
            .executeAsync(
                """
                UPDATE tool_calls SET
                    completed_at = ?,
                    status = ?,
                    output_hash = ?,
                    error_signature = ?
                WHERE id = ?
                """,
                parameters: [
                    .int(Int(Date().timeIntervalSince1970)),
                    .text(status.rawValue),
                    .text(outputHash ?? ""),
                    .text(diagnosis ?? ""),
                    .text(id)
                ]
            )
    }

    /// Execute a specific tool by name.
    /// Dispatches to registered tool implementations.
    private func executeSpecificTool(
        name: String,
        request: ToolCallRequest,
        session: SessionContext,
        contract: ToolContract
    ) async -> ToolCallResponse {
        let toolRequest = ToolRequest(
            arguments: (try? JSONSerialization.jsonObject(with: Data(request.parameters.utf8)) as? [String: String]) ?? [:]
        )
        
        switch name {
        case "read_file":
            let response = try? await ReadFileTool().handle(request: toolRequest)
            return ToolCallResponse(from: response, toolName: name)
        case "swift_build":
            let response = try? await SwiftBuildTool().handle(request: toolRequest)
            return ToolCallResponse(from: response, toolName: name)
        case "apply_patch":
            let response = try? await ApplyPatchTool().handle(request: toolRequest)
            return ToolCallResponse(from: response, toolName: name)
        case "enhanced_read_file":
            let response = try? await EnhancedReadFileTool().handle(request: toolRequest)
            return ToolCallResponse(from: response, toolName: name)
        case "swift_test":
            return await SwiftTestTool().execute(request, session: session)
        case "git_diff":
            return await GitDiffTool().execute(request, session: session)
        case "trace_query":
            return await TraceQueryTool().execute(request, session: session)
        case "context_search":
            return await ContextSearchTool().execute(request, session: session)
        case "digest_codebase":
            return ToolCallResponse(status: .failed, toolName: name, diagnosis: "EnhancedDigestCodebaseTool not yet implemented")
        case "delegate":
            return await DelegateTool().execute(request, session: session)
        default:
            return ToolCallResponse(
                status: .failed,
                toolName: name,
                diagnosis: "Unknown tool: \(name)"
            )
        }
    }

    /// Reset loop breaker history for a session
    public func resetSession(_ sessionId: String) async {
        await loopBreaker.resetSession(sessionId: sessionId)
        await policyGate.resetSessionUsage(sessionId)
    }
}

extension ToolCallResponse {
    init(from response: ToolResponse?, toolName: String) {
        if let response = response {
            self.init(
                status: response.success ? .success : .failed,
                result: response.output.data(using: .utf8),
                toolName: toolName,
                diagnosis: response.success ? nil : response.output
            )
        } else {
            self.init(
                status: .failed,
                toolName: toolName,
                diagnosis: "Tool execution returned nil response"
            )
        }
    }
}
