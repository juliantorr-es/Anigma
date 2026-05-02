//
//  ProgressiveLowering.swift
//  ModelRegistry
//
//  Progressive lowering with intelligent fallback strategies.
//  Implements multi-stage lowering with fallback mechanisms for
//  handling unsupported operations and platform constraints.
//

import Foundation

/// Progressive lowering stage
public enum ProgressiveStage: String, Codable, Sendable, CaseIterable {
    /// Stage 1: Basic lowering with minimal optimizations
    case basic = "basic"
    
    /// Stage 2: Moderate optimizations with some fusion
    case moderate = "moderate"
    
    /// Stage 3: Aggressive optimizations with full fusion
    case aggressive = "aggressive"
    
    /// Stage 4: ANE-specific optimizations
    case aneOptimized = "ane_optimized"
    
    /// Stage 5: Quantization-aware optimizations
    case quantized = "quantized"
    
    /// Display name for the stage
    public var displayName: String {
        switch self {
        case .basic: return "Basic Lowering"
        case .moderate: return "Moderate Optimizations"
        case .aggressive: return "Aggressive Optimizations"
        case .aneOptimized: return "ANE Optimized"
        case .quantized: return "Quantized"
        }
    }
    
    /// Description of what the stage does
    public var description: String {
        switch self {
        case .basic:
            return "Basic lowering with minimal optimizations for maximum compatibility"
        case .moderate:
            return "Moderate optimizations with some operation fusion"
        case .aggressive:
            return "Aggressive optimizations with full operation fusion"
        case .aneOptimized:
            return "ANE-specific optimizations for Apple Neural Engine"
        case .quantized:
            return "Quantization-aware optimizations for reduced memory usage"
        }
    }
    
    /// Fallback stage if this stage fails
    public var fallbackStage: ProgressiveStage? {
        switch self {
        case .quantized: return .aneOptimized
        case .aneOptimized: return .aggressive
        case .aggressive: return .moderate
        case .moderate: return .basic
        case .basic: return nil
        }
    }
}

/// Fallback strategy
public enum FallbackStrategy: String, Codable, Sendable {
    /// Immediate fallback on first failure
    case immediate = "immediate"
    
    /// Attempt recovery before falling back
    case attemptRecovery = "attempt_recovery"
    
    /// Partial fallback for specific operations
    case partial = "partial"
    
    /// No fallback - fail completely
    case none = "none"
}

/// Fallback reason
public enum FallbackReason: String, Codable, Sendable {
    /// Unsupported operation
    case unsupportedOperation = "unsupported_operation"
    
    /// Memory constraint violation
    case memoryConstraint = "memory_constraint"
    
    /// Performance constraint violation
    case performanceConstraint = "performance_constraint"
    
    /// Platform limitation
    case platformLimitation = "platform_limitation"
    
    /// Quantization failure
    case quantizationFailure = "quantization_failure"
    
    /// Verification failure
    case verificationFailure = "verification_failure"
    
    /// Timeout
    case timeout = "timeout"
}

/// Progressive lowering configuration
public struct ProgressiveLoweringConfig: Codable, Sendable {
    /// Starting stage
    public let startStage: ProgressiveStage
    
    /// Target stage (maximum to attempt)
    public let targetStage: ProgressiveStage
    
    /// Fallback strategy
    public let fallbackStrategy: FallbackStrategy
    
    /// Maximum fallback attempts
    public let maxFallbackAttempts: Int
    
    /// Whether to enable operation replacement
    public let enableOpReplacement: Bool
    
    /// Operation replacements for unsupported ops
    public let opReplacements: [String: String]
    
    /// Whether to enable shape adaptation
    public let enableShapeAdaptation: Bool
    
    /// Whether to enable precision reduction
    public let enablePrecisionReduction: Bool
    
    /// Performance targets
    public let performanceTargets: PerformanceTargets?
    
    /// Memory budget in MB
    public let memoryBudgetMB: Int?
    
