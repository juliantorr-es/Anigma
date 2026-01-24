//
//  GrapheneStreaming.swift
//  AnigmaCore
//
//  Streaming support for Graphene nodes.
//
//  Enables:
//  - AsyncSequence-based streaming outputs
//  - Partial result delivery during execution
//  - Progressive refinement patterns
//  - Streaming LLM token output
//

import Foundation

// MARK: - Streaming Port Types

/// A port that produces values over time.
public struct StreamingTextPort: PortType, Sendable {
    public static var typeId: String { "StreamingText" }
    public static var displayName: String { "Streaming Text" }

    public let streamId: String

    public init(streamId: String = UUID().uuidString) {
        self.streamId = streamId
    }
}

/// A chunk of streaming text data.
public struct TextChunk: Sendable {
    public let text: String
    public let isFinal: Bool
    public let tokenCount: Int
    public let timestamp: Date

    public init(text: String, isFinal: Bool = false, tokenCount: Int = 0) {
        self.text = text
        self.isFinal = isFinal
        self.tokenCount = tokenCount
        self.timestamp = Date()
    }
}

// MARK: - Streaming Executor Protocol

/// Protocol for node executors that support streaming output.
public protocol StreamingNodeExecutor: NodeExecutor {
    /// Execute with streaming output.
    func executeStreaming(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) -> AsyncThrowingStream<StreamingOutput, Error>
}

/// Output from a streaming node.
public enum StreamingOutput: Sendable {
    case chunk(portName: String, value: AnyPortValue, progress: Double)
    case final(outputs: [String: AnyPortValue])
    case progress(message: String, percent: Double)
    case error(Error)
}

// MARK: - Streaming Manager

/// Manages active streams during graph execution.
public actor StreamingManager {
    private var activeStreams: [String: StreamState] = [:]
    private var subscribers: [String: [StreamSubscriber]] = [:]

    public init() {}

    /// Create a new stream.
    public func createStream(id: String) {
        activeStreams[id] = StreamState(id: id)
    }

    /// Emit a chunk to a stream.
    public func emit(streamId: String, chunk: TextChunk) {
        guard var state = activeStreams[streamId] else { return }
        state.chunks.append(chunk)
        state.totalText += chunk.text
        activeStreams[streamId] = state

        // Notify subscribers
        if let subs = subscribers[streamId] {
            for sub in subs {
                sub.onChunk(chunk)
            }
        }
    }

    /// Close a stream.
    public func close(streamId: String) {
        if var state = activeStreams[streamId] {
            state.isClosed = true
            activeStreams[streamId] = state

            // Notify subscribers
            if let subs = subscribers[streamId] {
                for sub in subs {
                    sub.onComplete()
                }
            }
        }
    }

    /// Get the accumulated text for a stream.
    public func accumulatedText(streamId: String) -> String {
        activeStreams[streamId]?.totalText ?? ""
    }

    /// Subscribe to a stream.
    public func subscribe(streamId: String, subscriber: StreamSubscriber) {
        subscribers[streamId, default: []].append(subscriber)
    }

    /// Check if a stream is active.
    public func isActive(streamId: String) -> Bool {
        guard let state = activeStreams[streamId] else { return false }
        return !state.isClosed
    }

    /// Clean up completed streams.
    public func cleanup() {
        activeStreams = activeStreams.filter { !$0.value.isClosed }
        subscribers = subscribers.filter { activeStreams[$0.key] != nil }
    }
}

/// Internal state for a stream.
private struct StreamState {
    let id: String
    var chunks: [TextChunk] = []
    var totalText: String = ""
    var isClosed: Bool = false
}

/// Subscriber interface for streams.
public protocol StreamSubscriber: Sendable {
    func onChunk(_ chunk: TextChunk)
    func onComplete()
    func onError(_ error: Error)
}

// MARK: - Streaming LLM Executor

/// Executor for streaming LLM text generation.
public struct StreamingTextGenerationExecutor: StreamingNodeExecutor {
    private let streamingManager: StreamingManager

    public init(streamingManager: StreamingManager) {
        self.streamingManager = streamingManager
    }

    public func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        // Non-streaming execution: collect all chunks and return final result
        var fullText = ""
        let initialTokenCount = 0

        for try await output in executeStreaming(
            descriptor: descriptor,
            instance: instance,
            inputs: inputs,
            context: context
        ) {
            switch output {
            case .chunk(let portName, let value, _):
                if portName == "response", let text = value.as(TextPort.self)?.value {
                    fullText += text
                }
            case .final(let outputs):
                return outputs
            case .progress:
                continue
            case .error(let error):
                throw error
            }
        }

        return [
            "response": AnyPortValue(TextPort(fullText)),
"tokens": AnyPortValue(NumberPort(Double(initialTokenCount)))
        ]
    }

    public func executeStreaming(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) -> AsyncThrowingStream<StreamingOutput, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
