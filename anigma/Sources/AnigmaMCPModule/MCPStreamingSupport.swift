//
//  MCPStreamingSupport.swift
//  AnigmaMCPModule
//
//  Infrastructure for streaming tool progress over MCP protocol.
//  Enables real-time feedback for long-running operations.
//

import AnigmaPrimitives
import Foundation
import HarmoniaV2Surface

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
    private var itemsProcessedCount: Int = 0
    private var totalItemsCount: Int = 0

    public init() {}

    /// Register callback for progress updates
    public func onProgress(_ callback: @escaping @Sendable (ProgressUpdate) async -> Void) {
        updateCallbacks.append(callback)
    }

    /// Start phase
    public func startPhase(_ phase: ToolPhase, message: String) async {
        currentPhase = phase
        await emitUpdate(message: message)
    }

    /// Update progress percentage
    public func updateProgress(_ progress: Double, message: String? = nil) async {
        await emitUpdate(progress: progress, message: message)
    }

    /// Compatibility overload for detailed progress tracking
    public func updateProgress(itemsProcessed: Int, totalItems: Int, currentItem: String? = nil) async {
        itemsProcessedCount = itemsProcessed
        totalItemsCount = totalItems
        let progress = totalItems > 0 ? Double(itemsProcessed) / Double(totalItems) : 0.0
        await emitUpdate(progress: progress, message: currentItem ?? "Processing...", currentItem: currentItem)
    }

    /// Update items processed
    public func updateItems(processed: Int, total: Int? = nil, message: String? = nil) async {
        itemsProcessedCount = processed
        if let total = total {
            totalItemsCount = total
        }
        
        let progress = totalItemsCount > 0 ? Double(itemsProcessedCount) / Double(totalItemsCount) : 0.0
        await emitUpdate(progress: progress, message: message)
    }

    /// Mark the current phase as completed.
    public func completePhase(message: String) async {
        currentPhase = .complete
        await emitUpdate(progress: 1.0, message: message)
    }

    /// Mark the current phase as failed.
    public func error(_ message: String) async {
        currentPhase = .error
        await emitUpdate(progress: 1.0, message: message, error: message)
    }

    /// Emit an update to all registered callbacks
    public func emitUpdate(
        progress: Double = 0.0,
        message: String? = nil,
        currentItem: String? = nil,
        error: String? = nil
    ) async {
        let update = ProgressUpdate(
            phase: currentPhase,
            progress: progress,
            message: message ?? "Executing...",
            itemsProcessed: itemsProcessedCount,
            totalItems: totalItemsCount > 0 ? totalItemsCount : nil,
            estimatedTimeRemaining: estimateTimeRemaining(progress: progress),
            currentItem: currentItem,
            error: error
        )

        for callback in updateCallbacks {
            await callback(update)
        }
    }

    /// Estimate remaining time
    private func estimateTimeRemaining(progress: Double) -> TimeInterval? {
        guard progress > 0.0 && progress < 1.0 else { return nil }
        let elapsed = Date().timeIntervalSince(startTime)
        let total = elapsed / progress
        return total - elapsed
    }
}

/// Emit update configuration for batching
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
