//
//  LoweringSupportingTypes.swift
//  ModelRegistry
//
//  Supporting types for the model lowering pipeline.
//

import Foundation

/// The 6 stages of the model lowering pipeline
public enum LoweringStage: String, Codable, Sendable, CaseIterable {
    /// Stage 1: Capture model IR from source format
    case irCapture = "ir_capture"
    
    /// Stage 2: Canonicalize operations and structure
    case canonicalization = "canonicalization"
    
    /// Stage 3: Apply lowering passes and optimizations
    case loweringPasses = "lowering_passes"
    
    /// Stage 4: Apply shape discipline and constraints
    case shapeDiscipline = "shape_discipline"
    
    /// Stage 5: Export to target format
    case export = "export"
    
    /// Stage 6: Verify correctness and performance
    case verification = "verification"
    
    /// Display name for the stage
    public var displayName: String {
        switch self {
        case .irCapture: return "IR Capture"
        case .canonicalization: return "Canonicalization"
        case .loweringPasses: return "Lowering Passes"
        case .shapeDiscipline: return "Shape Discipline"
        case .export: return "Export"
        case .verification: return "Verification"
        }
    }
    
    /// Description of what the stage does
    public var description: String {
        switch self {
        case .irCapture:
            return "Capture intermediate representation from source model format"
        case .canonicalization:
            return "Canonicalize operations and structure for target platform"
        case .loweringPasses:
            return "Apply platform-specific lowering passes and optimizations"
        case .shapeDiscipline:
            return "Apply shape constraints and memory layout optimizations"
        case .export:
            return "Export to target runtime format (CoreML, ONNX, etc.)"
        case .verification:
            return "Verify correctness, performance, and compliance"
        }
    }
}

/// Intermediate representation of a model
public struct ModelIR: Sendable {
    /// Format of the IR
    public let format: IRFormat
    
    /// Path to the IR file
    public var path: String
    
    /// Metadata about the IR
    public var metadata: [String: String]
    
    /// Hash of the computation graph
    public let graphHash: String
    
    public init(
        format: IRFormat,
        path: String,
        metadata: [String: String] = [:],
        graphHash: String
    ) {
        self.format = format
        self.path = path
        self.metadata = metadata
        self.graphHash = graphHash
    }
}

/// Supported IR formats
public enum IRFormat: String, Codable, Sendable {
    case pytorch = "pytorch"
    case onnx = "onnx"
    case torchscript = "torchscript"
    case fx = "fx"
    case mlx = "mlx"
    case gguf = "gguf"
    case coreml = "coreml"
    case unknown = "unknown"
}

/// Result of a single pipeline stage
public struct StageResult: Sendable {
    /// Stage that produced this result
    public let stage: LoweringStage
    
    /// Input IR to the stage
    public let inputIR: ModelIR
    
    /// Output IR from the stage
    public let outputIR: ModelIR
    
    /// Whether the stage succeeded
    public let success: Bool
    
    /// Issues encountered during processing
    public let issues: [String]
    
    /// Stage-specific metadata
    public let metadata: [String: String]
    
    public init(
        stage: LoweringStage,
        inputIR: ModelIR,
        outputIR: ModelIR,
        success: Bool,
        issues: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.stage = stage
        self.inputIR = inputIR
        self.outputIR = outputIR
        self.success = success
        self.issues = issues
        self.metadata = metadata
    }
}

/// Complete lowering pipeline result
public struct LoweringResult: Sendable {
    /// Input model path
    public let inputPath: String
    
    /// Output model path
    public let outputPath: String
    
    /// Workload category
    public let workloadCategory: WorkloadCategory
    
    /// Stages that were applied
    public let appliedStages: [LoweringStage]
    
    /// Verification results
    public let verification: LoweringVerification
    
    /// When the lowering started
    public let timestamp: Date
    
    /// Additional metadata
    public let metadata: [String: String]
    
    /// CoreReceipt ID for auditability
    public let receiptId: String
    
    public init(
        inputPath: String,
        outputPath: String,
        workloadCategory: WorkloadCategory,
        appliedStages: [LoweringStage],
        verification: LoweringVerification,
        timestamp: Date = Date(),
        metadata: [String: String] = [:],
        receiptId: String = UUID().uuidString
    ) {
        self.inputPath = inputPath
        self.outputPath = outputPath
        self.workloadCategory = workloadCategory
        self.appliedStages = appliedStages
        self.verification = verification
        self.timestamp = timestamp
        self.metadata = metadata
        self.receiptId = receiptId
    }
    
    /// Creates a simple receipt dictionary for auditability
    public func createReceipt() -> [String: Any] {
        return [
            "receipt_id": receiptId,
            "input_path": inputPath,
            "output_path": outputPath,
            "workload_category": workloadCategory.rawValue,
            "applied_stages": appliedStages.map { $0.rawValue },
            "verification_passed": verification.passed,
            "timestamp": timestamp,
            "metadata": metadata
        ]
    }
}

