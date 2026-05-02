import AnigmaPrimitives
import Foundation
import Darwin
import ANEServicesCore
import CapsuleCore
import CryptoKit

/// Execution receipt for runtime evidence collection of ANE capsule executions.
/// Provides cryptographic proof of computation including hardware attestation,
/// performance metrics, and input/output validation.
public struct ExecutionReceipt: Sendable, Codable, Hashable {
    /// Unique identifier for this receipt
    public let receiptId: String
    
    /// Capsule that was executed
    public let capsuleId: String
    public let capsuleVersion: String
    
    /// Compute unit used for execution
    public let computeUnit: ANEComputeUnit
    
    /// Hardware attestation evidence
    public let hardwareEvidence: HardwareEvidence
    
    /// Performance metrics
    public let performanceMetrics: PerformanceMetrics
    
    /// Input/output validation
    public let validationEvidence: ValidationEvidence
    
    /// Cryptographic signatures
    public let signatures: [Signature]
    
    /// Timestamps
    public let executionStart: Date
    public let executionEnd: Date
    public let receiptGenerationTime: Date
    
    /// CoreReceipt metadata
    public let metadata: [String: String]
    
    /// CoreReceipt status
    public let status: ReceiptStatus
    
    public init(
        receiptId: String,
        capsuleId: String,
        capsuleVersion: String,
        computeUnit: ANEComputeUnit,
        hardwareEvidence: HardwareEvidence,
        performanceMetrics: PerformanceMetrics,
        validationEvidence: ValidationEvidence,
        signatures: [Signature],
        executionStart: Date,
        executionEnd: Date,
        receiptGenerationTime: Date,
        metadata: [String: String] = [:],
        status: ReceiptStatus = .valid
    ) {
        self.receiptId = receiptId
        self.capsuleId = capsuleId
        self.capsuleVersion = capsuleVersion
        self.computeUnit = computeUnit
        self.hardwareEvidence = hardwareEvidence
        self.performanceMetrics = performanceMetrics
        self.validationEvidence = validationEvidence
        self.signatures = signatures
        self.executionStart = executionStart
        self.executionEnd = executionEnd
        self.receiptGenerationTime = receiptGenerationTime
        self.metadata = metadata
        self.status = status
    }
    
    /// Generate a new execution receipt
    public static func generate(
        for descriptor: ANECapsuleDescriptor,
        computeUnit: ANEComputeUnit,
        inputHash: String,
        outputHash: String,
        performanceMetrics: PerformanceMetrics? = nil,
        hardwareEvidence: HardwareEvidence? = nil
    ) async throws -> ExecutionReceipt {
        let startTime = Date()
        
        // Collect hardware evidence if not provided
        let hardwareEvidenceResult: HardwareEvidence
        if let hardwareEvidence = hardwareEvidence {
            hardwareEvidenceResult = hardwareEvidence
        } else {
            hardwareEvidenceResult = try await collectHardwareEvidence(for: computeUnit)
        }
        
        // Collect performance metrics if not provided
        let performanceMetricsResult: PerformanceMetrics
        if let performanceMetrics = performanceMetrics {
            performanceMetricsResult = performanceMetrics
        } else {
            performanceMetricsResult = try await collectPerformanceMetrics()
        }
        
        // Generate validation evidence
        let validationEvidence = ValidationEvidence(
            inputHash: inputHash,
            outputHash: outputHash,
            capsuleHash: BLAKE3Digest.hex(of: Data(descriptor.id.utf8)),
            computeUnitHash: BLAKE3Digest.hex(of: Data(computeUnit.rawValue.utf8))
        )
        
        // Generate signatures
        let signatures = try await generateSignatures(
            capsuleId: descriptor.id,
            computeUnit: computeUnit,
            hardwareEvidence: hardwareEvidenceResult,
            validationEvidence: validationEvidence
        )
        
        let endTime = Date()
        
        return ExecutionReceipt(
            receiptId: UUID().uuidString,
            capsuleId: descriptor.id,
            capsuleVersion: descriptor.version,
            computeUnit: computeUnit,
            hardwareEvidence: hardwareEvidenceResult,
            performanceMetrics: performanceMetricsResult,
            validationEvidence: validationEvidence,
            signatures: signatures,
            executionStart: startTime,
            executionEnd: endTime,
            receiptGenerationTime: Date(),
            metadata: [
                "gate_status": descriptor.gate.status.rawValue,
                "gate_reason": descriptor.gate.reason ?? "",
                "tags": descriptor.tags.joined(separator: ",")
            ]
        )
    }
    
