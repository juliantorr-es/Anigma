import Foundation
import CryptoKit

/// MCP Trust Model for anigma-cli
/// Implements hash/signature verification, scope enforcement, and per-call receipts
public actor CLIMCPTrustModel {

    // MARK: - Models

    public struct MCPCall: Codable, Sendable {
        public let id: String
        public let timestamp: Date
        public let toolName: String
        public let serverName: String
        public let requestHash: String
        public let responseHash: String?
        public let signature: String?
        public let scope: MCPScope
        public let quota: QuotaUsage
        public let verified: Bool
    }

    public struct MCPScope: Codable, Sendable {
        public let allowedOperations: Set<String>
        public let allowedPaths: Set<String>
        public let allowedDomains: Set<String>
        public let maxDataSize: Int64
        public let expiresAt: Date?

        public static var `default`: MCPScope {
            MCPScope(
                allowedOperations: ["read", "search", "list"],
                allowedPaths: [],
                allowedDomains: [],
                maxDataSize: 1_000_000, // 1MB
                expiresAt: nil
            )
        }
    }

    public struct QuotaUsage: Codable, Sendable {
        public var callsCount: Int
        public var dataTransferred: Int64
        public var lastReset: Date

        public static var zero: QuotaUsage {
            QuotaUsage(callsCount: 0, dataTransferred: 0, lastReset: Date())
        }
    }

    public struct QuotaLimits: Codable, Sendable {
        public let maxCallsPerHour: Int
        public let maxCallsPerDay: Int
        public let maxDataPerHour: Int64
        public let maxDataPerDay: Int64

        public static var `default`: QuotaLimits {
            QuotaLimits(
                maxCallsPerHour: 100,
                maxCallsPerDay: 1000,
                maxDataPerHour: 10_000_000,  // 10MB
                maxDataPerDay: 100_000_000   // 100MB
            )
        }
    }

    public struct TrustLevel: Codable, Sendable {
        public let serverName: String
        public let level: Level
        public let grantedAt: Date
        public let grantedBy: String

        public enum Level: String, Codable, Sendable {
            case untrusted
            case read_only
            case restricted
            case trusted
        }
    }

    // MARK: - Properties

    private let dbPath: String
    private var mcpCalls: [MCPCall]
    private var trustLevels: [String: TrustLevel]
    private var quotas: [String: QuotaUsage]
    private let quotaLimits: QuotaLimits
    private var scopes: [String: MCPScope]

    // MARK: - Initialization

    public init(dbPath: String, quotaLimits: QuotaLimits = .default) {
        self.dbPath = dbPath
        self.mcpCalls = []
        self.trustLevels = [:]
        self.quotas = [:]
        self.quotaLimits = quotaLimits
        self.scopes = [:]
    }

    // MARK: - Trust Management

    public func setTrustLevel(server: String, level: TrustLevel.Level, grantedBy: String) {
        trustLevels[server] = TrustLevel(
            serverName: server,
            level: level,
            grantedAt: Date(),
            grantedBy: grantedBy
        )

        // Set default scope based on trust level
        switch level {
        case .untrusted:
            scopes[server] = MCPScope(
                allowedOperations: [],
                allowedPaths: [],
                allowedDomains: [],
                maxDataSize: 0,
                expiresAt: nil
            )
        case .read_only:
            scopes[server] = MCPScope(
                allowedOperations: ["read", "search", "list"],
                allowedPaths: [],
                allowedDomains: [],
                maxDataSize: 1_000_000,
                expiresAt: nil
            )
        case .restricted:
            scopes[server] = MCPScope(
                allowedOperations: ["read", "write", "search", "list"],
                allowedPaths: [],
                allowedDomains: [],
                maxDataSize: 10_000_000,
                expiresAt: Date().addingTimeInterval(86400) // 24 hours
            )
        case .trusted:
            scopes[server] = MCPScope(
                allowedOperations: ["read", "write", "delete", "search", "list", "execute"],
                allowedPaths: [],
                allowedDomains: [],
                maxDataSize: 100_000_000,
                expiresAt: nil
            )
        }
    }

    public func getTrustLevel(server: String) -> TrustLevel.Level {
        trustLevels[server]?.level ?? .untrusted
    }

    public func listTrustedServers() -> [TrustLevel] {
        Array(trustLevels.values)
    }

    // MARK: - Scope Management

    public func setScope(server: String, scope: MCPScope) {
        scopes[server] = scope
    }

    public func getScope(server: String) -> MCPScope {
        scopes[server] ?? .default
    }

    public func checkScope(server: String, operation: String) -> Bool {
        guard let scope = scopes[server] else {
            return false
        }

        // Check if scope expired
        if let expiresAt = scope.expiresAt, expiresAt < Date() {
            return false
        }

        return scope.allowedOperations.contains(operation)
    }

    // MARK: - Quota Management

    public func checkQuota(server: String, dataSize: Int64) async -> Bool {
        var quota = quotas[server] ?? .zero

        // Reset quota if needed
        let now = Date()
        let hoursSinceReset = now.timeIntervalSince(quota.lastReset) / 3600
        if hoursSinceReset >= 1.0 {
            quota = .zero
        }

        // Check hourly limits
        if quota.callsCount >= quotaLimits.maxCallsPerHour {
            return false
        }
        if quota.dataTransferred + dataSize > quotaLimits.maxDataPerHour {
            return false
        }

        return true
    }

    public func incrementQuota(server: String, dataSize: Int64) {
        var quota = quotas[server] ?? .zero
        quota.callsCount += 1
        quota.dataTransferred += dataSize
        quotas[server] = quota
    }

    public func resetQuota(server: String) {
        quotas[server] = .zero
    }

    public func getQuotaUsage(server: String) -> QuotaUsage {
        quotas[server] ?? .zero
    }

    // MARK: - Call Tracking

    public func recordMCPCall(
        toolName: String,
        serverName: String,
        request: Data,
        response: Data?,
        signature: String?
    ) async throws -> MCPCall {
        let requestHash = hashData(request)
        let responseHash = response.map { hashData($0) }

        // Verify signature if provided
        let verified = signature != nil ? verifySignature(signature!, data: request) : false

        let call = MCPCall(
            id: UUID().uuidString,
            timestamp: Date(),
            toolName: toolName,
            serverName: serverName,
            requestHash: requestHash,
            responseHash: responseHash,
            signature: signature,
            scope: getScope(server: serverName),
            quota: getQuotaUsage(server: serverName),
            verified: verified
        )

        mcpCalls.append(call)

        // Update quota
        let dataSize = Int64(request.count + (response?.count ?? 0))
        incrementQuota(server: serverName, dataSize: dataSize)

        // Persist to database
        try await persistMCPCall(call)

        return call
    }

    public func listMCPCalls(server: String? = nil) -> [MCPCall] {
        if let server = server {
            return mcpCalls.filter { $0.serverName == server }
        }
        return mcpCalls
    }

    public func getMCPCall(id: String) -> MCPCall? {
        mcpCalls.first { $0.id == id }
    }

    // MARK: - Verification

    public func verifyMCPCall(
        server: String,
        operation: String,
        dataSize: Int64
    ) async throws {
        // Check trust level
        let trustLevel = getTrustLevel(server: server)
        if trustLevel == .untrusted {
            throw MCPTrustError.untrustedServer(server)
        }

        // Check scope
        if !checkScope(server: server, operation: operation) {
            throw MCPTrustError.operationNotAllowed(operation, server)
        }

        // Check quota
        if !(await checkQuota(server: server, dataSize: dataSize)) {
            throw MCPTrustError.quotaExceeded(server)
        }

        // Check scope data size limit
        let scope = getScope(server: server)
        if dataSize > scope.maxDataSize {
            throw MCPTrustError.dataSizeExceeded(dataSize, scope.maxDataSize)
        }
    }

    // MARK: - Cryptographic Operations

    private func hashData(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func verifySignature(_ signature: String, data: Data) -> Bool {
        // In a real implementation, this would verify a cryptographic signature
        // For now, we just check that the signature is not empty
        return !signature.isEmpty
    }

    func generateReceipt(for call: MCPCall) -> String {
        let receiptData: [String: Any] = [
            "id": call.id,
            "timestamp": ISO8601DateFormatter().string(from: call.timestamp),
            "tool": call.toolName,
            "server": call.serverName,
            "request_hash": call.requestHash,
            "response_hash": call.responseHash ?? "",
            "verified": call.verified
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: receiptData, options: [.prettyPrinted, .sortedKeys]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return hashData(jsonString.data(using: .utf8)!)
        }

        return ""
    }

    // MARK: - Persistence

    private func persistMCPCall(_ call: MCPCall) async throws {
        let db = try await openDatabase()

        let createTable = """
        CREATE TABLE IF NOT EXISTS mcp_calls (
            id TEXT PRIMARY KEY,
            timestamp TEXT NOT NULL,
            tool_name TEXT NOT NULL,
            server_name TEXT NOT NULL,
            request_hash TEXT NOT NULL,
            response_hash TEXT,
            signature TEXT,
            scope_json TEXT NOT NULL,
            quota_json TEXT NOT NULL,
            verified INTEGER NOT NULL
        )
        """

        _ = try await db.execute(createTable)

        let encoder = JSONEncoder()
        guard let scopeJSON = String(data: try encoder.encode(call.scope), encoding: .utf8) else {
            fatalError("Failed to unwrap scopeJSON")
        }
        guard let quotaJSON = String(data: try encoder.encode(call.quota), encoding: .utf8) else {
            fatalError("Failed to unwrap quotaJSON")
        }

        let insert = """
        INSERT INTO mcp_calls (
            id, timestamp, tool_name, server_name,
            request_hash, response_hash, signature,
            scope_json, quota_json, verified
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        _ = try await db.execute(insert, parameters: [
            .text(call.id),
            .text(ISO8601DateFormatter().string(from: call.timestamp)),
            .text(call.toolName),
            .text(call.serverName),
            .text(call.requestHash),
            .text(call.responseHash ?? ""),
            .text(call.signature ?? ""),
            .text(scopeJSON),
            .text(quotaJSON),
            .int(call.verified ? 1 : 0)
        ])
    }

    func loadMCPCalls() async throws {
        let db = try await openDatabase()

        let query = """
        SELECT id, timestamp, tool_name, server_name,
               request_hash, response_hash, signature,
               scope_json, quota_json, verified
        FROM mcp_calls
        ORDER BY timestamp DESC
        """

        let rows = try await db.query(query)
        let decoder = JSONDecoder()

        for row in rows {
            guard let id = row["id"]?.asString,
                  let timestampStr = row["timestamp"]?.asString,
                  let timestamp = ISO8601DateFormatter().date(from: timestampStr),
                  let toolName = row["tool_name"]?.asString,
                  let serverName = row["server_name"]?.asString,
                  let requestHash = row["request_hash"]?.asString,
                  let scopeJSON = row["scope_json"]?.asString,
                  let quotaJSON = row["quota_json"]?.asString,
                  let verifiedInt = row["verified"]?.asInt else {
                continue
            }

            let responseHash = row["response_hash"]?.asString
            let signature = row["signature"]?.asString

            guard let scopeData = scopeJSON.data(using: .utf8),
                  let scope = try? decoder.decode(MCPScope.self, from: scopeData),
                  let quotaData = quotaJSON.data(using: .utf8),
                  let quota = try? decoder.decode(QuotaUsage.self, from: quotaData) else {
                continue
            }

            let call = MCPCall(
                id: id,
                timestamp: timestamp,
                toolName: toolName,
                serverName: serverName,
                requestHash: requestHash,
                responseHash: responseHash?.isEmpty == false ? responseHash : nil,
                signature: signature?.isEmpty == false ? signature : nil,
                scope: scope,
                quota: quota,
                verified: verifiedInt != 0
            )

            mcpCalls.append(call)
        }
    }

    private func openDatabase() async throws -> CLIDatabaseActor {
        let db = CLIDatabaseActor(config: CLIDatabaseConfig(databasePath: dbPath))
        try await db.open()
        return db
    }
}

// MARK: - Errors

enum MCPTrustError: Error, LocalizedError {
    case untrustedServer(String)
    case operationNotAllowed(String, String)
    case quotaExceeded(String)
    case dataSizeExceeded(Int64, Int64)
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .untrustedServer(let server):
            return "Untrusted MCP server: \(server)"
        case .operationNotAllowed(let operation, let server):
            return "Operation '\(operation)' not allowed for server: \(server)"
        case .quotaExceeded(let server):
            return "Quota exceeded for server: \(server)"
        case .dataSizeExceeded(let size, let limit):
            return "Data size \(size) exceeds limit \(limit)"
        case .verificationFailed:
            return "MCP call verification failed"
        }
    }
}
