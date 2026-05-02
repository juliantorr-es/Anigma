//
//  PluginSystem.swift
//  AnigmaCore
//
//  Plugin architecture for extending the Graphene pipeline.
//
//  Inspired by Graphite's extensibility model:
//  - Dynamic node registration
//  - Sandboxed plugin execution
//  - Plugin manifest and versioning
//  - Hot-reloading support (development mode)
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import ContractsCore
import InferenceCore
import Foundation

// MARK: - Plugin Protocol

/// Protocol for Graphene pipeline plugins.
public protocol GraphenePlugin: Sendable {
    /// Unique identifier for this plugin.
    var identifier: PluginIdentifier { get }

    /// Human-readable name.
    var displayName: String { get }

    /// Plugin version.
    var version: PluginVersion { get }

    /// Description of what this plugin provides.
    var description: String { get }

    /// Author information.
    var author: String { get }

    /// Required minimum Graphene version.
    var minimumEngineVersion: PluginVersion { get }

    /// Node descriptors provided by this plugin.
    var nodeDescriptors: [NodeDescriptor] { get }

    /// Node executors provided by this plugin.
    var nodeExecutors: [NodeTypeId: any NodeExecutor] { get }

    /// Called when the plugin is loaded.
    func onLoad() async throws

    /// Called when the plugin is unloaded.
    func onUnload() async throws
}

extension GraphenePlugin {
    public var minimumEngineVersion: PluginVersion { PluginVersion(major: 1, minor: 0, patch: 0) }

    public func onLoad() async throws {}
    public func onUnload() async throws {}
}

// MARK: - Plugin Identifier

/// Unique identifier for a plugin.
public struct PluginIdentifier: Hashable, Codable, Sendable {
    public let organization: String
    public let name: String

    public var fullId: String { "\(organization).\(name)" }

    public init(organization: String, name: String) {
        self.organization = organization
        self.name = name
    }
}

// MARK: - Plugin Version

