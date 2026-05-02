import Foundation
import ANEServicesCore
import CoreML
import ANECapsuleContracts
import ANECapabilityCatalog

/// Placement verifier for ANE compatibility checking of CoreML models.
/// Validates that models can run on requested compute units and provides
/// compatibility recommendations.
public actor PlacementVerifier {
    private let capabilityRegistry: ANECapabilityRegistry
    private var compatibilityCache: [String: CompatibilityResult] = [:] // modelPath -> result
    
    public init(capabilityRegistry: ANECapabilityRegistry = ANECapabilityRegistry()) {
        self.capabilityRegistry = capabilityRegistry
    }
    
    /// Verify placement for a capsule with requested compute unit
    public func verifyPlacement(
        for descriptor: ANECapsuleDescriptor,
        requestedComputeUnit: ANEComputeUnit
    ) async throws {
        // Check gate status
        switch descriptor.gate.status {
        case .gated:
            throw PlacementError.gated(
                capsuleId: descriptor.id,
                reason: descriptor.gate.reason ?? "Access gated"
            )
        case .deprecated:
            throw PlacementError.deprecated(
                capsuleId: descriptor.id,
                reason: descriptor.gate.reason ?? "Capsule deprecated"
            )
        case .experimental, .open:
            // Continue verification
            break
        }
        
        // Check compute unit support
        guard descriptor.supportedComputeUnits.contains(requestedComputeUnit) else {
            throw PlacementError.unsupportedComputeUnit(
                capsuleId: descriptor.id,
                requested: requestedComputeUnit,
                supported: descriptor.supportedComputeUnits
            )
        }
        
        // Check system compatibility
        let compatibility = try await checkSystemCompatibility(for: requestedComputeUnit)
        guard compatibility.isCompatible else {
            throw PlacementError.systemIncompatible(
                computeUnit: requestedComputeUnit,
                reasons: compatibility.issues
            )
        }
        
        // Check resource availability
        let resourceCheck = try await checkResourceAvailability(for: requestedComputeUnit)
        guard resourceCheck.isAvailable else {
            throw PlacementError.resourceUnavailable(
                computeUnit: requestedComputeUnit,
                reasons: resourceCheck.issues
            )
        }
    }
    
    /// Verify CoreML model compatibility with ANE
    public func verifyCoreMLModel(
        at modelURL: URL,
        requestedComputeUnit: ANEComputeUnit = .neuralEngine
    ) async throws -> CoreMLCompatibilityResult {
        let cacheKey = "\(modelURL.path):\(requestedComputeUnit.rawValue)"
        
        // Check cache
        if let cached = compatibilityCache[cacheKey] {
            return CoreMLCompatibilityResult(
                isCompatible: cached.isCompatible,
                recommendedComputeUnit: cached.recommendedComputeUnit,
                issues: cached.issues,
                warnings: cached.warnings,
                modelMetadata: cached.modelMetadata
            )
        }
        
        // Load model metadata
        let metadata = try await loadCoreMLMetadata(at: modelURL)
        
        // Check compatibility
        let compatibility = try await checkCoreMLCompatibility(
            metadata: metadata,
            requestedComputeUnit: requestedComputeUnit
        )
        
        // Cache result
        compatibilityCache[cacheKey] = compatibility
        
        return CoreMLCompatibilityResult(
            isCompatible: compatibility.isCompatible,
            recommendedComputeUnit: compatibility.recommendedComputeUnit,
            issues: compatibility.issues,
            warnings: compatibility.warnings,
            modelMetadata: metadata
        )
    }
    
    /// Get placement recommendations for a capsule
    public func getPlacementRecommendations(
        for descriptor: ANECapsuleDescriptor,
        constraints: PlacementConstraints? = nil
    ) async -> PlacementRecommendation {
        let constraints = constraints ?? PlacementConstraints()
        var recommendations: [ComputeUnitRecommendation] = []
        
        for computeUnit in descriptor.supportedComputeUnits.sorted(by: { $0.rawValue < $1.rawValue }) {
            do {
                let compatibility = try await checkSystemCompatibility(for: computeUnit)
                let resourceCheck = try await checkResourceAvailability(for: computeUnit)
                
                if compatibility.isCompatible && resourceCheck.isAvailable {
                    let score = calculateRecommendationScore(
                        for: computeUnit,
                        descriptor: descriptor,
                        compatibility: compatibility,
                        resourceCheck: resourceCheck,
                        constraints: constraints
                    )
                    
                    let recommendation = ComputeUnitRecommendation(
                        computeUnit: computeUnit,
                        score: score,
                        compatibility: compatibility,
                        resourceAvailability: resourceCheck,
                        estimatedPerformance: estimatePerformance(
                            for: computeUnit,
                            descriptor: descriptor
                        ),
                        estimatedPower: estimatePowerConsumption(
                            for: computeUnit,
                            descriptor: descriptor
                        )
                    )
                    
                    recommendations.append(recommendation)
                }
            } catch {
                // Skip incompatible units
                continue
            }
        }
        
        // Sort by score (descending)
        recommendations.sort { $0.score > $1.score }
        
        return PlacementRecommendation(
            capsuleId: descriptor.id,
            recommendations: recommendations,
            constraints: constraints
        )
    }
    
    // MARK: - Private Methods
    
    private func checkSystemCompatibility(for computeUnit: ANEComputeUnit) async throws -> SystemCompatibility {
        var issues: [String] = []
        var warnings: [String] = []
        
        switch computeUnit {
        case .neuralEngine:
            #if os(macOS)
            // Check for ANE availability on macOS
            if #available(macOS 14.0, *) {
                // macOS 14+ has ANE support on Apple Silicon
                let processInfo = ProcessInfo.processInfo
                if processInfo.isiOSAppOnMac || processInfo.isMacCatalystApp {
                    warnings.append("Running in compatibility mode on macOS")
                }
            } else {
                issues.append("ANE requires macOS 14.0 or later")
            }
            #else
            issues.append("ANE not available on this platform")
            #endif
            
            // Check CoreML version
            if #available(macOS 11.0, iOS 14.0, *) {
                // CoreML with ANE support available
            } else {
                issues.append("CoreML with ANE support requires macOS 11.0/iOS 14.0 or later")
            }
            
        case .gpu:
            #if canImport(Metal)
            // Metal GPU available
            #else
            issues.append("Metal GPU not available on this platform")
            #endif
            
        case .cpu:
            // CPU is always available
            break
            
        case .all:
            // Check all units
            break
        }
        
        return SystemCompatibility(
            computeUnit: computeUnit,
            isCompatible: issues.isEmpty,
            issues: issues,
            warnings: warnings
        )
    }
    
    private func checkResourceAvailability(for computeUnit: ANEComputeUnit) async throws -> ResourceAvailability {
        let issues: [String] = []
        var warnings: [String] = []
        var metrics: [String: Double] = [:]
        
        let processInfo = ProcessInfo.processInfo
        
        switch computeUnit {
        case .neuralEngine:
            // Check thermal state
            let thermalState = processInfo.thermalState
            if thermalState == .critical || thermalState == .serious {
                warnings.append("High thermal state: \(thermalState)")
            }
            
            // Check power state
            if processInfo.isLowPowerModeEnabled {
                warnings.append("Low power mode enabled - ANE performance may be limited")
            }
            
            // Estimate ANE availability (simplified)
            metrics["thermal_state"] = Double(thermalState.rawValue)
            metrics["low_power_mode"] = processInfo.isLowPowerModeEnabled ? 1.0 : 0.0
            
        case .gpu:
            // GPU-specific checks
            #if canImport(Metal)
            // In a real implementation, check Metal device properties
            warnings.append("GPU resource check not fully implemented")
            #endif
            
        case .cpu:
            // Check CPU load
            let load = systemLoadAverage()
            if load.0 > 0.8 { // 1-minute load average > 80%
                warnings.append("High CPU load: \(String(format: "%.2f", load.0))")
            }
            
            metrics["load_1min"] = load.0
            metrics["load_5min"] = load.1
            metrics["load_15min"] = load.2
            
            // Check memory pressure
            #if os(macOS)
            let memoryPressure = systemMemoryPressure()
            if memoryPressure > 0.7 {
                warnings.append("High memory pressure: \(String(format: "%.1f%%", memoryPressure * 100))")
            }
            metrics["memory_pressure"] = memoryPressure
            #endif
            
        case .all:
            // Check all resources
            break
        }
        
        return ResourceAvailability(
            computeUnit: computeUnit,
            isAvailable: issues.isEmpty,
            issues: issues,
            warnings: warnings,
            metrics: metrics
        )
    }
    
    private func loadCoreMLMetadata(at modelURL: URL) async throws -> CoreMLModelMetadata {
        #if canImport(CoreML)
        do {
            let compiledURL = try await MLModel.compileModel(at: modelURL)
            let model = try MLModel(contentsOf: compiledURL)
            let description = model.modelDescription
            
            return CoreMLModelMetadata(
                inputDescriptions: description.inputDescriptionsByName,
                outputDescriptions: description.outputDescriptionsByName,
                metadata: description.metadata,
                isUpdatable: description.isUpdatable,
                supportsANE: checkModelSupportsANE(description),
                modelSize: try modelURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            )
        } catch {
            throw PlacementError.modelLoadFailed(modelURL: modelURL, error: error)
        }
        #else
        throw PlacementError.coreMLNotAvailable
        #endif
    }
    
    private func checkCoreMLCompatibility(
        metadata: CoreMLModelMetadata,
        requestedComputeUnit: ANEComputeUnit
    ) async throws -> CompatibilityResult {
        var issues: [String] = []
        var warnings: [String] = []
        var recommendedUnit = requestedComputeUnit
        
        // Check ANE support
        if requestedComputeUnit == .neuralEngine && !metadata.supportsANE {
            issues.append("Model does not support ANE acceleration")
            recommendedUnit = .cpu // Fallback recommendation
            
            if metadata.modelSize > 100 * 1024 * 1024 { // 100MB
                warnings.append("Large model size (\(metadata.modelSize) bytes) may impact CPU performance")
            }
        }
        
        // Check model complexity
        let complexity = estimateModelComplexity(metadata: metadata)
        if complexity > 100_000_000 && requestedComputeUnit == .cpu { // 100M ops
            warnings.append("High model complexity may cause performance issues on CPU")
        }
        
        // Check input/output types
        for (name, description) in metadata.inputDescriptions {
            if description.type == .image {
                warnings.append("Image input '\(name)' may have specialized acceleration requirements")
            }
        }
        
        return CompatibilityResult(
            isCompatible: issues.isEmpty,
            recommendedComputeUnit: recommendedUnit,
            issues: issues,
            warnings: warnings,
            modelMetadata: metadata
        )
    }
    
    private func checkModelSupportsANE(_ description: MLModelDescription) -> Bool {
        #if canImport(CoreML)
        // Check if model supports ANE
        // This is a simplified check - real implementation would examine model architecture
        let metadata = description.metadata
        
        // Check for ANE-specific metadata
        if let author = metadata[.author] as? String,
           author.lowercased().contains("ane") || author.lowercased().contains("neural") {
            return true
        }
        
        // Check model size and complexity hints
        let totalParams = estimateParameterCount(from: description)
        return totalParams < 500_000_000 // ANE typically handles up to ~500M parameters well
        #else
        return false
        #endif
    }
    
    private func estimateModelComplexity(metadata: CoreMLModelMetadata) -> Int {
        // Simplified complexity estimation
        var totalOps = 0
        
        for (_, inputDesc) in metadata.inputDescriptions {
            if let constraint = inputDesc.multiArrayConstraint {
                let shape = constraint.shape
                let elementCount = shape.reduce(1) { $0 * $1.intValue }
                totalOps += elementCount * 10 // Rough estimate
            }
        }
        
        return totalOps
    }
    
    private func estimateParameterCount(from description: MLModelDescription) -> Int {
        // Simplified parameter count estimation
        var totalParams = 0
        
        for (_, outputDesc) in description.outputDescriptionsByName {
            if let constraint = outputDesc.multiArrayConstraint {
                let shape = constraint.shape
                let params = shape.reduce(1) { $0 * $1.intValue }
                totalParams += params
            }
        }
        
        return totalParams
    }
    
    private func calculateRecommendationScore(
        for computeUnit: ANEComputeUnit,
        descriptor: ANECapsuleDescriptor,
        compatibility: SystemCompatibility,
        resourceCheck: ResourceAvailability,
        constraints: PlacementConstraints
    ) -> Double {
        var score = 0.0
        
        // Base score for compute unit preference
        if computeUnit == descriptor.defaultComputeUnit {
            score += 100.0
        }
        
        // Performance consideration
        switch computeUnit {
        case .neuralEngine:
            score += 90.0
        case .gpu:
            score += 80.0
        case .cpu:
            score += 60.0
        case .all:
            score += 70.0
        }
        
        // Resource availability adjustment
        if !resourceCheck.warnings.isEmpty {
            score -= Double(resourceCheck.warnings.count) * 5.0
        }
        
        // Constraint matching
        if let preferredUnit = constraints.preferredComputeUnit,
           computeUnit == preferredUnit {
            score += 50.0
        }
        
        if let maxPower = constraints.maxPowerWatts {
            let estimatedPower = estimatePowerConsumption(for: computeUnit, descriptor: descriptor)
            if estimatedPower <= maxPower {
                score += 30.0
            } else {
                score -= 50.0
            }
        }
        
        if let maxMemory = constraints.maxMemoryMB {
            // Simplified memory estimation
            let estimatedMemory = estimateMemoryUsage(for: computeUnit, descriptor: descriptor)
            if estimatedMemory <= maxMemory {
                score += 20.0
            } else {
                score -= 40.0
            }
        }
        
        return max(score, 0.0)
    }
    
    private func estimatePerformance(
        for computeUnit: ANEComputeUnit,
        descriptor: ANECapsuleDescriptor
    ) -> PerformanceEstimate {
        // Simplified performance estimation
        switch computeUnit {
        case .neuralEngine:
            return PerformanceEstimate(
                latencyMs: 5.0,
                throughput: 200.0,
                confidence: 0.8
            )
        case .gpu:
            return PerformanceEstimate(
                latencyMs: 10.0,
                throughput: 100.0,
                confidence: 0.7
            )
        case .cpu:
            return PerformanceEstimate(
                latencyMs: 50.0,
                throughput: 20.0,
                confidence: 0.9
            )
        case .all:
            return PerformanceEstimate(
                latencyMs: 20.0,
                throughput: 50.0,
                confidence: 0.6
            )
        }
    }
    
    private func estimatePowerConsumption(
        for computeUnit: ANEComputeUnit,
        descriptor: ANECapsuleDescriptor
    ) -> Double {
        // Simplified power estimation (watts)
        switch computeUnit {
        case .neuralEngine: return 4.0
        case .gpu: return 8.0
        case .cpu: return 6.0
        case .all: return 6.0 // Average
        }
    }
    
    private func estimateMemoryUsage(
        for computeUnit: ANEComputeUnit,
        descriptor: ANECapsuleDescriptor
    ) -> Int {
        // Simplified memory estimation (MB)
        switch computeUnit {
        case .neuralEngine: return 256
        case .gpu: return 512
        case .cpu: return 1024
        case .all: return 512 // Conservative
        }
    }
    
    private func systemLoadAverage() -> (Double, Double, Double) {
        var loadavg = [Double](repeating: 0, count: 3)
        if getloadavg(&loadavg, 3) > 0 {
            return (loadavg[0], loadavg[1], loadavg[2])
        }
        return (0.0, 0.0, 0.0)
    }
    
    #if os(macOS)
    private func systemMemoryPressure() -> Double {
        // Simplified memory pressure estimation
        // Note: ProcessInfo doesn't provide freeMemory, so we use a simplified approach
        let processInfo = ProcessInfo.processInfo
        let totalMemory = processInfo.physicalMemory
        
        // For simplified estimation, assume 70% usage as a reasonable default
        // In a real implementation, this would use platform-specific APIs to get actual free memory
        let estimatedUsedMemory = totalMemory * 7 / 10
        
        return Double(estimatedUsedMemory) / Double(totalMemory)
    }
    #endif
    
    private struct CompatibilityResult {
        let isCompatible: Bool
        let recommendedComputeUnit: ANEComputeUnit
        let issues: [String]
        let warnings: [String]
        let modelMetadata: CoreMLModelMetadata
    }
}
