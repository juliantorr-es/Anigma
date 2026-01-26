import Foundation
import AnigmaNativeShims
import CapsuleCore
import TelemetryCore

/// Low-level wrapper for the native text chunking capsule.
public final class TextChunkingCapsuleWrapper {
    private let handle: CapsuleHandle<AnyObject>
    private let diagnostics: CapsuleDiagnostics
    private static let algorithmVersion = "rabin-v1"
    
    public init(
        config: TextChunkingConfig,
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        let resolvedDiagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        self.diagnostics = resolvedDiagnostics
        var rawHandle: anigma_text_chunking_capsule_t?
        var error = anigma_capsule_error_t()
        
        var cConfig = anigma_text_chunking_config_t()
        cConfig.target_chunk_size = Int(config.targetChunkSize)
        cConfig.min_chunk_size = Int(config.minChunkSize)
        cConfig.max_chunk_size = Int(config.maxChunkSize)
        cConfig.window_size = Int(config.windowSize)
        cConfig.polynomial = config.polynomial
        cConfig.determinism_tier = config.determinismTier
        
        let status = anigma_text_chunking_capsule_create(&cConfig, &rawHandle, &error)
        guard status == ANIGMA_OK, let finalHandle = rawHandle else {
            resolvedDiagnostics.event(
                level: .error,
                category: "textchunking.init",
                message: "Failed to create native handle (status: \(status))",
                correlationID: nil,
                tags: ["algorithm_version": Self.algorithmVersion]
            )
            throw capsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: finalHandle,
            destroyFunction: capsuleDestroyer(anigma_text_chunking_capsule_destroy)
        )
    }
    
    public func processBytes(_ data: Data) throws {
        let span = diagnostics.beginSpan(
            name: "TextChunkingCapsuleWrapper.processBytes",
            category: "textchunking.native.process",
            correlationID: nil,
            tags: [
                "input_bytes": "\(data.count)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        var error = anigma_capsule_error_t()
        try handle.withHandle { rawHandle in
            let status = data.withUnsafeBytes { bytes in
                anigma_text_chunking_capsule_process_bytes(
                    rawHandle,
                    bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    &error
                )
            }
            guard status == ANIGMA_OK else {
                diagnostics.event(
                    level: .error,
                    category: "textchunking.native.process",
                    message: "Native process failed (status: \(status))",
                    correlationID: nil,
                    tags: [:]
                )
                span.end(status: .error)
                throw capsuleError(status: status, error: error)
            }
        }
        span.end(status: .ok)
    }
    
    public func finalize() throws {
        let span = diagnostics.beginSpan(
            name: "TextChunkingCapsuleWrapper.finalize",
            category: "textchunking.native.finalize",
            correlationID: nil,
            tags: ["algorithm_version": Self.algorithmVersion]
        )
        var error = anigma_capsule_error_t()
        try handle.withHandle { rawHandle in
            let status = anigma_text_chunking_capsule_finalize(rawHandle, &error)
            guard status == ANIGMA_OK else {
                diagnostics.event(
                    level: .error,
                    category: "textchunking.native.finalize",
                    message: "Native finalize failed (status: \(status))",
                    correlationID: nil,
                    tags: [:]
                )
                span.end(status: .error)
                throw capsuleError(status: status, error: error)
            }
        }
        span.end(status: .ok)
    }
    
    public func reset() throws {
        let span = diagnostics.beginSpan(
            name: "TextChunkingCapsuleWrapper.reset",
            category: "textchunking.native.reset",
            correlationID: nil,
            tags: ["algorithm_version": Self.algorithmVersion]
        )
        var error = anigma_capsule_error_t()
        try handle.withHandle { rawHandle in
            let status = anigma_text_chunking_capsule_reset(rawHandle, &error)
            guard status == ANIGMA_OK else {
                diagnostics.event(
                    level: .error,
                    category: "textchunking.native.reset",
                    message: "Native reset failed (status: \(status))",
                    correlationID: nil,
                    tags: [:]
                )
                span.end(status: .error)
                throw capsuleError(status: status, error: error)
            }
        }
        span.end(status: .ok)
    }
    
    public func getBoundaries() throws -> [anigma_chunk_boundary_t] {
        let span = diagnostics.beginSpan(
            name: "TextChunkingCapsuleWrapper.getBoundaries",
            category: "textchunking.native.boundaries",
            correlationID: nil,
            tags: ["algorithm_version": Self.algorithmVersion]
        )
        var error = anigma_capsule_error_t()
        do {
            let boundaries = try handle.withHandle { rawHandle in
            var count: Int = 0
            let countStatus = anigma_text_chunking_capsule_get_boundary_count(rawHandle, &count, &error)
            guard countStatus == ANIGMA_OK else {
                diagnostics.event(
                    level: .error,
                    category: "textchunking.native.boundaries",
                    message: "Boundary count failed (status: \(countStatus))",
                    correlationID: nil,
                    tags: [:]
                )
                span.end(status: .error)
                throw capsuleError(status: countStatus, error: error)
            }
            
            var boundaries = [anigma_chunk_boundary_t](repeating: anigma_chunk_boundary_t(), count: count)
            var actual: Int = 0
            let getStatus = anigma_text_chunking_capsule_get_chunk_info(rawHandle, &boundaries, count, &actual, &error)
            guard getStatus == ANIGMA_OK else {
                diagnostics.event(
                    level: .error,
                    category: "textchunking.native.boundaries",
                    message: "Boundary fetch failed (status: \(getStatus))",
                    correlationID: nil,
                    tags: [:]
                )
                span.end(status: .error)
                throw capsuleError(status: getStatus, error: error)
            }

                return Array(boundaries.prefix(actual))
            }
            span.end(status: .ok)
            return boundaries
        } catch {
            diagnostics.event(
                level: .error,
                category: "textchunking.native.boundaries",
                message: "Boundary read failed: \(error)",
                correlationID: nil,
                tags: [:]
            )
            span.end(status: .error)
            throw error
        }
    }
    
    public func extractChunks(from data: Data) async throws -> [Data] {
        // Simple extraction based on boundaries
        let boundaries = try getBoundaries()
        var chunks: [Data] = []
        var lastOffset = 0
        
        for boundary in boundaries {
            let offset = Int(boundary.offset)
            if offset > lastOffset && offset <= data.count {
                chunks.append(data.subdata(in: lastOffset..<offset))
                lastOffset = offset
            }
        }
        
        if lastOffset < data.count {
            chunks.append(data.subdata(in: lastOffset..<data.count))
        }
        
        return chunks
    }
}

private func capsuleError(status: anigma_status_t, error: anigma_capsule_error_t) -> CapsuleNativeError {
    let message = error.message.map { String(cString: $0) } ?? "Capsule error"
    return CapsuleNativeError(status: status, code: error.code, message: message)
}

private func capsuleDestroyer(
    _ destroy: @escaping (UnsafeMutableRawPointer, UnsafeMutablePointer<anigma_capsule_error_t>) -> anigma_status_t
) -> (UnsafeMutableRawPointer) -> Void {
    { ptr in
        var err = anigma_capsule_error_t()
        _ = destroy(ptr, &err)
    }
}
