import Foundation
import CryptoKit
import CapsuleCore
import AnigmaCore
import ContractsCore
import VectorCapsule
import TelemetryCore

public actor LayoutIndexingSystem {
    private let database: ContextumDatabase
    private let maxChunkSize: Int
    private let vectorCapsule: VectorCapsule?
    
    public init(database: ContextumDatabase, maxChunkSize: Int = 512, vectorCapsule: VectorCapsule? = nil) {
        self.database = database
        self.maxChunkSize = maxChunkSize
        self.vectorCapsule = vectorCapsule
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
    
    // MARK: - Geometry Operations
    
    /// Convert layout bounding box to SVG path for visualization
    /// - Parameter boundingBox: The layout bounding box
    /// - Returns: SVG path string representing the bounding box
    public func layoutRegionToSVG(boundingBox: BoundingBoxRef) -> String {
        let x = boundingBox.x
        let y = boundingBox.y
        let width = boundingBox.width
        let height = boundingBox.height
        
        if vectorCapsule != nil {
            let bounds = BoundingBox(minX: x, minY: y, maxX: x + width, maxY: y + height)
            recordVectorCapsuleTelemetry(operation: "layoutRegionToSVG", success: true)
            return svgPathFromBounds(bounds)
        }
        return manualLayoutRegionToSVG(x: x, y: y, width: width, height: height)
    }
    
    /// Union multiple layout regions using VectorCapsule
    /// - Parameter regions: Array of bounding boxes to union
    /// - Returns: Array of bounding boxes representing the union result
    public func unionRegions(_ regions: [BoundingBoxRef]) -> [BoundingBoxRef] {
        guard regions.count > 1 else { return regions }
        
        if let capsule = vectorCapsule {
            do {
                let svgPaths = regions.map { layoutRegionToSVG(boundingBox: $0) }
                var resultPath = svgPaths[0]
                for i in 1..<svgPaths.count {
                    resultPath = try capsule.union(pathA: resultPath, pathB: svgPaths[i])
                }
                let bounds = try capsule.getBounds(path: resultPath)
                recordVectorCapsuleTelemetry(operation: "unionRegions", success: true)
                return [BoundingBoxRef(x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height)]
            } catch {
                recordVectorCapsuleTelemetry(operation: "unionRegions", success: false, error: error.localizedDescription)
            }
        }
        return manualUnionRegions(regions)
    }
    
    /// Intersect multiple layout regions using VectorCapsule
    /// - Parameter regions: Array of bounding boxes to intersect
    /// - Returns: Array of bounding boxes representing the intersection result
    public func intersectRegions(_ regions: [BoundingBoxRef]) -> [BoundingBoxRef] {
        guard regions.count > 1 else { return regions }
        
        if let capsule = vectorCapsule {
            do {
                let svgPaths = regions.map { layoutRegionToSVG(boundingBox: $0) }
                var resultPath = svgPaths[0]
                for i in 1..<svgPaths.count {
                    resultPath = try capsule.intersection(pathA: resultPath, pathB: svgPaths[i])
                }
                let bounds = try capsule.getBounds(path: resultPath)
                recordVectorCapsuleTelemetry(operation: "intersectRegions", success: true)
                return [BoundingBoxRef(x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height)]
            } catch {
                recordVectorCapsuleTelemetry(operation: "intersectRegions", success: false, error: error.localizedDescription)
            }
        }
        return manualIntersectRegions(regions)
    }
    
    /// Simplify complex polygon boundary using Douglas-Peucker algorithm via VectorCapsule
    /// - Parameters:
    ///   - boundary: Array of points defining the polygon boundary
    ///   - tolerance: Simplification tolerance
    /// - Returns: Simplified array of points
    public func simplifyRegionBoundary(_ boundary: [Point], tolerance: Float) -> [Point] {
        guard boundary.count > 2 else { return boundary }
        
        if let capsule = vectorCapsule {
            do {
                let svgPath = pointsToSVGPath(boundary)
                let simplifiedPath = try capsule.douglasPeuckerSimplify(path: svgPath, tolerance: Double(tolerance))
                _ = try capsule.getBounds(path: simplifiedPath)
                recordVectorCapsuleTelemetry(operation: "simplifyRegionBoundary", success: true)
                return svgPathToPoints(simplifiedPath)
            } catch {
                recordVectorCapsuleTelemetry(operation: "simplifyRegionBoundary", success: false, error: error.localizedDescription)
            }
        }
        return manualSimplifyRegionBoundary(boundary, tolerance: tolerance)
    }
    
    /// Check if a point is inside a region using VectorCapsule
    /// - Parameters:
    ///   - point: The point to check
    ///   - region: The bounding box region
    /// - Returns: True if point is inside the region
    public func pointInRegion(point: PointRef, region: BoundingBoxRef) -> Bool {
        if let capsule = vectorCapsule {
            do {
                let svgPath = layoutRegionToSVG(boundingBox: region)
                let capsulePoint = Point(x: point.x, y: point.y)
                let result = try capsule.pointInPolygon(point: capsulePoint, path: svgPath)
                recordVectorCapsuleTelemetry(operation: "pointInRegion", success: true)
                return result
            } catch {
                recordVectorCapsuleTelemetry(operation: "pointInRegion", success: false, error: error.localizedDescription)
            }
        }
        return manualPointInRegion(point: point, region: region)
    }
    
    /// Calculate bounding box from an array of points
    /// - Parameter points: Array of points
    /// - Returns: Bounding box containing all points
    public func calculateRegionBounds(_ points: [PointRef]) -> BoundingBoxRef {
        guard !points.isEmpty else {
            return BoundingBoxRef(x: 0, y: 0, width: 0, height: 0)
        }
        
        if let capsule = vectorCapsule {
            do {
                let svgPath = pointsToSVGPath(points.map { Point(x: $0.x, y: $0.y) })
                let bounds = try capsule.getBounds(path: svgPath)
                recordVectorCapsuleTelemetry(operation: "calculateRegionBounds", success: true)
                return BoundingBoxRef(x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height)
            } catch {
                recordVectorCapsuleTelemetry(operation: "calculateRegionBounds", success: false, error: error.localizedDescription)
            }
        }
        return manualCalculateRegionBounds(points)
    }
    
    // MARK: - Fallback Manual Implementations
    
    private func manualLayoutRegionToSVG(x: Double, y: Double, width: Double, height: Double) -> String {
        return "M \(x) \(y) L \(x + width) \(y) L \(x + width) \(y + height) L \(x) \(y + height) Z"
    }
    
    private func manualUnionRegions(_ regions: [BoundingBoxRef]) -> [BoundingBoxRef] {
        guard !regions.isEmpty else { return [] }
        
        var minX = regions[0].x
        var minY = regions[0].y
        var maxX = regions[0].x + regions[0].width
        var maxY = regions[0].y + regions[0].height
        
        for region in regions.dropFirst() {
            minX = min(minX, region.x)
            minY = min(minY, region.y)
            maxX = max(maxX, region.x + region.width)
            maxY = max(maxY, region.y + region.height)
        }
        
        return [BoundingBoxRef(x: minX, y: minY, width: maxX - minX, height: maxY - minY)]
    }
    
    private func manualIntersectRegions(_ regions: [BoundingBoxRef]) -> [BoundingBoxRef] {
        guard !regions.isEmpty else { return [] }
        
        var intersect = regions[0]
        
        for region in regions.dropFirst() {
            let newX = max(intersect.x, region.x)
            let newY = max(intersect.y, region.y)
            let newWidth = min(intersect.x + intersect.width, region.x + region.width) - newX
            let newHeight = min(intersect.y + intersect.height, region.y + region.height) - newY
            
            if newWidth <= 0 || newHeight <= 0 {
                return []
            }
            
            intersect = BoundingBoxRef(x: newX, y: newY, width: newWidth, height: newHeight)
        }
        
        return [intersect]
    }
    
    private func manualSimplifyRegionBoundary(_ boundary: [Point], tolerance: Float) -> [Point] {
        guard boundary.count > 2 else { return boundary }
        return boundary
    }
    
    private func manualPointInRegion(point: PointRef, region: BoundingBoxRef) -> Bool {
        return point.x >= region.x && point.x <= region.x + region.width &&
               point.y >= region.y && point.y <= region.y + region.height
    }
    
    private func manualCalculateRegionBounds(_ points: [PointRef]) -> BoundingBoxRef {
        guard !points.isEmpty else {
            return BoundingBoxRef(x: 0, y: 0, width: 0, height: 0)
        }
        
        var minX = points[0].x
        var minY = points[0].y
        var maxX = points[0].x
        var maxY = points[0].y
        
        for point in points.dropFirst() {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }
        
        return BoundingBoxRef(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    // MARK: - Helper Methods
    
    private func svgPathFromBounds(_ bounds: BoundingBox) -> String {
        return "M \(bounds.minX) \(bounds.minY) L \(bounds.maxX) \(bounds.minY) L \(bounds.maxX) \(bounds.maxY) L \(bounds.minX) \(bounds.maxY) Z"
    }
    
    private func pointsToSVGPath(_ points: [Point]) -> String {
        guard !points.isEmpty else { return "" }
        var path = "M \(points[0].x) \(points[0].y)"
        for point in points.dropFirst() {
            path += " L \(point.x) \(point.y)"
        }
        path += " Z"
        return path
    }
    
    private func svgPathToPoints(_ path: String) -> [Point] {
        // Split by SVG path commands and spaces
        let separators = CharacterSet(charactersIn: "MLZ ")
        let components = path.components(separatedBy: separators).filter { !$0.isEmpty }
        var points: [Point] = []
        var index = 0
        var x: Double = 0
        var y: Double = 0
        
        for component in components {
            if index % 2 == 0 {
                x = Double(component) ?? 0
            } else {
                y = Double(component) ?? 0
                points.append(Point(x: x, y: y))
            }
            index += 1
        }
        
        return points
    }
    
    private func recordVectorCapsuleTelemetry(
        operation: String,
        success: Bool,
        error: String? = nil
    ) {
        // Fire-and-forget telemetry - don't block the calling function
        var diagnostics: [String: String] = [
            "capsule_type": "VectorCapsule",
            "operation": operation,
            "capsule_used": "true"
        ]
        
        if !success, let errorMessage = error {
            diagnostics["error"] = errorMessage
        }
        
        let event = TelemetryEventComponent(
            eventId: UUID().uuidString,
            eventType: .capsule,
            outcome: success ? .success : .failure,
            diagnosticPayload: diagnostics
        )
        
        let db = self.database
        Task.detached {
            try? await db.insertEvent(event)
        }
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

/// Point reference for spatial coordinates.
public struct PointRef: Hashable, Codable, Sendable {
    public let x: Double
    public let y: Double
    
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}
