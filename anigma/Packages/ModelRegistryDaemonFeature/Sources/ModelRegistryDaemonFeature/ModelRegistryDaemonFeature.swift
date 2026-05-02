/// ModelRegistryDaemonFeature
///
/// Static plugin wiring for ModelRegistry feature.
/// 
/// This demonstrates the static plugin architecture:
/// - The feature implementation is NOT imported by the kernel
/// - This wiring target imports the implementation AND the contracts
/// - Only the executable includes this wiring target
/// - Feature registers workers through the DaemonFeatureRegistrar protocol
///
/// This keeps DaemonKernel slim while allowing feature implementations
/// to remain independent.

import Foundation
import DaemonFeatureContracts
import ModelRegistry

/// ModelRegistry daemon feature
/// 
/// Registers model registry workers and routes with the daemon.
public struct ModelRegistryDaemonFeature: DaemonFeatureRegistrar {
    public static var featureID: FeatureID { "model-registry" }
    
    public static var dependencies: [FeatureID] { [] }
    
    /// Register ModelRegistry with the daemon
    /// 
    /// Registers:
    /// - model-query worker for querying models from registry
    /// - model-load worker for loading specific models
    public static func register(into registry: inout DaemonFeatureRegistry) throws {
        // Register model query worker
        registry.registerWorker(kind: "model-query") {
            ModelQueryWorker()
        }
        
        // Register model load worker
        registry.registerWorker(kind: "model-load") {
            ModelLoadWorker()
        }
        
        // Register capability for model management
        let metadata = CapabilityMetadata(
            description: "Manages ML model lifecycle and queries",
            requirements: []
        )
        registry.registerCapability(capabilityID: "model-management", metadata: metadata)
    }
}

// MARK: - Workers

/// Worker for querying models in the registry
struct ModelQueryWorker: JobWorker {
    func work(with input: JobInput) async throws -> JobOutput {
        // Placeholder: would use ModelRegistry.ModelRegistryStore to query models
        return JobOutput(result: ["models": AnyCodable([String]())])
    }
}

/// Worker for loading a specific model
struct ModelLoadWorker: JobWorker {
    func work(with input: JobInput) async throws -> JobOutput {
        // Placeholder: would use ModelRegistry to load a model
        return JobOutput(result: ["status": AnyCodable("loaded")])
    }
}
