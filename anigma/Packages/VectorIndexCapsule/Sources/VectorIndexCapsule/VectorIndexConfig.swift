import Foundation

/// Configuration for the vector index.
public struct VectorIndexConfig: Sendable, Codable {
    public var dimension: Int
    public var maxElements: Int
    public var M: Int
    public var efConstruction: Int
    public var efSearch: Int
    public var allowReplaceDeleted: Bool
    public var mmapPath: String?
    
    public init(
        dimension: Int,
        maxElements: Int = 10000,
        M: Int = 16,
        efConstruction: Int = 200,
        efSearch: Int = 50,
        allowReplaceDeleted: Bool = false,
        mmapPath: String? = nil
    ) {
        self.dimension = dimension
        self.maxElements = maxElements
        self.M = M
        self.efConstruction = efConstruction
        self.efSearch = efSearch
        self.allowReplaceDeleted = allowReplaceDeleted
        self.mmapPath = mmapPath
    }
}
