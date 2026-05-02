//
//  CoreMLArtifactContract.swift
//  ContractsCore
//
//  CoreML artifact contract implementing the 5 SURFACE layers:
//  Schema, Limits, Versioning, Capability, Receipts
//

import FoundationContracts
import GovernanceContracts
import EvidenceContracts
import Foundation
import CryptoKit
import AnigmaPrimitives

// MARK: - SURFACE Layer 1: Schema

/// Tensor shape specification for CoreML models
public struct TensorShape: Sendable, Codable, Hashable {
    /// Batch dimension (optional, -1 for dynamic)
    public let batch: Int
    /// Channel dimension
    public let channels: Int
    /// Height dimension
    public let height: Int
    /// Width dimension
    public let width: Int
    
    public init(batch: Int = -1, channels: Int, height: Int, width: Int) {
        self.batch = batch
        self.channels = channels
        self.height = height
        self.width = width
    }
    
    /// Returns total element count
    public var elementCount: Int {
        let effectiveBatch = batch == -1 ? 1 : batch
        return effectiveBatch * channels * height * width
    }
    
    /// Validates shape constraints
    public func validate() throws {
        guard channels > 0 else {
            throw ValidationError.schemaViolation("Channels must be positive")
        }
        guard height > 0 else {
            throw ValidationError.schemaViolation("Height must be positive")
        }
        guard width > 0 else {
            throw ValidationError.schemaViolation("Width must be positive")
        }
        guard batch == -1 || batch > 0 else {
            throw ValidationError.schemaViolation("Batch must be -1 (dynamic) or positive")
        }
        
        // Validate reasonable limits for dimensions
        guard channels <= 1024 else {
            throw ValidationError.schemaViolation("Channels dimension too large (max 1024)")
        }
        guard height <= 8192 else {
            throw ValidationError.schemaViolation("Height dimension too large (max 8192)")
        }
        guard width <= 8192 else {
            throw ValidationError.schemaViolation("Width dimension too large (max 8192)")
        }
        guard batch == -1 || batch <= 256 else {
            throw ValidationError.schemaViolation("Batch dimension too large (max 256)")
        }
        
        // Validate total element count doesn't exceed practical limits
        guard elementCount <= 16_777_216 else { // 16M elements
            throw ValidationError.schemaViolation("Total tensor elements exceed maximum (16,777,216)")
        }
    }
}

/// Supported CoreML data types
public enum CoreMLDataType: String, Sendable, Codable, CaseIterable {
    case float16 = "float16"
    case float32 = "float32"
    case int8 = "int8"
    case int16 = "int16"
    case int32 = "int32"
    case uint8 = "uint8"
    case uint16 = "uint16"
    case uint32 = "uint32"
    case bool = "bool"
    
    /// Returns size in bytes
    public var byteSize: Int {
        switch self {
        case .float16: return 2
        case .float32: return 4
        case .int8, .uint8, .bool: return 1
        case .int16, .uint16: return 2
        case .int32, .uint32: return 4
        }
    }
}

/// Coordinate system specification for spatial operations
public struct CoordinateSystem: Sendable, Codable, Hashable {
    /// Origin location (top-left, center, etc.)
    public let origin: Origin
    /// Axis orientation (row-major, column-major)
    public let orientation: Orientation
    /// Normalization range (0-1, -1-1, etc.)
    public let normalization: Normalization
    
    public enum Origin: String, Sendable, Codable {
        case topLeft = "top_left"
        case center = "center"
        case bottomLeft = "bottom_left"
    }
    
    public enum Orientation: String, Sendable, Codable {
        case rowMajor = "row_major"
        case columnMajor = "column_major"
    }
    
    public enum Normalization: String, Sendable, Codable {
        case zeroToOne = "0_1"
        case minusOneToOne = "-1_1"
        case imagenet = "imagenet"
        case custom = "custom"
    }
    
    public init(origin: Origin = .topLeft, orientation: Orientation = .rowMajor, normalization: Normalization = .zeroToOne) {
        self.origin = origin
        self.orientation = orientation
        self.normalization = normalization
    }
}

extension CoordinateSystem {
    /// Validates coordinate system for given data type
    public func validate(for dataType: CoreMLDataType) throws {
        // Validate normalization compatibility with data type
        switch normalization {
        case .imagenet:
            guard dataType == .float32 || dataType == .float16 else {
                throw ValidationError.schemaViolation("ImageNet normalization requires float32 or float16 data type, got \(dataType.rawValue)")
            }
        case .zeroToOne, .minusOneToOne:
            // These normalizations work with all numeric types
            guard dataType != .bool else {
                throw ValidationError.schemaViolation("Normalization \(normalization.rawValue) not compatible with bool data type")
            }
        case .custom:
            // Custom normalization has no restrictions
            break
        }
        
        // Validate origin and orientation combinations
        if origin == .center && orientation == .columnMajor {
            // This is an unusual but valid combination
            // Could add specific validation if needed
        }
    }
}

/// Input/output specification for CoreML models
public struct IOTensorSpec: Sendable, Codable, Hashable {
    /// Tensor name
    public let name: String
    /// Data type
    public let dataType: CoreMLDataType
    /// Shape specification
    public let shape: TensorShape
    /// Coordinate system
    public let coordinateSystem: CoordinateSystem
    /// Optional description
    public let description: String?
    
    public init(name: String, dataType: CoreMLDataType, shape: TensorShape, coordinateSystem: CoordinateSystem = CoordinateSystem(), description: String? = nil) {
        self.name = name
        self.dataType = dataType
        self.shape = shape
        self.coordinateSystem = coordinateSystem
        self.description = description
    }
    
    /// Calculates memory footprint in bytes
    public var memoryFootprint: Int {
        shape.elementCount * dataType.byteSize
    }
    
    /// Validates tensor specification
    public func validate() throws {
        try shape.validate()
        guard !name.isEmpty else {
            throw ValidationError.schemaViolation("Tensor name cannot be empty")
        }
        
        // Validate tensor name follows naming conventions
        guard name.range(of: "^[a-zA-Z_][a-zA-Z0-9_]*$", options: .regularExpression) != nil else {
            throw ValidationError.schemaViolation("Tensor name must start with letter or underscore and contain only alphanumeric characters")
        }
        
        // Validate memory footprint doesn't exceed reasonable limits
        guard memoryFootprint <= 268_435_456 else { // 256MB
            throw ValidationError.schemaViolation("Tensor memory footprint exceeds maximum (256MB)")
        }
        
        // Validate coordinate system consistency
        try coordinateSystem.validate(for: dataType)
    }
}