/// Result of partial lowering (specific stages only)
public struct PartialLoweringResult: Sendable {
    /// Input model path
    public let inputPath: String
    
    /// Output model path
    public let outputPath: String
    
    /// Workload category
    public let workloadCategory: WorkloadCategory
    
    /// Stages that were applied
    public let appliedStages: [LoweringStage]
    
    /// Results for each applied stage
    public let stageResults: [LoweringStage: StageResult]
    
    /// When the lowering started
    public let timestamp: Date
    
    /// Additional metadata
    public let metadata: [String: String]
    
    public init(
        inputPath: String,
        outputPath: String,
        workloadCategory: WorkloadCategory,
        appliedStages: [LoweringStage],
        stageResults: [LoweringStage: StageResult],
        timestamp: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.inputPath = inputPath
        self.outputPath = outputPath
        self.workloadCategory = workloadCategory
        self.appliedStages = appliedStages
        self.stageResults = stageResults
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

/// Verification results
public struct LoweringVerification: Sendable {
    /// Whether verification passed
    public let passed: Bool
    
    /// Issues found during verification
    public let issues: [String]
    
    /// Golden test results if available
    public let goldenTestResults: GoldenTestResults?
    
    /// Performance metrics if measured
    public let performanceMetrics: PerformanceMetrics?
    
    public init(
        passed: Bool,
        issues: [String] = [],
        goldenTestResults: GoldenTestResults? = nil,
        performanceMetrics: PerformanceMetrics? = nil
    ) {
        self.passed = passed
        self.issues = issues
        self.goldenTestResults = goldenTestResults
        self.performanceMetrics = performanceMetrics
    }
}

/// Golden test results for verification
public struct GoldenTestResults: Sendable {
    /// Total number of tests
    public let testCount: Int
    
    /// Number of tests that passed
    public let passedCount: Int
    
    /// Maximum error observed
    public let maxError: Double
    
    /// Average error observed
    public let avgError: Double
    
    /// Test cases that failed
    public let failedCases: [GoldenTestCase]
    
    public init(
        testCount: Int,
        passedCount: Int,
        maxError: Double,
        avgError: Double,
        failedCases: [GoldenTestCase] = []
    ) {
        self.testCount = testCount
        self.passedCount = passedCount
        self.maxError = maxError
        self.avgError = avgError
        self.failedCases = failedCases
    }
}

/// Individual golden test case
public struct GoldenTestCase: Sendable {
    /// Test case identifier
    public let id: String
    
    /// Expected output
    public let expected: [Float]
    
    /// Actual output
    public let actual: [Float]
    
    /// Error magnitude
    public let error: Double
    
    /// Whether the test passed
    public let passed: Bool
    
    public init(
        id: String,
        expected: [Float],
        actual: [Float],
        error: Double,
        passed: Bool
    ) {
        self.id = id
        self.expected = expected
        self.actual = actual
        self.error = error
        self.passed = passed
    }
}

/// Performance metrics
public struct PerformanceMetrics: Sendable {
    /// Inference latency in milliseconds
    public let latencyMS: Double
    
    /// Throughput in inferences per second
    public let throughputIPS: Double
    
    /// Memory usage in MB
    public let memoryUsageMB: Double
    
    /// Peak memory usage in MB
    public let peakMemoryMB: Double
    
    /// Power consumption in watts (if available)
    public let powerWatts: Double?
    
    public init(
        latencyMS: Double,
        throughputIPS: Double,
        memoryUsageMB: Double,
        peakMemoryMB: Double,
        powerWatts: Double? = nil
    ) {
        self.latencyMS = latencyMS
        self.throughputIPS = throughputIPS
        self.memoryUsageMB = memoryUsageMB
        self.peakMemoryMB = peakMemoryMB
        self.powerWatts = powerWatts
    }
}

/// Lowering pipeline errors
public enum LoweringError: Error, Sendable {
    case stageNotSupported(LoweringStage)
    case invalidModelFormat(String)
    case unsupportedOperation(String)
    case shapeConstraintViolation(String)
    case memoryBudgetExceeded(Int, Int) // budget, actual
    case performanceTargetMissed(String)
    case verificationFailed([String])
    case exportFailed(String)
}

extension LoweringError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .stageNotSupported(let stage):
            return "Stage \(stage.rawValue) is not supported"
        case .invalidModelFormat(let format):
            return "Invalid model format: \(format)"
        case .unsupportedOperation(let op):
            return "Unsupported operation: \(op)"
        case .shapeConstraintViolation(let constraint):
            return "Shape constraint violation: \(constraint)"
        case .memoryBudgetExceeded(let budget, let actual):
            return "Memory budget exceeded: \(actual)MB > \(budget)MB"
        case .performanceTargetMissed(let target):
            return "Performance target missed: \(target)"
        case .verificationFailed(let issues):
            return "Verification failed with issues: \(issues.joined(separator: ", "))"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        }
    }
}