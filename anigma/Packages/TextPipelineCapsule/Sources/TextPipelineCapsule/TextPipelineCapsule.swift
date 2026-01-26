import Foundation
import CapsuleCore
import TextPipelineNative
import AnigmaNativeShims

public actor TextPipelineCapsule: IdentifiableCapsule {
    private let handle: CapsuleHandle<AnyObject>
    
    public init(config: TextPipelineConfig) throws {
        var rawHandle: anigma_text_pipeline_capsule_t? = nil
        var error = anigma_capsule_error_t()
        
        var cConfig = anigma_text_pipeline_config_v2_t()
        cConfig.unicode_form = config.unicodeForm.toNative()
        cConfig.case_mode = config.caseMode.toNative()
        cConfig.diacritic_mode = config.diacriticMode.toNative()
        cConfig.preserve_whitespace = config.preserveWhitespace ? 1 : 0
        cConfig.preserve_line_breaks = config.preserveLineBreaks ? 1 : 0
        cConfig.determinism_tier = UInt32(config.determinismTier)

        let status = anigma_text_pipeline_capsule_create(&cConfig, &rawHandle, &error)
        
        guard status == ANIGMA_OK, let finalHandle = rawHandle else {
            throw capsuleError(status: status, error: error)
        }

        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: finalHandle,
            destroyFunction: capsuleDestroyer(anigma_text_pipeline_capsule_destroy)
        )
    }
    
    public func normalize(_ text: String, form: UnicodeForm) throws -> String {
        var buffer = anigma_capsule_buffer_t()
        var error = anigma_capsule_error_t()
        
        let utf8 = text.utf8
        let status = try handle.withHandle { h in
            utf8.withContiguousStorageIfAvailable { ptr in
                anigma_text_pipeline_capsule_normalize_unicode(h, ptr.baseAddress, ptr.count, form.toNative(), &buffer, &error)
            } ?? {
                let array = Array(utf8)
                return array.withUnsafeBytes { ptr in
                    anigma_text_pipeline_capsule_normalize_unicode(h, ptr.baseAddress?.assumingMemoryBound(to: UInt8.self), array.count, form.toNative(), &buffer, &error)
                }
            }()
        }

        guard status == ANIGMA_OK else {
            throw capsuleError(status: status, error: error)
        }
        
        defer { free(buffer.ptr) }
        return String(decoding: UnsafeRawBufferPointer(start: buffer.ptr, count: buffer.len), as: UTF8.self)
    }
    
    public func transform(_ text: String) throws -> TextPipelineResult {
        var result = anigma_text_result_v2_t()
        var error = anigma_capsule_error_t()
        
        let utf8 = text.utf8
        let status = try handle.withHandle { h in
            utf8.withContiguousStorageIfAvailable { ptr in
                anigma_text_pipeline_capsule_transform(h, ptr.baseAddress, ptr.count, &result, &error)
            } ?? {
                let array = Array(utf8)
                return array.withUnsafeBytes { ptr in
                    anigma_text_pipeline_capsule_transform(h, ptr.baseAddress?.assumingMemoryBound(to: UInt8.self), array.count, &result, &error)
                }
            }()
        }

        guard status == ANIGMA_OK else {
            throw capsuleError(status: status, error: error)
        }
        
        defer {
            free(result.transformed_text)
            free(result.boundaries)
        }
        
        let transformed = String(decoding: UnsafeRawBufferPointer(start: result.transformed_text, count: result.transformed_length), as: UTF8.self)
        
        let boundaries = UnsafeBufferPointer(start: result.boundaries, count: Int(result.boundary_count)).map { b in
            TextBoundary(type: .init(from: b.type), offset: Int(b.offset), length: Int(b.length), confidence: Double(b.confidence) / 100.0)
        }
        
        return TextPipelineResult(
            transformedText: transformed,
            boundaries: boundaries
        )
    }
}

public struct TextPipelineResult: Sendable {
    public let transformedText: String
    public let boundaries: [TextBoundary]
}

public struct TextBoundary: Sendable {
    public enum BoundaryType: Sendable {
        case grapheme, word, sentence, line
        
        init(from native: anigma_text_boundary_type_t) {
            switch native {
            case ANIGMA_BOUNDARY_GRAPHEME: self = .grapheme
            case ANIGMA_BOUNDARY_WORD: self = .word
            case ANIGMA_BOUNDARY_SENTENCE: self = .sentence
            case ANIGMA_BOUNDARY_LINE: self = .line
            default: self = .grapheme
            }
        }
    }
    
    public let type: BoundaryType
    public let offset: Int
    public let length: Int
    public let confidence: Double
}

private func capsuleError(status: anigma_status_t, error: anigma_capsule_error_t) -> CapsuleError {
    let message = error.message.map { String(cString: $0) } ?? "Capsule error"
    return CapsuleError(status: status, code: error.code, message: message)
}

private func capsuleDestroyer(
    _ destroy: @escaping (UnsafeMutableRawPointer, UnsafeMutablePointer<anigma_capsule_error_t>) -> anigma_status_t
) -> (UnsafeMutableRawPointer) -> Void {
    { ptr in
        var err = anigma_capsule_error_t()
        _ = destroy(ptr, &err)
    }
}

extension UnicodeForm {
    func toNative() -> anigma_unicode_form_t {
        switch self {
        case .none: return ANIGMA_UNICODE_NONE
        case .nfc: return ANIGMA_UNICODE_NFC
        case .nfd: return ANIGMA_UNICODE_NFD
        case .nfkc: return ANIGMA_UNICODE_NFKC
        case .nfkd: return ANIGMA_UNICODE_NFKD
        }
    }
}

extension CaseMode {
    func toNative() -> anigma_case_mode_t {
        switch self {
        case .none: return ANIGMA_CASE_NONE
        case .lower: return ANIGMA_CASE_LOWER
        case .upper: return ANIGMA_CASE_UPPER
        case .title: return ANIGMA_CASE_TITLE
        case .fold: return ANIGMA_CASE_FOLD
        }
    }
}

extension DiacriticMode {
    func toNative() -> anigma_diacritic_mode_t {
        switch self {
        case .keep: return ANIGMA_DIACRITICS_KEEP
        case .strip: return ANIGMA_DIACRITICS_STRIP
        case .normalize: return ANIGMA_DIACRITICS_NORMALIZE
        }
    }
}
