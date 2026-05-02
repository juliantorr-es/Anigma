//
//  GrapheneRegistry.swift
//  AnigmaCore
//
//  Node type registry and execution backend for Graphene.
//
//  Inspired by Graphite's node registry pattern:
//  - Central catalog of available node types
//  - Plugin registration for custom nodes
//  - Execution backend abstraction (CPU/GPU/Neural)
//  - Node factory for instantiation
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import ContractsCore
import InferenceCore
import Foundation
import CoreGraphics

// MARK: - Node Executor Protocol

/// Protocol for node execution backends.
public protocol NodeExecutor: Sendable {
    /// Execute a node with given inputs and parameters.
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue]
}

/// Context provided during node execution.
public struct GrapheneExecutionContext: Sendable {
    public let graphId: NodeGraphId
    public let nodeId: NodeInstanceId
    public let cache: NodeCacheProtocol
    public let resourceManager: ResourceManager
    public let cancellationToken: CancellationToken

    public init(
        graphId: NodeGraphId,
        nodeId: NodeInstanceId,
        cache: NodeCacheProtocol,
        resourceManager: ResourceManager,
        cancellationToken: CancellationToken
    ) {
        self.graphId = graphId
        self.nodeId = nodeId
        self.cache = cache
        self.resourceManager = resourceManager
        self.cancellationToken = cancellationToken
    }
}

/// Token for cooperative cancellation.
public actor CancellationToken {
    private var _isCancelled = false

    public var isCancelled: Bool { _isCancelled }

    public func cancel() {
        _isCancelled = true
    }

    public init() {}
}

// MARK: - Resource Manager

/// Manages resources (memory, GPU, temp files) during execution.
public actor ResourceManager {
    private var allocatedResources: [String: Any] = [:]
    private var tempFiles: [URL] = []

    public init() {}

    public func allocate<T>(key: String, value: T) {
        allocatedResources[key] = value
    }

    public func get<T>(key: String, as type: T.Type) -> T? {
        allocatedResources[key] as? T
    }

    public func release(key: String) {
        allocatedResources[key] = nil
    }

    public func createTempFile(extension ext: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString + "." + ext
        let url = tempDir.appendingPathComponent(fileName)
        tempFiles.append(url)
        return url
    }

    public func cleanup() {
        for url in tempFiles {
            try? FileManager.default.removeItem(at: url)
        }
        tempFiles.removeAll()
        allocatedResources.removeAll()
    }
}

// MARK: - Node Cache Protocol

/// Protocol for caching node outputs.
public protocol NodeCacheProtocol: Sendable {
    func get(key: NodeCacheKey) async -> [String: AnyPortValue]?
    func set(key: NodeCacheKey, value: [String: AnyPortValue]) async
    func invalidate(nodeId: NodeInstanceId) async
    func invalidateAll() async
}

/// Cache key combining node identity and input hash.
public struct NodeCacheKey: Hashable, Sendable {
    public let nodeId: NodeInstanceId
    public let inputHash: Int
    public let parameterHash: Int

    public init(nodeId: NodeInstanceId, inputHash: Int, parameterHash: Int) {
        self.nodeId = nodeId
        self.inputHash = inputHash
        self.parameterHash = parameterHash
    }
}

/// In-memory node cache implementation.
public actor InMemoryNodeCache: NodeCacheProtocol {
    private var cache: [NodeCacheKey: [String: AnyPortValue]] = [:]
    private var accessOrder: [NodeCacheKey] = []
    private let maxEntries: Int

    public init(maxEntries: Int = 100) {
        self.maxEntries = maxEntries
    }

    public func get(key: NodeCacheKey) -> [String: AnyPortValue]? {
        if let value = cache[key] {
            // Move to end of access order (LRU)
            accessOrder.removeAll { $0 == key }
            accessOrder.append(key)
            return value
        }
        return nil
    }

    public func set(key: NodeCacheKey, value: [String: AnyPortValue]) {
        cache[key] = value
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)

        // Evict oldest if over capacity
        while cache.count > maxEntries, let oldest = accessOrder.first {
            cache[oldest] = nil
            accessOrder.removeFirst()
        }
    }

    public func invalidate(nodeId: NodeInstanceId) {
        let keysToRemove = cache.keys.filter { $0.nodeId == nodeId }
        for key in keysToRemove {
            cache[key] = nil
            accessOrder.removeAll { $0 == key }
        }
    }

    public func invalidateAll() {
        cache.removeAll()
        accessOrder.removeAll()
    }
}

