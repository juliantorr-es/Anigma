import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import CapsuleCore

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
    public let bufferPoolSize: Int
    public let determinismTier: UInt32

    public init(
        algorithm: CompressionAlgorithm,
        mode: CompressionMode,
        level: CompressionLevel,
        bufferPoolSize: Int = 16,
        determinismTier: UInt32 = 1
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
            buffer_pool_size: size_t(bufferPoolSize),
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
            bufferPoolSize: Int(native.buffer_pool_size),
            determinismTier: native.determinism_tier
        )
    }
}

/// Dictionary training configuration.
public struct CompressionDictionaryConfig: Sendable {
    public let dictionarySize: Int
    public let minSampleSize: Int
    public let maxSampleSize: Int
    public let maxSamples: Int

    public init(
        dictionarySize: Int,
        minSampleSize: Int = 0,
        maxSampleSize: Int = 0,
        maxSamples: Int = 0
    ) {
        self.dictionarySize = dictionarySize
        self.minSampleSize = minSampleSize
        self.maxSampleSize = maxSampleSize
        self.maxSamples = maxSamples
    }

    var nativeConfig: anigma_compression_dict_config_t {
        anigma_compression_dict_config_t(
            dictionary_size: size_t(dictionarySize),
            min_sample_size: size_t(minSampleSize),
            max_sample_size: size_t(maxSampleSize),
            max_samples: size_t(maxSamples)
        )
    }
}

