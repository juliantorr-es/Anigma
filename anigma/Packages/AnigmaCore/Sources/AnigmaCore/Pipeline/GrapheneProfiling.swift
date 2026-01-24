//
//  GrapheneProfiling.swift
//  AnigmaCore
//
//  Profiling and introspection for Graphene pipelines.
//
//  Provides:
//  - Per-node execution timing
//  - Cache hit/miss statistics
//  - Memory usage tracking
//  - Error traces
//  - Execution history
//

import Foundation

// MARK: - Execution Trace

/// Detailed trace of a graph execution.
public struct ExecutionTrace: Sendable, Codable {
    public let id: UUID
    public let graphId: NodeGraphId
    public let startTime: Date
    public let endTime: Date
    public let status: ProfilingExecutionStatus
    public let nodeTraces: [NodeInstanceId: NodeTrace]
    public let totalCacheHits: Int
    public let totalCacheMisses: Int
    public let peakMemoryBytes: Int
    public let errorInfo: ErrorInfo?

    public var totalDuration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    public init(
        id: UUID = UUID(),
        graphId: NodeGraphId,
        startTime: Date,
        endTime: Date,
        status: ProfilingExecutionStatus,
        nodeTraces: [NodeInstanceId: NodeTrace],
        totalCacheHits: Int,
        totalCacheMisses: Int,
        peakMemoryBytes: Int = 0,
        errorInfo: ErrorInfo? = nil
    ) {
        self.id = id
        self.graphId = graphId
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
        self.nodeTraces = nodeTraces
        self.totalCacheHits = totalCacheHits
        self.totalCacheMisses = totalCacheMisses
        self.peakMemoryBytes = peakMemoryBytes
        self.errorInfo = errorInfo
    }
}

/// Status of an execution for profiling.
public enum ProfilingExecutionStatus: String, Codable, Sendable {
    case success
    case partialSuccess
    case failed
    case cancelled
    case timeout
}

/// Trace for a single node execution.
public struct NodeTrace: Sendable, Codable {
    public let nodeId: NodeInstanceId
    public let nodeTypeId: NodeTypeId
    public let displayName: String
    public let startTime: Date
    public let endTime: Date
    public let wasCached: Bool
    public let executionBackend: ExecutionBackend
    public let inputSizes: [String: Int]
    public let outputSizes: [String: Int]
    public let memoryUsedBytes: Int
    public let errorInfo: ErrorInfo?

    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    public init(
        nodeId: NodeInstanceId,
        nodeTypeId: NodeTypeId,
        displayName: String,
        startTime: Date,
        endTime: Date,
        wasCached: Bool,
        executionBackend: ExecutionBackend,
        inputSizes: [String: Int] = [:],
        outputSizes: [String: Int] = [:],
        memoryUsedBytes: Int = 0,
        errorInfo: ErrorInfo? = nil
    ) {
        self.nodeId = nodeId
        self.nodeTypeId = nodeTypeId
        self.displayName = displayName
        self.startTime = startTime
        self.endTime = endTime
        self.wasCached = wasCached
        self.executionBackend = executionBackend
        self.inputSizes = inputSizes
        self.outputSizes = outputSizes
        self.memoryUsedBytes = memoryUsedBytes
        self.errorInfo = errorInfo
    }
}

/// Backend used for execution.
public enum ExecutionBackend: String, Codable, Sendable {
    case cpu
    case gpu
    case neuralEngine
    case cached
    case skipped
}

/// Error information for traces.
public struct ErrorInfo: Sendable, Codable {
    public let message: String
    public let code: String?
    public let stackTrace: [String]
    public let recoverable: Bool

    public init(
        message: String,
        code: String? = nil,
        stackTrace: [String] = [],
        recoverable: Bool = false
    ) {
        self.message = message
        self.code = code
        self.stackTrace = stackTrace
        self.recoverable = recoverable
    }

    public init(from error: Error) {
        self.message = error.localizedDescription
        self.code = nil
        self.stackTrace = []
        self.recoverable = false
    }
}

// MARK: - Profiler

