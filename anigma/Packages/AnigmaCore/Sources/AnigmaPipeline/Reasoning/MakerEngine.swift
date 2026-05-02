//
//  MakerEngine.swift
//  AnigmaCore
//
//  Generic MAKER step engine that provides governed, stateless step execution.
//  This is the core of Anigma's self-building capability.
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import InferenceCore
import Foundation
import CryptoKit
import ContractsCore
import AnigmaPrimitives
import SecurityEventsManager

/// Actor-based MAKER engine for governed step execution
public actor MakerEngine {

    // MARK: - Dependencies

    private let policyEngine: PolicyEnforcementEngine
    private let auditLog: any AuditLogging
    private let evidenceRecorder: any EvidenceRecording
    private let candidateGenerators: [CandidateGenerator]
    private let stepExecutors: [StepExecutor]
    private let quarantineManager: QuarantineManager
    private let enhancementLayer: MakerEnhancementLayer
    private var optimizationStrategies: [String: OptimizationStrategy] = [:]

    // MARK: - Configuration

    private let config: MakerEngineConfig

    // MARK: - State

    private var activeTraces: [TraceId: StepTrace] = [:]
    private var failureHistory: [String: [FailureRecord]] = [:]  // stepId -> failures

    // MARK: - Internal Types

    private struct EnhancementContext {
        let inputHash: String
        let deterministicStepId: String
        let determinismContext: DeterminismContext
        let inputSample: MakerResourceSample
    }

    private struct DeterminismObservation {
        private(set) var notSeedableComponents: Set<String> = []

        mutating func markNotSeedable(_ component: String) {
            notSeedableComponents.insert(component)
        }

        var notes: [String]? {
            guard !notSeedableComponents.isEmpty else { return nil }
            return notSeedableComponents.sorted().map { "not_seedable:\($0)" }
        }

        var isSeedable: Bool {
            notSeedableComponents.isEmpty
        }
    }

    private struct AdapterReceiptOutcome {
        let resourceLimitExceeded: Bool
    }

    // MARK: - Initialization

    public init(
        policyEngine: PolicyEnforcementEngine,
        auditLog: any AuditLogging,
        evidenceRecorder: any EvidenceRecording,
        candidateGenerators: [CandidateGenerator] = [],
        stepExecutors: [StepExecutor] = [],
        quarantineManager: QuarantineManager,
        config: MakerEngineConfig = .default,
        enhancementLayer: MakerEnhancementLayer = .fallback(),
        optimizationStrategies: [String: OptimizationStrategy] = [:]
    ) {
        self.policyEngine = policyEngine
        self.auditLog = auditLog
        self.evidenceRecorder = evidenceRecorder
        self.candidateGenerators = candidateGenerators
        self.stepExecutors = stepExecutors
        self.quarantineManager = quarantineManager
        self.config = config
        self.enhancementLayer = enhancementLayer
        self.optimizationStrategies = optimizationStrategies
    }

    // MARK: - Public Interface

    /// Execute a step with full governance and tracing
    public func executeStep(_ input: StepInput) async throws -> StepOutput {
        let traceId = TraceId.generate()
        let startTime = Date()

        // Create initial trace
        var trace = StepTrace(
            id: traceId,
            stepId: input.stepId,
            workflowId: input.context.workflowId,
            sessionId: input.context.sessionId,
            timestamp: startTime,
            input: input,
            candidates: [],
            decision: StepDecision(
                stepId: input.stepId,
                selectedCandidate: nil,
                trustTierRequired: input.context.trustTier
            ),
            output: nil,
            events: [
                TraceEvent(
                    id: EventId.generate(),
                    timestamp: startTime,
                    type: .stepStarted,
                    severity: .info,
                    component: "MakerEngine",
                    message: "Step execution started",
                    data: [
                        "stepId": input.stepId.value,
                        "enhancementsEnabled": "\(config.enhancementsEnabled)"
                    ]
                )
            ]
        )

        activeTraces[traceId] = trace

        let enhancementContext = buildEnhancementContext(for: input)
        var determinismObservation = DeterminismObservation()

        do {
            // Check quarantine status first
            if let quarantineAction = try await checkQuarantine(for: input) {
                trace.events.append(TraceEvent(
                    id: EventId.generate(),
                    timestamp: Date(),
                    type: .quarantineTriggered,
                    severity: .warning,
                    component: "MakerEngine",
                    message: "Step is quarantined",
                    data: ["reason": quarantineAction.reason]
                ))

                // Log to SecurityEventsManager
                if let manager = SecurityEventingService.shared {
                    manager.logCapabilityDecision(
                        engineId: input.stepId.value,
                        capability: "step_execution",
                        granted: false,
                        trustTier: input.context.trustTier.rawValue,
                        zone: input.context.zone.rawValue,
                        reason: "Step quarantined - \(quarantineAction.reason)"
                    )
                }

                let quarantinedOutput = StepOutput(
                    stepId: input.stepId,
                    stateDelta: StateDelta(),
                    metrics: StepMetrics(duration: 0, memoryUsed: 0),
                    status: .quarantined
                )

                try await finalizeTrace(&trace, output: quarantinedOutput)
                return quarantinedOutput
            }

            // Deterministic size-cap guard for enhancements (does not run when disabled)
            if let enhancementContext, config.enhancementsEnabled {
                if enhancementContext.inputSample.bytes > config.enhancementLimits.maxBytes
                    || enhancementContext.inputSample.lines > config.enhancementLimits.maxLines {
                    await quarantineManager.quarantineStep(
                        stepId: input.stepId,
                        reason: "resource_limit",
                        duration: config.quarantineDuration
                    )

                    // Log to SecurityEventsManager
                    if let manager = SecurityEventingService.shared {
                        manager.logCapabilityDecision(
                            engineId: input.stepId.value,
                            capability: "resource_allocation",
                            granted: false,
                            trustTier: input.context.trustTier.rawValue,
                            zone: input.context.zone.rawValue,
                            reason: "Enhancement resource limit exceeded"
                        )
                    }

                    let cappedOutput = StepOutput(
                        stepId: input.stepId,
                        stateDelta: StateDelta(),
                        metrics: StepMetrics(duration: 0, memoryUsed: Int64(enhancementContext.inputSample.bytes)),
                        status: .quarantined
                    )

                    await recordEnhancementReceipt(
                        for: input,
                        output: cappedOutput,
                        decision: nil,
                        enhancementContext: enhancementContext,
                        resourceLimitExceeded: true,
                        quarantineDecision: "resource_limit",
                        determinismObservation: determinismObservation,
                        startedAt: startTime,
                        finishedAt: Date()
                    )

                    try await finalizeTrace(&trace, output: cappedOutput)
                    return cappedOutput
                }
            }

            // Generate candidates
            let candidates = try await generateCandidates(
                for: input,
                determinismContext: enhancementContext?.determinismContext,
                determinismObservation: &determinismObservation
            )
            trace.candidates = candidates

            trace.events.append(TraceEvent(
                id: EventId.generate(),
                timestamp: Date(),
                type: .candidateGenerated,
                severity: .info,
                component: "MakerEngine",
                message: "Generated \(candidates.count) candidates",
                data: ["count": "\(candidates.count)"]
            ))

            // Evaluate candidates against policy
            let evaluatedCandidates = try await evaluateCandidates(candidates, for: input)

            // Select best candidate deterministically
            let decision = try await selectCandidate(
                from: evaluatedCandidates,
                for: input,
                determinismContext: enhancementContext?.determinismContext
            )
            trace.decision = decision

            trace.events.append(TraceEvent(
                id: EventId.generate(),
                timestamp: Date(),
                type: .candidateSelected,
                severity: .info,
                component: "MakerEngine",
                message: decision.selectedCandidate != nil ? "Candidate selected" : "No candidate selected",
                data: decision.selectedCandidate.map { ["candidateId": $0.value] } ?? [:]
            ))

            let selectedCandidate = decision.selectedCandidate.flatMap { selectedId in
                candidates.first { $0.id == selectedId }
            }

            if let enhancementContext, config.enhancementsEnabled, let selectedCandidate {
                let adapterOutcome = await emitAdapterReceipts(
                    for: selectedCandidate,
                    input: input,
                    enhancementContext: enhancementContext,
                    determinismObservation: &determinismObservation
                )
                if adapterOutcome.resourceLimitExceeded {
                    await quarantineManager.quarantineStep(
                        stepId: input.stepId,
                        reason: "resource_limit",
                        duration: config.quarantineDuration
                    )

                    let cappedOutput = StepOutput(
                        stepId: input.stepId,
                        stateDelta: StateDelta(),
                        metrics: StepMetrics(duration: 0, memoryUsed: Int64(enhancementContext.inputSample.bytes)),
                        status: .quarantined
                    )

                    await recordEnhancementReceipt(
                        for: input,
                        output: cappedOutput,
                        decision: decision,
                        enhancementContext: enhancementContext,
                        resourceLimitExceeded: true,
                        quarantineDecision: "resource_limit",
                        determinismObservation: determinismObservation,
                        startedAt: startTime,
                        finishedAt: Date()
                    )

                    try await finalizeTrace(&trace, output: cappedOutput)
                    return cappedOutput
                }
            }

            // Execute selected candidate or return failure
            let output: StepOutput
            if decision.selectedCandidate != nil {
                guard let selectedCandidate else {
                    throw MakerEngineError.selectedCandidateNotFound
                }

                output = try await executeCandidate(
                    selectedCandidate,
                    for: input,
                    determinismContext: enhancementContext?.determinismContext,
                    determinismObservation: &determinismObservation
                )
                trace.events.append(TraceEvent(
                    id: EventId.generate(),
                    timestamp: Date(),
                    type: .stepCompleted,
                    severity: .info,
                    component: "MakerEngine",
                    message: "Step completed successfully",
                    data: ["duration": "\(output.metrics.duration)"]
                ))
            } else {
                // No candidate selected - create failure output
                output = StepOutput(
                    stepId: input.stepId,
                    stateDelta: StateDelta(),
                    metrics: StepMetrics(duration: Date().timeIntervalSince(startTime), memoryUsed: 0),
                    status: .failed
                )

                trace.events.append(TraceEvent(
                    id: EventId.generate(),
                    timestamp: Date(),
                    type: .stepFailed,
                    severity: .error,
                    component: "MakerEngine",
                    message: decision.rejectionReason ?? "No suitable candidate found",
                    data: [:]
                ))

                // Record failure for loop resistance
                await recordFailure(for: input.stepId, reason: decision.rejectionReason ?? "No candidate")
            }

            if let enhancementContext {
                await recordEnhancementReceipt(
                    for: input,
                    output: output,
                    decision: decision,
                    enhancementContext: enhancementContext,
                    resourceLimitExceeded: false,
                    quarantineDecision: output.status == .quarantined ? "quarantined" : nil,
                    determinismObservation: determinismObservation,
                    startedAt: startTime,
                    finishedAt: Date()
                )
            }

            try await finalizeTrace(&trace, output: output)
            return output

        } catch {
            // Handle execution errors
            let errorOutput = StepOutput(
                stepId: input.stepId,
                stateDelta: StateDelta(),
                metrics: StepMetrics(duration: Date().timeIntervalSince(startTime), memoryUsed: 0),
                status: .failed
            )

            trace.events.append(TraceEvent(
                id: EventId.generate(),
                timestamp: Date(),
                type: .stepFailed,
                severity: .error,
                component: "MakerEngine",
                message: error.localizedDescription,
                data: ["error": String(describing: error)]
            ))

            await recordFailure(for: input.stepId, reason: error.localizedDescription)

            if let enhancementContext {
                await recordEnhancementReceipt(
                    for: input,
                    output: errorOutput,
                    decision: nil,
                    enhancementContext: enhancementContext,
                    resourceLimitExceeded: false,
                    quarantineDecision: nil,
                    determinismObservation: determinismObservation,
                    startedAt: startTime,
                    finishedAt: Date()
                )
            }

            try await finalizeTrace(&trace, output: errorOutput)
            throw error
        }
    }

    /// Get trace for a specific step
    public func getTrace(_ traceId: TraceId) async -> StepTrace? {
        return activeTraces[traceId]
    }

    /// Get failure history for loop resistance analysis
    public func getFailureHistory(for stepId: StepId) async -> [FailureRecord] {
        return failureHistory[stepId.value, default: []]
    }

    // MARK: - Optimization Interface

    /// Register an optimization strategy with the engine
    public func registerOptimizationStrategy(_ strategy: OptimizationStrategy) {
        optimizationStrategies[strategy.strategyId] = strategy
    }

    /// Apply optimization to candidates before policy evaluation
    public func applyOptimizations(
        to candidates: [StepCandidate],
        context: StepContext,
        profile: OptimizationProfile
    ) async throws -> [OptimizedCandidate] {
        var optimizedCandidates: [OptimizedCandidate] = []
        
        for candidate in candidates {
            var currentCandidate = candidate
            
            // Apply each optimization strategy in profile order
            for strategyId in profile.strategyIds {
                guard let strategy = optimizationStrategies[strategyId] else { continue }
                
                do {
                    let optimized = try await strategy.optimize(
                        candidate: currentCandidate,
                        context: context
                    )
                    currentCandidate = optimized.optimizedCandidate
                    
                    // Create optimization record
                    let optimizedCandidate = OptimizedCandidate(
                        originalCandidate: candidate,
                        optimizedCandidate: currentCandidate,
                        optimizationStrategy: strategyId,
                        optimizationMetrics: OptimizationMetrics(
                            performanceImprovement: 0.0, // Calculate based on execution
                            resourceReduction: ResourceEstimate(),
                            confidenceImpact: 0.0,      // Calculate based on policy impact
                            optimizationTimeMs: Date().timeIntervalSince(Date()),
                            determinismPreserved: true
                        ),
                        appliedOptimizations: [
                            AppliedOptimization(
                                optimizationType: .performanceImprovement,
                                description: "Applied \(strategy.name)",
                                beforeValue: "original",
                                afterValue: "optimized",
                                impactScore: 0.5
                            )
                        ]
                    )
                    optimizedCandidates.append(optimizedCandidate)
                } catch {
                    // Log optimization failure but continue with original candidate
                    try await auditLog.recordEvent(
                        id: UUID(),
                        type: .custom,
                        principal: "MakerEngine",
                        module: "OptimizationEngine",
                        description: "Optimization failed for strategy \(strategyId): \(error)",
                        metadata: [
                            "strategyId": strategyId,
                            "candidateId": candidate.id.value,
                            "error": String(describing: error)
                        ]
                    )
                    
                    // Add original candidate without optimization
                    let unoptimizedCandidate = OptimizedCandidate(
                        originalCandidate: candidate,
                        optimizedCandidate: candidate,
                        optimizationStrategy: strategyId,
                        optimizationMetrics: OptimizationMetrics(
                            performanceImprovement: 0.0,
                            resourceReduction: ResourceEstimate(),
                            confidenceImpact: 0.0,
                            optimizationTimeMs: 0,
                            determinismPreserved: true
                        ),
                        appliedOptimizations: []
                    )
                    optimizedCandidates.append(unoptimizedCandidate)
                }
            }
        }
        
        return optimizedCandidates
    }

    /// Execute step with optimization profile
    public func executeStepWithOptimizations(
        _ input: StepInput,
        optimizationProfile: OptimizationProfile
    ) async throws -> StepOutput {
        let traceId = TraceId.generate()
        let startTime = Date()
        
        // Create optimization context (currently unused - available for future optimization strategies)
        _ = OptimizationContext(
            sessionId: input.context.sessionId,
            workflowId: input.context.workflowId,
            optimizationProfile: optimizationProfile,
            deterministicSeed: nil // Use input hash for determinism
        )
        
        // Create initial trace
        var trace = StepTrace(
            id: traceId,
            stepId: input.stepId,
            workflowId: input.context.workflowId,
            sessionId: input.context.sessionId,
            timestamp: startTime,
            input: input,
            candidates: [],
            decision: StepDecision(
                stepId: input.stepId,
                selectedCandidate: nil,
                trustTierRequired: input.context.trustTier
            ),
            output: nil,
            events: [
                TraceEvent(
                    id: EventId.generate(),
                    timestamp: startTime,
                    type: .stepStarted,
                    severity: .info,
                    component: "MakerEngine",
                    message: "Optimized step execution started",
                    data: [
                        "stepId": input.stepId.value,
                        "optimizationProfile": optimizationProfile.profileId,
                        "strategyCount": "\(optimizationProfile.strategyIds.count)"
                    ]
                )
            ]
        )
        
        activeTraces[traceId] = trace
        
        do {
            // Generate candidates
            var determinismObservation = DeterminismObservation()
            let candidates = try await generateCandidates(for: input, determinismContext: nil, determinismObservation: &determinismObservation)
            
            // Apply optimizations
            let optimizedCandidates = try await applyOptimizations(
                to: candidates,
                context: input.context,
                profile: optimizationProfile
            )
            
            trace.candidates = optimizedCandidates.map { $0.originalCandidate }
            trace.events.append(TraceEvent(
                id: EventId.generate(),
                timestamp: Date(),
                type: .candidateGenerated,
                severity: .info,
                component: "MakerEngine",
                message: "Generated and optimized \(optimizedCandidates.count) candidates",
                data: ["count": "\(optimizedCandidates.count)"]
            ))
            
            // Evaluate optimized candidates against policy
            let evaluatedOptimzed = try await evaluateCandidates(optimizedCandidates.map { $0.optimizedCandidate }, for: input)
            
            // Select best optimized candidate deterministically
            let decision = try await selectCandidate(from: evaluatedOptimzed, for: input, determinismContext: nil)
            trace.decision = decision
            
            trace.events.append(TraceEvent(
                id: EventId.generate(),
                timestamp: Date(),
                type: .candidateSelected,
                severity: .info,
                component: "MakerEngine",
                message: decision.selectedCandidate != nil ? "Optimized candidate selected" : "No optimized candidate selected",
                data: decision.selectedCandidate.map { ["candidateId": $0.value] } ?? [:]
            ))
            
            let selectedOptimzed = decision.selectedCandidate.flatMap { selectedId in
                optimizedCandidates.first { $0.optimizedCandidate.id == selectedId }
            }
            
            // Execute selected optimized candidate
            let output: StepOutput
            if decision.selectedCandidate != nil {
                guard let selectedOptimzed = selectedOptimzed else {
                    throw MakerEngineError.selectedCandidateNotFound
                }
                
                output = try await executeCandidate(
                    selectedOptimzed.optimizedCandidate,
                    for: input,
                    determinismContext: nil,
                    determinismObservation: &determinismObservation
                )
                trace.events.append(TraceEvent(
                    id: EventId.generate(),
                    timestamp: Date(),
                    type: .stepCompleted,
                    severity: .info,
                    component: "MakerEngine",
                    message: "Optimized step completed successfully",
                    data: ["duration": "\(output.metrics.duration)"]
                ))
            } else {
                // No candidate selected - create failure output
                output = StepOutput(
                    stepId: input.stepId,
                    stateDelta: StateDelta(),
                    metrics: StepMetrics(duration: Date().timeIntervalSince(startTime), memoryUsed: 0),
                    status: .failed
                )
                trace.events.append(TraceEvent(
                    id: EventId.generate(),
                    timestamp: Date(),
                    type: .stepFailed,
                    severity: .error,
                    component: "MakerEngine",
                    message: decision.rejectionReason ?? "No suitable optimized candidate found",
                    data: [:]
                ))
                
                // Record failure for loop resistance
                await recordFailure(for: input.stepId, reason: decision.rejectionReason ?? "No optimized candidate")
            }
            
            try await finalizeTrace(&trace, output: output)
            return output
            
        } catch {
            // Handle execution errors
            let errorOutput = StepOutput(
                stepId: input.stepId,
                stateDelta: StateDelta(),
                metrics: StepMetrics(duration: Date().timeIntervalSince(startTime), memoryUsed: 0),
                status: .failed
            )
            trace.events.append(TraceEvent(
                id: EventId.generate(),
                timestamp: Date(),
                type: .stepFailed,
                severity: .error,
                component: "MakerEngine",
                message: error.localizedDescription,
                data: ["error": String(describing: error)]
            ))
            
            await recordFailure(for: input.stepId, reason: error.localizedDescription)
            try await finalizeTrace(&trace, output: errorOutput)
            throw error
        }
    }

    // MARK: - Private Methods

    private func buildEnhancementContext(for input: StepInput) -> EnhancementContext? {
        guard config.enhancementsEnabled else { return nil }
        guard let inputData = try? MakerReceiptEncoding.canonicalData(input) else { return nil }
        let inputHash = MakerReceiptEncoding.blake3Hex(of: inputData)
        let deterministicStepId = MakerReceiptEncoding.blake3Hex(
            of: Data((inputHash + config.enhancementCodeVersion).utf8)
        )
        let determinismContext = DeterminismContext(
            seed: deterministicStepId,
            deterministicStepId: deterministicStepId
        )
        let inputSample = MakerResourceSizer.measure(data: inputData)
        return EnhancementContext(
            inputHash: inputHash,
            deterministicStepId: deterministicStepId,
            determinismContext: determinismContext,
            inputSample: inputSample
        )
    }

    private func deterministicOutputHash(for output: StepOutput) -> String? {
        let sanitizedMetrics = StepMetrics(
            duration: 0,
            memoryUsed: 0,
            tokensProcessed: nil,
            filesAccessed: 0,
            networkCalls: 0
        )
        let sanitizedOutput = StepOutput(
            stepId: output.stepId,
            stateDelta: output.stateDelta,
            artifacts: output.artifacts,
            metrics: sanitizedMetrics,
            status: output.status
        )
        guard let data = try? MakerReceiptEncoding.canonicalData(sanitizedOutput) else { return nil }
        return MakerReceiptEncoding.blake3Hex(of: data)
    }

    private func currentAdapterIdentifiers() -> [String: String] {
        [
            MakerAdapterIdentity.diffId: adapterVersion(for: enhancementLayer.diffAdapter),
            MakerAdapterIdentity.parseId: adapterVersion(for: enhancementLayer.parseAdapter),
            MakerAdapterIdentity.regexId: adapterVersion(for: enhancementLayer.regexValidator),
            MakerAdapterIdentity.policyId: adapterVersion(for: enhancementLayer.policyEvaluator)
        ]
    }

    private func adapterVersion(for adapter: Any) -> String {
        if let versioned = adapter as? MakerAdapterVersioned {
            return versioned.adapterVersion
        }
        return MakerAdapterIdentity.unknownVersion
    }

    private func candidateTieBreakKey(
        for candidate: StepCandidate,
        determinismContext: DeterminismContext?
    ) -> String {
        guard let determinismContext else { return candidate.id.value }
        let core = CandidateTieBreakCore(
            action: candidate.action,
            reasoning: candidate.reasoning,
            estimatedImpact: candidate.estimatedImpact,
            policyFlags: candidate.policyFlags
        )
        guard let data = try? MakerReceiptEncoding.canonicalData(core) else {
            return candidate.id.value
        }
        let coreHash = MakerReceiptEncoding.blake3Hex(of: data)
        return MakerReceiptEncoding.blake3Hex(of: Data((determinismContext.seed + coreHash).utf8))
    }

    private func baselineText(for input: StepInput) -> String {
        guard let data = try? MakerReceiptEncoding.canonicalData(input.stateSlice) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    private func candidateText(for candidate: StepCandidate) -> String {
        let sortedParameters = candidate.action.parameters
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
        return [
            "action:\(candidate.action.type.rawValue)",
            "params:\(sortedParameters)",
            "reasoning:\(candidate.reasoning)"
        ].joined(separator: "\n")
    }

    private func regexPattern(for input: StepInput) -> String {
        input.stateSlice.metadata["regexPattern"] ?? ".*"
    }

    private func emitAdapterReceipts(
        for candidate: StepCandidate,
        input: StepInput,
        enhancementContext: EnhancementContext,
        determinismObservation: inout DeterminismObservation
    ) async -> AdapterReceiptOutcome {
        let baseline = baselineText(for: input)
        let candidatePayload = candidateText(for: candidate)
        let pattern = regexPattern(for: input)
        let determinismContext = enhancementContext.determinismContext
        let trackSeedability = config.enhancementDeterminismCheckEnabled
        var resourceLimitExceeded = false

        // Diff adapter receipt
        let diffAdapter = enhancementLayer.diffAdapter
        let diffSeededAdapter = diffAdapter as? SeededMakerDiffAdapter
        let diffLimitExceeded = MakerResourceSizer.exceeds(texts: [baseline, candidatePayload], limits: config.enhancementLimits)
        let diffNotes: [String]?
        if trackSeedability, diffSeededAdapter == nil {
            determinismObservation.markNotSeedable("adapter:\(MakerAdapterIdentity.diffId)")
            diffNotes = ["not_seedable:adapter:\(MakerAdapterIdentity.diffId)"]
        } else {
            diffNotes = nil
        }
        let diffStarted = Date()
        let diffResult: MakerDiffResult
        if diffLimitExceeded {
            resourceLimitExceeded = true
            diffResult = MakerDiffResult(changed: false, deltaBytes: 0, summary: "Resource limit exceeded")
        } else if let diffSeededAdapter {
            if let result = try? diffSeededAdapter.diff(
                baseline: baseline,
                candidate: candidatePayload,
                limits: config.enhancementLimits,
                determinism: determinismContext
            ) {
                diffResult = result
            } else {
                diffResult = MakerDiffResult(changed: false, deltaBytes: 0, summary: "Adapter error")
            }
        } else {
            if let result = try? diffAdapter.diff(
                baseline: baseline,
                candidate: candidatePayload,
                limits: config.enhancementLimits
            ) {
                diffResult = result
            } else {
                diffResult = MakerDiffResult(changed: false, deltaBytes: 0, summary: "Adapter error")
            }
        }
        let diffFinished = Date()
        let diffInputHash = try? MakerReceiptEncoding.hashCanonical(
            AdapterDiffInput(baseline: baseline, candidate: candidatePayload)
        )
        let diffOutputHash = try? MakerReceiptEncoding.hashCanonical(diffResult)
        let diffSample = MakerResourceSizer.measure(text: candidatePayload)
        persistAdapterReceipt(
            adapterId: MakerAdapterIdentity.diffId,
            adapterVersion: adapterVersion(for: diffAdapter),
            inputHash: diffInputHash,
            outputHash: diffOutputHash,
            policyDecision: nil,
            resourceLimitExceeded: diffLimitExceeded,
            quarantineDecision: diffLimitExceeded ? "resource_limit" : nil,
            enhancementContext: enhancementContext,
            input: input,
            observational: MakerReceiptObservational(
                durationMs: diffFinished.timeIntervalSince(diffStarted) * 1000,
                memoryUsedBytes: diffSample.bytes,
                determinismNotes: diffNotes,
                determinismCheckPassed: nil
            )
        )

        // Parse adapter receipt
        let parseAdapter = enhancementLayer.parseAdapter
        let parseSeededAdapter = parseAdapter as? SeededMakerParseAdapter
        let parseLimitExceeded = MakerResourceSizer.exceeds(text: candidatePayload, limits: config.enhancementLimits)
        let parseNotes: [String]?
        if trackSeedability, parseSeededAdapter == nil {
            determinismObservation.markNotSeedable("adapter:\(MakerAdapterIdentity.parseId)")
            parseNotes = ["not_seedable:adapter:\(MakerAdapterIdentity.parseId)"]
        } else {
            parseNotes = nil
        }
        let parseStarted = Date()
        let parseResult: MakerParseResult
        if parseLimitExceeded {
            resourceLimitExceeded = true
            parseResult = MakerParseResult(nodeCount: 0, diagnostics: ["Resource limit exceeded"])
        } else if let parseSeededAdapter {
            if let result = try? parseSeededAdapter.parse(
                text: candidatePayload,
                limits: config.enhancementLimits,
                determinism: determinismContext
            ) {
                parseResult = result
            } else {
                parseResult = MakerParseResult(nodeCount: 0, diagnostics: ["Adapter error"])
            }
        } else {
            if let result = try? parseAdapter.parse(text: candidatePayload, limits: config.enhancementLimits) {
                parseResult = result
            } else {
                parseResult = MakerParseResult(nodeCount: 0, diagnostics: ["Adapter error"])
            }
        }
        let parseFinished = Date()
        let parseInputHash = try? MakerReceiptEncoding.hashCanonical(
            AdapterParseInput(text: candidatePayload)
        )
        let parseOutputHash = try? MakerReceiptEncoding.hashCanonical(parseResult)
        let parseSample = MakerResourceSizer.measure(text: candidatePayload)
        persistAdapterReceipt(
            adapterId: MakerAdapterIdentity.parseId,
            adapterVersion: adapterVersion(for: parseAdapter),
            inputHash: parseInputHash,
            outputHash: parseOutputHash,
            policyDecision: nil,
            resourceLimitExceeded: parseLimitExceeded,
            quarantineDecision: parseLimitExceeded ? "resource_limit" : nil,
            enhancementContext: enhancementContext,
            input: input,
            observational: MakerReceiptObservational(
                durationMs: parseFinished.timeIntervalSince(parseStarted) * 1000,
                memoryUsedBytes: parseSample.bytes,
                determinismNotes: parseNotes,
                determinismCheckPassed: nil
            )
        )

        // Regex adapter receipt
        let regexAdapter = enhancementLayer.regexValidator
        let regexSeededAdapter = regexAdapter as? SeededMakerRegexValidator
        let regexLimitExceeded = MakerResourceSizer.exceeds(
            texts: [pattern, candidatePayload],
            limits: config.enhancementLimits
        )
        let regexNotes: [String]?
        if trackSeedability, regexSeededAdapter == nil {
            determinismObservation.markNotSeedable("adapter:\(MakerAdapterIdentity.regexId)")
            regexNotes = ["not_seedable:adapter:\(MakerAdapterIdentity.regexId)"]
        } else {
            regexNotes = nil
        }
        let regexStarted = Date()
        let regexResult: MakerRegexValidationResult
        if regexLimitExceeded {
            resourceLimitExceeded = true
            regexResult = MakerRegexValidationResult(
                isMatch: false,
                checkedLength: 0,
                diagnostics: ["Resource limit exceeded"]
            )
        } else if let regexSeededAdapter {
            if let result = try? regexSeededAdapter.validate(
                pattern: pattern,
                content: candidatePayload,
                limits: config.enhancementLimits,
                determinism: determinismContext
            ) {
                regexResult = result
            } else {
                regexResult = MakerRegexValidationResult(
                    isMatch: false,
                    checkedLength: 0,
                    diagnostics: ["Adapter error"]
                )
            }
        } else {
            if let result = try? regexAdapter.validate(
                pattern: pattern,
                content: candidatePayload,
                limits: config.enhancementLimits
            ) {
                regexResult = result
            } else {
                regexResult = MakerRegexValidationResult(
                    isMatch: false,
                    checkedLength: 0,
                    diagnostics: ["Adapter error"]
                )
            }
        }
        let regexFinished = Date()
        let regexInputHash = try? MakerReceiptEncoding.hashCanonical(
            AdapterRegexInput(pattern: pattern, content: candidatePayload)
        )
        let regexOutputHash = try? MakerReceiptEncoding.hashCanonical(regexResult)
        let regexSample = MakerResourceSizer.measure(text: candidatePayload)
        persistAdapterReceipt(
            adapterId: MakerAdapterIdentity.regexId,
            adapterVersion: adapterVersion(for: regexAdapter),
            inputHash: regexInputHash,
            outputHash: regexOutputHash,
            policyDecision: nil,
            resourceLimitExceeded: regexLimitExceeded,
            quarantineDecision: regexLimitExceeded ? "resource_limit" : nil,
            enhancementContext: enhancementContext,
            input: input,
            observational: MakerReceiptObservational(
                durationMs: regexFinished.timeIntervalSince(regexStarted) * 1000,
                memoryUsedBytes: regexSample.bytes,
                determinismNotes: regexNotes,
                determinismCheckPassed: nil
            )
        )

        // Policy adapter receipt
        let policyAdapter = enhancementLayer.policyEvaluator
        let policySeededAdapter = policyAdapter as? SeededMakerPolicyEvaluator
        let policyInput = AdapterPolicyInput(candidate: candidate, context: input.context)
        let policyInputData = try? MakerReceiptEncoding.canonicalData(policyInput)
        let policySample = policyInputData.map(MakerResourceSizer.measure(data:)) ?? MakerResourceSample(bytes: 0, lines: 0)
        let policyLimitExceeded = policySample.bytes > config.enhancementLimits.maxBytes
            || policySample.lines > config.enhancementLimits.maxLines
        let policyNotes: [String]?
        if trackSeedability, policySeededAdapter == nil {
            determinismObservation.markNotSeedable("adapter:\(MakerAdapterIdentity.policyId)")
            policyNotes = ["not_seedable:adapter:\(MakerAdapterIdentity.policyId)"]
        } else {
            policyNotes = nil
        }
        let policyStarted = Date()
        let policyResult: MakerPolicyEvaluation
        let policyAdapterFailed: Bool
        if policyLimitExceeded {
            resourceLimitExceeded = true
            policyResult = MakerPolicyEvaluation(flags: [], violations: [])
            policyAdapterFailed = false
        } else if let policySeededAdapter {
            if let result = try? await policySeededAdapter.evaluate(
                candidate: candidate,
                context: input.context,
                determinism: determinismContext
            ) {
                policyResult = result
                policyAdapterFailed = false
            } else {
                policyResult = MakerPolicyEvaluation(flags: [], violations: [])
                policyAdapterFailed = true
            }
        } else {
            if let result = try? await policyAdapter.evaluate(candidate: candidate, context: input.context) {
                policyResult = result
                policyAdapterFailed = false
            } else {
                policyResult = MakerPolicyEvaluation(flags: [], violations: [])
                policyAdapterFailed = true
            }
        }
        let policyFinished = Date()
        let policyInputHash = try? MakerReceiptEncoding.hashCanonical(policyInput)
        let policyOutputHash = try? MakerReceiptEncoding.hashCanonical(policyResult)
        let policyDecision = policyAdapterFailed
            ? "adapter_error"
            : "flags:\(policyResult.flags.count),violations:\(policyResult.violations.count)"
        persistAdapterReceipt(
            adapterId: MakerAdapterIdentity.policyId,
            adapterVersion: adapterVersion(for: policyAdapter),
            inputHash: policyInputHash,
            outputHash: policyOutputHash,
            policyDecision: policyDecision,
            resourceLimitExceeded: policyLimitExceeded,
            quarantineDecision: policyLimitExceeded ? "resource_limit" : nil,
            enhancementContext: enhancementContext,
            input: input,
            observational: MakerReceiptObservational(
                durationMs: policyFinished.timeIntervalSince(policyStarted) * 1000,
                memoryUsedBytes: policySample.bytes,
                determinismNotes: policyNotes,
                determinismCheckPassed: nil
            )
        )

        return AdapterReceiptOutcome(resourceLimitExceeded: resourceLimitExceeded)
    }

    private func persistAdapterReceipt(
        adapterId: String,
        adapterVersion: String,
        inputHash: String?,
        outputHash: String?,
        policyDecision: String?,
        resourceLimitExceeded: Bool,
        quarantineDecision: String?,
        enhancementContext: EnhancementContext,
        input: StepInput,
        observational: MakerReceiptObservational
    ) {
        guard let inputHash, let outputHash else { return }

        // Use enhancementContext.deterministicStepId as the base deterministic ID for the adapter step
        // But we must mix in the adapter ID to make it unique per adapter
        let adapterDeterministicId = MakerReceiptEncoding.blake3Hex(
            of: Data((enhancementContext.deterministicStepId + adapterId).utf8)
        )

        let core = MakerReceiptCore(
            deterministicStepId: adapterDeterministicId,
            stepId: input.stepId.value,
            sessionId: input.context.sessionId,
            workflowId: input.context.workflowId,
            inputHash: inputHash,
            outputHash: outputHash,
            adapterIdentifiers: [adapterId: adapterVersion],
            policyDecision: policyDecision,
            quarantineDecision: quarantineDecision,
            resourceLimitExceeded: resourceLimitExceeded,
            limits: config.enhancementLimits,
            enhancementEnabled: config.enhancementsEnabled,
            enhancementCodeVersion: config.enhancementCodeVersion
        )
        let receipt = MakerReceipt(core: core, observational: observational)
        do {
            _ = try config.enhancementReceiptPersister.persist(
                receipt: receipt,
                runId: input.context.sessionId,
                stepId: StepId("\(input.stepId.value)-\(adapterId)")
            )
        } catch {
            // Adapter receipt failures must not block MakerEngine execution.
        }
    }

    /// Check if step is quarantined
    private func checkQuarantine(for input: StepInput) async throws -> QuarantineAction? {
        return await quarantineManager.checkQuarantine(
            stepId: input.stepId,
            sessionId: input.context.sessionId,
            trustTier: input.context.trustTier
        )
    }

    /// Generate K candidates from registered generators
    private func generateCandidates(
        for input: StepInput,
        determinismContext: DeterminismContext?,
        determinismObservation: inout DeterminismObservation
    ) async throws -> [StepCandidate] {
        var allCandidates: [StepCandidate] = []

        for generator in candidateGenerators {
            if let determinismContext,
               let seededGenerator = generator as? DeterministicCandidateGenerator {
                let candidates = try await seededGenerator.generateCandidates(for: input, determinism: determinismContext)
                allCandidates.append(contentsOf: candidates)
            } else {
                if determinismContext != nil, config.enhancementDeterminismCheckEnabled {
                    determinismObservation.markNotSeedable("candidate_generator:\(String(describing: type(of: generator)))")
                }
                let candidates = try await generator.generateCandidates(for: input)
                allCandidates.append(contentsOf: candidates)
            }
        }

        // Apply K limit from config
        let k = config.maxCandidatesPerStep
        if allCandidates.count > k {
            // Sort by confidence and take top K
            allCandidates.sort { $0.confidence > $1.confidence }
            allCandidates = Array(allCandidates.prefix(k))
        }

        return allCandidates
    }

    /// Evaluate candidates against policy and trust tier
    private func evaluateCandidates(_ candidates: [StepCandidate], for input: StepInput) async throws -> [EvaluatedCandidate] {
        var evaluated: [EvaluatedCandidate] = []

        for candidate in candidates {
            // Check policy compliance
            let policyResult = try await policyEngine.evaluateAction(
                action: candidate.action,
                context: input.context,
                trustTier: input.context.trustTier
            )

            // Log if policy rejects candidate
            if !policyResult.allowed {
                if let manager = SecurityEventingService.shared {
                    manager.logCapabilityDecision(
                        engineId: input.stepId.value,
                        capability: "candidate_selection",
                        granted: false,
                        trustTier: input.context.trustTier.rawValue,
                        zone: input.context.zone.rawValue,
                        reason: "Policy rejected candidate: \(candidate.name)"
                    )
                }
            }

            // Calculate adjusted score based on policy flags
            let adjustedScore = calculateAdjustedScore(
                originalScore: candidate.confidence,
                policyFlags: candidate.policyFlags + policyResult.flags,
                riskLevel: candidate.estimatedImpact.riskLevel
            )

            evaluated.append(EvaluatedCandidate(
                candidate: candidate,
                adjustedScore: adjustedScore,
                policyResult: policyResult
            ))
        }

        return evaluated
    }

    /// Select best candidate deterministically
    private func selectCandidate(
        from evaluated: [EvaluatedCandidate],
        for input: StepInput,
        determinismContext: DeterminismContext?
    ) async throws -> StepDecision {
        // Filter out candidates with critical policy violations
        let viableCandidates = evaluated.filter { evaluated in
            !evaluated.policyResult.violations.contains { $0.severity == .critical }
        }

        guard !viableCandidates.isEmpty else {
            let violations = evaluated.flatMap { $0.policyResult.violations }
            return StepDecision(
                stepId: input.stepId,
                selectedCandidate: nil,
                rejectionReason: "All candidates have critical policy violations",
                policyViolations: violations,
                trustTierRequired: input.context.trustTier
            )
        }

        // Sort by adjusted score (highest first) with deterministic tie-breaking
        let sortedCandidates = viableCandidates.sorted { (lhs: EvaluatedCandidate, rhs: EvaluatedCandidate) in
            if Swift.abs(lhs.adjustedScore - rhs.adjustedScore) < 0.001 {
                let lhsKey = candidateTieBreakKey(for: lhs.candidate, determinismContext: determinismContext)
                let rhsKey = candidateTieBreakKey(for: rhs.candidate, determinismContext: determinismContext)
                if lhsKey == rhsKey {
                    return lhs.candidate.id.value < rhs.candidate.id.value
                }
                return lhsKey < rhsKey
            }
            return lhs.adjustedScore > rhs.adjustedScore
        }

        guard let selected = sortedCandidates.first else {
            fatalError("Failed to unwrap selected")
        }

        return StepDecision(
            stepId: input.stepId,
            selectedCandidate: selected.candidate.id,
            policyViolations: selected.policyResult.violations,
            trustTierRequired: input.context.trustTier
        )
    }

    /// Execute selected candidate
    private func executeCandidate(
        _ candidate: StepCandidate,
        for input: StepInput,
        determinismContext: DeterminismContext?,
        determinismObservation: inout DeterminismObservation
    ) async throws -> StepOutput {
        // Find appropriate executor for candidate action type
        guard let executor = findExecutor(for: candidate.action.type) else {
            throw MakerEngineError.noExecutorForAction(candidate.action.type)
        }

        if let determinismContext,
           let seededExecutor = executor as? DeterministicStepExecutor {
            return try await seededExecutor.execute(
                candidate.action,
                with: input,
                determinism: determinismContext
            )
        }

        if determinismContext != nil, config.enhancementDeterminismCheckEnabled {
            determinismObservation.markNotSeedable("step_executor:\(String(describing: type(of: executor)))")
        }

        return try await executor.execute(candidate.action, with: input)
    }

    /// Calculate adjusted score based on policy flags and risk
    private func calculateAdjustedScore(
        originalScore: Double,
        policyFlags: [PolicyFlag],
        riskLevel: RiskLevel
    ) -> Double {
        var adjustedScore = originalScore

        // Apply penalties for policy flags
        for flag in policyFlags {
            switch flag.severity {
            case .warning:
                adjustedScore *= 0.9
            case .error:
                adjustedScore *= 0.7
            case .critical:
                adjustedScore *= 0.1  // Heavily penalize
            case .info:
                break  // No penalty for info
            }
        }

        // Apply risk-based adjustment
        switch riskLevel {
        case .low:
            break  // No adjustment
        case .medium:
            adjustedScore *= 0.95
        case .high:
            adjustedScore *= 0.8
        case .critical:
            adjustedScore *= 0.5
        }

        return adjustedScore
    }

    /// Find executor for action type
    private func findExecutor(for actionType: ActionType) -> StepExecutor? {
        return stepExecutors.first { $0.canExecute(actionType) }
    }

    /// Record failure for loop resistance
    private func recordFailure(for stepId: StepId, reason: String) async {
        let record = FailureRecord(
            timestamp: Date(),
            reason: reason,
            fingerprint: generateFailureFingerprint(reason)
        )

        var failures = failureHistory[stepId.value, default: []]
        failures.append(record)

        // Keep only recent failures (configurable)
        let maxFailures = config.maxFailureHistory
        if failures.count > maxFailures {
            failures = Array(failures.suffix(maxFailures))
        }

        failureHistory[stepId.value] = failures

        // Check if we should trigger quarantine
        if shouldTriggerQuarantine(failures) {
            await quarantineManager.quarantineStep(
                stepId: stepId,
                reason: "Repeated failures: \(failures.count) attempts",
                duration: config.quarantineDuration
            )
        }
    }

    private func generateFailureFingerprint(_ reason: String) -> String {
        // Simple normalization
        let normalized = reason.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        // In production, use more sophisticated fingerprinting
        return normalized.blake3Hex
    }

    /// Check if quarantine should be triggered
    private func shouldTriggerQuarantine(_ failures: [FailureRecord]) -> Bool {
        guard failures.count >= config.quarantineThreshold else { return false }

        // Check if failures are similar (same fingerprint)
        let recentFailures = Array(failures.suffix(config.quarantineThreshold))
        let fingerprints = Set(recentFailures.map { $0.fingerprint })

        // If all recent failures have same fingerprint, trigger quarantine
        return fingerprints.count == 1
    }

    private func recordEnhancementReceipt(
        for input: StepInput,
        output: StepOutput,
        decision: StepDecision?,
        enhancementContext: EnhancementContext,
        resourceLimitExceeded: Bool,
        quarantineDecision: String?,
        determinismObservation: DeterminismObservation,
        startedAt: Date,
        finishedAt: Date
    ) async {
        guard config.enhancementsEnabled else { return }

        guard let outputHash = deterministicOutputHash(for: output) else { return }
        let inputHash = enhancementContext.inputHash
        let adapterIdentifiers = currentAdapterIdentifiers()
        
        // Handle optional decision safely
        let policyDecision: String?
        if let decision = decision {
             policyDecision = decision.selectedCandidate.map { "selected:\($0.value)" } ?? decision.rejectionReason
        } else {
             policyDecision = nil
        }
        
        let core = MakerReceiptCore(
            deterministicStepId: enhancementContext.deterministicStepId,
            stepId: input.stepId.value,
            sessionId: input.context.sessionId,
            workflowId: input.context.workflowId,
            inputHash: inputHash,
            outputHash: outputHash,
            adapterIdentifiers: adapterIdentifiers,
            policyDecision: policyDecision,
            quarantineDecision: quarantineDecision,
            resourceLimitExceeded: resourceLimitExceeded,
            limits: config.enhancementLimits,
            enhancementEnabled: config.enhancementsEnabled,
            enhancementCodeVersion: config.enhancementCodeVersion
        )

        let observational = MakerReceiptObservational(
            durationMs: finishedAt.timeIntervalSince(startedAt) * 1000,
            memoryUsedBytes: Int(output.metrics.memoryUsed),
            determinismNotes: determinismObservation.notes,
            determinismCheckPassed: nil
        )

        let receipt = MakerReceipt(core: core, observational: observational)

        do {
            _ = try config.enhancementReceiptPersister.persist(
                receipt: receipt,
                runId: input.context.sessionId,
                stepId: input.stepId
            )
        } catch {
            // CoreReceipt failures must not block MakerEngine execution.
        }

        if config.enhancementDeterminismCheckEnabled, !resourceLimitExceeded {
            await performDeterminismCheck(
                input: input,
                enhancementContext: enhancementContext,
                originalOutput: output,
                originalReceipt: receipt,
                determinismObservation: determinismObservation
            )
        }
    }

    /// Determinism check: double-run under the same inputs/seed and compare deterministic receipt cores.
    /// Quarantine on divergence, but never block the main step execution.
    private func performDeterminismCheck(
        input: StepInput,
        enhancementContext: EnhancementContext,
        originalOutput: StepOutput,
        originalReceipt: MakerReceipt,
        determinismObservation: DeterminismObservation
    ) async {
        var combinedObservation = determinismObservation
        let secondOutput: StepOutput
        do {
            secondOutput = try await reexecuteForDeterminism(
                input: input,
                determinismContext: enhancementContext.determinismContext,
                determinismObservation: &combinedObservation
            )
        } catch {
            await quarantineManager.quarantineStep(
                stepId: input.stepId,
                reason: "Determinism check execution failed: \(error)",
                duration: config.quarantineDuration
            )
            return
        }

        guard let secondReceipt = buildDeterminismReceipt(
            for: input,
            output: secondOutput,
            enhancementContext: enhancementContext,
            decision: nil,
            wasQuarantined: secondOutput.status == .quarantined,
            determinismObservation: combinedObservation,
            determinismCheckPassed: nil,
            resourceLimitExceeded: originalReceipt.core.resourceLimitExceeded
        ) else {
            return
        }

        guard
            let firstHash = try? MakerReceiptEncoding.hashCanonical(originalReceipt.core),
            let secondHash = try? MakerReceiptEncoding.hashCanonical(secondReceipt.core)
        else {
            return
        }

        if firstHash != secondHash || originalReceipt.core.outputHash != secondReceipt.core.outputHash {
            await quarantineManager.quarantineStep(
                stepId: input.stepId,
                reason: "Determinism check failed: receipt core or output hash mismatch",
                duration: config.quarantineDuration
            )
            let divergenceCore = MakerReceiptCore(
                deterministicStepId: secondReceipt.core.deterministicStepId,
                stepId: secondReceipt.core.stepId,
                sessionId: secondReceipt.core.sessionId,
                workflowId: secondReceipt.core.workflowId,
                inputHash: secondReceipt.core.inputHash,
                outputHash: secondReceipt.core.outputHash,
                adapterIdentifiers: secondReceipt.core.adapterIdentifiers,
                policyDecision: secondReceipt.core.policyDecision,
                quarantineDecision: "nondeterminism",
                resourceLimitExceeded: secondReceipt.core.resourceLimitExceeded,
                limits: secondReceipt.core.limits,
                enhancementEnabled: secondReceipt.core.enhancementEnabled,
                enhancementCodeVersion: secondReceipt.core.enhancementCodeVersion
            )
            let divergenceReceipt = MakerReceipt(
                core: divergenceCore,
                observational: MakerReceiptObservational(
                    durationMs: 0,
                    memoryUsedBytes: Int(secondOutput.metrics.memoryUsed),
                    determinismNotes: combinedObservation.notes,
                    determinismCheckPassed: combinedObservation.isSeedable ? false : nil
                )
            )
            _ = try? config.enhancementReceiptPersister.persist(
                receipt: divergenceReceipt,
                runId: input.context.sessionId,
                stepId: StepId("\(input.stepId.value)-determinism-check")
            )
        }
    }

    /// Re-executes a deterministic path for comparison. Ordering is kept stable; randomness should
    /// be seeded by determinismContext.seed when adapters use it (future work).
    private func reexecuteForDeterminism(
        input: StepInput,
        determinismContext: DeterminismContext,
        determinismObservation: inout DeterminismObservation
    ) async throws -> StepOutput {
        // In this phase we rely on existing deterministic ordering. Seedable adapters can later
        // consume determinismContext.seed.
        let candidates = try await generateCandidates(
            for: input,
            determinismContext: determinismContext,
            determinismObservation: &determinismObservation
        )
        
        guard let decision = try? await selectCandidate(from: try await evaluateCandidates(candidates, for: input), for: input, determinismContext: determinismContext) else {
            return StepOutput(stepId: input.stepId, stateDelta: StateDelta(), metrics: StepMetrics(duration: 0, memoryUsed: 0), status: .failed)
        }

        guard let selectedId = decision.selectedCandidate,
              let candidate = candidates.first(where: { $0.id == selectedId }) else {
            return StepOutput(
                stepId: input.stepId,
                stateDelta: StateDelta(),
                metrics: StepMetrics(duration: 0, memoryUsed: 0),
                status: .failed
            )
        }

        return try await executeCandidate(
            candidate,
            for: input,
            determinismContext: determinismContext,
            determinismObservation: &determinismObservation
        )
    }

    private func buildDeterminismReceipt(
        for input: StepInput,
        output: StepOutput,
        enhancementContext: EnhancementContext,
        decision: StepDecision?,
        wasQuarantined: Bool,
        determinismObservation: DeterminismObservation,
        determinismCheckPassed: Bool?,
        resourceLimitExceeded: Bool
    ) -> MakerReceipt? {
        let inputHash = enhancementContext.inputHash
        guard let outputHash = deterministicOutputHash(for: output) else { return nil }
        let adapterIdentifiers = currentAdapterIdentifiers()
        
        let policyDecision: String?
        if let decision = decision {
             policyDecision = decision.selectedCandidate.map { "selected:\($0.value)" } ?? decision.rejectionReason
        } else {
             policyDecision = nil
        }
        
        let quarantineDecision = wasQuarantined || output.status == .quarantined ? "quarantined" : nil

        let core = MakerReceiptCore(
            deterministicStepId: enhancementContext.deterministicStepId,
            stepId: input.stepId.value,
            sessionId: input.context.sessionId,
            workflowId: input.context.workflowId,
            inputHash: inputHash,
            outputHash: outputHash,
            adapterIdentifiers: adapterIdentifiers,
            policyDecision: policyDecision,
            quarantineDecision: quarantineDecision,
            resourceLimitExceeded: resourceLimitExceeded,
            limits: config.enhancementLimits,
            enhancementEnabled: config.enhancementsEnabled,
            enhancementCodeVersion: config.enhancementCodeVersion
        )
        
        let observational = MakerReceiptObservational(
            durationMs: output.metrics.duration * 1000,
            memoryUsedBytes: Int(output.metrics.memoryUsed),
            determinismNotes: determinismObservation.notes,
            determinismCheckPassed: determinismCheckPassed
        )

        return MakerReceipt(core: core, observational: observational)
    }

    /// Finalize and persist trace
    private func finalizeTrace(_ trace: inout StepTrace, output: StepOutput) async throws {
        trace.output = output

        // Validate trace contract
        let contract = StepTraceContract(trace)
        try StepTraceContract.validateInvariants(contract)

        // Persist through evidence recorder
        let traceData = try JSONEncoder().encode(trace)
        let traceHash = SHA256.hash(data: traceData)
        let traceHead = EvidenceHead(
            headId: trace.id.value,
            headHash: traceHash.compactMap { String(format: "%02x", $0) }.joined(),
            timestamp: Date(),
            lastActor: "MakerEngine"
        )
        try await evidenceRecorder.recordEvidence(head: traceHead, content: traceData)

        // Remove from active traces
        activeTraces.removeValue(forKey: trace.id)

        // Log to audit trail
        try await auditLog.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.custom,
            principal: "MakerEngine",
            module: "MakerEngine",
            description: "Step execution for stepId: \(trace.stepId.value)",
            metadata: [
                "stepId": trace.stepId.value,
                "workflowId": trace.workflowId,
                "sessionId": trace.sessionId,
                "status": output.status == .completed ? "completed" : "failed",
                "duration": "\(output.metrics.duration)",
                "original_event_type": "stepExecution"
            ]
        )
    }
}

