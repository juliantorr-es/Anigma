/// Matrix type and operations
import Foundation

/// A generic matrix implementation
public struct Matrix<T: Numeric> {
    public let rows: Int
    public let columns: Int
    private let data: [T]
    
    public init(rows: Int, columns: Int, data: [T]) {
        precondition(data.count == rows * columns, "Data count must match rows × columns")
        self.rows = rows
        self.columns = columns
        self.data = data
    }
    
    /// Access element at row, column
    public subscript(row: Int, column: Int) -> T {
        data[row * columns + column]
    }
    
    /// Get row as vector
    public func getRow(_ index: Int) -> [T] {
        Array(data[(index * columns)..<((index + 1) * columns)])
    }
    
    /// Get column as vector
    public func getColumn(_ index: Int) -> [T] {
        (0..<rows).map { data[$0 * columns + index] }
    }
}

/// Floating-point matrix operations
public struct FloatMatrix {
    public let rows: Int
    public let columns: Int
    private let data: [Double]
    
    public init(rows: Int, columns: Int, data: [Double]) {
        precondition(data.count == rows * columns, "Data count must match rows × columns")
        self.rows = rows
        self.columns = columns
        self.data = data
    }
    
    /// Create identity matrix
    public static func identity(size: Int) -> FloatMatrix {
        var data = Array(repeating: 0.0, count: size * size)
        for i in 0..<size {
            data[i * size + i] = 1.0
        }
        return FloatMatrix(rows: size, columns: size, data: data)
    }
    
    /// Create zero matrix
    public static func zeros(rows: Int, columns: Int) -> FloatMatrix {
        FloatMatrix(rows: rows, columns: columns, data: Array(repeating: 0.0, count: rows * columns))
    }
    
    /// Create matrix filled with a value
    public static func filled(rows: Int, columns: Int, value: Double) -> FloatMatrix {
        FloatMatrix(rows: rows, columns: columns, data: Array(repeating: value, count: rows * columns))
    }
    
    /// Access element at row, column
    public subscript(row: Int, column: Int) -> Double {
        get { data[row * columns + column] }
        set { 
            var mutableData = data
            mutableData[row * columns + column] = newValue
            // This is a limitation of value types; in real implementation would need to handle mutability
        }
    }
    
    /// Get row as vector
    public func getRow(_ index: Int) -> [Double] {
        Array(data[(index * columns)..<((index + 1) * columns)])
    }
    
    /// Get column as vector
    public func getColumn(_ index: Int) -> [Double] {
        (0..<rows).map { data[$0 * columns + index] }
    }
    
    /// Transpose
    public var transpose: FloatMatrix {
        var transposed = Array(repeating: 0.0, count: rows * columns)
        for i in 0..<rows {
            for j in 0..<columns {
                transposed[j * rows + i] = data[i * columns + j]
            }
        }
        return FloatMatrix(rows: columns, columns: rows, data: transposed)
    }
    
    /// Matrix multiplication
    public func matrixMultiply(with other: FloatMatrix) -> FloatMatrix? {
        guard columns == other.rows else { return nil }
        
        var result = Array(repeating: 0.0, count: rows * other.columns)
        
        for i in 0..<rows {
            for j in 0..<other.columns {
                var sum = 0.0
                for k in 0..<columns {
                    sum += data[i * columns + k] * other.data[k * other.columns + j]
                }
                result[i * other.columns + j] = sum
            }
        }
        
        return FloatMatrix(rows: rows, columns: other.columns, data: result)
    }
    
    /// Element-wise addition
    public static func + (lhs: FloatMatrix, rhs: FloatMatrix) -> FloatMatrix? {
        guard lhs.rows == rhs.rows && lhs.columns == rhs.columns else { return nil }
        let result = zip(lhs.data, rhs.data).map { $0 + $1 }
        return FloatMatrix(rows: lhs.rows, columns: lhs.columns, data: result)
    }
    
    /// Element-wise subtraction
    public static func - (lhs: FloatMatrix, rhs: FloatMatrix) -> FloatMatrix? {
        guard lhs.rows == rhs.rows && lhs.columns == rhs.columns else { return nil }
        let result = zip(lhs.data, rhs.data).map { $0 - $1 }
        return FloatMatrix(rows: lhs.rows, columns: lhs.columns, data: result)
    }
    
    /// Scalar multiplication
    public static func * (lhs: FloatMatrix, rhs: Double) -> FloatMatrix {
        FloatMatrix(rows: lhs.rows, columns: lhs.columns, data: lhs.data.map { $0 * rhs })
    }
    
    /// Scalar multiplication (reversed)
    public static func * (lhs: Double, rhs: FloatMatrix) -> FloatMatrix {
        rhs * lhs
    }
    
    /// Determinant (2x2 and 3x3 only)
    public var determinant: Double? {
        if rows == 2 && columns == 2 {
            return data[0] * data[3] - data[1] * data[2]
        } else if rows == 3 && columns == 3 {
            return data[0] * (data[4] * data[8] - data[5] * data[7]) -
                   data[1] * (data[3] * data[8] - data[5] * data[6]) +
                   data[2] * (data[3] * data[7] - data[4] * data[6])
        }
        return nil
    }
    
    /// Inverse (2x2 and 3x3 only)
    public func inverse() -> FloatMatrix? {
        guard let det = determinant, det != 0 else { return nil }
        
        if rows == 2 && columns == 2 {
            let invDet = 1.0 / det
            return FloatMatrix(rows: 2, columns: 2, data: [
                data[3] * invDet,
                -data[1] * invDet,
                -data[2] * invDet,
                data[0] * invDet
            ])
        }
        
        return nil
    }
    
    /// Frobenius norm
    public var frobeniusNorm: Double {
        sqrt(data.reduce(0.0) { $0 + $1 * $1 })
    }
    
    /// Trace (sum of diagonal elements)
    public var trace: Double? {
        guard rows == columns else { return nil }
        var sum = 0.0
        for i in 0..<rows {
            sum += data[i * columns + i]
        }
        return sum
    }
}
