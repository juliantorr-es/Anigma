import Foundation

/// A pure data object representing a render operation with stable, deterministic ID.
/// RenderIntents are immutable and can be safely cached and reused.
public struct RenderIntent: Sendable {
    /// Unique identifier for this intent, derived from its canonical encoding.
    public let id: IntentID
    
    /// Type of render operation.
    public let type: RenderIntentType
    
    /// Parameters for the render operation.
    public let parameters: [String: ParameterValue]
    
    /// Dependencies on other intents (by ID).
    public let dependencies: [IntentID]
    
    /// Metadata for debugging and telemetry.
    public let metadata: [String: String]
    
    /// Version of the intent format (for forward/backward compatibility).
    public let version: UInt8
    
    /// Create a new RenderIntent.
    /// - Parameters:
    ///   - type: Type of render operation
    ///   - parameters: Parameters for the operation
    ///   - dependencies: Dependencies on other intents
    ///   - metadata: Debugging and telemetry metadata
    ///   - version: Format version (defaults to 1)
    public init(
        type: RenderIntentType,
        parameters: [String: ParameterValue] = [:],
        dependencies: [IntentID] = [],
        metadata: [String: String] = [:],
        version: UInt8 = 1
    ) {
        self.type = type
        self.parameters = parameters
        self.dependencies = dependencies
        self.metadata = metadata
        self.version = version
        
        // Generate stable ID from canonical encoding
        self.id = StableHasher.hash { hasher in
            hasher.update(with: version)
            hasher.update(with: type.rawValue)
            
            // Parameters in sorted order for determinism
            let sortedKeys = parameters.keys.sorted()
            hasher.update(with: UInt64(sortedKeys.count))
            for key in sortedKeys {
                hasher.update(with: key)
                if let value = parameters[key] {
                    value.updateHasher(&hasher)
                }
            }
            
            // Dependencies
            hasher.update(with: dependencies) { hasher, dependency in
                hasher.update(with: dependency)
            }
            
            // Metadata in sorted order
            let sortedMetadataKeys = metadata.keys.sorted()
            hasher.update(with: UInt64(sortedMetadataKeys.count))
            for key in sortedMetadataKeys {
                hasher.update(with: key)
                if let value = metadata[key] {
                    hasher.update(with: value)
                }
            }
        }
    }
    
    /// Check if this intent depends on another intent.
    public func depends(on otherID: IntentID) -> Bool {
        dependencies.contains(otherID)
    }
    
    /// Get a parameter value, throwing if not found or type mismatch.
    public func getParameter<T>(_ key: String, as type: T.Type) throws -> T {
        guard let param = parameters[key] else {
            throw RenderIntentError.parameterNotFound(key)
        }
        
        guard let value = param.value as? T else {
            throw RenderIntentError.typeMismatch(key, String(describing: T.self))
        }
        
        return value
    }
    
    /// Get a parameter value with a default if not found.
    public func getParameter<T>(_ key: String, default defaultValue: T) -> T {
        (try? getParameter(key, as: T.self)) ?? defaultValue
    }
    
    /// Create a modified copy with updated parameters.
    public func withParameters(_ newParameters: [String: ParameterValue]) -> RenderIntent {
        RenderIntent(
            type: type,
            parameters: newParameters,
            dependencies: dependencies,
            metadata: metadata,
            version: version
        )
    }
    
    /// Create a modified copy with additional metadata.
    public func withMetadata(_ newMetadata: [String: String]) -> RenderIntent {
        var merged = metadata
        for (key, value) in newMetadata {
            merged[key] = value
        }
        
        return RenderIntent(
            type: type,
            parameters: parameters,
            dependencies: dependencies,
            metadata: merged,
            version: version
        )
    }
}

// MARK: - RenderIntentType

/// Types of render operations.
public enum RenderIntentType: String, Sendable, Codable {
    /// Clear the render target with a color.
    case clear
    
    /// Draw text at a position.
    case drawText
    
    /// Draw a rectangle.
    case drawRect
    
    /// Draw an image.
    case drawImage
    
    /// Apply a blur effect.
    case blur
    
    /// Apply a color matrix transformation.
    case colorMatrix
    
    /// Composite multiple layers.
    case composite
    
