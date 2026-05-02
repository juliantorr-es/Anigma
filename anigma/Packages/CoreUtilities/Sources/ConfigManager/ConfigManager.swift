import Foundation
import CapsuleCore
import TelemetryCore

// MARK: - Config Manager

/// Actor-based configuration manager with validation and hot-reload support
public actor ConfigManager: Sendable {
    
    // MARK: - Properties
    
    /// Diagnostics for observability
    private let diagnostics: CapsuleDiagnostics
    
    /// Configuration for the config manager
    private let configuration: ConfigManagerConfiguration
    
    /// Loaded configurations by namespace
    private var configurations: [String: Configuration] = [:]
    
    /// Configuration schemas for validation
    private var schemas: [String: ConfigurationSchema] = [:]
    
    /// File monitors for hot-reload
    private var fileMonitors: [String: ConfigurationFileMonitor] = [:]
    
    /// Event listeners for configuration changes
    private var eventListeners: [ConfigEventListener] = []
    
    /// Environment variable overrides
    private let environmentOverrides: EnvironmentOverrides
    
    // MARK: - Initialization
    
    /// Initialize ConfigManager
    /// - Parameters:
    ///   - diagnostics: Diagnostics collector for observability
    ///   - configuration: Config manager configuration
    public init(
        diagnostics: CapsuleDiagnostics,
        configuration: ConfigManagerConfiguration = .default
    ) async {
        self.diagnostics = diagnostics
        self.configuration = configuration
        self.environmentOverrides = EnvironmentOverrides()
        
        let span = diagnostics.beginSpan(
            name: "ConfigManager.init",
            category: "config.initialization",
            correlationID: nil,
            tags: [:]
        )
        
        do {
            // Load default configurations
            try await loadDefaultConfigurations()
            
            // Load schemas
            try await loadConfigurationSchemas()
            
            // Setup file monitoring for hot-reload
            if configuration.enableHotReload {
                await setupFileMonitoring()
            }
            
            span.end(status: .ok)
            
            diagnostics.event(
                level: .info,
                category: "config.initialization",
                message: "ConfigManager initialized with \(configurations.count) configurations",
                correlationID: nil,
                metadata: ["config_count": "\(configurations.count)"]
            )
            
        } catch {
            span.end(status: .error)
            throw CapsuleError.internalError(details: "ConfigManager initialization failed: \(error)")
        }
    }
    
    deinit {
        Task {
            await shutdown()
        }
    }
    
    // MARK: - Public API
    
    /// Get configuration value
    /// - Parameters:
    ///   - key: Configuration key (supports dot notation)
    ///   - namespace: Configuration namespace
    ///   - type: Expected value type
    ///   - defaultValue: Default value if key not found
    ///   - correlationID: Request ID for tracing
    /// - Returns: Configuration value
    public func getValue<T>(
        key: String,
        namespace: String = "default",
        type: T.Type,
        defaultValue: T? = nil,
        correlationID: String? = nil
    ) async throws -> T? where T: Codable {
        let corrID = correlationID ?? CorrelationIDContext.current
        
        guard let config = configurations[namespace] else {
            if let defaultValue = defaultValue {
                return defaultValue
            }
            throw CapsuleError.invalidInput(
                field: "namespace",
                constraint: "Configuration namespace not found: \(namespace)"
            )
        }
        
        // Check environment override first
        if let envValue = environmentOverrides.getValue(key: key, namespace: namespace, type: type) {
            return envValue
        }
        
        // Get value from configuration
        let value = try config.getValue(key: key, type: type)
        
        diagnostics.event(
            level: .debug,
            category: "config.access",
            message: "Configuration value accessed: \(key)",
            correlationID: corrID,
            metadata: [
                "namespace": namespace,
                "type": String(describing: type)
            ]
        )
        
        return value ?? defaultValue
    }
    
    /// Get entire configuration namespace
    /// - Parameters:
    ///   - namespace: Configuration namespace
    ///   - correlationID: Request ID for tracing
    /// - Returns: Configuration data
    public func getConfiguration(
        namespace: String,
        correlationID: String? = nil
    ) async throws -> Configuration {
        let corrID = correlationID ?? CorrelationIDContext.current
        
        guard let config = configurations[namespace] else {
            throw CapsuleError.invalidInput(
                field: "namespace",
                constraint: "Configuration namespace not found: \(namespace)"
            )
        }
        
        diagnostics.event(
            level: .debug,
            category: "config.access",
            message: "Configuration namespace accessed: \(namespace)",
            correlationID: corrID,
            metadata: [:]
        )
        
        return config
    }
    
    /// Load configuration from file
    /// - Parameters:
    ///   - path: Path to configuration file
    ///   - namespace: Configuration namespace
    ///   - format: File format
    ///   - correlationID: Request ID for tracing
    /// - Throws: CapsuleError if loading fails
    public func loadConfiguration(
        from path: String,
        namespace: String,
        format: ConfigurationFormat = .auto,
        correlationID: String? = nil
    ) async throws {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "ConfigManager.loadConfiguration",
            category: "config.loading",
            correlationID: corrID,
            tags: [
                "namespace": namespace,
                "path": path
            ]
        )
        
        defer { span.end(status: .ok) }
        
        guard FileManager.default.fileExists(atPath: path) else {
            span.end(status: .error)
            throw CapsuleError.invalidInput(
                field: "path",
                constraint: "Configuration file does not exist: \(path)"
            )
        }
        
        do {
            // Detect format if auto
            let detectedFormat = format == .auto ? detectFormat(from: path) : format
            
            // Load file data
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            
            // Parse configuration
            let config = try parseConfiguration(data: data, format: detectedFormat, namespace: namespace)
            
            // Validate against schema if available
            if let schema = schemas[namespace] {
                try validateConfiguration(config, against: schema)
            }
            
            // Store configuration
            configurations[namespace] = config
            
            // Setup file monitoring for hot-reload
            if configuration.enableHotReload {
                await setupFileMonitor(for: namespace, at: path)
            }
            
            // Notify listeners
            await notifyConfigurationLoaded(namespace, config)
            
            diagnostics.event(
                level: .info,
                category: "config.loading",
                message: "Configuration loaded: \(namespace)",
                correlationID: corrID,
                metadata: [
                    "namespace": namespace,
                    "format": detectedFormat.rawValue,
                    "path": path
                ]
            )
            
        } catch {
            span.end(status: .error)
            throw CapsuleError.operationFailed(
                code: 4001,
                message: "Failed to load configuration: \(namespace)",
                context: [
                    "namespace": namespace,
                    "path": path,
                    "error": "\(error)"
                ]
            )
        }
    }
    
    /// Reload configuration
    /// - Parameters:
    ///   - namespace: Configuration namespace
    ///   - correlationID: Request ID for tracing
    /// - Throws: CapsuleError if reload fails
    public func reloadConfiguration(
        namespace: String,
        correlationID: String? = nil
    ) async throws {
        let corrID = correlationID ?? CorrelationIDContext.current
        
        guard let monitor = fileMonitors[namespace] else {
            throw CapsuleError.invalidInput(
                field: "namespace",
                constraint: "No file monitor configured for namespace: \(namespace)"
            )
        }
        
        try await loadConfiguration(
            from: monitor.path,
            namespace: namespace,
            correlationID: corrID
        )
        
        await notifyConfigurationReloaded(namespace)
    }
    
    /// Register configuration schema
    /// - Parameters:
    ///   - schema: Configuration schema
    ///   - namespace: Configuration namespace
    ///   - correlationID: Request ID for tracing
    /// - Throws: CapsuleError if registration fails
    public func registerSchema(
        _ schema: ConfigurationSchema,
        for namespace: String,
        correlationID: String? = nil
    ) async throws {
        let corrID = correlationID ?? CorrelationIDContext.current
        
        schemas[namespace] = schema
        
        // Validate existing configuration against new schema
        if let config = configurations[namespace] {
            try validateConfiguration(config, against: schema)
        }
        
        diagnostics.event(
            level: .info,
            category: "config.schema",
            message: "Schema registered for namespace: \(namespace)",
            correlationID: corrID,
            metadata: ["namespace": namespace]
        )
    }
    
    /// Validate configuration against schema
    /// - Parameters:
    ///   - namespace: Configuration namespace
    ///   - correlationID: Request ID for tracing
    /// - Returns: Validation result
    public func validateConfiguration(
        namespace: String,
        correlationID: String? = nil
    ) async throws -> ValidationResult {
        let corrID = correlationID ?? CorrelationIDContext.current
        
        guard let config = configurations[namespace] else {
            throw CapsuleError.invalidInput(
                field: "namespace",
                constraint: "Configuration namespace not found: \(namespace)"
            )
        }
        
        guard let schema = schemas[namespace] else {
            // No schema to validate against
            return ValidationResult(isValid: true)
        }
        
        return try validateConfiguration(config, against: schema)
    }
    
    /// Get all configuration namespaces
    /// - Returns: Array of namespace names
    public func getAllNamespaces() -> [String] {
        return Array(configurations.keys).sorted()
    }
    
    /// Get configuration health status
    /// - Returns: Health information
    public func getHealthStatus() -> ConfigHealth {
        let totalNamespaces = configurations.count
        let validNamespaces = configurations.values.filter { config in
            guard let schema = schemas[config.namespace] else { return true }
            do {
                _ = try validateConfiguration(config, against: schema)
                return true
            } catch {
                return false
            }
        }.count
        
        return ConfigHealth(
            status: validNamespaces == totalNamespaces ? .healthy : .degraded,
            totalNamespaces: totalNamespaces,
            validNamespaces: validNamespaces,
            hotReloadEnabled: configuration.enableHotReload,
            lastReload: fileMonitors.values.compactMap { $0.lastReload }.max()
        )
    }
    
    /// Add event listener
    /// - Parameter listener: Event listener
    public func addEventListener(_ listener: ConfigEventListener) {
        eventListeners.append(listener)
    }
    
    /// Remove event listener
    /// - Parameter listener: Event listener to remove
    public func removeEventListener(_ listener: ConfigEventListener) {
        eventListeners.removeAll { $0.id == listener.id }
    }
    
    /// Shutdown the config manager
    public func shutdown() async {
        // Stop all file monitors
        for monitor in fileMonitors.values {
            monitor.stop()
        }
        fileMonitors.removeAll()
        
        diagnostics.event(
            level: .info,
            category: "config.shutdown",
            message: "ConfigManager shutdown completed",
            correlationID: nil,
            metadata: [:]
        )
    }
    
    // MARK: - Private Methods
    
    private func loadDefaultConfigurations() async throws {
        // Load default configuration files
        let configDir = configuration.configDirectory
        
        for file in try FileManager.default.contentsOfDirectory(atPath: configDir) {
            let path = "\(configDir)/\(file)"
            let url = URL(fileURLWithPath: path)
            
            guard url.pathExtension != "schema" else { continue } // Skip schema files
            
            let namespace = url.deletingPathExtension().lastPathComponent
            let format = detectFormat(from: path)
            
            do {
                try await loadConfiguration(from: path, namespace: namespace, format: format)
            } catch {
                diagnostics.event(
                    level: .warning,
                    category: "config.loading",
                    message: "Failed to load default configuration: \(namespace)",
                    correlationID: nil,
                    metadata: [
                        "namespace": namespace,
                        "path": path,
                        "error": "\(error)"
                    ]
                )
            }
        }
    }
    
    private func loadConfigurationSchemas() async throws {
        let configDir = configuration.configDirectory
        
        for file in try FileManager.default.contentsOfDirectory(atPath: configDir) {
            let path = "\(configDir)/\(file)"
            let url = URL(fileURLWithPath: path)
            
            guard url.pathExtension == "schema" else { continue }
            
            let namespace = url.deletingPathExtension().lastPathComponent
            
            do {
                let data = try Data(contentsOf: url)
                let schema = try JSONDecoder().decode(ConfigurationSchema.self, from: data)
                schemas[namespace] = schema
                
                diagnostics.event(
                    level: .debug,
                    category: "config.schema",
                    message: "Schema loaded: \(namespace)",
                    correlationID: nil,
                    metadata: ["namespace": namespace]
                )
                
            } catch {
                diagnostics.event(
                    level: .warning,
                    category: "config.schema",
                    message: "Failed to load schema: \(namespace)",
                    correlationID: nil,
                    metadata: [
                        "namespace": namespace,
                        "path": path,
                        "error": "\(error)"
                    ]
                )
            }
        }
    }
    
    private func setupFileMonitoring() async {
        for (namespace, config) in configurations {
            if let path = config.sourcePath {
                await setupFileMonitor(for: namespace, at: path)
            }
        }
    }
    
    private func setupFileMonitor(for namespace: String, at path: String) async {
        let monitor = ConfigurationFileMonitor(
            path: path,
            handler: { [weak self] in
                Task { [weak self] in
                    try? await self?.reloadConfiguration(namespace: namespace)
                }
            }
        )
        
        fileMonitors[namespace] = monitor
        monitor.start()
    }
    
    private func detectFormat(from path: String) -> ConfigurationFormat {
        let url = URL(fileURLWithPath: path)
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "json": return .json
        case "yaml", "yml": return .yaml
        case "plist": return .plist
        default: return .json // Default to JSON
        }
    }
    
    private func parseConfiguration(
        data: Data,
        format: ConfigurationFormat,
        namespace: String
    ) throws -> Configuration {
        switch format {
        case .json:
            return try parseJSONConfiguration(data: data, namespace: namespace)
        case .yaml:
            return try parseYAMLConfiguration(data: data, namespace: namespace)
        case .plist:
            return try parsePlistConfiguration(data: data, namespace: namespace)
        case .auto:
            // Should never happen as format should be detected
            throw CapsuleError.invalidInput(
                field: "format",
                constraint: "Auto format not supported for parsing"
            )
        }
    }
    
    private func parseJSONConfiguration(data: Data, namespace: String) throws -> Configuration {
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        guard let dict = jsonObject as? [String: Any] else {
            throw CapsuleError.invalidInput(
                field: "data",
                constraint: "JSON configuration must be an object"
            )
        }
        
        return Configuration(
            namespace: namespace,
            data: dict,
            sourcePath: nil,
            format: .json,
            loadedAt: Date()
        )
    }
    
    private func parseYAMLConfiguration(data: Data, namespace: String) throws -> Configuration {
        // For now, throw error - would need YAML parser
        throw CapsuleError.operationFailed(
            code: 4002,
            message: "YAML parsing not yet implemented",
            context: ["namespace": namespace]
        )
    }
    
    private func parsePlistConfiguration(data: Data, namespace: String) throws -> Configuration {
        var format: PropertyListSerialization.PropertyListFormat = .xml
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: &format)
        guard let dict = plist as? [String: Any] else {
            throw CapsuleError.invalidInput(
                field: "data",
                constraint: "Plist configuration must be a dictionary"
            )
        }
        
        return Configuration(
            namespace: namespace,
            data: dict,
            sourcePath: nil,
            format: .plist,
            loadedAt: Date()
        )
    }
    
    private func validateConfiguration(_ config: Configuration, against schema: ConfigurationSchema) throws -> ValidationResult {
        var issues: [ValidationIssue] = []
        var warnings: [ValidationIssue] = []
        
        // Simple validation - in real implementation would use JSON Schema
        for (key, fieldSchema) in schema.properties {
            let value = config.data[key]
            
            // Check required fields
            if fieldSchema.required && value == nil {
                issues.append(ValidationIssue(
                    id: UUID().uuidString,
                    severity: .error,
                    message: "Required field missing: \(key)",
                    entryPath: key
                ))
            }
            
            // Type validation
            if let value = value, let expectedType = fieldSchema.type {
                if !validateType(value: value, expectedType: expectedType) {
                    issues.append(ValidationIssue(
                        id: UUID().uuidString,
                        severity: .error,
                        message: "Type mismatch for field: \(key). Expected: \(expectedType)",
                        entryPath: key
                    ))
                }
            }
        }
        
        return ValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            warnings: warnings
        )
    }
    
    private func validateType(value: Any, expectedType: String) -> Bool {
        switch expectedType {
        case "string":
            return value is String
        case "number", "integer":
            return value is NSNumber
        case "boolean":
            return value is Bool
        case "array":
            return value is [Any]
        case "object":
            return value is [String: Any]
        default:
            return true
        }
    }
    
    private func notifyConfigurationLoaded(_ namespace: String, _ config: Configuration) async {
        let event = ConfigEvent.configurationLoaded(namespace, config)
        for listener in eventListeners {
            await listener.handleEvent(event)
        }
    }
    
    private func notifyConfigurationReloaded(_ namespace: String) async {
        if let config = configurations[namespace] {
            let event = ConfigEvent.configurationReloaded(namespace, config)
            for listener in eventListeners {
                await listener.handleEvent(event)
            }
        }
    }
}