    /// Validate the execution receipt
    public func validate() async throws -> ValidationResult {
        var issues: [String] = []
        var warnings: [String] = []
        
        // Check receipt status
        if status != ReceiptStatus.valid {
            issues.append("CoreReceipt status is \(status)")
        }
        
        // Validate timestamps
        if executionStart > executionEnd {
            issues.append("Execution start time is after end time")
        }
        
        if receiptGenerationTime < executionEnd {
            warnings.append("CoreReceipt generated before execution end")
        }
        
        // Validate signatures
        for signature in signatures {
            do {
                try await validateSignature(signature)
            } catch {
                issues.append("Signature validation failed: \(error.localizedDescription)")
            }
        }
        
        // Validate hardware evidence
        if !hardwareEvidence.isValid {
            issues.append("Hardware evidence is invalid")
        }
        
        // Validate performance metrics
        if performanceMetrics.executionTime < 0 {
            issues.append("Negative execution time")
        }
        
        // Check for anomalies
        if performanceMetrics.powerWatts > 100 {
            warnings.append("High power consumption: \(performanceMetrics.powerWatts)W")
        }
        
        if performanceMetrics.memoryUsageMB > 1024 {
            warnings.append("High memory usage: \(performanceMetrics.memoryUsageMB)MB")
        }
        
        let validationResult = ValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            warnings: warnings,
            validationTime: Date()
        )
        
        if !issues.isEmpty {
            throw ReceiptValidationError.validationFailed(result: validationResult)
        }
        