/// Complete schema specification for CoreML model
public struct CoreMLSchema: Sendable, Codable {
    /// Model description
    public let description: String
    /// Input tensor specifications
    public let inputs: [IOTensorSpec]
    /// Output tensor specifications
    public let outputs: [IOTensorSpec]
    /// Model type (classifier, regressor, etc.)
    public let modelType: String
    /// Optional class labels for classifiers
    public let classLabels: [String]?
    /// Feature names (for interpretability)
    public let featureNames: [String]?
    
    public init(description: String, inputs: [IOTensorSpec], outputs: [IOTensorSpec], modelType: String, classLabels: [String]? = nil, featureNames: [String]? = nil) {
        self.description = description
        self.inputs = inputs
        self.outputs = outputs
        self.modelType = modelType
        self.classLabels = classLabels
        self.featureNames = featureNames
    }
    
    /// Validates complete schema
    public func validate() throws {
        guard !description.isEmpty else {
            throw ValidationError.schemaViolation("Model description cannot be empty")
        }
        guard !inputs.isEmpty else {
            throw ValidationError.schemaViolation("Model must have at least one input")
        }
        guard !outputs.isEmpty else {
            throw ValidationError.schemaViolation("Model must have at least one output")
        }
        guard !modelType.isEmpty else {
            throw ValidationError.schemaViolation("Model type cannot be empty")
        }
        
        for input in inputs {
            try input.validate()
        }
        for output in outputs {
            try output.validate()
        }
        
        // Validate unique tensor names
        let allNames = inputs.map { $0.name } + outputs.map { $0.name }
        let uniqueNames = Set(allNames)
        guard allNames.count == uniqueNames.count else {
            throw ValidationError.schemaViolation("Tensor names must be unique")
        }
    }
    
    /// Computes schema hash for versioning
    public var schemaHash: String {
        var components: [String] = []
        components.append(description)
        components.append(modelType)
        
        for input in inputs.sorted(by: { $0.name < $1.name }) {
            components.append("input:\(input.name):\(input.dataType.rawValue):\(input.shape.batch),\(input.shape.channels),\(input.shape.height),\(input.shape.width)")
        }
        
        for output in outputs.sorted(by: { $0.name < $1.name }) {
            components.append("output:\(output.name):\(output.dataType.rawValue):\(output.shape.batch),\(output.shape.channels),\(output.shape.height),\(output.shape.width)")
        }
        
        if let classLabels = classLabels {
            components.append("labels:\(classLabels.joined(separator: ","))")
        }
        
        if let featureNames = featureNames {
            components.append("features:\(featureNames.joined(separator: ","))")
        }
        
        let combined = components.joined(separator: "|")
        return BLAKE3Digest.hex(of: Data(combined.utf8))
    }
}

// MARK: - SURFACE Layer 2: Limits

/// Limits enforcement result with detailed information
public struct LimitsEnforcementResult: Sendable {
    /// Whether limits were violated
    public let violated: Bool
    /// Type of violation (hard or soft)
    public let violationType: ViolationType
    /// Detailed violation messages
    public let violations: [String]
    /// Warning messages for soft limits
    public let warnings: [String]
    
    public enum ViolationType: Sendable {
        case hard
        case soft
        case none
    }
    
    public init(violated: Bool = false, violationType: ViolationType = .none, violations: [String] = [], warnings: [String] = []) {
        self.violated = violated
        self.violationType = violationType
        self.violations = violations
        self.warnings = warnings
    }
    
    /// Creates a result with hard violations
    public static func hardViolation(_ messages: [String]) -> LimitsEnforcementResult {
        LimitsEnforcementResult(violated: true, violationType: .hard, violations: messages)
    }
    
    /// Creates a result with soft violations (warnings)
    public static func softViolation(_ warnings: [String]) -> LimitsEnforcementResult {
        LimitsEnforcementResult(violated: true, violationType: .soft, warnings: warnings)
    }
    
    /// Creates a clean result
    public static func clean() -> LimitsEnforcementResult {
        LimitsEnforcementResult()
    }
}

/// Hard boundaries that cannot be exceeded
public struct HardLimits: Sendable, Codable {
    /// Maximum batch size (-1 for unlimited)
    public let maxBatchSize: Int
    /// Maximum memory footprint in bytes
    public let maxMemoryBytes: Int64
    /// Maximum inference time in milliseconds
    public let maxInferenceTimeMs: Int64
    /// Maximum model size in bytes
    public let maxModelSizeBytes: Int64
    /// Maximum input size in bytes
    public let maxInputSizeBytes: Int64
    /// Maximum output size in bytes
    public let maxOutputSizeBytes: Int64
    
    public init(maxBatchSize: Int = -1, maxMemoryBytes: Int64, maxInferenceTimeMs: Int64, maxModelSizeBytes: Int64, maxInputSizeBytes: Int64, maxOutputSizeBytes: Int64) {
        self.maxBatchSize = maxBatchSize
        self.maxMemoryBytes = maxMemoryBytes
        self.maxInferenceTimeMs = maxInferenceTimeMs
        self.maxModelSizeBytes = maxModelSizeBytes
        self.maxInputSizeBytes = maxInputSizeBytes
        self.maxOutputSizeBytes = maxOutputSizeBytes
    }
    
    /// Validates hard limits
    public func validate() throws {
        guard maxMemoryBytes > 0 else {
            throw ValidationError.policyViolation("Max memory must be positive")
        }
        guard maxInferenceTimeMs > 0 else {
            throw ValidationError.policyViolation("Max inference time must be positive")
        }
        guard maxModelSizeBytes > 0 else {
            throw ValidationError.policyViolation("Max model size must be positive")
        }
        guard maxInputSizeBytes > 0 else {
            throw ValidationError.policyViolation("Max input size must be positive")
        }
        guard maxOutputSizeBytes > 0 else {
            throw ValidationError.policyViolation("Max output size must be positive")
        }
    }
}

/// Soft boundaries with warnings but not failures
public struct SoftLimits: Sendable, Codable {
    /// Recommended batch size for optimal performance
    public let recommendedBatchSize: Int
    /// Target memory footprint in bytes
    public let targetMemoryBytes: Int64
    /// Target inference time in milliseconds
    public let targetInferenceTimeMs: Int64
    /// Warning threshold for memory usage (percentage of max)
    public let memoryWarningThreshold: Double
    /// Warning threshold for inference time (percentage of max)
    public let timeWarningThreshold: Double
    
