//
//  AccelerateOperations.swift
//  SaturationInferenceCore
//
//  Phase 2: Accelerate Framework Operations
//  TD Tasks: td-sli-2026-2.1, td-sli-2026-2.2, td-sli-2026-2.3
//
//  vDSP, vForce, BLAS, and BNNS operations for CPU-accelerated inference.
//

import Accelerate
import Foundation

/// Accelerate-based operations for CPU inference
///
/// Provides optimized implementations using Apple's Accelerate framework:
/// - vDSP: Vector operations (add, multiply, dot product, reductions)
/// - BLAS: Matrix operations (GEMM, GEMV)
/// - vForce: Vectorized matrix operations (when available)
/// - BNNS: Neural network operations
///
/// All operations work with Float32 data type and support batch processing.
internal enum AccelerateOperations {

  // MARK: - Matrix Multiplication

  /// Matrix multiplication: C = alpha * A * B + beta * C
  /// - Parameters:
  ///   - a: Input matrix A [m, k]
  ///   - b: Input matrix B [k, n]
  ///   - c: Output matrix C [m, n]
  ///   - alpha: Scaling factor for A*B
  ///   - beta: Scaling factor for C
  ///   - m: Rows of A and C
  ///   - k: Columns of A, rows of B
  ///   - n: Columns of B and C
  internal static func gemm(
    _ a: UnsafePointer<Float>,
    _ b: UnsafePointer<Float>,
    _ c: UnsafeMutablePointer<Float>,
    alpha: Float = 1.0,
    beta: Float = 0.0,
    m: Int,
    k: Int,
    n: Int,
    lda: Int,
    ldb: Int,
    ldc: Int
  ) {
    cblas_sgemm(
      CblasRowMajor,
      CblasNoTrans,
      CblasNoTrans,
      Int32(m),
      Int32(n),
      Int32(k),
      alpha,
      a,
      Int32(lda),
      b,
      Int32(ldb),
      beta,
      c,
      Int32(ldc)
    )
  }

  /// Matrix-vector multiplication: y = alpha * A * x + beta * y
  internal static func gemv(
    _ a: UnsafePointer<Float>,
    _ x: UnsafePointer<Float>,
    _ y: UnsafeMutablePointer<Float>,
    alpha: Float = 1.0,
    beta: Float = 0.0,
    m: Int,
    n: Int,
    lda: Int,
    incx: Int = 1,
    incy: Int = 1
  ) {
    cblas_sgemv(
      CblasRowMajor,
      CblasNoTrans,
      Int32(m),
      Int32(n),
      alpha,
      a,
      Int32(lda),
      x,
      Int32(incx),
      beta,
      y,
      Int32(incy)
    )
  }

  // MARK: - Vector Operations (vDSP)

  /// Vector addition: z = x + y
  internal static func vadd(
    _ x: UnsafePointer<Float>,
    _ y: UnsafePointer<Float>,
    _ z: UnsafeMutablePointer<Float>,
    count: Int
  ) {
    vDSP_vadd(x, 1, y, 1, z, 1, vDSP_Length(count))
  }

  /// Vector subtraction: z = x - y
  internal static func vsub(
    _ x: UnsafePointer<Float>,
    _ y: UnsafePointer<Float>,
    _ z: UnsafeMutablePointer<Float>,
    count: Int
  ) {
    vDSP_vsub(y, 1, x, 1, z, 1, vDSP_Length(count))
  }

  /// Vector multiplication: z = x * y (element-wise)
  internal static func vmul(
    _ x: UnsafePointer<Float>,
    _ y: UnsafePointer<Float>,
    _ z: UnsafeMutablePointer<Float>,
    count: Int
  ) {
    vDSP_vmul(x, 1, y, 1, z, 1, vDSP_Length(count))
  }

  /// Vector division: z = x / y
  internal static func vdiv(
    _ x: UnsafePointer<Float>,
    _ y: UnsafePointer<Float>,
    _ z: UnsafeMutablePointer<Float>,
    count: Int
  ) {
    vDSP_vdiv(y, 1, x, 1, z, 1, vDSP_Length(count))
  }

