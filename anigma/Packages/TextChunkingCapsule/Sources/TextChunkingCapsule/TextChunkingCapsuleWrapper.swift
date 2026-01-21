import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import CapsuleCore

// Static error message constants to ensure proper lifetime management
private let chunkingNotFinalizedMsg = "Chunking not finalized"
private let dataSizeMismatchMsg = "Data size does not match processed bytes"
private let chunkBoundaryOutOfBoundsMsg = "Chunk boundary out of bounds"

// Helper to create error messages with static string pointers
private func createError(code: anigma_status_t, message: UnsafePointer<CChar>?, detail: UnsafePointer<CChar>? = nil, aux: UInt64 = 0) -> anigma_capsule_error_t {
    return anigma_capsule_error_t(
        code: code,
        message: message,
        detail: detail,
        aux: aux
    )
}

// Helper with string parameter that converts to static pointer
private func createError(code: anigma_status_t, message: String, detail: String? = nil, aux: UInt64 = 0) -> anigma_capsule_error_t {
    // Use static C string literals that persist for program lifetime
    switch message {
    case "Chunking not finalized":
        return createError(code: code, message: chunkingNotFinalizedMsg, detail: detail, aux: aux)
    case "Data size does not match processed bytes":
        return createError(code: code, message: dataSizeMismatchMsg, detail: detail, aux: aux)
    case "Chunk boundary out of bounds":
        return createError(code: code, message: chunkBoundaryOutOfBoundsMsg, detail: detail, aux: aux)
    default:
        // For any other messages, create a static copy
        return message.withCString { messagePtr in
            let staticPtr = UnsafePointer<CChar>(messagePtr)
            if let detail = detail {
                return detail.withCString { detailPtr in
                    let staticDetail = UnsafePointer<CChar>(detailPtr)
                    return createError(code: code, message: staticPtr, detail: staticDetail, aux: aux)
                }
            } else {
                return createError(code: code, message: staticPtr, detail: nil, aux: aux)
            }
        }
    }
}

/// Swift wrapper for the text chunking capsule with Rabin fingerprinting.
/// Provides both streaming and one-shot APIs for content-defined chunking.
public final class TextChunkingCapsuleWrapper {
    /// Capsule identity information.
    public static var identity: anigma_capsule_identity_t {
        anigma_text_chunking_capsule_get_identity()
    }
    
    private var handle: CapsuleHandle<AnyObject>?
    private let config: TextChunkingConfig
    private var totalBytesProcessed: UInt64 = 0
    private var finalized: Bool = false
    private let lock = NSLock()
    
    /// Total number of bytes processed since last reset.
    public var bytesProcessed: UInt64 { totalBytesProcessed }
    /// Whether chunking has been finalized.
    public var isFinalized: Bool { finalized }
    /// Configuration used for this capsule.
    public var configuration: TextChunkingConfig { config }
    
    /// Create a text chunking capsule with the given configuration.
    /// - Parameter config: Configuration for Rabin fingerprinting chunking.
    ///   If nil, uses default configuration.
    public init(config: TextChunkingConfig? = nil) throws {
        let config = config ?? TextChunkingConfig.default
        var rawHandle: anigma_text_chunking_capsule_t?
        var error = anigma_capsule_error_t()
        
        var cConfig = config.toCStruct()
        let status = anigma_text_chunking_capsule_create(&cConfig, &rawHandle, &error)
        guard status == ANIGMA_OK, let rawHandle = rawHandle else {
            throw CapsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: rawHandle,
            destroyFunction: anigma_text_chunking_capsule_destroy
        )
        self.config = config
    }
    
    deinit {
        handle?.invalidate()
    }
    
