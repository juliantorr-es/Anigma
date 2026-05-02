// Copyright (c) 2025 Anigma
// Licensed under the MIT License

import HarmoniaCore
import HarmoniaSecurity
import HarmoniaInference
import AnigmaCore
import AnigmaPrimitives
import Foundation
import AccessumModule
import ObservatoriumModule

// MARK: - Service Adapter Factory

/// Factory for creating and registering service adapters
/// Provides convenient methods for setting up adapters with HarmoniaModule's ServiceRegistry
public actor ServiceAdapterFactory {
    // MARK: - Properties
    
    private let registry: ServiceRegistry
    private var createdAdapters: [String: ServiceHandler] = [:]
    
    // MARK: - Initialization
    
    /// Initialize the factory with a service registry
    /// - Parameter registry: The ServiceRegistry to register adapters with
    public init(registry: ServiceRegistry) {
        self.registry = registry
    }
    
    // MARK: - Adapter Creation & Registration
    
    /// Create and register AccessumServiceAdapter
    /// - Parameters:
    ///   - coordinator: Optional custom AccessumCoordinator
    ///   - autoRegister: Whether to immediately register with the registry
    /// - Returns: The created AccessumServiceAdapter
    public func createAccessumAdapter(
        coordinator: AccessumCoordinator = AccessumCoordinator(),
        autoRegister: Bool = true
    ) async throws -> AccessumServiceAdapter {
        let adapter = AccessumServiceAdapter(coordinator: coordinator)
        
        if autoRegister {
            try await registry.register(service: adapter)
        }
        
        createdAdapters[adapter.serviceId] = adapter
        return adapter
    }
    
    /// Create and register ObservatoriumServiceAdapter
    /// - Parameters:
    ///   - coordinator: Optional custom ObservatoriumCoordinator
    ///   - autoRegister: Whether to immediately register with the registry
    /// - Returns: The created ObservatoriumServiceAdapter
    public func createObservatoriumAdapter(
        coordinator: ObservatoriumCoordinator = ObservatoriumCoordinator(),
        autoRegister: Bool = true
    ) async throws -> ObservatoriumServiceAdapter {
        let adapter = ObservatoriumServiceAdapter(coordinator: coordinator)
        
        if autoRegister {
            try await registry.register(service: adapter)
        }
        
        createdAdapters[adapter.serviceId] = adapter
        return adapter
    }
    
    /// Create and register all standard adapters at once
    /// - Returns: Dictionary of service IDs to adapters
    public func createAllStandardAdapters() async throws -> [String: ServiceHandler] {
        let accessumAdapter = try await createAccessumAdapter()
        let observatoriumAdapter = try await createObservatoriumAdapter()
        
        return [
            accessumAdapter.serviceId: accessumAdapter,
            observatoriumAdapter.serviceId: observatoriumAdapter
        ]
    }
    
    // MARK: - Adapter Registration
    
    /// Register an existing adapter with the service registry
    /// - Parameter adapter: The ServiceHandler to register
    public func registerAdapter(_ adapter: ServiceHandler) async throws {
        try await registry.register(service: adapter)
        createdAdapters[adapter.serviceId] = adapter
    }
    
    /// Unregister an adapter from the service registry
    /// - Parameter serviceId: The service ID to unregister
    public func unregisterAdapter(_ serviceId: String) async throws {
        try await registry.unregister(serviceId: serviceId)
        createdAdapters.removeValue(forKey: serviceId)
    }
    
    // MARK: - Adapter Queries
    
    /// Get a previously created adapter by service ID
    /// - Parameter serviceId: The service ID to retrieve
    /// - Returns: The ServiceHandler if found
    public func getAdapter(_ serviceId: String) -> ServiceHandler? {
        createdAdapters[serviceId]
    }
    
    /// Get all created adapters
    /// - Returns: Dictionary of service IDs to adapters
    public func getAllAdapters() -> [String: ServiceHandler] {
        createdAdapters
    }
    
    /// Check if an adapter has been created
    /// - Parameter serviceId: The service ID to check
    public func hasAdapter(_ serviceId: String) -> Bool {
        createdAdapters[serviceId] != nil
    }
    
    // MARK: - Health Management
    
    /// Check health of all created adapters
    /// - Returns: Dictionary of service IDs to health statuses
    public func checkAllAdaptersHealth() async throws -> [String: HealthStatus] {
        var healthStatuses: [String: HealthStatus] = [:]
        
        for (serviceId, adapter) in createdAdapters {
            do {
                let status = try await adapter.getHealth()
                healthStatuses[serviceId] = status
            } catch {
                healthStatuses[serviceId] = .unhealthy
            }
        }
        
        return healthStatuses
    }
    
    /// Check health of a specific adapter
    /// - Parameter serviceId: The service ID to check
    /// - Returns: The HealthStatus
    public func checkAdapterHealth(_ serviceId: String) async throws -> HealthStatus {
        guard let adapter = createdAdapters[serviceId] else {
            throw FactoryError.adapterNotFound(serviceId)
        }
        return try await adapter.getHealth()
    }
    
    // MARK: - Factory Errors
    
    public enum FactoryError: LocalizedError, Sendable {
        case adapterNotFound(String)
        case adapterAlreadyExists(String)
        case registrationFailed(String, String)
        
        public var errorDescription: String? {
            switch self {
            case .adapterNotFound(let serviceId):
                return "Adapter not found: \(serviceId)"
            case .adapterAlreadyExists(let serviceId):
                return "Adapter already exists: \(serviceId)"
            case .registrationFailed(let serviceId, let reason):
                return "Failed to register adapter \(serviceId): \(reason)"
            }
        }
    }
}

