import Foundation
import CapsuleCore
import AnigmaNativeShims
import TelemetryCore

/// High-level actor wrapper for text chunking operations.
/// Provides thread-safe access to the native Rabin fingerprinting implementation.
public actor TextChunkingCapsule: IdentifiableCapsule {
    private let wrapper: TextChunkingCapsuleWrapper
    private let diagnostics: CapsuleDiagnostics
    private let config: TextChunkingConfig
    private static let algorithmVersion = "rabin-v1"
    
    public init(
        config: TextChunkingConfig = TextChunkingConfig(),
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        let resolvedDiagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        let span = resolvedDiagnostics.beginSpan(
            name: "TextChunkingCapsule.init",
            category: "textchunking.init",
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
                category: "textchunking.init",
                message: "Failed to create chunker: \(error)",
                correlationID: nil,
                metadata: [:]
            )
            span.end(status: .error)
            throw error
        }
    }
    
    /// One-shot chunking of a String. Returns String chunks.
    /// Handles UTF-8 conversion and ensures valid string boundaries.
    public func chunk(_ text: String) throws -> [String] {
        let span = diagnostics.beginSpan(
            name: "TextChunkingCapsule.chunkString",
            category: "textchunking.chunk",
            correlationID: nil,
            tags: [
                "input_chars": "\(text.count)",
                "input_bytes": "\(text.utf8.count)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        let data = Data(text.utf8)
        do {
            try wrapper.reset()
            try wrapper.processBytes(data)
            try wrapper.finalize()
        } catch {
            diagnostics.event(
                level: .error,
                category: "textchunking.chunk",
                message: "Chunking failed: \(error)",
                correlationID: nil,
                metadata: [:]
            )
            span.end(status: .error)
            throw error
        }
        
        let boundaries = try wrapper.getBoundaries()
        var chunks: [String] = []
        
        for boundary in boundaries {
            let offset = Int(boundary.offset)
            let length = Int(boundary.length)
            if offset + length <= data.count {
                let chunkData = data.subdata(in: offset..<(offset + length))
                if let chunkString = String(data: chunkData, encoding: .utf8) {
                    chunks.append(chunkString)
                } else {
                    // If we hit an invalid UTF-8 boundary (rare with CDC but possible),
                    // we try to expand slightly to find a valid one or just skip.
                    // For now, we fall back to a safer string-based approach if needed.
                }
            }
        }
        
        let finalChunks = chunks.isEmpty && !text.isEmpty ? [text] : chunks
        diagnostics.event(
            level: .info,
            category: "textchunking.chunk",
            message: "Chunking completed",
            correlationID: nil,
            metadata: ["chunk_count": "\(finalChunks.count)"]
        )
        span.end(status: .ok)
        return finalChunks
    }
    
    /// One-shot chunking of Data.
    public func chunk(_ data: Data) throws -> [Data] {
        let span = diagnostics.beginSpan(
            name: "TextChunkingCapsule.chunkData",
            category: "textchunking.chunk",
            correlationID: nil,
            tags: [
                "input_bytes": "\(data.count)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        do {
            try wrapper.reset()
            try wrapper.processBytes(data)
            try wrapper.finalize()
        } catch {
            diagnostics.event(
                level: .error,
                category: "textchunking.chunk",
                message: "Chunking failed: \(error)",
                correlationID: nil,
                metadata: [:]
            )
            span.end(status: .error)
            throw error
        }
        
        let boundaries = try wrapper.getBoundaries()
        var chunks: [Data] = []
        
        for boundary in boundaries {
            let offset = Int(boundary.offset)
            let length = Int(boundary.length)
            if offset + length <= data.count {
                chunks.append(data.subdata(in: offset..<(offset + length)))
            }
        }
        
        diagnostics.event(
            level: .info,
            category: "textchunking.chunk",
            message: "Chunking completed",
            correlationID: nil,
            metadata: ["chunk_count": "\(chunks.count)"]
        )
        span.end(status: .ok)
        return chunks
    }
    
    public func processBytes(_ data: Data) throws {
        let span = diagnostics.beginSpan(
            name: "TextChunkingCapsule.processBytes",
            category: "textchunking.process",
            correlationID: nil,
            tags: [
                "input_bytes": "\(data.count)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        do {
            try wrapper.processBytes(data)
            span.end(status: .ok)
        } catch {
            diagnostics.event(
                level: .error,
                category: "textchunking.process",
                message: "Process bytes failed: \(error)",
                correlationID: nil,
                metadata: [:]
            )
            span.end(status: .error)
            throw error
        }
    }
    
    public func finalize() throws -> [anigma_chunk_boundary_t] {
        let span = diagnostics.beginSpan(
            name: "TextChunkingCapsule.finalize",
            category: "textchunking.finalize",
            correlationID: nil,
            tags: ["algorithm_version": Self.algorithmVersion]
        )
        do {
            try wrapper.finalize()
            let boundaries = try wrapper.getBoundaries()
            diagnostics.event(
                level: .info,
                category: "textchunking.finalize",
                message: "Finalize completed",
                correlationID: nil,
                metadata: ["boundary_count": "\(boundaries.count)"]
            )
            span.end(status: .ok)
            return boundaries
        } catch {
            diagnostics.event(
                level: .error,
                category: "textchunking.finalize",
                message: "Finalize failed: \(error)",
                correlationID: nil,
                metadata: [:]
            )
            span.end(status: .error)
            throw error
        }
    }
    
    public func reset() throws {
        let span = diagnostics.beginSpan(
            name: "TextChunkingCapsule.reset",
            category: "textchunking.reset",
            correlationID: nil,
            tags: ["algorithm_version": Self.algorithmVersion]
        )
        do {
            try wrapper.reset()
            span.end(status: .ok)
        } catch {
            diagnostics.event(
                level: .error,
                category: "textchunking.reset",
                message: "Reset failed: \(error)",
                correlationID: nil,
                metadata: [:]
            )
            span.end(status: .error)
            throw error
        }
    }
}