    /// Custom operation defined by shader.
    case custom
}

// MARK: - ParameterValue

/// Type-erased parameter value for render intents.
public enum ParameterValue: Sendable {
    case string(String)
    case int(Int64)
    case uint(UInt64)
    case float(Double)
    case bool(Bool)
    case data(Data)
    case intentID(IntentID)
    case array([ParameterValue])
    case dictionary([String: ParameterValue])
    
    /// The underlying value (type-erased).
    public var value: Any {
        switch self {
        case .string(let value): return value
        case .int(let value): return value
        case .uint(let value): return value
        case .float(let value): return value
        case .bool(let value): return value
        case .data(let value): return value
        case .intentID(let value): return value
        case .array(let value): return value
        case .dictionary(let value): return value
        }
    }
}

extension ParameterValue: StableHashable {
    public func updateHasher(_ hasher: inout StableHasher) {
        switch self {
        case .string(let value):
            hasher.update(with: 0 as UInt8)
            hasher.update(with: value)
        case .int(let value):
            hasher.update(with: 1 as UInt8)
            hasher.update(with: value)
        case .uint(let value):
            hasher.update(with: 2 as UInt8)
            hasher.update(with: value)
        case .float(let value):
            hasher.update(with: 3 as UInt8)
            hasher.update(with: value)
        case .bool(let value):
            hasher.update(with: 4 as UInt8)
            hasher.update(with: value)
        case .data(let value):
            hasher.update(with: 5 as UInt8)
            hasher.update(with: UInt64(value.count))
            hasher.update(with: value)
        case .intentID(let value):
            hasher.update(with: 6 as UInt8)
            hasher.update(with: value)
        case .array(let values):
            hasher.update(with: 7 as UInt8)
            hasher.update(with: values) { hasher, element in
                element.updateHasher(&hasher)
            }
        case .dictionary(let dict):
            hasher.update(with: 8 as UInt8)
            let sortedKeys = dict.keys.sorted()
            hasher.update(with: UInt64(sortedKeys.count))
            for key in sortedKeys {
                hasher.update(with: key)
                if let value = dict[key] {
                    value.updateHasher(&hasher)
                }
            }
        }
    }
}

extension ParameterValue: Equatable {
    public static func == (lhs: ParameterValue, rhs: ParameterValue) -> Bool {
        switch (lhs, rhs) {
        case (.string(let l), .string(let r)): return l == r
        case (.int(let l), .int(let r)): return l == r
        case (.uint(let l), .uint(let r)): return l == r
        case (.float(let l), .float(let r)): return l == r
        case (.bool(let l), .bool(let r)): return l == r
        case (.data(let l), .data(let r)): return l == r
        case (.intentID(let l), .intentID(let r)): return l == r
        case (.array(let l), .array(let r)): return l == r
        case (.dictionary(let l), .dictionary(let r)): return l == r
        default: return false
        }
    }
}

extension ParameterValue: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .string(let value): hasher.combine(0); hasher.combine(value)
        case .int(let value): hasher.combine(1); hasher.combine(value)
        case .uint(let value): hasher.combine(2); hasher.combine(value)
        case .float(let value): hasher.combine(3); hasher.combine(value)
        case .bool(let value): hasher.combine(4); hasher.combine(value)
        case .data(let value): hasher.combine(5); hasher.combine(value)
        case .intentID(let value): hasher.combine(6); hasher.combine(value)
        case .array(let values): hasher.combine(7); hasher.combine(values)
        case .dictionary(let dict): hasher.combine(8); hasher.combine(dict)
        }
    }
}

// MARK: - Errors

public enum RenderIntentError: Error {
    case parameterNotFound(String)
    case typeMismatch(String, String)
    case invalidParameter(String)
    case dependencyCycle([IntentID])
}

// MARK: - Convenience Initializers

extension RenderIntent {
    /// Create a clear intent.
    public static func clear(
        color: SIMD4<Float>,
        target: String = "default",
        metadata: [String: String] = [:]
    ) -> RenderIntent {
        RenderIntent(
            type: .clear,
            parameters: [
                "color": .float(Double(color.x)),
                "r": .float(Double(color.x)),
                "g": .float(Double(color.y)),
                "b": .float(Double(color.z)),
                "a": .float(Double(color.w)),
                "target": .string(target)
            ],
            metadata: metadata
        )
    }
    