    public init(recommendedBatchSize: Int = 1, targetMemoryBytes: Int64, targetInferenceTimeMs: Int64, memoryWarningThreshold: Double = 0.8, timeWarningThreshold: Double = 0.8) {
        self.recommendedBatchSize = recommendedBatchSize
        self.targetMemoryBytes = targetMemoryBytes
        self.targetInferenceTimeMs = targetInferenceTimeMs
        self.memoryWarningThreshold = memoryWarningThreshold
        self.timeWarningThreshold = timeWarningThreshold
    }
    
    /// Validates soft limits
    public func validate() throws {
        guard recommendedBatchSize > 0 else {
            throw ValidationError.policyViolation("Recommended batch size must be positive")
        }
        guard targetMemoryBytes > 0 else {
            throw ValidationError.policyViolation("Target memory must be positive")
        }
        guard targetInferenceTimeMs > 0 else {
            throw ValidationError.policyViolation("Target inference time must be positive")
        }
        guard memoryWarningThreshold > 0 && memoryWarningThreshold <= 1.0 else {
            throw ValidationError.policyViolation("Memory warning threshold must be between 0 and 1")
        }
        guard timeWarningThreshold > 0 && timeWarningThreshold <= 1.0 else {
            throw ValidationError.policyViolation("Time warning threshold must be between 0 and 1")
        }
    }
}

/// Complete limits specification
public struct CoreMLLimits: Sendable, Codable {
    /// Hard boundaries
    public let hard: HardLimits
    /// Soft boundaries
    public let soft: SoftLimits
    /// Platform-specific constraints
    public let platformConstraints: [String: String]
    
    public init(hard: HardLimits, soft: SoftLimits, platformConstraints: [String: String] = [:]) {
        self.hard = hard
        self.soft = soft
        self.platformConstraints = platformConstraints
    }
    
    /// Validates limits specification
    public func validate() throws {
        try hard.validate()
        try soft.validate()
        
        // Ensure soft limits are within hard limits
        guard soft.targetMemoryBytes <= hard.maxMemoryBytes else {
            throw ValidationError.policyViolation("Target memory exceeds maximum memory")
        }
        guard soft.targetInferenceTimeMs <= hard.maxInferenceTimeMs else {
            throw ValidationError.policyViolation("Target inference time exceeds maximum time")
        }
        guard soft.recommendedBatchSize <= hard.maxBatchSize || hard.maxBatchSize == -1 else {
            throw ValidationError.policyViolation("Recommended batch size exceeds maximum batch size")
        }
    }
    
    /// Enforces hard and soft limits against actual runtime values
    public func enforceLimits(
        actualBatchSize: Int? = nil,
        actualMemoryBytes: Int64? = nil,
        actualInferenceTimeMs: Int64? = nil,
        actualModelSizeBytes: Int64? = nil,
        actualInputSizeBytes: Int64? = nil,
        actualOutputSizeBytes: Int64? = nil
    ) -> LimitsEnforcementResult {
        var hardViolations: [String] = []
        var softWarnings: [String] = []
        
        // Check hard limits
        if let batchSize = actualBatchSize, hard.maxBatchSize != -1 {
            if batchSize > hard.maxBatchSize {
                hardViolations.append("Batch size \(batchSize) exceeds maximum \(hard.maxBatchSize)")
            }
        }
        
        if let memoryBytes = actualMemoryBytes {
            if memoryBytes > hard.maxMemoryBytes {
                hardViolations.append("Memory usage \(memoryBytes) bytes exceeds maximum \(hard.maxMemoryBytes) bytes")
            } else if memoryBytes > Int64(Double(hard.maxMemoryBytes) * soft.memoryWarningThreshold) {
                softWarnings.append("Memory usage \(memoryBytes) bytes exceeds warning threshold (\(Int(soft.memoryWarningThreshold * 100))% of max)")
            }
        }
        
        if let inferenceTime = actualInferenceTimeMs {
            if inferenceTime > hard.maxInferenceTimeMs {
                hardViolations.append("Inference time \(inferenceTime)ms exceeds maximum \(hard.maxInferenceTimeMs)ms")
            } else if inferenceTime > Int64(Double(hard.maxInferenceTimeMs) * soft.timeWarningThreshold) {
                softWarnings.append("Inference time \(inferenceTime)ms exceeds warning threshold (\(Int(soft.timeWarningThreshold * 100))% of max)")
            }
        }
        
        if let modelSize = actualModelSizeBytes, modelSize > hard.maxModelSizeBytes {
            hardViolations.append("Model size \(modelSize) bytes exceeds maximum \(hard.maxModelSizeBytes) bytes")
        }
        
        if let inputSize = actualInputSizeBytes, inputSize > hard.maxInputSizeBytes {
            hardViolations.append("Input size \(inputSize) bytes exceeds maximum \(hard.maxInputSizeBytes) bytes")
        }
        
        if let outputSize = actualOutputSizeBytes, outputSize > hard.maxOutputSizeBytes {
            hardViolations.append("Output size \(outputSize) bytes exceeds maximum \(hard.maxOutputSizeBytes) bytes")
        }
        
        // Check soft limits for warnings
        if let batchSize = actualBatchSize, batchSize > soft.recommendedBatchSize {
            softWarnings.append("Batch size \(batchSize) exceeds recommended \(soft.recommendedBatchSize)")
        }
        
        if let memoryBytes = actualMemoryBytes, memoryBytes > soft.targetMemoryBytes {
            softWarnings.append("Memory usage \(memoryBytes) bytes exceeds target \(soft.targetMemoryBytes) bytes")
        }
        
        if let inferenceTime = actualInferenceTimeMs, inferenceTime > soft.targetInferenceTimeMs {
            softWarnings.append("Inference time \(inferenceTime)ms exceeds target \(soft.targetInferenceTimeMs)ms")
        }
        
        if !hardViolations.isEmpty {
            return .hardViolation(hardViolations)
        } else if !softWarnings.isEmpty {
            return .softViolation(softWarnings)
        } else {
            return .clean()
        }
    }
}

// MARK: - SURFACE Layer 3: Versioning

/// Architecture fingerprint for deterministic identification
public struct ArchitectureFingerprint: Sendable, Codable, Hashable {
    /// Model architecture name (e.g., "MobileNetV2", "ResNet50")
    public let architecture: String
    /// Operation set version
    public let opsetVersion: String
    /// CoreML specification version
    public let coremlVersion: String
    /// Compiler version used
    public let compilerVersion: String
    /// Quantization scheme if any
    public let quantization: String?
    /// Custom architecture hash
    public let customHash: String?
    
    public init(architecture: String, opsetVersion: String, coremlVersion: String, compilerVersion: String, quantization: String? = nil, customHash: String? = nil) {
        self.architecture = architecture
        self.opsetVersion = opsetVersion
        self.coremlVersion = coremlVersion
        self.compilerVersion = compilerVersion
        self.quantization = quantization
        self.customHash = customHash
    }
    
