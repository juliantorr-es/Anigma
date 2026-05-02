import Foundation
import ANEServicesCore
import CoreML

public struct CoreMLModelMetadata: @unchecked Sendable {
    public let inputDescriptions: [String: MLFeatureDescription]
    public let outputDescriptions: [String: MLFeatureDescription]
    public let metadata: [MLModelMetadataKey: Any]
    public let isUpdatable: Bool
    public let supportsANE: Bool
    public let modelSize: Int
    
    // Custom Codable implementation for MLFeatureDescription
    public init(
        inputDescriptions: [String: MLFeatureDescription],
        outputDescriptions: [String: MLFeatureDescription],
        metadata: [MLModelMetadataKey: Any],
        isUpdatable: Bool,
        supportsANE: Bool,
        modelSize: Int
    ) {
        self.inputDescriptions = inputDescriptions
        self.outputDescriptions = outputDescriptions
        self.metadata = metadata
        self.isUpdatable = isUpdatable
        self.supportsANE = supportsANE
        self.modelSize = modelSize
    }
    
    // Simplified encoding/decoding for demonstration
    enum CodingKeys: String, CodingKey {
        case inputDescriptions
        case outputDescriptions
        case metadata
        case isUpdatable
        case supportsANE
        case modelSize
    }
}
