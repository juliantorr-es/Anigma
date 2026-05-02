/// DaemonFeatureContracts
/// 
/// Defines the minimal, stable interfaces for static feature registration in the daemon.
/// These contracts form the boundary between the daemon kernel (which owns lifecycle and registries)
/// and feature implementations (which register themselves through these protocols).
/// 
/// Key invariant: This target contains ONLY contracts, no feature implementations.

import Foundation

/// Unique identifier for a registered feature
public typealias FeatureID = String

/// Registration contract for daemon features
/// 
/// Each backend feature must implement this protocol to register with the daemon.
/// Registration happens at startup through the DaemonFeatureRegistry.
/// 
/// Example:
/// ```swift
/// struct ModelRegistryFeature: DaemonFeatureRegistrar {
///     static var featureID: FeatureID { "model-registry" }
///     static var dependencies: [FeatureID] { [] }
///     
///     static func register(into registry: inout DaemonFeatureRegistry) throws {
///         let factory = { ModelRegistryWorker() as any JobWorker }
///         registry.registerWorker(kind: "model-query", factory: factory)
///     }
/// }
/// ```
public protocol DaemonFeatureRegistrar: Sendable {
    /// Unique identifier for this feature
    static var featureID: FeatureID { get }
    
    /// Feature IDs that must be registered before this feature
    static var dependencies: [FeatureID] { get }
    
    /// Register this feature's workers, routes, tools, and capabilities
    /// 
    /// Called once during daemon startup after all dependencies are registered.
    /// Should register all workers, routes, capabilities, and tools through the registry.
    static func register(into registry: inout DaemonFeatureRegistry) throws
}

/// Descriptor for a registered job worker
public struct WorkerRegistration: Sendable {
    public let kind: String
    public let factory: @Sendable () -> any JobWorker
    
    public init(kind: String, factory: @escaping @Sendable () -> any JobWorker) {
        self.kind = kind
        self.factory = factory
    }
}

/// Descriptor for a registered HTTP route
public struct RouteRegistration: Sendable {
    public let path: String
    public let method: String
    public let handler: @Sendable (RouteRequest) async throws -> RouteResponse
    
    public init(path: String, method: String, handler: @escaping @Sendable (RouteRequest) async throws -> RouteResponse) {
        self.path = path
        self.method = method
        self.handler = handler
    }
}

/// Descriptor for a registered tool
public struct ToolRegistration: Sendable {
    public let toolID: String
    public let definition: ToolDefinition
    
    public init(toolID: String, definition: ToolDefinition) {
        self.toolID = toolID
        self.definition = definition
    }
}

/// Descriptor for a registered capability
public struct CapabilityRegistration: Sendable {
    public let capabilityID: String
    public let metadata: CapabilityMetadata
    
    public init(capabilityID: String, metadata: CapabilityMetadata) {
        self.capabilityID = capabilityID
        self.metadata = metadata
    }
}

/// Feature manifest describing a registered feature
public struct FeatureManifest: Sendable {
    public let featureID: FeatureID
    public let workers: [String: WorkerRegistration]
    public let routes: [RouteRegistration]
    public let tools: [String: ToolRegistration]
    public let capabilities: [String: CapabilityRegistration]
    
    public init(
        featureID: FeatureID,
        workers: [String: WorkerRegistration] = [:],
        routes: [RouteRegistration] = [],
        tools: [String: ToolRegistration] = [:],
        capabilities: [String: CapabilityRegistration] = [:]
    ) {
        self.featureID = featureID
        self.workers = workers
        self.routes = routes
        self.tools = tools
        self.capabilities = capabilities
    }
}

/// Registry for daemon features
/// 
/// Accumulates registrations from features and provides inspection capabilities.
/// Mutable during startup, read-only after daemon is running.
public struct DaemonFeatureRegistry: Sendable {
    private(set) var workers: [String: WorkerRegistration] = [:]
    private(set) var routes: [RouteRegistration] = []
    private(set) var tools: [String: ToolRegistration] = [:]
    private(set) var capabilities: [String: CapabilityRegistration] = [:]
    private(set) var manifests: [FeatureID: FeatureManifest] = [:]
    