/// Semantic version for plugins.
public struct PluginVersion: Hashable, Codable, Sendable, Comparable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let prerelease: String?

    public var string: String {
        var s = "\(major).\(minor).\(patch)"
        if let pre = prerelease {
            s += "-\(pre)"
        }
        return s
    }

    public init(major: Int, minor: Int, patch: Int, prerelease: String? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = prerelease
    }

    public static func < (lhs: PluginVersion, rhs: PluginVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

// MARK: - Plugin Manifest

/// Manifest describing a plugin's metadata and requirements.
public struct PluginManifest: Codable, Sendable {
    public let identifier: PluginIdentifier
    public let displayName: String
    public let version: PluginVersion
    public let description: String
    public let author: String
    public let license: String
    public let homepage: URL?
    public let minimumEngineVersion: PluginVersion
    public let dependencies: [PluginDependency]
    public let nodeTypes: [String]
    public let capabilities: [PluginCapability]

    public struct PluginDependency: Codable, Sendable {
        public let identifier: PluginIdentifier
        public let minimumVersion: PluginVersion
    }

    public enum PluginCapability: String, Codable, Sendable {
        case nodes  // Provides custom nodes
        case processors  // Provides data processors
        case models  // Bundles ML models
        case tools  // Provides external tool integrations
        case themes  // Provides UI themes
    }
}

// MARK: - Plugin State

/// Tracks the state of a loaded plugin.
public struct PluginState: Sendable {
    public let identifier: PluginIdentifier
    public let version: PluginVersion
    public var status: PluginStatus
    public var loadedAt: Date?
    public var error: String?
    public var registeredNodes: [NodeTypeId]

    public enum PluginStatus: String, Sendable {
        case discovered
        case loading
        case loaded
        case failed
        case disabled
        case unloading
    }
}

// MARK: - Plugin Manager

/// Manages plugin lifecycle and registration.
public actor PluginManager {
    public static let shared = PluginManager()

    private let registry: NodeRegistry
    private var plugins: [PluginIdentifier: any GraphenePlugin] = [:]
    private var pluginStates: [PluginIdentifier: PluginState] = [:]
    private var loadOrder: [PluginIdentifier] = []

    private init() {
        self.registry = NodeRegistry.shared
    }

    // MARK: - Plugin Loading

    /// Load a plugin.
    public func loadPlugin(_ plugin: any GraphenePlugin) async throws {
        let identifier = plugin.identifier

        // Check if already loaded
        if plugins[identifier] != nil {
            throw PluginError.alreadyLoaded(identifier)
        }

        // Update state
        var state = PluginState(
            identifier: identifier,
            version: plugin.version,
            status: .loading,
            registeredNodes: []
        )
        pluginStates[identifier] = state

        do {
            // Call plugin's onLoad
            try await plugin.onLoad()

            // Register all node types
            for descriptor in plugin.nodeDescriptors {
                if let executor = plugin.nodeExecutors[descriptor.typeId] {
                    await registry.register(descriptor: descriptor, executor: executor)
                    state.registeredNodes.append(descriptor.typeId)
                }
            }

            // Update state
            state.status = .loaded
            state.loadedAt = Date()
            pluginStates[identifier] = state

            plugins[identifier] = plugin
            loadOrder.append(identifier)

        } catch {
            state.status = .failed
            state.error = error.localizedDescription
            pluginStates[identifier] = state
            throw error
        }
    }

    /// Unload a plugin.
    public func unloadPlugin(_ identifier: PluginIdentifier) async throws {
        guard let plugin = plugins[identifier] else {
            throw PluginError.notFound(identifier)
        }

        guard var state = pluginStates[identifier] else {
            throw PluginError.notFound(identifier)
        }

        state.status = .unloading
        pluginStates[identifier] = state

        // Call plugin's onUnload
        try await plugin.onUnload()

        // Unregister all node types
        for nodeTypeId in state.registeredNodes {
            await registry.unregister(nodeTypeId)
        }

        // Remove from tracking
        plugins[identifier] = nil
        pluginStates[identifier] = nil
        loadOrder.removeAll { $0 == identifier }
    }

    /// Reload a plugin (development mode).
    public func reloadPlugin(_ identifier: PluginIdentifier) async throws {
        guard let plugin = plugins[identifier] else {
            throw PluginError.notFound(identifier)
        }

        try await unloadPlugin(identifier)
        try await loadPlugin(plugin)
    }

    // MARK: - Plugin Discovery

    /// Discover plugins from a directory.
    public func discoverPlugins(in directory: URL) async throws -> [PluginManifest] {
        var manifests: [PluginManifest] = []

        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey]
        )

        for url in contents {
            let manifestURL = url.appendingPathComponent("manifest.json")
            if fileManager.fileExists(atPath: manifestURL.path) {
                let data = try Data(contentsOf: manifestURL)
                let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)
                manifests.append(manifest)
            }
        }

        return manifests
    }

    // MARK: - Plugin Queries

    /// Get all loaded plugins.
    public func loadedPlugins() -> [PluginIdentifier] {
        loadOrder
    }

    /// Get plugin state.
    public func state(for identifier: PluginIdentifier) -> PluginState? {
        pluginStates[identifier]
    }

    /// Get all plugin states.
    public func allStates() -> [PluginState] {
        Array(pluginStates.values)
    }

    /// Check if a plugin is loaded.
    public func isLoaded(_ identifier: PluginIdentifier) -> Bool {
        plugins[identifier] != nil
    }

    /// Get nodes provided by a plugin.
    public func nodes(from identifier: PluginIdentifier) -> [NodeTypeId] {
        pluginStates[identifier]?.registeredNodes ?? []
    }
}

// MARK: - Plugin Errors

public enum PluginError: Error, LocalizedError {
    case alreadyLoaded(PluginIdentifier)
    case notFound(PluginIdentifier)
    case incompatibleVersion(required: PluginVersion, actual: PluginVersion)
    case dependencyMissing(PluginIdentifier)
    case manifestInvalid(reason: String)
    case loadFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .alreadyLoaded(let id):
            return "Plugin already loaded: \(id.fullId)"
        case .notFound(let id):
            return "Plugin not found: \(id.fullId)"
        case .incompatibleVersion(let required, let actual):
            return "Incompatible version: requires \(required.string), got \(actual.string)"
        case .dependencyMissing(let id):
            return "Missing dependency: \(id.fullId)"
        case .manifestInvalid(let reason):
            return "Invalid manifest: \(reason)"
        case .loadFailed(let reason):
            return "Plugin load failed: \(reason)"
        }
    }
}

