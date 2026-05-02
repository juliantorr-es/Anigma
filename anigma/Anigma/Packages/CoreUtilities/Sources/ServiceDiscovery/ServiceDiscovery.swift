import Foundation
import CapsuleCore
import TelemetryCore

// MARK: - Service Discovery

/// Actor-based service discovery system for dynamic capsule loading
public actor ServiceDiscovery: Sendable {
    
    // MARK: - Properties
    
    /// Diagnostics for observability
    private let diagnostics: CapsuleDiagnostics
    
    /// Capsule registry for managing loaded capsules
    private let capsuleRegistry: CapsuleRegistry
    
    /// Configuration for service discovery
    private let configuration: ServiceDiscoveryConfiguration
    
    /// Registry of available services by capability
    private var serviceRegistry: [String: [ServiceInstance]] = [:]
    
    /// Service health monitor
    private let healthMonitor: ServiceHealthMonitor
    
    /// Dependency resolver
    private let dependencyResolver: DependencyResolver
    
    /// Service listeners
    private var serviceListeners: [ServiceDiscoveryListener] = []
    
    // MARK: - Initialization
    
    /// Initialize ServiceDiscovery
    /// - Parameters:
    ///   - diagnostics: Diagnostics collector for observability
    ///   - capsuleRegistry: Capsule registry for managing loaded capsules
    ///   - configuration: Service discovery configuration
    public init(
        diagnostics: CapsuleDiagnostics,
        capsuleRegistry: CapsuleRegistry,
        configuration: ServiceDiscoveryConfiguration = .default
    ) async throws {
        self.diagnostics = diagnostics
        self.capsuleRegistry = capsuleRegistry
        self.configuration = configuration
        self.healthMonitor = ServiceHealthMonitor(
            diagnostics: diagnostics,
            checkInterval: configuration.healthCheckInterval
        )
        self.dependencyResolver = DependencyResolver()
        
        let span = diagnostics.beginSpan(
            name: "ServiceDiscovery.init",
            category: "service_discovery.initialization",
            correlationID: nil,
            tags: [:]
        )
        
        do {
            // Initialize service registry from available capsules
            try await initializeServiceRegistry()
            
            // Start health monitoring
            await healthMonitor.start()
            
            span.end(status: .ok)
            
diagnostics.event(
            level: .info,
            category: "service_discovery.initialization",
            message: "ServiceDiscovery initialized with \(serviceRegistry.keys.count) capabilities",
            correlationID: nil,
            metadata: ["capabilities": "\(serviceRegistry.keys.count)"]
        )
            
        } catch {
            span.end(status: .error)
            throw CapsuleError.internalError(details: "ServiceDiscovery initialization failed: \\(error)")
        }
    }
    
    deinit {
        Task {
            await healthMonitor.stop()
        }
    }
    
    // MARK: - Public API
    
    /// Discover services by capability
    /// - Parameters:
    ///   - capability: Service capability to discover
    ///   - versionRequirement: Optional version requirement
    ///   - correlationID: Request ID for tracing
    /// - Returns: Array of matching service instances
    /// - Throws: CapsuleError if discovery fails
    public func discoverServices(
        capability: String,
        versionRequirement: VersionRequirement? = nil,
        correlationID: String? = nil
    ) async throws -> [ServiceInstance] {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "ServiceDiscovery.discoverServices",
            category: "service_discovery.discovery",
            correlationID: corrID,
            tags: ["capability": capability]
        )
        
        defer { span.end(status: .ok) }
        
        guard let services = serviceRegistry[capability] else {
            diagnostics.event(
                level: .debug,
                category: "service_discovery.discovery",
                message: "No services found for capability: \(capability)",
                correlationID: corrID,
                metadata: [:]
            )
            return []
        }
        
        var filteredServices = services
        
        // Apply version filtering
        if let requirement = versionRequirement {
            filteredServices = services.filter { requirement.satisfies($0.version) }
        }
        
        // Filter by health status
        filteredServices = filteredServices.filter { $0.health.status == .healthy }
        
        // Sort by priority and load
        filteredServices.sort { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            return (lhs.load ?? 0) < (rhs.load ?? 0)
        }
        
        diagnostics.event(
            level: .debug,
            category: "service_discovery.discovery",
            message: "Discovered \(filteredServices.count) services for capability: \(capability)",
            correlationID: corrID,
            metadata: ["service_count": "\(filteredServices.count)"]
        )
        
        return filteredServices
    }
    
    /// Get a specific service instance
    /// - Parameters:
    ///   - serviceID: Unique identifier of the service
    ///   - correlationID: Request ID for tracing
    /// - Returns: Service instance if found
    public func getService(
        _ serviceID: String,
        correlationID: String? = nil
    ) async -> ServiceInstance? {
        for (_, services) in serviceRegistry {
            if let service = services.first(where: { $0.id == serviceID }) {
                return service
            }
        }
        return nil
    }
    
    /// Register a new service
    /// - Parameters:
    ///   - service: Service instance to register
    ///   - correlationID: Request ID for tracing
    /// - Throws: CapsuleError if registration fails
    public func registerService(
        _ service: ServiceInstance,
        correlationID: String? = nil
    ) async throws {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "ServiceDiscovery.registerService",
            category: "service_discovery.registration",
            correlationID: corrID,
            tags: ["service_id": service.id, "capability": service.capability]
        )
        
        defer { span.end(status: .ok) }
        
        if serviceRegistry[service.capability] == nil {
            serviceRegistry[service.capability] = []
        }
        
        serviceRegistry[service.capability]?.append(service)
        
        // Add to health monitoring
        await healthMonitor.addService(service)
        
        // Notify listeners
        await notifyServiceRegistered(service)
        
        diagnostics.event(
            level: .info,
            category: "service_discovery.registration",
            message: "Service registered: \(service.name)",
            correlationID: corrID,
            metadata: [
                "service_id": service.id,
                "capability": service.capability,
                "version": service.version.description
            ]
        )
    }
    
    /// Unregister a service
    /// - Parameters:
    ///   - serviceID: Unique identifier of the service
    ///   - correlationID: Request ID for tracing
    /// - Throws: CapsuleError if unregistration fails
    public func unregisterService(
        _ serviceID: String,
        correlationID: String? = nil
    ) async throws {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "ServiceDiscovery.unregisterService",
            category: "service_discovery.unregistration",
            correlationID: corrID,
            tags: ["service_id": serviceID]
        )
        
        defer { span.end(status: .ok) }
        
        var serviceToRemove: ServiceInstance?
        
        for (capability, services) in serviceRegistry {
            if let index = services.firstIndex(where: { $0.id == serviceID }) {
                serviceToRemove = services[index]
                serviceRegistry[capability]?.remove(at: index)
                break
            }
        }
        
        guard let service = serviceToRemove else {
            throw CapsuleError.invalidInput(
                field: "serviceID",
                constraint: "Service not found: \(serviceID)"
            )
        }
        
        // Remove from health monitoring
        await healthMonitor.removeService(serviceID)
        
        // Notify listeners
        await notifyServiceUnregistered(service)
        
        diagnostics.event(
            level: .info,
            category: "service_discovery.unregistration",
            message: "Service unregistered: \(service.name)",
            correlationID: corrID,
            metadata: ["service_id": serviceID]
        )
    }
    
    /// Load and register a capsule as a service
    /// - Parameters:
    ///   - capsuleID: Unique identifier of the capsule
    ///   - correlationID: Request ID for tracing
    /// - Returns: Array of registered service instances
    /// - Throws: CapsuleError if loading fails
    public func loadCapsuleAsService(
        _ capsuleID: String,
        correlationID: String? = nil
    ) async throws -> [ServiceInstance] {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "ServiceDiscovery.loadCapsuleAsService",
            category: "service_discovery.loading",
            correlationID: corrID,
            tags: ["capsule_id": capsuleID]
        )
        
        defer { span.end(status: .ok) }
        
        // Load the capsule through registry
        let capsuleInstance = try await capsuleRegistry.loadCapsule(capsuleID, correlationID: corrID)
        
        // Create service instances for each capability
        var serviceInstances: [ServiceInstance] = []
        
        for capability in capsuleInstance.metadata.capabilities {
            let service = ServiceInstance(
                id: "\(capsuleInstance.metadata.id).\(capability)",
                name: capsuleInstance.metadata.name,
                capability: capability,
                version: capsuleInstance.metadata.version,
                endpoint: capsuleInstance.metadata.healthCheckEndpoint ?? "/health",
                capsuleInstance: capsuleInstance,
                priority: 1.0,
                metadata: capsuleInstance.metadata
            )
            
            try await registerService(service, correlationID: corrID)
            serviceInstances.append(service)
        }
        
        diagnostics.event(
            level: .info,
            category: "service_discovery.loading",
            message: "Loaded capsule as service: \(capsuleInstance.metadata.name)",
            correlationID: corrID,
            metadata: [
                "capsule_id": capsuleID,
                "services_created": "\(serviceInstances.count)"
            ]
        )
        
        return serviceInstances
    }
    
    /// Resolve service dependencies
    /// - Parameters:
    ///   - dependencies: Array of service dependencies
    ///   - correlationID: Request ID for tracing
    /// - Returns: Resolved service instances
    /// - Throws: CapsuleError if resolution fails
    public func resolveDependencies(
        _ dependencies: [ServiceDependency],
        correlationID: String? = nil
    ) async throws -> [ServiceInstance] {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "ServiceDiscovery.resolveDependencies",
            category: "service_discovery.resolution",
            correlationID: corrID,
            tags: ["dependency_count": "\(dependencies.count)"]
        )
        
        defer { span.end(status: .ok) }
        
        var resolvedServices: [ServiceInstance] = []
        
        for dependency in dependencies {
            let services = try await discoverServices(
                capability: dependency.capability,
                versionRequirement: dependency.versionRequirement,
                correlationID: corrID
            )
            
            guard let service = services.first else {
                throw CapsuleError.operationFailed(
                    code: 2001,
                    message: "Cannot resolve dependency: \(dependency.capability)",
                    context: [
                        "capability": dependency.capability,
                        "version_requirement": dependency.versionRequirement?.description ?? "any"
                    ]
                )
            }
            
            resolvedServices.append(service)
        }
        
        return resolvedServices
    }
    
    /// Get all registered capabilities
    /// - Returns: Array of capability names
    public func getAllCapabilities() -> [String] {
        return Array(serviceRegistry.keys).sorted()
    }
    
    /// Get services by capability
    /// - Parameter capability: Service capability
    /// - Returns: Array of service instances
    public func getServicesByCapability(_ capability: String) -> [ServiceInstance] {
        return serviceRegistry[capability] ?? []
    }
    
    /// Get discovery system health
    /// - Returns: Health status
    public func getHealthStatus() -> ServiceDiscoveryHealth {
        let totalServices = serviceRegistry.values.flatMap { $0 }.count
        let healthyServices = serviceRegistry.values.flatMap { $0 }.filter { $0.health.status == .healthy }.count
        
        return ServiceDiscoveryHealth(
            totalCapabilities: serviceRegistry.keys.count,
            totalServices: totalServices,
            healthyServices: healthyServices,
            healthMonitorActive: await healthMonitor.isActive()
        )
    }
    
    /// Add service discovery listener
    /// - Parameter listener: Event listener
    public func addListener(_ listener: ServiceDiscoveryListener) {
        serviceListeners.append(listener)
    }
    
    /// Remove service discovery listener
    /// - Parameter listener: Event listener to remove
    public func removeListener(_ listener: ServiceDiscoveryListener) {
        serviceListeners.removeAll { $0.id == listener.id }
    }
    
    // MARK: - Private Methods
    
    private func initializeServiceRegistry() async throws {
        let availableCapsules = await capsuleRegistry.getAllAvailableCapsules()
        
        for (_, capsuleMetadata) in availableCapsules {
            for capability in capsuleMetadata.capabilities {
                let service = ServiceInstance(
                    id: "\(capsuleMetadata.id).\(capability)",
                    name: capsuleMetadata.name,
                    capability: capability,
                    version: capsuleMetadata.version,
                    endpoint: capsuleMetadata.healthCheckEndpoint ?? "/health",
                    capsuleInstance: nil,
                    priority: 1.0,
                    metadata: capsuleMetadata
                )
                
                if serviceRegistry[capability] == nil {
                    serviceRegistry[capability] = []
                }
                serviceRegistry[capability]?.append(service)
            }
        }
    }
    
    private func notifyServiceRegistered(_ service: ServiceInstance) async {
        let event = ServiceDiscoveryEvent.serviceRegistered(service)
        for listener in serviceListeners {
            await listener.handleEvent(event)
        }
    }
    
    private func notifyServiceUnregistered(_ service: ServiceInstance) async {
        let event = ServiceDiscoveryEvent.serviceUnregistered(service)
        for listener in serviceListeners {
            await listener.handleEvent(event)
        }
    }
}

