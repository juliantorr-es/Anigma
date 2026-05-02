import Foundation
import CapsuleCore
import AnigmaNativeShims
import TelemetryCore

fileprivate enum TextPipelineBoundaryMetric {
    static let create = "capsule.textpipeline.create"
    static let normalize = "capsule.textpipeline.normalize"
    static let transform = "capsule.textpipeline.transform"
    static let destroy = "capsule.textpipeline.destroy"
}

public actor TextPipelineCapsuleWrapper: IdentifiableCapsule {
    private let handle: CapsuleHandle<AnyObject>
    private let diagnostics: CapsuleDiagnostics
    private let config: TextPipelineConfig
    private let byteScratchPool = ReusableArrayPool<UInt8>(maxBuffers: 2)
    
    public init(
        config: TextPipelineConfig,
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        let resolvedDiagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        var rawHandle: anigma_text_pipeline_capsule_t? = nil
        var error = anigma_capsule_error_t()

        let span = resolvedDiagnostics.beginSpan(
            name: "TextPipelineCapsuleWrapper.init",
            category: "textpipeline.init",
            correlationID: nil,
            tags: [
                "unicode_form": "\(config.unicodeForm)",
                "case_mode": "\(config.caseMode)",
                "diacritic_mode": "\(config.diacriticMode)",
                "determinism_tier": "\(config.determinismTier)"
            ]
        )
        
        var cConfig = anigma_text_pipeline_config_v2_t()
        cConfig.unicode_form = config.unicodeForm.toNative()
        cConfig.case_mode = config.caseMode.toNative()
        cConfig.diacritic_mode = config.diacriticMode.toNative()
        cConfig.preserve_whitespace = config.preserveWhitespace ? 1 : 0
        cConfig.preserve_line_breaks = config.preserveLineBreaks ? 1 : 0
        cConfig.determinism_tier = UInt32(config.determinismTier)

        CrossLanguageCallMetrics.record(boundary: TextPipelineBoundaryMetric.create)
        let status = anigma_text_pipeline_capsule_create(&cConfig, &rawHandle, &error)
        
        guard status == ANIGMA_OK, let finalHandle = rawHandle else {
            resolvedDiagnostics.event(
                level: .error,
                category: "textpipeline.init",
                message: "Failed to create capsule handle (status: \(status))",
                correlationID: nil,
                metadata: [:]
            )
            span.end(status: .error)
            throw capsuleError(status: status, error: error)
        }

        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: finalHandle,
            destroyFunction: capsuleDestroyer(anigma_text_pipeline_capsule_destroy)
        )
        self.config = config
        self.diagnostics = resolvedDiagnostics
        span.end(status: .ok)
    }
    
    public func normalize(_ text: String, form: UnicodeForm) throws -> String {
        let span = diagnostics.beginSpan(
            name: "TextPipelineCapsuleWrapper.normalize",
            category: "textpipeline.normalize",
            correlationID: nil,
            tags: [
                "input_chars": "\(text.count)",
                "form": "\(form)",
                "locale": Locale.current.identifier
            ]
        )
        var loggedError = false
        var buffer = anigma_capsule_buffer_t()
        var error = anigma_capsule_error_t()
        
        let utf8 = text.utf8
        do {
            CrossLanguageCallMetrics.record(boundary: TextPipelineBoundaryMetric.normalize)
            let status = try handle.withHandle { h in
                utf8.withContiguousStorageIfAvailable { ptr in
                    anigma_text_pipeline_capsule_normalize_unicode(h, ptr.baseAddress, ptr.count, form.toNative(), &buffer, &error)
                } ?? {
                    byteScratchPool.withBuffer(minimumCapacity: utf8.count) { scratch in
                        scratch.append(contentsOf: utf8)
                        return scratch.withUnsafeBytes { ptr in
                            anigma_text_pipeline_capsule_normalize_unicode(h, ptr.baseAddress?.assumingMemoryBound(to: UInt8.self), scratch.count, form.toNative(), &buffer, &error)
                        }
                    }
                }()
            }

            guard status == ANIGMA_OK else {
                loggedError = true
                diagnostics.event(
                    level: .error,
                    category: "textpipeline.normalize",
                    message: "Normalization failed (status: \(status))",
                    correlationID: nil,
                    metadata: [:]
                )
                span.end(status: .error)
                throw capsuleError(status: status, error: error)
            }

            defer { free(buffer.ptr) }
            let normalized = String(decoding: UnsafeRawBufferPointer(start: buffer.ptr, count: buffer.len), as: UTF8.self)
            diagnostics.event(
                level: .info,
                category: "textpipeline.normalize",
                message: "Normalization completed",
                correlationID: nil,
                metadata: ["output_chars": "\(normalized.count)"]
            )
            span.end(status: .ok)
            return normalized
        } catch {
            if !loggedError {
                diagnostics.event(
                    level: .error,
                    category: "textpipeline.normalize",
                    message: "Normalization threw error: \(error)",
                    correlationID: nil,
                    metadata: [:]
                )
            }
            span.end(status: .error)
            throw error
        }
    }
    
    public func transform(_ text: String) throws -> TextPipelineResult {
        let span = diagnostics.beginSpan(
            name: "TextPipelineCapsuleWrapper.transform",
            category: "textpipeline.segment",
            correlationID: nil,
            tags: [
                "input_chars": "\(text.count)",
                "locale": Locale.current.identifier
            ]
        )
        var loggedError = false
        var result = anigma_text_result_v2_t()
        var error = anigma_capsule_error_t()
        
        let utf8 = text.utf8
        do {
            CrossLanguageCallMetrics.record(boundary: TextPipelineBoundaryMetric.transform)
            let status = try handle.withHandle { h in
                utf8.withContiguousStorageIfAvailable { ptr in
                    anigma_text_pipeline_capsule_transform(h, ptr.baseAddress, ptr.count, &result, &error)
                } ?? {
                    byteScratchPool.withBuffer(minimumCapacity: utf8.count) { scratch in
                        scratch.append(contentsOf: utf8)
                        return scratch.withUnsafeBytes { ptr in
                            anigma_text_pipeline_capsule_transform(h, ptr.baseAddress?.assumingMemoryBound(to: UInt8.self), scratch.count, &result, &error)
                        }
                    }
                }()
            }

            guard status == ANIGMA_OK else {
                loggedError = true
                diagnostics.event(
                    level: .error,
                    category: "textpipeline.segment",
                    message: "Transform failed (status: \(status))",
                    correlationID: nil,
                    metadata: [:]
                )
                span.end(status: .error)
                throw capsuleError(status: status, error: error)
            }

            defer {
                free(result.transformed_text)
                free(result.offset_map)
                free(result.boundaries)
            }

            let transformed = String(decoding: UnsafeRawBufferPointer(start: result.transformed_text, count: result.transformed_length), as: UTF8.self)

            let boundaries = UnsafeBufferPointer(start: result.boundaries, count: Int(result.boundary_count)).map { b in
                TextBoundary(type: .init(from: b.type), offset: Int(b.offset), length: Int(b.length), confidence: Double(b.confidence) / 100.0)
            }

            diagnostics.event(
                level: .info,
                category: "textpipeline.segment",
                message: "Segmentation completed",
                correlationID: nil,
                metadata: [
                    "output_chars": "\(transformed.count)",
                    "boundary_count": "\(boundaries.count)"
                ]
            )
            span.end(status: .ok)
            return TextPipelineResult(
                transformedText: transformed,
                boundaries: boundaries
            )
        } catch {
            if !loggedError {
                diagnostics.event(
                    level: .error,
                    category: "textpipeline.segment",
                    message: "Transform threw error: \(error)",
                    correlationID: nil,
                    metadata: [:]
                )
            }
            span.end(status: .error)
            throw error
        }
    }

    /// Transform multiple texts with a single handle checkout.
    /// This keeps the same per-item parity as `transform(_:)` while amortizing
    /// the lock, span, and buffer reuse overhead across the whole batch.
    public func transformBatch(_ texts: [String]) throws -> [TextPipelineResult] {
        guard !texts.isEmpty else { return [] }

        let totalCharacters = texts.reduce(0) { $0 + $1.count }
        let span = diagnostics.beginSpan(
            name: "TextPipelineCapsuleWrapper.transformBatch",
            category: "textpipeline.batch_segment",
            correlationID: nil,
            tags: [
                "batch_size": "\(texts.count)",
                "input_chars": "\(totalCharacters)"
            ]
        )

        do {
            CrossLanguageCallMetrics.record(
                boundary: TextPipelineBoundaryMetric.transform,
                calls: UInt64(texts.count)
            )
            let results = try handle.withHandle { h in
                try texts.enumerated().map { index, text in
                    var result = anigma_text_result_v2_t()
                    var error = anigma_capsule_error_t()
                    defer {
                        free(result.transformed_text)
                        free(result.offset_map)
                        free(result.boundaries)
                    }

                    let status = try withUTF8Bytes(for: text) { bytes, length in
                        anigma_text_pipeline_capsule_transform(
                            h,
                            bytes,
                            length,
                            &result,
                            &error
                        )
                    }

                    guard status == ANIGMA_OK else {
                        diagnostics.event(
                            level: .error,
                            category: "textpipeline.batch_segment",
                            message: "Batch transform failed at index \(index) (status: \(status))",
                            correlationID: nil,
                            metadata: [
                                "batch_size": "\(texts.count)",
                                "input_chars": "\(text.count)"
                            ]
                        )
                        throw capsuleError(status: status, error: error)
                    }

                    return decodeTransformResult(result)
                }
            }

            diagnostics.event(
                level: .info,
                category: "textpipeline.batch_segment",
                message: "Batch transformation completed",
                correlationID: nil,
                metadata: [
                    "batch_size": "\(texts.count)",
                    "total_input_chars": "\(totalCharacters)"
                ]
            )
            span.end(status: .ok)
            return results
        } catch {
            span.end(status: .error)
            throw error
        }
    }

    /// Normalize multiple texts with a single handle checkout.
    public func normalizeBatch(_ texts: [String], form: UnicodeForm) throws -> [String] {
        guard !texts.isEmpty else { return [] }

        let totalCharacters = texts.reduce(0) { $0 + $1.count }
        let span = diagnostics.beginSpan(
            name: "TextPipelineCapsuleWrapper.normalizeBatch",
            category: "textpipeline.batch_normalize",
            correlationID: nil,
            tags: [
                "batch_size": "\(texts.count)",
                "input_chars": "\(totalCharacters)",
                "form": "\(form)"
            ]
        )

        do {
            CrossLanguageCallMetrics.record(
                boundary: TextPipelineBoundaryMetric.normalize,
                calls: UInt64(texts.count)
            )
            let normalized = try handle.withHandle { h in
                try texts.enumerated().map { index, text in
                    var buffer = anigma_capsule_buffer_t()
                    var error = anigma_capsule_error_t()
                    defer { free(buffer.ptr) }

                    let status = try withUTF8Bytes(for: text) { bytes, length in
                        anigma_text_pipeline_capsule_normalize_unicode(
                            h,
                            bytes,
                            length,
                            form.toNative(),
                            &buffer,
                            &error
                        )
                    }

                    guard status == ANIGMA_OK else {
                        diagnostics.event(
                            level: .error,
                            category: "textpipeline.batch_normalize",
                            message: "Batch normalization failed at index \(index) (status: \(status))",
                            correlationID: nil,
                            metadata: [
                                "batch_size": "\(texts.count)",
                                "input_chars": "\(text.count)"
                            ]
                        )
                        throw capsuleError(status: status, error: error)
                    }

                    return String(
                        decoding: UnsafeRawBufferPointer(start: buffer.ptr, count: buffer.len),
                        as: UTF8.self
                    )
                }
            }

            diagnostics.event(
                level: .info,
                category: "textpipeline.batch_normalize",
                message: "Batch normalization completed",
                correlationID: nil,
                metadata: [
                    "batch_size": "\(texts.count)",
                    "total_input_chars": "\(totalCharacters)"
                ]
            )
            span.end(status: .ok)
            return normalized
        } catch {
            span.end(status: .error)
            throw error
        }
    }

    private func withUTF8Bytes<R>(
        for text: String,
        _ body: (UnsafePointer<UInt8>?, Int) throws -> R
    ) rethrows -> R {
        let utf8 = text.utf8
        if let result = try utf8.withContiguousStorageIfAvailable({ storage in
            try body(storage.baseAddress, storage.count)
        }) {
            return result
        }

        return try byteScratchPool.withBuffer(minimumCapacity: utf8.count) { scratch in
            scratch.append(contentsOf: utf8)
            return try scratch.withUnsafeBytes { rawBuffer in
                try body(
                    rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    scratch.count
                )
            }
        }
    }

    private func decodeTransformResult(_ result: anigma_text_result_v2_t) -> TextPipelineResult {
        let transformed = String(
            decoding: UnsafeRawBufferPointer(
                start: result.transformed_text,
                count: result.transformed_length
            ),
            as: UTF8.self
        )

        let boundaries = UnsafeBufferPointer(start: result.boundaries, count: Int(result.boundary_count)).map { boundary in
            TextBoundary(
                type: .init(from: boundary.type),
                offset: Int(boundary.offset),
                length: Int(boundary.length),
                confidence: Double(boundary.confidence) / 100.0
            )
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

private func capsuleError(status: anigma_status_t, error: anigma_capsule_error_t) -> CapsuleNativeError {
    let message = error.message.map { String(cString: $0) } ?? "Capsule error"
    return CapsuleNativeError(status: status, code: error.code, message: message)
}

private func capsuleDestroyer(
    _ destroy: @escaping (UnsafeMutableRawPointer, UnsafeMutablePointer<anigma_capsule_error_t>) -> anigma_status_t
) -> (UnsafeMutableRawPointer) -> Void {
    { ptr in
        CrossLanguageCallMetrics.record(boundary: TextPipelineBoundaryMetric.destroy)
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
