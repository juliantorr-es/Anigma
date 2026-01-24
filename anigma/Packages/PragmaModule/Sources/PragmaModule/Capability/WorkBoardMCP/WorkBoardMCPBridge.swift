//
//  WorkBoardMCPBridge.swift
//  PragmaModule
//
//  MCP bridge for work board operations.
//

import AnigmaPrimitives
import ContractsCore
import Foundation

/// MCP session binding for work board access.
public struct WorkBoardMCPSession: Sendable {
    public let sessionId: String
    public let surfaceId: SurfaceId
    public let actorId: ActorId
    public let trustTier: TrustTier
    public let securityZone: SecurityZone
    public let isRemote: Bool

    public init(
        sessionId: String,
        surfaceId: SurfaceId,
        actorId: ActorId,
        trustTier: TrustTier,
        securityZone: SecurityZone,
        isRemote: Bool = false
    ) {
        self.sessionId = sessionId
        self.surfaceId = surfaceId
        self.actorId = actorId
        self.trustTier = trustTier
        self.securityZone = securityZone
        self.isRemote = isRemote
    }
}

/// Errors for MCP bridge operations.
public enum MCPBridgeError: Error, LocalizedError, Sendable {
    case accessDenied(reason: String)
    case staleSnapshot(expected: String, actual: String)
    case invalidRequest(code: String, message: String)
    case governanceViolation(code: String, message: String)

    public var errorDescription: String? {
        switch self {
        case .accessDenied(let reason):
            return "Access denied: \(reason)"
        case .staleSnapshot(let expected, let actual):
            return "Stale snapshot: expected \(expected), got \(actual)"
        case .invalidRequest(let code, let message):
            return "Invalid request (\(code)): \(message)"
        case .governanceViolation(let code, let message):
            return "Governance violation (\(code)): \(message)"
        }
    }
}

