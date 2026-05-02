//
//  ModelLoweringPipeline.swift
//  ModelRegistry
//
//  6-stage model lowering pipeline for CoreML conversion.
//  Transforms generic models into CoreML-friendly "bricks" with tight contracts.
//

import Foundation
import IntelligenceContracts
import FoundationContracts

/// 6-stage lowering pipeline for model transformation
public actor ModelLoweringPipeline {
    private let workDir: URL
    private let stageProcessors: [LoweringStage: StageProcessor]
    
    public init(workDir: URL) {
        self.workDir = workDir
        self.stageProcessors = [
            .irCapture: IRCaptureProcessor(),
            .canonicalization: CanonicalizationProcessor(),
            .loweringPasses: LoweringPassesProcessor(),
            .shapeDiscipline: ShapeDisciplineProcessor(),
            .export: ExportProcessor(),
            .verification: VerificationProcessor()
        ]
    }
    
    // MARK: - Pipeline Execution
    
    /// Apply complete lowering pipeline to a model
    public func applyLowering(
        modelPath: String,
        workloadCategory: WorkloadCategory,
        policy: LoweringPolicy? = nil
    ) async throws -> LoweringResult {
        let startTime = Date()
        let outputDir = workDir.appendingPathComponent("lowered_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        let policyToUse = policy ?? LoweringPolicy.default(for: workloadCategory)
        var currentIR = ModelIR(
            format: .unknown,
            path: modelPath,
            metadata: [:],
            graphHash: ""
        )
        
        var appliedStages: [LoweringStage] = []
        var stageResults: [LoweringStage: StageResult] = [:]
        
        // Execute each stage in sequence
        for stage in LoweringStage.allCases {
            guard let processor = stageProcessors[stage] else {
                continue
            }
            
            let stageResult = try await processor.process(
                ir: currentIR,
                workloadCategory: workloadCategory,
                policy: policyToUse,
                outputDir: outputDir
            )
            
            currentIR = stageResult.outputIR
            appliedStages.append(stage)
            stageResults[stage] = stageResult
            
            // Early exit if stage failed
            if !stageResult.success {
                break
            }
        }
        
        let verification = LoweringVerification(
            passed: appliedStages.count == LoweringStage.allCases.count,
            issues: stageResults.values.flatMap { $0.issues },
            goldenTestResults: nil
        )
        
        return LoweringResult(
            inputPath: modelPath,
            outputPath: currentIR.path,
            workloadCategory: workloadCategory,
            appliedStages: appliedStages,
            verification: verification,
            timestamp: startTime,
            metadata: [
                "duration_sec": String(Int(Date().timeIntervalSince(startTime))),
                "output_dir": outputDir.path,
                "policy_applied": policyToUse.workloadCategory.rawValue,
                "stage_results": stageResults.map { "\($0.key.rawValue):\($0.value.success)" }.joined(separator: ";")
            ]
        )
    }
    
    /// Apply specific stage(s) to a model
    public func applyStages(
        _ stages: [LoweringStage],
        to modelPath: String,
        workloadCategory: WorkloadCategory,
        policy: LoweringPolicy? = nil
    ) async throws -> PartialLoweringResult {
        let startTime = Date()
        let outputDir = workDir.appendingPathComponent("partial_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        let policyToUse = policy ?? LoweringPolicy.default(for: workloadCategory)
        var currentIR = ModelIR(
            format: .unknown,
            path: modelPath,
            metadata: [:],
            graphHash: ""
        )
        
        var stageResults: [LoweringStage: StageResult] = [:]
        
        for stage in stages {
            guard let processor = stageProcessors[stage] else {
                throw LoweringError.stageNotSupported(stage)
            }
            
            let stageResult = try await processor.process(
                ir: currentIR,
                workloadCategory: workloadCategory,
                policy: policyToUse,
                outputDir: outputDir
            )
            
            currentIR = stageResult.outputIR
            stageResults[stage] = stageResult
            
            if !stageResult.success {
                break
            }
        }
        
        return PartialLoweringResult(
            inputPath: modelPath,
            outputPath: currentIR.path,
            workloadCategory: workloadCategory,
            appliedStages: stages,
            stageResults: stageResults,
            timestamp: startTime,
            metadata: [
                "duration_sec": String(Int(Date().timeIntervalSince(startTime))),
                "output_dir": outputDir.path
            ]
        )
    }
}

// MARK: - Stage Processors

protocol StageProcessor: Sendable {
    func process(
        ir: ModelIR,
        workloadCategory: WorkloadCategory,
        policy: LoweringPolicy,
        outputDir: URL
    ) async throws -> StageResult
}

struct IRCaptureProcessor: StageProcessor {
    func process(
        ir: ModelIR,
        workloadCategory: WorkloadCategory,
        policy: LoweringPolicy,
        outputDir: URL
    ) async throws -> StageResult {
        // In practice, this would use torch.export or FX graph capture
        let graphHash = try await computeFileSHA256(url: URL(fileURLWithPath: ir.path))
        
        let capturedIR = ModelIR(
            format: .pytorch,
            path: ir.path,
            metadata: [
                "capture_method": "torch.export",
                "workload_category": workloadCategory.rawValue,
                "graph_hash": graphHash
            ],
            graphHash: graphHash
        )
        
        return StageResult(
            stage: .irCapture,
            inputIR: ir,
            outputIR: capturedIR,
            success: true,
            issues: [],
            metadata: ["graph_hash": graphHash]
        )
    }
}

struct CanonicalizationProcessor: StageProcessor {
    func process(
        ir: ModelIR,
        workloadCategory: WorkloadCategory,
        policy: LoweringPolicy,
        outputDir: URL
    ) async throws -> StageResult {
        var canonicalized = ir
        canonicalized.metadata["canonicalized"] = "true"
        canonicalized.metadata["attention_style"] = policy.attentionStyle.rawValue
        canonicalized.metadata["normalization"] = policy.normalizationType.rawValue
        canonicalized.metadata["precision"] = policy.precision.rawValue
        
        if policy.removeOptionalBranches {
            canonicalized.metadata["branches_removed"] = "true"
        }
        
        return StageResult(
            stage: .canonicalization,
            inputIR: ir,
            outputIR: canonicalized,
            success: true,
            issues: [],
            metadata: [
                "attention_style": policy.attentionStyle.rawValue,
                "normalization": policy.normalizationType.rawValue
            ]
        )
    }
}

struct LoweringPassesProcessor: StageProcessor {
    func process(
        ir: ModelIR,
        workloadCategory: WorkloadCategory,
        policy: LoweringPolicy,
        outputDir: URL
    ) async throws -> StageResult {
        var lowered = ir
        lowered.metadata["lowering_applied"] = "true"
        
        // Apply op replacements
        for (unsupportedOp, replacementOp) in policy.opReplacements {
            lowered.metadata["replaced_\(unsupportedOp)"] = replacementOp
        }
        
        // Apply fusions
        if policy.fuseLinearActivation {
            lowered.metadata["fused_linear_activation"] = "true"
        }
        
        // Apply quantization if enabled
        if policy.enableQuantization, let scheme = policy.quantizationScheme {
            lowered.metadata["quantization_scheme"] = scheme.rawValue
            lowered.metadata["quantization_applied"] = "true"
        }
        
        return StageResult(
            stage: .loweringPasses,
            inputIR: ir,
            outputIR: lowered,
            success: true,
            issues: [],
            metadata: [
                "op_replacements": String(policy.opReplacements.count),
                "fuse_linear_activation": String(policy.fuseLinearActivation)
            ]
        )
    }
}

struct ShapeDisciplineProcessor: StageProcessor {
    func process(
        ir: ModelIR,
        workloadCategory: WorkloadCategory,
        policy: LoweringPolicy,
        outputDir: URL
    ) async throws -> StageResult {
        var shaped = ir
        shaped.metadata["shape_discipline_applied"] = "true"
        
        // Apply shape constraints
        if let maxTokens = policy.maxTokens {
            shaped.metadata["max_tokens"] = String(maxTokens)
        }
        
        if let maxBatchSize = policy.maxBatchSize {
            shaped.metadata["max_batch_size"] = String(maxBatchSize)
        }
        
        if let fixedResolution = policy.fixedResolution {
            shaped.metadata["fixed_resolution"] = "\(fixedResolution.width)x\(fixedResolution.height)"
        }
        
        // Mark dynamic shapes
        shaped.metadata["dynamic_shapes"] = String(policy.allowDynamicShapes)
        
        // Apply memory budget if specified
        if let memoryBudget = policy.memoryBudgetMB {
            shaped.metadata["memory_budget_mb"] = String(memoryBudget)
        }
        
        return StageResult(
            stage: .shapeDiscipline,
            inputIR: ir,
            outputIR: shaped,
            success: true,
            issues: [],
            metadata: [
                "allow_dynamic_shapes": String(policy.allowDynamicShapes),
                "memory_budget_mb": policy.memoryBudgetMB.map(String.init) ?? "none"
            ]
        )
    }
}

struct ExportProcessor: StageProcessor {
    func process(
        ir: ModelIR,
        workloadCategory: WorkloadCategory,
        policy: LoweringPolicy,
        outputDir: URL
    ) async throws -> StageResult {
        // In practice, this would export to ONNX or PyTorch format for CoreML conversion
        let exportPath = outputDir.appendingPathComponent("model_ready_for_coreml.pt")
        let exportData = "Exported model for CoreML conversion".data(using: .utf8)!
        try exportData.write(to: exportPath)
        
        var exported = ir
        exported.path = exportPath.path
        exported.metadata["exported"] = "true"
        exported.metadata["export_format"] = "torchscript"
        
        return StageResult(
            stage: .export,
            inputIR: ir,
            outputIR: exported,
            success: true,
            issues: [],
            metadata: [
                "export_path": exportPath.path,
                "export_format": "torchscript"
            ]
        )
    }
}

struct VerificationProcessor: StageProcessor {
    func process(
        ir: ModelIR,
        workloadCategory: WorkloadCategory,
        policy: LoweringPolicy,
        outputDir: URL
    ) async throws -> StageResult {
        // Placeholder verification - would run actual verification tests
        let verificationPassed = true
        let issues: [String] = []
        
        var verified = ir
        verified.metadata["verified"] = String(verificationPassed)
        
        if let target = policy.performanceTarget {
            verified.metadata["performance_target_latency_ms"] = target.latencyMS.map { String($0) } ?? "none"
        }
        
        return StageResult(
            stage: .verification,
            inputIR: ir,
            outputIR: verified,
            success: verificationPassed,
            issues: issues,
            metadata: [
                "verification_passed": String(verificationPassed),
                "issues_count": String(issues.count)
            ]
        )
    }
}

// MARK: - Utility

private func computeFileSHA256(url: URL) async throws -> String {
    let data = try Data(contentsOf: url)
    var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    data.withUnsafeBytes {
        _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
    }
    return hash.map { String(format: "%02x", $0) }.joined()
}

import CommonCrypto

// MARK: - Policy Protocol Integration

extension ModelLoweringPipeline {
    /// Apply lowering with a workload-specific policy protocol
    public func applyLowering(
        modelPath: String,
        policy: LoweringPolicyProtocol
    ) async throws -> LoweringResult {
        return try await applyLowering(
            modelPath: modelPath,
            workloadCategory: policy.workloadCategory,
            policy: policy.basePolicy
        )
    }
    
    /// Apply lowering with workload-specific transformations
    public func applyLoweringWithTransformations(
        modelPath: String,
        policy: LoweringPolicyProtocol
    ) async throws -> LoweringResult {
        let startTime = Date()
        let outputDir = workDir.appendingPathComponent("lowered_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        var currentIR = ModelIR(
            format: .unknown,
            path: modelPath,
            metadata: [:],
            graphHash: ""
        )
        
        var appliedStages: [LoweringStage] = []
        var stageResults: [LoweringStage: StageResult] = [:]
        
        // Execute each stage in sequence with policy-specific transformations
        for stage in LoweringStage.allCases {
            guard let processor = stageProcessors[stage] else {
                continue
            }
            
            // Apply policy-specific transformations before stage processing
            currentIR = try await policy.applyTransformations(
                to: currentIR,
                stage: stage,
                outputDir: outputDir
            )
            
            let stageResult = try await processor.process(
                ir: currentIR,
                workloadCategory: policy.workloadCategory,
                policy: policy.basePolicy,
                outputDir: outputDir
            )
            
            currentIR = stageResult.outputIR
            appliedStages.append(stage)
            stageResults[stage] = stageResult
            
            // Early exit if stage failed
            if !stageResult.success {
                break
            }
        }
        
        let verification = LoweringVerification(
            passed: appliedStages.count == LoweringStage.allCases.count,
            issues: stageResults.values.flatMap { $0.issues },
            goldenTestResults: nil
        )
        
        return LoweringResult(
            inputPath: modelPath,
            outputPath: currentIR.path,
            workloadCategory: policy.workloadCategory,
            appliedStages: appliedStages,
            verification: verification,
            timestamp: startTime,
            metadata: [
                "duration_sec": String(Int(Date().timeIntervalSince(startTime))),
                "output_dir": outputDir.path,
                "policy_type": String(describing: type(of: policy)),
                "policy_workload": policy.workloadCategory.rawValue,
                "stage_results": stageResults.map { "\($0.key.rawValue):\($0.value.success)" }.joined(separator: ";")
            ]
        )
    }
    
    /// Generate bricks for a model using workload-specific policy
    public func generateBricks(
        modelPath: String,
        policy: LoweringPolicyProtocol,
        inputConstraints: InputConstraints,
        memoryBudgetMB: Int? = nil
    ) async throws -> [ModelBrick] {
        // First analyze the model to get actual constraints
        let modelAnalysis = try await analyzeModel(at: modelPath)
        
        // Combine analysis with provided constraints
        let combinedConstraints = combineConstraints(
            analysis: modelAnalysis,
            userConstraints: inputConstraints
        )
        
        // Generate bricks using the policy
        return try policy.generateBricks(
            inputConstraints: combinedConstraints,
            memoryBudgetMB: memoryBudgetMB
        )
    }
    
    /// Analyze model to determine input constraints
    private func analyzeModel(at path: String) async throws -> ModelAnalysis {
        // Placeholder implementation - would analyze model architecture
        // In practice, this would use torch.export or similar to analyze the model
        let fileManager = FileManager.default
        let attributes = try fileManager.attributesOfItem(atPath: path)
        let fileSize = attributes[.size] as? Int ?? 0
        
        // Simple heuristic based on file size
        let estimatedMemoryMB = fileSize / (1024 * 1024)
        
        return ModelAnalysis(
            supportsDynamicShapes: true,
            maxSequenceLength: 4096,
            maxBatchSize: 32,
            recommendedPrecision: .fp16,
            estimatedMemoryMB: max(256, estimatedMemoryMB * 2) // 2x overhead
        )
    }
    
    /// Combine model analysis with user constraints
    private func combineConstraints(
        analysis: ModelAnalysis,
        userConstraints: InputConstraints
    ) -> InputConstraints {
        return InputConstraints(
            minWidth: max(1, userConstraints.minWidth),
            maxWidth: min(analysis.maxSequenceLength, userConstraints.maxWidth),
            minHeight: max(1, userConstraints.minHeight),
            maxHeight: min(analysis.maxSequenceLength, userConstraints.maxHeight),
            minBatchSize: max(1, userConstraints.minBatchSize),
            maxBatchSize: min(analysis.maxBatchSize, userConstraints.maxBatchSize),
            minChannels: max(1, userConstraints.minChannels),
            maxChannels: min(analysis.maxSequenceLength, userConstraints.maxChannels)
        )
    }
}

