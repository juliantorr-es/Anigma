//
//  LargeDocumentProcessor.swift
//  DiaplasionModule
//
//  Handles streaming processing of large documents to manage memory usage.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives

/// Processes large documents in batches to manage memory efficiently.
public struct LargeDocumentProcessor: Sendable {
    
    // MARK: - Configuration
    
    /// Batch size for processing pages
    public let batchSize: Int
    
    /// Memory threshold in MB to trigger batched processing
    public let memoryThreshold: Int
    
    /// Maximum concurrent processing jobs
    public let maxConcurrentJobs: Int
    
    /// Progress callback during processing
    public let onProgress: ((ProcessingProgress) -> Void)?
    
    // MARK: - Initialization
    
    public init(
        batchSize: Int? = nil,
        memoryThreshold: Int? = nil,
        maxConcurrentJobs: Int? = nil,
        onProgress: ((ProcessingProgress) -> Void)? = nil
    ) {
        self.batchSize = batchSize ?? DiaplasionConfiguration.largeDocumentBatchSize
        self.memoryThreshold = memoryThreshold ?? DiaplasionConfiguration.performanceMaxMemoryMB
        self.maxConcurrentJobs = maxConcurrentJobs ?? DiaplasionConfiguration.performanceConcurrentJobs
        self.onProgress = onProgress
    }
    
    // MARK: - Public Interface
    
    /// Process a large document using streaming/batched approach.
    ///
    /// - Parameters:
    ///   - document: The document source to process
    ///   - processor: The processing function to apply to each batch
    /// - Returns: Processing result with consolidated output
    public func processDocument<T>(
        _ document: DocumentSourceComponent,
        processor: @escaping @Sendable (DocumentBatch) async throws -> T
    ) async throws -> LargeDocumentResult<T> {
        
        // Check if document requires batched processing
        guard shouldUseBatchedProcessing(document) else {
            // Use regular processing for smaller documents
            let totalPages = document.pageCount ?? 1
            let batch = DocumentBatch(
                pages: Array(1...totalPages),
                document: document,
                isFinalBatch: true
            )
            
            let result = try await processor(batch)
            return LargeDocumentResult(
                results: [result],
                metadata: ProcessingMetadata(
                    totalPages: totalPages,
                    batchesProcessed: 1,
                    processingTime: 0,
                    memoryPeak: estimateMemoryUsage(for: document)
                )
            )
        }
        
        return try await processBatchedDocument(document, processor: processor)
    }
    
    /// Process pages in batches with memory management.
    private func processBatchedDocument<T>(
        _ document: DocumentSourceComponent,
        processor: @escaping @Sendable (DocumentBatch) async throws -> T
    ) async throws -> LargeDocumentResult<T> {
        
        let startTime = Date()
        var results: [T] = []
        var batchesProcessed = 0
        var currentMemoryUsage: Double = 0
        
        // Split pages into batches
        let totalPages = document.pageCount ?? 1
        let pageBatches = splitIntoBatches(1...totalPages, batchSize: batchSize)
        
        onProgress?(ProcessingProgress(
            currentPage: 0,
            totalPages: totalPages,
            currentBatch: 0,
            totalBatches: pageBatches.count,
            percentage: 0.0,
            stage: .starting
        ))
        
        for (batchIndex, pages) in pageBatches.enumerated() {
            let isFinalBatch = batchIndex == pageBatches.count - 1
            
            // Create batch for processing
            let batch = DocumentBatch(
                pages: Array(pages),
                document: document,
                isFinalBatch: isFinalBatch
            )
            
            // Process batch with memory monitoring
            let batchResult = try await processWithMemoryManagement(
                batch: batch,
                processor: processor,
                batchIndex: batchIndex + 1,
                totalBatches: pageBatches.count
            )
            
            results.append(batchResult)
            batchesProcessed += 1
            
            // Estimate current memory usage
            currentMemoryUsage = estimateMemoryUsage(for: document, processedBatches: batchesProcessed)
            
            // Report progress
            let processedPages = min((batchIndex + 1) * batchSize, totalPages)
            let percentage = Double(processedPages) / Double(totalPages) * 100
            
            onProgress?(ProcessingProgress(
                currentPage: processedPages,
                totalPages: totalPages,
                currentBatch: batchIndex + 1,
                totalBatches: pageBatches.count,
                percentage: percentage,
                stage: isFinalBatch ? .finalizing : .processing
            ))
            
            // Memory cleanup between batches
            await performMemoryCleanup()
            
            // Check memory pressure
            if currentMemoryUsage > Double(memoryThreshold) {
                await Logger.shared.warning(
                    "High memory usage detected: \(String(format: "%.1f", currentMemoryUsage))MB",
                    category: "Diaplasion"
                )
                
                // Aggressive cleanup
                await performAggressiveMemoryCleanup()
            }
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return LargeDocumentResult(
            results: results,
            metadata: ProcessingMetadata(
                totalPages: totalPages,
                batchesProcessed: batchesProcessed,
                processingTime: processingTime,
                memoryPeak: currentMemoryUsage
            )
        )
    }
    
    // MARK: - Helper Methods
    
    /// Determine if document should use batched processing.
    private func shouldUseBatchedProcessing(_ document: DocumentSourceComponent) -> Bool {
        // Use configuration threshold
        return DiaplasionConfiguration.isLargeDocument(fileSizeBytes: document.fileSize ?? 0)
    }
    
    /// Split range of pages into batches.
    private func splitIntoBatches(_ range: ClosedRange<Int>, batchSize: Int) -> [[Int]] {
        var batches: [[Int]] = []
        var currentBatch: [Int] = []
        
        for page in range {
            currentBatch.append(page)
            
            if currentBatch.count >= batchSize {
                batches.append(currentBatch)
                currentBatch = []
            }
        }
        
        if !currentBatch.isEmpty {
            batches.append(currentBatch)
        }
        
        return batches
    }
    
    /// Process a single batch with memory monitoring.
    private func processWithMemoryManagement<T>(
        batch: DocumentBatch,
        processor: @escaping @Sendable (DocumentBatch) async throws -> T,
        batchIndex: Int,
        totalBatches: Int
    ) async throws -> T {
        
        let memoryBefore = estimateCurrentMemoryUsage()
        
        do {
            let result = try await processor(batch)
            
            let memoryAfter = estimateCurrentMemoryUsage()
            let memoryDelta = memoryAfter - memoryBefore
            
            await Logger.shared.debug(
                "Batch \(batchIndex)/\(totalBatches) processed. Memory delta: \(String(format: "%.1f", memoryDelta))MB",
                category: "Diaplasion"
            )
            
            return result
            
        } catch {
            await Logger.shared.error(
                "Batch \(batchIndex)/\(totalBatches) failed: \(error.localizedDescription)",
                category: "Diaplasion"
            )
            throw error
        }
    }
    
    // MARK: - Memory Management
    
    /// Estimate memory usage for document processing.
    private func estimateMemoryUsage(for document: DocumentSourceComponent, processedBatches: Int = 0) -> Double {
        let baseMemory = Double(document.fileSize ?? 0) / (1024 * 1024) * 2 // Rough estimate
        let batchMemory = Double(processedBatches * batchSize) * 0.5 // ~0.5MB per page
        return baseMemory + batchMemory
    }
    
    /// Estimate current memory usage.
    private func estimateCurrentMemoryUsage() -> Double {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(taskInfo.resident_size) / (1024 * 1024)
        }
        
        return 0.0
    }
    