private struct CandidateTieBreakCore: Codable {
    let action: CandidateAction
    let reasoning: String
    let estimatedImpact: ImpactEstimate
    let policyFlags: [PolicyFlag]
}

private struct AdapterDiffInput: Codable {
    let baseline: String
    let candidate: String
}

private struct AdapterParseInput: Codable {
    let text: String
}

private struct AdapterRegexInput: Codable {
    let pattern: String
    let content: String
}

private struct AdapterPolicyInput: Codable {
    let candidate: StepCandidate
    let context: StepContext
}

// MARK: - Supporting Types

/// Configuration for MAKER engine
public struct MakerEngineConfig: Sendable {
    public let maxCandidatesPerStep: Int
    public let maxFailureHistory: Int
    public let quarantineThreshold: Int
    public let quarantineDuration: TimeInterval
    public let enhancementsEnabled: Bool
    public let enhancementLimits: MakerResourceLimits
    public let enhancementReceiptPersister: any MakerReceiptPersisting
    public let enhancementCodeVersion: String
    public let enhancementDeterminismCheckEnabled: Bool

    public init(
        maxCandidatesPerStep: Int = 5,
        maxFailureHistory: Int = 10,
        quarantineThreshold: Int = 3,
        quarantineDuration: TimeInterval = 300,  // 5 minutes
        enhancementsEnabled: Bool = false,
        enhancementLimits: MakerResourceLimits = .default,
        enhancementReceiptPersister: any MakerReceiptPersisting = FileMakerReceiptPersister(),
        enhancementCodeVersion: String = "unknown",
        enhancementDeterminismCheckEnabled: Bool = false
    ) {
        self.maxCandidatesPerStep = maxCandidatesPerStep
        self.maxFailureHistory = maxFailureHistory
        self.quarantineThreshold = quarantineThreshold
        self.quarantineDuration = quarantineDuration
        self.enhancementsEnabled = enhancementsEnabled
        self.enhancementLimits = enhancementLimits
        self.enhancementReceiptPersister = enhancementReceiptPersister
        self.enhancementCodeVersion = enhancementCodeVersion
        self.enhancementDeterminismCheckEnabled = enhancementDeterminismCheckEnabled
    }

