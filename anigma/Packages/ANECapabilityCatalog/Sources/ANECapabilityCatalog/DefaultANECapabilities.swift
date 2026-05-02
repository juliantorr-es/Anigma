import Foundation
import ANEServicesCore
import CapsuleCore
import ANECapsuleContracts

public enum DefaultANECapabilities {
    public static let embeddingANEOnly = ANECapability(
        id: "anigma.capability.embedding.ane_only",
        displayName: "ANE-Only Embedding",
        level: .aneOnly,
        supportedComputeUnits: [.neuralEngine],
        preferredComputeUnit: .neuralEngine,
        supportsFallback: false,
        performanceProfile: [
            .neuralEngine: PerformanceProfile(
                opsPerSecond: 1_000_000_000,
                latencyMs: 2.5,
                throughput: 400,
                source: .estimated
            )
        ],
        memoryRequirements: [.neuralEngine: 256],
        powerProfile: [
            .neuralEngine: PowerProfile(
                powerWatts: 3.5,
                efficiency: 285_714_286,
                thermalProfile: .balanced
            )
        ],
        optimizationHints: OptimizationHints(
            preferredBatchSize: 32,
            useMixedPrecision: true,
            enableQuantization: true,
            memoryAlignment: 128,
            threadingConfig: ThreadingConfig(
                preferredThreadCount: 1,
                useThreadAffinity: true,
                threadPriority: .normal
            )
        )
    )
    
    public static let embeddingMixed = ANECapability(
        id: "anigma.capability.embedding.mixed",
        displayName: "Mixed ANE/CPU Embedding",
        level: .mixed,
        supportedComputeUnits: [.neuralEngine, .cpu],
        preferredComputeUnit: .neuralEngine,
        supportsFallback: true,
        performanceProfile: [
            .neuralEngine: PerformanceProfile(
                opsPerSecond: 1_000_000_000,
                latencyMs: 2.5,
                throughput: 400,
                source: .estimated
            ),
            .cpu: PerformanceProfile(
                opsPerSecond: 100_000_000,
                latencyMs: 25.0,
                throughput: 40,
                source: .estimated
            )
        ],
        memoryRequirements: [
            .neuralEngine: 256,
            .cpu: 512
        ],
        powerProfile: [
            .neuralEngine: PowerProfile(
                powerWatts: 3.5,
                efficiency: 285_714_286,
                thermalProfile: .balanced
            ),
            .cpu: PowerProfile(
                powerWatts: 8.0,
                efficiency: 12_500_000,
                thermalProfile: .warm
            )
        ]
    )
    
    public static let cpuOnly = ANECapability(
        id: "anigma.capability.cpu_only",
        displayName: "CPU-Only Computation",
        level: .cpuOnly,
        supportedComputeUnits: [.cpu],
        preferredComputeUnit: .cpu,
        supportsFallback: false,
        performanceProfile: [
            .cpu: PerformanceProfile(
                opsPerSecond: 100_000_000,
                latencyMs: 10.0,
                throughput: 100,
                source: .estimated
            )
        ],
        memoryRequirements: [.cpu: 256],
        powerProfile: [
            .cpu: PowerProfile(
                powerWatts: 6.0,
                efficiency: 16_666_667,
                thermalProfile: .balanced
            )
        ]
    )
    
    public static func defaultForLevel(_ level: ANECapabilityLevel) -> ANECapability {
        switch level {
        case .aneOnly:
            return embeddingANEOnly
        case .mixed:
            return embeddingMixed
        case .cpuOnly:
            return cpuOnly
        }
    }
}