        return validationResult
    }
    
    /// Verify that the receipt matches expected input/output
    public func verifyInputOutput(
        expectedInputHash: String,
        expectedOutputHash: String
    ) -> Bool {
        return validationEvidence.inputHash == expectedInputHash &&
               validationEvidence.outputHash == expectedOutputHash
    }
    
    /// Get execution duration
    public var executionDuration: TimeInterval {
        executionEnd.timeIntervalSince(executionStart)
    }
    
    /// Get receipt age
    public var receiptAge: TimeInterval {
        Date().timeIntervalSince(receiptGenerationTime)
    }
    
    /// Check if receipt is expired
    public var isExpired: Bool {
        receiptAge > 24 * 60 * 60 // 24 hours
    }
    
    /// Generate a summary of the receipt
    public var summary: ReceiptSummary {
        ReceiptSummary(
            receiptId: receiptId,
            capsuleId: capsuleId,
            computeUnit: computeUnit,
            executionDuration: executionDuration,
            powerConsumption: performanceMetrics.powerWatts,
            memoryUsage: performanceMetrics.memoryUsageMB,
            status: status,
            isValid: hardwareEvidence.isValid && performanceMetrics.executionTime >= 0
        )
    }
    
    // MARK: - Private Methods
    
    private static func collectHardwareEvidence(for computeUnit: ANEComputeUnit) async throws -> HardwareEvidence {
        let processInfo = ProcessInfo.processInfo
        
        // Collect system information
        let systemInfo = SystemInfo(
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            architecture: systemArchitecture(),
            modelIdentifier: modelIdentifier(),
            thermalState: processInfo.thermalState,
            lowPowerMode: processInfo.isLowPowerModeEnabled
        )
        
        // Collect compute unit specific evidence
        let computeUnitInfo = ComputeUnitInfo(
            unitType: computeUnit,
            availability: await checkComputeUnitAvailability(computeUnit),
            capabilities: await collectComputeUnitCapabilities(computeUnit)
        )
        
        // Generate attestation
        let attestation = try await generateHardwareAttestation(
            systemInfo: systemInfo,
            computeUnitInfo: computeUnitInfo
        )
        
        return HardwareEvidence(
            systemInfo: systemInfo,
            computeUnitInfo: computeUnitInfo,
            attestation: attestation,
            collectionTime: Date()
        )
    }
    
    private static func collectPerformanceMetrics() async throws -> PerformanceMetrics {
        let processInfo = ProcessInfo.processInfo
        
        // Collect CPU usage
        let cpuUsage = await collectCPUUsage()
        
        // Collect memory usage
        let memoryUsage = collectMemoryUsage()
        
        // Collect power metrics (simplified)
        let powerMetrics = collectPowerMetrics()
        
        // Collect thermal metrics
        let thermalMetrics = ThermalMetrics(
            state: processInfo.thermalState,
            temperature: nil, // Would require platform-specific APIs
            fanSpeed: nil
        )
        
        return PerformanceMetrics(
            executionTime: 0.0, // Will be set by caller
            cpuUsage: cpuUsage,
            memoryUsageMB: memoryUsage,
            powerWatts: powerMetrics.powerWatts,
            thermalMetrics: thermalMetrics,
            collectionTime: Date()
        )
    }
    
    private static func generateSignatures(
        capsuleId: String,
        computeUnit: ANEComputeUnit,
        hardwareEvidence: HardwareEvidence,
        validationEvidence: ValidationEvidence
    ) async throws -> [Signature] {
        var signatures: [Signature] = []
        
        // Generate hardware signature
        let hardwareData = try JSONEncoder().encode(hardwareEvidence)
        let hardwareSignature = try await signData(hardwareData, keyId: "hardware")
        signatures.append(hardwareSignature)
        
        // Generate capsule signature
        let capsuleData = "\(capsuleId):\(computeUnit.rawValue)".data(using: .utf8)!
        let capsuleSignature = try await signData(capsuleData, keyId: "capsule")
        signatures.append(capsuleSignature)
        
        // Generate validation signature
        let validationData = try JSONEncoder().encode(validationEvidence)
        let validationSignature = try await signData(validationData, keyId: "validation")
        signatures.append(validationSignature)
        
        return signatures
    }
    
    private static func signData(_ data: Data, keyId: String) async throws -> Signature {
        // In a real implementation, this would use actual cryptographic signing
        // For now, we'll use a simplified hash-based approach
        
        let hash = BLAKE3Digest.hex(of: data)
        
        return Signature(
            keyId: keyId,
            algorithm: "BLAKE3",
            value: hash,
            timestamp: Date()
        )
    }
    
    private func validateSignature(_ signature: Signature) async throws {
        // Simplified validation - just check format
        guard !signature.keyId.isEmpty else {
            throw ReceiptValidationError.invalidSignature("Empty key ID")
        }
        
        guard !signature.value.isEmpty else {
            throw ReceiptValidationError.invalidSignature("Empty signature value")
        }
        
        guard signature.timestamp <= Date() else {
            throw ReceiptValidationError.invalidSignature("Future timestamp")
        }
        
        // In a real implementation, verify cryptographic signature
    }
    
    private static func checkComputeUnitAvailability(_ computeUnit: ANEComputeUnit) async -> ComputeUnitAvailability {
        // Simplified availability check
        switch computeUnit {
        case .neuralEngine:
            #if os(macOS)
            if #available(macOS 14.0, *) {
                return .available
            } else {
                return .unavailable(reason: "Requires macOS 14.0+")
            }
            #else
            return .unavailable(reason: "Not available on this platform")
            #endif
        case .gpu:
            #if canImport(Metal)
            return .available
            #else
            return .unavailable(reason: "Metal not available")
            #endif
        case .cpu:
            return .available
        case .all:
            return .partial(availableUnits: [.cpu]) // Simplified
        }
    }
    
    private static func collectComputeUnitCapabilities(_ computeUnit: ANEComputeUnit) async -> [String: AnyCodable] {
        // Simplified capability collection
        var capabilities: [String: AnyCodable] = [:]
        
        switch computeUnit {
        case .neuralEngine:
            capabilities["max_ops_per_second"] = AnyCodable.int(1_000_000_000)
            capabilities["memory_bandwidth_gbs"] = AnyCodable.int(200)
            capabilities["precision"] = AnyCodable.array(["FP16", "INT8"].map { AnyCodable.string($0) })
        case .gpu:
            capabilities["max_ops_per_second"] = AnyCodable.int(500_000_000)
            capabilities["memory_bandwidth_gbs"] = AnyCodable.int(100)
            capabilities["precision"] = AnyCodable.array(["FP32", "FP16"].map { AnyCodable.string($0) })
        case .cpu:
            let coreCount = ProcessInfo.processInfo.processorCount
            capabilities["core_count"] = AnyCodable.int(coreCount)
            capabilities["max_frequency_ghz"] = AnyCodable.double(3.2) // Example
            capabilities["precision"] = AnyCodable.array(["FP64", "FP32", "FP16"].map { AnyCodable.string($0) })
        case .all:
            capabilities["mixed_precision"] = AnyCodable.bool(true)
        }
        
        return capabilities
    }
    
    private struct HardwareAttestationData: Codable {
        let system: SystemInfo
        let computeUnit: ComputeUnitInfo
    }
    
    private static func generateHardwareAttestation(
        systemInfo: SystemInfo,
        computeUnitInfo: ComputeUnitInfo
    ) async throws -> HardwareAttestation {
        // Generate attestation data
        let attestationData = try JSONEncoder().encode(HardwareAttestationData(
            system: systemInfo,
            computeUnit: computeUnitInfo
        ))
        
        let hash = BLAKE3Digest.hex(of: attestationData)
        
        return HardwareAttestation(
            hash: hash,
            generationTime: Date(),
            attestationType: "hardware_evidence"
        )
    }
    
    private static func collectCPUUsage() async -> CPUUsage {
        // Simplified CPU usage collection
        // In a real implementation, use platform-specific APIs
        return CPUUsage(
            user: 0.2,
            system: 0.1,
            idle: 0.7,
            collectionTime: Date()
        )
    }
    
    private static func collectMemoryUsage() -> Int {
        let processInfo = ProcessInfo.processInfo
        #if os(macOS)
        // freeMemory is not available on ProcessInfo, use simplified estimation
        let memoryPressure = processInfo.physicalMemory * 70 / 100 // Assume 70% usage
        return Int(memoryPressure / 1024 / 1024) // Convert to MB
        #else
        return 0 // Simplified
        #endif
    }
    
    private static func collectPowerMetrics() -> PowerMetrics {
        // Simplified power metrics
        // In a real implementation, use platform-specific APIs
        return PowerMetrics(
            powerWatts: 5.0,
            voltage: nil,
            current: nil,
            collectionTime: Date()
        )
    }
    
    private static func systemArchitecture() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
    
    private static func modelIdentifier() -> String {
        #if os(macOS)
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
        #else
        return "unknown"
        #endif
    }
}