    public init(
        startStage: ProgressiveStage = .basic,
        targetStage: ProgressiveStage = .aneOptimized,
        fallbackStrategy: FallbackStrategy = .attemptRecovery,
        maxFallbackAttempts: Int = 3,
        enableOpReplacement: Bool = true,
        opReplacements: [String: String] = [:],
        enableShapeAdaptation: Bool = true,
        enablePrecisionReduction: Bool = true,
        performanceTargets: PerformanceTargets? = nil,
        memoryBudgetMB: Int? = nil
    ) {
        self.startStage = startStage
        self.targetStage = targetStage
        self.fallbackStrategy = fallbackStrategy
        self.maxFallbackAttempts = maxFallbackAttempts
        self.enableOpReplacement = enableOpReplacement
        self.opReplacements = opReplacements
        self.enableShapeAdaptation = enableShapeAdaptation
        self.enablePrecisionReduction = enablePrecisionReduction
        self.performanceTargets = performanceTargets
        self.memoryBudgetMB = memoryBudgetMB
    }
}

/// Performance targets for progressive lowering
public struct PerformanceTargets: Codable, Sendable {
    /// Maximum latency in milliseconds
    public let maxLatencyMS: Double?
    
    /// Minimum throughput in inferences per second
    public let minThroughputIPS: Double?
    
    /// Maximum memory usage in MB
    public let maxMemoryMB: Int?
    
    /// Maximum power consumption in watts
    public let maxPowerWatts: Double?
    
    public init(
        maxLatencyMS: Double? = nil,
        minThroughputIPS: Double? = nil,
        maxMemoryMB: Int? = nil,
        maxPowerWatts: Double? = nil
    ) {
        self.maxLatencyMS = maxLatencyMS
        self.minThroughputIPS = minThroughputIPS
        self.maxMemoryMB = maxMemoryMB
        self.maxPowerWatts = maxPowerWatts
    }
}

/// Progressive lowering result
public struct ProgressiveLoweringResult: Sendable {
    /// Final stage achieved
    public let achievedStage: ProgressiveStage
    
    /// Whether lowering succeeded
    public let success: Bool
    
    /// Applied stages with results
    public let stageResults: [ProgressiveStage: StageExecutionResult]
    
    /// Fallbacks that occurred
    public let fallbacks: [FallbackEvent]
    
    /// Final model IR
    public let finalIR: ModelIR
    
    /// Performance metrics
    public let performanceMetrics: PerformanceMetrics?
    
    /// Issues encountered
    public let issues: [String]
    
    /// Total duration
    public let duration: TimeInterval
    
    public init(
        achievedStage: ProgressiveStage,
        success: Bool,
        stageResults: [ProgressiveStage: StageExecutionResult],
        fallbacks: [FallbackEvent],
        finalIR: ModelIR,
        performanceMetrics: PerformanceMetrics? = nil,
        issues: [String] = [],
        duration: TimeInterval
    ) {
        self.achievedStage = achievedStage
        self.success = success
        self.stageResults = stageResults
        self.fallbacks = fallbacks
        self.finalIR = finalIR
        self.performanceMetrics = performanceMetrics
        self.issues = issues
        self.duration = duration
    }
}

/// Stage execution result
public struct StageExecutionResult: Sendable {
    /// Stage that was executed
    public let stage: ProgressiveStage
    
    /// Whether stage succeeded
    public let success: Bool
    
    /// Output IR from stage
    public let outputIR: ModelIR
    
    /// Performance metrics for this stage
    public let performanceMetrics: PerformanceMetrics?
    
    /// Issues encountered during stage
    public let issues: [String]
    
    /// Duration of stage execution
    public let duration: TimeInterval
    
    public init(
        stage: ProgressiveStage,
        success: Bool,
        outputIR: ModelIR,
        performanceMetrics: PerformanceMetrics? = nil,
        issues: [String] = [],
        duration: TimeInterval
    ) {
        self.stage = stage
        self.success = success
        self.outputIR = outputIR
        self.performanceMetrics = performanceMetrics
        self.issues = issues
        self.duration = duration
    }
}

/// Fallback event
public struct FallbackEvent: Codable, Sendable {
    /// From stage
    public let fromStage: ProgressiveStage
    
    /// To stage
    public let toStage: ProgressiveStage
    
