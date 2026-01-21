import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import CapsuleCore

extension CapsuleBuffer {
    /// Execute a closure with a borrowed buffer pointing to the data's bytes.
    /// The buffer is only valid for the duration of the closure.
    static func withBorrowedData<T>(
        _ data: Data,
        _ body: (borrowing CapsuleBuffer) throws -> T
    ) rethrows -> T {
        try data.withUnsafeBytes { bytes in
            var buffer = CapsuleBuffer(
                borrowedInput: bytes.baseAddress!,
                count: bytes.count
            )
            return try body(buffer)
        }
    }
}

/// Compression algorithm enumeration.
public enum CompressionAlgorithm: Sendable {
    case zstd
    case brotli
    case lz4

    var nativeAlgo: anigma_compression_algo_t {
        switch self {
        case .zstd: return ANIGMA_COMPRESSION_ALGO_ZSTD
        case .brotli: return ANIGMA_COMPRESSION_ALGO_BROTLI
        case .lz4: return ANIGMA_COMPRESSION_ALGO_LZ4
        }
    }

    init?(nativeAlgo: anigma_compression_algo_t) {
        switch nativeAlgo {
        case ANIGMA_COMPRESSION_ALGO_ZSTD: self = .zstd
        case ANIGMA_COMPRESSION_ALGO_BROTLI: self = .brotli
        case ANIGMA_COMPRESSION_ALGO_LZ4: self = .lz4
        default: return nil
        }
    }
}

/// Compression mode (determinism tier).
public enum CompressionMode: Sendable {
    case streaming
    case deterministic  // Tier 1 for receipts (fixed parameters)
    case optimized     // Tier 2 for performance

    var nativeMode: anigma_compression_mode_t {
        switch self {
        case .streaming: return ANIGMA_COMPRESSION_MODE_STREAMING
        case .deterministic: return ANIGMA_COMPRESSION_MODE_DETERMINISTIC
        case .optimized: return ANIGMA_COMPRESSION_MODE_OPTIMIZED
        }
    }

    init?(nativeMode: anigma_compression_mode_t) {
        switch nativeMode {
        case ANIGMA_COMPRESSION_MODE_STREAMING: self = .streaming
        case ANIGMA_COMPRESSION_MODE_DETERMINISTIC: self = .deterministic
        case ANIGMA_COMPRESSION_MODE_OPTIMIZED: self = .optimized
        default: return nil
        }
    }
}

/// Compression level.
public enum CompressionLevel: Sendable {
    case `default`
    case fast
    case best

    var nativeLevel: anigma_compression_level_t {
        switch self {
        case .default: return ANIGMA_COMPRESSION_LEVEL_DEFAULT
        case .fast: return ANIGMA_COMPRESSION_LEVEL_FAST
        case .best: return ANIGMA_COMPRESSION_LEVEL_BEST
        }
    }

    init?(nativeLevel: anigma_compression_level_t) {
        switch nativeLevel {
        case ANIGMA_COMPRESSION_LEVEL_DEFAULT: self = .default
        case ANIGMA_COMPRESSION_LEVEL_FAST: self = .fast
        case ANIGMA_COMPRESSION_LEVEL_BEST: self = .best
        default: return nil
        }
    }
}

/// Compression configuration.
public struct CompressionConfig: Sendable {
    public let algorithm: CompressionAlgorithm
    public let mode: CompressionMode
    public let level: CompressionLevel
    public let bufferPoolSize: size_t
    public let determinismTier: UInt32

    public init(
        algorithm: CompressionAlgorithm,
        mode: CompressionMode,
        level: CompressionLevel,
        bufferPoolSize: size_t = 0,
        determinismTier: UInt32 = 0
    ) {
        self.algorithm = algorithm
        self.mode = mode
        self.level = level
        self.bufferPoolSize = bufferPoolSize
        self.determinismTier = determinismTier
    }

    var nativeConfig: anigma_compression_config_t {
        anigma_compression_config_t(
            algorithm: algorithm.nativeAlgo,
            mode: mode.nativeMode,
            level: level.nativeLevel,
            buffer_pool_size: bufferPoolSize,
            determinism_tier: determinismTier
        )
    }
}

