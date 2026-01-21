//
//  MCPStreamingSupport.swift
//  AnigmaMCPModule
//
//  Infrastructure for streaming tool progress over MCP protocol.
//  Enables real-time feedback for long-running operations.
//

import AnigmaPrimitives
import Foundation
import HarmoniaModule

/// Progress update streamed during tool execution
public struct ProgressUpdate: Sendable, Codable, Hashable {
    /// Unique ID for this progress update
    public let updateId: String

    /// Timestamp of the update
    public let timestamp: Date

    /// Phase or stage of execution
    public let phase: ToolPhase

    /// Progress percentage (0.0 to 1.0)
    public let progress: Double

    /// Human-readable status message
    public let message: String

    /// Optional: items processed so far
    public let itemsProcessed: Int?

    /// Optional: total items to process
    public let totalItems: Int?

    /// Optional: estimated time remaining (seconds)
    public let estimatedTimeRemaining: TimeInterval?

    /// Optional: current item being processed
    public let currentItem: String?

    /// Optional: error message if in error state
    public let error: String?

    public init(
        phase: ToolPhase,
        progress: Double,
        message: String,
        itemsProcessed: Int? = nil,
        totalItems: Int? = nil,
        estimatedTimeRemaining: TimeInterval? = nil,
        currentItem: String? = nil,
        error: String? = nil
    ) {
        self.updateId = UUID().uuidString
        self.timestamp = Date()
        self.phase = phase
        self.progress = progress
        self.message = message
        self.itemsProcessed = itemsProcessed
        self.totalItems = totalItems
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.currentItem = currentItem
        self.error = error
    }
}

/// Tool execution phase
public enum ToolPhase: String, Sendable, Codable, Hashable {
    case initializing = "initializing"
    case analyzing = "analyzing"
    case processing = "processing"
    case indexing = "indexing"
    case computing = "computing"
    case generating = "generating"
    case compiling = "compiling"
    case finalizing = "finalizing"
    case complete = "complete"
    case error = "error"
}