  /// Vector negation: y = -x
  internal static func vneg(
    _ x: UnsafePointer<Float>,
    _ y: UnsafeMutablePointer<Float>,
    count: Int
  ) {
    vDSP_vneg(x, 1, y, 1, vDSP_Length(count))
  }

  /// Vector absolute value: y = |x|
  internal static func vabs(
    _ x: UnsafePointer<Float>,
    _ y: UnsafeMutablePointer<Float>,
    count: Int
  ) {
    vDSP_vabs(x, 1, y, 1, vDSP_Length(count))
  }

  // MARK: - Scalar Operations

  /// Vector-scalar addition: y = x + alpha
  internal static func vsma(
    _ alpha: Float,
    _ x: UnsafePointer<Float>,
    _ y: UnsafeMutablePointer<Float>,
    count: Int
  ) {
    var scalar = alpha
    vDSP_vsadd(x, vDSP_Stride(1), &scalar, y, vDSP_Stride(1), vDSP_Length(count))
  }

  /// Vector-scalar multiplication: y = x * alpha
  internal static func vsmul(
    _ x: UnsafePointer<Float>,
    _ alpha: Float,
    _ y: UnsafeMutablePointer<Float>,
    count: Int
  ) {
    var scalar = alpha
    vDSP_vsmul(x, vDSP_Stride(1), &scalar, y, vDSP_Stride(1), vDSP_Length(count))
  }

  // MARK: - Reduction Operations

  /// Sum of vector elements
  internal static func sum(
    _ x: UnsafePointer<Float>,
    count: Int
  ) -> Float {
    var result: Float = 0.0
    vDSP_sve(x, 1, &result, vDSP_Length(count))
    return result
  }

  /// Sum of squared vector elements (for norm calculations)
  internal static func sumOfSquares(
    _ x: UnsafePointer<Float>,
    count: Int
  ) -> Float {
    var result: Float = 0.0
    vDSP_svesq(x, 1, &result, vDSP_Length(count))
    return result
  }

  /// Mean of vector elements
  internal static func mean(
    _ x: UnsafePointer<Float>,
    count: Int
  ) -> Float {
    var result: Float = 0.0
    vDSP_meanv(x, 1, &result, vDSP_Length(count))
    return result
  }

  /// Maximum value in vector
  internal static func max(
    _ x: UnsafePointer<Float>,
    count: Int
  ) -> Float {
    var result: Float = 0.0
    vDSP_maxv(x, 1, &result, vDSP_Length(count))
    return result
  }

  /// Minimum value in vector
  internal static func min(
    _ x: UnsafePointer<Float>,
    count: Int
  ) -> Float {
    var result: Float = 0.0
    vDSP_minv(x, 1, &result, vDSP_Length(count))
    return result
  }

  // MARK: - Dot Product

  /// Dot product: sum(x .* y)
  internal static func dot(
    _ x: UnsafePointer<Float>,
    _ y: UnsafePointer<Float>,
    count: Int
  ) -> Float {
    var result: Float = 0.0
    vDSP_dotpr(x, vDSP_Stride(1), y, vDSP_Stride(1), &result, vDSP_Length(count))
    return result
  }

  // MARK: - Layer Normalization

