import Foundation
import TelemetryCore

/// Extension to DocumentIRSerialization for emitting diagnostic spans
public extension DocumentIRSerialization {
    
    /// Encode node to JSON data with diagnostic span
    static func encodeToJSONWithDiagnostics(
        _ node: DocumentIRNode,
        diagnostics: CapsuleDiagnostics,
        correlationID: String? = nil
    ) throws -> Data {
        let span = diagnostics.beginSpan(
            name: "DocumentIRSerialization.encodeToJSON",
            category: "serialization",
            correlationID: correlationID,
            tags: ["node_type": "\(type(of: node))"]
        )
        
        do {
            let result = try encodeToJSON(node)
            
            diagnostics.event(
                level: .debug,
                category: "documentir.serialization",
                message: "Successfully encoded DocumentIR node to JSON",
                correlationID: correlationID,
                metadata: ["data_size": "\(result.count) bytes"]
            )
            
            span.end(status: .ok)
            return result
        } catch {
            diagnostics.event(
                level: .error,
                category: "documentir.serialization",
                message: "Failed to encode DocumentIR node to JSON: \(error)",
                correlationID: correlationID,
                metadata: ["error": "\(error)"]
            )
            
            span.end(status: .error)
            throw error
        }
    }
    
    /// Decode node from JSON data with diagnostic span
    static func decodeFromJSONWithDiagnostics(
        _ data: Data,
        diagnostics: CapsuleDiagnostics,
        correlationID: String? = nil
    ) throws -> DocumentIRNode {
        let span = diagnostics.beginSpan(
            name: "DocumentIRSerialization.decodeFromJSON",
            category: "serialization",
            correlationID: correlationID,
            tags: ["data_size": "\(data.count) bytes"]
        )
        
        do {
            let result = try decodeFromJSON(data)
            
            diagnostics.event(
                level: .debug,
                category: "documentir.serialization",
                message: "Successfully decoded DocumentIR node from JSON",
                correlationID: correlationID,
                metadata: ["node_type": "\(type(of: result))"]
            )
            
            span.end(status: .ok)
            return result
        } catch {
            diagnostics.event(
                level: .error,
                category: "documentir.serialization",
                message: "Failed to decode DocumentIR node from JSON: \(error)",
                correlationID: correlationID,
                metadata: ["error": "\(error)"]
            )
            
            span.end(status: .error)
            throw error
        }
    }
    
    /// Traverse document tree with diagnostic span
    static func traverseWithDiagnostics(
        _ node: DocumentIRNode,
        visitor: DocumentIRVisitor,
        diagnostics: CapsuleDiagnostics,
        correlationID: String? = nil
    ) {
        let span = diagnostics.beginSpan(
            name: "DocumentIRTraversal.traverseDepthFirst",
            category: "traversal",
            correlationID: correlationID,
            tags: ["visitor_type": "\(type(of: visitor))"]
        )
        
        let traversal = DocumentIRTraversal(visitor: visitor)
        traversal.traverseDepthFirst(node)
        
        diagnostics.event(
            level: .debug,
            category: "documentir.traversal",
            message: "Document tree traversal completed",
            correlationID: correlationID,
            metadata: ["visitor": "\(type(of: visitor))"]
        )
        
        span.end(status: .ok)
    }
    
    /// Extract text with diagnostic span
    static func extractTextWithDiagnostics(
        _ node: DocumentIRNode,
        diagnostics: CapsuleDiagnostics,
        correlationID: String? = nil
    ) -> String {
        let span = diagnostics.beginSpan(
            name: "DocumentIRSerialization.extractText",
            category: "extraction",
            correlationID: correlationID,
            tags: ["operation": "text"]
        )
        
        let result = extractText(node)
        
        diagnostics.event(
            level: .debug,
            category: "documentir.extraction",
            message: "Text extraction completed",
            correlationID: correlationID,
            metadata: ["text_length": "\(result.count)"]
        )
        
        span.end(status: .ok)
        return result
    }
    
    /// Extract images with diagnostic span
    static func extractImagesWithDiagnostics(
        _ node: DocumentIRNode,
        diagnostics: CapsuleDiagnostics,
        correlationID: String? = nil
    ) -> [DocumentIRNode.Image] {
        let span = diagnostics.beginSpan(
            name: "DocumentIRSerialization.extractImages",
            category: "extraction",
            correlationID: correlationID,
            tags: ["operation": "images"]
        )
        
        let result = extractImages(node)
        
        diagnostics.event(
            level: .debug,
            category: "documentir.extraction",
            message: "Image extraction completed",
            correlationID: correlationID,
            metadata: ["image_count": "\(result.count)"]
        )
        
        span.end(status: .ok)
        return result
    }
    
    /// Extract links with diagnostic span
    static func extractLinksWithDiagnostics(
        _ node: DocumentIRNode,
        diagnostics: CapsuleDiagnostics,
        correlationID: String? = nil
    ) -> [DocumentIRNode.Link] {
        let span = diagnostics.beginSpan(
            name: "DocumentIRSerialization.extractLinks",
            category: "extraction",
            correlationID: correlationID,
            tags: ["operation": "links"]
        )
        
        let result = extractLinks(node)
        
        diagnostics.event(
            level: .debug,
            category: "documentir.extraction",
            message: "Link extraction completed",
            correlationID: correlationID,
            metadata: ["link_count": "\(result.count)"]
        )
        
        span.end(status: .ok)
        return result
    }
    
    /// Extract code blocks with diagnostic span
    static func extractCodeBlocksWithDiagnostics(
        _ node: DocumentIRNode,
        diagnostics: CapsuleDiagnostics,
        correlationID: String? = nil
    ) -> [DocumentIRNode.CodeBlock] {
        let span = diagnostics.beginSpan(
            name: "DocumentIRSerialization.extractCodeBlocks",
            category: "extraction",
            correlationID: correlationID,
            tags: ["operation": "code_blocks"]
        )
        
        let result = extractCodeBlocks(node)
        
        diagnostics.event(
            level: .debug,
            category: "documentir.extraction",
            message: "Code block extraction completed",
            correlationID: correlationID,
            metadata: ["code_block_count": "\(result.count)"]
        )
        
        span.end(status: .ok)
        return result
    }
    
    /// Count node types with diagnostic span
    static func countNodeTypesWithDiagnostics(
        _ node: DocumentIRNode,
        diagnostics: CapsuleDiagnostics,
        correlationID: String? = nil
    ) -> [String: Int] {
        let span = diagnostics.beginSpan(
            name: "DocumentIRSerialization.countNodeTypes",
            category: "analysis",
            correlationID: correlationID,
            tags: ["operation": "count_types"]
        )
        
        let result = countNodeTypes(node)
        let totalNodes = result.values.reduce(0, +)
        
        diagnostics.event(
            level: .debug,
            category: "documentir.analysis",
            message: "Node type counting completed",
            correlationID: correlationID,
            metadata: [
                "total_nodes": "\(totalNodes)",
                "node_types": "\(result.keys.count)"
            ]
        )
        
        span.end(status: .ok)
        return result
    }
}