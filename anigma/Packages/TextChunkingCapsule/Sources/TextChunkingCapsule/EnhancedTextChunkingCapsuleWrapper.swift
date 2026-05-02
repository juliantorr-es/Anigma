import Foundation
import AnigmaNativeShims
import CapsuleCore
import TelemetryCore
import AnigmaPrimitives

public final class EnhancedTextChunkingCapsuleWrapper {
    private let wrapper: TextChunkingCapsuleWrapper
    private let diagnostics: CapsuleDiagnostics
    private let config: TextChunkingConfig
    private static let algorithmVersion = "rabin-v1"

    public init(
        config: TextChunkingConfig,
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        let resolvedDiagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        let span = resolvedDiagnostics.beginSpan(
            name: "EnhancedTextChunkingCapsuleWrapper.init",
            category: "textchunking.enhanced.init",
            correlationID: nil,
            tags: [
                "target_chunk": "\(config.targetChunkSize)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        do {
            self.wrapper = try TextChunkingCapsuleWrapper(config: config, diagnostics: resolvedDiagnostics)
            self.config = config
            self.diagnostics = resolvedDiagnostics
            span.end(status: .ok)
        } catch {
            resolvedDiagnostics.event(
                level: .error,
                category: "textchunking.enhanced.init",
                message: "Failed to create enhanced chunker: \(error)",
                correlationID: nil,
                metadata: [:]
            )
            span.end(status: .error)
            throw error
        }
    }

    public func chunk(_ data: Data, documentId: String) throws -> [EnhancedChunkBoundary] {
        let span = diagnostics.beginSpan(
            name: "EnhancedTextChunkingCapsuleWrapper.chunk",
            category: "textchunking.enhanced.chunk",
            correlationID: nil,
            tags: [
                "input_bytes": "\(data.count)",
                "document_id": documentId,
                "algorithm_version": Self.algorithmVersion
            ]
        )

        guard !documentId.isEmpty else {
            diagnostics.event(
                level: .error,
                category: "textchunking.enhanced.chunk",
                message: "Document ID is required",
                correlationID: nil,
                metadata: [:]
            )
            span.end(status: .error)
            throw CapsuleError.invalidInput(field: "documentId", constraint: "must not be empty")
        }

        guard !data.isEmpty else {
            span.end(status: .ok)
            return []
        }

        do {
            try wrapper.reset()
            try wrapper.processBytes(data)
            try wrapper.finalize()
        } catch {
            diagnostics.event(
                level: .error,
                category: "textchunking.enhanced.chunk",
                message: "Chunking failed: \(error)",
                correlationID: nil,
                metadata: [:]
            )
            span.end(status: .error)
            throw error
        }

        let boundaries: [anigma_chunk_boundary_t]
        do {
            boundaries = try wrapper.getBoundaries()
        } catch {
            diagnostics.event(
                level: .error,
                category: "textchunking.enhanced.chunk",
                message: "Failed to read boundaries: \(error)",
                correlationID: nil,
                metadata: [:]
            )
            span.end(status: .error)
            throw error
        }
        let normalizedBoundaries: [anigma_chunk_boundary_t]
        if boundaries.isEmpty {
            var fallback = anigma_chunk_boundary_t()
            fallback.offset = 0
            fallback.length = UInt64(data.count)
            normalizedBoundaries = [fallback]
        } else {
            normalizedBoundaries = boundaries
        }

        var results: [EnhancedChunkBoundary] = []
        for boundary in normalizedBoundaries {
            let offset = Int(boundary.offset)
            let length = Int(boundary.length)
            guard offset >= 0, length > 0, offset + length <= data.count else {
                diagnostics.event(
                    level: .warning,
                    category: "textchunking.enhanced.chunk",
                    message: "Skipping invalid boundary",
                    correlationID: nil,
                    metadata: [
                        "offset": "\(offset)",
                        "length": "\(length)",
                        "data_size": "\(data.count)"
                    ]
                )
                continue
            }

            let chunkData = data.subdata(in: offset..<(offset + length))
            var idData = Data(documentId.utf8)
            idData.append(0x1f)
            idData.append(chunkData)
            let stableId = BLAKE3Digest.hex(of: idData)
            results.append(
                EnhancedChunkBoundary(
                    offset: offset,
                    length: length,
                    stableId: stableId
                )
            )
        }

        diagnostics.event(
            level: .info,
            category: "textchunking.enhanced.chunk",
            message: "Enhanced chunking completed",
            correlationID: nil,
            metadata: [
                "chunk_count": "\(results.count)",
                "target_chunk": "\(config.targetChunkSize)"
            ]
        )
        span.end(status: .ok)
        return results
    }
}

public struct EnhancedChunkBoundary: Sendable, Codable {
    public let offset: Int
    public let length: Int
    public let stableId: String
}

public enum UnicodeForm: UInt32 {
    case none = 0
    case nfc = 1
}