/// Progress tracker for streaming updates
public actor ProgressTracker {
    private var updateCallbacks: [@Sendable (ProgressUpdate) async -> Void] = []
    private var currentPhase: ToolPhase = .initializing
    private var startTime = Date()
    private var itemsProcessed: Int = 0
    private var totalItems: Int = 0

    public init() {}

    /// Register callback for progress updates
    public func onProgress(_ callback: @escaping @Sendable (ProgressUpdate) async -> Void) {
        updateCallbacks.append(callback)
    }

    /// Start phase
    public func startPhase(_ phase: ToolPhase, message: String) async {
        currentPhase = phase
        await emitUpdate(
            phase: phase,
            progress: phase == .initializing ? 0.0 : 0.1,
            message: message
        )
    }

    /// Update items processed
    public func updateProgress(
        itemsProcessed: Int,
        totalItems: Int,
        currentItem: String? = nil
    ) async {
        self.itemsProcessed = itemsProcessed
        self.totalItems = totalItems

        let progress = totalItems > 0 ? Double(itemsProcessed) / Double(totalItems) : 0.0
        let estimated = estimateTimeRemaining(progress: progress)

        await emitUpdate(
            phase: currentPhase,
            progress: progress,
            message: "Processed \(itemsProcessed) of \(totalItems) items",
            itemsProcessed: itemsProcessed,
            totalItems: totalItems,
            estimatedTimeRemaining: estimated,
            currentItem: currentItem
        )
    }

    /// Complete phase
    public func completePhase(message: String) async {
        await emitUpdate(
            phase: currentPhase,
            progress: 1.0,
            message: message
        )
    }

    /// Mark as error
    public func error(_ error: String) async {
        await emitUpdate(
            phase: .error,
            progress: 0.0,
            message: "Error occurred",
public struct EmitUpdateConfiguration: Sendable {
    public let phase: String
    public let progress: Double?
    public let message: String?
    public let itemsProcessed: Int?
    public let totalItems: Int?
    public let estimatedTimeRemaining: TimeInterval?
    public let currentItem: String?
    public let error: String?
    
    public init(
        phase: String,
        progress: Double? = nil,
        message: String? = nil,
        itemsProcessed: Int? = nil,
        totalItems: Int? = nil,
        estimatedTimeRemaining: TimeInterval? = nil,
        currentItem: String? = nil,
        error: String? = nil
    ) {
        self.phase = phase
        self.progress = progress
        self.message = message
        self.itemsProcessed = itemsProcessed
        self.totalItems = totalItems
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.currentItem = currentItem
        self.error = error
    }
}

// Migration Guide:
// Old call:
// emitUpdate(
//     phase: value,
//     progress: value,
//     message: value,
//     itemsProcessed: value,
//     totalItems: value,
//     estimatedTimeRemaining: value,
//     currentItem: value,
//     error: value,
// )
//
// New call:
// let config = EmitUpdateConfiguration(
//     phase: value,
//     progress: value,
//     message: value,
//     itemsProcessed: value,
//     totalItems: value,
//     estimatedTimeRemaining: value,
//     currentItem: value,
//     error: value,
// )
// emitUpdate(config: config)
        phase: String,
        progress: Double? = nil,
        message: String? = nil,
        itemsProcessed: Int? = nil,
        totalItems: Int? = nil,
        estimatedTimeRemaining: TimeInterval? = nil,
        currentItem: String? = nil,
        error: String? = nil
    ) {
        self.phase = phase
        self.progress = progress
        self.message = message
        self.itemsProcessed = itemsProcessed
        self.totalItems = totalItems
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.currentItem = currentItem
        self.error = error
    }
}
        phase: String,
        progress: Double? = nil,
        message: String? = nil,
        itemsProcessed: Int? = nil,
        totalItems: Int? = nil,
        estimatedTimeRemaining: TimeInterval? = nil,
        currentItem: String? = nil,
        error: String? = nil
    ) {
        self.phase = phase
        self.progress = progress
        self.message = message
        self.itemsProcessed = itemsProcessed
        self.totalItems = totalItems
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.currentItem = currentItem
        self.error = error
    }
}

// Updated function signature:
func emitUpdate(config: EmitUpdateConfiguration) async {
    let update = ProgressUpdate(
        phase: config.phase,
        progress: config.progress,
        message: config.message,
        itemsProcessed: config.itemsProcessed,
        totalItems: config.totalItems,
        estimatedTimeRemaining: config.estimatedTimeRemaining,
        currentItem: config.currentItem,
        error: config.error
    )
    // ... rest of the function
}
            estimatedTimeRemaining: estimatedTimeRemaining,
            currentItem: currentItem,
            error: error
        )

        for callback in updateCallbacks {
            await callback(update)
        }
    }

    /// Estimate remaining time
    private func estimateTimeRemaining(progress: Double) -> TimeInterval? {
        guard progress > 0.0 else { return nil }
        let elapsed = Date().timeIntervalSince(startTime)
        let total = elapsed / progress
        return total - elapsed
    }
}

/// MCP Response for streaming progress
public extension ToolCallResponse {
    /// Create response with streaming progress support
    static func streaming(
        toolName: String,
        progressUpdates: [ProgressUpdate]
    ) -> ToolCallResponse {
        // Encode progress updates as result
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        let resultData = try? encoder.encode(progressUpdates)

        return ToolCallResponse(
            status: .success,
            result: resultData,
            toolName: toolName,
            diagnosis: "Tool execution streaming: \(progressUpdates.count) progress updates"
        )
    }

    /// Create progress response
    static func progress(
        toolName: String,
        update: ProgressUpdate
    ) -> ToolCallResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        let resultData = try? encoder.encode(update)

        return ToolCallResponse(
            status: .success,
            result: resultData,
            toolName: toolName,
            diagnosis: "Progress: \(update.message)"
        )
    }
}