    /// Process bytes through the chunking capsule (streaming API).
    /// - Parameter data: Data to process.
    public func processBytes(_ data: Data) throws {
        guard !data.isEmpty else { return }
        finalized = false
        var error = anigma_capsule_error_t()
        try handle?.withHandle { rawHandle in
            let status = data.withUnsafeBytes { bytes in
                anigma_text_chunking_capsule_process_bytes(
                    rawHandle,
                    bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    &error
                )
            }
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
        totalBytesProcessed += UInt64(data.count)
    }
    
    /// Finalize chunking and compute remaining boundaries.
    /// Must be called after all input data has been processed.
    public func finalize() throws {
        var error = anigma_capsule_error_t()
        try handle?.withHandle { rawHandle in
            let status = anigma_text_chunking_capsule_finalize(rawHandle, &error)
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
        finalized = true
    }
    
    /// Reset the chunking capsule state for new input.
    /// Resets internal state and allows reuse of the same handle.
    public func reset() throws {
        var error = anigma_capsule_error_t()
        try handle?.withHandle { rawHandle in
            let status = anigma_text_chunking_capsule_reset(rawHandle, &error)
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
        totalBytesProcessed = 0
        finalized = false
    }
    
    /// Get the number of chunk boundaries detected.
    /// - Note: Requires that chunking has been finalized.
    public func boundaryCount() throws -> Int {
        guard finalized else {
            throw CapsuleError(
                status: ANIGMA_ERR_INVALID_ARG,
                error: createError(code: ANIGMA_ERR_INVALID_ARG, message: "Chunking not finalized")
            )
        }
        var count: size_t = 0
        var error = anigma_capsule_error_t()
        try handle?.withHandle { rawHandle in
            let status = anigma_text_chunking_capsule_get_boundary_count(rawHandle, &count, &error)
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
        return Int(count)
    }
    
    /// Get chunk boundaries (start offsets within the processed data).
    /// - Returns: Array of start offsets (bytes) for each chunk.
    /// - Note: Requires that chunking has been finalized.
    public func boundaries() throws -> [UInt64] {
        let count = try boundaryCount()
        guard count > 0 else { return [] }
        
        var offsets = [UInt64](repeating: 0, count: count)
        var actual: size_t = 0
        var error = anigma_capsule_error_t()
        try handle?.withHandle { rawHandle in
            let status = anigma_text_chunking_capsule_get_boundaries(
                rawHandle,
                &offsets,
                count,
                &actual,
                &error
            )
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
        return Array(offsets.prefix(Int(actual)))
    }
    
    /// Get complete chunk information (offsets and lengths).
    /// - Returns: Array of chunk boundaries.
    /// - Note: Requires that chunking has been finalized.
    public func chunkInfo() throws -> [ChunkBoundary] {
        let count = try boundaryCount()
        guard count > 0 else { return [] }
        
        var cBoundaries = [anigma_chunk_boundary_t](repeating: anigma_chunk_boundary_t(offset: 0, length: 0), count: count)
        var actual: size_t = 0
        var error = anigma_capsule_error_t()
        try handle?.withHandle { rawHandle in
            let status = anigma_text_chunking_capsule_get_chunk_info(
                rawHandle,
                &cBoundaries,
                count,
                &actual,
                &error
            )
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
        return cBoundaries.prefix(Int(actual)).map { ChunkBoundary(from: $0) }
    }
    
    /// Extract chunk data slices from the original data.
    /// - Parameter data: Original data that was processed (must match total bytes processed).
    /// - Returns: Array of Data slices corresponding to each chunk.
    /// - Note: Requires that chunking has been finalized.
    public func extractChunks(from data: Data) throws -> [Data] {
        guard finalized else {
            throw CapsuleError(
                status: ANIGMA_ERR_INVALID_ARG,
                error: createError(code: ANIGMA_ERR_INVALID_ARG, message: "Chunking not finalized")
            )
        }
        guard data.count == totalBytesProcessed else {
            throw CapsuleError(
                status: ANIGMA_ERR_INVALID_ARG,
                error: createError(code: ANIGMA_ERR_INVALID_ARG, message: "Data size does not match processed bytes")
            )
        }
        let boundaries = try chunkInfo()
        var chunks: [Data] = []
        chunks.reserveCapacity(boundaries.count)
        for boundary in boundaries {
            let start = Int(boundary.offset)
            let end = start + Int(boundary.length)
            guard start >= 0 && end <= data.count else {
                throw CapsuleError(
                    status: ANIGMA_ERR_INVALID_ARG,
                    error: createError(code: ANIGMA_ERR_INVALID_ARG, message: "Chunk boundary out of bounds")
                )
            }
            chunks.append(data.subdata(in: start..<end))
        }
        return chunks
    }
    
    /// One-shot chunking of a complete buffer (returns start offsets).
    /// Convenience method for small buffers that don't need streaming.
    /// - Parameters:
    ///   - data: Input data to chunk.
    ///   - config: Configuration (optional, defaults to default config).
    /// - Returns: Array of start offsets (bytes) for each chunk.
    public static func chunkOffsets(_ data: Data, config: TextChunkingConfig? = nil) throws -> [UInt64] {
        guard !data.isEmpty else { return [] }
        
        var cConfig: UnsafePointer<anigma_text_chunking_config_t>?
        if let config = config {
            var temp = config.toCStruct()
            cConfig = withUnsafePointer(to: &temp) { $0 }
        }
        
        var buffer = anigma_capsule_buffer_t()
        data.withUnsafeBytes { bytes in
            buffer.ptr = UnsafeMutablePointer<UInt8>(mutating: bytes.baseAddress?.assumingMemoryBound(to: UInt8.self))
            buffer.len = data.count
            buffer.cap = data.count
        }
        
        // First call to get required size
        var error = anigma_capsule_error_t()
        let queryStatus = anigma_text_chunking_capsule_chunk_buffer(
            cConfig,
            &buffer,
            nil,
            0,
            nil,
            &error
        )
        guard queryStatus == ANIGMA_ERR_BUFFER_TOO_SMALL else {
            throw CapsuleError(status: queryStatus, error: error)
        }
        
        let requiredCount = error.aux
        guard requiredCount > 0 else { return [] }
        
        var offsets = [UInt64](repeating: 0, count: Int(requiredCount))
        var actual: size_t = 0
        let fillStatus = anigma_text_chunking_capsule_chunk_buffer(
            cConfig,
            &buffer,
            &offsets,
            Int(requiredCount),
            &actual,
            &error
        )
        guard fillStatus == ANIGMA_OK else {
            throw CapsuleError(status: fillStatus, error: error)
        }
        
        return Array(offsets.prefix(Int(actual)))
    }
    
    /// One-shot chunking of a complete buffer (returns boundaries with lengths).
    /// Convenience method for small buffers that don't need streaming.
    /// - Parameters:
    ///   - data: Input data to chunk.
    ///   - config: Configuration (optional, defaults to default config).
    /// - Returns: Array of chunk boundaries (offset and length).
    public static func chunkBoundaries(_ data: Data, config: TextChunkingConfig? = nil) throws -> [ChunkBoundary] {
        guard !data.isEmpty else { return [] }
        // Use streaming API for simplicity and consistency
        let wrapper = try TextChunkingCapsuleWrapper(config: config)
        try wrapper.processBytes(data)
        try wrapper.finalize()
        return try wrapper.chunkInfo()
    }
}

/// Configuration for text chunking with Rabin fingerprinting.
public struct TextChunkingConfig: Sendable {
    public var targetChunkSize: Int
    public var minChunkSize: Int
    public var maxChunkSize: Int
    public var windowSize: Int
    public var polynomial: UInt64
    public var determinismTier: UInt32
    
    public static var `default`: TextChunkingConfig {
        let cConfig = anigma_text_chunking_capsule_get_default_config()
        return TextChunkingConfig(from: cConfig)
    }
    
    public init(
        targetChunkSize: Int = 2048,
        minChunkSize: Int = 512,
        maxChunkSize: Int = 8192,
        windowSize: Int = 48,
        polynomial: UInt64 = 0x3DA3358B4DC173, // Typical irreducible polynomial
        determinismTier: UInt32 = 1
    ) {
        self.targetChunkSize = targetChunkSize
        self.minChunkSize = minChunkSize
        self.maxChunkSize = maxChunkSize
        self.windowSize = windowSize
        self.polynomial = polynomial
        self.determinismTier = determinismTier
    }
    
    public func validate() throws {
        var error = anigma_capsule_error_t()
        var cConfig = toCStruct()
        let status = anigma_text_chunking_capsule_validate_config(&cConfig, &error)
        guard status == ANIGMA_OK else {
            throw CapsuleError(status: status, error: error)
        }
    }
    
    internal func toCStruct() -> anigma_text_chunking_config_t {
        anigma_text_chunking_config_t(
            target_chunk_size: targetChunkSize,
            min_chunk_size: minChunkSize,
            max_chunk_size: maxChunkSize,
            window_size: windowSize,
            polynomial: polynomial,
            determinism_tier: determinismTier
        )
    }
    
    internal init(from cConfig: anigma_text_chunking_config_t) {
        self.targetChunkSize = cConfig.target_chunk_size
        self.minChunkSize = cConfig.min_chunk_size
        self.maxChunkSize = cConfig.max_chunk_size
        self.windowSize = cConfig.window_size
        self.polynomial = cConfig.polynomial
        self.determinismTier = cConfig.determinism_tier
    }
}

/// Chunk boundary information (start offset and length).
public struct ChunkBoundary: Sendable {
    public var offset: UInt64
    public var length: UInt64
    
    public init(offset: UInt64, length: UInt64) {
        self.offset = offset
        self.length = length
    }
    
    internal init(from cBoundary: anigma_chunk_boundary_t) {
        self.offset = cBoundary.offset
        self.length = cBoundary.length
    }
    
    internal func toCStruct() -> anigma_chunk_boundary_t {
        anigma_chunk_boundary_t(offset: offset, length: length)
    }
}

extension ChunkBoundary {
    /// Create chunk boundaries from start offsets and total data size.
    /// - Parameters:
    ///   - offsets: Array of start offsets (must be sorted ascending).
    ///   - totalSize: Total size of the data.
    /// - Returns: Array of chunk boundaries with lengths computed as differences between offsets.
    public static func boundaries(from offsets: [UInt64], totalSize: UInt64) -> [ChunkBoundary] {
        guard !offsets.isEmpty else { return [] }
        var boundaries: [ChunkBoundary] = []
        for i in 0..<offsets.count {
            let start = offsets[i]
            let end = (i + 1 < offsets.count) ? offsets[i + 1] : totalSize
            guard end >= start else { continue }
            boundaries.append(ChunkBoundary(offset: start, length: end - start))
        }
        return boundaries
    }
}