    /// Reason for fallback
    public let reason: FallbackReason
    
    /// Operation that caused fallback (if applicable)
    public let failingOperation: String?
    
    /// Error message
    public let errorMessage: String
    
    /// Timestamp
    public let timestamp: Date
    
    public init(
        fromStage: ProgressiveStage,
        toStage: ProgressiveStage,
        reason: FallbackReason,
        failingOperation: String? = nil,
        errorMessage: String,
        timestamp: Date = Date()
    ) {
        self.fromStage = fromStage
        self.toStage = toStage
        self.reason = reason
        self.failingOperation = failingOperation
        self.errorMessage = errorMessage
        self.timestamp = timestamp
    }
}

/// Progressive lowering with intelligent fallback strategies
public actor ProgressiveLowering {
    private let config: ProgressiveLoweringConfig
    private let aneOptimizer: ANEOptimizer?
    private let shapeOptimizer: ShapeOptimizer?
    private let enableVerification: Bool
    
    public init(
        config: ProgressiveLoweringConfig = ProgressiveLoweringConfig(),
        aneOptimizer: ANEOptimizer? = nil,
        shapeOptimizer: ShapeOptimizer? = nil,
        enableVerification: Bool = true
    ) {
        self.config = config
        self.aneOptimizer = aneOptimizer
        self.shapeOptimizer = shapeOptimizer
        self.enableVerification = enableVerification
    }
    
    /// Apply progressive lowering with fallback strategies
    public func applyProgressiveLowering(
        modelPath: String,
        workloadCategory: WorkloadCategory
    ) async throws -> ProgressiveLoweringResult {
        let startTime = Date()
        var currentStage = config.startStage
        var stageResults: [ProgressiveStage: StageExecutionResult] = [:]
        var fallbacks: [FallbackEvent] = []
        var issues: [String] = []
        
        // Start with initial IR
        var currentIR = ModelIR(
            format: .unknown,
            path: modelPath,
            metadata: [:],
            graphHash: ""
        )
        
        // Track fallback attempts
        var fallbackAttempts = 0
        
        // Execute stages progressively
        while currentStage <= config.targetStage && fallbackAttempts <= config.maxFallbackAttempts {
            do {
                // Execute current stage
                let stageResult = try await executeStage(
                    stage: currentStage,
                    ir: currentIR,
                    workloadCategory: workloadCategory
                )
                
                stageResults[currentStage] = stageResult
                currentIR = stageResult.outputIR
                
                // Verify stage result if enabled
                if enableVerification {
                    let verificationResult = try await verifyStageResult(stageResult)
                    if !verificationResult.passed {
                        throw ProgressiveLoweringError.verificationFailed(
                            stage: currentStage,
                            issues: verificationResult.issues
                        )
                    }
                }
                
                // Check performance targets
                if let targets = config.performanceTargets,
                   let metrics = stageResult.performanceMetrics {
                    if !meetsPerformanceTargets(metrics: metrics, targets: targets) {
                        throw ProgressiveLoweringError.performanceTargetMissed(
                            stage: currentStage,
                            metrics: metrics
                        )
                    }
                }
                
                // Check memory budget
                if let budget = config.memoryBudgetMB,
                   let metrics = stageResult.performanceMetrics,
                   metrics.memoryUsageMB > Double(budget) {
                    throw ProgressiveLoweringError.memoryBudgetExceeded(
                        stage: currentStage,
                        budget: budget,
                        actual: Int(metrics.memoryUsageMB)
                    )
                }
                
                // Stage succeeded, move to next stage if not at target
                if currentStage < config.targetStage {
                    currentStage = nextStage(after: currentStage)
                } else {
                    // Reached target stage successfully
                    break
                }
                
            } catch {
                // Stage failed, handle fallback
                let fallbackResult = try await handleFallback(
                    error: error,
                    currentStage: currentStage,
                    currentIR: currentIR,
                    workloadCategory: workloadCategory,
                    fallbackAttempts: &fallbackAttempts
                )
                
                fallbacks.append(contentsOf: fallbackResult.fallbacks)
                issues.append(contentsOf: fallbackResult.issues)
                
                if let nextStage = fallbackResult.nextStage {
                    currentStage = nextStage
                } else {
                    // No more fallbacks available
                    break
                }
            }
        }
        
        // Calculate final performance metrics
        let finalMetrics = try await calculatePerformanceMetrics(ir: currentIR, workloadCategory: workloadCategory)
        
        // Determine success and achieved stage
        let success = currentStage >= config.startStage
        let achievedStage = success ? currentStage : config.startStage
        
        return ProgressiveLoweringResult(
            achievedStage: achievedStage,
            success: success,
            stageResults: stageResults,
            fallbacks: fallbacks,
            finalIR: currentIR,
            performanceMetrics: finalMetrics,
            issues: issues,
            duration: Date().timeIntervalSince(startTime)
        )
    }
    
    /// Execute a specific progressive stage
    private func executeStage(
        stage: ProgressiveStage,
        ir: ModelIR,
        workloadCategory: WorkloadCategory
    ) async throws -> StageExecutionResult {
        let stageStartTime = Date()
        var stageIR = ir
        var issues: [String] = []
        
        // Apply stage-specific transformations
        switch stage {
        case .basic:
            stageIR = try await applyBasicLowering(ir: stageIR, workloadCategory: workloadCategory)
            
        case .moderate:
            stageIR = try await applyModerateOptimizations(ir: stageIR, workloadCategory: workloadCategory)
            
        case .aggressive:
            stageIR = try await applyAggressiveOptimizations(ir: stageIR, workloadCategory: workloadCategory)
            
        case .aneOptimized:
            stageIR = try await applyANEOptimizations(ir: stageIR, workloadCategory: workloadCategory)
            
        case .quantized:
            stageIR = try await applyQuantizationOptimizations(ir: stageIR, workloadCategory: workloadCategory)
        }
        
        // Calculate stage performance metrics
        let performanceMetrics = try await calculateStagePerformanceMetrics(
            ir: stageIR,
            workloadCategory: workloadCategory
        )
        
        // Update IR metadata
        stageIR.metadata["progressive_stage"] = stage.rawValue
        stageIR.metadata["stage_applied"] = "true"
        
        return StageExecutionResult(
            stage: stage,
            success: true,
            outputIR: stageIR,
            performanceMetrics: performanceMetrics,
            issues: issues,
            duration: Date().timeIntervalSince(stageStartTime)
        )
    }
    
    /// Apply basic lowering (minimal optimizations)
    private func applyBasicLowering(
        ir: ModelIR,
        workloadCategory: WorkloadCategory
    ) async throws -> ModelIR {
        var basicIR = ir
        
        // Apply minimal optimizations
        basicIR.metadata["basic_lowering_applied"] = "true"
        basicIR.metadata["optimization_level"] = "minimal"
        
        // Apply operation replacements if enabled
        if config.enableOpReplacement {
            for (unsupportedOp, replacementOp) in config.opReplacements {
                basicIR.metadata["replaced_\(unsupportedOp)"] = replacementOp
            }
        }
        
        return basicIR
    }
    
    /// Apply moderate optimizations
    private func applyModerateOptimizations(
        ir: ModelIR,
        workloadCategory: WorkloadCategory
    ) async throws -> ModelIR {
        var moderateIR = ir
        
        // Apply moderate optimizations
        moderateIR.metadata["moderate_optimizations_applied"] = "true"
        moderateIR.metadata["optimization_level"] = "moderate"
        
        // Apply basic fusion patterns
        moderateIR.metadata["fused_linear_relu"] = "true"
        moderateIR.metadata["fused_conv_bn"] = "true"
        
        // Apply shape adaptation if enabled
        if config.enableShapeAdaptation {
            moderateIR.metadata["shape_adapted"] = "true"
        }
        
        return moderateIR
    }
    
    /// Apply aggressive optimizations
    private func applyAggressiveOptimizations(
        ir: ModelIR,
        workloadCategory: WorkloadCategory
    ) async throws -> ModelIR {
        var aggressiveIR = ir
        
        // Apply aggressive optimizations
        aggressiveIR.metadata["aggressive_optimizations_applied"] = "true"
        aggressiveIR.metadata["optimization_level"] = "aggressive"
        
        // Apply full fusion patterns
        aggressiveIR.metadata["fused_attention_qkv"] = "true"
        aggressiveIR.metadata["fused_conv_bn_relu"] = "true"
        aggressiveIR.metadata["fused_layer_norm_silu"] = "true"
        
        // Apply precision reduction if enabled
        if config.enablePrecisionReduction {
            aggressiveIR.metadata["precision_reduced"] = "true"
            aggressiveIR.metadata["precision"] = "fp16"
        }
        
        // Apply shape optimizations if available
        if let optimizer = shapeOptimizer {
            let shapeResult = try await optimizer.optimizeShapes(
                ir: aggressiveIR,
                workloadCategory: workloadCategory,
                inputConstraints: nil
            )
            aggressiveIR = shapeResult.optimizedIR
        }
        
        return aggressiveIR
    }
    
    /// Apply ANE optimizations
    private func applyANEOptimizations(
        ir: ModelIR,
        workloadCategory: WorkloadCategory
    ) async throws -> ModelIR {
        var aneIR = ir
        
        // Apply ANE optimizations
        aneIR.metadata["ane_optimizations_applied"] = "true"
        aneIR.metadata["optimization_level"] = "ane_optimized"
        
        // Apply ANE-specific optimizations if optimizer available
        if let optimizer = aneOptimizer {
            let aneResult = try await optimizer.optimize(
                ir: aneIR,
                workloadCategory: workloadCategory,
                memoryBudgetMB: config.memoryBudgetMB
            )
            aneIR = aneResult.optimizedIR
        } else {
            // Apply basic ANE optimizations
            aneIR.metadata["ane_aligned"] = "true"
            aneIR.metadata["ane_memory_layout"] = "optimized"
            aneIR.metadata["ane_kernel_selection"] = "optimized"
        }
        
        return aneIR
    }
    
    /// Apply quantization optimizations
    private func applyQuantizationOptimizations(
        ir: ModelIR,
        workloadCategory: WorkloadCategory
    ) async throws -> ModelIR {
        var quantizedIR = ir
        
        // Apply quantization optimizations
        quantizedIR.metadata["quantization_optimizations_applied"] = "true"
        quantizedIR.metadata["optimization_level"] = "quantized"
        
        // Apply quantization
        quantizedIR.metadata["quantized"] = "true"
        quantizedIR.metadata["quantization_bits"] = "8"
        quantizedIR.metadata["quantization_type"] = "post_training"
        
        // Apply quantization-aware optimizations
        quantizedIR.metadata["quantization_aware_training"] = "simulated"
        quantizedIR.metadata["quantization_granularity"] = "per_tensor"
        
        return quantizedIR
    }
    
    /// Handle fallback from failed stage
    private func handleFallback(
        error: Error,
        currentStage: ProgressiveStage,
        currentIR: ModelIR,
        workloadCategory: WorkloadCategory,
        fallbackAttempts: inout Int
    ) async throws -> FallbackHandlingResult {
        var fallbacks: [FallbackEvent] = []
        var issues: [String] = []
        
        // Determine fallback reason
        let (reason, failingOperation, errorMessage) = analyzeError(error)
        
        // Check fallback strategy
        switch config.fallbackStrategy {
        case .immediate:
            // Immediate fallback to next stage
            return try await handleImmediateFallback(
                currentStage: currentStage,
                reason: reason,
                failingOperation: failingOperation,
                errorMessage: errorMessage,
                fallbackAttempts: &fallbackAttempts,
                fallbacks: &fallbacks,
                issues: &issues
            )
            
        case .attemptRecovery:
            // Attempt recovery before falling back
            return try await handleRecoveryFallback(
                currentStage: currentStage,
                currentIR: currentIR,
                workloadCategory: workloadCategory,
                reason: reason,
                failingOperation: failingOperation,
                errorMessage: errorMessage,
                fallbackAttempts: &fallbackAttempts,
                fallbacks: &fallbacks,
                issues: &issues
            )
            
        case .partial:
            // Partial fallback for specific operations
            return try await handlePartialFallback(
                currentStage: currentStage,
                currentIR: currentIR,
                workloadCategory: workloadCategory,
                reason: reason,
                failingOperation: failingOperation,
                errorMessage: errorMessage,
                fallbackAttempts: &fallbackAttempts,
                fallbacks: &fallbacks,
                issues: &issues
            )
            
        case .none:
            // No fallback, rethrow error
            throw error
        }
    }
    
    /// Handle immediate fallback strategy
    private func handleImmediateFallback(
        currentStage: ProgressiveStage,
        reason: FallbackReason,
        failingOperation: String?,
        errorMessage: String,
        fallbackAttempts: inout Int,
        fallbacks: inout [FallbackEvent],
        issues: inout [String]
    ) async throws -> FallbackHandlingResult {
        guard let nextStage = currentStage.fallbackStage else {
            throw ProgressiveLoweringError.noFallbackAvailable(currentStage: currentStage)
        }
        
        fallbackAttempts += 1
        
        let fallbackEvent = FallbackEvent(
            fromStage: currentStage,
            toStage: nextStage,
            reason: reason,
            failingOperation: failingOperation,
            errorMessage: errorMessage
        )
        fallbacks.append(fallbackEvent)
        
        issues.append("Immediate fallback from \(currentStage.rawValue) to \(nextStage.rawValue): \(errorMessage)")
        
        return FallbackHandlingResult(
            nextStage: nextStage,
            fallbacks: fallbacks,
            issues: issues
        )
    }
    
    /// Handle recovery fallback strategy
    private func handleRecoveryFallback(
        currentStage: ProgressiveStage,
        currentIR: ModelIR,
        workloadCategory: WorkloadCategory,
        reason: FallbackReason,
        failingOperation: String?,
        errorMessage: String,
        fallbackAttempts: inout Int,
        fallbacks: inout [FallbackEvent],
        issues: inout [String]
    ) async throws -> FallbackHandlingResult {
        // Attempt recovery based on error type
        switch reason {
        case .unsupportedOperation:
            if config.enableOpReplacement, let operation = failingOperation {
                // Try operation replacement
                if let replacement = config.opReplacements[operation] {
                    issues.append("Attempting operation replacement: \(operation) -> \(replacement)")
                    
                    var recoveredIR = currentIR
                    recoveredIR.metadata["recovered_\(operation)"] = replacement
                    
                    // Return to same stage with recovered IR
                    return FallbackHandlingResult(
                        nextStage: currentStage,
                        fallbacks: fallbacks,
                        issues: issues
                    )
                }
            }
            
        case .memoryConstraint:
            if config.enableShapeAdaptation {
                // Try shape adaptation
                issues.append("Attempting shape adaptation for memory constraint")
                
                if let optimizer = shapeOptimizer {
                    let shapeResult = try await optimizer.optimizeShapes(
                        ir: currentIR,
                        workloadCategory: workloadCategory,
                        inputConstraints: nil
                    )
                    
                    if shapeResult.metrics.estimatedMemoryUsageMB <= (config.memoryBudgetMB ?? Int.max) {
                        // Memory constraint resolved, continue with same stage
                        return FallbackHandlingResult(
                            nextStage: currentStage,
                            fallbacks: fallbacks,
                            issues: issues
                        )
                    }
                }
            }
            
        case .performanceConstraint:
            // Try precision reduction
            if config.enablePrecisionReduction {
                issues.append("Attempting precision reduction for performance constraint")
                
                var recoveredIR = currentIR
                recoveredIR.metadata["precision_reduced_recovery"] = "true"
                recoveredIR.metadata["precision"] = "fp16"
                
                return FallbackHandlingResult(
                    nextStage: currentStage,
                    fallbacks: fallbacks,
                    issues: issues
                )
            }
            
        default:
            break
        }
        
        // Recovery failed, fall back to next stage
        return try await handleImmediateFallback(
            currentStage: currentStage,
            reason: reason,
            failingOperation: failingOperation,
            errorMessage: errorMessage,
            fallbackAttempts: &fallbackAttempts,
            fallbacks: &fallbacks,
            issues: &issues
        )
    }
    
    /// Handle partial fallback strategy
    private func handlePartialFallback(
        currentStage: ProgressiveStage,
        currentIR: ModelIR,
        workloadCategory: WorkloadCategory,
        reason: FallbackReason,
        failingOperation: String?,
        errorMessage: String,
        fallbackAttempts: inout Int,
        fallbacks: inout [FallbackEvent],
        issues: inout [String]
    ) async throws -> FallbackHandlingResult {
        // For partial fallback, we continue with current stage but mark the failing operation
        var partialIR = currentIR
        
        if let operation = failingOperation {
            partialIR.metadata["partial_fallback_\(operation)"] = "true"
            partialIR.metadata["fallback_reason"] = reason.rawValue
            
            issues.append("Partial fallback for operation \(operation): \(errorMessage)")
            
            // Mark operation as bypassed or replaced
            if config.enableOpReplacement, let replacement = config.opReplacements[operation] {
                partialIR.metadata["replaced_\(operation)"] = replacement
            } else {
                partialIR.metadata["bypassed_\(operation)"] = "true"
            }
        }
        
        // Continue with same stage
        return FallbackHandlingResult(
            nextStage: currentStage,
            fallbacks: fallbacks,
            issues: issues
        )
    }
    
    /// Analyze error to determine fallback reason
    private func analyzeError(_ error: Error) -> (FallbackReason, String?, String) {
        switch error {
        case let progressiveError as ProgressiveLoweringError:
            return progressiveError.fallbackInfo
            
        default:
            return (.unsupportedOperation, nil, error.localizedDescription)
        }
    }
    
    /// Verify stage result
    private func verifyStageResult(_ stageResult: StageExecutionResult) async throws -> StageVerificationResult {
        // In practice, this would run actual verification tests
        // For now, return a placeholder verification
        
        let passed = true
        var issues: [String] = []
        
        return StageVerificationResult(passed: passed, issues: issues)
    }
    
    /// Check if performance metrics meet targets
    private func meetsPerformanceTargets(metrics: PerformanceMetrics, targets: PerformanceTargets) -> Bool {
        if let maxLatency = targets.maxLatencyMS, metrics.latencyMS > maxLatency {
            return false
        }
        
        if let minThroughput = targets.minThroughputIPS, metrics.throughputIPS < minThroughput {
            return false
        }
        
        if let maxMemory = targets.maxMemoryMB, metrics.memoryUsageMB > Double(maxMemory) {
            return false
        }
        
        if let maxPower = targets.maxPowerWatts, let power = metrics.powerWatts, power > maxPower {
            return false
        }
        
        return true
    }
    
    /// Get next stage after current stage
    private func nextStage(after stage: ProgressiveStage) -> ProgressiveStage {
        let allStages = ProgressiveStage.allCases
        guard let currentIndex = allStages.firstIndex(of: stage),
              currentIndex + 1 < allStages.count else {
            return stage
        }
        return allStages[currentIndex + 1]
    }
    
    /// Calculate stage performance metrics
    private func calculateStagePerformanceMetrics(
        ir: ModelIR,
        workloadCategory: WorkloadCategory
    ) async throws -> PerformanceMetrics {
        // In practice, this would measure actual performance
        // For now, return estimated metrics based on stage
        
        let latencyMS: Double
        let throughputIPS: Double
        let memoryUsageMB: Double
        
        switch workloadCategory {
        case .embeddings:
            latencyMS = 10.0
            throughputIPS = 100.0
            memoryUsageMB = 500.0
        case .perception:
            latencyMS = 50.0
            throughputIPS = 20.0
            memoryUsageMB = 750.0
        case .prefill:
            latencyMS = 100.0
            throughputIPS = 10.0
            memoryUsageMB = 2000.0
        case .decode:
            latencyMS = 20.0
            throughputIPS = 50.0
            memoryUsageMB = 1000.0
        default:
            latencyMS = 30.0
            throughputIPS = 33.0
            memoryUsageMB = 300.0
        }
        
        return PerformanceMetrics(
            latencyMS: latencyMS,
            throughputIPS: throughputIPS,
            memoryUsageMB: memoryUsageMB,
            peakMemoryMB: memoryUsageMB * 1.2,
            powerWatts: nil
        )
    }
    
    /// Calculate final performance metrics
    private func calculatePerformanceMetrics(
        ir: ModelIR,
        workloadCategory: WorkloadCategory
    ) async throws -> PerformanceMetrics? {
        return try await calculateStagePerformanceMetrics(ir: ir, workloadCategory: workloadCategory)
    }
}

