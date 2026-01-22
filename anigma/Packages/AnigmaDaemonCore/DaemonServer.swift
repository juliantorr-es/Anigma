//
//  DaemonServer.swift
//  AnigmaDaemonCore
//
//  Main daemon server coordinator (simplified for MVP).
//

import AnigmaCore
import DatabaseCore
import ExecutionCore
import Foundation
import GovernanceCore
import StorageCore
import TelemetryCore

/// Main daemon server actor (coordinator)
public actor DaemonServer {
    private let configuration: DaemonConfiguration
    private let telemetry: TelemetryClient
    private let tokenManager: CapabilityTokenManager
    private let apiKeyManager: APIKeyManager
    private let jobQueue: JobQueue
    private let httpServer: HTTPServerManager
    private let vault: VaultAuthority
    private let jobRegistry: JobRegistry
    private let workerPool: WorkerPool
    private let receiptEngine: ReceiptEngine
    private let jobEvents: JobEventHub
    private let database: DatabaseActor
    private let rateLimiter: RateLimiter // Pass 8
    private let signalManager: SignalManager
    private let healthManager: HealthManager
    private let resourceMonitor: ResourceMonitor

    private var isRunning: Bool = false
    private var startTime: Date?
    private var jobProcessingTask: Task<Void, Never>?
    private var vaultSizeCache: (bytes: UInt64, updatedAt: Date)?
    private let vaultSizeCacheTTL: TimeInterval = 10

    // API version for contract compliance
    private let apiVersion = "1.0.0"
    private let daemonVersion = "0.1.0"
    private let buildHash = "dev"

    public init(configuration: DaemonConfiguration) async throws {
        self.configuration = configuration

        // Initialize Vault URL (Required for Logging setup)
        let vaultURL = URL(
            fileURLWithPath: (configuration.vault.rootPath as NSString).expandingTildeInPath)

        // Ensure vault directory exists
        try? FileManager.default.createDirectory(
            at: vaultURL, withIntermediateDirectories: true, attributes: nil)

        // Initialize telemetry with Rotating File Logging (Pass 3)
        let logDir = vaultURL.appendingPathComponent("logs")
        var sinks: [TelemetrySink] = [ConsoleTelemetrySink()]

        do {
             let fileSink = try RotatingFileTelemetrySink(logDirectory: logDir)
             sinks.append(fileSink)
        } catch {
             print("Warning: Failed to initialize file logging: \(error)")
        }
        self.telemetry = TelemetryClient(sinks: sinks)

        // Initialize token manager
        self.tokenManager = CapabilityTokenManager()

        // Initialize Database
        let dbPath = vaultURL.appendingPathComponent("vault.db").path
        self.database = DatabaseActor(dbPath: dbPath)
        try await self.database.open()

        // Initialize API key manager (if enabled)
        self.apiKeyManager = APIKeyManager(database: self.database, tokenManager: self.tokenManager)
        if configuration.daemon.apiKeysEnabled {
            try await self.apiKeyManager.initializeStorage()
        }

        // Initialize Job Persistence (Pass 4 Wiring)
        let persistence = SQLiteJobPersistence(database: self.database)
        try await persistence.initializeSchema()

        // Initialize job queue with persistence
        self.jobQueue = JobQueue(
            maxConcurrentJobs: configuration.resources.maxConcurrentJobs,
            persistence: persistence
        )

        // Initialize HTTP server
        self.httpServer = HTTPServerManager()

        // Initialize Job Registry
        self.jobRegistry = JobRegistry()
        await self.jobRegistry.register(worker: ArtifactCopyWorker())
        await self.jobRegistry.register(worker: MemoryLeakWorker())
        await self.jobRegistry.register(worker: CPUBurnWorker())
        await self.jobRegistry.register(worker: PDFWorker())
        await self.jobRegistry.register(worker: LaTeXWorker())
        await self.jobRegistry.register(worker: NoOpWorker())

        // Initialize Worker Pool with Resource Limits (Pass 6)
        self.workerPool = WorkerPool(
            maxConcurrentJobs: configuration.resources.maxConcurrentJobs,
            resourceLimits: (configuration.resources.maxMemoryMB, 60)
        )

        self.vault = try await VaultAuthority(
            rootURL: vaultURL,
            database: self.database,
            keyProvider: DefaultVaultKeyProvider.make()
        )

        let receiptStore: ExecutionCore.ReceiptStore
        switch configuration.governance.receiptStoreMode {
        case .vault:
            receiptStore = VaultReceiptStore(vault: vault)
        case .inMemory:
            receiptStore = InMemoryReceiptStore()
        }

        // Initialize Receipt Engine
        self.receiptEngine = ReceiptEngine(
            signer: DefaultReceiptSigner(),
            store: receiptStore,
            telemetry: self.telemetry
        )
        self.jobEvents = JobEventHub()

        // Initialize Rate Limiter (Pass 8)
        self.rateLimiter = RateLimiter(capacity: 100, refillRate: 10.0)
        
        // Initialize Signal Manager for graceful shutdown
        self.signalManager = SignalManager()
        await signalManager.setupDefaultHandlers(
            shutdownHandler: { [weak self] in
                await self?.handleGracefulShutdown()
            },
            reloadHandler: { [weak self] in
                await self?.handleConfigurationReload()
            }
        )
        
        // Initialize Health Manager
        self.healthManager = HealthManager(daemonStartTime: Date())
        
        // Initialize Resource Monitor
        self.resourceMonitor = ResourceMonitor(
            thresholds: ResourceThresholds(
                maxMemoryMB: configuration.resources.maxMemoryMB,
                maxCPUPercent: 80.0,
                maxDiskUsagePercent: 90.0
            )
        )
        
        // Set up resource monitoring event handlers
        await resourceMonitor.registerEventHandler { [weak self] event in
            await self?.handleResourceEvent(event)
        }
    }

    func registerWorker(_ worker: JobWorker) async {
        await jobRegistry.register(worker: worker)
    }

    /// Start the daemon
    public func start() async throws {
        guard !isRunning else {
            throw DaemonError.alreadyRunning
        }

        isRunning = true
        startTime = Date()

        // Start resource monitoring
        await resourceMonitor.startMonitoring()
        
        // Start HTTP server
        try await httpServer.start(
            configuration: configuration.daemon,
            daemon: self
        )

        // Restore pending jobs (Pass 4 Wiring)
        await jobQueue.restore()

        // Start continuous job processing loop
        jobProcessingTask = Task {
            await runJobProcessingLoop()
        }

        // Emit startup telemetry
        _ = await telemetry.emit(
            category: .system,
            name: "daemon_started",
            values: [
                "api_version": .hashedToken(TelemetryHash(input: apiVersion)),
                "tcp_enabled": .boolean(configuration.daemon.tcpEnabled),
                "restored_jobs": .boolean(true)
            ]
        )

        logInfo("anigmad started", category: "Daemon")
        logInfo("  API version: \(apiVersion)", category: "Daemon")
        logInfo("  Socket: \(configuration.daemon.unixSocket)", category: "Daemon")
        logInfo(
            "  TCP: \(configuration.daemon.tcpEnabled ? "enabled" : "disabled")", category: "Daemon"
        )
        logInfo("  Resource Limits: RAM=\(configuration.resources.maxMemoryMB)MB", category: "Daemon")
    }

    /// Stop the daemon
    public func stop() async {
        await performShutdown()
    }
    
    /// Handle graceful shutdown from signal
    private func handleGracefulShutdown() async {
        print("Initiating graceful shutdown...")
        await performShutdown()
        
        // Give the process a moment to clean up
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Exit cleanly
        exit(0)
    }
    
    /// Handle configuration reload
    private func handleConfigurationReload() async {
        print("Configuration reload requested...")
        // TODO: Implement configuration reload logic
        print("Configuration reload not yet implemented")
    }
    
    /// Perform the actual shutdown sequence
    private func performShutdown() async {
        guard isRunning else { return }

        isRunning = false

        // Stop accepting new jobs
        await jobQueue.pause()

        // Wait for existing jobs to complete or timeout
        if let jobTask = jobProcessingTask {
            jobTask.cancel()
            
            // Wait up to 30 seconds for jobs to complete
            let timeout = Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
            
            _ = await withTaskGroup(of: Void.self) { group in
                group.addTask { await jobTask }
                group.addTask { await timeout.value }
            }
        }

        // Stop HTTP server
        await httpServer.stop()
        
        // Stop worker pool
        await workerPool.stop()
        
        // Stop resource monitoring
        await resourceMonitor.stopMonitoring()

        // Clean up signal handlers
        await signalManager.cleanup()

        _ = await telemetry.emit(
            category: .system,
            name: "daemon_stopped",
            values: [
                "uptime": Date().timeIntervalSince(startTime ?? Date()),
                "jobs_processed": jobQueue.processedJobCount
            ]
        )

        logInfo("anigmad stopped gracefully", category: "Daemon")
    }
    
    /// Handle resource monitoring events
    private func handleResourceEvent(_ event: ResourceEvent) async {
        switch event {
        case .memoryWarning(let usage, let threshold):
            _ = await telemetry.emit(
                category: .system,
                name: "memory_warning",
                values: ["usage": Double(usage), "threshold": Double(threshold)]
            )
            print("⚠️  Memory usage warning: \(usage / 1024 / 1024)MB / \(threshold / 1024 / 1024)MB")
            
        case .memoryCritical(let usage, let threshold):
            _ = await telemetry.emit(
                category: .system,
                name: "memory_critical",
                values: ["usage": Double(usage), "threshold": Double(threshold)]
            )
            print("🚨 Critical memory usage: \(usage / 1024 / 1024)MB / \(threshold / 1024 / 1024)MB")
            await resourceMonitor.performCleanup()
            
        case .cpuWarning(let usage, let threshold):
            _ = await telemetry.emit(
                category: .system,
                name: "cpu_warning",
                values: ["usage": usage, "threshold": threshold]
            )
            print("⚠️  CPU usage warning: \(String(format: "%.1f", usage))% / \(String(format: "%.1f", threshold))%")
            
        case .cpuCritical(let usage, let threshold):
            _ = await telemetry.emit(
                category: .system,
                name: "cpu_critical",
                values: ["usage": usage, "threshold": threshold]
            )
            print("🚨 Critical CPU usage: \(String(format: "%.1f", usage))% / \(String(format: "%.1f", threshold))%")
            
        case .diskWarning(let usage, let threshold):
            _ = await telemetry.emit(
                category: .system,
                name: "disk_warning",
                values: ["usage": usage, "threshold": threshold]
            )
            print("⚠️  Disk usage warning: \(String(format: "%.1f", usage))% / \(String(format: "%.1f", threshold))%")
            
        case .threadWarning(let count, let threshold):
            _ = await telemetry.emit(
                category: .system,
                name: "thread_warning",
                values: ["count": count, "threshold": threshold]
            )
            print("⚠️  Thread count warning: \(count) / \(threshold)")
            
        case .resourceUsageNormal:
            _ = await telemetry.emit(
                category: .system,
                name: "resource_usage_normal",
                values: [:]
            )
            print("✅ Resource usage returned to normal levels")
        }
    }

    // MARK: - gRPC Service Handlers

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
        // Simple rate limit for login attempts per generic bucket?
        // We'll skip rate limiting OpenSession for now or use "global" key
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
        // Rate Limiting (Pass 8)
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
struct HandleIngestArtifactConfiguration: Sendable {
    let ctx: DaemonRequestContext
    let kind: ArtifactKind
    let mime: String
    let data: Data
    let plaintextSha256: String
    let chunkCount: Int
    let byteCount: Int
    let filenameHint: String?
}

func handleIngestArtifact(config: HandleIngestArtifactConfiguration) async throws -> IngestResult {
    if await !rateLimiter.allow(clientId: config.ctx.clientId) {
        throw DaemonError.rateLimitExceeded
    }
    
    _ = try await tokenManager.validateToken(config.ctx.capabilityToken, requiredScope: "vault.write")
    
    let vKind = StorageCore.VaultArtifactKind(rawValue: config.kind) ?? .original
    let ref = try await vault.ingest(data: config.data, kind: vKind, mime: config.mime)
    let receipt = try await receiptEngine.recordActionExecution(
        actionName: "vault.ingest",
        authority: "anigmad",
        decision: .allowed,
        reasonCode: "INGESTED",
        inputs: [
            "hash": ref.sha256Hex,
            "mime": ref.mime,
            "kind": ref.kind.rawValue,
            "bytes": ref.byteLen,
            "plaintext_sha256": config.plaintextSha256,
            "chunk_count": config.chunkCount,
            "byte_count": config.byteCount,
            "filename_hint": config.filenameHint ?? "none"
        ]
    )
    
    return IngestResult(
        artifact: ArtifactRef(
            hash: ref.sha256Hex,
            mediaType: ref.mime,
            sizeBytes: UInt64(ref.byteLen)
        ),
        receiptHash: receipt.receiptID
    )
}

    func handleIngestChunk(
        ctx: DaemonRequestContext,
        mime: String,
        filenameHint: String?,
        chunkIndex: Int,
        chunkBytes: Int,
        totalBytes: Int
    ) async -> String? {
        if await !rateLimiter.allow(clientId: ctx.clientId) {
            return nil
        }

        guard configuration.governance.auditAllOperations else { return nil }
        do {
            _ = try await tokenManager.validateToken(
                ctx.capabilityToken, requiredScope: "vault.write")
            let receipt = try await receiptEngine.recordActionExecution(
                actionName: "vault.ingest.chunk",
                authority: "anigmad",
                decision: .allowed,
                reasonCode: "CHUNK_RECEIVED",
                inputs: [
                    "client_id": ctx.clientId,
                    "mime": mime,
                    "filename_hint": filenameHint ?? "none"
                ],
                outputs: [
                    "chunk_index": chunkIndex,
                    "chunk_bytes": chunkBytes,
                    "total_bytes": totalBytes
                ]
            )
            return receipt.receiptID
        } catch {
            print("Receipt warning: failed to record ingest chunk receipt: \(error)")
            return nil
        }
    }

    /// Retrieve an artifact from the vault
    func handleRetrieveArtifact(
        ctx: DaemonRequestContext,
        hash: String
    ) async throws -> (data: Data, receiptHash: String?) {
        if await !rateLimiter.allow(clientId: ctx.clientId) {
            throw DaemonError.rateLimitExceeded
        }

        _ = try await tokenManager.validateToken(
            ctx.capabilityToken, requiredScope: "vault.read")
        let data = try await vault.open(hash: hash)
        var receiptHash: String?
        if configuration.governance.auditAllOperations {
            do {
                let receipt = try await receiptEngine.recordActionExecution(
                    actionName: "vault.retrieve",
                    authority: "anigmad",
                    decision: .allowed,
                    reasonCode: "RETRIEVED",
                    inputs: ["hash": hash],
                    outputs: ["bytes": data.count]
                )
                receiptHash = receipt.receiptID
            } catch {
                print("Receipt warning: failed to record retrieve receipt: \(error)")
            }
        }
        return (data, receiptHash)
    }

    /// List artifacts in the vault
    func handleListArtifacts(
        ctx: DaemonRequestContext,
        pageToken: String?,
        pageSize: Int?
    ) async throws -> (artifacts: [ArtifactRef], nextPageToken: String?) {
        if await !rateLimiter.allow(clientId: ctx.clientId) {
            throw DaemonError.rateLimitExceeded
        }

        _ = try await tokenManager.validateToken(
            ctx.capabilityToken, requiredScope: "vault.read")
        let vaultArtifacts = try await vault.listArtifacts()
        let sorted = vaultArtifacts.sorted { $0.sha256Hex < $1.sha256Hex }
        let size = max(1, min(pageSize ?? 100, 1000))
        var startIndex = 0

        if let token = pageToken, !token.isEmpty {
            guard let tokenIndex = sorted.firstIndex(where: { $0.sha256Hex == token }) else {
                throw DaemonError.invalidPageToken(token)
            }
            startIndex = tokenIndex + 1
        }

        let endIndex = min(startIndex + size, sorted.count)
        let page = sorted[startIndex..<endIndex]
        let nextToken = endIndex < sorted.count ? page.last?.sha256Hex : nil

        let artifacts = page.map { ref in
            ArtifactRef(
                hash: ref.sha256Hex,
                mediaType: ref.mime,
                sizeBytes: UInt64(ref.byteLen)
            )
        }
        if configuration.governance.auditAllOperations {
            do {
                _ = try await receiptEngine.recordActionExecution(
                    actionName: "vault.list",
                    authority: "anigmad",
                    decision: .allowed,
                    reasonCode: "LISTED",
                    inputs: [
                        "page_token": pageToken ?? "none",
                        "page_size": size
                    ],
                    outputs: [
                        "count": artifacts.count,
                        "next_page_token": nextToken ?? "none"
                    ]
                )
            } catch {
                logWarning("failed to record list receipt: \(error)", category: "Receipt")
            }
        }
        return (artifacts, nextToken)
    }

    /// SubmitJob handler (simplified)
    func handleSubmitJob(
        ctx: DaemonRequestContext,
        spec: JobSpec
    ) async throws -> SubmitJobResponse {
        if await !rateLimiter.allow(clientId: ctx.clientId) {
             return SubmitJobResponse(
                jobId: "",
                receiptHash: "",
                error: ErrorStatus(code: "RATE_LIMIT", message: "Too many requests", detailJson: nil)
             )
        }

        do {
            // Validate token
            _ = try await tokenManager.validateToken(
                ctx.capabilityToken, requiredScope: "job.submit")

            // Submit job to queue
            let jobId = await jobQueue.submit(spec: spec, clientId: ctx.clientId)

            do {
                let receipt = try await receiptEngine.recordActionExecution(
                    actionName: "job.submit",
                    authority: "anigmad",
                    decision: .allowed,
                    reasonCode: "QUEUED",
                    inputs: [
                        "job_id": jobId,
                        "kind": spec.kind,
                        "client_id": ctx.clientId
                    ],
                    outputs: [
                        "input_count": spec.inputs.count
                    ]
                )
                await emitJobEvent(
                    jobId: jobId,
                    type: .state,
                    message: JobState.queued.rawValue,
                    progressPermille: 0,
                    receiptHash: receipt.receiptID
                )

                return SubmitJobResponse(
                    jobId: jobId,
                    receiptHash: receipt.receiptID,
                    error: nil
                )
            } catch {
                await emitJobEvent(
                    jobId: jobId,
                    type: .state,
                    message: JobState.queued.rawValue,
                    progressPermille: 0,
                    receiptHash: nil
                )
                return SubmitJobResponse(
                    jobId: jobId,
                    receiptHash: "",
                    error: ErrorStatus(
                        code: "RECEIPT_FAILED",
                        message: "Job queued but receipt failed: \(error.localizedDescription)",
                        detailJson: nil
                    )
                )
            }
        } catch {
            return SubmitJobResponse(
                jobId: "",
                receiptHash: "",
                error: ErrorStatus(
                    code: "SUBMIT_FAILED", message: error.localizedDescription, detailJson: nil)
            )
        }
    }

    /// GetJobStatus handler
    func handleGetJobStatus(
        ctx: DaemonRequestContext,
        jobId: String
    ) async throws -> GetJobStatusResponse {
        if await !rateLimiter.allow(clientId: ctx.clientId) {
            return GetJobStatusResponse(
                jobId: jobId, state: "ERROR", progressPermille: 0, outputs: [], finalReceiptHash: nil,
                error: ErrorStatus(code: "RATE_LIMIT", message: "Too many requests", detailJson: nil))
        }

        // Validate token
        _ = try await tokenManager.validateToken(
            ctx.capabilityToken, requiredScope: "job.read")

        // Get job status
        guard let job = await jobQueue.getStatus(jobId: jobId) else {
            return GetJobStatusResponse(
                jobId: jobId,
                state: "NOT_FOUND",
                progressPermille: 0,
                outputs: [],
                finalReceiptHash: nil,
                error: ErrorStatus(
                    code: "JOB_NOT_FOUND",
                    message: "Job not found: \(jobId)",
                    detailJson: nil
                )
            )
        }

        return GetJobStatusResponse(
            jobId: job.id,
            state: job.state.rawValue,
            progressPermille: job.state == .succeeded ? 1000 : 0,
            outputs: job.outputs,
            finalReceiptHash: job.receiptHash,
            error: job.errorMessage.map {
                ErrorStatus(code: "JOB_FAILED", message: $0, detailJson: nil)
            }
        )
    }

    /// Cancel a running or queued job
    func handleCancelJob(
        ctx: DaemonRequestContext,
        jobId: String
    ) async throws -> CancelJobResponse {
        if await !rateLimiter.allow(clientId: ctx.clientId) {
            return CancelJobResponse(canceled: false, receiptHash: nil, error: ErrorStatus(code: "RATE_LIMIT", message: "Too many requests", detailJson: nil))
        }

        _ = try await tokenManager.validateToken(
            ctx.capabilityToken, requiredScope: "job.cancel")

        await jobQueue.cancel(jobId: jobId)
        await workerPool.terminateWorker(for: jobId)

        _ = await telemetry.emit(
            category: .system,
            name: "job_canceled",
            values: ["job_id": .hashedToken(TelemetryHash(input: jobId))]
        )

        do {
            let receipt = try await receiptEngine.recordActionExecution(
                actionName: "job.cancel",
                authority: "anigmad",
                decision: .allowed,
                reasonCode: "CANCELED",
                inputs: [
                    "job_id": jobId,
                    "client_id": ctx.clientId
                ]
            )

            await emitJobEvent(
                jobId: jobId,
                type: .state,
                message: JobState.canceled.rawValue,
                progressPermille: 0,
                receiptHash: receipt.receiptID
            )

            return CancelJobResponse(
                canceled: true,
                receiptHash: receipt.receiptID,
                error: nil
            )
        } catch {
            await emitJobEvent(
                jobId: jobId,
                type: .state,
                message: JobState.canceled.rawValue,
                progressPermille: 0,
                receiptHash: nil,
                error: ErrorStatus(
                    code: "RECEIPT_FAILED",
                    message: "Job canceled but receipt failed: \(error.localizedDescription)",
                    detailJson: nil
                )
            )
            return CancelJobResponse(
                canceled: true,
                receiptHash: nil,
                error: ErrorStatus(
                    code: "RECEIPT_FAILED",
                    message: "Job canceled but receipt failed: \(error.localizedDescription)",
                    detailJson: nil
                )
            )
        }
    }

    // MARK: - Receipt Verification

    func handleGetReceipt(
        ctx: DaemonRequestContext,
        receiptHash: String
    ) async -> (receipt: ReceiptWire?, error: ErrorStatus?) {
        if await !rateLimiter.allow(clientId: ctx.clientId) {
             return (nil, ErrorStatus(code: "RATE_LIMIT", message: "Too many requests", detailJson: nil))
        }

        do {
            _ = try await tokenManager.validateToken(
                ctx.capabilityToken, requiredScope: "audit.read")
        } catch {
            return (
                nil,
                ErrorStatus(
                    code: "AUTH_DENIED",
                    message: error.localizedDescription,
                    detailJson: nil
                )
            )
        }

        guard isValidReceiptHash(receiptHash) else {
            return (
                nil,
                ErrorStatus(
                    code: "INVALID_RECEIPT_HASH",
                    message: "Invalid receipt hash: \(receiptHash)",
                    detailJson: nil
                )
            )
        }

        guard let receipt = try? await receiptEngine.retrieveReceipt(receiptID: receiptHash) else {
            return (
                nil,
                ErrorStatus(
                    code: "RECEIPT_NOT_FOUND",
                    message: "Receipt not found: \(receiptHash)",
                    detailJson: nil
                )
            )
        }
        return (receipt, nil)
    }

    func handleVerifyChain(
        ctx: DaemonRequestContext,
        headReceiptHash: String
    ) async -> (ok: Bool, message: String, error: ErrorStatus?) {
        if await !rateLimiter.allow(clientId: ctx.clientId) {
            return (false, "Rate limit exceeded", ErrorStatus(code: "RATE_LIMIT", message: "Too many requests", detailJson: nil))
        }

        do {
            _ = try await tokenManager.validateToken(
                ctx.capabilityToken, requiredScope: "audit.read")
        } catch {
            return (
                false,
                "Audit access denied",
                ErrorStatus(
                    code: "AUTH_DENIED",
                    message: error.localizedDescription,
                    detailJson: nil
                )
            )
        }

        guard isValidReceiptHash(headReceiptHash) else {
            return (
                false,
                "Invalid receipt hash",
                ErrorStatus(
                    code: "INVALID_RECEIPT_HASH",
                    message: "Invalid receipt hash: \(headReceiptHash)",
                    detailJson: nil
                )
            )
        }

        var chain: [ReceiptWire] = []
        var currentHash: String? = headReceiptHash
        let maxDepth = 1000
        var depth = 0

        while let hash = currentHash, depth < maxDepth {
            guard let receipt = try? await receiptEngine.retrieveReceipt(receiptID: hash) else {
                return (
                    false,
                    "Chain broken: missing receipt \(hash)",
                    ErrorStatus(
                        code: "RECEIPT_NOT_FOUND",
                        message: "Receipt not found: \(hash)",
                        detailJson: nil
                    )
                )
            }

            chain.append(receipt)
            currentHash = receipt.previousReceiptHash
            depth += 1
        }

        if depth >= maxDepth {
            return (
                false,
                "Chain too long or cycle detected",
                ErrorStatus(code: "CHAIN_TOO_LONG", message: "Chain too long", detailJson: nil)
            )
        }

        do {
            let valid = try await receiptEngine.verifyChain(receipts: chain)
            if valid {
                return (true, "Chain verified", nil)
            }
            return (false, "Verification failed", ErrorStatus(code: "CHAIN_VERIFICATION_FAILED", message: "Verification failed", detailJson: nil))
        } catch {
            return (false, "Verification error: \(error.localizedDescription)", ErrorStatus(code: "CHAIN_VERIFICATION_FAILED", message: error.localizedDescription, detailJson: nil))
        }
    }

    func handleTelemetryEvent(
        ctx: DaemonRequestContext,
        event: AnigmaTelemetryEvent
    ) async -> (accepted: Bool, error: String?, receiptHash: String?) {
        if await !rateLimiter.allow(clientId: ctx.clientId) {
            return (false, "Rate limit exceeded", nil)
        }

        do {
            _ = try await tokenManager.validateToken(
                ctx.capabilityToken, requiredScope: "telemetry.write")
        } catch {
            let receiptHash = await recordTelemetryReceipt(
                ctx: ctx,
                event: event,
                decision: .denied,
                reasonCode: "AUTH_DENIED",
                error: error.localizedDescription
            )
            return (false, error.localizedDescription, receiptHash)
        }

        guard configuration.telemetry.enabled else {
            return (false, "Telemetry disabled", nil)
        }

        do {
            let decoded = try decodeTelemetryPayload(event.payloadJson)
            var values = decoded.values
            values["stream_type"] = .hashedToken(TelemetryHash(input: event.type))
            values["streamed_at_ms"] = .integer64(Int64(event.atUnixMs))
            values["client_id"] = .hashedToken(TelemetryHash(input: ctx.clientId))

            let result = await telemetry.emit(
                category: decoded.category,
                name: decoded.name,
                privacyClassification: decoded.privacyClassification,
                values: values
            )
            switch result {
            case .success:
                let receiptHash = await recordTelemetryReceipt(
                    ctx: ctx,
                    event: event,
                    decision: .allowed,
                    reasonCode: "TELEMETRY_ACCEPTED",
                    error: nil
                )
                return (true, nil, receiptHash)
            case .failure(let error):
                return (false, error.localizedDescription, nil)
            }
        } catch {
            return (false, error.localizedDescription, nil)
        }
    }

    func handleTelemetryStreamSummary(
        ctx: DaemonRequestContext,
        accepted: Int,
        rejected: Int,
        lastReceiptHash: String?
    ) async {
        guard configuration.governance.auditAllOperations else { return }
        do {
            _ = try await receiptEngine.recordActionExecution(
                actionName: "telemetry.stream",
                authority: "anigmad",
                decision: rejected == 0 ? .allowed : .error,
                reasonCode: rejected == 0 ? "TELEMETRY_ACCEPTED" : "TELEMETRY_REJECTED",
                inputs: ["client_id": ctx.clientId],
                outputs: [
                    "accepted": accepted,
                    "rejected": rejected,
                    "last_receipt_hash": lastReceiptHash ?? "none"
                ]
            )
        } catch {
            print("Receipt warning: failed to record telemetry stream receipt: \(error)")
        }
    }

    // MARK: - Job Processing

    private func runJobProcessingLoop() async {
        logInfo("Starting continuous job processing loop", category: "JobProcessing")
        while !Task.isCancelled {
            if let job = await jobQueue.dequeue() {
                await executeJob(job)
            } else {
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    // MARK: - Missing Handlers

    func handleListJobs(
        ctx: DaemonRequestContext,
        pageToken: String?,
        pageSize: Int?,
        filterByState: [String]
    ) async throws -> (jobs: [Job], nextPageToken: String?) {
        if await !rateLimiter.allow(clientId: ctx.clientId) {
            throw DaemonError.rateLimitExceeded
        }

        _ = try await tokenManager.validateToken(
            ctx.capabilityToken, requiredScope: "job.read")
        
        let (jobs, nextToken) = await jobQueue.listJobs(
            pageToken: pageToken,
            pageSize: pageSize,
            filterByState: filterByState
        )
        
        if configuration.governance.auditAllOperations {
            do {
                _ = try await receiptEngine.recordActionExecution(
                    actionName: "job.list",
                    authority: "anigmad",
                    decision: .allowed,
                    reasonCode: "LISTED",
                    inputs: [
                        "client_id": ctx.clientId,
                        "page_token": pageToken ?? "none",
                        "page_size": pageSize ?? 100,
                        "filter_by_state": filterByState.joined(separator: ",")
                    ],
                    outputs: [
                        "count": jobs.count,
                        "next_page_token": nextToken ?? "none"
                    ]
                )
            } catch {
                logWarning("failed to record job list receipt: \(error)", category: "Receipt")
            }
        }
        
        return (jobs, nextToken)
    }

    func handleStreamTelemetry(
        ctx: DaemonRequestContext,
        events: [AnigmaTelemetryEvent]
    ) async throws -> (ok: Bool, receiptHash: String?) {
        // TODO: implement
        throw DaemonError.configurationError("StreamTelemetry not implemented")
    }

    private func executeJob(_ job: Job) async {
        logInfo("Starting job: \(job.id)", category: "JobExecution")
        var execOutputs: [ArtifactRef] = []
        var execError: String?
        var decision: ReceiptDecision = .allowed
        var reason: String = "JOB_COMPLETED"

        do {
            await jobQueue.markRunning(jobId: job.id)
            await emitJobEvent(jobId: job.id, type: .state, message: JobState.running.rawValue, progressPermille: 0)

            guard await jobRegistry.worker(for: job.spec.kind) != nil else {
                throw WorkerError.executionFailed("Unknown job kind: \(job.spec.kind)")
            }

            switch configuration.daemon.executionMode {
            case .subprocess:
                let worker = await workerPool.acquireWorker(for: job.id)
                defer {
                    let pool = self.workerPool
                    Task { await pool.releaseWorker(worker) }
                }

                let vaultData = try await loadVaultData(for: job.spec.inputs)
                let workerOutputs = try await worker.execute(job: job, vaultData: vaultData)
                execOutputs = try await ingestWorkerOutputs(workerOutputs, inputs: job.spec.inputs, jobId: job.id, jobKind: job.spec.kind)
            case .inProcess:
                let workerOutputs = try await executeInProcess(job)
                execOutputs = try await ingestWorkerOutputs(workerOutputs, inputs: job.spec.inputs, jobId: job.id, jobKind: job.spec.kind)
            }
        } catch {
            execError = error.localizedDescription
            decision = .error
            reason = "JOB_FAILED"
        }

        do {
            let receipt = try await receiptEngine.recordActionExecution(
                actionName: job.spec.kind,
                authority: "anigmad",
                decision: decision,
                reasonCode: reason,
                inputs: ["job_id": job.id],
                outputs: ["output_count": execOutputs.count, "error": execError ?? "none"]
            )

            if let err = execError {
                await jobQueue.fail(jobId: job.id, error: err, receiptHash: receipt.receiptID)
                await emitJobEvent(jobId: job.id, type: .state, message: JobState.failed.rawValue, progressPermille: 0, receiptHash: receipt.receiptID, error: ErrorStatus(code: "JOB_FAILED", message: err, detailJson: nil))
            } else {
                await jobQueue.complete(jobId: job.id, outputs: execOutputs, receiptHash: receipt.receiptID)
                await emitJobEvent(jobId: job.id, type: .state, message: JobState.succeeded.rawValue, progressPermille: 1000, receiptHash: receipt.receiptID)
            }
        } catch {
            print("Receipt failed: \(error)")
        }
    }

    func executeInProcess(_ job: Job) async throws -> [JobOutputPayload] {
        guard let worker = await jobRegistry.worker(for: job.spec.kind) else {
            throw WorkerError.executionFailed("Unknown job kind: \(job.spec.kind)")
        }

        let vaultData = try await loadVaultData(for: job.spec.inputs)
        return try await worker.execute(inputs: job.spec.inputs, config: job.spec.configCanonical, vaultData: vaultData)
    }

    func ingestWorkerOutputs(_ outputs: [JobOutputPayload], inputs: [ArtifactRef], jobId: String, jobKind: String) async throws -> [ArtifactRef] {
        var finalOutputs: [ArtifactRef] = []
        for output in outputs {
            let vKind = StorageCore.VaultArtifactKind(rawValue: output.kind) ?? .derived
            let ref = try await vault.ingest(data: output.data, kind: vKind, mime: output.mediaType)
            let artifactRef = ArtifactRef(hash: ref.sha256Hex, mediaType: ref.mime, sizeBytes: UInt64(ref.byteLen))
            finalOutputs.append(artifactRef)

            for input in inputs {
                try await vault.recordEdge(parentHash: input.hash, childHash: ref.sha256Hex, relation: "derived_from", runId: jobId, stepId: jobKind)
            }

            let receipt = try await receiptEngine.recordActionExecution(
                actionName: "job.output.ingest",
                authority: "anigmad",
                decision: .allowed,
                reasonCode: "OUTPUT_INGESTED",
                inputs: ["job_id": jobId, "output_hash": ref.sha256Hex],
                outputs: ["mime": ref.mime, "bytes": ref.byteLen]
            )
        }
        return finalOutputs
    }

    func handleStreamJobEvents(ctx: DaemonRequestContext, jobId: String) async throws -> AsyncStream<DaemonJobEvent> {
        return AsyncStream { _ in }
    }

    private func isValidReceiptHash(_ hash: String) -> Bool {
        return hash.count == 64 && hash.allSatisfy { $0.isHexDigit }
    }

    private func decodeTelemetryPayload(_ payloadJson: String) throws -> TelemetryEvent {
        let data = Data(payloadJson.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TelemetryEvent.self, from: data)
    }

    private func recordTelemetryReceipt(ctx: DaemonRequestContext, event: AnigmaTelemetryEvent, decision: ReceiptDecision, reasonCode: String, error: String?) async -> String? {
        let receipt = try? await receiptEngine.recordActionExecution(
            actionName: "telemetry.event",
            authority: "anigmad",
            decision: decision,
            reasonCode: reasonCode,
            inputs: ["client_id": ctx.clientId, "event_type": event.type],
            outputs: ["error": error ?? "none"]
        )
        return receipt?.receiptID
    }

    private func logInfo(_ message: String, category: String) {
        Task {
            _ = await telemetry.emit(
                category: .system,
                name: "log_info",
                values: [
                    "message": .hashedToken(TelemetryHash(input: message)),
                    "category": .hashedToken(TelemetryHash(input: category))
                ]
            )
            print("[\(category)] \(message)")
        }
    }

    private func logWarning(_ message: String, category: String) {
        Task {
            _ = await telemetry.emit(
                category: .system,
                name: "log_warning",
                values: [
                    "message": .hashedToken(TelemetryHash(input: message)),
                    "category": .hashedToken(TelemetryHash(input: category))
                ]
            )
            print("[\(category)] WARNING: \(message)")
        }
    }

    private func logError(_ message: String, category: String) {
         Task {
             _ = await telemetry.emit(
                 category: .system,
                 name: "log_error",
                 values: [
                    "message": .hashedToken(TelemetryHash(input: message)),
                    "category": .hashedToken(TelemetryHash(input: category))
                 ]
             )
             print("[\(category)] ERROR: \(message)")
         }
     }
}

// MARK: - Errors

public enum DaemonError: Error, LocalizedError {
    case alreadyRunning
    case notRunning
    case configurationError(String)
    case invalidPageToken(String)
    case rateLimitExceeded

    public var errorDescription: String? {
        switch self {
        case .alreadyRunning: return "Daemon already running"
        case .notRunning: return "Daemon not running"
        case .configurationError(let d): return "Config error: \(d)"
        case .invalidPageToken(let t): return "Invalid token: \(t)"
        case .rateLimitExceeded: return "Rate limit exceeded"
        }
    }
}
