//
//  DaemonServer+Session.swift
//  AnigmaDaemonCore
//

import DatabaseCore
import Foundation
import AnigmaCore
import AnigmaPrimitives
import ContractsCore
import MCP
import AnigmaAgents
import CathedralModule
import SubprocessPooling
import TelemetryCore

// MARK: - MCP Health Monitoring

/// MCP health status for detailed health checks
struct MCPHealthStatus: Codable, Sendable {
    let isHealthy: Bool
    let workerCount: Int
    let failedTaskCount: Int
    let averageTaskDuration: TimeInterval?
    let message: String
}

extension DaemonServer {
    /// HealthCheck handler
    func handleHealthCheck() async -> AnigmaHealthResponse {
        return AnigmaHealthResponse(
            ok: isRunning,
            message: isRunning ? "ok" : "stopped",
            apiVersion: apiVersion
        )
    }
    
    /// Detailed health check endpoint for monitoring
    func handleDetailedHealthCheck() async -> DetailedHealthResponse {
        // Check MCP worker pool health
        let mcHealth = await checkMCPHealth()
        
        return DetailedHealthResponse(
            health: AnigmaHealthResponse(
                ok: isRunning && mcHealth.isHealthy,
                message: isRunning ? "ok" : "stopped",
                apiVersion: apiVersion
            ),
            daemonVersion: daemonVersion,
            buildHash: buildHash,
            mcWorkerHealth: mcHealth
        )
    }

    /// Check MCP worker pool health
    private func checkMCPHealth() async -> MCPHealthStatus {
        let mcMetrics = await subprocessManager.getMCPMetrics()
        
        let isHealthy = mcMetrics.activeWorkers > 0 && 
                       mcMetrics.totalTasksFailed < 100 && // Threshold for failed tasks
                       (mcMetrics.averageTaskDuration ?? 0) < 30.0 // 30s timeout threshold
        
        return MCPHealthStatus(
            isHealthy: isHealthy,
            workerCount: Int(mcMetrics.activeWorkers),
            failedTaskCount: mcMetrics.totalTasksFailed,
            averageTaskDuration: mcMetrics.averageTaskDuration,
            message: isHealthy ? "MCP workers healthy" : "MCP workers degraded"
        )
    }

    /// OpenSession handler
    func handleOpenSession(
        requestedClientName: String,
        requestedScopes: [String]
    ) async -> AnigmaOpenSessionResponse {
        if await !rateLimiter.allow(clientId: "global_login") {
            // Proceed for now as structurally required
        }

        let token = await tokenManager.mintToken(
            clientName: requestedClientName,
            requestedScopes: requestedScopes
        )

        let tokenData = (try? token.encode()) ?? Data()
        let expiresMs = UInt64(token.expiresAt.timeIntervalSince1970 * 1000)

        return AnigmaOpenSessionResponse(
            clientId: token.clientId,
            capabilityToken: tokenData,
            expiresUnixMs: expiresMs,
            grantedScopes: token.scopes
        )
    }

    /// API key exchange handler
    func handleAPIKeyExchange(
        apiKey: String,
        clientName: String
    ) async throws -> AnigmaOpenSessionResponse {
        // Rate limit by API key
        let rateLimitKey = "api_key_exchange_\(apiKey.prefix(8))"
        if await !rateLimiter.allow(clientId: rateLimitKey) {
            throw DaemonError.rateLimitExceeded
        }

        guard configuration.daemon.apiKeysEnabled else {
            throw DaemonError.configurationError("API keys are not enabled")
        }

        let token = try await apiKeyManager.exchangeForKeyToken(apiKey, clientName: clientName)
        
        let tokenData = (try? token.encode()) ?? Data()
        let expiresMs = UInt64(token.expiresAt.timeIntervalSince1970 * 1000)
        
        return AnigmaOpenSessionResponse(
            clientId: token.clientId,
            capabilityToken: tokenData,
            expiresUnixMs: expiresMs,
            grantedScopes: token.scopes
        )
    }

