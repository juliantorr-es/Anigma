//
//  VectorColumnType.swift
//  DatabaseCore
//
//  PostgreSQL vector column type support for pgvector extension.
//
//  See td-0982de: Add vector column type support
//  See td-89a996: PostgreSQL First-Class Implementation Epic
//

import Foundation

/// Represents a PostgreSQL vector column with dimension information
public struct VectorColumn: Sendable, Hashable {
    /// Column name
    public let name: String
    
    /// Number of dimensions in the vector
    public let dimensions: Int
    
    public init(name: String, dimensions: Int) {
        self.name = name
        self.dimensions = dimensions
    }
    
    /// Get the PostgreSQL type declaration for this vector
    public var sqlType: String {
        return "vector(\(dimensions))"
    }
    
    /// Get the qualified column reference with table name
    public func qualified(table: String) -> String {
        return "\(table).\(name)"
    }
}

/// Database parameter extension for vector data
public extension DatabaseParameter {
    /// Create a vector parameter from Float32 array
    /// - Parameter vector: Array of Float values to convert to vector
    /// - Returns: DatabaseParameter with binary blob representation
    static func vector(_ vector: [Float]) -> DatabaseParameter {
        var data = Data()
        data.reserveCapacity(vector.count * MemoryLayout<Float32>.size)
        for value in vector {
            var floatValue = Float32(value)
            data.append(withUnsafeBytes(of: &floatValue) { Data($0) })
        }
        return .blob(data)
    }
}

/// Vector distance operators for pgvector extension
public enum VectorDistanceOperator: String, Sendable {
    /// Cosine distance: <=> returns 1 - cosine similarity (0 = identical, 2 = opposite)
    case cosine = "<=>"
    /// Negative inner product: <#> returns negative dot product
    case negativeInnerProduct = "<#>"
    /// L2 (Euclidean) distance: <-> returns squared Euclidean distance
    case l2 = "<->"
}

/// Extension to TypedQueryBuilder for vector operations
extension TypedQueryBuilder {
    /// Add ORDER BY nearest neighbor search
    /// - Parameters:
    ///   - column: Vector column name
    ///   - queryVector: Query vector as Float array
    ///   - operator: Distance operator to use
    public mutating func orderByNearestNeighbor(
        column: String,
        to queryVector: [Float],
        using op: VectorDistanceOperator = .cosine
    ) {
        let vectorLiteral = queryVector.map { String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), $0) }.joined(separator: ",")
        let columnRef = column
        orderByRaw("\(columnRef) \(op.rawValue) ARRAY[\(vectorLiteral)]::vector")
    }
}
