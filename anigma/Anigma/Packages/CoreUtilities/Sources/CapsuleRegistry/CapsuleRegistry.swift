import Foundation
import CapsuleCore
import TelemetryCore

// MARK: - CapsuleRegistry

/// Actor-based registry for managing capsule lifecycle and discovery
public actor CapsuleRegistry: Sendable {
    
    // MARK: - Properties
    
    /// Diagnostics for observability
    private let diagnostics: CapsuleDiagnostics
    
    /// Registry of loaded capsules
    private var capsules: [String: CapsuleInstance] = [:]
    
    /// Registry of available capsule metadata
    private var availableCapsules: [String: CapsuleMetadata] = [:]
    
    /// Configuration for the registry
    private let configuration: RegistryConfiguration
    
    /// File monitor for hot-reloading
    private let fileMonitor: FileSystemMonitor
    
    /// Event listeners for registry changes
    private var eventListeners: [CapsuleRegistryEventListener] = []
    
    // MARK: - Initialization
    
    /// Initialize CapsuleRegistry
    /// - Parameters:
    ///   - diagnostics: Diagnostics collector for observability
    ///   - configuration: Registry configuration
    ///   - packagesDirectory: Directory containing capsule packages
    public init(
        diagnostics: CapsuleDiagnostics,
        configuration: RegistryConfiguration = .default,
        packagesDirectory: String? = nil
    ) async throws {
        self.diagnostics = diagnostics
        self.configuration = configuration
        self.fileMonitor = FileSystemMonitor(
            directory: packagesDirectory ?? configuration.packagesDirectory,
            handler: { [weak self] event in
                Task { [weak self] in
                    await self?.handleFileSystemEvent(event)
                }
            }
        )
        
        let span = diagnostics.beginSpan(
            name: "CapsuleRegistry.init",
            category: "registry.initialization",
            correlationID: nil,
            tags: ["packages_directory": configuration.packagesDirectory]
        )
        
        do {
            // Load available capsules from packages directory
            try await loadAvailableCapsules()
            
            // Start file monitoring for hot-reload if enabled
            if configuration.enableHotReload {
                fileMonitor.start()
            }
            
            span.end(status: .ok)
            
            diagnostics.event(
                level: .info,
                category: "registry.initialization",
                message: "CapsuleRegistry initialized with \\(availableCapsules.count) available capsules",
                correlationID: nil,
                metadata: ["available_capsules": "\\(availableCapsules.count)"]
            )
            
        } catch {
            span.end(status: .error)
            diagnostics.event(
                level: .error,
                category: "registry.initialization",
                message: "Failed to initialize CapsuleRegistry: \\(error)",
                correlationID: nil,
                metadata: [:]
            )
            throw CapsuleError.internalError(details: "CapsuleRegistry initialization failed: \\(error)")
        }
    }
    
    deinit {
        fileMonitor.stop()
    }
    
    // MARK: - Public API
    
    /// Load a capsule by ID
    /// - Parameters:
    ///   - capsuleID: Unique identifier of the capsule
    ///   - correlationID: Request ID for tracing
    /// - Returns: Capsule instance
    /// - Throws: CapsuleError if loading fails
    public func loadCapsule(
        _ capsuleID: String,
        correlationID: String? = nil
    ) async throws -> CapsuleInstance {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "CapsuleRegistry.loadCapsule",
            category: "registry.loading",
            correlationID: corrID,
            tags: ["capsule_id": capsuleID]
        )
        
        defer { span.end(status: .ok) }
        
        guard let metadata = availableCapsules[capsuleID] else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "capsuleID",
                constraint: "Capsule not found in registry: \\(capsuleID)"
            )
        }
        
        // Check if already loaded
        if let existing = capsules[capsuleID] {
            if existing.state == .active {
                diagnostics.event(
                    level: .debug,
                    category: "registry.loading",
                    message: "Capsule already active: \\(capsuleID)",
                    correlationID: corrID,
                    metadata: [:]
                )
                return existing
            } else if existing.state == .loading {
                throw CapsuleError.operationFailed(
                    code: 1001,
                    message: "Capsule is already being loaded",
                    context: ["capsule_id": capsuleID]
                )
            }
        }
        
        // Create new instance and load
        let instance = CapsuleInstance(metadata: metadata)
        capsules[capsuleID] = instance
        instance.updateState(.loading)
        
        do {
            // Check dependencies
            try await checkDependencies(metadata, correlationID: corrID)
            
            // Load the capsule
            try await performCapsuleLoad(instance, correlationID: corrID)
            
            instance.updateState(.active)
            instance.updateHealth(CapsuleHealth(status: .healthy))
            
            // Notify listeners
            await notifyCapsuleLoaded(instance)
            
            diagnostics.event(
                level: .info,
                category: "registry.loading",
                message: "Capsule loaded successfully: \\(capsuleID)",
                correlationID: corrID,
                metadata: [
                    "capsule_name": metadata.name,
                    "version": metadata.version.description
                ]
            )
            
            return instance
            
        } catch {
            instance.updateState(.error, error: error as? CapsuleError ?? CapsuleError.internalError(details: "\\(error)"))
            span.end(status: .error)
            
            diagnostics.event(
                level: .error,
                category: "registry.loading",
                message: "Failed to load capsule: \\(capsuleID) - \\(error)",
                correlationID: corrID,
                metadata: [:]
            )
            
            throw error
        }
    }
    
    /// Unload a capsule
    /// - Parameters:
    ///   - capsuleID: Unique identifier of the capsule
    ///   - correlationID: Request ID for tracing
    /// - Throws: CapsuleError if unloading fails
    public func unloadCapsule(
        _ capsuleID: String,
        correlationID: String? = nil
    ) async throws {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "CapsuleRegistry.unloadCapsule",
            category: "registry.unloading",
            correlationID: corrID,
            tags: ["capsule_id": capsuleID]
        )
        
        guard let instance = capsules[capsuleID] else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "capsuleID",
                constraint: "Capsule not loaded: \\(capsuleID)"
            )
        }
        
        guard instance.state == .active || instance.state == .error else {
            span.end(status: .error)
            throw CapsuleError.operationFailed(
                code: 1002,
                message: "Cannot unload capsule in state: \\(instance.state.rawValue)",
                context: ["capsule_id": capsuleID, "state": instance.state.rawValue]
            )
        }
        
        do {
            instance.updateState(.unloading)
            
            // Check for dependent capsules
            try await checkDependents(capsuleID, correlationID: corrID)
            
            // Perform unload
            try await performCapsuleUnload(instance, correlationID: corrID)
            
            instance.updateState(.unloaded)
            capsules.removeValue(forKey: capsuleID)
            
            // Notify listeners
            await notifyCapsuleUnloaded(instance)
            
            span.end(status: .ok)
            
            diagnostics.event(
                level: .info,
                category: "registry.unloading",
                message: "Capsule unloaded successfully: \\(capsuleID)",
                correlationID: corrID,
                metadata: [:]
            )
            
        } catch {
            instance.updateState(.error, error: error as? CapsuleError ?? CapsuleError.internalError(details: "\\(error)"))
            span.end(status: .error)
            throw error
        }
    }
    
    /// Get a loaded capsule instance
    /// - Parameter capsuleID: Unique identifier of the capsule
    /// - Returns: Capsule instance if loaded
    public func getCapsule(_ capsuleID: String) -> CapsuleInstance? {
        return capsules[capsuleID]
    }
    
    /// Get all loaded capsules
    /// - Returns: Dictionary of loaded capsule instances
    public func getAllLoadedCapsules() -> [String: CapsuleInstance] {
        return capsules
    }
    
    /// Get all available capsule metadata
    /// - Returns: Dictionary of available capsule metadata
    public func getAllAvailableCapsules() -> [String: CapsuleMetadata] {
        return availableCapsules
    }
    
    /// Reload a capsule (unload then load)
    /// - Parameters:
    ///   - capsuleID: Unique identifier of the capsule
    ///   - correlationID: Request ID for tracing
    /// - Returns: New capsule instance
    /// - Throws: CapsuleError if reload fails
    public func reloadCapsule(
        _ capsuleID: String,
        correlationID: String? = nil
    ) async throws -> CapsuleInstance {
        let corrID = correlationID ?? CorrelationIDContext.current
        
        // Unload if loaded
        if capsules[capsuleID] != nil {
            try await unloadCapsule(capsuleID, correlationID: corrID)
        }
        
        // Load again
        return try await loadCapsule(capsuleID, correlationID: corrID)
    }
    
    /// Add event listener for registry changes
    /// - Parameter listener: Event listener
    public func addEventListener(_ listener: CapsuleRegistryEventListener) {
        eventListeners.append(listener)
    }
    
    /// Remove event listener
    /// - Parameter listener: Event listener to remove
    public func removeEventListener(_ listener: CapsuleRegistryEventListener) {
        eventListeners.removeAll { $0.id == listener.id }
    }
    
    /// Get registry health status
    /// - Returns: Health information
    public func getHealthStatus() -> RegistryHealth {
        return RegistryHealth(
            totalAvailable: availableCapsules.count,
            loadedActive: capsules.values.filter { $0.state == .active }.count,
            loadedError: capsules.values.filter { $0.state == .error }.count,
            uptime: ProcessInfo.processInfo.systemUptime,
            hotReloadEnabled: configuration.enableHotReload
        )
    }
    
    // MARK: - Private Methods
    
    private func loadAvailableCapsules() async throws {
        let packagesURL = URL(fileURLWithPath: configuration.packagesDirectory)
        
        guard FileManager.default.fileExists(atPath: packagesURL.path) else {
            throw CapsuleError.invalidConfiguration(
                reason: "Packages directory does not exist: \\(configuration.packagesDirectory)"
            )
        }
        
        let enumerator = FileManager.default.enumerator(at: packagesURL, includingPropertiesForKeys: nil)
        
        while let url = enumerator?.nextObject() as? URL {
            if url.hasDirectoryPath {
                await loadCapsuleFromDirectory(url)
            }
        }
    }
    
    private func loadCapsuleFromDirectory(_ url: URL) async {
        do {
            let metadataURL = url.appendingPathComponent("Capsule.json")
            guard FileManager.default.fileExists(atPath: metadataURL.path) else { return }
            
            let data = try Data(contentsOf: metadataURL)
            let metadata = try JSONDecoder().decode(CapsuleMetadata.self, from: data)
            
            availableCapsules[metadata.id] = metadata
            
            diagnostics.event(
                level: .debug,
                category: "registry.discovery",
                message: "Discovered capsule: \\(metadata.name)",
                correlationID: nil,
                metadata: [
                    "capsule_id": metadata.id,
                    "version": metadata.version.description
                ]
            )
            
        } catch {
            diagnostics.event(
                level: .warning,
                category: "registry.discovery",
                message: "Failed to load capsule metadata from \\(url.lastPathComponent): \\(error)",
                correlationID: nil,
                metadata: ["path": url.path]
            )
        }
    }
    
    private func checkDependencies(_ metadata: CapsuleMetadata, correlationID: String) async throws {
        for dependency in metadata.dependencies {
            guard !dependency.optional else { continue }
            
            let loadedInstance = capsules[dependency.name]
            guard let instance = loadedInstance, instance.state == .active else {
                throw CapsuleError.operationFailed(
                    code: 1003,
                    message: "Required dependency not loaded: \\(dependency.name)",
                    context: [
                        "capsule_id": metadata.id,
                        "dependency": dependency.name,
                        "version_requirement": "\\(dependency.versionRequirement)"
                    ]
                )
            }
            
            guard dependency.versionRequirement.satisfies(instance.metadata.version) else {
                throw CapsuleError.operationFailed(
                    code: 1004,
                    message: "Dependency version mismatch: \\(dependency.name)",
                    context: [
                        "capsule_id": metadata.id,
                        "dependency": dependency.name,
                        "required": "\\(dependency.versionRequirement)",
                        "actual": "\\(instance.metadata.version)"
                    ]
                )
            }
        }
    }
    
    private func checkDependents(_ capsuleID: String, correlationID: String) async throws {
        for (_, instance) in capsules {
            guard instance.state == .active else { continue }
            
            for dependency in instance.metadata.dependencies {
                if dependency.name == capsuleID && !dependency.optional {
                    throw CapsuleError.operationFailed(
                        code: 1005,
                        message: "Cannot unload capsule: has active dependents",
                        context: [
                            "capsule_id": capsuleID,
                            "dependent": instance.metadata.id
                        ]
                    )
                }
            }
        }
    }
    
    private func performCapsuleLoad(_ instance: CapsuleInstance, correlationID: String) async throws {
        // This would be implemented by the specific capsule type
        // For now, simulate successful loading
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
    }
    
    private func performCapsuleUnload(_ instance: CapsuleInstance, correlationID: String) async throws {
        // This would be implemented by the specific capsule type
        // For now, simulate successful unloading
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
    }
    
    private func handleFileSystemEvent(_ event: FileSystemEvent) async {
        switch event.type {
        case .modified, .added:
            await loadCapsuleFromDirectory(event.url)
        case .deleted:
            // Handle capsule removal
            break
        }
    }
    
    private func notifyCapsuleLoaded(_ instance: CapsuleInstance) async {
        let event = CapsuleRegistryEvent.capsuleLoaded(instance)
        for listener in eventListeners {
            await listener.handleEvent(event)
        }
    }
    
    private func notifyCapsuleUnloaded(_ instance: CapsuleInstance) async {
        let event = CapsuleRegistryEvent.capsuleUnloaded(instance)
        for listener in eventListeners {
            await listener.handleEvent(event)
        }
    }
}