/// Profiler for Graphene pipeline execution.
public actor GrapheneProfiler {
    public static let shared = GrapheneProfiler()

    private var traces: [UUID: ExecutionTrace] = [:]
    private var activeExecutions: [NodeGraphId: ExecutionBuilder] = [:]
    private var aggregateStats = AggregateStatistics()

    // Configuration
    private var maxTraceHistory: Int = 100
    private var isEnabled: Bool = true

    private init() {}

    // MARK: - Execution Lifecycle

    /// Start tracing an execution.
    public func startExecution(graphId: NodeGraphId) -> UUID {
        guard isEnabled else { return UUID() }

        let traceId = UUID()
        activeExecutions[graphId] = ExecutionBuilder(
            traceId: traceId,
            graphId: graphId,
            startTime: Date()
        )
        return traceId
    }

    /// Record a node starting.
    public func nodeStarted(
        graphId: NodeGraphId,
        nodeId: NodeInstanceId,
        typeId: NodeTypeId,
        displayName: String
    ) {
        guard isEnabled, var builder = activeExecutions[graphId] else { return }
        builder.nodeStarted(nodeId: nodeId, typeId: typeId, displayName: displayName)
        activeExecutions[graphId] = builder
    }

    /// Record a node completing.
    public func nodeCompleted(
        graphId: NodeGraphId,
        nodeId: NodeInstanceId,
        wasCached: Bool,
        backend: ExecutionBackend,
        inputSizes: [String: Int] = [:],
        outputSizes: [String: Int] = [:]
    ) {
        guard isEnabled, var builder = activeExecutions[graphId] else { return }
        builder.nodeCompleted(
            nodeId: nodeId,
            wasCached: wasCached,
            backend: backend,
            inputSizes: inputSizes,
            outputSizes: outputSizes
        )
        activeExecutions[graphId] = builder
    }

    /// Record a node failing.
    public func nodeFailed(
        graphId: NodeGraphId,
        nodeId: NodeInstanceId,
        error: Error
    ) {
        guard isEnabled, var builder = activeExecutions[graphId] else { return }
        builder.nodeFailed(nodeId: nodeId, error: error)
        activeExecutions[graphId] = builder
    }

    /// Finish tracing an execution.
    public func finishExecution(
        graphId: NodeGraphId,
        status: ProfilingExecutionStatus,
        cacheHits: Int,
        cacheMisses: Int
    ) -> ExecutionTrace? {
        guard isEnabled, let builder = activeExecutions[graphId] else { return nil }
        activeExecutions[graphId] = nil

        let trace = builder.build(
            status: status,
            cacheHits: cacheHits,
            cacheMisses: cacheMisses
        )

        // Store trace
        traces[trace.id] = trace

        // Evict old traces if over limit
        while traces.count > maxTraceHistory {
            if let oldest = traces.values.min(by: { $0.startTime < $1.startTime }) {
                traces[oldest.id] = nil
            }
        }

        // Update aggregate stats
        updateAggregateStats(with: trace)

        return trace
    }

    // MARK: - Queries

    /// Get a trace by ID.
    public func getTrace(_ id: UUID) -> ExecutionTrace? {
        traces[id]
    }

    /// Get recent traces for a graph.
    public func recentTraces(for graphId: NodeGraphId, limit: Int = 10) -> [ExecutionTrace] {
        traces.values
            .filter { $0.graphId == graphId }
            .sorted { $0.startTime > $1.startTime }
            .prefix(limit)
            .map { $0 }
    }

    /// Get all recent traces.
    public func allRecentTraces(limit: Int = 50) -> [ExecutionTrace] {
        traces.values
            .sorted { $0.startTime > $1.startTime }
            .prefix(limit)
            .map { $0 }
    }

    /// Get aggregate statistics.
    public func getAggregateStats() -> AggregateStatistics {
        aggregateStats
    }

    /// Get node performance summary.
    public func nodePerformanceSummary(typeId: NodeTypeId) -> NodePerformanceSummary {
        var durations: [TimeInterval] = []
        var cacheHits = 0
        var cacheMisses = 0
        var errors = 0

        for trace in traces.values {
            for nodeTrace in trace.nodeTraces.values where nodeTrace.nodeTypeId == typeId {
                durations.append(nodeTrace.duration)
                if nodeTrace.wasCached {
                    cacheHits += 1
                } else {
                    cacheMisses += 1
                }
                if nodeTrace.errorInfo != nil {
                    errors += 1
                }
            }
        }

        return NodePerformanceSummary(
            typeId: typeId,
            executionCount: durations.count,
            avgDuration: durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count),
            minDuration: durations.min() ?? 0,
            maxDuration: durations.max() ?? 0,
            cacheHitRate: cacheHits + cacheMisses > 0 ? Double(cacheHits) / Double(cacheHits + cacheMisses) : 0,
            errorRate: !durations.isEmpty ? Double(errors) / Double(durations.count) : 0
        )
    }

    // MARK: - Configuration

    /// Enable or disable profiling.
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    /// Set max trace history.
    public func setMaxHistory(_ max: Int) {
        maxTraceHistory = max
    }

    /// Clear all traces.
    public func clearTraces() {
        traces.removeAll()
        aggregateStats = AggregateStatistics()
    }

    // MARK: - Private

    private func updateAggregateStats(with trace: ExecutionTrace) {
        aggregateStats.totalExecutions += 1
        aggregateStats.totalDuration += trace.totalDuration
        aggregateStats.totalCacheHits += trace.totalCacheHits
        aggregateStats.totalCacheMisses += trace.totalCacheMisses

        switch trace.status {
        case .success:
            aggregateStats.successCount += 1
        case .partialSuccess:
            aggregateStats.partialSuccessCount += 1
        case .failed:
            aggregateStats.failureCount += 1
        case .cancelled:
            aggregateStats.cancelledCount += 1
        case .timeout:
            aggregateStats.timeoutCount += 1
        }

        // Track slowest nodes
        for nodeTrace in trace.nodeTraces.values {
            aggregateStats.nodeDurations[nodeTrace.nodeTypeId, default: []].append(nodeTrace.duration)
        }
    }
}