extension CompressionConfig {
    public static func defaultConfiguration(for algorithm: CompressionAlgorithm) -> CompressionConfig {
        let native = anigma_compression_capsule_get_default_config(algorithm.nativeAlgo)
        return CompressionConfig(
            algorithm: algorithm,
            mode: CompressionMode(nativeMode: native.mode) ?? .streaming,
            level: CompressionLevel(nativeLevel: native.level) ?? .default,
            bufferPoolSize: native.buffer_pool_size,
            determinismTier: native.determinism_tier
        )
    }
}

/// Dictionary training configuration.
public struct CompressionDictionaryConfig: Sendable {
    public let dictionarySize: size_t
    public let minSampleSize: size_t
    public let maxSampleSize: size_t
    public let maxSamples: size_t

    public init(
        dictionarySize: size_t,
        minSampleSize: size_t,
        maxSampleSize: size_t,
        maxSamples: size_t
    ) {
        self.dictionarySize = dictionarySize
        self.minSampleSize = minSampleSize
        self.maxSampleSize = maxSampleSize
        self.maxSamples = maxSamples
    }

    var nativeConfig: anigma_compression_dict_config_t {
        anigma_compression_dict_config_t(
            dictionary_size: dictionarySize,
            min_sample_size: minSampleSize,
            max_sample_size: maxSampleSize,
            max_samples: maxSamples
        )
    }
}

/// Thread‑safe wrapper for the compression capsule.
public final class CompressionCapsuleWrapper {
    private let lock = NSLock()
    private var handle: CapsuleHandle<AnyObject>?