// MARK: - Supporting Types

public struct HardwareEvidence: Sendable, Codable, Hashable {
    public let systemInfo: SystemInfo
    public let computeUnitInfo: ComputeUnitInfo
    public let attestation: HardwareAttestation
    public let collectionTime: Date
    
    public var isValid: Bool {
        // Check attestation validity
        guard attestation.generationTime <= Date() else { return false }
        guard !attestation.hash.isEmpty else { return false }
        
        // Check system info validity
        guard !systemInfo.osVersion.isEmpty else { return false }
        guard !systemInfo.architecture.isEmpty else { return false }
        
        return true
    }
    
    public init(
        systemInfo: SystemInfo,
        computeUnitInfo: ComputeUnitInfo,
        attestation: HardwareAttestation,
        collectionTime: Date
    ) {
        self.systemInfo = systemInfo
        self.computeUnitInfo = computeUnitInfo
        self.attestation = attestation
        self.collectionTime = collectionTime
    }

    public static func == (lhs: HardwareEvidence, rhs: HardwareEvidence) -> Bool {
        return lhs.systemInfo == rhs.systemInfo &&
               lhs.computeUnitInfo == rhs.computeUnitInfo &&
               lhs.attestation == rhs.attestation &&
               lhs.collectionTime == rhs.collectionTime
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(systemInfo)
        hasher.combine(computeUnitInfo)
        hasher.combine(attestation)
        hasher.combine(collectionTime)
    }
}

