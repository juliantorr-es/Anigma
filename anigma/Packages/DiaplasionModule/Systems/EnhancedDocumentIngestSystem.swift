//
//  EnhancedDocumentIngestSystem.swift
//  DiaplasionModule
//
//  Extracted from DiaplasionSystems.swift
//  Enhanced Document Ingest System with large document support.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

// MARK: - Large Document Processing Integration

/// Enhanced Document Ingest System with large document support.
public struct EnhancedDocumentIngestSystem: System {
    public var name: String { "EnhancedDocumentIngest" }
    
    private let largeDocumentProcessor: LargeDocumentProcessor
    private let progressTracker: ProgressTracker
    private let checkpointManager: CheckpointManager
    
    public init(
        largeDocumentProcessor: LargeDocumentProcessor = LargeDocumentProcessor(),
        progressTracker: ProgressTracker = ProgressTracker(),
        checkpointManager: CheckpointManager = CheckpointManager()
    ) {
        self.largeDocumentProcessor = largeDocumentProcessor
        self.progressTracker = progressTracker
        self.checkpointManager = checkpointManager
    }
    
    public func update(world: World) async {
        let files = await world.query(FileComponent.self)
        
        for (entity, fileComp) in files {
            // Skip if already ingested
            if await world.hasComponent(entity, DocumentSourceComponent.self) {
                continue
            }
            
            guard let path = fileComp.path else {
                await Logger.shared.warning("FileComponent has no path", category: "Diaplasion")
                continue
            }
            
            // Check for existing checkpoint
            let hasCheckpoint = checkpointManager.hasCheckpoint(
                entityId: entity,
                operationType: "document_ingest"
            )
            
            if hasCheckpoint && DiaplasionConfiguration.enableProgressTracking {
                do {
                    if let checkpoint = try await checkpointManager.loadCheckpoint(
                        entityType: IngestCheckpointData.self,
                        entityId: entity,
                        operationType: "document_ingest"
                    ) {
                        await Logger.shared.info(
                            "Resuming document ingestion from checkpoint",
                            category: "Diaplasion"
                        )
                        
                        await resumeIngestion(
                            from: checkpoint,
                            for: entity,
                            at: path,
                            in: world
                        )
                        continue
                    }
                } catch {
                    await Logger.shared.warning(
                        "Failed to load checkpoint: \(error)",
                        category: "Diaplasion"
                    )
                }
            }
            
            // Start new ingestion with progress tracking
            await startIngestion(
                for: entity,
                at: path,
                in: world
            )
        }
    }
    
    private func startIngestion(
        for entity: EntityID,
        at path: String,
        in world: World
    ) async {
        await progressTracker.startJob(
            entityId: entity,
            jobType: .documentIngest,
            totalSteps: 5,
            metadata: ["path": path]
        )
        
        do {
            // Check if it's a large document
            let fileSize = try FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64 ?? 0
            let isLarge = DiaplasionConfiguration.isLargeDocument(fileSizeBytes: fileSize)
            
            if isLarge {
                await ingestLargeDocument(
                    for: entity,
                    at: path,
                    fileSize: fileSize,
                    in: world
                )
            } else {
                await ingestRegularDocument(
                    for: entity,
                    at: path,
                    in: world
                )
            }
            
        } catch {
            await Logger.shared.error(
                "Document ingestion failed: \(error)",
                category: "Diaplasion"
            )
            
            await progressTracker.completeJob(
                entityId: entity,
                success: false,
                finalMessage: error.localizedDescription
            )
        }
    }
    
    private func ingestLargeDocument(
        for entity: EntityID,
        at path: String,
        fileSize: Int64,
        in world: World
    ) async {
        await Logger.shared.info(
            "Processing large document (\(String(format: "%.1f", Double(fileSize) / (1024 * 1024)))MB)",
            category: "Diaplasion"
        )
        
        // Create progress callback
        let onProgress: (ProcessingProgress) -> Void = { (progress: ProcessingProgress) in
            Task {
                await world.addComponent(entity, ProgressUpdateComponent(
                    action: .update(
                        currentStep: progress.currentPage,
                        stage: progress.stage,
                        message: "Processing page \(progress.currentPage) of \(progress.totalPages)",
                        metadata: ["batch": "\(progress.currentBatch)/\(progress.totalBatches)"]
                    )
                ))
            }
        }
        
        let processor = LargeDocumentProcessor(
            onProgress: onProgress
        )
        
        do {
            let source = try await createDocumentSource(at: path, fileSize: fileSize)
            
            let result = try await processor.processDocument(source) { batch in
                // Process batch with checkpoint saving
                let batchResult = try await processBatch(batch, entity: entity, world: world)
                
                // Save checkpoint after each batch
                let checkpointData = IngestCheckpointData(
                    processedPages: batch.pages,
                    currentBatch: batch.document.pageCount! / processor.batchSize,
                    totalBatches: batch.document.pageCount! / processor.batchSize
                )
                
                try await checkpointManager.saveCheckpoint(
                    entityId: entity,
                    operationType: "document_ingest",
                    data: checkpointData,
                    metadata: ["processed_pages": "\(batch.pages.count)"]
                )
                
                return batchResult
            }
            
            await world.addComponent(entity, result.results.last!) // Last batch result
            await world.addComponent(entity, result.metadata.toComponent())
            
            await progressTracker.completeJob(
                entityId: entity,
                success: true,
                finalMessage: "Large document processed successfully",
                resultMetadata: [
                    "batches_processed": "\(result.metadata.batchesProcessed)",
                    "processing_time": "\(String(format: "%.2f", result.metadata.processingTime))s",
                    "memory_peak": "\(String(format: "%.1f", result.metadata.memoryPeak))MB"
                ]
            )
            
            // Clean up checkpoints on successful completion
            _ = try? await checkpointManager.deleteCheckpoint(entityId: entity, operationType: "document_ingest")
            
        } catch {
            await Logger.shared.error(
                "Large document processing failed: \(error)",
                category: "Diaplasion"
            )
            
            await progressTracker.completeJob(
                entityId: entity,
                success: false,
                finalMessage: error.localizedDescription
            )
        }
    }
    
