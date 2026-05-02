import Foundation

// MARK: - Event System

/// Events emitted by the CapsuleRegistry
public enum CapsuleRegistryEvent: Sendable {
    case capsuleLoaded(CapsuleInstance)
    case capsuleUnloaded(CapsuleInstance)
    case capsuleStateChanged(CapsuleInstance, from: CapsuleState, to: CapsuleState)
    case capsuleHealthChanged(CapsuleInstance, newHealth: CapsuleHealth)
    case dependencyResolved(CapsuleInstance, dependency: String, version: SemanticVersion)
    case dependencyFailed(CapsuleInstance, dependency: String, error: CapsuleError)
    case hotReloadStarted
    case hotReloadStopped
}

/// Event listener for registry changes
public actor CapsuleRegistryEventListener: Identifiable, Sendable {
    public let id: String
    private let handler: (CapsuleRegistryEvent) async -> Void
    
    public init(id: String = UUID().uuidString, handler: @escaping (CapsuleRegistryEvent) async -> Void) {
        self.id = id
        self.handler = handler
    }
    
    func handleEvent(_ event: CapsuleRegistryEvent) async {
        await handler(event)
    }
}

// MARK: - Semantic Version Extensions

extension SemanticVersion: CustomStringConvertible {
    public     var description: String {
        var version = "\(major).\(minor).\(patch)"
        if let preRelease = preRelease {
            version += "-\(preRelease)"
        }
        if let build = build {
            version += "+\(build)"
        }
        return version
    }
}

extension SemanticVersion: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        let parts = value.split(separator: ".")
        guard parts.count >= 3 else {
            fatalError("Invalid semantic version: \(value)")
        }
        
        self.init(
            major: Int(parts[0]) ?? 0,
            minor: Int(parts[1]) ?? 0,
            patch: Int(parts[2]) ?? 0
        )
    }
}

// MARK: - Version Requirement Extensions

extension VersionRequirement: CustomStringConvertible {
    public     var description: String {
        switch self {
        case .exact(let version):
            return "=\(version)"
        case .greaterThan(let version):
            return ">\(version)"
        case .greaterThanOrEqual(let version):
            return ">=\(version)"
        case .lessThan(let version):
            return "<\(version)"
        case .lessThanOrEqual(let version):
            return "<=\(version)"
        case .range(let lower, let upper):
            return "\(lower) - \(upper)"
        case .compatibleWith(let version):
            return "^\(version)"
        }
    }
}

// MARK: - Utility Functions

/// Resolve a dependency graph and return loading order
public func resolveDependencyGraph(
    capsules: [String: CapsuleMetadata]
) -> Result<[String], CapsuleError> {
    var visited: Set<String> = []
    var visiting: Set<String> = []
    var result: [String] = []
    
    func visit(_ capsuleID: String) -> Bool {
        if visiting.contains(capsuleID) {
            return false // Circular dependency
        }
        
        if visited.contains(capsuleID) {
            return true
        }
        
        visiting.insert(capsuleID)
        
        guard let capsule = capsules[capsuleID] else {
            return true // Capsule not found, skip
        }
        
        // Visit all dependencies first
        for dependency in capsule.dependencies where !dependency.optional {
            if !visit(dependency.name) {
                return false
            }
        }
        
        visiting.remove(capsuleID)
        visited.insert(capsuleID)
        result.append(capsuleID)
        return true
    }
    
    for capsuleID in capsules.keys {
        if !visit(capsuleID) {
            return .failure(.operationFailed(
                code: 1006,
                message: "Circular dependency detected",
                context: ["starting_point": capsuleID]
            ))
        }
    }
    
    return .success(result)
}

/// Validate that a set of capsules can be loaded together
public func validateCapsuleCompatibility(
    capsules: [CapsuleMetadata]
) -> [CapsuleCompatibilityIssue] {
    var issues: [CapsuleCompatibilityIssue] = []
    let capsuleMap = Dictionary(uniqueKeysWithValues: capsules.map { ($0.id, $0) })
    
    // Check for duplicate capabilities
    var capabilityMap: [String: [String]] = [:]
    for capsule in capsules {
        for capability in capsule.capabilities {
            capabilityMap[capability, default: []].append(capsule.id)
        }
    }
    
    for (capability, capsuleIDs) in capabilityMap where capsuleIDs.count > 1 {
        issues.append(.duplicateCapability(
            capability: capability,
            capsuleIDs: capsuleIDs
        ))
    }
    
    // Check dependency satisfaction
    for capsule in capsules {
        for dependency in capsule.dependencies where !dependency.optional {
            if let dependencyCapsule = capsuleMap[dependency.name] {
                if !dependency.versionRequirement.satisfies(dependencyCapsule.version) {
                    issues.append(.dependencyVersionMismatch(
                        capsuleID: capsule.id,
                        dependencyName: dependency.name,
                        required: dependency.versionRequirement.description,
                        available: dependencyCapsule.version.description
                    ))
                }
            } else {
                issues.append(.missingDependency(
                    capsuleID: capsule.id,
                    dependencyName: dependency.name
                ))
            }
        }
    }
    
    return issues
}

/// Compatibility issue between capsules
public enum CapsuleCompatibilityIssue: Sendable {
    case duplicateCapability(capability: String, capsuleIDs: [String])
    case missingDependency(capsuleID: String, dependencyName: String)
    case dependencyVersionMismatch(capsuleID: String, dependencyName: String, required: String, available: String)
    
    public var description: String {
        switch self {
        case .duplicateCapability(let capability, let capsuleIDs):
            return "Duplicate capability '\(capability)' in capsules: \(capsuleIDs.joined(separator: ", "))"
        case .missingDependency(let capsuleID, let dependencyName):
            return "Missing dependency '\(dependencyName)' for capsule '\(capsuleID)'"
        case .dependencyVersionMismatch(let capsuleID, let dependencyName, let required, let available):
            return "Dependency version mismatch for '\(dependencyName)' in '\(capsuleID)': required \(required), available \(available)"
        }
    }
}