// MARK: - Node Registry

/// Central registry of available node types.
public actor NodeRegistry {
    public static let shared = NodeRegistry()

    private var descriptors: [NodeTypeId: NodeDescriptor] = [:]
    private var executors: [NodeTypeId: any NodeExecutor] = [:]
    private var categories: Set<String> = []

    private init() {
        // Built-in nodes registration deferred to avoid actor isolation
    }

    // MARK: - Registration

    /// Register a node type with its descriptor and executor.
    public func register(
        descriptor: NodeDescriptor,
        executor: any NodeExecutor
    ) {
        descriptors[descriptor.typeId] = descriptor
        executors[descriptor.typeId] = executor
        categories.insert(descriptor.category)
    }

    /// Unregister a node type.
    public func unregister(_ typeId: NodeTypeId) {
        descriptors[typeId] = nil
        executors[typeId] = nil
    }

    // MARK: - Lookup

    /// Get a node descriptor by type ID.
    public func descriptor(for typeId: NodeTypeId) -> NodeDescriptor? {
        descriptors[typeId]
    }

    /// Get an executor for a node type.
    public func executor(for typeId: NodeTypeId) -> (any NodeExecutor)? {
        executors[typeId]
    }

    /// Get all registered node types.
    public func allDescriptors() -> [NodeDescriptor] {
        Array(descriptors.values)
    }

    /// Get all node types in a category.
    public func descriptors(inCategory category: String) -> [NodeDescriptor] {
        descriptors.values.filter { $0.category == category }
    }

    /// Get all categories.
    public func allCategories() -> [String] {
        Array(categories).sorted()
    }

    /// Search for nodes by name or description.
    public func search(query: String) -> [NodeDescriptor] {
        let lowered = query.lowercased()
        return descriptors.values.filter {
            $0.displayName.lowercased().contains(lowered) ||
            $0.description.lowercased().contains(lowered)
        }
    }

    // MARK: - Factory

    /// Create a new node instance from a type.
    public func createInstance(
        typeId: NodeTypeId,
        displayName: String? = nil,
        position: CGPoint = .zero
    ) throws -> NodeInstance {
        guard let descriptor = descriptors[typeId] else {
            throw GrapheneError.nodeTypeNotFound(typeId)
        }

        // Initialize with default parameter values
        var parameterValues: [String: ParameterValue] = [:]
        for param in descriptor.parameters {
            parameterValues[param.name] = param.defaultValue
        }

        return NodeInstance(
            typeId: typeId,
            displayName: displayName ?? descriptor.displayName,
            parameterValues: parameterValues,
            position: position
        )
    }

    // MARK: - Built-In Nodes

    private func registerBuiltInNodes() {
        // Register core utility nodes
        registerTextNodes()
        registerMathNodes()
        registerFlowNodes()
        registerIONodes()
    }

    private func registerTextNodes() {
        // Text Input node
        let textInput = NodeDescriptor(
            typeId: NodeTypeId(category: "Text", name: "TextInput"),
            displayName: "Text Input",
            description: "Provides a text value to the graph",
            category: "Text",
            inputs: [],
            outputs: [OutputPortDef(name: "text", type: TextPort.self)],
            parameters: [
                NodeParameter(name: "value", type: .text, defaultValue: .text(""))
            ]
        )
        register(descriptor: textInput, executor: TextInputExecutor())

        // Text Template node
        let textTemplate = NodeDescriptor(
            typeId: NodeTypeId(category: "Text", name: "TextTemplate"),
            displayName: "Text Template",
            description: "Formats text using a template with variables",
            category: "Text",
            inputs: [
                InputPortDef(name: "variables", type: JsonPort.self, isRequired: false)
            ],
            outputs: [OutputPortDef(name: "result", type: TextPort.self)],
            parameters: [
                NodeParameter(name: "template", type: .text, defaultValue: .text("Hello, {name}!"))
            ]
        )
        register(descriptor: textTemplate, executor: TextTemplateExecutor())

        // Text Concat node
        let textConcat = NodeDescriptor(
            typeId: NodeTypeId(category: "Text", name: "TextConcat"),
            displayName: "Concatenate",
            description: "Joins two text values",
            category: "Text",
            inputs: [
                InputPortDef(name: "a", type: TextPort.self),
                InputPortDef(name: "b", type: TextPort.self)
            ],
            outputs: [OutputPortDef(name: "result", type: TextPort.self)],
            parameters: [
                NodeParameter(name: "separator", type: .text, defaultValue: .text(""))
            ]
        )
        register(descriptor: textConcat, executor: TextConcatExecutor())
    }

    private func registerMathNodes() {
        // Number Input node
        let numberInput = NodeDescriptor(
            typeId: NodeTypeId(category: "Math", name: "NumberInput"),
            displayName: "Number",
            description: "Provides a numeric value to the graph",
            category: "Math",
            inputs: [],
            outputs: [OutputPortDef(name: "value", type: NumberPort.self)],
            parameters: [
                NodeParameter(name: "value", type: .number, defaultValue: .number(0))
            ]
        )
        register(descriptor: numberInput, executor: NumberInputExecutor())

        // Math Operation node
        let mathOp = NodeDescriptor(
            typeId: NodeTypeId(category: "Math", name: "MathOperation"),
            displayName: "Math",
            description: "Performs basic math operations",
            category: "Math",
            inputs: [
                InputPortDef(name: "a", type: NumberPort.self),
                InputPortDef(name: "b", type: NumberPort.self)
            ],
            outputs: [OutputPortDef(name: "result", type: NumberPort.self)],
            parameters: [
                NodeParameter(
                    name: "operation",
                    type: .choice,
                    defaultValue: .choice("add", options: ["add", "subtract", "multiply", "divide", "power", "modulo"])
                )
            ]
        )
        register(descriptor: mathOp, executor: MathOperationExecutor())
    }

    private func registerFlowNodes() {
        // Branch node (if/else)
        let branch = NodeDescriptor(
            typeId: NodeTypeId(category: "Flow", name: "Branch"),
            displayName: "Branch",
            description: "Routes data based on a condition",
            category: "Flow",
            inputs: [
                InputPortDef(name: "condition", type: BoolPort.self),
                InputPortDef(name: "trueValue", type: TextPort.self),
                InputPortDef(name: "falseValue", type: TextPort.self)
            ],
            outputs: [OutputPortDef(name: "result", type: TextPort.self)]
        )
        register(descriptor: branch, executor: BranchExecutor())

        // Compare node
        let compare = NodeDescriptor(
            typeId: NodeTypeId(category: "Flow", name: "Compare"),
            displayName: "Compare",
            description: "Compares two values",
            category: "Flow",
            inputs: [
                InputPortDef(name: "a", type: NumberPort.self),
                InputPortDef(name: "b", type: NumberPort.self)
            ],
            outputs: [OutputPortDef(name: "result", type: BoolPort.self)],
            parameters: [
                NodeParameter(
                    name: "operation",
                    type: .choice,
                    defaultValue: .choice("equals", options: ["equals", "notEquals", "lessThan", "greaterThan", "lessOrEqual", "greaterOrEqual"])
                )
            ]
        )
        register(descriptor: compare, executor: CompareExecutor())
    }

    private func registerIONodes() {
        // Graph Input node (receives data from parent graph or external)
        let graphInput = NodeDescriptor(
            typeId: NodeTypeId(category: "IO", name: "GraphInput"),
            displayName: "Graph Input",
            description: "Receives input data for this graph",
            category: "IO",
            inputs: [],
            outputs: [OutputPortDef(name: "value", type: TextPort.self)],
            parameters: [
                NodeParameter(name: "inputName", type: .text, defaultValue: .text("input")),
                NodeParameter(name: "dataType", type: .choice, defaultValue: .choice("text", options: ["text", "number", "bool", "image", "audio", "tensor", "json"]))
            ]
        )
        register(descriptor: graphInput, executor: GraphInputExecutor())

        // Graph Output node (sends data to parent graph or external)
        let graphOutput = NodeDescriptor(
            typeId: NodeTypeId(category: "IO", name: "GraphOutput"),
            displayName: "Graph Output",
            description: "Sends output data from this graph",
            category: "IO",
            inputs: [
                InputPortDef(name: "value", type: TextPort.self)
            ],
            outputs: [],
            parameters: [
                NodeParameter(name: "outputName", type: .text, defaultValue: .text("output"))
            ]
        )
        register(descriptor: graphOutput, executor: GraphOutputExecutor())
    }
}