  /// Layer normalization: y = gamma * (x - mean) / sqrt(var + epsilon) + beta
  ///
  /// Optimized implementation using vDSP for mean and variance calculations.
  /// - Parameters:
  ///   - x: Input vector
  ///   - y: Output vector
  ///   - gamma: Scale parameter
  ///   - beta: Shift parameter
  ///   - epsilon: Small constant for numerical stability
  ///   - n: Vector length
  internal static func layerNorm(
    _ x: UnsafePointer<Float>,
    _ y: UnsafeMutablePointer<Float>,
    _ gamma: UnsafePointer<Float>?,
    _ beta: UnsafePointer<Float>?,
    epsilon: Float,
    n: Int
  ) {
    // Calculate mean
    let mean = AccelerateOperations.mean(x, count: n)

    // Calculate variance: E[(x - mean)^2]
    // vDSP doesn't have a direct variance function, so we compute it manually
    
    // Allocate temporary buffers using malloc for aligned memory
    let tempPtr = UnsafeMutablePointer<Float>.allocate(capacity: n)
    defer { tempPtr.deallocate() }
    
    let sqPtr = UnsafeMutablePointer<Float>.allocate(capacity: n)
    defer { sqPtr.deallocate() }
    
    let normalizedPtr = UnsafeMutablePointer<Float>.allocate(capacity: n)
    defer { normalizedPtr.deallocate() }

    // First, subtract mean from all elements
    AccelerateOperations.vsma(-mean, x, tempPtr, count: n)

    // Then square the differences
    vmul(tempPtr, tempPtr, sqPtr, count: n)
    
    // Calculate mean of squared values (variance)
    let variance = AccelerateOperations.mean(sqPtr, count: n)

    // Calculate standard deviation
    let stdDev = sqrtf(variance + epsilon)

    // Normalize: (x - mean) / stdDev
    AccelerateOperations.vsma(-mean, x, normalizedPtr, count: n)
    vDSP_vsmul(normalizedPtr, 1, [Float(1.0 / stdDev)], normalizedPtr, 1, vDSP_Length(n))

    // Apply gamma and beta
    if let gamma = gamma, let beta = beta {
      for i in 0..<n {
        y[i] = normalizedPtr[i] * gamma[i] + beta[i]
      }
    } else {
      for i in 0..<n {
        y[i] = normalizedPtr[i]
      }
    }
  }

  // MARK: - Softmax

  /// Softmax: y[i] = exp(x[i]) / sum(exp(x))
  ///
  /// Numerically stable implementation that subtracts max first.
  /// - Parameters:
  ///   - x: Input vector
  ///   - y: Output vector
  ///   - n: Vector length
  internal static func softmax(
    _ x: UnsafePointer<Float>,
    _ y: UnsafeMutablePointer<Float>,
    n: Int
  ) {
    // Find max for numerical stability
    let maxVal = AccelerateOperations.max(x, count: n)

    // Compute exp(x - max) to avoid overflow
    var expShifted = [Float](repeating: 0.0, count: n)
    AccelerateOperations.vsma(-maxVal, x, &expShifted, count: n)

    for i in 0..<n {
      expShifted[i] = expf(expShifted[i])
    }

    // Compute sum of exponentials
    let sumExp = sum(&expShifted, count: n)

    // Normalize
    vDSP_vsmul(&expShifted, 1, [Float(1.0 / sumExp)], y, 1, vDSP_Length(n))
  }

  // MARK: - GELU Activation

  /// GELU approximation using vDSP
  ///
  /// Uses the approximation: GELU(x) = 0.5 * x * (1 + tanh(sqrt(2/pi) * (x + 0.044715 * x^3)))
  /// - Parameters:
  ///   - x: Input vector
  ///   - y: Output vector
  ///   - n: Vector length
  internal static func gelu(
    _ x: UnsafePointer<Float>,
    _ y: UnsafeMutablePointer<Float>,
    n: Int
  ) {
    let sqrt2OverPi = Float(0.7978845608)  // sqrt(2/pi)
    let magicConstant = Float(0.044715)  // 0.044715 for tanh approximation

    // Compute x^3
    var xCubed = [Float](repeating: 0.0, count: n)
    for i in 0..<n {
      xCubed[i] = x[i] * x[i] * x[i]
    }

    // Compute x + magicConstant * x^3
    var xPlus = [Float](repeating: 0.0, count: n)
    var magicVec = [Float](repeating: magicConstant, count: n)
    vmul(&magicVec, &xCubed, &xPlus, count: n)
    var xPlusTemp = xPlus
    vadd(x, &xPlus, &xPlusTemp, count: n)

    // Compute sqrt(2/pi) * (x + magicConstant * x^3)
    var xPlusTemp2 = xPlusTemp
    vDSP_vsmul(&xPlusTemp, 1, [Float(sqrt2OverPi)], &xPlusTemp2, 1, vDSP_Length(n))

    // Compute tanh
    for i in 0..<n {
      xPlus[i] = tanhf(xPlusTemp2[i])
    }

    // Compute 1 + tanh(...)
    var xPlusCopy = xPlus
    AccelerateOperations.vsma(1.0, &xPlus, &xPlusCopy, count: n)

    // Compute 0.5 * x * (1 + tanh(...))
    var tempResult = [Float](repeating: 0, count: n)
    vmul(x, &xPlusCopy, &tempResult, count: n)
    vDSP_vsmul(&tempResult, 1, [Float(0.5)], y, 1, vDSP_Length(n))
  }

