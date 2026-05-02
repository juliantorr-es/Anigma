import Foundation

// MARK: - Service Discovery Events

/// Events emitted by the ServiceDiscovery system
public enum ServiceDiscoveryEvent: Sendable {
    case serviceRegistered(ServiceInstance)
    case serviceUnregistered(ServiceInstance)
    case serviceHealthChanged(ServiceInstance, previousHealth: ServiceHealth, newHealth: ServiceHealth)
    case dependencyResolved(String, service: ServiceInstance)
    case dependencyFailed(String, error: CapsuleError)
    case capabilityAdded(String, services: [ServiceInstance])
    case capabilityRemoved(String)
    case healthMonitorStarted
    case healthMonitorStopped
}

/// Service discovery event listener
public actor ServiceDiscoveryListener: Identifiable, Sendable {
    public let id: String
    private let handler: (ServiceDiscoveryEvent) async -> Void
    
    public init(id: String = UUID().uuidString, handler: @escaping (ServiceDiscoveryEvent) async -> Void) {
        self.id = id
        self.handler = handler
    }
    
    func handleEvent(_ event: ServiceDiscoveryEvent) async {
        await handler(event)
    }
}

// MARK: - Service Health Extensions

extension ServiceHealth: CustomStringConvertible {
    public var description: String {
        var result = "ServiceHealth(status: \(status.rawValue)"
        if let message = message {
            result += ", message: \(message)"
        }
        if let responseTime = responseTime {
            result += ", responseTime: \(String(format: "%.3f", responseTime))s"
        }
        result += ")"
        return result
    }
}

// MARK: - Service Instance Extensions

extension ServiceInstance: CustomStringConvertible {
    public var description: String {
        return "ServiceInstance(id: \(id), name: \(name), capability: \(capability), version: \(version), health: \(health.status.rawValue))"
    }
}

// MARK: - Utility Functions

/// Create a service dependency
public func dependency(
    _ capability: String,
    version: VersionRequirement? = nil,
    optional: Bool = false
) -> ServiceDependency {
    return ServiceDependency(
        capability: capability,
        versionRequirement: version,
        optional: optional
    )
}

/// Create an exact version requirement
public func exact(_ version: String) -> VersionRequirement {
    let semVer = SemanticVersion(stringLiteral: version)
    return .exact(semVer)
}

/// Create a compatible version requirement (^1.2.3)
public func compatible(_ version: String) -> VersionRequirement {
    let semVer = SemanticVersion(stringLiteral: version)
    return .compatibleWith(semVer)
}

/// Create a greater than or equal version requirement
public func greaterThanOrEqual(_ version: String) -> VersionRequirement {
    let semVer = SemanticVersion(stringLiteral: version)
    return .greaterThanOrEqual(semVer)
}

/// Create a version range requirement
public func range(from: String, to: String) -> VersionRequirement {
    let lower = SemanticVersion(stringLiteral: from)
    let upper = SemanticVersion(stringLiteral: to)
    return .range(lower, upper)
}

/// Validate service compatibility
public func validateServiceCompatibility(
    services: [ServiceInstance]
) -> [ServiceCompatibilityIssue] {
    var issues: [ServiceCompatibilityIssue] = []
    
    // Group services by capability
    var capabilityMap: [String: [ServiceInstance]] = [:]
    for service in services {
        capabilityMap[service.capability, default: []].append(service)
    }
    
    // Check for version conflicts within capabilities
    for (capability, serviceInstances) in capabilityMap {
        let versions = serviceInstances.map { $0.version }.sorted()
        if versions.count > 1 {
            let minVersion = versions.first!
            let maxVersion = versions.last!
            
            if minVersion.major != maxVersion.major {
                issues.append(.majorVersionConflict(
                    capability: capability,
                    versions: versions.map { $0.description }
                ))
            }
        }
    }
    
    return issues
}

/// Service compatibility issue
public enum ServiceCompatibilityIssue: Sendable {
    case majorVersionConflict(capability: String, versions: [String])
    case duplicateServiceID(serviceIDs: [String])
    case incompatibleEndpoint(serviceID: String, endpoint: String)
    
    public var description: String {
        switch self {
        case .majorVersionConflict(let capability, let versions):
            return "Major version conflict in capability '\(capability)': \(versions.joined(separator: ", "))"
        case .duplicateServiceID(let serviceIDs):
            return "Duplicate service IDs: \(serviceIDs.joined(separator: ", "))"
        case .incompatibleEndpoint(let serviceID, let endpoint):
            return "Incompatible endpoint for service '\(serviceID)': \(endpoint)"
        }
    }
}

/// Service selection strategies
public enum ServiceSelectionStrategy: Sendable {
    case firstAvailable
    case highestPriority
    case lowestLoad
    case roundRobin
    case random
    
    func select(from services: [ServiceInstance]) -> ServiceInstance? {
        switch self {
        case .firstAvailable:
            return services.first
            
        case .highestPriority:
            return services.max { $0.priority < $1.priority }
            
        case .lowestLoad:
            return services.min { lhs, rhs in
                guard let lhsLoad = lhs.load, let rhsLoad = rhs.load else {
                    return lhs.load != nil
                }
                return lhsLoad < rhsLoad
            }
            
        case .roundRobin:
            // Simple round robin - would need state management for real implementation
            return services.first
            
        case .random:
            return services.randomElement()
        }
    }
}

/// Service request context
public struct ServiceRequestContext: Sendable {
    public let requestID: String
    public let userID: String?
    public let sessionID: String?
    public let metadata: [String: String]
    
    public init(
        requestID: String = UUID().uuidString,
        userID: String? = nil,
        sessionID: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.requestID = requestID
        self.userID = userID
        self.sessionID = sessionID
        self.metadata = metadata
    }
}

/// Service invocation result
public struct ServiceInvocationResult: Sendable {
    public let serviceID: String
    public let capability: String
    public let success: Bool
    public let responseTime: TimeInterval
    public let error: CapsuleError?
    public let metadata: [String: String]
    
    public init(
        serviceID: String,
        capability: String,
        success: Bool,
        responseTime: TimeInterval,
        error: CapsuleError? = nil,
        metadata: [String: String] = [:]
    ) {
        self.serviceID = serviceID
        self.capability = capability
        self.success = success
        self.responseTime = responseTime
        self.error = error
        self.metadata = metadata
    }
}