// MARK: - Built-In Plugin Base

/// Base class for built-in plugins.
open class BuiltInPlugin: GraphenePlugin, @unchecked Sendable {

    public let identifier: PluginIdentifier
    public let displayName: String
    public let version: PluginVersion
    public let description: String
    public let author: String

    open var nodeDescriptors: [NodeDescriptor] { [] }
    open var nodeExecutors: [NodeTypeId: any NodeExecutor] { [:] }

    public init(
        organization: String,
        name: String,
        displayName: String,
        version: PluginVersion = PluginVersion(major: 1, minor: 0, patch: 0),
        description: String = "",
        author: String = "Anigma"
    ) {
        self.identifier = PluginIdentifier(organization: organization, name: name)
        self.displayName = displayName
        self.version = version
        self.description = description
        self.author = author
    }
}

// MARK: - Script Node Support

/// Configuration for script-based nodes.
public struct ScriptNodeConfig: Sendable {
    public let language: ScriptLanguage
    public let source: String
    public let inputs: [InputPortDef]
    public let outputs: [OutputPortDef]
    public let parameters: [NodeParameter]
    public var isSandboxed: Bool

    public enum ScriptLanguage: String, Codable, Sendable {
        case javascript
        case python
        case lua
    }

    public init(
        language: ScriptLanguage,
        source: String,
        inputs: [InputPortDef] = [],
        outputs: [OutputPortDef] = [],
        parameters: [NodeParameter] = [],
        isSandboxed: Bool = true
    ) {
        self.language = language
        self.source = source
        self.inputs = inputs
        self.outputs = outputs
        self.parameters = parameters
        self.isSandboxed = isSandboxed
    }
}

/// Executor for script-based nodes (placeholder for future implementation).
public struct ScriptNodeExecutor: NodeExecutor {
    public let config: ScriptNodeConfig
    public let runtime: any ScriptRuntime

    public init(config: ScriptNodeConfig, runtime: any ScriptRuntime = UnavailableScriptRuntime()) {
        self.config = config
        self.runtime = runtime
    }

    public func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        let sandbox = config.isSandboxed ? PluginSandbox.restrictive : PluginSandbox.permissive
        let request = ScriptExecutionRequest(
            language: config.language,
            source: config.source,
            inputs: inputs,
            parameters: instance.parameterValues,
            sandbox: sandbox
        )
        let resolvedRuntime = await ScriptRuntimeRegistry.shared.resolveRuntime(
            preferred: runtime,
            language: request.language
        )
        return try await resolvedRuntime.execute(request, context: context)
    }
}

/// Execution request for a script runtime.
public struct ScriptExecutionRequest: Sendable {
    public let language: ScriptNodeConfig.ScriptLanguage
    public let source: String
    public let inputs: [String: AnyPortValue]
    public let parameters: [String: ParameterValue]
    public let sandbox: PluginSandbox

    public init(
        language: ScriptNodeConfig.ScriptLanguage,
        source: String,
        inputs: [String: AnyPortValue],
        parameters: [String: ParameterValue],
        sandbox: PluginSandbox
    ) {
        self.language = language
        self.source = source
        self.inputs = inputs
        self.parameters = parameters
        self.sandbox = sandbox
    }
}

/// Script runtime execution surface for plugin nodes.
public protocol ScriptRuntime: Sendable {
    /// Execute a script request and return output port values.
    func execute(_ request: ScriptExecutionRequest, context: GrapheneExecutionContext) async throws
        -> [String: AnyPortValue]
}

/// Errors emitted by script runtimes.
public enum ScriptGenericCoreError: Error, LocalizedError, Sendable {
    case unavailable(String)
    case sandboxViolation(String)
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable(let detail):
            return "Script runtime unavailable: \(detail)"
        case .sandboxViolation(let detail):
            return "Script runtime sandbox violation: \(detail)"
        case .executionFailed(let detail):
            return "Script runtime failed: \(detail)"
        }
    }
}

