import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import CapsuleCore

// Static error message constants to ensure proper lifetime management
private let invalidHandleMsg = "Invalid capsule handle"
private let transformFailedMsg = "Text transformation failed"
private let unicodeNormFailedMsg = "Unicode normalization failed"
private let utf8ValidationFailedMsg = "UTF-8 validation failed"
private let boundaryDetectionFailedMsg = "Boundary detection failed"

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
    case "Text transformation failed":
        return createError(code: code, message: transformFailedMsg, detail: detail, aux: aux)
    case "Unicode normalization failed":
        return createError(code: code, message: unicodeNormFailedMsg, detail: detail, aux: aux)
    case "UTF-8 validation failed":
        return createError(code: code, message: utf8ValidationFailedMsg, detail: detail, aux: aux)
    case "Boundary detection failed":
        return createError(code: code, message: boundaryDetectionFailedMsg, detail: detail, aux: aux)
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

/// Swift wrapper for deterministic text processing capsule.
/// Provides Unicode normalization, case conversion, diacritic processing, and boundary detection.
public final class TextPipelineCapsuleWrapper {
    /// Capsule identity information.
    public static var identity: anigma_capsule_identity_t {
        anigma_text_pipeline_capsule_get_identity()
    }
    
    private var handle: CapsuleHandle<AnyObject>?
    private let lock = NSLock()
    
    /// Create a text pipeline capsule with default configuration.
    public init() throws {
        var rawHandle: anigma_text_pipeline_capsule_t?
        var error = anigma_capsule_error_t()
        
        let status = anigma_text_pipeline_capsule_create(nil, &rawHandle, &error)
        guard status == ANIGMA_OK, let rawHandle = rawHandle else {
            throw CapsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: rawHandle,
            destroyFunction: anigma_text_pipeline_capsule_destroy
        )
    }
    
    deinit {
        lock.withLock {
            handle?.invalidate()
        }
    }
    
    // MARK: - Core Transformation
    