_ = inputs["prompt"]?.as(TextPort.self)?.value ?? ""
        _ = inputs["systemPrompt"]?.as(TextPort.self)?.value
        _ = instance.parameterValues["maxTokens"]?.intValue ?? 512
        _ = instance.parameterValues["temperature"]?.doubleValue ?? 0.7

                    // Create stream
                    let streamId = UUID().uuidString
                    await streamingManager.createStream(id: streamId)

                    // Simulate streaming LLM output
                    // In real implementation, this would call InferencePlane with streaming
                    let words = "This is a simulated streaming response that demonstrates how the Graphene pipeline handles streaming LLM output. Each word is delivered as a separate token, allowing the UI to show real-time generation progress.".split(separator: " ")

                    var fullResponse = ""
                    var streamingTokenCount = 0

                    for (index, word) in words.enumerated() {
                        // Check for cancellation
                        if await context.cancellationToken.isCancelled {
                            continuation.finish(throwing: GrapheneError.executionFailed(
                                nodeId: instance.id,
                                reason: "Cancelled"
                            ))
                            return
                        }

                        let text = (index == 0 ? "" : " ") + String(word)
                        fullResponse += text
                        streamingTokenCount += 1

                        let chunk = TextChunk(text: text, tokenCount: 1)
                        await streamingManager.emit(streamId: streamId, chunk: chunk)

                        let progress = Double(index + 1) / Double(words.count)
                        continuation.yield(.chunk(
                            portName: "response",
                            value: AnyPortValue(TextPort(text)),
                            progress: progress
                        ))

                        // Simulate token generation delay
                        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
                    }

                    await streamingManager.close(streamId: streamId)

                    continuation.yield(.final(outputs: [
                        "response": AnyPortValue(TextPort(fullResponse)),
"tokens": AnyPortValue(NumberPort(Double(0)))
                    ]))

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Streaming Graph Execution

extension GrapheneEngine {
    /// Execute a graph with streaming support.
    public func executeStreaming(
        graph: NodeGraph,
        inputs: [String: AnyPortValue] = [:],
        options: ExecutionOptions = .default
    ) -> AsyncThrowingStream<StreamingGraphOutput, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Execute with streaming callbacks
                    let result = try await self.execute(
                        graph: graph,
                        inputs: inputs,
                        options: options
                    )

                    continuation.yield(.complete(result))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

/// Output from streaming graph execution.
public enum StreamingGraphOutput: Sendable {
    case nodeStarted(nodeId: NodeInstanceId, nodeName: String)
    case nodeProgress(nodeId: NodeInstanceId, progress: Double, message: String?)
    case nodeChunk(nodeId: NodeInstanceId, portName: String, value: AnyPortValue)
    case nodeCompleted(nodeId: NodeInstanceId, executionTime: TimeInterval)
    case complete(GraphExecutionResult)
}

// MARK: - Stream Collector

/// Collects streaming output into a final result.
public actor StreamCollector {
    private var chunks: [String: [AnyPortValue]] = [:]
    private var isComplete = false

    public init() {}

    /// Add a chunk for a port.
    public func addChunk(portName: String, value: AnyPortValue) {
        chunks[portName, default: []].append(value)
    }

    /// Mark as complete.
    public func complete() {
        isComplete = true
    }

    /// Get accumulated text for a port.
    public func accumulatedText(portName: String) -> String {
        chunks[portName]?.compactMap { $0.as(TextPort.self)?.value }.joined() ?? ""
    }

    /// Check if complete.
    public func checkComplete() -> Bool {
        isComplete
    }
}

// MARK: - Progressive Refinement

/// Configuration for progressive refinement execution.
public struct ProgressiveRefinementConfig: Sendable {
    /// Number of refinement passes.
    public let passes: Int

    /// Quality level per pass (0.0 to 1.0).
    public let qualityLevels: [Double]

    /// Delay between passes.
    public let delayBetweenPasses: TimeInterval

    public init(
        passes: Int = 3,
        qualityLevels: [Double] = [0.3, 0.6, 1.0],
        delayBetweenPasses: TimeInterval = 0.1
    ) {
        self.passes = passes
        self.qualityLevels = qualityLevels
        self.delayBetweenPasses = delayBetweenPasses
    }

    public static let quick = ProgressiveRefinementConfig(passes: 2, qualityLevels: [0.5, 1.0])
    public static let detailed = ProgressiveRefinementConfig(passes: 4, qualityLevels: [0.25, 0.5, 0.75, 1.0])
}

/// Result of progressive refinement.
public struct RefinementResult: Sendable {
    public let pass: Int
    public let quality: Double
    public let outputs: [String: AnyPortValue]
    public let executionTime: TimeInterval
}