/// Registry for resolving script runtimes by language.
public actor ScriptRuntimeRegistry {
    public static let shared = ScriptRuntimeRegistry()

    private var runtimes: [ScriptNodeConfig.ScriptLanguage: any ScriptRuntime] = [:]
    private var defaultRuntime: any ScriptRuntime = LocalProcessScriptRuntime()

    private init() {}

    public func setRuntime(
        _ runtime: any ScriptRuntime,
        for language: ScriptNodeConfig.ScriptLanguage
    ) {
        runtimes[language] = runtime
    }

    public func clearRuntime(for language: ScriptNodeConfig.ScriptLanguage) {
        runtimes[language] = nil
    }

    public func setDefaultRuntime(_ runtime: any ScriptRuntime) {
        defaultRuntime = runtime
    }

    public func resolveRuntime(
        preferred: any ScriptRuntime,
        language: ScriptNodeConfig.ScriptLanguage
    ) -> any ScriptRuntime {
        if !(preferred is UnavailableScriptRuntime) {
            return preferred
        }
        return runtimes[language] ?? defaultRuntime
    }
}

public struct UnavailableScriptRuntime: ScriptRuntime {
    public init() {}

    public func execute(
        _ request: ScriptExecutionRequest,
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        throw ScriptGenericCoreError.unavailable("No script runtime registered.")
    }
}

/// Process-based script runtime for development or permissive execution paths.
public struct LocalProcessScriptRuntime: ScriptRuntime {
    public let interpreter: [ScriptNodeConfig.ScriptLanguage: String]

    public init(
        interpreter: [ScriptNodeConfig.ScriptLanguage: String] = [
            .javascript: "node",
            .python: "python3",
            .lua: "lua"
        ]
    ) {
        self.interpreter = interpreter
    }

    public func execute(
        _ request: ScriptExecutionRequest,
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        guard request.sandbox.allowNetworkAccess,
            request.sandbox.allowFileSystemRead,
            request.sandbox.allowFileSystemWrite
        else {
            throw ScriptGenericCoreError.sandboxViolation(
                "LocalProcessScriptRuntime requires permissive sandbox settings.")
        }

        guard let runtime = interpreter[request.language] else {
            throw ScriptGenericCoreError.unavailable(
                "No interpreter configured for \(request.language).")
        }

        let scriptURL = try await context.resourceManager.createTempFile(
            extension: scriptExtension(for: request.language))
        try request.source.write(to: scriptURL, atomically: true, encoding: .utf8)

        let payload = try ScriptRuntimeRequestPayload.from(request: request)
        let inputData = try JSONEncoder().encode(payload)

        let result = try await runProcess(
            executable: "/usr/bin/env",
            arguments: [runtime, scriptURL.path],
            input: inputData,
            timeout: request.sandbox.executionTimeout
        )

        guard result.exitCode == 0 else {
            throw ScriptGenericCoreError.executionFailed(result.stderr)
        }

        guard !result.stdout.isEmpty else { return [:] }
        let outputs = try JSONDecoder().decode(ScriptRuntimeOutputPayload.self, from: result.stdout)
        return try outputs.toPortValues()
    }
}

private struct ScriptRuntimeRequestPayload: Codable {
    let inputs: [String: ScriptValue]
    let parameters: [String: ParameterValue]

    static func from(request: ScriptExecutionRequest) throws -> ScriptRuntimeRequestPayload {
        let inputs = try request.inputs.mapValues { try ScriptValue.from(portValue: $0) }
        return ScriptRuntimeRequestPayload(inputs: inputs, parameters: request.parameters)
    }
}

private struct ScriptRuntimeOutputPayload: Codable {
    let outputs: [String: ScriptValue]

    func toPortValues() throws -> [String: AnyPortValue] {
        try outputs.mapValues { try $0.toPortValue() }
    }
}

private enum ScriptValueType: String, Codable {
    case text
    case number
    case boolean
    case json
}

private struct ScriptValue: Codable {
    let type: ScriptValueType
    let text: String?
    let number: Double?
    let boolean: Bool?
    let json: String?

    static func from(portValue: AnyPortValue) throws -> ScriptValue {
        if let text = portValue.as(TextPort.self) {
            return ScriptValue(type: .text, text: text.value, number: nil, boolean: nil, json: nil)
        }
        if let number = portValue.as(NumberPort.self) {
            return ScriptValue(
                type: .number, text: nil, number: number.value, boolean: nil, json: nil)
        }
        if let bool = portValue.as(BoolPort.self) {
            return ScriptValue(
                type: .boolean, text: nil, number: nil, boolean: bool.value, json: nil)
        }
        if let jsonPort = portValue.as(JsonPort.self) {
            let jsonString = String(data: jsonPort.data, encoding: .utf8) ?? "{}"
            return ScriptValue(type: .json, text: nil, number: nil, boolean: nil, json: jsonString)
        }
        throw ScriptGenericCoreError.executionFailed("Unsupported port type: \(portValue.typeId)")
    }