    /// Computes fingerprint hash
    public var fingerprintHash: String {
        var components: [String] = []
        components.append(architecture)
        components.append(opsetVersion)
        components.append(coremlVersion)
        components.append(compilerVersion)
        
        if let quantization = quantization {
            components.append(quantization)
        }
        
        if let customHash = customHash {
            components.append(customHash)
        }
        
        let combined = components.joined(separator: "|")
        return BLAKE3Digest.hex(of: Data(combined.utf8))
    }
}

/// Composite version identifier
public struct CoreMLVersion: Sendable, Codable, Hashable {
    /// Semantic version (major.minor.patch)
    public let semantic: String
    /// Build identifier
    public let build: String
    /// Architecture fingerprint
    public let architectureFingerprint: ArchitectureFingerprint
    /// Compatibility flags
    public let compatibility: [String: Bool]
    
    public init(semantic: String, build: String, architectureFingerprint: ArchitectureFingerprint, compatibility: [String: Bool] = [:]) {
        self.semantic = semantic
        self.build = build
        self.architectureFingerprint = architectureFingerprint
        self.compatibility = compatibility
    }
    
    /// Validates version specification
    public func validate() throws {
        // Validate semantic version format
        let parts = semantic.split(separator: ".")
        guard parts.count == 3 else {
            throw ValidationError.schemaViolation("Semantic version must be in format major.minor.patch")
        }
        
        for part in parts {
            guard Int(part) != nil else {
                throw ValidationError.schemaViolation("Semantic version parts must be integers")
            }
        }
        
        guard !build.isEmpty else {
            throw ValidationError.schemaViolation("Build identifier cannot be empty")
        }
    }
    
    /// Computes composite version hash
    public var versionHash: String {
        var components: [String] = []
        components.append(semantic)
        components.append(build)
        components.append(architectureFingerprint.fingerprintHash)
        
        let sortedCompatibility = compatibility.sorted { $0.key < $1.key }
        for (key, value) in sortedCompatibility {
            components.append("\(key):\(value)")
        }
        
        let combined = components.joined(separator: "|")
        return BLAKE3Digest.hex(of: Data(combined.utf8))
    }
}

// MARK: - SURFACE Layer 4: Capability

/// Hardware acceleration capability declaration
public enum HardwareCapability: String, Sendable, Codable, CaseIterable {
    case aneOnly = "ANE_ONLY"
    case mixed = "MIXED"
    case cpuOnly = "CPU_ONLY"
    case gpuOnly = "GPU_ONLY"
    
    /// Returns supported hardware targets
    public var supportedTargets: [String] {
        switch self {
        case .aneOnly:
            return ["ANE"]
        case .mixed:
            return ["ANE", "CPU", "GPU"]
        case .cpuOnly:
            return ["CPU"]
        case .gpuOnly:
            return ["GPU"]
        }
    }
    
    /// Checks if capability supports specific hardware
    public func supports(_ hardware: String) -> Bool {
        supportedTargets.contains(hardware.uppercased())
    }
}

/// Performance profile for different hardware targets
public struct PerformanceProfile: Sendable, Codable {
    /// Target hardware
    public let hardware: String
    /// Expected inference time in milliseconds
    public let expectedInferenceTimeMs: Int64
    /// Expected memory usage in bytes
    public let expectedMemoryBytes: Int64
    /// Power consumption estimate in milliwatts
    public let powerEstimateMw: Int64?
    /// Thermal impact rating (1-10)
    public let thermalImpact: Int?
    
    public init(hardware: String, expectedInferenceTimeMs: Int64, expectedMemoryBytes: Int64, powerEstimateMw: Int64? = nil, thermalImpact: Int? = nil) {
        self.hardware = hardware
        self.expectedInferenceTimeMs = expectedInferenceTimeMs
        self.expectedMemoryBytes = expectedMemoryBytes
        self.powerEstimateMw = powerEstimateMw
        self.thermalImpact = thermalImpact
    }
    
    /// Validates performance profile
    public func validate() throws {
        guard !hardware.isEmpty else {
            throw ValidationError.schemaViolation("Hardware target cannot be empty")
        }
        guard expectedInferenceTimeMs > 0 else {
            throw ValidationError.policyViolation("Expected inference time must be positive")
        }
        guard expectedMemoryBytes > 0 else {
            throw ValidationError.policyViolation("Expected memory usage must be positive")
        }
        if let thermalImpact = thermalImpact {
            guard (1...10).contains(thermalImpact) else {
                throw ValidationError.policyViolation("Thermal impact must be between 1 and 10")
            }
        }
    }
}

/// Complete capability specification
public struct CoreMLCapability: Sendable, Codable {
    /// Hardware capability declaration
    public let hardwareCapability: HardwareCapability
    /// Performance profiles for supported hardware
    public let performanceProfiles: [PerformanceProfile]
    /// Required system features
    public let requiredFeatures: [String]
    /// Optional system features
    public let optionalFeatures: [String]
    /// Minimum OS version
    public let minOSVersion: String
    /// Minimum CoreML version
    public let minCoreMLVersion: String
    
    public init(hardwareCapability: HardwareCapability, performanceProfiles: [PerformanceProfile], requiredFeatures: [String] = [], optionalFeatures: [String] = [], minOSVersion: String = "14.0", minCoreMLVersion: String = "5.0") {
        self.hardwareCapability = hardwareCapability
        self.performanceProfiles = performanceProfiles
        self.requiredFeatures = requiredFeatures
        self.optionalFeatures = optionalFeatures
        self.minOSVersion = minOSVersion
        self.minCoreMLVersion = minCoreMLVersion
    }
    
    /// Validates capability specification
    public func validate() throws {
        // Validate performance profiles
        for profile in performanceProfiles {
            try profile.validate()
            
            // Ensure profile hardware is supported by capability
            guard hardwareCapability.supports(profile.hardware) else {
                throw ValidationError.policyViolation("Performance profile hardware \(profile.hardware) not supported by capability \(hardwareCapability.rawValue)")
            }
        }
        
        // Validate OS version format
        let osParts = minOSVersion.split(separator: ".")
        guard osParts.count >= 2 else {
            throw ValidationError.schemaViolation("Minimum OS version must be in format major.minor")
        }
        
        // Validate CoreML version format
        let coremlParts = minCoreMLVersion.split(separator: ".")
        guard coremlParts.count >= 2 else {
            throw ValidationError.schemaViolation("Minimum CoreML version must be in format major.minor")
        }
    }
}

// MARK: - SURFACE Layer 5: Receipts