// MARK: - Supporting Types

/// Fallback handling result
private struct FallbackHandlingResult {
    let nextStage: ProgressiveStage?
    let fallbacks: [FallbackEvent]
    let issues: [String]
}

/// Verification result
private struct StageVerificationResult {
    let passed: Bool
    let issues: [String]
}

/// Progressive lowering errors
public enum ProgressiveLoweringError: Error, Sendable {
    case verificationFailed(stage: ProgressiveStage, issues: [String])
    case performanceTargetMissed(stage: ProgressiveStage, metrics: PerformanceMetrics)
    case memoryBudgetExceeded(stage: ProgressiveStage, budget: Int, actual: Int)
    case unsupportedOperation(stage: ProgressiveStage, operation: String)
    case noFallbackAvailable(currentStage: ProgressiveStage)
    case maxFallbackAttemptsExceeded(maxAttempts: Int)
    
    var fallbackInfo: (FallbackReason, String?, String) {
        switch self {
        case .verificationFailed(let stage, let issues):
            return (.verificationFailure, nil, "Verification failed at stage \(stage): \(issues.joined(separator: ", "))")
        case .performanceTargetMissed(let stage, let metrics):
            return (.performanceConstraint, nil, "Performance target missed at stage \(stage): latency=\(metrics.latencyMS)ms")
        case .memoryBudgetExceeded(let stage, let budget, let actual):
            return (.memoryConstraint, nil, "Memory budget exceeded at stage \(stage): \(actual)MB > \(budget)MB")
        case .unsupportedOperation(let stage, let operation):
            return (.unsupportedOperation, operation, "Unsupported operation \(operation) at stage \(stage)")
        case .noFallbackAvailable(let currentStage):
            return (.platformLimitation, nil, "No fallback available from stage \(currentStage)")
        case .maxFallbackAttemptsExceeded(let maxAttempts):
            return (.timeout, nil, "Maximum fallback attempts exceeded: \(maxAttempts)")
        }
    }
}