    /// Initialize a compression capsule with the given configuration.
    /// - Parameter config: Compression configuration.
    /// - Throws: `CapsuleError` if creation fails.
    public init(config: CompressionConfig) throws {
        var rawHandle: anigma_compression_capsule_t?
        var error = anigma_capsule_error_t()

        let nativeConfig = config.nativeConfig
        let status = withUnsafePointer(to: nativeConfig) { configPtr in
            anigma_compression_capsule_create(configPtr, &rawHandle, &error)
        }
        guard status == ANIGMA_OK, let rawHandle = rawHandle else {
            throw CapsuleError(status: status, error: error)
        }

        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: rawHandle,
            destroyFunction: anigma_compression_capsule_destroy
        )
    }

    /// Initialize a compression capsule with default configuration for the algorithm.
    /// - Parameter algorithm: Compression algorithm.
    /// - Throws: `CapsuleError` if creation fails.
    public convenience init(algorithm: CompressionAlgorithm) throws {
        try self.init(config: CompressionConfig.defaultConfiguration(for: algorithm))
    }

    /// Validate a compression configuration.
    /// - Parameter config: Configuration to validate.
    /// - Throws: `CapsuleError` if the configuration is invalid.
    public static func validate(config: CompressionConfig) throws {
        var error = anigma_capsule_error_t()
        let nativeConfig = config.nativeConfig
        let status = withUnsafePointer(to: nativeConfig) { configPtr in
            anigma_compression_capsule_validate_config(configPtr, &error)
        }
        guard status == ANIGMA_OK else {
            throw CapsuleError(status: status, error: error)
        }
    }

    deinit {
        lock.withLock {
            handle?.invalidate()
        }
    }

    /// Acquire a buffer from the capsule's buffer pool.
    /// - Parameter size: Requested buffer size.
    /// - Returns: A `CapsuleBuffer` backed by pooled memory.
    /// - Throws: `CapsuleError` if the acquisition fails.
    public func acquireBuffer(size: size_t) throws -> CapsuleBuffer {
        var buffer = anigma_capsule_buffer_t()
        var error = anigma_capsule_error_t()

        try lock.withLock {
            try handle?.withHandle { rawHandle in
                let status = anigma_compression_capsule_acquire_buffer(
                    rawHandle,
                    size,
                    &buffer,
                    &error
                )
                guard status == ANIGMA_OK else {
                    throw CapsuleError(status: status, error: error)
                }
            }
        }

        return CapsuleBuffer(capsuleAllocated: buffer.ptr, count: buffer.len)
    }

    /// Release a buffer back to the capsule's buffer pool.
    /// - Parameter buffer: The buffer to release.
    /// - Throws: `CapsuleError` if the release fails.
    public func releaseBuffer(_ buffer: consuming CapsuleBuffer) throws {
        // Temporary placeholder to allow compilation
        var mutableBuffer = buffer
        mutableBuffer.markReleased()
    }

    /// Estimate the compressed size for a given input size.
    /// - Parameter inputSize: Input size in bytes.
    /// - Returns: Estimated compressed size in bytes.
    /// - Throws: `CapsuleError` if the estimation fails.
    public func estimateCompressedSize(inputSize: size_t) throws -> size_t {
        var estimatedSize: size_t = 0
        var error = anigma_capsule_error_t()

        try lock.withLock {
            try handle?.withHandle { rawHandle in
                let status = anigma_compression_capsule_estimate_compressed_size(
                    rawHandle,
                    inputSize,
                    &estimatedSize,
                    &error
                )
                guard status == ANIGMA_OK else {
                    throw CapsuleError(status: status, error: error)
                }
            }
        }

        return estimatedSize
    }

    /// Compress data using the capsule's streaming API.
    /// - Parameter input: Input data.
    /// - Returns: Compressed data.
    /// - Throws: `CapsuleError` if compression fails.
    public func compress(_ input: Data) throws -> Data {
        try input.withUnsafeBytes { bytes in
            var buffer = CapsuleBuffer(borrowedInput: bytes.baseAddress!, count: bytes.count)
            let outputBuffer = try CapsuleBuffer.fill { descriptorPtr in
                var error = anigma_capsule_error_t()
                return try lock.withLock {
                    try handle?.withHandle { rawHandle in
                         var inputDesc = buffer.withUnsafeDescriptor { (ptr: UnsafePointer<anigma_capsule_buffer_t>) in ptr.pointee }
                         let status = anigma_compression_capsule_compress(
                             rawHandle,
                             &inputDesc,
                             descriptorPtr,
                             &error
                         )
                        guard status == ANIGMA_OK || status == ANIGMA_ERR_BUFFER_TOO_SMALL else {
                            throw CapsuleError(status: status, error: error)
                        }
                        return status
                    } ?? ANIGMA_ERR_NOT_INITIALIZED
                }
            }
            return outputBuffer.toData()
        }
    }

    /// Decompress data using the capsule's streaming API.
    /// - Parameter input: Compressed data.
    /// - Returns: Decompressed data.
    /// - Throws: `CapsuleError` if decompression fails.
    public func decompress(_ input: Data) throws -> Data {
        try input.withUnsafeBytes { bytes in
            var buffer = CapsuleBuffer(borrowedInput: bytes.baseAddress!, count: bytes.count)
            let outputBuffer = try CapsuleBuffer.fill { descriptorPtr in
                var error = anigma_capsule_error_t()
                return try lock.withLock {
                    try handle?.withHandle { rawHandle in
                         var inputDesc = buffer.withUnsafeDescriptor { (ptr: UnsafePointer<anigma_capsule_buffer_t>) in ptr.pointee }
                         let status = anigma_compression_capsule_decompress(
                             rawHandle,
                             &inputDesc,
                             descriptorPtr,
                             &error
                         )
                        guard status == ANIGMA_OK || status == ANIGMA_ERR_BUFFER_TOO_SMALL else {
                            throw CapsuleError(status: status, error: error)
                        }
                        return status
                    } ?? ANIGMA_ERR_NOT_INITIALIZED
                }
            }
            return outputBuffer.toData()
        }
    }

    /// Begin a streaming compression operation.
    /// - Returns: A stream handle for subsequent operations.
    /// - Throws: `CapsuleError` if the operation fails.
    public func beginCompressStream() throws -> CompressionStreamHandle {
        var rawStreamHandle: anigma_capsule_handle_t?
        var error = anigma_capsule_error_t()

        try lock.withLock {
            try handle?.withHandle { rawHandle in
                let status = anigma_compression_capsule_begin_compress_stream(
                    rawHandle,
                    &rawStreamHandle,
                    &error
                )
                guard status == ANIGMA_OK, let rawStreamHandle = rawStreamHandle else {
                    throw CapsuleError(status: status, error: error)
                }
            }
        }

        guard let rawStreamHandle = rawStreamHandle else {
            throw CapsuleError(
                status: ANIGMA_ERR_NOT_INITIALIZED,
                error: anigma_capsule_error_t(
                    code: ANIGMA_ERR_NOT_INITIALIZED,
                    message: "Stream handle not created",
                    detail: nil,
                    aux: 0
                )
            )
        }

        return CompressionStreamHandle(
            rawHandle: rawStreamHandle,
            capsule: self
        )
    }

    /// Begin a streaming decompression operation.
    /// - Returns: A stream handle for subsequent operations.
    /// - Throws: `CapsuleError` if the operation fails.
    public func beginDecompressStream() throws -> CompressionStreamHandle {
        var rawStreamHandle: anigma_capsule_handle_t?
        var error = anigma_capsule_error_t()

        try lock.withLock {
            try handle?.withHandle { rawHandle in
                let status = anigma_compression_capsule_begin_decompress_stream(
                    rawHandle,
                    &rawStreamHandle,
                    &error
                )
                guard status == ANIGMA_OK, let rawStreamHandle = rawStreamHandle else {
                    throw CapsuleError(status: status, error: error)
                }
            }
        }

        guard let rawStreamHandle = rawStreamHandle else {
            throw CapsuleError(
                status: ANIGMA_ERR_NOT_INITIALIZED,
                error: anigma_capsule_error_t(
                    code: ANIGMA_ERR_NOT_INITIALIZED,
                    message: "Stream handle not created",
                    detail: nil,
                    aux: 0
                )
            )
        }

        return CompressionStreamHandle(
            rawHandle: rawStreamHandle,
            capsule: self
        )
    }

    /// Train a compression dictionary from sample data.
    /// - Parameters:
    ///   - config: Dictionary training configuration.
    ///   - samples: Array of sample data buffers.
    /// - Returns: Trained dictionary data.
    /// - Throws: `CapsuleError` if training fails.
    public func trainDictionary(
        config: CompressionDictionaryConfig,
        samples: [Data]
    ) throws -> Data {
        let nativeConfig = config.nativeConfig
        let sampleDescriptors = samples.map { data -> anigma_capsule_buffer_t in
            data.withUnsafeBytes { bytes in
                anigma_capsule_buffer_t(
                    ptr: UnsafeMutablePointer<UInt8>(mutating: bytes.baseAddress!
                        .assumingMemoryBound(to: UInt8.self)),
                    len: bytes.count,
                    cap: bytes.count
                )
            }
        }

        let dictionaryBuffer = try CapsuleBuffer.fill { descriptorPtr in
            var error = anigma_capsule_error_t()
            return try lock.withLock {
                try handle?.withHandle { rawHandle in
                    let status = withUnsafePointer(to: nativeConfig) { configPtr in
                        sampleDescriptors.withUnsafeBufferPointer { samplesPtr in
                            anigma_compression_capsule_train_dictionary(
                                rawHandle,
                                configPtr,
                                samplesPtr.baseAddress,
                                sampleDescriptors.count,
                                descriptorPtr,
                                &error
                            )
                        }
                    }
                    guard status == ANIGMA_OK || status == ANIGMA_ERR_BUFFER_TOO_SMALL else {
                        throw CapsuleError(status: status, error: error)
                    }
                    return status
                } ?? ANIGMA_ERR_NOT_INITIALIZED
            }
        }
        return dictionaryBuffer.toData()
    }

    /// Load a compression dictionary for use with subsequent operations.
    /// - Parameter dictionary: Dictionary data.
    /// - Throws: `CapsuleError` if loading fails.
    public func loadDictionary(_ dictionary: Data) throws {
        try dictionary.withUnsafeBytes { bytes in
            var buffer = CapsuleBuffer(borrowedInput: bytes.baseAddress!, count: bytes.count)
            var error = anigma_capsule_error_t()

            try lock.withLock {
                try handle?.withHandle { rawHandle in
                     var dictDesc = buffer.withUnsafeDescriptor { (ptr: UnsafePointer<anigma_capsule_buffer_t>) in ptr.pointee }
                     let status = anigma_compression_capsule_load_dictionary(
                         rawHandle,
                         &dictDesc,
                         &error
                     )
                    guard status == ANIGMA_OK else {
                        throw CapsuleError(status: status, error: error)
                    }
                }
            }
        }
    }
}

