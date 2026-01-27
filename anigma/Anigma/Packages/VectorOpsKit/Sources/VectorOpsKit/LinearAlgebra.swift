/// Linear algebra utilities
import Foundation

/// Linear algebra utilities and decompositions
public struct LinearAlgebra {
    /// Solve Ax = b using Gaussian elimination
    public static func solve(A: FloatMatrix, b: [Double]) -> [Double]? {
        guard A.rows == A.columns && A.rows == b.count else { return nil }
        
        let n = A.rows
        var augmented = Array(repeating: 0.0, count: n * (n + 1))
        
        // Create augmented matrix [A|b]
        for i in 0..<n {
            for j in 0..<n {
                augmented[i * (n + 1) + j] = A[i, j]
            }
            augmented[i * (n + 1) + n] = b[i]
        }
        
        // Forward elimination
        for i in 0..<n {
            // Find pivot
            var maxRow = i
            for k in (i + 1)..<n {
                if abs(augmented[k * (n + 1) + i]) > abs(augmented[maxRow * (n + 1) + i]) {
                    maxRow = k
                }
            }
            
            // Swap rows
            for j in 0...(n) {
                (augmented[i * (n + 1) + j], augmented[maxRow * (n + 1) + j]) = 
                (augmented[maxRow * (n + 1) + j], augmented[i * (n + 1) + j])
            }
            
            // Check for singular matrix
            if abs(augmented[i * (n + 1) + i]) < 1e-10 {
                return nil
            }
            
            // Eliminate column
            for k in (i + 1)..<n {
                let factor = augmented[k * (n + 1) + i] / augmented[i * (n + 1) + i]
                for j in i...(n) {
                    augmented[k * (n + 1) + j] -= factor * augmented[i * (n + 1) + j]
                }
            }
        }
        
        // Back substitution
        var x = Array(repeating: 0.0, count: n)
        for i in stride(from: n - 1, through: 0, by: -1) {
            x[i] = augmented[i * (n + 1) + n]
            for j in (i + 1)..<n {
                x[i] -= augmented[i * (n + 1) + j] * x[j]
            }
            x[i] /= augmented[i * (n + 1) + i]
        }
        
        return x
    }
    
    /// QR decomposition using Gram-Schmidt
    public static func qrDecomposition(_ A: FloatMatrix) -> (Q: FloatMatrix, R: FloatMatrix)? {
        guard A.rows >= A.columns else { return nil }
        
        let m = A.rows
        let n = A.columns
        
        var Q = Array(repeating: 0.0, count: m * n)
        var R = Array(repeating: 0.0, count: n * n)
        
        for j in 0..<n {
            // Get column j
            var v = (0..<m).map { i in A[i, j] }
            
            // Orthogonalize against previous columns
            for i in 0..<j {
                var dotProduct = 0.0
                for k in 0..<m {
                    dotProduct += Q[k * n + i] * v[k]
                }
                R[i * n + j] = dotProduct
                
                for k in 0..<m {
                    v[k] -= dotProduct * Q[k * n + i]
                }
            }
            
            // Normalize
            var norm = 0.0
            for k in 0..<m {
                norm += v[k] * v[k]
            }
            norm = sqrt(norm)
            
            guard norm > 1e-10 else { return nil }
            
            R[j * n + j] = norm
            for k in 0..<m {
                Q[k * n + j] = v[k] / norm
            }
        }
        
        let qMatrix = FloatMatrix(rows: m, columns: n, data: Q)
        let rMatrix = FloatMatrix(rows: n, columns: n, data: R)
        
        return (qMatrix, rMatrix)
    }
    
    /// Eigenvalue solver (power iteration method)
    public static func powerIteration(_ A: FloatMatrix, iterations: Int = 100) -> (eigenvalue: Double, eigenvector: [Double])? {
        guard A.rows == A.columns else { return nil }
        
        let n = A.rows
        var x = Array(repeating: 1.0 / sqrt(Double(n)), count: n)
        var eigenvalue = 0.0
        
        for _ in 0..<iterations {
            // Multiply A*x
            var Ax = Array(repeating: 0.0, count: n)
            for i in 0..<n {
                for j in 0..<n {
                    Ax[i] += A[i, j] * x[j]
                }
            }
            
            // Compute eigenvalue as Rayleigh quotient
            var norm = 0.0
            for i in 0..<n {
                norm += Ax[i] * Ax[i]
            }
            norm = sqrt(norm)
            
            guard norm > 0 else { return nil }
            
            eigenvalue = norm
            
            // Normalize x
            for i in 0..<n {
                x[i] = Ax[i] / norm
            }
        }
        
        return (eigenvalue, x)
    }
}