/// Placement evidence for model deployment
public struct PlacementReceipt: Sendable, Codable {
    /// Placement identifier
    public let placementId: String
    /// Target location (bundle path, cache location, etc.)
    public let targetLocation: String
    /// Placement timestamp
    public let timestamp: Date
    /// Placement checksum
    public let checksum: String
    /// Placement metadata
    public let metadata: [String: String]
    /// Evidence references
    public let evidenceRefs: [EvidenceRef]
    
    public init(placementId: String, targetLocation: String, timestamp: Date = Date(), checksum: String, metadata: [String: String] = [:], evidenceRefs: [EvidenceRef] = []) {
        self.placementId = placementId
        self.targetLocation = targetLocation
        self.timestamp = timestamp
        self.checksum = checksum
        self.metadata = metadata
        self.evidenceRefs = evidenceRefs
    }
    
    /// Validates placement receipt
    public func validate() throws {
        guard !placementId.isEmpty else {
            throw ValidationError.invalidEvidence("Placement ID cannot be empty")
        }
        guard !targetLocation.isEmpty else {
            throw ValidationError.invalidEvidence("Target location cannot be empty")
        }
        guard !checksum.isEmpty else {
            throw ValidationError.invalidEvidence("Checksum cannot be empty")
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case placementId, targetLocation, timestamp, checksum, metadata, evidenceRefs
    }
}

/// Execution evidence for model inference
public struct CoreMLExecutionReceipt: Sendable, Codable {
    /// Execution identifier
    public let executionId: String
    /// Input hash
    public let inputHash: String
    /// Output hash
    public let outputHash: String
    /// Execution timestamp
    public let timestamp: Date
    /// Hardware used
    public let hardwareUsed: String
    /// Actual inference time in milliseconds
    public let actualInferenceTimeMs: Int64
    /// Actual memory usage in bytes
    public let actualMemoryBytes: Int64
    /// Success flag
    public let success: Bool
    /// Error message if failed
    public let errorMessage: String?
    /// Evidence references
    public let evidenceRefs: [EvidenceRef]
    
    public init(executionId: String, inputHash: String, outputHash: String, timestamp: Date = Date(), hardwareUsed: String, actualInferenceTimeMs: Int64, actualMemoryBytes: Int64, success: Bool = true, errorMessage: String? = nil, evidenceRefs: [EvidenceRef] = []) {
        self.executionId = executionId
        self.inputHash = inputHash
        self.outputHash = outputHash
        self.timestamp = timestamp
        self.hardwareUsed = hardwareUsed
        self.actualInferenceTimeMs = actualInferenceTimeMs
        self.actualMemoryBytes = actualMemoryBytes
        self.success = success
        self.errorMessage = errorMessage
        self.evidenceRefs = evidenceRefs
    }
    
    /// Validates execution receipt
    public func validate() throws {
        guard !executionId.isEmpty else {
            throw ValidationError.invalidEvidence("Execution ID cannot be empty")
        }
        guard !inputHash.isEmpty else {
            throw ValidationError.invalidEvidence("Input hash cannot be empty")
        }
        guard !outputHash.isEmpty else {
            throw ValidationError.invalidEvidence("Output hash cannot be empty")
        }
        guard !hardwareUsed.isEmpty else {
            throw ValidationError.invalidEvidence("Hardware used cannot be empty")
        }
        guard actualInferenceTimeMs > 0 else {
            throw ValidationError.invalidEvidence("Actual inference time must be positive")
        }
        guard actualMemoryBytes > 0 else {
            throw ValidationError.invalidEvidence("Actual memory usage must be positive")
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case executionId, inputHash, outputHash, timestamp, hardwareUsed
        case actualInferenceTimeMs, actualMemoryBytes, success, errorMessage, evidenceRefs
    }
}

/// Complete receipts specification
public struct CoreMLReceipts: Sendable, Codable {
    /// Placement receipts
    public let placements: [PlacementReceipt]
    /// Execution receipts
    public let executions: [CoreMLExecutionReceipt]
    /// Validation receipts
    public let validations: [ValidationReceipt]
    
    public init(placements: [PlacementReceipt] = [], executions: [CoreMLExecutionReceipt] = [], validations: [ValidationReceipt] = []) {
        self.placements = placements
        self.executions = executions
        self.validations = validations
    }
    
    /// Validates receipts specification
    public func validate() throws {
        for placement in placements {
            try placement.validate()
        }
        for execution in executions {
            try execution.validate()
        }
        for validation in validations {
            try validation.validate()
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case placements, executions, validations
    }
}

/// Validation receipt for model verification
public struct ValidationReceipt: Sendable, Codable {
    /// Validation identifier
    public let validationId: String
    /// Validation type (schema, limits, capability, etc.)
    public let validationType: String
    /// Validation timestamp
    public let timestamp: Date
    /// Validation result
    public let result: ValidationResult
    /// Details
    public let details: [String: String]
    /// Evidence references
    public let evidenceRefs: [EvidenceRef]
    
    public init(validationId: String, validationType: String, timestamp: Date = Date(), result: ValidationResult, details: [String: String] = [:], evidenceRefs: [EvidenceRef] = []) {
        self.validationId = validationId
        self.validationType = validationType
        self.timestamp = timestamp
        self.result = result
        self.details = details
        self.evidenceRefs = evidenceRefs
    }
    
    /// Validates validation receipt
    public func validate() throws {
        guard !validationId.isEmpty else {
            throw ValidationError.invalidEvidence("Validation ID cannot be empty")
        }
        guard !validationType.isEmpty else {
            throw ValidationError.invalidEvidence("Validation type cannot be empty")
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case validationId, validationType, timestamp, result, details, evidenceRefs
    }
}

/// Validation result enumeration
public enum ValidationResult: String, Sendable, Codable {
    case passed = "passed"
    case failed = "failed"
    case warning = "warning"
    case skipped = "skipped"
}

// MARK: - Runtime Validation

/// Runtime validator for CoreML artifacts
public struct CoreMLRuntimeValidator: Sendable {
    /// The artifact being validated
    public let artifact: CoreMLArtifact
    
    public init(artifact: CoreMLArtifact) {
        self.artifact = artifact
    }
    