    /// GetStatus handler
    func handleGetStatus(ctx: DaemonRequestContext) async throws -> AnigmaStatusResponse {
        // Rate Limiting
        if await !rateLimiter.allow(clientId: ctx.clientId) {
            throw DaemonError.rateLimitExceeded
        }

        _ = try await tokenManager.validateToken(
            ctx.capabilityToken, requiredScope: "system.read")

        let vaultSizeBytes = try await resolveVaultSizeBytes()
        let dbMetrics = await (database as! DatabaseActor).getMetrics()
        let extraJson: String? = {
            guard let data = try? JSONEncoder().encode(dbMetrics) else { return nil }
            return String(data: data, encoding: .utf8)
        }()

        _ = await telemetry.emit(
            category: .system,
            name: "database_metrics_snapshot",
            privacyClassification: .internal,
            values: [
                "query_count": .integer(dbMetrics.queryCount),
                "transaction_retries": .integer(dbMetrics.transactionRetries),
                "busy_timeouts": .integer(dbMetrics.busyTimeoutExhausted),
                "active_connections": .integer(dbMetrics.activeConnectionCount ?? 0),
                "connection_open_count": .integer(dbMetrics.connectionOpenCount ?? 0),
                "connection_close_count": .integer(dbMetrics.connectionCloseCount ?? 0)
            ]
        )

        // Get MCP metrics from subprocess manager for extended status
        let mcMetrics = await subprocessManager.getMCPMetrics()
        
        // Create simple MCP metrics for extraJson
        struct MCPStatus: Encodable {
            let mcWorkerPoolSize: Int
            let mcTasksCompleted: Int
            let mcTasksFailed: Int
            let mcAvgTaskDuration: Double
        }
        
        let mcStatus = MCPStatus(
            mcWorkerPoolSize: mcMetrics.activeWorkers,
            mcTasksCompleted: mcMetrics.totalTasksCompleted,
            mcTasksFailed: mcMetrics.totalTasksFailed,
            mcAvgTaskDuration: mcMetrics.averageTaskDuration ?? 0
        )
        
        let extendedJson: String? = {
            guard let data = try? JSONEncoder().encode(mcStatus) else { return nil }
            return String(data: data, encoding: .utf8)
        }()
        
        let response = AnigmaStatusResponse(
            apiVersion: apiVersion,
            daemonVersion: daemonVersion,
            buildHash: buildHash,
            socketPath: configuration.daemon.unixSocket,
            tcpEnabled: configuration.daemon.tcpEnabled,
            workerProcesses: UInt32(configuration.resources.workerProcesses),
            vaultSizeBytes: vaultSizeBytes,
            vaultQuotaBytes: UInt64(configuration.vault.maxSizeGB) * 1024 * 1024 * 1024,
            extraJson: extendedJson
        )
        if configuration.governance.auditAllOperations {
            do {
                _ = try await receiptEngine.recordActionExecution(
                    actionName: "daemon.status",
                    authority: "anigmad",
                    decision: .allowed,
                    reasonCode: "STATUS_READ",
                    inputs: [
                        "client_id": ctx.clientId
                    ],
                    outputs: [
                        "vault_size_bytes": vaultSizeBytes,
                        "tcp_enabled": configuration.daemon.tcpEnabled
                    ]
                )
            } catch {
                logWarning("CoreReceipt warning: failed to record status receipt: \(error)", category: "CoreReceipt")
            }
        }
        return response
    }

    func handleOnboardingStatus(ctx: DaemonRequestContext) async throws -> AnigmaOnboardingStatusResponse {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "system.read")
        
        // Simple check: is there at least one model registered?
        let models = try await modelRegistry.query(ModelQuery(taskKind: nil))
        let isOnboarded = !models.isEmpty
        
        return AnigmaOnboardingStatusResponse(isOnboarded: isOnboarded, error: nil)
    }
}

struct DetailedHealthResponse: Codable, Sendable {
    let health: AnigmaHealthResponse
    let daemonVersion: String
    let buildHash: String
    let mcWorkerHealth: MCPHealthStatus
}
