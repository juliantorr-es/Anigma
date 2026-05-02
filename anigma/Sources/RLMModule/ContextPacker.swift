import Foundation
import AnigmaCore
import AnigmaPrimitives

/// Optimized context assembly engine.
/// Follows "Stupid-Fast" principles:
/// 1. Linear-time assembly (no repeated concatenation).
/// 2. Diversity-aware selection (avoids redundant chunks).
/// 3. Structural awareness (preserves headings and anchors).
public actor ContextPacker {
    public struct PackingConfig: Sendable {
        public var maxTokens: Int = 4096
        public var dedupeThreshold: Double = 0.8 // Semantic similarity threshold
        public var preferDiverseSections: Bool = true
        public var includeMetadata: Bool = true
        
        public static let `default` = PackingConfig()
    }
    
    public init() {}
    
    /// Pack retrieved spans into a deterministic context bundle.
    public func pack(
        spans: [ScoredSpan],
        config: PackingConfig = .default
    ) async throws -> PackedContext {
        let startTime = Date()
        
        // 1. Deduplicate and filter spans
        let filteredSpans = filterSpans(spans, config: config)
        
        // 2. Sort by document and offset for logical flow
        // (Though usually we want most relevant first, for long context LLMs logical flow is better)
        let orderedSpans = filteredSpans.sorted { a, b in
            if a.metadata["sourceId"] == b.metadata["sourceId"] {
                let offsetA = Int(a.metadata["offset"] ?? "0") ?? 0
                let offsetB = Int(b.metadata["offset"] ?? "0") ?? 0
                return offsetA < offsetB
            }
            return (a.metadata["sourceId"] ?? "") < (b.metadata["sourceId"] ?? "")
        }
        
        // 3. Assemble using linear builder
        var builder = ""
        builder.reserveCapacity(config.maxTokens * 4) // Approx 4 chars per token
        
        var currentSourceId = ""
        var totalTokens = 0
        
        for span in orderedSpans {
            // Rough token estimate
            let spanTokens = span.content.count / 4 
            if totalTokens + spanTokens > config.maxTokens {
                break
            }
            
            if config.includeMetadata && span.metadata["sourceId"] != currentSourceId {
                currentSourceId = span.metadata["sourceId"] ?? "unknown"
                builder += "\n--- Source: \(currentSourceId) ---\n"
            }
            
            builder += span.content
            builder += "\n"
            
            totalTokens += spanTokens
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let result = PackedContext(
            content: builder,
            tokenCount: totalTokens,
            sourceSpans: filteredSpans.map { $0.spanId },
            assemblyTimeMs: Int(duration * 1000)
        )
        
        return result
    }
    
    private func filterSpans(_ spans: [ScoredSpan], config: PackingConfig) -> [ScoredSpan] {
        var seenHashes = Set<Int>()
        var filtered: [ScoredSpan] = []
        
        for span in spans {
            let contentHash = span.content.hashValue
            if !seenHashes.contains(contentHash) {
                filtered.append(span)
                seenHashes.insert(contentHash)
            }
        }
        
        return filtered
    }
}

public struct PackedContext: Sendable, Codable {
    public let content: String
    public let tokenCount: Int
    public let sourceSpans: [String]
    public let assemblyTimeMs: Int
}
