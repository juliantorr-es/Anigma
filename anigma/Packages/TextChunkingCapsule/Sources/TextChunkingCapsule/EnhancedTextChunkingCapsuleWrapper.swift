import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import CapsuleCore

// Static error message constants to ensure proper lifetime management
private let invalidHandleMsg = "Invalid capsule handle"
private let chunkingNotFinalizedMsg = "Chunking not finalized"
private let dataSizeMismatchMsg = "Data size does not match processed bytes"
private let chunkBoundaryOutOfBoundsMsg = "Chunk boundary out of bounds"
private let textPipelineFailedMsg = "Text pipeline processing failed"

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
    case "Invalid capsule handle":
        return createError(code: code, message: invalidHandleMsg, detail: detail, aux: aux)
    case "Chunking not finalized":
        return createError(code: code, message: chunkingNotFinalizedMsg, detail: detail, aux: aux)
    case "Data size does not match processed bytes":
        return createError(code: code, message: dataSizeMismatchMsg, detail: detail, aux: aux)
    case "Chunk boundary out of bounds":
        return createError(code: code, message: chunkBoundaryOutOfBoundsMsg, detail: detail, aux: aux)
    case "Text pipeline processing failed":
        return createError(code: code, message: textPipelineFailedMsg, detail: detail, aux: aux)
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

/// Enhanced chunk boundary information with stable ID generation.
public struct EnhancedChunkBoundary: Sendable {
    public var offset: UInt64           // Byte offset in original text
    public var length: UInt64          // Length in bytes
    public var stableId: String       // Stable chunk ID for evidence chain
    public var type: String           // Type of boundary reason
    public var confidence: UInt8       // Confidence score (0-255)
    public var textHash: String?      // Hash of chunk text for change detection
    
    public init(offset: UInt64, length: UInt64, stableId: String, type: String, confidence: UInt8, textHash: String? = nil) {
        self.offset = offset
        self.length = length
        self.stableId = stableId
        self.type = type
        self.confidence = confidence
        self.textHash = textHash
    }
    
    internal init(from cBoundary: anigma_chunk_boundary_t, with documentId: String) {
        self.offset = cBoundary.offset
        self.length = cBoundary.length
        self.type = "chunk"
        self.confidence = 255
        
        // Generate stable ID: docId + offset + length + hash
        let idComponents = [documentId, String(cBoundary.offset), String(cBoundary.length)]
        self.stableId = idComponents.joined(separator: "_")
    }
}

/// Configuration for enhanced text chunking with TextPipeline integration.
public struct EnhancedTextChunkingConfig: Sendable {
    public var targetChunkSize: Int
    public var minChunkSize: Int
    public var maxChunkSize: Int
    public var windowSize: Int
    public var polynomial: UInt64
    public var determinismTier: UInt32
    
    // TextPipeline integration options
    public var enableTextNormalization: Bool
    public var unicodeForm: UnicodeForm
    public var enableBoundaryHinting: Bool
    public var enableStableIds: Bool
    public var documentIdPrefix: String
    
    public static var `default`: EnhancedTextChunkingConfig {
        let cConfig = anigma_text_chunking_capsule_get_default_config()
        return EnhancedTextChunkingConfig(
            targetChunkSize: Int(cConfig.target_chunk_size),
            minChunkSize: Int(cConfig.min_chunk_size),
            maxChunkSize: Int(cConfig.max_chunk_size),
            windowSize: Int(cConfig.window_size),
            polynomial: cConfig.polynomial,
            determinismTier: cConfig.determinism_tier,
            enableTextNormalization: true,
            unicodeForm: .nfc,
            enableBoundaryHinting: true,
            enableStableIds: true,
            documentIdPrefix: "doc"
        )
    }
}

/// Swift wrapper for enhanced text chunking capsule with TextPipeline integration.
/// Provides stable chunk IDs, deterministic output, and Unicode normalization.
public final class EnhancedTextChunkingCapsuleWrapper {
    /// Capsule identity information.
    public static var identity: anigma_capsule_identity_t {
        anigma_text_chunking_capsule_get_identity()
    }
    
    private var chunkingHandle: CapsuleHandle<AnyObject>?
    private var textPipelineHandle: CapsuleHandle<AnyObject>?
    private var config: EnhancedTextChunkingConfig
    private var currentDocumentId: String
    private var totalBytesProcessed: UInt64 = 0
    private var textPipelineConfig: TextPipelineConfig?
    private let lock = NSLock()
    
    /// Configuration used by this capsule.
    public var configuration: EnhancedTextChunkingConfig { config }
    
    /// Total number of bytes processed since last reset.
    public var bytesProcessed: UInt64 { totalBytesProcessed }
    
