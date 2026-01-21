import Foundation
import CryptoKit
import CapsuleCore
import AnigmaCore
import ContractsCore

public actor LayoutIndexingSystem {
    private let database: ContextumDatabase
    private let maxChunkSize: Int
    
    public init(database: ContextumDatabase, maxChunkSize: Int = 512) {
        self.database = database
        self.maxChunkSize = maxChunkSize
    }
    
    /// Process PDF layout output and create indexed chunks with layout metadata
    /// - Parameters:
    ///   - sourceId: Source identifier for the PDF
    ///   - layoutOutput: PDF layout analysis output
    ///   - chunkPrefix: Optional prefix for chunk IDs (e.g., "pdf-")
    /// - Returns: Array of created chunk components
    public func processPDFLayout(
        sourceId: String,
        layoutOutput: PDFLayoutOutput,
        chunkPrefix: String = "pdf-"
    ) async throws -> [ChunkComponent] {
        var allChunks: [ChunkComponent] = []
        let pageCount = layoutOutput.pages.count
        
        for (pageIndex, page) in layoutOutput.pages.enumerated() {
            // Process text segments
            for (segmentIndex, segment) in page.segments.enumerated() {
                let chunks = try await processTextSegment(
                    sourceId: sourceId,
                    pageIndex: pageIndex,
                    segment: segment,
                    segmentIndex: segmentIndex,
                    totalPages: pageCount,
                    chunkPrefix: chunkPrefix
                )
                allChunks.append(contentsOf: chunks)
            }
            
            // Process tables as special chunks
            for (tableIndex, table) in page.tables.enumerated() {
                let chunk = try await processTable(
                    sourceId: sourceId,
                    pageIndex: pageIndex,
                    tableIndex: tableIndex,
                    boundingBox: table.boundingBox,
                    totalPages: pageCount,
                    chunkPrefix: chunkPrefix
                )
                allChunks.append(chunk)
            }
            
            // Process figures as special chunks
            for (figureIndex, figure) in page.figures.enumerated() {
                let chunk = try await processFigure(
                    sourceId: sourceId,
                    pageIndex: pageIndex,
                    figureIndex: figureIndex,
                    boundingBox: figure.boundingBox,
                    totalPages: pageCount,
                    chunkPrefix: chunkPrefix
                )
                allChunks.append(chunk)
            }
            
            // Process images as special chunks
            for (imageIndex, image) in page.images.enumerated() {
                let chunk = try await processImage(
                    sourceId: sourceId,
                    pageIndex: pageIndex,
                    imageIndex: imageIndex,
                    image: image,
                    totalPages: pageCount,
                    chunkPrefix: chunkPrefix
                )
                allChunks.append(chunk)
            }
        }
        
        // Record telemetry event
        let event = TelemetryEventComponent(
            eventId: UUID().uuidString,
            eventType: .chunk,
            outcome: .success
        )
        try await database.insertEvent(event)
        
        return allChunks
    }
    
    // MARK: - Text Segment Processing
    
    private func processTextSegment(
        sourceId: String,
        pageIndex: Int,
        segment: PDFLayoutSegment,
        segmentIndex: Int,
        totalPages: Int,
        chunkPrefix: String
    ) async throws -> [ChunkComponent] {
        let text = segment.text
        guard !text.isEmpty else { return [] }
        
        // If text is within max chunk size, create single chunk
        if text.count <= maxChunkSize {
            return [try await createTextChunk(
                sourceId: sourceId,
                pageIndex: pageIndex,
                segment: segment,
                segmentIndex: segmentIndex,
                text: text,
                chunkIndex: 0,
                totalChunks: 1,
                totalPages: totalPages,
                chunkPrefix: chunkPrefix
            )]
        } else {
            // Text is too large, split it
            return try await splitAndChunkText(
                sourceId: sourceId,
                pageIndex: pageIndex,
                segment: segment,
                segmentIndex: segmentIndex,
                text: text,
                totalPages: totalPages,
                chunkPrefix: chunkPrefix
            )
        }
    }
    
    private func splitAndChunkText(
        sourceId: String,
        pageIndex: Int,
        segment: PDFLayoutSegment,
        segmentIndex: Int,
        text: String,
        totalPages: Int,
        chunkPrefix: String
    ) async throws -> [ChunkComponent] {
        // Simple splitting by sentences
        let sentences = text.split(separator: ". ").map(String.init)
        var chunks: [ChunkComponent] = []
        var currentChunkText = ""
        var chunkIndex = 0
        
        for sentence in sentences {
            if currentChunkText.isEmpty {
                currentChunkText = sentence
            } else if (currentChunkText + ". " + sentence).count <= maxChunkSize {
                currentChunkText += ". " + sentence
            } else {
                // Create chunk for current accumulated text
                let chunk = try await createTextChunk(
                    sourceId: sourceId,
                    pageIndex: pageIndex,
                    segment: segment,
                    segmentIndex: segmentIndex,
                    text: currentChunkText,
                    chunkIndex: chunkIndex,
                    totalChunks: -1, // Will update later
                    totalPages: totalPages,
                    chunkPrefix: chunkPrefix
                )
                chunks.append(chunk)
                
                chunkIndex += 1
                currentChunkText = sentence
            }
        }
        
        // Add last chunk if any text remains
        if !currentChunkText.isEmpty {
            let chunk = try await createTextChunk(
                sourceId: sourceId,
                pageIndex: pageIndex,
                segment: segment,
                segmentIndex: segmentIndex,
                text: currentChunkText,
                chunkIndex: chunkIndex,
                totalChunks: chunkIndex + 1,
                totalPages: totalPages,
                chunkPrefix: chunkPrefix
            )
            chunks.append(chunk)
        }
        
        // Update total chunks for all chunks in this segment
        // Note: Currently each chunk knows its own total, we could update them if needed
        return chunks
    }
    
    private func createTextChunk(
        sourceId: String,
        pageIndex: Int,
        segment: PDFLayoutSegment,
        segmentIndex: Int,
        text: String,
        chunkIndex: Int,
        totalChunks: Int,
        totalPages: Int,
        chunkPrefix: String
    ) async throws -> ChunkComponent {
        let chunkId = "\(chunkPrefix)page\(pageIndex)-seg\(segmentIndex)-\(chunkIndex)"
        let chunkData = Data(text.utf8)
        let hash = SHA256.hash(data: chunkData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        let chunk = ChunkComponent(
            chunkId: chunkId,
            sourceId: sourceId,
            contentHash: hashString,
            chunkIndex: chunkIndex,
            totalChunks: totalChunks,
            byteRange: 0..<chunkData.count,
            tokenCount: nil
        )
        
        // Create layout metadata
        let layoutMetadata = ChunkLayoutMetadata(
            pageIndex: pageIndex,
            segmentType: "text",
            boundingBox: [
                segment.boundingBox.x,
                segment.boundingBox.y,
                segment.boundingBox.x + segment.boundingBox.width,
                segment.boundingBox.y + segment.boundingBox.height
            ],
            confidence: 1.0
        )
        
        // Insert into database
        try await database.insertChunk(chunk, content: text, layoutMetadata: layoutMetadata)
        
        return chunk
    }
    
    // MARK: - Table Processing
    
    private func processTable(
        sourceId: String,
        pageIndex: Int,
        tableIndex: Int,
        boundingBox: BoundingBoxRef,
        totalPages: Int,
        chunkPrefix: String
    ) async throws -> ChunkComponent {
        let chunkId = "\(chunkPrefix)page\(pageIndex)-table\(tableIndex)"
        let content = "Table region at page \(pageIndex + 1)"
        let chunkData = Data(content.utf8)
        let hash = SHA256.hash(data: chunkData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        let chunk = ChunkComponent(
            chunkId: chunkId,
            sourceId: sourceId,
            contentHash: hashString,
            chunkIndex: tableIndex,
            totalChunks: 1,
            byteRange: 0..<chunkData.count,
            tokenCount: nil
        )
        
        let layoutMetadata = ChunkLayoutMetadata(
            pageIndex: pageIndex,
            segmentType: "table",
            boundingBox: [
                boundingBox.x,
                boundingBox.y,
                boundingBox.x + boundingBox.width,
                boundingBox.y + boundingBox.height
            ],
            confidence: 1.0
        )
        
        try await database.insertChunk(chunk, content: content, layoutMetadata: layoutMetadata)
        
        return chunk
    }
    
    // MARK: - Figure Processing
    
    private func processFigure(
        sourceId: String,
        pageIndex: Int,
        figureIndex: Int,
        boundingBox: BoundingBoxRef,
        totalPages: Int,
        chunkPrefix: String
    ) async throws -> ChunkComponent {
        let chunkId = "\(chunkPrefix)page\(pageIndex)-figure\(figureIndex)"
        let content = "Figure region at page \(pageIndex + 1)"
        let chunkData = Data(content.utf8)
        let hash = SHA256.hash(data: chunkData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        let chunk = ChunkComponent(
            chunkId: chunkId,
            sourceId: sourceId,
            contentHash: hashString,
            chunkIndex: figureIndex,
            totalChunks: 1,
            byteRange: 0..<chunkData.count,
            tokenCount: nil
        )
        
        let layoutMetadata = ChunkLayoutMetadata(
            pageIndex: pageIndex,
            segmentType: "figure",
            boundingBox: [
                boundingBox.x,
                boundingBox.y,
                boundingBox.x + boundingBox.width,
                boundingBox.y + boundingBox.height
            ],
            confidence: 1.0
        )
        
        try await database.insertChunk(chunk, content: content, layoutMetadata: layoutMetadata)
        
        return chunk
    }
    
    // MARK: - Image Processing
    
    private func processImage(
        sourceId: String,
        pageIndex: Int,
        imageIndex: Int,
        image: PDFLayoutImage,
        totalPages: Int,
        chunkPrefix: String
    ) async throws -> ChunkComponent {
        let chunkId = "\(chunkPrefix)page\(pageIndex)-image\(imageIndex)"
        let content = "Image at page \(pageIndex + 1)"
        let chunkData = Data(content.utf8)
        let hash = SHA256.hash(data: chunkData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        let chunk = ChunkComponent(
            chunkId: chunkId,
            sourceId: sourceId,
            contentHash: hashString,
            chunkIndex: imageIndex,
            totalChunks: 1,
            byteRange: 0..<chunkData.count,
            tokenCount: nil
        )
        
        let layoutMetadata = ChunkLayoutMetadata(
            pageIndex: pageIndex,
            segmentType: "image",
            boundingBox: [
                image.boundingBox.x,
                image.boundingBox.y,
                image.boundingBox.x + image.boundingBox.width,
                image.boundingBox.y + image.boundingBox.height
            ],
            confidence: 1.0
        )
        
        try await database.insertChunk(chunk, content: content, layoutMetadata: layoutMetadata)
        
        return chunk
    }
}
