/// DaemonKernel
///
/// The minimal runtime kernel for the Anigma daemon.
/// Owns lifecycle, feature registration, and core infrastructure.
/// Does NOT import feature implementations.
///
/// This kernel implements static plugin architecture:
/// - Features register through DaemonFeatureRegistrar protocol
/// - Feature implementation modules are imported only by wiring targets
/// - The kernel executes registered workers/routes without direct feature imports

import Foundation
import DaemonFeatureContracts

/// Daemon lifecycle state
public enum DaemonPhase: Sendable, Equatable {
    case initializing
    case registering
    case ready
    case running
    case shutting_down
    case stopped
}

/// Daemon kernel actor
/// 
/// Manages:
/// - Feature registration
/// - Worker/route/tool/capability lifecycle
/// - Daemon startup/shutdown
/// - Inspection APIs for monitoring
public actor DaemonKernel {
    private let dispatchQueue: DispatchQueue
    private(set) var phase: DaemonPhase = .initializing
    private(set) var registry: DaemonFeatureRegistry = DaemonFeatureRegistry()
    private var registeredFeatures: [FeatureID] = []
    
    public init() {
        self.dispatchQueue = DispatchQueue(label: "com.anigma.daemon.kernel", attributes: .concurrent)
    }
    
    /// Register a single feature
    /// 
    /// - Parameters:
    ///   - feature: The feature type conforming to DaemonFeatureRegistrar
    /// - Throws: If registration fails or dependencies are not met
    public func registerFeature(_ feature: any DaemonFeatureRegistrar.Type) async throws {
        guard phase == .registering else {
            throw KernelError.notInRegistrationPhase(currentPhase: phase)
        }
        
        // Check dependencies
        for dependency in feature.dependencies {
            guard registeredFeatures.contains(dependency) else {
                throw KernelError.missingDependency(featureID: feature.featureID, missing: dependency)
            }
        }
        
        // Register the feature
        try feature.register(into: &registry)
        registeredFeatures.append(feature.featureID)
        
        // Record manifest. The manifest is intentionally narrow for now; the
        // registry remains the source of truth for the full registration set.
        let manifest = FeatureManifest(featureID: feature.featureID)
        registry.recordManifest(manifest)
    }
    
    /// Execute a registered worker
    /// 
    /// - Parameters:
    ///   - kind: The worker kind to execute
    ///   - input: The input for the worker
    /// - Returns: The output from the worker
    /// - Throws: If worker is not found or execution fails
    public func executeWorker(kind: String, input: JobInput) async throws -> JobOutput {
        guard phase == .running || phase == .ready else {
            throw KernelError.kernelNotReady(currentPhase: phase)
        }
        
        // This would need access to the workers through the registry
        // For now, this is a placeholder for the actual dispatch logic
        throw KernelError.workerNotFound(kind)
    }
    
    /// Start the kernel
    /// 
    /// Transitions from initializing -> registering (ready for feature registration)
    public func start() async {
        phase = .registering
    }
    
    /// Finish registration and mark the kernel as ready
    /// 
    /// After this, no more features can be registered.
    public func finishRegistration() async throws {
        guard phase == .registering else {
            throw KernelError.notInRegistrationPhase(currentPhase: phase)
        }
        phase = .ready
    }
    
    /// Transition kernel to running state
    public func run() async throws {
        guard phase == .ready else {
            throw KernelError.invalidStateTransition(from: phase, to: .running)
        }
        phase = .running
    }
    
    /// Shut down the kernel
    public func shutdown() async throws {
        guard phase == .running || phase == .ready else {
            throw KernelError.invalidStateTransition(from: phase, to: .shutting_down)
        }
        phase = .shutting_down
        // TODO: Cleanup resources
        phase = .stopped
    }
    
    // MARK: - Inspection APIs
    
    /// Get current phase
    public func getPhase() -> DaemonPhase {
        phase
    }
    
    /// List all registered features
    public func listFeatures() -> [FeatureID] {
        registeredFeatures
    }
    
    /// List all registered worker kinds
    public func listWorkers() -> [String] {
        registry.listWorkerKinds()
    }
    
    /// List all registered routes
    public func listRoutes() -> [(path: String, method: String)] {
        registry.listRoutes()
    }
    
    /// List all registered tools
    public func listTools() -> [String] {
        registry.listToolIDs()
    }
    
    /// List all registered capabilities
    public func listCapabilities() -> [String] {
        registry.listCapabilityIDs()
    }
    
    /// Get feature manifests for inspection
    public func inspectFeatures() -> [FeatureID: FeatureManifest] {
        registry.inspectFeatures()
    }
}

/// Kernel-specific errors
public enum KernelError: LocalizedError, Sendable {
    case notInRegistrationPhase(currentPhase: DaemonPhase)
    case missingDependency(featureID: FeatureID, missing: FeatureID)
    case kernelNotReady(currentPhase: DaemonPhase)
    case workerNotFound(String)
    case invalidStateTransition(from: DaemonPhase, to: DaemonPhase)
    
    public var errorDescription: String? {
        switch self {
        case .notInRegistrationPhase(let phase):
            return "Cannot register feature: kernel is in \(phase) phase, not registering"
        case .missingDependency(let feature, let missing):
            return "Feature '\(feature)' requires feature '\(missing)' to be registered first"
        case .kernelNotReady(let phase):
            return "Kernel is not ready (phase: \(phase))"
        case .workerNotFound(let kind):
            return "Worker kind '\(kind)' is not registered"
        case .invalidStateTransition(let from, let to):
            return "Cannot transition from \(from) to \(to)"
        }
    }
}

// MARK: - Bootstrap Helper

/// Helper to bootstrap daemon kernel with a set of features
/// 
/// Usage:
/// ```swift
/// let kernel = DaemonKernel()
/// try await bootstrapKernel(kernel, with: [
///     ModelRegistryFeature.self,
///     HarmoniaDaemonFeature.self,
/// ])
/// ```
public func bootstrapKernel(
    _ kernel: DaemonKernel,
    with features: [any DaemonFeatureRegistrar.Type]
) async throws {
    await kernel.start()
    
    for feature in features {
        try await kernel.registerFeature(feature)
    }
    
    try await kernel.finishRegistration()
    try await kernel.run()
}