    /// Create an enhanced text chunking capsule with the given configuration.
    /// - Parameter config: Enhanced configuration for text chunking
    public init(config: EnhancedTextChunkingConfig = .default) throws {
        var chunkingRawHandle: anigma_text_chunking_capsule_t?
        var textPipelineRawHandle: anigma_text_pipeline_capsule_t?
        var error = anigma_capsule_error_t()
        
        // Create chunking capsule
        let cConfig = anigma_text_chunking_config_t(
            target_chunk_size: config.targetChunkSize,
            min_chunk_size: config.minChunkSize,
            max_chunk_size: config.maxChunkSize,
            window_size: config.windowSize,
            polynomial: config.polynomial,
            determinism_tier: config.determinismTier
        )
        let chunkingStatus = anigma_text_chunking_capsule_create(&cConfig, &chunkingRawHandle, &error)
        guard chunkingStatus == ANIGMA_OK, let chunkingHandle = chunkingRawHandle else {
            throw CapsuleError(status: chunkingStatus, error: error)
        }
        
        // Create text pipeline capsule if enabled
        if config.enableTextNormalization || config.enableBoundaryHinting {
            let textCConfig = TextPipelineConfig(
                unicodeForm: config.unicodeForm,
                caseMode: .none,
                diacriticMode: .keep,
                preserveWhitespace: true,
                preserveLineBreaks: true,
                determinismTier: config.determinismTier
            ).toCStruct()
            
            let textStatus = anigma_text_pipeline_capsule_create(&textCConfig, &textPipelineRawHandle, &error)
            guard textStatus == ANIGMA_OK, let textHandle = textPipelineRawHandle else {
                throw CapsuleError(status: textStatus, error: error)
            }
            
            self.textPipelineConfig = TextPipelineConfig(from: textCConfig)
            self.textPipelineHandle = CapsuleHandle<AnyObject>(
                rawHandle: textHandle,
                destroyFunction: anigma_text_pipeline_capsule_destroy
            )
        } else {
            self.textPipelineConfig = nil
            self.textPipelineHandle = nil
        }
        
        self.chunkingHandle = CapsuleHandle<AnyObject>(
            rawHandle: chunkingHandle,
            destroyFunction: anigma_text_chunking_capsule_destroy
        )
        self.config = config
        
        // Generate initial document ID
        currentDocumentId = "\(config.documentIdPrefix)_\(Date().timeIntervalSince1970))"
    }
    
    deinit {
        lock.withLock {
            chunkingHandle?.invalidate()
            textPipelineHandle?.invalidate()
        }
    }
    
    // MARK: - Chunking Operations
    