// MARK: - Supporting Types

/// Configuration for ServiceDiscovery
public struct ServiceDiscoveryConfiguration: Sendable {
    public let healthCheckInterval: TimeInterval
    public let maxConcurrentHealthChecks: Int
    public let enableHealthMonitoring: Bool
    public let serviceTimeout: TimeInterval
    
    public static let `default` = ServiceDiscoveryConfiguration(
        healthCheckInterval: 30.0,
        maxConcurrentHealthChecks: 10,
        enableHealthMonitoring: true,
        serviceTimeout: 10.0
    )
    
    public init(
        healthCheckInterval: TimeInterval = 30.0,
        maxConcurrentHealthChecks: Int = 10,
        enableHealthMonitoring: Bool = true,
        serviceTimeout: TimeInterval = 10.0
    ) {
        self.healthCheckInterval = healthCheckInterval
        self.maxConcurrentHealthChecks = maxConcurrentHealthChecks
        self.enableHealthMonitoring = enableHealthMonitoring
        self.serviceTimeout = serviceTimeout
    }
}

/// Service instance representation
public struct ServiceInstance: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let capability: String
    public let version: SemanticVersion
    public let endpoint: String
    public let capsuleInstance: CapsuleInstance?
    public let priority: Double
    public let metadata: CapsuleMetadata?
    
    private let lock = NSLock()
    private nonisolated(unsafe) var _health: ServiceHealth
    private nonisolated(unsafe) var _load: Double?
    private nonisolated(unsafe) var _lastHealthCheck: Date?
    
    public var health: ServiceHealth {
        lock.lock()
        defer { lock.unlock() }
        return _health
    }
    
    public var load: Double? {
        lock.lock()
        defer { lock.unlock() }
        return _load
    }
    
    public var lastHealthCheck: Date? {
        lock.lock()
        defer { lock.unlock() }
        return _lastHealthCheck
    }
    
    public init(
        id: String,
        name: String,
        capability: String,
        version: SemanticVersion,
        endpoint: String,
        capsuleInstance: CapsuleInstance? = nil,
        priority: Double = 1.0,
        metadata: CapsuleMetadata? = nil
    ) {
        self.id = id
        self.name = name
        self.capability = capability
        self.version = version
        self.endpoint = endpoint
        self.capsuleInstance = capsuleInstance
        self.priority = priority
        self.metadata = metadata
        self._health = ServiceHealth(status: .unknown)
    }
    
    internal func updateHealth(_ newHealth: ServiceHealth, load: Double? = nil) {
        lock.lock()
        defer { lock.unlock() }
        _health = newHealth
        _load = load
        _lastHealthCheck = Date()
    }
}