    func toPortValue() throws -> AnyPortValue {
        switch type {
        case .text:
            return AnyPortValue(TextPort(text ?? ""))
        case .number:
            return AnyPortValue(NumberPort(number ?? 0))
        case .boolean:
            return AnyPortValue(BoolPort(boolean ?? false))
        case .json:
            let data = (json ?? "{}").data(using: .utf8) ?? Data()
            return AnyPortValue(JsonPort(data: data))
        }
    }
}

private func scriptExtension(for language: ScriptNodeConfig.ScriptLanguage) -> String {
    switch language {
    case .javascript:
        return "js"
    case .python:
        return "py"
    case .lua:
        return "lua"
    }
}

private struct LocalProcessResult {
    let exitCode: Int32
    let stdout: Data
    let stderr: String
}

import os

private final class ProcessCompletion: Sendable {
    private let state = OSAllocatedUnfairLock(initialState: false)

    func shouldTerminate() -> Bool {
        state.withLock { finished in
            // Return true if NOT finished (i.e. should terminate process)
            let result = !finished
            return result
        }
    }

    func finish(
        _ result: Result<LocalProcessResult, Error>,
        continuation: CheckedContinuation<LocalProcessResult, Error>
    ) {
        let alreadyFinished = state.withLock { finished in
            if finished {
                return true
            }
            finished = true
            return false
        }

        if !alreadyFinished {
            continuation.resume(with: result)
        }
    }
}

private func runProcess(
    executable: String,
    arguments: [String],
    input: Data,
    timeout: TimeInterval
) async throws -> LocalProcessResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    let stdinPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    process.standardInput = stdinPipe

    try process.run()

    stdinPipe.fileHandleForWriting.write(input)
    stdinPipe.fileHandleForWriting.closeFile()

    return try await withCheckedThrowingContinuation { continuation in
        let state = ProcessCompletion()

        let finish: @Sendable (Result<LocalProcessResult, Error>) -> Void = { result in
            state.finish(result, continuation: continuation)
        }

        process.terminationHandler = { process in
            let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            finish(
                .success(
                    LocalProcessResult(
                        exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)))
        }

        if timeout > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                guard state.shouldTerminate() else { return }
                process.terminate()
                finish(.failure(ScriptGenericCoreError.executionFailed("Script timed out.")))
            }
        }
    }
}

// MARK: - Plugin Sandbox

/// Sandbox configuration for plugin execution.
public struct PluginSandbox: Sendable {
    public var allowNetworkAccess: Bool
    public var allowFileSystemRead: Bool
    public var allowFileSystemWrite: Bool
    public var allowedPaths: [String]
    public var memoryLimit: Int  // bytes
    public var executionTimeout: TimeInterval

    public static let restrictive = PluginSandbox(
        allowNetworkAccess: false,
        allowFileSystemRead: false,
        allowFileSystemWrite: false,
        allowedPaths: [],
        memoryLimit: 64 * 1024 * 1024,  // 64MB
        executionTimeout: 30
    )

    public static let permissive = PluginSandbox(
        allowNetworkAccess: true,
        allowFileSystemRead: true,
        allowFileSystemWrite: true,
        allowedPaths: [],
        memoryLimit: 512 * 1024 * 1024,  // 512MB
        executionTimeout: 300
    )

    public init(
        allowNetworkAccess: Bool = false,
        allowFileSystemRead: Bool = false,
        allowFileSystemWrite: Bool = false,
        allowedPaths: [String] = [],
        memoryLimit: Int = 64 * 1024 * 1024,
        executionTimeout: TimeInterval = 30
    ) {
        self.allowNetworkAccess = allowNetworkAccess
        self.allowFileSystemRead = allowFileSystemRead
        self.allowFileSystemWrite = allowFileSystemWrite
        self.allowedPaths = allowedPaths
        self.memoryLimit = memoryLimit
        self.executionTimeout = executionTimeout
    }
}