// MARK: - Built-In Executors

struct TextInputExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        let value = instance.parameterValues["value"]?.stringValue ?? ""
        return ["text": AnyPortValue(TextPort(value))]
    }
}

struct TextTemplateExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        var template = instance.parameterValues["template"]?.stringValue ?? ""

        // Replace variables from input JSON
        if let jsonPort = inputs["variables"]?.as(JsonPort.self),
           let variables = try? jsonPort.dictionary() {
            for (key, value) in variables {
                template = template.replacingOccurrences(
                    of: "{\(key)}",
                    with: String(describing: value)
                )
            }
        }

        return ["result": AnyPortValue(TextPort(template))]
    }
}

struct TextConcatExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        let a = inputs["a"]?.as(TextPort.self)?.value ?? ""
        let b = inputs["b"]?.as(TextPort.self)?.value ?? ""
        let separator = instance.parameterValues["separator"]?.stringValue ?? ""

        return ["result": AnyPortValue(TextPort(a + separator + b))]
    }
}

struct NumberInputExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        let value = instance.parameterValues["value"]?.doubleValue ?? 0
        return ["value": AnyPortValue(NumberPort(value))]
    }
}

struct MathOperationExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        let a = inputs["a"]?.as(NumberPort.self)?.value ?? 0
        let b = inputs["b"]?.as(NumberPort.self)?.value ?? 0

        let operation: String
        if case .choice(let op, _) = instance.parameterValues["operation"] {
            operation = op
        } else {
            operation = "add"
        }

        let result: Double
        switch operation {
        case "add": result = a + b
        case "subtract": result = a - b
        case "multiply": result = a * b
        case "divide": result = b != 0 ? a / b : 0
        case "power": result = pow(a, b)
        case "modulo": result = b != 0 ? a.truncatingRemainder(dividingBy: b) : 0
        default: result = a + b
        }

        return ["result": AnyPortValue(NumberPort(result))]
    }
}