/// Builder for constructing execution traces.
private struct ExecutionBuilder {
    let traceId: UUID
    let graphId: NodeGraphId
    let startTime: Date
    var nodeBuilders: [NodeInstanceId: NodeTraceBuilder] = [:]

    struct NodeTraceBuilder {
        let nodeId: NodeInstanceId
        let typeId: NodeTypeId
        let displayName: String
        let startTime: Date
        var endTime: Date?
        var wasCached: Bool = false
        var backend: ExecutionBackend = .cpu
        var inputSizes: [String: Int] = [:]
        var outputSizes: [String: Int] = [:]
        var errorInfo: ErrorInfo?
    }

    mutating func nodeStarted(nodeId: NodeInstanceId, typeId: NodeTypeId, displayName: String) {
        nodeBuilders[nodeId] = NodeTraceBuilder(
            nodeId: nodeId,
            typeId: typeId,
            displayName: displayName,
            startTime: Date()
        )
    }

    mutating func nodeCompleted(
        nodeId: NodeInstanceId,
        wasCached: Bool,
        backend: ExecutionBackend,
        inputSizes: [String: Int],
        outputSizes: [String: Int]
    ) {
        guard var builder = nodeBuilders[nodeId] else { return }
        builder.endTime = Date()
        builder.wasCached = wasCached
        builder.backend = backend
        builder.inputSizes = inputSizes
        builder.outputSizes = outputSizes
        nodeBuilders[nodeId] = builder
    }

    mutating func nodeFailed(nodeId: NodeInstanceId, error: Error) {
        guard var builder = nodeBuilders[nodeId] else { return }
        builder.endTime = Date()
        builder.errorInfo = ErrorInfo(from: error)
        nodeBuilders[nodeId] = builder
    }

    func build(status: ProfilingExecutionStatus, cacheHits: Int, cacheMisses: Int) -> ExecutionTrace {
        var nodeTraces: [NodeInstanceId: NodeTrace] = [:]

        for (nodeId, builder) in nodeBuilders {
            nodeTraces[nodeId] = NodeTrace(
                nodeId: builder.nodeId,
                nodeTypeId: builder.typeId,
                displayName: builder.displayName,
                startTime: builder.startTime,
                endTime: builder.endTime ?? Date(),
                wasCached: builder.wasCached,
                executionBackend: builder.backend,
                inputSizes: builder.inputSizes,
                outputSizes: builder.outputSizes,
                errorInfo: builder.errorInfo
            )
        }

        return ExecutionTrace(
            id: traceId,
            graphId: graphId,
            startTime: startTime,
            endTime: Date(),
            status: status,
            nodeTraces: nodeTraces,
            totalCacheHits: cacheHits,
            totalCacheMisses: cacheMisses
        )
    }
}

// MARK: - Statistics Types

/// Aggregate statistics across all executions.
public struct AggregateStatistics: Sendable {
    public var totalExecutions: Int = 0
    public var totalDuration: TimeInterval = 0
    public var totalCacheHits: Int = 0
    public var totalCacheMisses: Int = 0
    public var successCount: Int = 0
    public var partialSuccessCount: Int = 0
    public var failureCount: Int = 0
    public var cancelledCount: Int = 0
    public var timeoutCount: Int = 0
    public var nodeDurations: [NodeTypeId: [TimeInterval]] = [:]

    public var avgDuration: TimeInterval {
        totalExecutions > 0 ? totalDuration / Double(totalExecutions) : 0
    }

    public var cacheHitRate: Double {
        let total = totalCacheHits + totalCacheMisses
        return total > 0 ? Double(totalCacheHits) / Double(total) : 0
    }

