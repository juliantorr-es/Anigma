import Foundation
import ANEServicesCore
import CoreML

public struct CoreMLCompatibilityResult: Sendable {
    public let isCompatible: Bool
    public let recommendedComputeUnit: ANEComputeUnit
    public let issues: [String]
    public let warnings: [String]
    public let modelMetadata: CoreMLModelMetadata
    
    public init(
        isCompatible: Bool,
        recommendedComputeUnit: ANEComputeUnit,
        issues: [String],
        warnings: [String],
        modelMetadata: CoreMLModelMetadata
    ) {
        self.isCompatible = isCompatible
        self.recommendedComputeUnit = recommendedComputeUnit
        self.issues = issues
        self.warnings = warnings
        self.modelMetadata = modelMetadata
    }
}