/// Service health status
public struct ServiceHealth: Codable, Sendable {
    public let status: HealthStatus
    public let message: String?
    public let responseTime: TimeInterval?
    public let lastCheck: Date
    
    public init(
        status: HealthStatus,
        message: String? = nil,
        responseTime: TimeInterval? = nil,
        lastCheck: Date = Date()
    ) {
        self.status = status
        self.message = message
        self.responseTime = responseTime
        self.lastCheck = lastCheck
    }
}

/// Service dependency specification
public struct ServiceDependency: Sendable {
    public let capability: String
    public let versionRequirement: VersionRequirement?
    public let optional: Bool
    
    public init(
        capability: String,
        versionRequirement: VersionRequirement? = nil,
        optional: Bool = false
    ) {
        self.capability = capability
        self.versionRequirement = versionRequirement
        self.optional = optional
    }
}

/// Service discovery health status
public struct ServiceDiscoveryHealth: Codable, Sendable {
    public let totalCapabilities: Int
    public let totalServices: Int
    public let healthyServices: Int
    public let healthMonitorActive: Bool
    
    public var status: String {
        if healthyServices == totalServices && totalServices > 0 {
            return "healthy"
        } else if healthyServices > 0 {
            return "degraded"
        } else {
            return "unhealthy"
        }
    }
}

