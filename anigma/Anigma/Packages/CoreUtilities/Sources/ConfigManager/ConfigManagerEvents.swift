import Foundation

// MARK: - Configuration Events

/// Events emitted by ConfigManager
public enum ConfigEvent: Sendable {
    case configurationLoaded(String, Configuration)
    case configurationReloaded(String, Configuration)
    case configurationValidated(String, ValidationResult)
    case configurationValidationFailed(String, ValidationResult)
    case schemaRegistered(String, ConfigurationSchema)
    case fileWatchStarted(String, String)
    case fileWatchStopped(String)
    case configurationError(String, CapsuleError)
}

/// Configuration event listener
public actor ConfigEventListener: Identifiable, Sendable {
    public let id: String
    private let handler: (ConfigEvent) async -> Void
    
    public init(id: String = UUID().uuidString, handler: @escaping (ConfigEvent) async -> Void) {
        self.id = id
        self.handler = handler
    }
    
    func handleEvent(_ event: ConfigEvent) async {
        await handler(event)
    }
}

// MARK: - Configuration Builder

/// Builder for creating configuration objects
public class ConfigurationBuilder {
    private var namespace: String = "default"
    private var data: [String: Any] = [:]
    private var sourcePath: String?
    private var format: ConfigurationFormat = .json
    
    public init() {}
    
    public func namespace(_ namespace: String) -> ConfigurationBuilder {
        self.namespace = namespace
        return self
    }
    
    public func sourcePath(_ sourcePath: String) -> ConfigurationBuilder {
        self.sourcePath = sourcePath
        return self
    }
    
    public func format(_ format: ConfigurationFormat) -> ConfigurationBuilder {
        self.format = format
        return self
    }
    
    public func set(key: String, value: Any) -> ConfigurationBuilder {
        data[key] = value
        return self
    }
    
    public func set(key: String, value: String?) -> ConfigurationBuilder {
        data[key] = value
        return self
    }
    
    public func set(key: String, value: Int?) -> ConfigurationBuilder {
        data[key] = value
        return self
    }
    
    public func set(key: String, value: Double?) -> ConfigurationBuilder {
        data[key] = value
        return self
    }
    
    public func set(key: String, value: Bool?) -> ConfigurationBuilder {
        data[key] = value
        return self
    }
    
    public func set<T: Codable>(key: String, value: T?) throws -> ConfigurationBuilder {
        if let value = value {
            let data = try JSONEncoder().encode(value)
            let json = try JSONSerialization.jsonObject(with: data)
            self.data[key] = json
        } else {
            self.data[key] = nil
        }
        return self
    }
    
    public func addAll(_ dictionary: [String: Any]) -> ConfigurationBuilder {
        for (key, value) in dictionary {
            data[key] = value
        }
        return self
    }
    
    public func build() -> Configuration {
        return Configuration(
            namespace: namespace,
            data: data,
            sourcePath: sourcePath,
            format: format
        )
    }
}

// MARK: - Configuration Template

/// Template for creating common configuration patterns
public struct ConfigurationTemplate: Sendable {
    public let name: String
    public let configuration: Configuration
    public let schema: ConfigurationSchema?
    
    public init(
        name: String,
        configuration: Configuration,
        schema: ConfigurationSchema? = nil
    ) {
        self.name = name
        self.configuration = configuration
        self.schema = schema
    }
    
    /// Create an instance of this template with overrides
    /// - Parameter overrides: Dictionary of key-value overrides
    /// - Returns: New configuration instance
    public func create(overrides: [String: Any] = [:]) -> Configuration {
        var newData = configuration.data
        
        for (key, value) in overrides {
            newData[key] = value
        }
        
        return Configuration(
            namespace: configuration.namespace,
            data: newData,
            sourcePath: configuration.sourcePath,
            format: configuration.format,
            loadedAt: Date()
        )
    }
}

/// Common configuration templates
public struct CommonConfigurationTemplates {
    
    /// Database connection configuration
    public static let database = ConfigurationTemplate(
        name: "database",
        configuration: ConfigurationBuilder()
            .namespace("database")
            .set(key: "host", value: "localhost")
            .set(key: "port", value: 5432)
            .set(key: "database", value: "anigma")
            .set(key: "username", value: "admin")
            .set(key: "password", value: "")
            .set(key: "ssl_enabled", value: true)
            .set(key: "connection_pool_size", value: 10)
            .set(key: "timeout", value: 30.0)
            .build(),
        schema: schema(for: "database", properties: [
            "host": stringProperty(required: true, description: "Database host"),
            "port": numberProperty(required: true, minimum: 1, maximum: 65535, description: "Database port"),
            "database": stringProperty(required: true, description: "Database name"),
            "username": stringProperty(required: true, description: "Database username"),
            "password": stringProperty(required: true, description: "Database password"),
            "ssl_enabled": booleanProperty(description: "Enable SSL connection"),
            "connection_pool_size": numberProperty(minimum: 1, maximum: 100, description: "Connection pool size"),
            "timeout": numberProperty(minimum: 1, maximum: 300, description: "Connection timeout in seconds")
        ], required: ["host", "port", "database", "username", "password"])
    )
    
