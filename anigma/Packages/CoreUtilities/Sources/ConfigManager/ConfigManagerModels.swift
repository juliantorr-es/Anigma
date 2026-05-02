import Foundation
import CapsuleCore
import TelemetryCore

// MARK: - Configuration Models

/// Configuration format types
public enum ConfigurationFormat: String, Codable, Sendable {
    case json = "json"
    case yaml = "yaml"
    case plist = "plist"
    case auto = "auto"
}

/// Configuration data container
public struct Configuration: Codable, Sendable {
    public let namespace: String
    public let data: [String: Any]
    public let sourcePath: String?
    public let format: ConfigurationFormat
    public let loadedAt: Date
    
    public init(
        namespace: String,
        data: [String: Any],
        sourcePath: String? = nil,
        format: ConfigurationFormat,
        loadedAt: Date = Date()
    ) {
        self.namespace = namespace
        self.data = data
        self.sourcePath = sourcePath
        self.format = format
        self.loadedAt = loadedAt
    }
    
    /// Get configuration value with dot notation support
    /// - Parameters:
    ///   - key: Configuration key (supports dot notation)
    ///   - type: Expected value type
    /// - Returns: Configuration value
    public func getValue<T>(key: String, type: T.Type) throws -> T? where T: Codable {
        let keys = key.split(separator: ".")
        var current: Any = data
        
        for keyComponent in keys {
            if let dict = current as? [String: Any] {
                current = dict[String(keyComponent)] ?? NSNull()
            } else {
                return nil
            }
        }
        
        if current is NSNull {
            return nil
        }
        
        // Convert to expected type
        if let result = current as? T {
            return result
        }
        
        // Try JSON conversion
        if let jsonData = try? JSONSerialization.data(withJSONObject: current) {
            return try? JSONDecoder().decode(T.self, from: jsonData)
        }
        
        return nil
    }
    
    /// Check if key exists
    /// - Parameter key: Configuration key
    /// - Returns: True if key exists
    public func hasKey(_ key: String) -> Bool {
        let keys = key.split(separator: ".")
        var current: Any = data
        
        for keyComponent in keys {
            if let dict = current as? [String: Any] {
                guard dict[String(keyComponent)] != nil else {
                    return false
                }
                current = dict[String(keyComponent)]!
            } else {
                return false
            }
        }
        
        return true
    }
}

// MARK: - Configuration Schema

/// Configuration schema for validation
public struct ConfigurationSchema: Codable, Sendable {
    public let schemaVersion: String
    public let namespace: String
    public let properties: [String: PropertySchema]
    public let required: [String]
    
    public init(
        schemaVersion: String = "1.0",
        namespace: String,
        properties: [String: PropertySchema],
        required: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.namespace = namespace
        self.properties = properties
        self.required = required
    }
}

/// Property schema definition
public struct PropertySchema: Codable, Sendable {
    public let type: String?
    public let required: Bool
    public let description: String?
    public let defaultValue: Any?
    public let enumValues: [Any]?
    public let minimum: Double?
    public let maximum: Double?
    public let minLength: Int?
    public let maxLength: Int?
    public let pattern: String?
    
    public init(
        type: String? = nil,
        required: Bool = false,
        description: String? = nil,
        defaultValue: Any? = nil,
        enumValues: [Any]? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        minLength: Int? = nil,
        maxLength: Int? = nil,
        pattern: String? = nil
    ) {
        self.type = type
        self.required = required
        self.description = description
        self.defaultValue = defaultValue
        self.enumValues = enumValues
        self.minimum = minimum
        self.maximum = maximum
        self.minLength = minLength
        self.maxLength = maxLength
        self.pattern = pattern
    }
}

// MARK: - Configuration Manager Configuration

/// Configuration for ConfigManager
public struct ConfigManagerConfiguration: Sendable {
    public let configDirectory: String
    public let enableHotReload: Bool
    public let reloadDelay: TimeInterval
    public let maxFileSize: Int
    public let allowedFormats: [ConfigurationFormat]
    
    public static let `default` = ConfigManagerConfiguration(
        configDirectory: "./Config",
        enableHotReload: true,
        reloadDelay: 1.0,
        maxFileSize: 10 * 1024 * 1024, // 10MB
        allowedFormats: [.json, .yaml, .plist]
    )
    
    public init(
        configDirectory: String = "./Config",
        enableHotReload: Bool = true,
        reloadDelay: TimeInterval = 1.0,
        maxFileSize: Int = 10 * 1024 * 1024,
        allowedFormats: [ConfigurationFormat] = [.json, .yaml, .plist]
    ) {
        self.configDirectory = configDirectory
        self.enableHotReload = enableHotReload
        self.reloadDelay = reloadDelay
        self.maxFileSize = maxFileSize
        self.allowedFormats = allowedFormats
    }
}

/// Configuration health status
public struct ConfigHealth: Codable, Sendable {
    public let status: HealthStatus
    public let totalNamespaces: Int
    public let validNamespaces: Int
    public let hotReloadEnabled: Bool
    public let lastReload: Date?
    
    public init(
        status: HealthStatus,
        totalNamespaces: Int,
        validNamespaces: Int,
        hotReloadEnabled: Bool,
        lastReload: Date?
    ) {
        self.status = status
        self.totalNamespaces = totalNamespaces
        self.validNamespaces = validNamespaces
        self.hotReloadEnabled = hotReloadEnabled
        self.lastReload = lastReload
    }
}