    /// Validates artifact before execution
    public func validateForExecution(
        inputBatchSize: Int? = nil,
        hardwareTarget: String? = nil
    ) throws -> ValidationReceipt {
        var validationDetails: [String: String] = [:]
        var warnings: [String] = []
        
        // Validate schema compatibility with execution context
        if let batchSize = inputBatchSize {
            for input in artifact.schema.inputs {
                if input.shape.batch != -1 && input.shape.batch != batchSize {
                    throw ValidationError.schemaViolation("Input batch size \(batchSize) doesn't match schema batch size \(input.shape.batch)")
                }
            }
            validationDetails["inputBatchSize"] = "\(batchSize)"
        }
        
        // Validate hardware compatibility
        if let hardware = hardwareTarget {
            guard artifact.capability.hardwareCapability.supports(hardware) else {
                throw ValidationError.policyViolation("Hardware target \(hardware) not supported by capability \(artifact.capability.hardwareCapability.rawValue)")
            }
            
            // Check if performance profile exists for this hardware
            let hasProfile = artifact.capability.performanceProfiles.contains { $0.hardware == hardware }
            if !hasProfile {
                warnings.append("No performance profile for hardware target \(hardware)")
            }
            validationDetails["hardwareTarget"] = hardware
        }
        
        // Validate memory requirements
        let totalInputMemory = artifact.schema.inputs.reduce(0) { $0 + $1.memoryFootprint }
        let totalOutputMemory = artifact.schema.outputs.reduce(0) { $0 + $1.memoryFootprint }
        
        if Int64(totalInputMemory) > artifact.limits.hard.maxInputSizeBytes {
            throw ValidationError.policyViolation("Total input memory \(totalInputMemory) bytes exceeds hard limit \(artifact.limits.hard.maxInputSizeBytes) bytes")
        }
        
        if Int64(totalOutputMemory) > artifact.limits.hard.maxOutputSizeBytes {
            throw ValidationError.policyViolation("Total output memory \(totalOutputMemory) bytes exceeds hard limit \(artifact.limits.hard.maxOutputSizeBytes) bytes")
        }
        
        validationDetails["totalInputMemory"] = "\(totalInputMemory)"
        validationDetails["totalOutputMemory"] = "\(totalOutputMemory)"
        
        // Check platform constraints
        if !artifact.limits.platformConstraints.isEmpty {
            validationDetails["platformConstraints"] = "\(artifact.limits.platformConstraints.count) constraints"
        }
        
        // Add warnings to details if any
        if !warnings.isEmpty {
            validationDetails["warnings"] = warnings.joined(separator: "; ")
        }
        
        return ValidationReceipt(
            validationId: UUID().uuidString,
            validationType: "execution_preflight",
            result: warnings.isEmpty ? .passed : .warning,
            details: validationDetails
        )
    }
    
    /// Validates execution results against limits
    public func validateExecutionResults(
        actualInferenceTimeMs: Int64,
        actualMemoryBytes: Int64,
        hardwareUsed: String,
        inputBatchSize: Int? = nil
    ) -> (LimitsEnforcementResult, ValidationReceipt) {
        let limitsResult = artifact.limits.enforceLimits(
            actualBatchSize: inputBatchSize,
            actualMemoryBytes: actualMemoryBytes,
            actualInferenceTimeMs: actualInferenceTimeMs
        )
        
        var validationDetails: [String: String] = [
            "actualInferenceTimeMs": "\(actualInferenceTimeMs)",
            "actualMemoryBytes": "\(actualMemoryBytes)",
            "hardwareUsed": hardwareUsed
        ]
        
        if let batchSize = inputBatchSize {
            validationDetails["inputBatchSize"] = "\(batchSize)"
        }
        
        let result: ValidationResult
        switch limitsResult.violationType {
        case .hard:
            result = .failed
            validationDetails["hardViolations"] = limitsResult.violations.joined(separator: "; ")
        case .soft:
            result = .warning
            validationDetails["softWarnings"] = limitsResult.warnings.joined(separator: "; ")
        case .none:
            result = .passed
        }
        
        let receipt = ValidationReceipt(
            validationId: UUID().uuidString,
            validationType: "execution_postflight",
            result: result,
            details: validationDetails
        )
        
        return (limitsResult, receipt)
    }
    
    /// Validates tensor data against schema
    public func validateTensorData(
        tensorName: String,
        dataType: CoreMLDataType,
        shape: TensorShape,
        data: Data? = nil
    ) throws -> ValidationReceipt {
        // Find tensor spec
        let allTensors = artifact.schema.inputs + artifact.schema.outputs
        guard let tensorSpec = allTensors.first(where: { $0.name == tensorName }) else {
            throw ValidationError.schemaViolation("Tensor '\(tensorName)' not found in schema")
        }
        
        var validationDetails: [String: String] = [
            "tensorName": tensorName,
            "expectedDataType": tensorSpec.dataType.rawValue,
            "actualDataType": dataType.rawValue,
            "expectedShape": "batch:\(tensorSpec.shape.batch), channels:\(tensorSpec.shape.channels), height:\(tensorSpec.shape.height), width:\(tensorSpec.shape.width)",
            "actualShape": "batch:\(shape.batch), channels:\(shape.channels), height:\(shape.height), width:\(shape.width)"
        ]
        
        // Validate data type
        guard dataType == tensorSpec.dataType else {
            throw ValidationError.schemaViolation("Data type mismatch for tensor '\(tensorName)': expected \(tensorSpec.dataType.rawValue), got \(dataType.rawValue)")
        }
        
        // Validate shape compatibility
        guard shape.channels == tensorSpec.shape.channels else {
            throw ValidationError.schemaViolation("Channels mismatch for tensor '\(tensorName)': expected \(tensorSpec.shape.channels), got \(shape.channels)")
        }
        
        guard shape.height == tensorSpec.shape.height else {
            throw ValidationError.schemaViolation("Height mismatch for tensor '\(tensorName)': expected \(tensorSpec.shape.height), got \(shape.height)")
        }
        
        guard shape.width == tensorSpec.shape.width else {
            throw ValidationError.schemaViolation("Width mismatch for tensor '\(tensorName)': expected \(tensorSpec.shape.width), got \(shape.width)")
        }
        
        // Validate batch size (allow dynamic batch -1 to match any positive batch)
        if tensorSpec.shape.batch != -1 {
            guard shape.batch == tensorSpec.shape.batch else {
                throw ValidationError.schemaViolation("Batch size mismatch for tensor '\(tensorName)': expected \(tensorSpec.shape.batch), got \(shape.batch)")
            }
        } else if shape.batch <= 0 {
            throw ValidationError.schemaViolation("Batch size must be positive for tensor '\(tensorName)', got \(shape.batch)")
        }
        
        // Validate data size if provided
        if let data = data {
            let expectedSize = shape.elementCount * dataType.byteSize
            guard data.count == expectedSize else {
                throw ValidationError.schemaViolation("Data size mismatch for tensor '\(tensorName)': expected \(expectedSize) bytes, got \(data.count) bytes")
            }
            validationDetails["dataSize"] = "\(data.count) bytes"
        }
        
        return ValidationReceipt(
            validationId: UUID().uuidString,
            validationType: "tensor_validation",
            result: .passed,
            details: validationDetails
        )
    }
}

// MARK: - CoreML Artifact Contract

/// Complete CoreML artifact specification with 5 SURFACE layers
public struct CoreMLArtifact: Sendable, Codable {
    /// Unique artifact identifier
    public let artifactId: String
    /// Model file hash
    public let modelHash: String
    /// Schema layer
    public let schema: CoreMLSchema
    /// Limits layer
    public let limits: CoreMLLimits
    /// Versioning layer
    public let versioning: CoreMLVersion
    /// Capability layer
    public let capability: CoreMLCapability
    /// Receipts layer
    public let receipts: CoreMLReceipts
    /// Creation metadata
    public let metadata: [String: String]
    /// Creation timestamp
    public let createdAt: Date
    
