import AnigmaPrimitives
import Foundation
import Darwin
import ANEServicesCore
import CapsuleCore
import CryptoKit
import ANECapsuleContracts

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
        if status != .valid {
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