// MARK: - Environment Overrides

/// Environment variable overrides for configuration
public class EnvironmentOverrides: Sendable {
    private let prefix: String
    
    public init(prefix: String = "ANIGMA_") {
        self.prefix = prefix
    }
    
    /// Get value from environment with type conversion
    /// - Parameters:
    ///   - key: Configuration key
    ///   - namespace: Configuration namespace
    ///   - type: Expected value type
    /// - Returns: Environment value if found
    public func getValue<T>(key: String, namespace: String, type: T.Type) -> T? where T: Codable {
        let envKey = "\(prefix)\(namespace.uppercased())_\(key.uppercased().replacingOccurrences(of: ".", with: "_"))"
        
        guard let envValue = ProcessInfo.processInfo.environment[envKey] else {
            return nil
        }
        
        // Convert to expected type
        if type == String.self {
            return envValue as? T
        } else if type == Int.self {
            return Int(envValue) as? T
        } else if type == Double.self {
            return Double(envValue) as? T
        } else if type == Bool.self {
            return (envValue.lowercased() == "true" || envValue == "1") as? T
        }
        
        // Try JSON decoding for complex types
        if let data = envValue.data(using: .utf8) {
            return try? JSONDecoder().decode(T.self, from: data)
        }
        
        return nil
    }
    
    /// Check if environment override exists
    /// - Parameters:
    ///   - key: Configuration key
    ///   - namespace: Configuration namespace
    /// - Returns: True if override exists
    public func hasOverride(key: String, namespace: String) -> Bool {
        let envKey = "\(prefix)\(namespace.uppercased())_\(key.uppercased().replacingOccurrences(of: ".", with: "_"))"
        return ProcessInfo.processInfo.environment[envKey] != nil
    }
}

// MARK: - File Monitor

/// File monitor for configuration hot-reload
internal class ConfigurationFileMonitor {
    let path: String
    private let handler: () -> Void
    private var fileWatcher: DispatchSourceFileSystemObject?
    private var lastModified: Date?
    private var reloadTask: Task<Void, Never>?
    
    var lastReload: Date? {
        return lastModified
    }
    
    init(path: String, handler: @escaping () -> Void) {
        self.path = path
        self.handler = handler
    }
    
    func start() {
        let fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor != -1 else { return }
        
        fileWatcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write],
            queue: DispatchQueue(label: "config.monitor.\(path)")
        )
        
        fileWatcher?.setEventHandler { [weak self] in
            self?.handleFileChange()
        }
        
        fileWatcher?.setCancelHandler {
            close(fileDescriptor)
        }
        
        fileWatcher?.resume()
    }
    
    func stop() {
        fileWatcher?.cancel()
        fileWatcher = nil
        reloadTask?.cancel()
        reloadTask = nil
    }
    
    private func handleFileChange() {
        // Debounce file changes
        reloadTask?.cancel()
        reloadTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second debounce
            await MainActor.run {
                self.lastModified = Date()
                self.handler()
            }
        }
    }
}

// MARK: - Configuration Extensions

extension Configuration: CustomStringConvertible {
    public var description: String {
        return "Configuration(namespace: \(namespace), keys: \(data.keys.count), format: \(format.rawValue))"
    }
}

extension ConfigurationSchema: CustomStringConvertible {
    public var description: String {
        return "ConfigurationSchema(namespace: \(namespace), properties: \(properties.count), required: \(required.count))"
    }
}

// MARK: - Utility Functions

/// Create a simple configuration schema
public func schema(
    for namespace: String,
    properties: [String: PropertySchema],
    required: [String] = []
) -> ConfigurationSchema {
    return ConfigurationSchema(
        namespace: namespace,
        properties: properties,
        required: required
    )
}

/// Create a property schema
public func property(
    type: String? = nil,
    required: Bool = false,
    description: String? = nil,
    defaultValue: Any? = nil
) -> PropertySchema {
    return PropertySchema(
        type: type,
        required: required,
        description: description,
        defaultValue: defaultValue
    )
}

/// Create a string property schema
public func stringProperty(
    required: Bool = false,
    minLength: Int? = nil,
    maxLength: Int? = nil,
    pattern: String? = nil,
    description: String? = nil
) -> PropertySchema {
    return PropertySchema(
        type: "string",
        required: required,
        description: description,
        minLength: minLength,
        maxLength: maxLength,
        pattern: pattern
    )
}

/// Create a number property schema
public func numberProperty(
    required: Bool = false,
    minimum: Double? = nil,
    maximum: Double? = nil,
    description: String? = nil
) -> PropertySchema {
    return PropertySchema(
        type: "number",
        required: required,
        description: description,
        minimum: minimum,
        maximum: maximum
    )
}

/// Create a boolean property schema
public func booleanProperty(
    required: Bool = false,
    description: String? = nil
) -> PropertySchema {
    return PropertySchema(
        type: "boolean",
        required: required,
        description: description
    )
}

/// Create an array property schema
public func arrayProperty(
    required: Bool = false,
    itemsType: String? = nil,
    description: String? = nil
) -> PropertySchema {
    return PropertySchema(
        type: "array",
        required: required,
        description: description
    )
}

/// Create an object property schema
public func objectProperty(
    required: Bool = false,
    description: String? = nil
) -> PropertySchema {
    return PropertySchema(
        type: "object",
        required: required,
        description: description
    )
}