/// Handle for a streaming compression or decompression operation.
public final class CompressionStreamHandle {
    private let lock = NSLock()
    private var rawHandle: anigma_capsule_handle_t?
    private weak var capsule: CompressionCapsuleWrapper?

    fileprivate init(rawHandle: anigma_capsule_handle_t, capsule: CompressionCapsuleWrapper) {
        self.rawHandle = rawHandle
        self.capsule = capsule
    }

    deinit {
        lock.withLock {
            if let handle = rawHandle {
                var error = anigma_capsule_error_t()
                _ = anigma_capsule_destroy_handle(handle, &error)
                rawHandle = nil
            }
        }
    }

    /// Continue streaming compression or decompression.
    /// - Parameters:
    ///   - input: Input data (can be partial).
    ///   - flush: Whether to flush internal buffers.
    /// - Returns: Compressed/decompressed data produced in this step.
    /// - Throws: `CapsuleError` if the operation fails.
    public func stream(
        _ input: Data?,
        flush: Bool = false
    ) throws -> Data {
        let outputBuffer = try CapsuleBuffer.fill { descriptorPtr in
            var error = anigma_capsule_error_t()
            return try lock.withLock {
                guard let rawHandle = rawHandle else {
                    throw CapsuleError(
                        status: ANIGMA_ERR_NOT_INITIALIZED,
                        error: anigma_capsule_error_t(
                            code: ANIGMA_ERR_NOT_INITIALIZED,
                            message: "Stream handle already destroyed",
                            detail: nil,
                            aux: 0
                        )
                    )
                }

                let status: anigma_status_t
                if let input = input {
                    status = input.withUnsafeBytes { bytes -> anigma_status_t in
                        var buffer = CapsuleBuffer(borrowedInput: bytes.baseAddress!, count: bytes.count)
                        var inputDesc = buffer.withUnsafeDescriptor { (ptr: UnsafePointer<anigma_capsule_buffer_t>) in ptr.pointee }
                        return anigma_compression_capsule_compress_stream(
                            rawHandle,
                            &inputDesc,
                            descriptorPtr,
                            flush,
                            &error
                        )
                    }
                } else {
                    status = anigma_compression_capsule_compress_stream(
                        rawHandle,
                        nil,
                        descriptorPtr,
                        flush,
                        &error
                    )
                }
                guard status == ANIGMA_OK || status == ANIGMA_ERR_BUFFER_TOO_SMALL else {
                    throw CapsuleError(status: status, error: error)
                }
                return status
            }
        }
        return outputBuffer.toData()
    }