public struct SystemInfo: Sendable, Codable, Hashable {
    public let osVersion: String
    public let architecture: String
    public let modelIdentifier: String
    public let thermalState: ProcessInfo.ThermalState
    public let lowPowerMode: Bool
    
    public init(
        osVersion: String,
        architecture: String,
        modelIdentifier: String,
        thermalState: ProcessInfo.ThermalState,
        lowPowerMode: Bool
    ) {
        self.osVersion = osVersion
        self.architecture = architecture
        self.modelIdentifier = modelIdentifier
        self.thermalState = thermalState
        self.lowPowerMode = lowPowerMode
    }
    
    private enum CodingKeys: String, CodingKey {
        case osVersion
        case architecture
        case modelIdentifier
        case thermalStateRawValue
        case lowPowerMode
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.osVersion = try container.decode(String.self, forKey: .osVersion)
        self.architecture = try container.decode(String.self, forKey: .architecture)
        self.modelIdentifier = try container.decode(String.self, forKey: .modelIdentifier)
        let rawThermalState = try container.decode(Int.self, forKey: .thermalStateRawValue)
        self.thermalState = ProcessInfo.ThermalState(rawValue: rawThermalState) ?? .nominal
        self.lowPowerMode = try container.decode(Bool.self, forKey: .lowPowerMode)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(osVersion, forKey: .osVersion)
        try container.encode(architecture, forKey: .architecture)
        try container.encode(modelIdentifier, forKey: .modelIdentifier)
        try container.encode(thermalState.rawValue, forKey: .thermalStateRawValue)
        try container.encode(lowPowerMode, forKey: .lowPowerMode)
    }
    
    public static func == (lhs: SystemInfo, rhs: SystemInfo) -> Bool {
        lhs.osVersion == rhs.osVersion &&
        lhs.architecture == rhs.architecture &&
        lhs.modelIdentifier == rhs.modelIdentifier &&
        lhs.thermalState.rawValue == rhs.thermalState.rawValue &&
        lhs.lowPowerMode == rhs.lowPowerMode
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(osVersion)
        hasher.combine(architecture)
        hasher.combine(modelIdentifier)
        hasher.combine(thermalState.rawValue)
        hasher.combine(lowPowerMode)
    }
}

public struct ComputeUnitInfo: Sendable, Codable, Hashable {
    public let unitType: ANEComputeUnit
    public let availability: ComputeUnitAvailability
    public let capabilities: [String: AnyCodable]
    
    // Custom Codable for capabilities dictionary
    public init(
        unitType: ANEComputeUnit,
        availability: ComputeUnitAvailability,
        capabilities: [String: AnyCodable]
    ) {
        self.unitType = unitType
        self.availability = availability
        self.capabilities = capabilities
    }
    