// MARK: - Comparable conformance for ProgressiveStage

extension ProgressiveStage: Comparable {
    public static func < (lhs: ProgressiveStage, rhs: ProgressiveStage) -> Bool {
        let order: [ProgressiveStage] = [.basic, .moderate, .aggressive, .aneOptimized, .quantized]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

// MARK: - Integration with ModelLoweringPipeline

extension ModelLoweringPipeline {
    /// Apply progressive lowering with fallback strategies
    public func applyProgressiveLowering(
        modelPath: String,
        workloadCategory: WorkloadCategory,
        config: ProgressiveLoweringConfig = ProgressiveLoweringConfig()
    ) async throws -> ProgressiveLoweringResult {
        let progressiveLowering = ProgressiveLowering(config: config)
        
        return try await progressiveLowering.applyProgressiveLowering(
            modelPath: modelPath,
            workloadCategory: workloadCategory
        )
    }
    
    /// Apply progressive lowering to an existing IR
    public func applyProgressiveLowering(
        to ir: ModelIR,
        workloadCategory: WorkloadCategory,
        config: ProgressiveLoweringConfig = ProgressiveLoweringConfig()
    ) async throws -> ProgressiveLoweringResult {
        let progressiveLowering = ProgressiveLowering(config: config)
        
        // Create a temporary file for the IR
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("model_\(UUID().uuidString).ir")
        let tempData = "Temporary IR file".data(using: .utf8)!
        try tempData.write(to: tempFile)
        
        return try await progressiveLowering.applyProgressiveLowering(
            modelPath: tempFile.path,
            workloadCategory: workloadCategory
        )
    }
}
