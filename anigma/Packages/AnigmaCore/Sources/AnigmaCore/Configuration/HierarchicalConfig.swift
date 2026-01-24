//
//  HierarchicalConfig.swift
//  AnigmaCore
//
//  Hierarchical configuration management with hot-reload support.
//  Inspired by Gemini CLI and CLIProxyAPI.
//

import Foundation

public protocol ConfigProvider: Sendable {
    func load() async throws -> [String: AnyCodable]
}

public actor ConfigManager {
    private var providers: [any ConfigProvider] = []
    private var mergedConfig: [String: AnyCodable] = [:]
    private var watcher: ConfigWatcher?

    public init() {}

    /// Deep merge dictionaries where later values override earlier ones.
    private func deepMerge(_ base: [String: AnyCodable], with new: [String: AnyCodable]) -> [String: AnyCodable] {
        var merged = base
        for (key, newValue) in new {
            if let baseValue = merged[key]?.value as? [String: AnyCodable],
               let nextValue = newValue.value as? [String: AnyCodable] {
                merged[key] = AnyCodable(deepMerge(baseValue, with: nextValue))
            } else {
                merged[key] = newValue
            }
        }
        return merged
    }

    public func reload() async throws {
        var newConfig: [String: AnyCodable] = [:]
        for provider in providers {
            let loaded = try await provider.load()
            newConfig = deepMerge(newConfig, with: loaded)
        }
        self.mergedConfig = newConfig
        NotificationCenter.default.post(name: .AnigmaConfigDidChange, object: nil)
    }

    public func get<T: Decodable>(_ key: String, as type: T.Type) -> T? {
        guard let anyCodable = mergedConfig[key] else { return nil }
        // Use JSONEncoder/Decoder for type-safe extraction from AnyCodable
        guard let data = try? JSONEncoder().encode(anyCodable) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    // ...
}

/// Provider that loads configuration from a YAML or JSON file.
public struct FileConfigProvider: ConfigProvider {
    let url: URL

    public init(url: URL) { self.url = url }

    public func load() async throws -> [String: AnyCodable] {
        let data = try Data(contentsOf: url)
        // In a real implementation, use a YAML/JSON decoder
        return try JSONDecoder().decode([String: AnyCodable].self, from: data)
    }
}

/// Provider that loads configuration from environment variables.
public struct EnvConfigProvider: ConfigProvider {
    let prefix: String

    public init(prefix: String = "ANIGMA_") { self.prefix = prefix }

    public func load() async throws -> [String: AnyCodable] {
        var config: [String: AnyCodable] = [:]
        for (key, value) in ProcessInfo.processInfo.environment {
            if key.hasPrefix(prefix) {
                let cleanKey = key.dropFirst(prefix.count).lowercased()
                config[String(cleanKey)] = AnyCodable(value)
            }
        }
        return config
    }
}

extension Notification.Name {
    public static let AnigmaConfigDidChange = Notification.Name("AnigmaConfigDidChange")
}

/// Generic wrapper for values in the config.
public struct AnyCodable: Codable, Sendable {
    public let value: Sendable

    public init(_ value: Sendable) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable: Unsupported type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let bool = value as? Bool {
            try container.encode(bool)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else if let array = value as? [Sendable] {
            try container.encode(array.map { AnyCodable($0) })
        } else if let dictionary = value as? [String: Sendable] {
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        }
    }
}