    private func ingestRegularDocument(
        for entity: EntityID,
        at path: String,
        in world: World
    ) async {
        // Use existing DocumentIngestSystem logic for regular documents
        let ingestSystem = DocumentIngestSystem()
        
        // Add progress tracking
        await progressTracker.updateProgress(
            entityId: entity,
            currentStep: 1,
            stage: .processing,
            message: "Processing document"
        )
        
        do {
            let result = try await ingestSystem.ingestDocument(at: path)
            await world.addComponent(entity, result.source)
            await world.addComponent(entity, result.ingested)
            if let assets = result.assets {
                await world.addComponent(entity, assets)
            }
            
            await progressTracker.completeJob(
                entityId: entity,
                success: true,
                finalMessage: "Document ingested successfully"
            )
            
        } catch {
            await Logger.shared.error(
                "Regular document ingestion failed: \(error)",
                category: "Diaplasion"
            )
            
            await progressTracker.completeJob(
                entityId: entity,
                success: false,
                finalMessage: error.localizedDescription
            )
        }
    }
    
    private func resumeIngestion(
        from checkpoint: Checkpoint<IngestCheckpointData>,
        for entity: EntityID,
        at path: String,
        in world: World
    ) async {
        let checkpointData = checkpoint.data
        
        await progressTracker.startJob(
            entityId: entity,
            jobType: .documentIngest,
            totalSteps: 5,
            metadata: [
                "resumed": "true",
                "resume_from_page": "\(checkpointData.processedPages.last ?? 0)"
            ]
        )
        
        // Continue from where we left off
        await Logger.shared.info(
            "Resuming ingestion from page \(checkpointData.processedPages.last ?? 0)",
            category: "Diaplasion"
        )
        
        // Implementation would continue processing from checkpoint data
        // This is simplified for brevity
        await ingestRegularDocument(for: entity, at: path, in: world)
    }
    
    private func createDocumentSource(at path: String, fileSize: Int64) async throws -> DocumentSourceComponent {
        // Simplified document source creation
        // In practice, this would detect format, count pages, etc.
        return DocumentSourceComponent(
            sourceURI: path,
            format: .pdf, // Simplified
            pageCount: 100, // Simplified
            fileSize: fileSize
        )
    }
    
    private func processBatch(_ batch: DocumentBatch, entity: EntityID, world: World) async throws -> DocumentSourceComponent {
        // Simplified batch processing
        // In practice, this would process actual pages
        return batch.document
    }
}

/// Checkpoint data for document ingestion.
public struct IngestCheckpointData: Codable {
    public let processedPages: [Int]
    public let currentBatch: Int
    public let totalBatches: Int
    
    public init(processedPages: [Int], currentBatch: Int, totalBatches: Int) {
        self.processedPages = processedPages
        self.currentBatch = currentBatch
        self.totalBatches = totalBatches
    }
}

extension ProcessingMetadata {
    /// Convert to component for ECS integration.
    public func toComponent() -> Component {
        // Simplified - would return an actual component type
        return ProcessingMetadataComponent(
            totalPages: totalPages,
            batchesProcessed: batchesProcessed,
            processingTime: processingTime,
            memoryPeak: memoryPeak
        )
    }
}

/// Component for storing processing metadata.
public struct ProcessingMetadataComponent: Component {
    public let totalPages: Int
    public let batchesProcessed: Int
    public let processingTime: TimeInterval
    public let memoryPeak: Double
    
    public init(
        totalPages: Int,
        batchesProcessed: Int,
        processingTime: TimeInterval,
        memoryPeak: Double
    ) {
        self.totalPages = totalPages
        self.batchesProcessed = batchesProcessed
        self.processingTime = processingTime
        self.memoryPeak = memoryPeak
    }
}