    /// Create a text drawing intent.
    public static func drawText(
        text: String,
        position: SIMD2<Float>,
        font: String = "system",
        size: Float = 16,
        color: SIMD4<Float> = SIMD4(0, 0, 0, 1),
        metadata: [String: String] = [:]
    ) -> RenderIntent {
        RenderIntent(
            type: .drawText,
            parameters: [
                "text": .string(text),
                "x": .float(Double(position.x)),
                "y": .float(Double(position.y)),
                "font": .string(font),
                "size": .float(Double(size)),
                "color_r": .float(Double(color.x)),
                "color_g": .float(Double(color.y)),
                "color_b": .float(Double(color.z)),
                "color_a": .float(Double(color.w))
            ],
            metadata: metadata
        )
    }
}

// MARK: - Codable Support

extension RenderIntent: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, type, parameters, dependencies, metadata, version
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let decodedID = try container.decode(IntentID.self, forKey: .id)
        let type = try container.decode(RenderIntentType.self, forKey: .type)
        let parameters = try container.decode([String: ParameterValue].self, forKey: .parameters)
        let dependencies = try container.decode([IntentID].self, forKey: .dependencies)
        let metadata = try container.decode([String: String].self, forKey: .metadata)
        let version = try container.decode(UInt8.self, forKey: .version)
        
        // Reconstruct to verify ID matches
        let reconstructed = RenderIntent(
            type: type,
            parameters: parameters,
            dependencies: dependencies,
            metadata: metadata,
            version: version
        )
        
        // Verify the ID matches what was encoded
        guard reconstructed.id == decodedID else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Intent ID mismatch: encoded \(decodedID), computed \(reconstructed.id)")
            )
        }
        
        self = reconstructed
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(parameters, forKey: .parameters)
        try container.encode(dependencies, forKey: .dependencies)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(version, forKey: .version)
    }
}

extension ParameterValue: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, value
    }
    
    private enum ValueType: String, Codable {
        case string, int, uint, float, bool, data, intentID, array, dictionary
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ValueType.self, forKey: .type)
        
        switch type {
        case .string:
            let value = try container.decode(String.self, forKey: .value)
            self = .string(value)
        case .int:
            let value = try container.decode(Int64.self, forKey: .value)
            self = .int(value)
        case .uint:
            let value = try container.decode(UInt64.self, forKey: .value)
            self = .uint(value)
        case .float:
            let value = try container.decode(Double.self, forKey: .value)
            self = .float(value)
        case .bool:
            let value = try container.decode(Bool.self, forKey: .value)
            self = .bool(value)
        case .data:
            let value = try container.decode(Data.self, forKey: .value)
            self = .data(value)
        case .intentID:
            let value = try container.decode(IntentID.self, forKey: .value)
            self = .intentID(value)
        case .array:
            let value = try container.decode([ParameterValue].self, forKey: .value)
            self = .array(value)
        case .dictionary:
            let value = try container.decode([String: ParameterValue].self, forKey: .value)
            self = .dictionary(value)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .string(let value):
            try container.encode(ValueType.string, forKey: .type)
            try container.encode(value, forKey: .value)
        case .int(let value):
            try container.encode(ValueType.int, forKey: .type)
            try container.encode(value, forKey: .value)
        case .uint(let value):
            try container.encode(ValueType.uint, forKey: .type)
            try container.encode(value, forKey: .value)
        case .float(let value):
            try container.encode(ValueType.float, forKey: .type)
            try container.encode(value, forKey: .value)
        case .bool(let value):
            try container.encode(ValueType.bool, forKey: .type)
            try container.encode(value, forKey: .value)
        case .data(let value):
            try container.encode(ValueType.data, forKey: .type)
            try container.encode(value, forKey: .value)
        case .intentID(let value):
            try container.encode(ValueType.intentID, forKey: .type)
            try container.encode(value, forKey: .value)
        case .array(let value):
            try container.encode(ValueType.array, forKey: .type)
            try container.encode(value, forKey: .value)
        case .dictionary(let value):
            try container.encode(ValueType.dictionary, forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }
}