/// Health monitor for services
actor ServiceHealthMonitor: Sendable {
    private let diagnostics: CapsuleDiagnostics
    private let checkInterval: TimeInterval
    private var services: [String: ServiceInstance] = [:]
    private var monitoringTask: Task<Void, Never>?
    private var isActive: Bool = false
    
    init(diagnostics: CapsuleDiagnostics, checkInterval: TimeInterval) {
        self.diagnostics = diagnostics
        self.checkInterval = checkInterval
    }
    
    func start() {
        guard !isActive else { return }
        isActive = true
        
        monitoringTask = Task {
            while isActive && !Task.isCancelled {
                await performHealthChecks()
                try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
            }
        }
    }
    
    func stop() {
        isActive = false
        monitoringTask?.cancel()
        monitoringTask = nil
    }
    
    func addService(_ service: ServiceInstance) {
        services[service.id] = service
    }
    
    func removeService(_ serviceID: String) {
        services.removeValue(forKey: serviceID)
    }
    
    func isActiveCheck() -> Bool {
        return isActive
    }
    
    private func performHealthChecks() async {
        for (serviceID, service) in services {
            await checkServiceHealth(service)
        }
    }
    
    private func checkServiceHealth(_ service: ServiceInstance) async {
        let startTime = Date()
        
        // Simulate health check - in real implementation would make HTTP call
        let isHealthy = Bool.random()
        let responseTime = Date().timeIntervalSince(startTime)
        
        let health = ServiceHealth(
            status: isHealthy ? .healthy : .unhealthy,
            message: isHealthy ? "Service is healthy" : "Service is not responding",
            responseTime: responseTime,
            lastCheck: Date()
        )
        
        // Update service health (this would need to be done through the service instance)
        service.updateHealth(health, load: Double.random(in: 0...1))
        
        diagnostics.event(
            level: .debug,
            category: "service_discovery.health_check",
            message: "Health check completed for \(service.name)",
            correlationID: nil,
            metadata: [
                "service_id": service.id,
                "status": health.status.rawValue,
                "response_time": "\(responseTime)"
            ]
        )
    }
}

/// Dependency resolver for services
actor DependencyResolver: Sendable {
    func resolve(_ dependencies: [ServiceDependency], from services: [ServiceInstance]) -> Result<[ServiceInstance], CapsuleError> {
        var resolved: [ServiceInstance] = []
        
        for dependency in dependencies {
            let candidates = services.filter { $0.capability == dependency.capability }
            
            let matching = candidates.filter { service in
                if let requirement = dependency.versionRequirement {
                    return requirement.satisfies(service.version)
                }
                return true
            }
            
            guard let selected = matching.sorted(by: { $0.priority > $1.priority }).first else {
                if !dependency.optional {
                    return .failure(.operationFailed(
                        code: 2002,
                        message: "Cannot resolve dependency: \(dependency.capability)",
                        context: ["capability": dependency.capability]
                    ))
                }
                continue
            }
            
            resolved.append(selected)
        }
        
        return .success(resolved)
    }
}