    public static let `default` = MakerEngineConfig()
}

/// Failure record for loop resistance
public struct FailureRecord: Sendable, Codable {
    public let timestamp: Date
    public let reason: String
    public let fingerprint: String

    public init(timestamp: Date, reason: String, fingerprint: String) {
        self.timestamp = timestamp
        self.reason = reason
        self.fingerprint = fingerprint
    }
}

/// Evaluated candidate with policy results
public struct EvaluatedCandidate: Sendable {
    public let candidate: StepCandidate
    public let adjustedScore: Double
    public let policyResult: PolicyEvaluationResult

    public init(candidate: StepCandidate, adjustedScore: Double, policyResult: PolicyEvaluationResult) {
        self.candidate = candidate
        self.adjustedScore = adjustedScore
        self.policyResult = policyResult
    }
}

/// Errors specific to MAKER engine
public enum MakerEngineError: Error, Sendable {
    case selectedCandidateNotFound
    case noExecutorForAction(ActionType)
    case quarantineRequired(String)
    case policyViolation(String)

    public var localizedDescription: String {
        switch self {
        case .selectedCandidateNotFound:
            return "Selected candidate not found in candidate list"
        case .noExecutorForAction(let action):
            return "No executor available for action type: \(action.rawValue)"
        case .quarantineRequired(let reason):
            return "Step is quarantined: \(reason)"
        case .policyViolation(let message):
            return "Policy violation: \(message)"
        }
    }
}

