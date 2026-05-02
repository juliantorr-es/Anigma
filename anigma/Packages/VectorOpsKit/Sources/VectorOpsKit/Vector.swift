/// Vector type and operations
import Foundation

/// A generic vector implementation
public struct Vector<T: Numeric> {
    public let elements: [T]
    
    public var count: Int {
        elements.count
    }
    
    public var dimension: Int {
        elements.count
    }
    
    public init(_ elements: [T]) {
        self.elements = elements
    }
    
    /// Access element by index
    public subscript(index: Int) -> T {
        elements[index]
    }
    
    /// Element-wise addition
    public static func + (lhs: Vector<T>, rhs: Vector<T>) -> Vector<T> {
        precondition(lhs.count == rhs.count, "Vectors must have same dimension")
        return Vector(zip(lhs.elements, rhs.elements).map { $0 + $1 })
    }
    
    /// Element-wise subtraction
    public static func - (lhs: Vector<T>, rhs: Vector<T>) -> Vector<T> {
        precondition(lhs.count == rhs.count, "Vectors must have same dimension")
        return Vector(zip(lhs.elements, rhs.elements).map { $0 - $1 })
    }
}

/// Floating-point vector operations
public struct FloatVector {
    public let elements: [Double]
    private static let metalLane = VectorumMetalLane()
    
    public var count: Int {
        elements.count
    }
    
    public var dimension: Int {
        elements.count
    }
    
    public init(_ elements: [Double]) {
        self.elements = elements
    }
    
    /// Access element by index
    public subscript(index: Int) -> Double {
        elements[index]
    }
    
    /// Magnitude (L2 norm)
    public var magnitude: Double {
        let floats = metalFloatElements
        if let squared = Self.metalLane.square(floats),
           let sumSquares = Self.metalLane.sum(squared) {
            return Double(sumSquares).squareRoot()
        }
        return sqrt(elements.reduce(0.0) { $0 + $1 * $1 })
    }
    
    /// Normalized vector
    public var normalized: FloatVector {
        let mag = magnitude
        guard mag > 0 else { return FloatVector(elements) }
        let floats = metalFloatElements
        if let scaled = Self.metalLane.scale(floats, by: Float(1.0 / mag)) {
            return FloatVector(scaled.map(Double.init))
        }
        return FloatVector(elements.map { $0 / mag })
    }
    
    /// Dot product
    public func dotProduct(with other: FloatVector) -> Double {
        precondition(count == other.count, "Vectors must have same dimension")
        let lhs = metalFloatElements
        let rhs = other.metalFloatElements
        if let dot = Self.metalLane.dotProduct(lhs, rhs) {
            return Double(dot)
        }
        return zip(elements, other.elements).reduce(0.0) { $0 + $1.0 * $1.1 }
    }
    
    /// Cosine similarity
    public func cosineSimilarity(with other: FloatVector) -> Double {
        let norm1 = magnitude
        let norm2 = other.magnitude
        guard norm1 > 0 && norm2 > 0 else { return 0.0 }
        return dotProduct(with: other) / (norm1 * norm2)
    }
    
    /// Euclidean distance
    public func euclideanDistance(to other: FloatVector) -> Double {
        precondition(count == other.count, "Vectors must have same dimension")
        let diff = zip(elements, other.elements).map { $0 - $1 }
        let floats = metalFloatElements
        if let deltas = Self.metalLane.subtract(floats, other.metalFloatElements),
           let squares = Self.metalLane.square(deltas),
           let sumSquares = Self.metalLane.sum(squares) {
            return Double(sumSquares).squareRoot()
        }
        return sqrt(diff.reduce(0.0) { $0 + $1 * $1 })
    }
    
    /// Manhattan distance
    public func manhattanDistance(to other: FloatVector) -> Double {
        precondition(count == other.count, "Vectors must have same dimension")
        if let deltas = Self.metalLane.absDifference(metalFloatElements, other.metalFloatElements),
           let sum = Self.metalLane.sum(deltas) {
            return Double(sum)
        }
        return zip(elements, other.elements).reduce(0.0) { $0 + Swift.abs($1.0 - $1.1) }
    }
    
    /// Element-wise addition
    public static func + (lhs: FloatVector, rhs: FloatVector) -> FloatVector {
        precondition(lhs.count == rhs.count, "Vectors must have same dimension")
        if let result = Self.metalLane.add(lhs.metalFloatElements, rhs.metalFloatElements) {
            return FloatVector(result.map(Double.init))
        }
        return FloatVector(zip(lhs.elements, rhs.elements).map { $0 + $1 })
    }
    
    /// Element-wise subtraction
    public static func - (lhs: FloatVector, rhs: FloatVector) -> FloatVector {
        precondition(lhs.count == rhs.count, "Vectors must have same dimension")
        if let result = Self.metalLane.subtract(lhs.metalFloatElements, rhs.metalFloatElements) {
            return FloatVector(result.map(Double.init))
        }
        return FloatVector(zip(lhs.elements, rhs.elements).map { $0 - $1 })
    }
    
    /// Scalar multiplication
    public static func * (lhs: FloatVector, rhs: Double) -> FloatVector {
        if let result = Self.metalLane.scale(lhs.metalFloatElements, by: Float(rhs)) {
            return FloatVector(result.map(Double.init))
        }
        return FloatVector(lhs.elements.map { $0 * rhs })
    }
    
    /// Scalar multiplication (reversed)
    public static func * (lhs: Double, rhs: FloatVector) -> FloatVector {
        rhs * lhs
    }
    
    /// Element-wise multiplication
    public func hadamardProduct(with other: FloatVector) -> FloatVector {
        precondition(count == other.count, "Vectors must have same dimension")
        if let result = Self.metalLane.hadamard(metalFloatElements, other.metalFloatElements) {
            return FloatVector(result.map(Double.init))
        }
        return FloatVector(zip(elements, other.elements).map { $0 * $1 })
    }
    
    /// Cross product (3D only)
    public func crossProduct(with other: FloatVector) -> FloatVector? {
        guard count == 3 && other.count == 3 else { return nil }
        return FloatVector([
            elements[1] * other.elements[2] - elements[2] * other.elements[1],
            elements[2] * other.elements[0] - elements[0] * other.elements[2],
            elements[0] * other.elements[1] - elements[1] * other.elements[0]
        ])
    }

    private var metalFloatElements: [Float] {
        elements.map(Float.init)
    }
}
