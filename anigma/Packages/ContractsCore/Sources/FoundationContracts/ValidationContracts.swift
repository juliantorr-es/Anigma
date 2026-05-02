import Foundation

/// Statistical summary of a media buffer's contents.
public struct BufferStatistics: Sendable, Codable, Hashable {
    public let min: Double
    public let max: Double
    public let mean: Double
    
    public init(min: Double, max: Double, mean: Double) {
        self.min = min
        self.max = max
        self.mean = mean
    }
}

/// The result of a high-speed SIMD buffer validation operation.
public struct SIMDValidationResult: Sendable, Codable, Hashable {
    public let isValid: Bool
    public let reason: String?
    public let statistics: BufferStatistics?
    
    public init(isValid: Bool, reason: String? = nil, statistics: BufferStatistics? = nil) {
        self.isValid = isValid
        self.reason = reason
        self.statistics = statistics
    }
}