// MARK: - Protocol Definitions

/// Protocol for generating step candidates
public protocol CandidateGenerator: Sendable {
    func generateCandidates(for input: StepInput) async throws -> [StepCandidate]
}

/// Protocol for generating step candidates deterministically with a context seed.
public protocol DeterministicCandidateGenerator: CandidateGenerator {
    func generateCandidates(for input: StepInput, determinism: DeterminismContext) async throws -> [StepCandidate]
}

/// Protocol for executing step actions
public protocol StepExecutor: Sendable {
    func canExecute(_ actionType: ActionType) -> Bool
    func execute(_ action: CandidateAction, with input: StepInput) async throws -> StepOutput
}

/// Protocol for executing step actions deterministically with a context seed.
public protocol DeterministicStepExecutor: StepExecutor {
    func execute(_ action: CandidateAction, with input: StepInput, determinism: DeterminismContext) async throws -> StepOutput
}

/// Protocol for quarantine management
public protocol QuarantineManager: Sendable {
    func checkQuarantine(stepId: StepId, sessionId: String, trustTier: TrustTier) async -> QuarantineAction?
    func quarantineStep(stepId: StepId, reason: String, duration: TimeInterval) async
}

    // MARK: - ReasoningKernel Integration
    
    /// Simplified integration bridge for future reasoning kernel analysis
    public func connectOptimizationToReasoning(
        _ optimizedCandidates: [OptimizedCandidate],
        context: StepContext
    ) async -> [String] {
        // Simplified integration - returns analysis recommendations
        var recommendations: [String] = []
        
        for optimized in optimizedCandidates {
            let impact = optimized.optimizationMetrics.performanceImprovement
            if impact > 0.5 {
                recommendations.append("High-impact optimization detected: \(impact * 100)% improvement")
            } else if impact > 0.2 {
                recommendations.append("Moderate optimization detected: \(impact * 100)% improvement")
            } else {
                recommendations.append("Low-impact optimization detected")
            }
        }
        
        return recommendations
    }

    // MARK: - String Extension for Hashing

private extension String {
    var blake3Hex: String {
        return BLAKE3Digest.hex(of: self)
    }
}