    public init() {}
    
    public mutating func registerWorker(kind: String, factory: @escaping @Sendable () -> any JobWorker) {
        workers[kind] = WorkerRegistration(kind: kind, factory: factory)
    }
    
    public mutating func registerRoute(path: String, method: String, handler: @escaping @Sendable (RouteRequest) async throws -> RouteResponse) {
        routes.append(RouteRegistration(path: path, method: method, handler: handler))
    }
    
    public mutating func registerTool(toolID: String, definition: ToolDefinition) {
        tools[toolID] = ToolRegistration(toolID: toolID, definition: definition)
    }
    
    public mutating func registerCapability(capabilityID: String, metadata: CapabilityMetadata) {
        capabilities[capabilityID] = CapabilityRegistration(capabilityID: capabilityID, metadata: metadata)
    }
    
    public mutating func recordManifest(_ manifest: FeatureManifest) {
        manifests[manifest.featureID] = manifest
    }
    
    /// Get inspection snapshot of all registered features
    public func inspectFeatures() -> [FeatureID: FeatureManifest] {
        manifests
    }
    
    /// List all registered worker kinds
    public func listWorkerKinds() -> [String] {
        Array(workers.keys)
    }
    
    /// List all registered route paths
    public func listRoutes() -> [(path: String, method: String)] {
        routes.map { ($0.path, $0.method) }
    }
    
    /// List all registered tool IDs
    public func listToolIDs() -> [String] {
        Array(tools.keys)
    }
    
    /// List all registered capability IDs
    public func listCapabilityIDs() -> [String] {
        Array(capabilities.keys)
    }
}

// MARK: - Minimal Protocol Definitions

/// Protocol for objects that can perform jobs
public protocol JobWorker: Sendable {
    func work(with input: JobInput) async throws -> JobOutput
}

/// Input to a job
public struct JobInput: Sendable, Codable {
    public let kind: String
    public let parameters: [String: AnyCodable]
    
    public init(kind: String, parameters: [String: AnyCodable] = [:]) {
        self.kind = kind
        self.parameters = parameters
    }
}

/// Output from a job
public struct JobOutput: Sendable, Codable {
    public let result: [String: AnyCodable]
    
    public init(result: [String: AnyCodable] = [:]) {
        self.result = result
    }
}

/// Route request
public struct RouteRequest: Sendable {
    public let path: String
    public let method: String
    public let body: Data?
    
    public init(path: String, method: String, body: Data? = nil) {
        self.path = path
        self.method = method
        self.body = body
    }
}

/// Route response
public struct RouteResponse: Sendable {
    public let statusCode: Int
    public let body: Data
    
    public init(statusCode: Int, body: Data = Data()) {
        self.statusCode = statusCode
        self.body = body
    }
}

/// Tool definition
public struct ToolDefinition: @unchecked Sendable, Codable {
    public let description: String
    public let parameters: [String: Any]
    
    public init(description: String, parameters: [String: Any] = [:]) {
        self.description = description
        self.parameters = parameters
    }
    
    enum CodingKeys: String, CodingKey {
        case description
        case parameters
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.description = try container.decode(String.self, forKey: .description)
        self.parameters = try container.decode([String: AnyCodable].self, forKey: .parameters).mapValues { $0.value }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(description, forKey: .description)
        let encodable = parameters.mapValues { AnyCodable($0) }
        try container.encode(encodable, forKey: .parameters)
    }
}

/// Capability metadata
public struct CapabilityMetadata: Sendable, Codable {
    public let description: String
    public let requirements: [String]
    
    public init(description: String, requirements: [String] = []) {
        self.description = description
        self.requirements = requirements
    }
}

/// Wrapper for any Codable value
public struct AnyCodable: @unchecked Sendable, Codable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnyCodable")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if value is NSNull {
            try container.encodeNil()
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else if let array = value as? [Any] {
            try container.encode(array.map { AnyCodable($0) })
        } else if let dict = value as? [String: Any] {
            try container.encode(dict.mapValues { AnyCodable($0) })
        } else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "Cannot encode AnyCodable"))
        }
    }
}