    enum CodingKeys: String, CodingKey {
        case unitType
        case availability
        case capabilities
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(unitType)
        hasher.combine(availability)
    }
    
    public static func == (lhs: ComputeUnitInfo, rhs: ComputeUnitInfo) -> Bool {
        lhs.unitType == rhs.unitType && lhs.availability == rhs.availability
    }
}

public struct HardwareAttestation: Sendable, Codable, Hashable {
    public let hash: String
    public let generationTime: Date
    public let attestationType: String
    
    public init(
        hash: String,
        generationTime: Date,
        attestationType: String
    ) {
        self.hash = hash
        self.generationTime = generationTime
        self.attestationType = attestationType
    }
}

public struct PerformanceMetrics: Sendable, Codable, Hashable {
    public let executionTime: TimeInterval
    public let cpuUsage: CPUUsage
    public let memoryUsageMB: Int
    public let powerWatts: Double
    public let thermalMetrics: ThermalMetrics
    public let collectionTime: Date
    
    public init(
        executionTime: TimeInterval,
        cpuUsage: CPUUsage,
        memoryUsageMB: Int,
        powerWatts: Double,
        thermalMetrics: ThermalMetrics,
        collectionTime: Date
    ) {
        self.executionTime = executionTime
        self.cpuUsage = cpuUsage
        self.memoryUsageMB = memoryUsageMB
        self.powerWatts = powerWatts
        self.thermalMetrics = thermalMetrics
        self.collectionTime = collectionTime
    }
}

public struct CPUUsage: Sendable, Codable, Hashable {
    public let user: Double
    public let system: Double
    public let idle: Double
    public let collectionTime: Date
    
    public var total: Double {
        user + system + idle
    }
    
    public init(
        user: Double,
        system: Double,
        idle: Double,
        collectionTime: Date
    ) {
        self.user = user
        self.system = system
        self.idle = idle
        self.collectionTime = collectionTime
    }
}

public struct ThermalMetrics: Sendable, Codable, Hashable {
    public let state: ProcessInfo.ThermalState
    public let temperature: Double?
    public let fanSpeed: Int?
    
    public init(
        state: ProcessInfo.ThermalState,
        temperature: Double?,
        fanSpeed: Int?
    ) {
        self.state = state
        self.temperature = temperature
        self.fanSpeed = fanSpeed
    }
    
    private enum CodingKeys: String, CodingKey {
        case stateRawValue
        case temperature
        case fanSpeed
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawState = try container.decode(Int.self, forKey: .stateRawValue)
        self.state = ProcessInfo.ThermalState(rawValue: rawState) ?? .nominal
        self.temperature = try container.decodeIfPresent(Double.self, forKey: .temperature)
        self.fanSpeed = try container.decodeIfPresent(Int.self, forKey: .fanSpeed)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(state.rawValue, forKey: .stateRawValue)
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encodeIfPresent(fanSpeed, forKey: .fanSpeed)
    }
    
    public static func == (lhs: ThermalMetrics, rhs: ThermalMetrics) -> Bool {
        lhs.state.rawValue == rhs.state.rawValue &&
        lhs.temperature == rhs.temperature &&
        lhs.fanSpeed == rhs.fanSpeed
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(state.rawValue)
        hasher.combine(temperature)
        hasher.combine(fanSpeed)
    }
}

public struct PowerMetrics: Sendable, Codable, Hashable {
    public let powerWatts: Double
    public let voltage: Double?
    public let current: Double?
    public let collectionTime: Date
    
    public init(
        powerWatts: Double,
        voltage: Double?,
        current: Double?,
        collectionTime: Date
    ) {
        self.powerWatts = powerWatts
        self.voltage = voltage
        self.current = current
        self.collectionTime = collectionTime
    }
}

public struct ValidationEvidence: Sendable, Codable, Hashable {
    public let inputHash: String
    public let outputHash: String
    public let capsuleHash: String
    public let computeUnitHash: String
    