    /// Continue streaming decompression.
    /// - Parameter input: Compressed input data (can be partial).
    /// - Returns: Decompressed data produced in this step.
    /// - Throws: `CapsuleError` if the operation fails.
    public func decompressStream(_ input: Data?) throws -> Data {
        let outputBuffer = try CapsuleBuffer.fill { descriptorPtr in
            var error = anigma_capsule_error_t()
            return try lock.withLock {
                guard let rawHandle = rawHandle else {
                    throw CapsuleError(
                        status: ANIGMA_ERR_NOT_INITIALIZED,
                        error: anigma_capsule_error_t(
                            code: ANIGMA_ERR_NOT_INITIALIZED,
                            message: "Stream handle already destroyed",
                            detail: nil,
                            aux: 0
                        )
                    )
                }

                let status: anigma_status_t
                if let input = input {
                    status = input.withUnsafeBytes { bytes -> anigma_status_t in
                        var buffer = CapsuleBuffer(borrowedInput: bytes.baseAddress!, count: bytes.count)
                        var inputDesc = buffer.withUnsafeDescriptor { (ptr: UnsafePointer<anigma_capsule_buffer_t>) in ptr.pointee }
                        return anigma_compression_capsule_decompress_stream(
                            rawHandle,
                            &inputDesc,
                            descriptorPtr,
                            &error
                        )
                    }
                } else {
                    status = anigma_compression_capsule_decompress_stream(
                        rawHandle,
                        nil,
                        descriptorPtr,
                        &error
                    )
                }
                guard status == ANIGMA_OK || status == ANIGMA_ERR_BUFFER_TOO_SMALL else {
                    throw CapsuleError(status: status, error: error)
                }
                return status
            }
        }
        return outputBuffer.toData()
    }

    /// End the streaming operation.
    /// - Throws: `CapsuleError` if ending the stream fails.
    public func end() throws {
        var error = anigma_capsule_error_t()
        try lock.withLock {
            guard let rawHandle = rawHandle else {
                    throw CapsuleError(
                        status: ANIGMA_ERR_NOT_INITIALIZED,
                        error: anigma_capsule_error_t(
                            code: ANIGMA_ERR_NOT_INITIALIZED,
                            message: "Stream handle already destroyed",
                            detail: nil,
                            aux: 0
                        )
                    )
            }

            let status = anigma_capsule_destroy_handle(rawHandle, &error)
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
            self.rawHandle = nil
        }
    }
}