  // MARK: - RMS Norm

  /// Root Mean Square normalization: y = x * rsqrt(ss + epsilon)
  /// where ss = sum(x^2) / n and rsqrt = 1 / sqrt
  /// - Parameters:
  ///   - x: Input vector
  ///   - y: Output vector
  ///   - epsilon: Small constant for numerical stability
  ///   - n: Vector length
  internal static func rmsNorm(
    _ x: UnsafePointer<Float>,
    _ y: UnsafeMutablePointer<Float>,
    epsilon: Float,
    n: Int
  ) {
    // Compute sum of squares
    let ss = sumOfSquares(x, count: n) / Float(n)

    // Compute 1 / sqrt(ss + epsilon)
    let scale = 1.0 / sqrtf(ss + epsilon)

    // Scale input
    vDSP_vsmul(x, 1, [Float(scale)], y, 1, vDSP_Length(n))
  }

  // MARK: - Batch Processing

  /// Batch matrix-vector multiplication
  /// - Parameters:
  ///   - a: Input matrix [batch, n]
  ///   - w: Weight matrix [n, outFeatures]
  ///   - b: Bias vector [outFeatures]
  ///   - y: Output matrix [batch, outFeatures]
  ///   - batchSize: Batch size
  ///   - n: Input features
  ///   - outFeatures: Output features
  internal static func batchMatVec(
    _ a: UnsafePointer<Float>,
    _ w: UnsafePointer<Float>,
    _ b: UnsafePointer<Float>?,
    _ y: UnsafeMutablePointer<Float>,
    batchSize: Int,
    n: Int,
    outFeatures: Int
  ) {
    // For each element in batch
    for i in 0..<batchSize {
      let rowOffset = i * n
      let outOffset = i * outFeatures

      // y[i] = A[i] * W + b
      for j in 0..<outFeatures {
        var sum: Float = 0.0
        let wOffset = j * n

        for k in 0..<n {
          sum += a[rowOffset + k] * w[wOffset + k]
        }

        y[outOffset + j] = sum + (b?[j] ?? 0.0)
      }
    }
  }

  // MARK: - Parallel Processing

  /// Parallel vector operation
  internal static func parallelVOp(
    _ x: UnsafePointer<Float>,
    _ y: UnsafePointer<Float>,
    _ z: UnsafeMutablePointer<Float>,
    elementCount: Int,
    operation: @escaping (UnsafePointer<Float>, UnsafePointer<Float>, UnsafeMutablePointer<Float>, Int) ->
      Void
  ) {
    // Use DispatchQueue for parallel processing
    let queue = DispatchQueue.global(qos: .userInitiated)
    let group = DispatchGroup()

    // Split work into chunks
    let processorCount = ProcessInfo.processInfo.processorCount
    let chunkSize = Swift.max(elementCount / processorCount, 1)
    let numChunks = (elementCount + chunkSize - 1) / chunkSize

    for i in 0..<numChunks {
      let start = i * chunkSize
      let end = Swift.min(start + chunkSize, elementCount)
      let chunkCount = end - start

      queue.async(group: group) {
        let xChunk = x.advanced(by: start)
        let yChunk = y.advanced(by: start)
        let zChunk = z.advanced(by: start)
        operation(xChunk, yChunk, zChunk, chunkCount)
      }
    }

    group.wait()
  }
}