/// Extension for tools to stream progress
extension SwiftBuildTool {
    /// Execute build with progress streaming
    public func executeWithStreaming(
        _ request: ToolCallRequest,
        session: SessionContext,
        progressCallback: @escaping @Sendable (ProgressUpdate) async -> Void
    ) async -> ToolCallResponse {
        let tracker = ProgressTracker()
        await tracker.onProgress(progressCallback)

        // Start
        await tracker.startPhase(.initializing, message: "Preparing build environment")

        // Execute (existing logic)
        return await execute(request, session: session)
    }
}

/// Extension for test tool streaming
extension EnhancedSwiftTestTool {
    /// Execute tests with progress streaming
    public func executeWithStreaming(
        _ request: ToolCallRequest,
        session: SessionContext,
        progressCallback: @escaping @Sendable (ProgressUpdate) async -> Void
    ) async -> ToolCallResponse {
        let tracker = ProgressTracker()
        await tracker.onProgress(progressCallback)

        await tracker.startPhase(.initializing, message: "Discovering tests")

        // Execute (existing logic)
        return await execute(request, session: session)
    }
}

/// Extension for digest codebase streaming
extension EnhancedDigestCodebaseTool {
    /// Digest codebase with progress streaming
    public func digestWithStreaming(
        sourceRoots: [String] = ["Sources", "Packages"],
        excludePatterns: [String] = [".build", "*.swiftmodule"],
        progressCallback: @escaping @Sendable (ProgressUpdate) async -> Void
    ) async throws -> CodebaseDigestResult {
        let tracker = ProgressTracker()
        await tracker.onProgress(progressCallback)

        await tracker.startPhase(.initializing, message: "Discovering source files")

        let sourceFiles = try discoverSourceFiles(
            roots: sourceRoots,
            excludePatterns: excludePatterns
        )

        await tracker.updateProgress(
            itemsProcessed: 0,
            totalItems: sourceFiles.count,
            currentItem: "Starting analysis"
        )

        var indexedFiles: [IndexedFile] = []
        var filesByLanguage: [String: Int] = [:]
        var filesByPurpose: [String: Int] = [:]
        var totalSymbols = 0
        var totalLines = 0

        for (index, fileURL) in sourceFiles.enumerated() {
            let relativePath = fileURL.relativePath(from: workingDirectory)

            // Update progress
            await tracker.updateProgress(
                itemsProcessed: index,
                totalItems: sourceFiles.count,
                currentItem: relativePath
            )

            // Index file
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let indexed = try await indexer.indexFile(
                filePath: relativePath,
                content: content
            )

            try await indexer.storeIndexedFile(indexed)

            indexedFiles.append(indexed)
            filesByLanguage[indexed.language, default: 0] += 1
            filesByPurpose[indexed.purpose.rawValue, default: 0] += 1
            totalSymbols += indexed.symbols.count
            totalLines += indexed.lineCount
        }

        // Switch to generating insights
        await tracker.startPhase(.generating, message: "Generating architecture insights with LLM")

        let insights = try await generateArchitectureInsights(
            indexedFiles: indexedFiles,
            sourceRoots: sourceRoots
        )

        // Switch to finalizing
        await tracker.startPhase(.finalizing, message: "Computing health metrics")

        let keyModules = identifyKeyModules(indexedFiles: indexedFiles)
        let healthMetrics = computeHealthMetrics(
            files: indexedFiles,
            symbols: totalSymbols,
            lines: totalLines
        )

        await tracker.completePhase(message: "Codebase digestion complete")

        return CodebaseDigestResult(
            sessionId: UUID().uuidString,
            filesIndexed: indexedFiles.count,
            symbolsExtracted: totalSymbols,
            totalLinesOfCode: totalLines,
            duration: 0,
            filesByLanguage: filesByLanguage,
            filesByPurpose: filesByPurpose,
            keyModules: keyModules,
            architectureInsights: insights,
            healthMetrics: healthMetrics,
            searchEnabled: true,
            embeddingsGenerated: !indexedFiles.isEmpty
        )
    }
}
