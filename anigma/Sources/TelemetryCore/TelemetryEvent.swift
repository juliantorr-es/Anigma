//
//  TelemetryEvent.swift
//  TelemetryCore
//
//  Core telemetry event structure with privacy-first design.
//  No arbitrary user strings - only controlled value types.
//

import Foundation

/// A telemetry event with privacy-enforced payload structure.
public struct TelemetryEvent: Sendable, Identifiable {
    public let id: String
    public let category: TelemetryCategory
    public let name: String
    public let timestamp: Date
    public let privacyClassification: PrivacyClassification
    public let values: [String: TelemetryValue]

    public init(
        id: String = UUID().uuidString,
        category: TelemetryCategory,
        name: String,
        timestamp: Date = Date(),
        privacyClassification: PrivacyClassification = .restricted,
        values: [String: TelemetryValue] = [:]
    ) {
        self.id = id
        self.category = category
        self.name = name
        self.timestamp = timestamp
        self.privacyClassification = privacyClassification
        self.values = values
    }
}

/// Categories of telemetry events with controlled vocabulary.
public enum TelemetryCategory: String, Sendable, CaseIterable {
    case system = "system"
    case performance = "performance"
    case security = "security"
    case error = "error"
    case workflow = "workflow"
    case tool = "tool"
    case memory = "memory"
    case audit = "audit"
}

/// Privacy classification levels - default to most restrictive.
public enum PrivacyClassification: String, Sendable, CaseIterable {
    case `public` = "public"
    case `internal` = "internal"
    case `restricted` = "restricted"

    public var samplingRate: Double {
        switch self {
        case .public: return 1.0
        case .internal: return 0.1
        case .restricted: return 0.01
        }
    }
}

// MARK: - Codable Wire Support
extension TelemetryEvent: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.category = try container.decode(TelemetryCategory.self, forKey: .category)
        self.name = try container.decode(String.self, forKey: .name)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.privacyClassification = try container.decode(PrivacyClassification.self, forKey: .privacyClassification)
        self.values = try container.decode([String: TelemetryValue].self, forKey: .values)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(category, forKey: .category)
        try container.encode(name, forKey: .name)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(privacyClassification, forKey: .privacyClassification)
        try container.encode(values, forKey: .values)
    }

    private enum CodingKeys: String, CodingKey {
        case id, category, name, timestamp, privacyClassification, values
    }
}

extension TelemetryCategory: Codable {}
extension PrivacyClassification: Codable {}