/// Thread‑safe actor for the compression capsule.
public actor CompressionCapsule {
    private let handle: CapsuleHandle<AnyObject>

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
            throw CapsuleNativeError(status: status, error: error)
        }

        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: rawHandle,
            destroyFunction: anigma_compression_capsule_destroy
        )
    }

    /// Initialize a compression capsule with default configuration for the algorithm.
    /// - Parameter algorithm: Compression algorithm.
    /// - Throws: `CapsuleError` if creation fails.
    public init(algorithm: CompressionAlgorithm) throws {
        try self.init(config: CompressionConfig.defaultConfiguration(for: algorithm))
    }

    /// Validate a compression configuration.
    public static func validate(config: CompressionConfig) throws {
        var error = anigma_capsule_error_t()
        let nativeConfig = config.nativeConfig
        let status = withUnsafePointer(to: nativeConfig) { configPtr in
            anigma_compression_capsule_validate_config(configPtr, &error)
        }
        guard status == ANIGMA_OK else {
            throw CapsuleNativeError(status: status, error: error)
        }
    }

    private func performTwoPhaseOperation(
        _ operation: (UnsafeMutablePointer<anigma_capsule_buffer_t>?, UnsafeMutablePointer<anigma_capsule_error_t>) throws -> anigma_status_t
    ) throws -> CapsuleBuffer {
        var error = anigma_capsule_error_t()
        let status = try operation(nil, &error)
        
        guard status == ANIGMA_ERR_BUFFER_TOO_SMALL else {
            throw CapsuleNativeError(status: status, error: error)
        }
        
        var buffer = CapsuleBuffer(callerAllocatedOutput: Int(error.aux))
        let fillStatus = try buffer.withUnsafeDescriptor { descPtr in
            try operation(descPtr, &error)
        }
        
        guard fillStatus == ANIGMA_OK else {
            throw CapsuleNativeError(status: fillStatus, error: error)
        }
        
        return buffer
    }

    /// Acquire a buffer from the capsule's buffer pool.
    public func acquireBuffer(size: Int) throws -> CapsuleBuffer {
        var buffer = anigma_capsule_buffer_t()
        var error = anigma_capsule_error_t()

        try handle.withHandle { rawHandle in
            let status = anigma_compression_capsule_acquire_buffer(
                rawHandle,
                size_t(size),
                &buffer,
                &error
            )
            guard status == ANIGMA_OK else {
                throw CapsuleNativeError(status: status, error: error)
            }
        }

        return CapsuleBuffer(capsuleAllocated: buffer.ptr, count: Int(buffer.len))
    }

    /// Release a buffer back to the capsule's buffer pool.
    public func releaseBuffer(_ buffer: consuming CapsuleBuffer) throws {
        var nativeBuf = buffer.withUnsafeDescriptor { (ptr: UnsafeMutablePointer<anigma_capsule_buffer_t>) in
            ptr.pointee
        }
        var error = anigma_capsule_error_t()
        
        try handle.withHandle { rawHandle in
            let status = anigma_compression_capsule_release_buffer(rawHandle, &nativeBuf, &error)
            guard status == ANIGMA_OK else {
                throw CapsuleNativeError(status: status, error: error)
            }
        }
        buffer.markReleased()
    }

    /// Estimate the compressed size for a given input size.
    public func estimateCompressedSize(inputSize: Int) throws -> Int {
        var estimatedSize: size_t = 0
        var error = anigma_capsule_error_t()

        try handle.withHandle { rawHandle in
            let status = anigma_compression_capsule_estimate_compressed_size(
                rawHandle,
                size_t(inputSize),
                &estimatedSize,
                &error
            )
            guard status == ANIGMA_OK else {
                throw CapsuleNativeError(status: status, error: error)
            }
        }

        return Int(estimatedSize)
    }

    /// Compress data using the capsule's simple API.
    public func compress(_ input: Data) throws -> Data {
        try input.withUnsafeBytes { bytes in
            let inputBuffer = CapsuleBuffer(borrowedInput: bytes.baseAddress!, count: bytes.count)
            let outputBuffer = try performTwoPhaseOperation { (outputDesc, errorPtr) in
                try handle.withHandle { rawHandle in
                    var inputDesc = inputBuffer.withUnsafeDescriptor { (ptr: UnsafePointer<anigma_capsule_buffer_t>) in
                        ptr.pointee
                    }
                    return anigma_compression_capsule_compress(rawHandle, &inputDesc, outputDesc, errorPtr)
                }
            }
            return outputBuffer.toData()
        }
    }

    /// Decompress data using the capsule's simple API.
    public func decompress(_ input: Data) throws -> Data {
        try input.withUnsafeBytes { bytes in
            let inputBuffer = CapsuleBuffer(borrowedInput: bytes.baseAddress!, count: bytes.count)
            let outputBuffer = try performTwoPhaseOperation { (outputDesc, errorPtr) in
                try handle.withHandle { rawHandle in
                    var inputDesc = inputBuffer.withUnsafeDescriptor { (ptr: UnsafePointer<anigma_capsule_buffer_t>) in
                        ptr.pointee
                    }
                    return anigma_compression_capsule_decompress(rawHandle, &inputDesc, outputDesc, errorPtr)
                }
            }
            return outputBuffer.toData()
        }
    }

    /// Begin a streaming compression operation.
    public func beginCompressStream() throws -> CompressionStreamHandle {
        var rawStreamHandle: anigma_capsule_handle_t?
        var error = anigma_capsule_error_t()

        try handle.withHandle { rawHandle in
            let status = anigma_compression_capsule_begin_compress_stream(
                rawHandle,
                &rawStreamHandle,
                &error
            )
            guard status == ANIGMA_OK, let _ = rawStreamHandle else {
                throw CapsuleNativeError(status: status, error: error)
            }
        }

        guard let rawStreamHandle = rawStreamHandle else {
            throw CapsuleNativeError(status: ANIGMA_ERR_INTERNAL, error: anigma_capsule_error_t())
        }

        return CompressionStreamHandle(rawHandle: rawStreamHandle, capsule: self)
    }

    /// Begin a streaming decompression operation.
    public func beginDecompressStream() throws -> CompressionStreamHandle {
        var rawStreamHandle: anigma_capsule_handle_t?
        var error = anigma_capsule_error_t()

        try handle.withHandle { rawHandle in
            let status = anigma_compression_capsule_begin_decompress_stream(
                rawHandle,
                &rawStreamHandle,
                &error
            )
            guard status == ANIGMA_OK, let _ = rawStreamHandle else {
                throw CapsuleNativeError(status: status, error: error)
            }
        }

        guard let rawStreamHandle = rawStreamHandle else {
            throw CapsuleNativeError(status: ANIGMA_ERR_INTERNAL, error: anigma_capsule_error_t())
        }

        return CompressionStreamHandle(rawHandle: rawStreamHandle, capsule: self)
    }

    /// Train a compression dictionary from sample data.
    public func trainDictionary(
        config: CompressionDictionaryConfig,
        samples: [Data]
    ) throws -> Data {
        let nativeConfig = config.nativeConfig
        let sampleDescriptors = samples.map { data -> anigma_capsule_buffer_t in
            data.withUnsafeBytes { bytes in
                anigma_capsule_buffer_t(
                    ptr: UnsafeMutablePointer<UInt8>(mutating: bytes.baseAddress!.assumingMemoryBound(to: UInt8.self)),
                    len: bytes.count,
                    cap: bytes.count
                )
            }
        }

        let dictionaryBuffer = try performTwoPhaseOperation { (outputDesc, errorPtr) in
            try handle.withHandle { rawHandle in
                withUnsafePointer(to: nativeConfig) { configPtr in
                    sampleDescriptors.withUnsafeBufferPointer { samplesPtr in
                        anigma_compression_capsule_train_dictionary(
                            rawHandle,
                            configPtr,
                            samplesPtr.baseAddress,
                            sampleDescriptors.count,
                            outputDesc,
                            errorPtr
                        )
                    }
                }
            }
        }
        return dictionaryBuffer.toData()
    }

    /// Load a compression dictionary for use with subsequent operations.
    public func loadDictionary(_ dictionary: Data) throws {
        try dictionary.withUnsafeBytes { bytes in
            let buffer = CapsuleBuffer(borrowedInput: bytes.baseAddress!, count: bytes.count)
            var error = anigma_capsule_error_t()

            try handle.withHandle { rawHandle in
                 var dictDesc = buffer.withUnsafeDescriptor { $0.pointee }
                 let status = anigma_compression_capsule_load_dictionary(
                     rawHandle,
                     &dictDesc,
                     &error
                 )
                guard status == ANIGMA_OK else {
                    throw CapsuleNativeError(status: status, error: error)
                }
            }
        }
    }
}