// MARK: - Convenience Extension

extension ServiceAdapterFactory {
    /// Pre-configured Accessum capabilities
    public static let accessumCapabilities: [ServiceCapability] = [
        ServiceCapability(
            action: "assessContent",
            inputType: "[String: AnyCodable]",
            outputType: "[String: AnyCodable]",
            timeout: 30.0
        ),
        ServiceCapability(
            action: "createClient",
            inputType: "[String: AnyCodable]",
            outputType: "[String: AnyCodable]",
            timeout: 5.0
        ),
        ServiceCapability(
            action: "updateClient",
            inputType: "[String: AnyCodable]",
            outputType: "[String: AnyCodable]",
            timeout: 5.0
        )
    ]
    
    /// Pre-configured Observatorium capabilities
    public static let observatoriumCapabilities: [ServiceCapability] = [
        ServiceCapability(
            action: "recordEvent",
            inputType: "[String: AnyCodable]",
            outputType: "[String: AnyCodable]",
            timeout: 5.0
        ),
        ServiceCapability(
            action: "recordMetric",
            inputType: "[String: AnyCodable]",
            outputType: "[String: AnyCodable]",
            timeout: 5.0
        ),
        ServiceCapability(
            action: "getMetrics",
            inputType: "[String: AnyCodable]",
            outputType: "[String: AnyCodable]",
            timeout: 10.0
        ),
        ServiceCapability(
            action: "createAlert",
            inputType: "[String: AnyCodable]",
            outputType: "[String: AnyCodable]",
            timeout: 5.0
        ),
        ServiceCapability(
            action: "getActiveAlerts",
            inputType: "[String: AnyCodable]",
            outputType: "[String: AnyCodable]",
            timeout: 10.0
        )
    ]
    
    /// Create a factory and initialize with all standard adapters
    /// - Parameter registry: The ServiceRegistry to use
    /// - Returns: Configured factory with all adapters registered
    public static func createWithAllAdapters(registry: ServiceRegistry) async throws -> ServiceAdapterFactory {
        let factory = ServiceAdapterFactory(registry: registry)
        _ = try await factory.createAllStandardAdapters()
        return factory
    }
    
    /// Create a factory with only Accessum adapter
    /// - Parameter registry: The ServiceRegistry to use
    /// - Returns: Configured factory with Accessum adapter registered
    public static func createWithAccessumOnly(registry: ServiceRegistry) async throws -> ServiceAdapterFactory {
        let factory = ServiceAdapterFactory(registry: registry)
        _ = try await factory.createAccessumAdapter()
        return factory
    }
    
    /// Create a factory with only Observatorium adapter
    /// - Parameter registry: The ServiceRegistry to use
    /// - Returns: Configured factory with Observatorium adapter registered
    public static func createWithObservatoriumOnly(registry: ServiceRegistry) async throws -> ServiceAdapterFactory {
        let factory = ServiceAdapterFactory(registry: registry)
        _ = try await factory.createObservatoriumAdapter()
        return factory
    }
}