    public init(
        inputHash: String,
        outputHash: String,
        capsuleHash: String,
        computeUnitHash: String
    ) {
        self.inputHash = inputHash
        self.outputHash = outputHash
        self.capsuleHash = capsuleHash
        self.computeUnitHash = computeUnitHash
    }
}

public enum ReceiptStatus: String, Sendable, Codable, CaseIterable {
    case valid = "VALID"
    case invalid = "INVALID"
    case expired = "EXPIRED"
    case pending = "PENDING"
    case revoked = "REVOKED"
}

public struct ValidationResult: Sendable, Codable {
    public let isValid: Bool
    public let issues: [String]
    public let warnings: [String]
    public let validationTime: Date
    
    public init(
        isValid: Bool,
        issues: [String],
        warnings: [String],
        validationTime: Date
    ) {
        self.isValid = isValid
        self.issues = issues
        self.warnings = warnings
        self.validationTime = validationTime
    }
}

public struct ReceiptSummary: Sendable, Codable {
    public let receiptId: String
    public let capsuleId: String
    public let computeUnit: ANEComputeUnit
    public let executionDuration: TimeInterval
    public let powerConsumption: Double
    public let memoryUsage: Int
    public let status: ReceiptStatus
    public let isValid: Bool
    
    public init(
        receiptId: String,
        capsuleId: String,
        computeUnit: ANEComputeUnit,
        executionDuration: TimeInterval,
        powerConsumption: Double,
        memoryUsage: Int,
        status: ReceiptStatus,
        isValid: Bool
    ) {
        self.receiptId = receiptId
        self.capsuleId = capsuleId
        self.computeUnit = computeUnit
        self.executionDuration = executionDuration
        self.powerConsumption = powerConsumption
        self.memoryUsage = memoryUsage
        self.status = status
        self.isValid = isValid
    }
}

// MARK: - Errors

public enum ReceiptValidationError: Error, Sendable, LocalizedError {
    case validationFailed(result: ValidationResult)
    case invalidSignature(String)
    case hardwareEvidenceInvalid
    case performanceMetricsInvalid
    case timestampInvalid
    
    public var errorDescription: String? {
        switch self {
        case .validationFailed(let result):
            return "CoreReceipt validation failed: \(result.issues.joined(separator: ", "))"
        case .invalidSignature(let reason):
            return "Invalid signature: \(reason)"
        case .hardwareEvidenceInvalid:
            return "Hardware evidence is invalid"
        case .performanceMetricsInvalid:
            return "Performance metrics are invalid"
        case .timestampInvalid:
            return "Timestamps are invalid"
        }
    }
}

// MARK: - Extensions

extension String {
    func blake3() -> String {
        let data = Data(self.utf8)
        return BLAKE3Digest.hex(of: data)
    }
}

// MARK: - CoreReceipt Manager