/// Thread‑safe handle for a streaming compression or decompression operation.
public final class CompressionStreamHandle {
    private let rawHandle: anigma_capsule_handle_t
    private let capsule: CompressionCapsule

    fileprivate init(rawHandle: anigma_capsule_handle_t, capsule: CompressionCapsule) {
        self.rawHandle = rawHandle
        self.capsule = capsule
    }

    deinit {
        let handle = rawHandle
        Task {
            var error = anigma_capsule_error_t()
            _ = anigma_capsule_destroy_handle(handle, &error)
        }
    }

    /// Continue streaming compression.
    public func stream(_ input: Data?, flush: Bool = false) async throws -> Data {
        if let input = input {
            return try input.withUnsafeBytes { bytes in
                var error = anigma_capsule_error_t()
                var buffer = CapsuleBuffer(callerAllocatedOutput: 128 * 1024)
                let status = try buffer.withUnsafeDescriptor { outputDesc in
                    if let base = bytes.baseAddress {
                        let inputBuffer = CapsuleBuffer(borrowedInput: base, count: bytes.count)
                        var inputDesc = inputBuffer.withUnsafeDescriptor { (ptr: UnsafePointer<anigma_capsule_buffer_t>) in
                            ptr.pointee
                        }
                        return anigma_compression_capsule_compress_stream(rawHandle, &inputDesc, outputDesc, flush, &error)
                    }
                    return anigma_compression_capsule_compress_stream(rawHandle, nil, outputDesc, flush, &error)
                }
                guard status == ANIGMA_OK else {
                    throw CapsuleNativeError(status: status, error: error)
                }
                return buffer.toData()
            }
        }
        var error = anigma_capsule_error_t()
        var buffer = CapsuleBuffer(callerAllocatedOutput: 128 * 1024)
        let status = try buffer.withUnsafeDescriptor { outputDesc in
            anigma_compression_capsule_compress_stream(rawHandle, nil, outputDesc, flush, &error)
        }
        guard status == ANIGMA_OK else {
            throw CapsuleNativeError(status: status, error: error)
        }
        return buffer.toData()
    }

    /// Continue streaming decompression.
    public func decompressStream(_ input: Data?) async throws -> Data {
        if let input = input {
            return try input.withUnsafeBytes { bytes in
                var error = anigma_capsule_error_t()
                var buffer = CapsuleBuffer(callerAllocatedOutput: 128 * 1024)
                let status = try buffer.withUnsafeDescriptor { outputDesc in
                    if let base = bytes.baseAddress {
                        let inputBuffer = CapsuleBuffer(borrowedInput: base, count: bytes.count)
                        var inputDesc = inputBuffer.withUnsafeDescriptor { (ptr: UnsafePointer<anigma_capsule_buffer_t>) in
                            ptr.pointee
                        }
                        return anigma_compression_capsule_decompress_stream(rawHandle, &inputDesc, outputDesc, &error)
                    }
                    return anigma_compression_capsule_decompress_stream(rawHandle, nil, outputDesc, &error)
                }
                guard status == ANIGMA_OK else {
                    throw CapsuleNativeError(status: status, error: error)
                }
                return buffer.toData()
            }
        }
        var error = anigma_capsule_error_t()
        var buffer = CapsuleBuffer(callerAllocatedOutput: 128 * 1024)
        let status = try buffer.withUnsafeDescriptor { outputDesc in
            anigma_compression_capsule_decompress_stream(rawHandle, nil, outputDesc, &error)
        }
        guard status == ANIGMA_OK else {
            throw CapsuleNativeError(status: status, error: error)
        }
        return buffer.toData()
    }
}