    public init(artifactId: String, modelHash: String, schema: CoreMLSchema, limits: CoreMLLimits, versioning: CoreMLVersion, capability: CoreMLCapability, receipts: CoreMLReceipts = CoreMLReceipts(), metadata: [String: String] = [:], createdAt: Date = Date()) {
        self.artifactId = artifactId
        self.modelHash = modelHash
        self.schema = schema
        self.limits = limits
        self.versioning = versioning
        self.capability = capability
        self.receipts = receipts
        self.metadata = metadata
        self.createdAt = createdAt
    }
    
    /// Computes artifact hash
    public var artifactHash: String {
        var components: [String] = []
        components.append(artifactId)
        components.append(modelHash)
        components.append(schema.schemaHash)
        components.append(versioning.versionHash)
        
        let sortedMetadata = metadata.sorted { $0.key < $1.key }
        for (key, value) in sortedMetadata {
            components.append("\(key):\(value)")
        }
        
        let combined = components.joined(separator: "|")
        return BLAKE3Digest.hex(of: Data(combined.utf8))
    }
}

/// CoreML Artifact Contract implementing WorkflowContract
public struct CoreMLArtifactContract: WorkflowContract {
    public static let id = ContractID(
        name: "coreml.artifact",
        major: 1,
        minor: 0,
        schemaHash: "v1.0"
    )
    
    public let payload: CoreMLArtifact
    
    public init(_ payload: CoreMLArtifact) {
        self.payload = payload
    }
    
    public static func validateInvariants(_ value: CoreMLArtifactContract) throws {
        let artifact = value.payload
        
        // Validate artifact hash matches computed hash
        guard artifact.artifactId == artifact.artifactHash else {
            throw ValidationError.invalidRequest("Artifact ID must match computed artifact hash")
        }
        
        // Validate each SURFACE layer
        try artifact.schema.validate()
        try artifact.limits.validate()
        try artifact.versioning.validate()
        try artifact.capability.validate()
        try artifact.receipts.validate()
        
        // Validate schema against limits
        let totalInputMemory = artifact.schema.inputs.reduce(0) { $0 + $1.memoryFootprint }
        let totalOutputMemory = artifact.schema.outputs.reduce(0) { $0 + $1.memoryFootprint }
        
        guard Int64(totalInputMemory) <= artifact.limits.hard.maxInputSizeBytes else {
            throw ValidationError.policyViolation("Total input memory \(totalInputMemory) bytes exceeds hard limit \(artifact.limits.hard.maxInputSizeBytes) bytes")
        }
        
        guard Int64(totalOutputMemory) <= artifact.limits.hard.maxOutputSizeBytes else {
            throw ValidationError.policyViolation("Total output memory \(totalOutputMemory) bytes exceeds hard limit \(artifact.limits.hard.maxOutputSizeBytes) bytes")
        }
        
        // Validate capability against schema
        for input in artifact.schema.inputs {
            guard input.shape.batch == -1 || input.shape.batch <= artifact.limits.hard.maxBatchSize || artifact.limits.hard.maxBatchSize == -1 else {
                throw ValidationError.policyViolation("Input batch size \(input.shape.batch) exceeds maximum batch size \(artifact.limits.hard.maxBatchSize)")
            }
        }
        
        // Validate receipts consistency
        for execution in artifact.receipts.executions {
            guard artifact.capability.hardwareCapability.supports(execution.hardwareUsed) else {
                throw ValidationError.invalidEvidence("Execution used hardware '\(execution.hardwareUsed)' not supported by capability '\(artifact.capability.hardwareCapability.rawValue)'")
            }
            
            // Validate execution metrics against limits
            let limitsResult = artifact.limits.enforceLimits(
                actualMemoryBytes: execution.actualMemoryBytes,
                actualInferenceTimeMs: execution.actualInferenceTimeMs
            )
            
            if case .hard = limitsResult.violationType {
                throw ValidationError.invalidEvidence("Execution receipt contains hard limit violations: \(limitsResult.violations.joined(separator: ", "))")
            }
        }
        
        // Validate model hash format (should be BLAKE3)
        guard artifact.modelHash.count == 64 else {
            throw ValidationError.invalidRequest("Model hash must be 64 characters (BLAKE3), got \(artifact.modelHash.count)")
        }
        
        // Validate all hex strings
        let hexCharacterSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        guard artifact.modelHash.rangeOfCharacter(from: hexCharacterSet.inverted) == nil else {
            throw ValidationError.invalidRequest("Model hash must contain only hex characters")
        }
        
        // Validate coordinate system consistency across tensors
        let allTensors = artifact.schema.inputs + artifact.schema.outputs
        let coordinateSystems = Set(allTensors.map { $0.coordinateSystem })
        if coordinateSystems.count > 1 {
            // Warn about mixed coordinate systems but don't fail
            // This is a soft validation that generates a warning receipt
            _ = ValidationReceipt(
                validationId: UUID().uuidString,
                validationType: "coordinate_system_consistency",
                result: .warning,
                details: ["warning": "Multiple coordinate systems detected in tensor specifications"]
            )
            // Note: We don't throw here, just document the warning
        }
        
        // Validate performance profiles against hardware capability
        for profile in artifact.capability.performanceProfiles {
            guard artifact.capability.hardwareCapability.supports(profile.hardware) else {
                throw ValidationError.policyViolation("Performance profile for hardware '\(profile.hardware)' not supported by capability '\(artifact.capability.hardwareCapability.rawValue)'")
            }
        }
        
        // Validate that required features are specified if ANE capability is declared
        if artifact.capability.hardwareCapability == .aneOnly || artifact.capability.hardwareCapability == .mixed {
            if artifact.capability.requiredFeatures.isEmpty {
                throw ValidationError.policyViolation("ANE-capable models must specify required features")
            }
        }
        
        // Validate timestamp consistency
        guard artifact.createdAt <= Date() else {
            throw ValidationError.invalidEvidence("Creation timestamp cannot be in the future")
        }
        
        for placement in artifact.receipts.placements {
            guard placement.timestamp <= Date() else {
                throw ValidationError.invalidEvidence("Placement timestamp cannot be in the future")
            }
        }
        
        for execution in artifact.receipts.executions {
            guard execution.timestamp <= Date() else {
                throw ValidationError.invalidEvidence("Execution timestamp cannot be in the future")
            }
        }
        
        for validation in artifact.receipts.validations {
            guard validation.timestamp <= Date() else {
                throw ValidationError.invalidEvidence("Validation timestamp cannot be in the future")
            }
        }
    }
}

// MARK: - Helper Extensions

extension CoreMLArtifactContract {
    /// Creates a validation receipt for this artifact
    public func createValidationReceipt(type: String, result: ValidationResult, details: [String: String] = [:]) -> ValidationReceipt {
        ValidationReceipt(
            validationId: UUID().uuidString,
            validationType: type,
            result: result,
            details: details
        )
    }
    
