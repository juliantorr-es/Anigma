//
//  PipelineRunner.swift
//  AnigmaCore
//
//  [Brief description of file purpose]
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import InferenceCore
import AnigmaFoundation
import AnigmaPrimitives
import ContractsCore
import SaturationKit
import DatabaseCore
import Foundation
import SecurityEventsManager

/// Pipeline runner that executes contract DAGs with strict budgets and receipts; tool access is denied by default.
public actor PipelineRunner {
    private let plan: PipelinePlan
    private let registry: ContractRegistry
    private let jobQueue: ContractJobQueue
    private let receiptStore: ReceiptStore
    private let artifactStore: PipelineArtifactStore
    private let defaultBudgets: ContractBudgets
    private let trustTier: TrustTier
    private let securityZone: SecurityZone
    private let executorIdentity: String
    private let now: () -> Date
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let embeddingComputer: EmbeddingComputing?
    private let testRunner: TestCommandRunning?
    private let grapheneEngine: GrapheneEngine

    private var receipts: [ContractReceipt]

    public init(
        plan: PipelinePlan,
        registry: ContractRegistry,
        jobQueue: ContractJobQueue,
        receiptStore: ReceiptStore,
        artifactStore: PipelineArtifactStore,
        defaultBudgets: ContractBudgets = ContractBudgets(maxWallTime: 5, maxRetries: 0),
        trustTier: TrustTier = .silver,
        securityZone: SecurityZone = .restricted,
        executorIdentity: String = "pipeline-runner",
        embeddingComputer: EmbeddingComputing? = nil,
        testRunner: TestCommandRunning? = nil,
        grapheneEngine: GrapheneEngine = GrapheneEngine(),
        now: @escaping () -> Date = { Date() }
    ) async throws {
        self.plan = plan
        self.registry = registry
        self.jobQueue = jobQueue
        self.receiptStore = receiptStore
        self.artifactStore = artifactStore
        self.defaultBudgets = defaultBudgets
        self.trustTier = trustTier
        self.securityZone = securityZone
        self.executorIdentity = executorIdentity
        self.embeddingComputer = embeddingComputer
        self.testRunner = testRunner
        self.grapheneEngine = grapheneEngine  // Initialize the new property
        self.now = now

        self.decoder = Self.makeDecoder()
        self.encoder = Self.makeEncoder()

        self.receipts = try await receiptStore.fetchReceipts(sessionID: plan.sessionID)
    }

    /// Factory method for lightweight test setups with provided database.
    /// 
    /// Preferred initializer - receives DatabaseExecutor via dependency injection.
    /// See ADR-0018 and td-317bbb for details.
    public static func create(
        engine: GrapheneEngine,
        database: any DatabaseExecutor
    ) async throws -> PipelineRunner {
        let plan = PipelinePlan(
            sessionID: UUID().uuidString,
            graph: PipelineGraph(edges: [:]),
            rootArtifactRefs: []
        )
        let registry = ContractRegistry()
        let jobQueue = try await ContractJobQueue(database: database)
        let receiptStore = try await ReceiptStore(database: database)
        let artifactStore = InMemoryPipelineArtifactStore()

        return try await PipelineRunner(
            plan: plan,
            registry: registry,
            jobQueue: jobQueue,
            receiptStore: receiptStore,
            artifactStore: artifactStore,
            grapheneEngine: engine
        )
    }

    public func runWithProfiling(
        graph: NodeGraph,
        inputs: [String: AnyPortValue] = [:],
        options: ExecutionOptions = .default
    ) async throws -> (result: GraphExecutionResult, trace: ExecutionTrace?) {
        let result = try await grapheneEngine.execute(
            graph: graph, inputs: inputs, options: options)
        // GrapheneEngine's execute method doesn't directly return a trace.
        // For now, we return nil for the trace. Profiling would need to be integrated
        // at the GrapheneEngine level with GrapheneProfiler.
        return (result, nil)
    }

    public func runStreaming(
        graph: NodeGraph,
        inputs: [String: AnyPortValue] = [:],
        options: ExecutionOptions = .default
    ) async -> ThrowingTransformSequence<
        AsyncThrowingStream<StreamingGraphOutput, Error>, PipelineStreamEvent
    > {
        let stream = await grapheneEngine.executeStreaming(
            graph: graph, inputs: inputs, options: options)
        return ThrowingTransformSequence(base: stream) { output -> PipelineStreamEvent in
            switch output {
            case .nodeStarted(let nodeId, let nodeName):
                return .nodeStarted(nodeId: nodeId, name: nodeName)
            case .nodeProgress(let nodeId, let progress, let message):
                return .progress(nodeId: nodeId, progress: progress, message: message)
            case .nodeChunk(let nodeId, let portName, let value):
                return .chunk(nodeId: nodeId, portName: portName, value: value)
            case .nodeCompleted(let nodeId, let executionTime):
                return .nodeCompleted(nodeId: nodeId, time: executionTime)
            case .complete(let result):
                return .complete(result: result)
            }
        }
    }

    /// Runs the pipeline until no eligible jobs remain. Safe to call repeatedly; plan enqueue is idempotent.
    public func runUntilIdle() async throws {
        try await ensurePlanEnqueued()

        while let job = try await jobQueue.dequeueNextReady(sessionID: plan.sessionID) {
            try await run(job: job)
            try await ensurePlanEnqueued()
        }
    }

    /// Returns all receipts (optionally filtered by session).
    public func allReceipts(sessionID: String? = nil) -> [ContractReceipt] {
        receipts.filter { sessionID == nil || $0.sessionID == sessionID }
    }

    /// Returns a compact status snapshot for the current session using persisted receipts/jobs.
    public func statusSnapshot() async throws -> PipelineStatus {
        let persistedReceipts = try await receiptStore.fetchReceipts(sessionID: plan.sessionID)
        let jobs = try await jobQueue.fetchJobs(sessionID: plan.sessionID)
        let nextEligible = plan.nextEligible(receipts: persistedReceipts)

        let satisfied = Set(
            persistedReceipts
                .filter { $0.status == .satisfied }
                .map(\.contractID.name)
        )

        var blocked: [BlockedContractStatus] = []
        let graphNodes = Set(plan.graph.topologicalOrder())
        for node in graphNodes {
            guard !satisfied.contains(node), !nextEligible.contains(node) else { continue }
            let upstream = plan.graph.upstream(of: node)
            let upstreamReceipts = persistedReceipts.filter {
                upstream.contains($0.contractID.name)
            }
            let blockers = upstreamReceipts.filter {
                $0.status != ContractsCore.ContractStatus.satisfied
            }
            guard !blockers.isEmpty else { continue }
            var statuses: [ContractID: ContractStatus] = [:]
            for receipt in blockers {
                statuses[receipt.contractID] = receipt.status
            }
            blocked.append(
                BlockedContractStatus(
                    contractID: ContractID(name: node, major: 1, minor: 0, schemaHash: "v1.0"),
                    upstreamStatuses: statuses))
        }

        let quarantined = persistedReceipts.filter { $0.status == .quarantined }
        let pendingJobs = jobs.filter { $0.status == .pending }
        let runningJobs = jobs.filter { $0.status == .running }

        return PipelineStatus(
            statusSchemaVersion: 1,
            sessionID: plan.sessionID,
            nextEligible: nextEligible,
            blocked: blocked,
            quarantined: quarantined,
            pendingJobs: pendingJobs,
            runningJobs: runningJobs
        )
    }

    /// Ensures all currently eligible contracts for the plan are enqueued exactly once.
    private func ensurePlanEnqueued() async throws {
        receipts = try await receiptStore.fetchReceipts(sessionID: plan.sessionID)
        let eligible = plan.nextEligible(receipts: receipts)
        for contractID in eligible {
            guard
                let spec = await registry.resolve(
                    ContractID(name: contractID, major: 1, minor: 0, schemaHash: "v1.0"))
            else { continue }
            let inputs = plan.inputRefs(
                for: ContractID(name: contractID, major: 1, minor: 0, schemaHash: "v1.0"),
                receipts: receipts)
            let inputKey = try ContractKeyDerivation.inputKey(
                inputArtifactKeys: inputs,
                inputSchemaVersion: spec.inputSchemaVersion
            )

            if let satisfied = try await receiptStore.fetchSatisfiedReceipt(
                contractID: ContractID(name: contractID, major: 1, minor: 0, schemaHash: "v1.0"),  // Convert to ContractID
                sessionID: plan.sessionID,
                inputKey: inputKey.raw
            ) {
                if !receipts.contains(where: { $0.runID == satisfied.runID }) {
                    receipts.append(satisfied)
                }
                continue
            }

            let queueKey = ContractKeyDerivation.queueKey(
                sessionID: plan.sessionID,
                contractID: contractID,  // contractID is already String
                inputKey: inputKey
            )
            let payload = RunContractJobPayload(
                contractID: ContractID(name: contractID, major: 1, minor: 0, schemaHash: "v1.0"),  // Convert to ContractID
                sessionID: plan.sessionID,
                inputArtifactIDs: inputs,
                inputKey: inputKey.raw
            )
            _ = try await jobQueue.enqueueIdempotent(payload, queueKey: queueKey)
        }
    }

    private func run(job: RunContractJobRecord) async throws {
        let start = now()

        guard let spec = await registry.resolve(job.payload.contractID) else {
            let metrics = ExecutionMetrics(
                wallTimeMs: 0,
                toolCallCount: 0,
                retryCount: job.attempts - 1,
                executor: executorIdentity
            )
            let receipt = ContractReceipt(
                contractID: job.payload.contractID,
                runID: job.id,
                sessionID: job.payload.sessionID,
                startedAt: start,
                endedAt: start,
                status: .failed,
                inputRefs: job.payload.inputArtifactIDs,
                outputRefs: [],
                evidenceRefs: [],
                metrics: metrics
            ).withComputedProvenanceHash()
            let stored = try await receiptStore.putReceiptIdempotent(
                receipt, inputKey: job.payload.inputKey)
            receipts.append(stored)
            _ = try await jobQueue.markQuarantined(job.id, reason: "Unknown contract id")
            return
        }

        // Validate trust tier requirements
        // TODO: Fix - requiredTrustTier not available on AnyContractSpec
        // if spec.requiredTrustTier > trustTier {
        //     if let manager = SecurityEventingService.shared {
        //         manager.logCapabilityDecision(
        //             engineId: plan.sessionID,
        //             capability: "pipeline_execution",
        //             granted: false,
        //             trustTier: trustTier.rawValue,
        //             zone: "pipeline",
        //             reason: "Insufficient trust tier for contract: \(spec.id.name) requires \(spec.requiredTrustTier.rawValue)"
        //         )
        //     }
        //     _ = try await jobQueue.markQuarantined(job.id, reason: "Insufficient trust tier")
        //     return
        // }

        let derivedInputKey = try ContractKeyDerivation.inputKey(
            inputArtifactKeys: job.payload.inputArtifactIDs,
            inputSchemaVersion: spec.inputSchemaVersion
        )
        let resolvedInputKey =
            job.payload.inputKey.isEmpty ? derivedInputKey.raw : job.payload.inputKey

        guard derivedInputKey.raw == resolvedInputKey else {
            let mismatch = ContractExecutionError.underlying(
                code: "contract.input.mismatch",
                message: "Input key mismatch for \(spec.id)"
            )
            try await handleFailure(
                job: job,
                status: .failed,
                error: mismatch,
                inputKey: derivedInputKey,
                startedAt: start
            )
            return
        }

        // Short-circuit if already satisfied (idempotent re-run)
        if let satisfied = try await receiptStore.fetchSatisfiedReceipt(
            contractID: spec.id,
            sessionID: plan.sessionID,
            inputKey: resolvedInputKey
        ) {
            if !receipts.contains(where: { $0.runID == satisfied.runID }) {
                receipts.append(satisfied)
            }
            _ = try await jobQueue.markCompleted(job.id)
            return
        }

        do {
            guard let inputID = job.payload.inputArtifactIDs.first else {
                throw ContractExecutionError.underlying(
                    code: "contract.input.missing",
                    message: "No input artifacts supplied"
                )
            }

            let inputEnvelopeData = try await artifactStore.loadEnvelopeData(inputID)
            let decodedInput = try spec.decodeInput(from: inputEnvelopeData, using: decoder)

            let keyMetadata = spec.artifactKeyMetadata(from: decodedInput)
            let artifactKey = try ContractKeyDerivation.artifactKey(
                contractID: spec.id,
                inputHash: derivedInputKey,
                outputSchemaVersion: spec.outputSchemaVersion,
                modelID: keyMetadata.0,
                modelVersion: keyMetadata.1
            )

            // Cache hit: artifact already exists, reuse output without executing.
            if let existingData = try? await artifactStore.loadEnvelopeData(artifactKey.raw) {
                let components = try spec.extractOutputComponents(
                    from: existingData, encoder: encoder, decoder: decoder)
                let metrics = ExecutionMetrics(
                    wallTimeMs: 0,
                    cpuTimeMs: components.metrics.cpuTimeMs,
                    promptTokens: components.metrics.promptTokens,
                    completionTokens: components.metrics.completionTokens,
                    totalTokens: components.metrics.totalTokens,
                    toolCallCount: components.metrics.toolCallCount,
                    retryCount: job.attempts - 1,
                    executor: executorIdentity,
                    cacheHit: true
                )

                let receipt = ContractReceipt(
                    contractID: spec.id,
                    runID: job.id,
                    sessionID: plan.sessionID,
                    startedAt: start,
                    endedAt: start,
                    status: .satisfied,
                    inputRefs: job.payload.inputArtifactIDs,
                    outputRefs: [artifactKey.raw],
                    evidenceRefs: components.evidenceRefs,
                    metrics: metrics
                ).withComputedProvenanceHash()

                let stored = try await receiptStore.putReceiptIdempotent(
                    receipt, inputKey: resolvedInputKey)
                receipts.append(stored)
                _ = try await jobQueue.markCompleted(job.id)
                return
            }

            let loggingRing = try SaturatedLoggingRing(capacity: 1024)

            let ctx = ContractContext(
                contractID: spec.id,
                runID: job.id,
                sessionID: plan.sessionID,
                trustTier: trustTier,
                securityZone: securityZone,
                budgets: defaultBudgets,
                auditLogger: nil,
                evidenceRecorder: nil,
                executorIdentity: executorIdentity,
                embeddingComputer: embeddingComputer,
                testRunner: testRunner,
                lane: spec.preferredLane ?? .control,
                loggingRing: ContractLoggingRingReference(loggingRing)
            )

            let outputData = try await runWithTimeout(defaultBudgets.maxWallTime) {
                let operationDecoder = Self.makeDecoder()
                let decodedInput = try spec.decodeInput(
                    from: inputEnvelopeData, using: operationDecoder)
                let result = try await spec.executeErased(input: decodedInput, ctx: ctx)
                let operationEncoder = Self.makeEncoder()
                return try spec.encodeOutput(result, using: operationEncoder)
            }

            let outputAny: Any = try spec.decodeOutput(from: outputData, using: decoder)
            try spec.validateErased(output: outputAny)

            let components = try spec.extractOutputComponents(
                from: outputData, encoder: encoder, decoder: decoder)

            let end = now()
            
            let ringSnapshot = await loggingRing.snapshotBinary()
            let ringHash = BLAKE3Digest.hex(of: ringSnapshot)
            
            let metrics = ExecutionMetrics(
                wallTimeMs: Int64(end.timeIntervalSince(start) * 1000),
                cpuTimeMs: components.metrics.cpuTimeMs,
                promptTokens: components.metrics.promptTokens,
                completionTokens: components.metrics.completionTokens,
                totalTokens: components.metrics.totalTokens,
                toolCallCount: components.metrics.toolCallCount,
                retryCount: job.attempts - 1,
                executor: executorIdentity,
                cacheHit: false
            )

            let receipt = ContractReceipt(
                contractID: spec.id,
                runID: job.id,
                sessionID: plan.sessionID,
                startedAt: start,
                endedAt: end,
                status: .satisfied,
                inputRefs: job.payload.inputArtifactIDs,
                outputRefs: [artifactKey.raw],
                evidenceRefs: components.evidenceRefs,
                metrics: metrics,
                loggingRingHash: ringHash
            ).withComputedProvenanceHash()

            let payloadData = components.payloadData
            let evidenceData = try encoder.encode(components.evidenceRefs)
            let metricsData = try encoder.encode(metrics)
            let receiptData = try encoder.encode(receipt)
            let envelopeData = try buildEnvelopeData(
                schemaVersion: components.schemaVersion,
                payloadData: payloadData,
                evidenceData: evidenceData,
                metricsData: metricsData,
                receiptData: receiptData
            )

            try await artifactStore.storeEnvelopeData(
                envelopeData,
                schemaVersion: components.schemaVersion,
                contractID: spec.id.name,
                sessionID: plan.sessionID,
                artifactKey: artifactKey.raw,
                payloadData: payloadData,
                evidenceData: evidenceData,
                metricsData: metricsData,
                receiptData: receiptData
            )
            let stored = try await receiptStore.putReceiptIdempotent(
                receipt, inputKey: resolvedInputKey)
            receipts.append(stored)
            _ = try await jobQueue.markCompleted(job.id)
        } catch let error as ContractValidationError {
            try await handleFailure(
                job: job,
                status: .rejected,
                error: error,
                inputKey: derivedInputKey,
                startedAt: start
            )
        } catch let error as ContractExecutionError {
            try await handleFailure(
                job: job,
                status: .failed,
                error: error,
                inputKey: derivedInputKey,
                startedAt: start
            )
        }
    }

    private func handleFailure(
        job: RunContractJobRecord,
        status: ContractStatus,
        error: Error,
        inputKey: InputKey,
        startedAt: Date
    ) async throws {
        let end = now()
        let metrics = ExecutionMetrics(
            wallTimeMs: Int64(end.timeIntervalSince(startedAt) * 1000),
            cpuTimeMs: nil,
            promptTokens: nil,
            completionTokens: nil,
            totalTokens: nil,
            toolCallCount: 0,
            retryCount: job.attempts - 1,
            executor: executorIdentity,
            cacheHit: false
        )
        let receipt = ContractReceipt(
            contractID: job.payload.contractID,
            runID: job.id,
            sessionID: plan.sessionID,
            startedAt: startedAt,
            endedAt: end,
            status: status,
            inputRefs: job.payload.inputArtifactIDs,
            outputRefs: [],
            evidenceRefs: [],
            metrics: metrics
        ).withComputedProvenanceHash()
        let stored = try await receiptStore.putReceiptIdempotent(receipt, inputKey: inputKey.raw)
        receipts.append(stored)

        let shouldRetry = job.attempts < defaultBudgets.maxRetries
        switch status {
        case .failed where shouldRetry:
            _ = try await jobQueue.markFailed(
                job.id, error: (error as? LocalizedError)?.errorDescription ?? "failed",
                allowRetry: true)
        case .failed, .rejected:
            _ = try await jobQueue.markQuarantined(
                job.id, reason: (error as? LocalizedError)?.errorDescription ?? "rejected")
        case .quarantined:
            _ = try await jobQueue.markQuarantined(
                job.id, reason: (error as? LocalizedError)?.errorDescription ?? "quarantined")
        case .satisfied:
            _ = try await jobQueue.markCompleted(job.id)
        }
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private func runWithTimeout<T: Sendable>(
        _ seconds: TimeInterval?,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        guard let seconds = seconds else {
            return try await operation()
        }

        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw ContractExecutionError.timeout(
                    code: "contract.timeout",
                    message: "Execution exceeded max wall time \(seconds)s"
                )
            }

            guard let result = try await group.next() else {
                throw ContractExecutionError.timeout(
                    code: "contract.timeout",
                    message: "Timeout expired before obtaining a result"
                )
            }
            group.cancelAll()
            return result
        }
    }
}

private func buildEnvelopeData(
    schemaVersion: Int,
    payloadData: Data,
    evidenceData: Data,
    metricsData: Data,
    receiptData: Data
) throws -> Data {
    let payloadObject = try JSONSerialization.jsonObject(with: payloadData)
    let evidenceObject = try JSONSerialization.jsonObject(with: evidenceData)
    let metricsObject = try JSONSerialization.jsonObject(with: metricsData)
    let receiptObject = try JSONSerialization.jsonObject(with: receiptData)

    let envelope: [String: Any] = [
        "schemaVersion": schemaVersion,
        "payload": payloadObject,
        "evidenceRefs": evidenceObject,
        "metrics": metricsObject,
        "receipt": receiptObject
    ]

    return try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
}