    /// Transform text using the full pipeline.
    /// - Parameter text: Input text to transform
    /// - Returns: Complete transformation result with boundaries and offset map
    public func transform(_ text: String) throws -> Data {
        let textData = text.data(using: .utf8) ?? Data()
        
        var result = anigma_text_result_t()
        var error = anigma_capsule_error_t()
        
        try handle?.withHandle { rawHandle in
            let status = textData.withUnsafeBytes { bytes in
                anigma_text_pipeline_capsule_transform(
                    rawHandle,
                    bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    textData.count,
                    &result,
                    &error
                )
            }
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
        
        // Return transformed text
        return Data(
            bytes: result.transformed_text,
            count: Int(result.transformed_length)
        )
    }
    
    /// Validate UTF-8 encoding of text.
    /// - Parameter text: Text to validate
    /// - Returns: True if text is valid UTF-8
    public func validateUTF8(_ text: String) throws -> Bool {
        let textData = text.data(using: .utf8) ?? Data()
        var isValid: UInt8 = 0
        var error = anigma_capsule_error_t()
        
        try handle?.withHandle { rawHandle in
            let status = textData.withUnsafeBytes { bytes in
                anigma_text_pipeline_capsule_validate_utf8(
                    rawHandle,
                    bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    textData.count,
                    &isValid,
                    &error
                )
            }
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
        
        return isValid != 0
    }
}

// MARK: - Convenience Extensions

extension TextPipelineCapsuleWrapper {
    
    /// Normalize text to NFC form.
    /// - Parameter text: Input text to normalize
    /// - Returns: NFC-normalized text
    public func normalizeNFC(_ text: String) throws -> String {
        let textData = text.data(using: .utf8) ?? Data()
        var buffer = anigma_capsule_buffer_t()
        var error = anigma_capsule_error_t()
        
        return try handle?.withHandle { rawHandle in
            // Two-phase buffer operation
            let queryStatus = textData.withUnsafeBytes { bytes in
                anigma_text_pipeline_capsule_normalize_unicode(
                    rawHandle,
                    bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    textData.count,
                    ANIGMA_UNICODE_NFC,
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
            
            let fillStatus = textData.withUnsafeBytes { bytes in
                anigma_text_pipeline_capsule_normalize_unicode(
                    rawHandle,
                    bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    textData.count,
                    ANIGMA_UNICODE_NFC,
                    &buffer,
                    &error
                )
            }
            
            guard fillStatus == ANIGMA_OK else {
                throw CapsuleError(status: fillStatus, error: error)
            }
            
            return String(data: outputData, encoding: .utf8) ?? text
        } ?? text
    }
    
    /// Convert text to lowercase.
    /// - Parameter text: Input text to convert
    /// - Returns: Lowercase text
    public func toLowercase(_ text: String) throws -> String {
        let textData = text.data(using: .utf8) ?? Data()
        var buffer = anigma_capsule_buffer_t()
        var error = anigma_capsule_error_t()
        
        return try handle?.withHandle { rawHandle in
            let queryStatus = textData.withUnsafeBytes { bytes in
                anigma_text_pipeline_capsule_convert_case(
                    rawHandle,
                    bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    textData.count,
                    ANIGMA_CASE_LOWER,
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
            
            let fillStatus = textData.withUnsafeBytes { bytes in
                anigma_text_pipeline_capsule_convert_case(
                    rawHandle,
                    bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    textData.count,
                    ANIGMA_CASE_LOWER,
                    &buffer,
                    &error
                )
            }
            
            guard fillStatus == ANIGMA_OK else {
                throw CapsuleError(status: fillStatus, error: error)
            }
            
            return String(data: outputData, encoding: .utf8) ?? text
        } ?? text
    }
    
    /// Remove diacritics from text.
    /// - Parameter text: Input text to process
    /// - Returns: Text without diacritics
    public func stripDiacritics(_ text: String) throws -> String {
        let textData = text.data(using: .utf8) ?? Data()
        var buffer = anigma_capsule_buffer_t()
        var error = anigma_capsule_error_t()
        
        return try handle?.withHandle { rawHandle in
            let queryStatus = textData.withUnsafeBytes { bytes in
                anigma_text_pipeline_capsule_process_diacritics(
                    rawHandle,
                    bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    textData.count,
                    ANIGMA_DIACRITICS_STRIP,
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
            
            let fillStatus = textData.withUnsafeBytes { bytes in
                anigma_text_pipeline_capsule_process_diacritics(
                    rawHandle,
                    bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    textData.count,
                    ANIGMA_DIACRITICS_STRIP,
                    &buffer,
                    &error
                )
            }
            
            guard fillStatus == ANIGMA_OK else {
                throw CapsuleError(status: fillStatus, error: error)
            }
            
            return String(data: outputData, encoding: .utf8) ?? text
        } ?? text
    }
    
    /// Fold text to ASCII for indexing.
    /// - Parameter text: Input text to fold
    /// - Returns: ASCII-compatible text
    public func foldToASCII(_ text: String) throws -> String {
        let textData = text.data(using: .utf8) ?? Data()
        var buffer = anigma_capsule_buffer_t()
        var error = anigma_capsule_error_t()
        
        return try handle?.withHandle { rawHandle in
            let queryStatus = textData.withUnsafeBytes { bytes in
                anigma_text_pipeline_capsule_fold_to_ascii(
                    rawHandle,
                    bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    textData.count,
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
            
            let fillStatus = textData.withUnsafeBytes { bytes in
                anigma_text_pipeline_capsule_fold_to_ascii(
                    rawHandle,
                    bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    textData.count,
                    &buffer,
                    &error
                )
            }
            
            guard fillStatus == ANIGMA_OK else {
                throw CapsuleError(status: fillStatus, error: error)
            }
            
            return String(data: outputData, encoding: .utf8) ?? text
        } ?? text
    }
}