    /// Creates a placement receipt for this artifact
    public func createPlacementReceipt(targetLocation: String, checksum: String, metadata: [String: String] = [:]) -> PlacementReceipt {
        PlacementReceipt(
            placementId: UUID().uuidString,
            targetLocation: targetLocation,
            checksum: checksum,
            metadata: metadata
        )
    }
    
    /// Creates an execution receipt for this artifact
    public func createExecutionReceipt(inputHash: String, outputHash: String, hardwareUsed: String, actualInferenceTimeMs: Int64, actualMemoryBytes: Int64, success: Bool = true, errorMessage: String? = nil) -> CoreMLExecutionReceipt {
        CoreMLExecutionReceipt(
            executionId: UUID().uuidString,
            inputHash: inputHash,
            outputHash: outputHash,
            hardwareUsed: hardwareUsed,
            actualInferenceTimeMs: actualInferenceTimeMs,
            actualMemoryBytes: actualMemoryBytes,
            success: success,
            errorMessage: errorMessage
        )
    }
    
    /// Creates a runtime validator for this artifact
    public func createRuntimeValidator() -> CoreMLRuntimeValidator {
        CoreMLRuntimeValidator(artifact: payload)
    }
    
    /// Validates the artifact for execution with given parameters
    public func validateForExecution(
        inputBatchSize: Int? = nil,
        hardwareTarget: String? = nil
    ) throws -> ValidationReceipt {
        let validator = createRuntimeValidator()
        return try validator.validateForExecution(
            inputBatchSize: inputBatchSize,
            hardwareTarget: hardwareTarget
        )
    }
    
    /// Validates tensor data against artifact schema
    public func validateTensorData(
        tensorName: String,
        dataType: CoreMLDataType,
        shape: TensorShape,
        data: Data? = nil
    ) throws -> ValidationReceipt {
        let validator = createRuntimeValidator()
        return try validator.validateTensorData(
            tensorName: tensorName,
            dataType: dataType,
            shape: shape,
            data: data
        )
    }
    
    /// Enforces limits against actual runtime values
    public func enforceLimits(
        actualBatchSize: Int? = nil,
        actualMemoryBytes: Int64? = nil,
        actualInferenceTimeMs: Int64? = nil,
        actualModelSizeBytes: Int64? = nil,
        actualInputSizeBytes: Int64? = nil,
        actualOutputSizeBytes: Int64? = nil
    ) -> LimitsEnforcementResult {
        payload.limits.enforceLimits(
            actualBatchSize: actualBatchSize,
            actualMemoryBytes: actualMemoryBytes,
            actualInferenceTimeMs: actualInferenceTimeMs,
            actualModelSizeBytes: actualModelSizeBytes,
            actualInputSizeBytes: actualInputSizeBytes,
            actualOutputSizeBytes: actualOutputSizeBytes
        )
    }
    
    /// Generates a comprehensive validation report for the artifact
    public func generateValidationReport() -> ValidationReceipt {
        var details: [String: String] = [:]
        var warnings: [String] = []
        var result: ValidationResult = .passed
        
        // Validate schema
        do {
            try payload.schema.validate()
            details["schema"] = "valid"
        } catch {
            details["schema"] = "invalid: \(error)"
            result = .failed
        }
        
        // Validate limits
        do {
            try payload.limits.validate()
            details["limits"] = "valid"
        } catch {
            details["limits"] = "invalid: \(error)"
            result = .failed
        }
        
        // Validate versioning
        do {
            try payload.versioning.validate()
            details["versioning"] = "valid"
        } catch {
            details["versioning"] = "invalid: \(error)"
            result = .failed
        }
        
        // Validate capability
        do {
            try payload.capability.validate()
            details["capability"] = "valid"
        } catch {
            details["capability"] = "invalid: \(error)"
            result = .failed
        }
        
        // Validate receipts
        do {
            try payload.receipts.validate()
            details["receipts"] = "valid"
        } catch {
            details["receipts"] = "invalid: \(error)"
            result = .failed
        }
        
        // Check memory requirements
        let totalInputMemory = payload.schema.inputs.reduce(0) { $0 + $1.memoryFootprint }
        let totalOutputMemory = payload.schema.outputs.reduce(0) { $0 + $1.memoryFootprint }
        
        if Int64(totalInputMemory) > payload.limits.hard.maxInputSizeBytes {
            warnings.append("Total input memory \(totalInputMemory) bytes approaches hard limit \(payload.limits.hard.maxInputSizeBytes) bytes")
            result = .warning
        }
        
        if Int64(totalOutputMemory) > payload.limits.hard.maxOutputSizeBytes {
            warnings.append("Total output memory \(totalOutputMemory) bytes approaches hard limit \(payload.limits.hard.maxOutputSizeBytes) bytes")
            result = .warning
        }
        
        // Check batch size compatibility
        for input in payload.schema.inputs {
            if input.shape.batch != -1 && input.shape.batch > payload.limits.hard.maxBatchSize && payload.limits.hard.maxBatchSize != -1 {
                warnings.append("Input batch size \(input.shape.batch) exceeds maximum batch size \(payload.limits.hard.maxBatchSize)")
                result = .warning
            }
        }
        
        // Add warnings to details
        if !warnings.isEmpty {
            details["warnings"] = warnings.joined(separator: "; ")
        }
        
        return ValidationReceipt(
            validationId: UUID().uuidString,
            validationType: "comprehensive_validation",
            result: result,
            details: details
        )
    }
}
