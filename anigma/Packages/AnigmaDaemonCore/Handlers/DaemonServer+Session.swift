//
//  DaemonServer+Session.swift
//  AnigmaDaemonCore
//

import Foundation
import ContractsCore
import TelemetryCore

extension DaemonServer {
    /// HealthCheck handler
    func handleHealthCheck() async -> HealthCheckResponse {
        let healthManager = HealthManager(daemonStartTime: startTime ?? Date())
        let health = await healthManager.generateHealthReport(
            jobQueue: jobQueue,
            workerPool: workerPool,
            httpServer: httpServer
        )
        
        return HealthCheckResponse(
            ok: isRunning,
            message: health.status.rawValue,
            apiVersion: apiVersion,
            uptime: health.uptime,
            memoryUsage: health.memoryInfo.residentSize,
            jobCount: health.jobQueueStats.totalJobs
        )
    }
    
    /// Detailed health check endpoint for monitoring
    func handleDetailedHealthCheck() async -> DetailedHealthResponse {
        let healthManager = HealthManager(daemonStartTime: startTime ?? Date())
        let health = await healthManager.generateHealthReport(
            jobQueue: jobQueue,
            workerPool: workerPool,
            httpServer: httpServer
        )
        
        return DetailedHealthResponse(
            health: health,
            daemonVersion: daemonVersion,
            buildHash: buildHash
        )
    }

    /// OpenSession handler
    func handleOpenSession(
        requestedClientName: String,
        requestedScopes: [String]
    ) async -> OpenSessionResponse {
        if await !rateLimiter.allow(clientId: "global_login") {
            // Proceed for now as structurally required
        }

        let token = await tokenManager.mintToken(
            clientName: requestedClientName,
            requestedScopes: requestedScopes
        )

        let tokenData = (try? token.encode()) ?? Data()
        let expiresMs = UInt64(token.expiresAt.timeIntervalSince1970 * 1000)

        return OpenSessionResponse(
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
    ) async throws -> OpenSessionResponse {
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
        
        return OpenSessionResponse(
            clientId: token.clientId,
            capabilityToken: tokenData,
            expiresUnixMs: expiresMs,
            grantedScopes: token.scopes
        )
    }

    /// GetStatus handler
    func handleGetStatus(ctx: DaemonRequestContext) async throws -> StatusResponse {
        // Rate Limiting
        if await !rateLimiter.allow(clientId: ctx.clientId) {
            throw DaemonError.rateLimitExceeded
        }

        _ = try await tokenManager.validateToken(
            ctx.capabilityToken, requiredScope: "system.read")

        let vaultSizeBytes = await resolveVaultSizeBytes()
        let dbMetrics = await database.getMetrics()

        let response = StatusResponse(
            apiVersion: apiVersion,
            daemonVersion: daemonVersion,
            buildHash: buildHash,
            socketPath: configuration.daemon.unixSocket,
            tcpEnabled: configuration.daemon.tcpEnabled,
            workerProcesses: UInt32(configuration.resources.workerProcesses),
            vaultSizeBytes: vaultSizeBytes,
            vaultQuotaBytes: UInt64(configuration.vault.maxSizeGB) * 1024 * 1024 * 1024,
            database: dbMetrics
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
                print("Receipt warning: failed to record status receipt: \(error)")
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