    public var successRate: Double {
        totalExecutions > 0 ? Double(successCount) / Double(totalExecutions) : 0
    }
}

/// Performance summary for a node type.
public struct NodePerformanceSummary: Sendable {
    public let typeId: NodeTypeId
    public let executionCount: Int
    public let avgDuration: TimeInterval
    public let minDuration: TimeInterval
    public let maxDuration: TimeInterval
    public let cacheHitRate: Double
    public let errorRate: Double
}

// MARK: - Trace Visualization

/// Generates a visual representation of an execution trace.
public struct TraceVisualizer {

    /// Generate a text-based timeline visualization.
    public static func generateTimeline(_ trace: ExecutionTrace) -> String {
        var output = "Execution Trace: \(trace.id)\n"
        output += "Graph: \(trace.graphId.rawValue)\n"
        output += "Duration: \(String(format: "%.2f", trace.totalDuration * 1000))ms\n"
        output += "Status: \(trace.status.rawValue)\n"
        output += "Cache: \(trace.totalCacheHits) hits, \(trace.totalCacheMisses) misses\n"
        output += String(repeating: "-", count: 60) + "\n"

        // Sort nodes by start time
        let sortedNodes = trace.nodeTraces.values.sorted { $0.startTime < $1.startTime }

        for nodeTrace in sortedNodes {
            let durationMs = nodeTrace.duration * 1000
            let cached = nodeTrace.wasCached ? " [cached]" : ""
            let error = nodeTrace.errorInfo != nil ? " [ERROR]" : ""
            output += String(format: "  %-30s %6.2fms  %s%s%s\n",
                           (nodeTrace.displayName as NSString).utf8String!,
                           durationMs,
                           nodeTrace.executionBackend.rawValue,
                           cached,
                           error)
        }

        return output
    }

    /// Generate a JSON representation.
    public static func generateJSON(_ trace: ExecutionTrace) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(trace)
    }
}

// MARK: - Performance Advisor

/// Provides optimization suggestions based on execution traces.
public struct PerformanceAdvisor {

    public static func analyze(_ traces: [ExecutionTrace]) -> [Suggestion] {
        var suggestions: [Suggestion] = []

        // Analyze cache effectiveness
        let totalCacheHits = traces.reduce(0) { $0 + $1.totalCacheHits }
        let totalCacheMisses = traces.reduce(0) { $0 + $1.totalCacheMisses }
        let cacheHitRate = (totalCacheHits + totalCacheMisses) > 0
            ? Double(totalCacheHits) / Double(totalCacheHits + totalCacheMisses)
            : 0

        if cacheHitRate < 0.3 && totalCacheMisses > 10 {
            suggestions.append(Suggestion(
                type: .caching,
                severity: .medium,
                message: "Low cache hit rate (\(String(format: "%.1f", cacheHitRate * 100))%). Consider increasing cache size or adjusting cache policies."
            ))
        }

        // Find slow nodes
        var nodeDurations: [NodeTypeId: [TimeInterval]] = [:]
        for trace in traces {
            for nodeTrace in trace.nodeTraces.values {
                nodeDurations[nodeTrace.nodeTypeId, default: []].append(nodeTrace.duration)
            }
        }

        for (typeId, durations) in nodeDurations {
            let avg = durations.reduce(0, +) / Double(durations.count)
            if avg > 1.0 { // > 1 second average
                suggestions.append(Suggestion(
                    type: .performance,
                    severity: .high,
                    message: "Node '\(typeId.name)' averages \(String(format: "%.2f", avg))s. Consider optimization or caching."
                ))
            }
        }

        // Check for frequent errors
        var errorCounts: [NodeTypeId: Int] = [:]
        for trace in traces {
            for nodeTrace in trace.nodeTraces.values where nodeTrace.errorInfo != nil {
                errorCounts[nodeTrace.nodeTypeId, default: 0] += 1
            }
        }

        for (typeId, count) in errorCounts where count > 3 {
            suggestions.append(Suggestion(
                type: .reliability,
                severity: .high,
                message: "Node '\(typeId.name)' has failed \(count) times. Review error handling and inputs."
            ))
        }

        return suggestions.sorted { $0.severity.rawValue > $1.severity.rawValue }
    }

    public struct Suggestion: Sendable {
        public let type: SuggestionType
        public let severity: Severity
        public let message: String
    }

    public enum SuggestionType: String, Sendable {
        case caching
        case performance
        case reliability
        case memory
        case architecture
    }

    public enum Severity: Int, Sendable {
        case low = 1
        case medium = 2
        case high = 3
    }
}