// MARK: - Supporting Types

/// Configuration for CapsuleRegistry
public struct RegistryConfiguration: Sendable {
    public let packagesDirectory: String
    public let enableHotReload: Bool
    public let maxConcurrentLoads: Int
    public let loadTimeout: TimeInterval
    
    public static let `default` = RegistryConfiguration(
        packagesDirectory: "./Packages",
        enableHotReload: true,
        maxConcurrentLoads: 5,
        loadTimeout: 30.0
    )
    
    public init(
        packagesDirectory: String,
        enableHotReload: Bool = true,
        maxConcurrentLoads: Int = 5,
        loadTimeout: TimeInterval = 30.0
    ) {
        self.packagesDirectory = packagesDirectory
        self.enableHotReload = enableHotReload
        self.maxConcurrentLoads = maxConcurrentLoads
        self.loadTimeout = loadTimeout
    }
}

/// Health status for the registry
public struct RegistryHealth: Codable, Sendable {
    public let totalAvailable: Int
    public let loadedActive: Int
    public let loadedError: Int
    public let uptime: TimeInterval
    public let hotReloadEnabled: Bool
    
    public var status: String {
        if loadedError > 0 {
            return "degraded"
        } else if loadedActive > 0 {
            return "healthy"
        } else {
            return "idle"
        }
    }
}

/// File system monitor for hot-reloading
internal class FileSystemMonitor {
    private let directory: String
    private let handler: (FileSystemEvent) -> Void
    private var fileWatcher: DispatchSourceFileSystemObject?
    
    init(directory: String, handler: @escaping (FileSystemEvent) -> Void) {
        self.directory = directory
        self.handler = handler
    }
    
    func start() {
        let fileDescriptor = open(directory, O_EVTONLY)
        guard fileDescriptor != -1 else { return }
        
        fileWatcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue(label: "filesystem.monitor")
        )
        
        fileWatcher?.setEventHandler { [weak self] in
            // Handle file system events
            Task { [weak self] in
                let event = FileSystemEvent(url: URL(fileURLWithPath: self?.directory ?? ""), type: .modified)
                self?.handler(event)
            }
        }
        
        fileWatcher?.setCancelHandler {
            close(fileDescriptor)
        }
        
        fileWatcher?.resume()
    }
    
    func stop() {
        fileWatcher?.cancel()
        fileWatcher = nil
    }
}

/// File system event
internal struct FileSystemEvent {
    let url: URL
    let type: FileSystemEventType
}

enum FileSystemEventType {
    case added
    case modified
    case deleted
}