/// MCP bridge that exposes WorkBoardProviding as MCP tools.
public actor WorkBoardMCPBridge {
    private let workBoard: WorkBoardProviding
    private let allowRemote: Bool
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Creates a new MCP bridge for work board tools.
    public init(workBoard: WorkBoardProviding, allowRemote: Bool = false) {
        self.workBoard = workBoard
        self.allowRemote = allowRemote
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.sortedKeys]
        self.decoder = JSONDecoder()
    }

    /// Handles an MCP tool call and returns a JSON payload string.
    /// Handles an MCP tool call and returns a JSON payload string.
    public func handle(
        tool: String,
        arguments: [String: String],
        session: WorkBoardMCPSession
    ) async throws -> String {
        if session.isRemote && !allowRemote {
            throw MCPBridgeError.accessDenied(reason: "Remote MCP access is disabled")
        }

        switch tool {
        case "work_board.snapshot":
            let scope = try decodeScope(from: arguments)
            let snapshot = try await workBoard.boardSnapshot(
                scope: scope, trustTier: session.trustTier)
            return try encode(snapshot)
        case "work_board.get_diff_summary":
            let attemptId = try attemptId(from: arguments)
            return try await encode(diffSummaryPayload(attemptId: attemptId, session: session))
        case "work_board.get_receipts":
            let attemptId = try attemptId(from: arguments)
            return try await encode(receiptsPayload(attemptId: attemptId, session: session))
        case "work_board.create_task":
            return try await submitIntent(
                action: .createTask,
                parameters: [
                    "projectId": .string(requiredString("projectId", arguments)),
                    "title": .string(requiredString("title", arguments)),
                    "description": optionalString("description", arguments).map(BindingValue.string)
                        ?? .null,
                    "tags": parseStringArray("tags", arguments).map {
                        .array($0.map(BindingValue.string))
                    } ?? .array([])
                ],
                arguments: arguments,
                session: session
            )
        case "work_board.start_attempt":
            return try await submitIntent(
                action: .startAttempt,
                parameters: [
                    "taskId": .string(requiredString("taskId", arguments)),
                    "executorProfileId": .string(requiredString("executorProfileId", arguments)),
                    "baseRef": optionalString("baseRef", arguments).map(BindingValue.string)
                        ?? .null,
                    "baseCommit": optionalString("baseCommit", arguments).map(BindingValue.string)
                        ?? .null,
                    "allowUnattendedExecution": .bool(
                        optionalBool("allowUnattendedExecution", arguments) ?? false)
                ],
                arguments: arguments,
                session: session
            )
        case "work_board.attach_worktree":
            return try await submitIntent(
                action: .attachWorktree,
                parameters: [
                    "attemptId": .string(requiredString("attemptId", arguments)),
                    "worktreeId": .string(requiredString("worktreeId", arguments)),
                    "baseRef": .string(requiredString("baseRef", arguments)),
                    "baseCommit": .string(requiredString("baseCommit", arguments))
                ],
                arguments: arguments,
                session: session
            )
        case "work_board.record_output":
            return try await submitIntent(
                action: .recordOutput,
                parameters: [
                    "attemptId": .string(requiredString("attemptId", arguments)),
                    "artifactKind": .string(requiredString("artifactKind", arguments)),
                    "uri": .string(requiredString("uri", arguments)),
                    "sha256": .string(requiredString("sha256", arguments)),
                    "summary": optionalString("summary", arguments).map(BindingValue.string)
                        ?? .null
                ],
                arguments: arguments,
                session: session
            )
        case "work_board.submit_review_comment":
            return try await submitIntent(
                action: .submitReviewComment,
                parameters: [
                    "attemptId": .string(requiredString("attemptId", arguments)),
                    "body": .string(requiredString("body", arguments)),
                    "filePath": optionalString("filePath", arguments).map(BindingValue.string)
                        ?? .null,
                    "line": optionalInt("line", arguments).map { .number(Double($0)) } ?? .null
                ],
                arguments: arguments,
                session: session
            )
        case "work_board.request_rerun":
            return try await submitIntent(
                action: .requestRerun,
                parameters: [
                    "attemptId": .string(requiredString("attemptId", arguments)),
                    "reason": optionalString("reason", arguments).map(BindingValue.string) ?? .null
                ],
                arguments: arguments,
                session: session
            )
        case "work_board.merge_attempt":
            return try await submitIntent(
                action: .mergeAttempt,
                parameters: [
                    "attemptId": .string(requiredString("attemptId", arguments)),
                    "mergeStrategy": .string(requiredString("mergeStrategy", arguments)),
                    "expectedHeadCommit": .string(requiredString("expectedHeadCommit", arguments))
                ],
                arguments: arguments,
                session: session
            )
        case "work_board.cancel_attempt":
            return try await submitIntent(
                action: .cancelAttempt,
                parameters: [
                    "attemptId": .string(requiredString("attemptId", arguments)),
                    "reason": optionalString("reason", arguments).map(BindingValue.string) ?? .null
                ],
                arguments: arguments,
                session: session
            )
        default:
            throw MCPBridgeError.invalidRequest(
                code: "unknown_tool", message: "Unknown tool \(tool)")
        }
    }

    // MARK: - Tool Helpers

    private func submitIntent(
        action: WorkBoardAction,
        parameters: [String: BindingValue],
        arguments: [String: String],
        session: WorkBoardMCPSession
    ) async throws -> String {
        let actorIdRaw = try requiredString("actorId", arguments)
        guard actorIdRaw == session.actorId.rawValue else {
            throw MCPBridgeError.accessDenied(reason: "Actor mismatch for session binding")
        }

        let header = ActionIntent.Header(
            surfaceId: session.surfaceId,
            actorId: ActorId(rawValue: actorIdRaw),
            capabilityToken: try requiredString("capabilityToken", arguments),
            irSnapshotId: try requiredString("irSnapshotId", arguments)
        )

        let intent = WorkBoardIntent(
            header: header,
            action: action,
            parameters: parameters
        )

        do {
            let result = try await workBoard.submitIntent(intent)
            return try encode(result)
        } catch let error as WorkBoardError {
            throw mapWorkBoardError(error)
        }
    }

    private func diffSummaryPayload(attemptId: AttemptId, session: WorkBoardMCPSession) async throws
        -> [String: String?] {
        let snapshot = try await workBoard.boardSnapshot(
            scope: WorkBoardScope(), trustTier: session.trustTier)
        guard let attempt = snapshot.attempts.first(where: { $0.id == attemptId }) else {
            throw MCPBridgeError.invalidRequest(
                code: "attempt_not_found", message: "Attempt not found")
        }
        guard let artifactId = attempt.diffSummaryArtifactId else {
            return ["summary": nil, "artifactId": nil]
        }
        let artifact = snapshot.artifacts.first { $0.id == artifactId }
        return [
            "summary": artifact?.summary,
            "artifactId": artifactId.raw.uuidString
        ]
    }

    private func receiptsPayload(attemptId: AttemptId, session: WorkBoardMCPSession) async throws
        -> [ReceiptRef] {
        let snapshot = try await workBoard.boardSnapshot(
            scope: WorkBoardScope(), trustTier: session.trustTier)
        guard let attempt = snapshot.attempts.first(where: { $0.id == attemptId }) else {
            throw MCPBridgeError.invalidRequest(
                code: "attempt_not_found", message: "Attempt not found")
        }
        return attempt.receipts
    }

    private func decodeScope(from arguments: [String: String]) throws -> WorkBoardScope {
        if let scopeJson = arguments["scope"] {
            guard let data = scopeJson.data(using: .utf8) else {
                throw MCPBridgeError.invalidRequest(
                    code: "invalid_scope", message: "Scope must be JSON")
            }
            return try decoder.decode(WorkBoardScope.self, from: data)
        }

        let projectId = arguments["projectId"].flatMap { WorkItemId(uuidString: $0) }
        let taskIds = parseStringArray("taskIds", arguments)?.compactMap {
            WorkItemId(uuidString: $0)
        }
        let includeArchived = optionalBool("includeArchived", arguments) ?? false
        return WorkBoardScope(
            projectId: projectId, taskIds: taskIds, includeArchived: includeArchived)
    }

    private func attemptId(from arguments: [String: String]) throws -> AttemptId {
        let raw = try requiredString("attemptId", arguments)
        guard let uuid = UUID(uuidString: raw) else {
            throw MCPBridgeError.invalidRequest(
                code: "invalid_attempt_id", message: "Invalid attemptId")
        }
        return AttemptId(raw: uuid)
    }

    private func encode<T: Encodable & Sendable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw MCPBridgeError.invalidRequest(
                code: "encoding_failure", message: "Failed to encode response")
        }
        return string
    }

    private func requiredString(_ key: String, _ arguments: [String: String]) throws -> String {
        guard let value = arguments[key], !value.isEmpty else {
            throw MCPBridgeError.invalidRequest(
                code: "missing_parameter", message: "Missing \(key)")
        }
        return value
    }

    private func optionalString(_ key: String, _ arguments: [String: String]) -> String? {
        arguments[key]
    }

    private func optionalInt(_ key: String, _ arguments: [String: String]) -> Int? {
        guard let value = arguments[key] else { return nil }
        return Int(value)
    }

    private func optionalBool(_ key: String, _ arguments: [String: String]) -> Bool? {
        guard let value = arguments[key] else { return nil }
        return value.lowercased() == "true"
    }

    private func parseStringArray(_ key: String, _ arguments: [String: String]) -> [String]? {
        guard let value = arguments[key], !value.isEmpty else { return nil }
        if value.hasPrefix("[") {
            guard let data = value.data(using: .utf8),
                let decoded = try? decoder.decode([String].self, from: data)
            else {
                return nil
            }
            return decoded
        }
        return value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func mapWorkBoardError(_ error: WorkBoardError) -> MCPBridgeError {
        switch error {
        case .staleSnapshot(let expected, let actual):
            return .staleSnapshot(expected: expected, actual: actual)
        case .accessDenied(let reason):
            return .accessDenied(reason: reason)
        case .governanceViolation(let code, let message):
            return .governanceViolation(code: code, message: message)
        case .invalidParameters(let message):
            return .invalidRequest(code: "invalid_parameters", message: message)
        default:
            return .invalidRequest(code: "work_board_error", message: error.localizedDescription)
        }
    }
}