    /// HTTP server configuration
    public static let httpServer = ConfigurationTemplate(
        name: "http_server",
        configuration: ConfigurationBuilder()
            .namespace("http_server")
            .set(key: "host", value: "0.0.0.0")
            .set(key: "port", value: 8080)
            .set(key: "cors_enabled", value: true)
            .set(key: "max_connections", value: 1000)
            .set(key: "request_timeout", value: 30.0)
            .set(key: "keep_alive", value: true)
            .set(key: "compression_enabled", value: true)
            .build(),
        schema: schema(for: "http_server", properties: [
            "host": stringProperty(description: "Server bind address"),
            "port": numberProperty(minimum: 1, maximum: 65535, description: "Server port"),
            "cors_enabled": booleanProperty(description: "Enable CORS"),
            "max_connections": numberProperty(minimum: 1, description: "Maximum concurrent connections"),
            "request_timeout": numberProperty(minimum: 1, maximum: 300, description: "Request timeout in seconds"),
            "keep_alive": booleanProperty(description: "Enable keep-alive connections"),
            "compression_enabled": booleanProperty(description: "Enable response compression")
        ])
    )
    
    /// Logging configuration
    public static let logging = ConfigurationTemplate(
        name: "logging",
        configuration: ConfigurationBuilder()
            .namespace("logging")
            .set(key: "level", value: "info")
            .set(key: "format", value: "json")
            .set(key: "output", value: "console")
            .set(key: "file_path", value: "/var/log/anigma.log")
            .set(key: "max_file_size", value: 100 * 1024 * 1024) // 100MB
            .set(key: "max_files", value: 10)
            .set(key: "enable_rotation", value: true)
            .build(),
        schema: schema(for: "logging", properties: [
            "level": stringProperty(enumValues: ["debug", "info", "warning", "error", "critical"], description: "Log level"),
            "format": stringProperty(enumValues: ["json", "text"], description: "Log format"),
            "output": stringProperty(enumValues: ["console", "file", "syslog"], description: "Log output destination"),
            "file_path": stringProperty(description: "Log file path"),
            "max_file_size": numberProperty(minimum: 1024, description: "Maximum log file size in bytes"),
            "max_files": numberProperty(minimum: 1, maximum: 1000, description: "Maximum number of log files to retain"),
            "enable_rotation": booleanProperty(description: "Enable log file rotation")
        ], required: ["level", "format", "output"])
    )
}

// MARK: - Configuration Migrator

/// Configuration migration tool
public class ConfigurationMigrator {
    private let fromVersion: String
    private let toVersion: String
    private let migrations: [String: MigrationStep]
    
    public init(fromVersion: String, toVersion: String, migrations: [String: MigrationStep]) {
        self.fromVersion = fromVersion
        self.toVersion = toVersion
        self.migrations = migrations
    }
    
    /// Migrate configuration from one version to another
    /// - Parameter configuration: Source configuration
    /// - Returns: Migrated configuration
    /// - Throws: CapsuleError if migration fails
    public func migrate(_ configuration: Configuration) throws -> Configuration {
        guard let currentVersion = configuration.data["version"] as? String else {
            throw CapsuleError.invalidInput(
                field: "version",
                constraint: "Configuration version not found"
            )
        }
        
        guard currentVersion == fromVersion else {
            throw CapsuleError.invalidInput(
                field: "version",
                constraint: "Cannot migrate from version \(currentVersion) to \(toVersion)"
            )
        }
        
        var newData = configuration.data
        newData["version"] = toVersion
        
        // Apply migration steps
        for (key, step) in migrations {
            let oldValue = newData[key]
            let newValue = try step.migrate(oldValue)
            newData[key] = newValue
        }
        
        return Configuration(
            namespace: configuration.namespace,
            data: newData,
            sourcePath: configuration.sourcePath,
            format: configuration.format,
            loadedAt: Date()
        )
    }
}

/// Migration step for configuration transformation
public protocol MigrationStep: Sendable {
    /// Migrate a value from old to new format
    /// - Parameter value: Old value (may be nil)
    /// - Returns: New value
    /// - Throws: CapsuleError if migration fails
    func migrate(_ value: Any?) throws -> Any?
}

/// Simple rename migration step
public struct RenameMigrationStep: MigrationStep {
    public let newName: String
    
    public init(newName: String) {
        self.newName = newName
    }
    
    public func migrate(_ value: Any?) throws -> Any? {
        return value
    }
}

/// Type conversion migration step
public struct TypeConversionMigrationStep: MigrationStep {
    public let targetType: String
    
    public init(targetType: String) {
        self.targetType = targetType
    }
    
    public func migrate(_ value: Any?) throws -> Any? {
        guard let value = value else { return nil }
        
        switch targetType {
        case "string":
            return "\(value)"
        case "number":
            if let stringValue = value as? String {
                return Double(stringValue)
            }
            return value
        case "boolean":
            if let stringValue = value as? String {
                return stringValue.lowercased() == "true" || stringValue == "1"
            }
            return value
        default:
            return value
        }
    }
}

/// Value transformation migration step
public struct ValueTransformMigrationStep: MigrationStep {
    private let transform: (Any?) throws -> Any?
    
    public init(_ transform: @escaping (Any?) throws -> Any?) {
        self.transform = transform
    }
    
    public func migrate(_ value: Any?) throws -> Any? {
        return try transform(value)
    }
}