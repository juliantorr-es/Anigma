// Copyright (c) 2025 Anigma
// Licensed under the MIT License




import AnigmaCore
import AnigmaPrimitives
import Foundation
import HarmoniaWorkflowContracts

// MARK: - Service Handler Protocol

public protocol ServiceHandler: Sendable {
    var serviceId: String { get }
    var descriptor: ServiceDescriptor { get }
    
    func execute(action: String, input: [String: AnyCodable]) async throws -> [String: AnyCodable]
    func getHealth() async throws -> HealthStatus
}

// MARK: - Service Registry (Thread-Safe)

public actor ServiceRegistry {
    private var services: [String: ServiceHandler] = [:]
    private var capabilities: [String: [String: ServiceCapability]] = [:]  // serviceId -> action -> capability
    
    public init() {}
    
    // MARK: - Registration
    
    public func register(service: ServiceHandler) throws {
        let serviceId = service.serviceId
        
        // Check for duplicate
        if services[serviceId] != nil {
            throw RegistryError.serviceAlreadyRegistered(serviceId)
        }
        
        services[serviceId] = service
        
        // Index capabilities
        var actionCapabilities: [String: ServiceCapability] = [:]
        for capability in service.descriptor.capabilities {
            actionCapabilities[capability.action] = capability
        }
        capabilities[serviceId] = actionCapabilities
    }
    
    public func unregister(serviceId: String) throws {
        guard services.removeValue(forKey: serviceId) != nil else {
            throw RegistryError.serviceNotFound(serviceId)
        }
        capabilities.removeValue(forKey: serviceId)
    }
    
    // MARK: - Queries
    
    public func getService(id: String) throws -> ServiceHandler {
        guard let service = services[id] else {
            throw RegistryError.serviceNotFound(id)
        }
        return service
    }
    
    public func getServicesByCapability(action: String) -> [ServiceHandler] {
        services.values.filter { service in
            service.descriptor.capabilities.contains { $0.action == action }
        }
    }
    
    public func getAllServices() -> [ServiceDescriptor] {
        services.values.map { $0.descriptor }
    }
    
    public func getCapability(serviceId: String, action: String) throws -> ServiceCapability {
        guard let actionCapabilities = capabilities[serviceId],
              let capability = actionCapabilities[action] else {
            throw RegistryError.capabilityNotFound(serviceId, action)
        }
        return capability
    }
    
    // MARK: - Health Management
    
    public func updateHealth(serviceId: String, status: HealthStatus) throws {
        guard var service = services[serviceId] else {
            throw RegistryError.serviceNotFound(serviceId)
        }
        
        // Update descriptor (requires re-registering or mutation capability)
        // This is a simplified version; real implementation might need mutable service state
    }
    
    public func getHealthyServices(forCapability action: String) -> [ServiceHandler] {
        getServicesByCapability(action: action).filter { service in
            service.descriptor.healthStatus != .unhealthy
        }
    }
    
    // MARK: - Statistics
    
    public var registeredServiceCount: Int {
        services.count
    }
    
    public func getRegistryStatistics() -> RegistryStatistics {
        let allServices = services.values
        let healthyCount = allServices.filter { $0.descriptor.healthStatus == .healthy }.count
        let totalCapabilities = allServices.reduce(0) { $0 + $1.descriptor.capabilities.count }
        
        return RegistryStatistics(
            totalServices: allServices.count,
            healthyServices: healthyCount,
            totalCapabilities: totalCapabilities
        )
    }
}

// MARK: - Registry Models

public struct RegistryStatistics: Sendable {
    public let totalServices: Int
    public let healthyServices: Int
    public let totalCapabilities: Int
    
    public var healthPercentage: Double {
        guard totalServices > 0 else { return 0 }
        return Double(healthyServices) / Double(totalServices) * 100
    }
}

// MARK: - Errors

public enum RegistryError: LocalizedError, Sendable {
    case serviceAlreadyRegistered(String)
    case serviceNotFound(String)
    case capabilityNotFound(String, String)
    case invalidServiceDescriptor(String)
    
    public var errorDescription: String? {
        switch self {
        case .serviceAlreadyRegistered(let id):
            return "Service already registered: \(id)"
        case .serviceNotFound(let id):
            return "Service not found: \(id)"
        case .capabilityNotFound(let serviceId, let action):
            return "Capability '\(action)' not found for service '\(serviceId)'"
        case .invalidServiceDescriptor(let reason):
            return "Invalid service descriptor: \(reason)"
        }
    }
}