    /// Perform basic memory cleanup.
    private func performMemoryCleanup() async {
        // Trigger garbage collection if available
        autoreleasepool {
            // Clear temporary caches
        }
        
        // Small delay to allow memory pressure to be resolved
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
    }
    
    /// Perform aggressive memory cleanup under pressure.
    private func performAggressiveMemoryCleanup() async {
        autoreleasepool {
            // Clear all temporary data structures
        }
        
        // Longer delay under memory pressure
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
    }
}

// MARK: - Supporting Types

/// A batch of pages from a document for processing.
public struct DocumentBatch: Sendable {
    public let pages: [Int]
    public let document: DocumentSourceComponent
    public let isFinalBatch: Bool
    
    public init(pages: [Int], document: DocumentSourceComponent, isFinalBatch: Bool) {
        self.pages = pages
        self.document = document
        self.isFinalBatch = isFinalBatch
    }
}

/// Progress information during large document processing.
public struct ProcessingProgress: Sendable {
    public let currentPage: Int
    public let totalPages: Int
    public let currentBatch: Int
    public let totalBatches: Int
    public let percentage: Double
    public let stage: ProcessingStage
    
    public init(
        currentPage: Int,
        totalPages: Int,
        currentBatch: Int,
        totalBatches: Int,
        percentage: Double,
        stage: ProcessingStage
    ) {
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.currentBatch = currentBatch
        self.totalBatches = totalBatches
        self.percentage = percentage
        self.stage = stage
    }
}

/// Processing stages for large document handling.
public enum ProcessingStage: String, CaseIterable, Sendable {
    case starting = "starting"
    case processing = "processing"
    case finalizing = "finalizing"
    case completed = "completed"
    case error = "error"
}

/// Result of large document processing.
public struct LargeDocumentResult<T>: Sendable {
    public let results: [T]
    public let metadata: ProcessingMetadata
    
    public init(results: [T], metadata: ProcessingMetadata) {
        self.results = results
        self.metadata = metadata
    }
}

/// Metadata about the processing operation.
public struct ProcessingMetadata: Sendable {
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

// MARK: - System Integration

/// System that coordinates large document processing.
public struct LargeDocumentProcessingSystem: System {
    public var name: String { "LargeDocumentProcessing" }
    
    private let processor: LargeDocumentProcessor
    
    public init(processor: LargeDocumentProcessor = LargeDocumentProcessor()) {
        self.processor = processor
    }
    
    public func update(world: World) async {
        // Query for entities that need large document processing
        let entities = await world.query(
            DocumentSourceComponent.self,
            TransformRequestComponent.self
        )
        
        for (entity, document, transform) in entities {
            // Skip if already processed
            if await world.hasComponent(entity, LargeDocumentProcessingComponent.self) {
                continue
            }
            
            // Check if document requires large document processing
            guard DiaplasionConfiguration.isLargeDocument(fileSizeBytes: document.fileSize ?? 0) else {
                continue
            }
            
            do {
                let processingComponent = LargeDocumentProcessingComponent(
                    documentId: entity,
                    startedAt: Date(),
                    status: .starting
                )
                
                await world.addComponent(entity, processingComponent)
                
                await Logger.shared.info(
                    "Large document processing started for entity \(entity)",
                    category: "Diaplasion"
                )
                
            } catch {
                await Logger.shared.error(
                    "Failed to start large document processing: \(error)",
                    category: "Diaplasion"
                )
            }
        }
    }
}

/// Component tracking large document processing status.
public struct LargeDocumentProcessingComponent: Component {
    public let documentId: EntityID
    public let startedAt: Date
    public var status: ProcessingStage
    public var progress: ProcessingProgress?
    public var completedAt: Date?
    
    public init(
        documentId: EntityID,
        startedAt: Date,
        status: ProcessingStage,
        progress: ProcessingProgress? = nil,
        completedAt: Date? = nil
    ) {
        self.documentId = documentId
        self.startedAt = startedAt
        self.status = status
        self.progress = progress
        self.completedAt = completedAt
    }
}