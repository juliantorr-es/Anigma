//
//  Configuration.swift
//  AnigmaCore
//
//  Configuration reading utilities for per-module settings.
//  Provides a simple key-value configuration system.
//

import Foundation

// MARK: - Configuration Source Protocol

/// Protocol for configuration sources (files, environment, etc.).
public protocol ConfigurationSource: Sendable {
    /// Gets a configuration value by key.
    func get(_ key: String) -> String?

    /// Gets all keys available in this source.
    func allKeys() -> [String]
}

// MARK: - Environment Configuration Source

/// Reads configuration from environment variables.
public struct EnvironmentConfigSource: ConfigurationSource {
    public let prefix: String

    public init(prefix: String = "ANIGMA_") {
        self.prefix = prefix
    }

    public func get(_ key: String) -> String? {
        let envKey = prefix + key.uppercased().replacingOccurrences(of: ".", with: "_")
        return ProcessInfo.processInfo.environment[envKey]
    }

    public func allKeys() -> [String] {
        ProcessInfo.processInfo.environment.keys
            .filter { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)).lowercased().replacingOccurrences(of: "_", with: ".") }
    }
}

// MARK: - Dictionary Configuration Source

/// In-memory configuration source.
public struct DictionaryConfigSource: ConfigurationSource {
    public let values: [String: String]

    public init(_ values: [String: String]) {
        self.values = values
    }

    public func get(_ key: String) -> String? {
        values[key]
    }

    public func allKeys() -> [String] {
        Array(values.keys)
    }
}

// MARK: - Configuration

/// Central configuration manager.
/// Reads from multiple sources with priority ordering.
public actor Configuration {
    public static let shared = Configuration()

    private var sources: [any ConfigurationSource] = [EnvironmentConfigSource()]
    private var cache: [String: String] = [:]
    private var defaults: [String: String] = [:]

    private init() {}

    /// Sets the configuration sources (in priority order, first wins).
    public func setSources(_ sources: [any ConfigurationSource]) {
        self.sources = sources
        self.cache = [:]  // Clear cache
    }

    /// Adds a configuration source with highest priority.
    public func addSource(_ source: any ConfigurationSource, priority: Bool = true) {
        if priority {
            sources.insert(source, at: 0)
        } else {
            sources.append(source)
        }
        cache = [:]  // Clear cache
    }

    /// Sets default values (used when no source provides a value).
    public func setDefaults(_ defaults: [String: String]) {
        self.defaults = defaults
    }

    /// Gets a configuration value.
    public func get(_ key: String) -> String? {
        // Check cache
        if let cached = cache[key] {
            return cached
        }

        // Search sources
        for source in sources {
            if let value = source.get(key) {
                cache[key] = value
                return value
            }
        }

        // Fall back to defaults
        return defaults[key]
    }

    /// Gets a configuration value or a default.
    public func get(_ key: String, default defaultValue: String) -> String {
        get(key) ?? defaultValue
    }

    /// Gets a configuration value as Int.
    public func getInt(_ key: String) -> Int? {
        get(key).flatMap { Int($0) }
    }

    /// Gets a configuration value as Int with default.
    public func getInt(_ key: String, default defaultValue: Int) -> Int {
        getInt(key) ?? defaultValue
    }

    /// Gets a configuration value as Double.
    public func getDouble(_ key: String) -> Double? {
        get(key).flatMap { Double($0) }
    }

    /// Gets a configuration value as Bool.
    public func getBool(_ key: String) -> Bool? {
        guard let value = get(key)?.lowercased() else { return nil }
        switch value {
        case "true", "yes", "1", "on": return true
        case "false", "no", "0", "off": return false
        default: return nil
        }
    }

    /// Gets a configuration value as Bool with default.
    public func getBool(_ key: String, default defaultValue: Bool) -> Bool {
        getBool(key) ?? defaultValue
    }

    /// Gets all configuration keys.
    public func allKeys() -> [String] {
        var keys = Set<String>()
        for source in sources {
            for key in source.allKeys() {
                keys.insert(key)
            }
        }
        for key in defaults.keys {
            keys.insert(key)
        }
        return Array(keys).sorted()
    }

    /// Clears the configuration cache.
    public func clearCache() {
        cache = [:]
    }
}

// MARK: - Configuration Keys

/// Common configuration keys for AnigmaCore.
public enum ConfigKey {
    public static let logLevel = "log.level"
    public static let logIncludeEmoji = "log.emoji"
    public static let schedulerMaxQueueSize = "scheduler.maxQueueSize"
    public static let schedulerCleanupAgeDays = "scheduler.cleanupAgeDays"
}