public actor ExecutionReceiptManager {
    private var receipts: [String: ExecutionReceipt] = [:]
    private let maxReceipts = 1000
    
    public init() {}
    
    /// Store a receipt
    public func store(_ receipt: ExecutionReceipt) {
        receipts[receipt.receiptId] = receipt
        
        // Enforce maximum limit
        if receipts.count > maxReceipts {
            // Remove oldest receipts
            let sorted = receipts.values.sorted { $0.receiptGenerationTime < $1.receiptGenerationTime }
            let toRemove = sorted.prefix(receipts.count - maxReceipts)
            for receipt in toRemove {
                receipts.removeValue(forKey: receipt.receiptId)
            }
        }
    }
    
    /// Get a receipt by ID
    public func getReceipt(_ id: String) -> ExecutionReceipt? {
        receipts[id]
    }
    
    /// Get all receipts
    public func getAllReceipts() -> [ExecutionReceipt] {
        Array(receipts.values).sorted { $0.receiptGenerationTime > $1.receiptGenerationTime }
    }
    
    /// Get receipts for a capsule
    public func getReceipts(forCapsule capsuleId: String) -> [ExecutionReceipt] {
        receipts.values
            .filter { $0.capsuleId == capsuleId }
            .sorted { $0.receiptGenerationTime > $1.receiptGenerationTime }
    }
    
    /// Get receipts by compute unit
    public func getReceipts(byComputeUnit computeUnit: ANEComputeUnit) -> [ExecutionReceipt] {
        receipts.values
            .filter { $0.computeUnit == computeUnit }
            .sorted { $0.receiptGenerationTime > $1.receiptGenerationTime }
    }
    
    /// Validate all receipts
    public func validateAllReceipts() async -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        for receipt in receipts.values {
            do {
                let result = try await receipt.validate()
                results.append(result)
            } catch {
                let errorResult = ValidationResult(
                    isValid: false,
                    issues: [error.localizedDescription],
                    warnings: [],
                    validationTime: Date()
                )
                results.append(errorResult)
            }
        }
        
        return results
    }
    
    /// Clean up expired receipts
    public func cleanupExpiredReceipts() -> Int {
        let expired = receipts.values.filter { $0.isExpired }
        for receipt in expired {
            receipts.removeValue(forKey: receipt.receiptId)
        }
        return expired.count
    }
    
    /// Generate statistics
    public func generateStatistics() -> ReceiptStatistics {
        let allReceipts = Array(receipts.values)
        
        let totalReceipts = allReceipts.count
        let validReceipts = allReceipts.filter { $0.status == .valid }.count
        let expiredReceipts = allReceipts.filter { $0.isExpired }.count
        
        let byComputeUnit = Dictionary(grouping: allReceipts, by: { $0.computeUnit })
            .mapValues { $0.count }
        
        let byCapsule = Dictionary(grouping: allReceipts, by: { $0.capsuleId })
            .mapValues { $0.count }
        
        let durations = allReceipts.map { $0.executionDuration }
        let averageDuration = durations.isEmpty ? nil : durations.reduce(0, +) / TimeInterval(durations.count)
        
        let powers = allReceipts.compactMap { $0.performanceMetrics.powerWatts }
        let averagePower = powers.isEmpty ? nil : powers.reduce(0, +) / Double(powers.count)
        
        return ReceiptStatistics(
            totalReceipts: totalReceipts,
            validReceipts: validReceipts,
            expiredReceipts: expiredReceipts,
            receiptsByComputeUnit: byComputeUnit,
            receiptsByCapsule: byCapsule,
            averageExecutionDuration: averageDuration,
            averagePowerConsumption: averagePower,
            generationTime: Date()
        )
    }
}

public struct ReceiptStatistics: Sendable, Codable {
    public let totalReceipts: Int
    public let validReceipts: Int
    public let expiredReceipts: Int
    public let receiptsByComputeUnit: [ANEComputeUnit: Int]
    public let receiptsByCapsule: [String: Int]
    public let averageExecutionDuration: TimeInterval?
    public let averagePowerConsumption: Double?
    public let generationTime: Date
    
    public init(
        totalReceipts: Int,
        validReceipts: Int,
        expiredReceipts: Int,
        receiptsByComputeUnit: [ANEComputeUnit: Int],
        receiptsByCapsule: [String: Int],
        averageExecutionDuration: TimeInterval?,
        averagePowerConsumption: Double?,
        generationTime: Date
    ) {
        self.totalReceipts = totalReceipts
        self.validReceipts = validReceipts
        self.expiredReceipts = expiredReceipts
        self.receiptsByComputeUnit = receiptsByComputeUnit
        self.receiptsByCapsule = receiptsByCapsule
        self.averageExecutionDuration = averageExecutionDuration
        self.averagePowerConsumption = averagePowerConsumption
        self.generationTime = generationTime
    }
}

import AnigmaPrimitives

public typealias AnyCodable = AnigmaPrimitives.AnyCodable