struct BranchExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        let condition = inputs["condition"]?.as(BoolPort.self)?.value ?? false

        if condition {
            if let trueValue = inputs["trueValue"]?.as(TextPort.self) {
                return ["result": AnyPortValue(trueValue)]
            }
        } else {
            if let falseValue = inputs["falseValue"]?.as(TextPort.self) {
                return ["result": AnyPortValue(falseValue)]
            }
        }

        return ["result": AnyPortValue(TextPort(""))]
    }
}

struct CompareExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        let a = inputs["a"]?.as(NumberPort.self)?.value ?? 0
        let b = inputs["b"]?.as(NumberPort.self)?.value ?? 0

        let operation: String
        if case .choice(let op, _) = instance.parameterValues["operation"] {
            operation = op
        } else {
            operation = "equals"
        }

        let result: Bool
        switch operation {
        case "equals": result = a == b
        case "notEquals": result = a != b
        case "lessThan": result = a < b
        case "greaterThan": result = a > b
        case "lessOrEqual": result = a <= b
        case "greaterOrEqual": result = a >= b
        default: result = false
        }

        return ["result": AnyPortValue(BoolPort(result))]
    }
}

struct GraphInputExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        // Graph inputs are resolved by the engine before execution
        // This executor returns a placeholder; the engine injects the actual value
        return ["value": AnyPortValue(TextPort(""))]
    }
}

struct GraphOutputExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        // Graph outputs pass through their input
        // The engine collects these as the graph's output
        return [:]
    }
}