    /// Process bytes through the enhanced chunking capsule (streaming API).
    /// - Parameter data: Data to process
    /// - Parameter documentId: Optional document ID for stable chunk IDs
    public func processBytes(_ data: Data, documentId: String? = nil) throws {
        guard !data.isEmpty else { return }
        
        // Update document ID if provided
        if let docId = documentId {
            currentDocumentId = docId
        }
        
        totalBytesProcessed += UInt64(data.count)
        
        lock.withLock {
            let status = data.withUnsafeBytes { bytes in
                anigma_text_chunking_capsule_process_bytes(
                    chunkingHandle!,
                    bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    &error
                )
            }
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
    }
    
    /// Finalize chunking and compute remaining boundaries.
    /// Must be called after all input data has been processed.
    public func finalize() throws {
        var error = anigma_capsule_error_t()
        
        lock.withLock {
            let status = anigma_text_chunking_capsule_finalize(chunkingHandle!, &error)
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
    }
    
    /// Reset the chunking capsule state for new input.
    /// Resets internal state and allows reuse of the same handle.
    public func reset() throws {
        var error = anigma_capsule_error_t()
        
        lock.withLock {
            let status = anigma_text_chunking_capsule_reset(chunkingHandle!, &error)
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
        
        totalBytesProcessed = 0
    }
    
    /// Get the number of chunk boundaries detected.
    /// - Note: Requires that chunking has been finalized.
    public func boundaryCount() throws -> Int {
        var count: size_t = 0
        var error = anigma_capsule_error_t()
        
        lock.withLock {
            let status = anigma_text_chunking_capsule_get_boundary_count(chunkingHandle!, &count, &error)
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
        
        lock.withLock {
            let status = anigma_text_chunking_capsule_get_boundaries(
                chunkingHandle!, &offsets, count, &actual, &error
            )
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
        
        return Array(offsets.prefix(Int(actual)))
    }
    
    /// Get enhanced chunk boundaries with stable IDs and metadata.
    /// - Returns: Array of enhanced chunk boundaries.
    /// - Note: Requires that chunking has been finalized and TextPipeline is enabled.
    public func enhancedBoundaries() throws -> [EnhancedChunkBoundary] {
        let boundaries = try boundaries()
        let count = boundaries.count
        
        guard config.enableStableIds && textPipelineHandle != nil else {
            // Return basic boundaries without stable IDs
            return boundaries.enumerated().map { offset, length in
                EnhancedChunkBoundary(from: anigma_chunk_boundary_t(offset: offset, length: length), with: currentDocumentId)
            }
        }
        
        // Get chunk text for each boundary to generate hashes
        var chunkTexts: [String] = []
        for boundary in boundaries {
            let start = Int(boundary.offset)
            let end = start + Int(boundary.length)
            guard end <= totalBytesProcessed else {
                chunkTexts.append("") // Safety check
                continue
            }
            
            let chunkText = try extractChunkText(start: start, end: end)
            chunkTexts.append(chunkText)
        }
        
        // Generate enhanced boundaries with stable IDs
        var enhancedBoundaries: [EnhancedChunkBoundary] = []
        for (index, boundary) in boundaries.enumerated() {
            let stableId = "\(currentDocumentId)_chunk_\(index)"
            let textHash = config.enableTextNormalization ? String(chunkTexts[index].utf8.hash) : nil
            
            let enhancedBoundary = EnhancedChunkBoundary(
                from: boundary,
                with: currentDocumentId
            )
            enhancedBoundary.stableId = stableId
            enhancedBoundary.textHash = textHash
            enhancedBoundaries.append(enhancedBoundary)
        }
        
        return enhancedBoundaries
    }
    
    /// Extract chunk data slices from the original data.
    /// - Parameter data: Original data that was processed (must match total bytes processed).
    /// - Returns: Array of Data slices corresponding to each chunk.
    /// - Note: Requires that chunking has been finalized.
    public func extractChunks(from data: Data) throws -> [Data] {
        let boundaries = try boundaries()
        guard data.count == totalBytesProcessed else {
            throw CapsuleError(
                status: ANIGMA_ERR_INVALID_ARG,
                error: createError(code: ANIGMA_ERR_INVALID_ARG, message: dataSizeMismatchMsg)
            )
        }
        
        var chunks: [Data] = []
        chunks.reserveCapacity(boundaries.count)
        
        for boundary in boundaries {
            let start = Int(boundary.offset)
            let end = start + Int(boundary.length)
            guard end <= data.count else {
                chunks.append(Data())
                continue
            }
            chunks.append(data.subdata(in: start..<end))
        }
        
        return chunks
    }
    
    // MARK: - One-shot Methods
    
    /// One-shot chunking of a complete buffer with enhanced configuration.
    /// - Parameters:
    ///   - data: Input data to chunk
    ///   - config: Enhanced configuration (optional, defaults to default config).
    ///   - documentId: Optional document ID for stable chunk IDs
    /// - Returns: Array of enhanced chunk boundaries
    public static func chunkEnhanced(
        _ data: Data,
        config: EnhancedTextChunkingConfig? = nil,
        documentId: String? = nil
    ) throws -> [EnhancedChunkBoundary] {
        guard !data.isEmpty else { return [] }
        
        let wrapper = try EnhancedTextChunkingCapsuleWrapper(config: config ?? .default)
        defer { 
            try? wrapper.processBytes(data, documentId: documentId)
            try? wrapper.finalize()
        }
        
        return try wrapper.enhancedBoundaries()
    }
    
    // MARK: - Private Helper Methods
    
    private func extractChunkText(start: Int, end: Int) throws -> String {
        guard let textPipeline = textPipelineHandle else {
            return ""
        }
        
        // Extract text portion for processing
        let textData = Data(count: end - start)
        
        var error = anigma_capsule_error_t()
        var processedText: Data?
        
        return textPipelineHandle.withHandle { textHandle in
            // Two-phase buffer operation for transformation
            var buffer = anigma_capsule_buffer_t()
            
            // Query required size
            let queryStatus = textData.withUnsafeBytes { bytes in
                anigma_text_pipeline_capsule_normalize_unicode(
                    textHandle,
                    bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    textData.count,
                    config.unicodeForm.cValue,
                    &buffer,
                    &error
                )
            }
            
            guard queryStatus == ANIGMA_ERR_BUFFER_TOO_SMALL else {
                throw CapsuleError(status: queryStatus, error: error)
            }
            
            let requiredSize = Int(error.aux)
            let outputData = Data(count: requiredSize)
            buffer.ptr = outputData.withUnsafeMutableBytes { $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }
            buffer.cap = requiredSize
            
            // Fill buffer
            let fillStatus = textData.withUnsafeBytes { bytes in
                anigma_text_pipeline_capsule_normalize_unicode(
                    textHandle,
                    bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    textData.count,
                    config.unicodeForm.cValue,
                    &buffer,
                    &error
                )
            }
            
            guard fillStatus == ANIGMA_OK else {
                throw CapsuleError(status: fillStatus, error: error)
            }
            
            // Extract normalized text
            let normalizedText = String(data: outputData, encoding: .utf8)
            
            // Get the portion corresponding to our range
            let startIndex = normalizedText.utf8.index(normalizedText.startIndex, offsetBy: start)
            let endIndex = normalizedText.utf8.index(startIndex, offsetBy: end)
            
            guard startIndex <= endIndex else {
                return ""  // Safety check
            }
            
            return String(normalizedText[startIndex..<endIndex])
        } ?? ""
    }
}