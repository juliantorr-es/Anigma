//
//  GrapheneVerticalSlice.swift
//  AnigmaCore
//
//  Vertical slice demonstrating end-to-end Graphene pipeline.
//
//  This file provides:
//  - A working Text→Prompt→LLM→Output pipeline
//  - Factory methods for common AI pipelines
//  - Integration tests for the full stack
//  - Example usage patterns
//

import Foundation

// MARK: - Pipeline Factory

/// Factory for creating common AI pipelines.
public struct PipelineFactory {
    private let registry: NodeRegistry
    private let engine: GrapheneEngine

    public init(registry: NodeRegistry = .shared, engine: GrapheneEngine? = nil) {
        self.registry = registry
        self.engine = engine ?? GrapheneEngine(registry: registry)
    }

    // MARK: - Simple Text Generation Pipeline

    /// Create a simple text generation pipeline.
    /// Input: text prompt → Output: generated response
    public func createSimpleTextGeneration(
        systemPrompt: String = "You are a helpful assistant.",
        model: String = "llama-3.2-3b",
        maxTokens: Int = 512,
        temperature: Double = 0.7
    ) async throws -> NodeGraph {
        var graph = NodeGraph(name: "Simple Text Generation")

        // 1. Graph Input - receives the user prompt
        let inputNode = NodeInstance(
            typeId: NodeTypeId(category: "IO", name: "GraphInput"),
            displayName: "User Prompt",
            parameterValues: [
                "inputName": .text("prompt"),
                "dataType": .choice("text", options: [])
            ],
            position: CGPoint(x: 100, y: 200)
        )
        graph.addNode(inputNode)

        // 2. System Prompt - defines LLM behavior
        let systemNode = NodeInstance(
            typeId: NodeTypeId(category: "Primitives/Prompt", name: "SystemPrompt"),
            displayName: "System Prompt",
            parameterValues: [
                "prompt": .text(systemPrompt)
            ],
            position: CGPoint(x: 100, y: 100)
        )
        graph.addNode(systemNode)

        // 3. LLM Text Generation
        let llmNode = NodeInstance(
            typeId: NodeTypeId(category: "AI/LLM", name: "TextGeneration"),
            displayName: "LLM",
            parameterValues: [
                "model": .model(identifier: model),
                "maxTokens": .integer(maxTokens),
                "temperature": .number(temperature),
                "localOnly": .boolean(true)
            ],
            position: CGPoint(x: 400, y: 150)
        )
        graph.addNode(llmNode)

        // 4. Graph Output
        let outputNode = NodeInstance(
            typeId: NodeTypeId(category: "IO", name: "GraphOutput"),
            displayName: "Response",
            parameterValues: [
                "outputName": .text("response")
            ],
            position: CGPoint(x: 700, y: 150)
        )
        graph.addNode(outputNode)

        // Connect nodes
        _ = graph.connect(
            from: inputNode.id, port: "value",
            to: llmNode.id, port: "prompt"
        )
        _ = graph.connect(
            from: systemNode.id, port: "prompt",
            to: llmNode.id, port: "systemPrompt"
        )
        _ = graph.connect(
            from: llmNode.id, port: "response",
            to: outputNode.id, port: "value"
        )

        // Expose interface
        graph.exposedInputs["prompt"] = PortId(
            nodeId: inputNode.id,
            portName: "value",
            isInput: false
        )
        graph.exposedOutputs["response"] = PortId(
            nodeId: llmNode.id,
            portName: "response",
            isInput: false
        )

        return graph
    }

    // MARK: - Summarization Pipeline

    /// Create a text summarization pipeline.
    public func createSummarization(
        style: String = "concise",
        model: String = "llama-3.2-3b"
    ) async throws -> NodeGraph {
        var graph = NodeGraph(name: "Summarization")

        // 1. Input
        let inputNode = NodeInstance(
            typeId: NodeTypeId(category: "IO", name: "GraphInput"),
            displayName: "Text to Summarize",
            parameterValues: [
                "inputName": .text("text"),
                "dataType": .choice("text", options: [])
            ]
        )
        graph.addNode(inputNode)

        // 2. Build JSON with the text as a variable
        let jsonNode = NodeInstance(
            typeId: NodeTypeId(category: "Primitives/Transform", name: "JSONBuild"),
            displayName: "Build Variables",
            parameterValues: [
                "key1": .text("text")
            ]
        )
        graph.addNode(jsonNode)

        // 3. Prompt Template
        let promptTemplate: String
        switch style {
        case "bullets":
            promptTemplate = "Summarize the following text as bullet points:\n\n{{text}}\n\nBullet point summary:"
        case "one_sentence":
            promptTemplate = "Summarize the following text in one sentence:\n\n{{text}}\n\nOne sentence summary:"
        case "detailed":
            promptTemplate = "Provide a detailed summary of the following text, preserving key points and nuances:\n\n{{text}}\n\nDetailed summary:"
        default:
            promptTemplate = "Summarize the following text concisely:\n\n{{text}}\n\nSummary:"
        }

        let templateNode = NodeInstance(
            typeId: NodeTypeId(category: "Primitives/Prompt", name: "PromptTemplate"),
            displayName: "Summarize Prompt",
            parameterValues: [
                "template": .text(promptTemplate),
                "delimiterStart": .text("{{"),
                "delimiterEnd": .text("}}")
            ]
        )
        graph.addNode(templateNode)

        // 4. LLM
        let llmNode = NodeInstance(
            typeId: NodeTypeId(category: "AI/LLM", name: "TextGeneration"),
            displayName: "Summarizer LLM",
            parameterValues: [
                "model": .model(identifier: model),
                "maxTokens": .integer(300),
                "temperature": .number(0.3) // Lower temp for summarization
            ]
        )
        graph.addNode(llmNode)

        // 5. Output
        let outputNode = NodeInstance(
            typeId: NodeTypeId(category: "IO", name: "GraphOutput"),
            displayName: "Summary",
            parameterValues: [
                "outputName": .text("summary")
            ]
        )
        graph.addNode(outputNode)

        // Connect
        _ = graph.connect(from: inputNode.id, port: "value", to: jsonNode.id, port: "value1")
        _ = graph.connect(from: jsonNode.id, port: "json", to: templateNode.id, port: "variables")
        _ = graph.connect(from: templateNode.id, port: "prompt", to: llmNode.id, port: "prompt")
        _ = graph.connect(from: llmNode.id, port: "response", to: outputNode.id, port: "value")

        return graph
    }

    // MARK: - RAG Pipeline

    /// Create a RAG (Retrieval-Augmented Generation) pipeline.
    public func createRAGPipeline(
        topK: Int = 3,
        model: String = "llama-3.2-3b",
        embedModel: String = "nomic-embed-text"
    ) async throws -> NodeGraph {
        var graph = NodeGraph(name: "RAG Pipeline")

        // 1. Query Input
        let queryInput = NodeInstance(
            typeId: NodeTypeId(category: "IO", name: "GraphInput"),
            displayName: "Query",
            parameterValues: [
                "inputName": .text("query"),
                "dataType": .choice("text", options: [])
            ]
        )
        graph.addNode(queryInput)

        // 2. Documents Input
        let docsInput = NodeInstance(
            typeId: NodeTypeId(category: "IO", name: "GraphInput"),
            displayName: "Documents",
            parameterValues: [
                "inputName": .text("documents"),
                "dataType": .choice("json", options: [])
            ]
        )
        graph.addNode(docsInput)

        // 3. Document Chunker
        let chunkerNode = NodeInstance(
            typeId: NodeTypeId(category: "AI/RAG", name: "DocumentChunker"),
            displayName: "Chunk Documents",
            parameterValues: [
                "strategy": .choice("semantic", options: []),
                "chunkSize": .integer(512),
                "overlap": .integer(50)
            ]
        )
        graph.addNode(chunkerNode)

        // 4. Semantic Search
        let searchNode = NodeInstance(
            typeId: NodeTypeId(category: "AI/Embedding", name: "SemanticSearch"),
            displayName: "Find Relevant Chunks",
            parameterValues: [
                "model": .model(identifier: embedModel),
                "topK": .integer(topK),
                "threshold": .number(0.5)
            ]
        )
        graph.addNode(searchNode)

        // 5. Context Builder (prompt template)
        let contextTemplate = """
        Answer the question based on the following context:

        Context:
        {{context}}

        Question: {{query}}

        Answer:
        """
        let contextNode = NodeInstance(
            typeId: NodeTypeId(category: "Primitives/Prompt", name: "PromptTemplate"),
            displayName: "Build RAG Prompt",
            parameterValues: [
                "template": .text(contextTemplate)
            ]
        )
        graph.addNode(contextNode)

        // 6. LLM
        let llmNode = NodeInstance(
            typeId: NodeTypeId(category: "AI/LLM", name: "TextGeneration"),
            displayName: "Answer Generator",
            parameterValues: [
                "model": .model(identifier: model),
                "maxTokens": .integer(500),
                "temperature": .number(0.5)
            ]
        )
        graph.addNode(llmNode)

        // 7. Output
        let outputNode = NodeInstance(
            typeId: NodeTypeId(category: "IO", name: "GraphOutput"),
            displayName: "Answer",
            parameterValues: [
                "outputName": .text("answer")
            ]
        )
        graph.addNode(outputNode)

        // Connect (simplified - real impl would need more intermediate nodes)
        _ = graph.connect(from: docsInput.id, port: "value", to: chunkerNode.id, port: "document")
        _ = graph.connect(from: queryInput.id, port: "value", to: searchNode.id, port: "query")
        _ = graph.connect(from: chunkerNode.id, port: "chunks", to: searchNode.id, port: "corpus")
        _ = graph.connect(from: contextNode.id, port: "prompt", to: llmNode.id, port: "prompt")
        _ = graph.connect(from: llmNode.id, port: "response", to: outputNode.id, port: "value")

        return graph
    }

    // MARK: - Audio Transcription Pipeline

    /// Create an audio transcription and summarization pipeline.
    public func createTranscribeAndSummarize(
        asrModel: String = "whisper-large-v3",
        llmModel: String = "llama-3.2-3b"
    ) async throws -> NodeGraph {
        var graph = NodeGraph(name: "Transcribe and Summarize")

        // 1. Audio Input
        let audioInput = NodeInstance(
            typeId: NodeTypeId(category: "IO", name: "GraphInput"),
            displayName: "Audio File",
            parameterValues: [
                "inputName": .text("audio"),
                "dataType": .choice("audio", options: [])
            ]
        )
        graph.addNode(audioInput)

        // 2. Speech to Text
        let asrNode = NodeInstance(
            typeId: NodeTypeId(category: "AI/Audio", name: "SpeechToText"),
            displayName: "Transcribe",
            parameterValues: [
                "model": .model(identifier: asrModel),
                "language": .choice("auto", options: [])
            ]
        )
        graph.addNode(asrNode)

        // 3. Summarization (reuse summarize subgraph concept)
        let summarizeNode = NodeInstance(
            typeId: NodeTypeId(category: "AI/LLM", name: "Summarize"),
            displayName: "Summarize Transcript",
            parameterValues: [
                "model": .model(identifier: llmModel),
                "style": .choice("concise", options: []),
                "maxLength": .integer(200)
            ]
        )
        graph.addNode(summarizeNode)

        // 4. Transcript Output
        let transcriptOutput = NodeInstance(
            typeId: NodeTypeId(category: "IO", name: "GraphOutput"),
            displayName: "Full Transcript",
            parameterValues: [
                "outputName": .text("transcript")
            ]
        )
        graph.addNode(transcriptOutput)

        // 5. Summary Output
        let summaryOutput = NodeInstance(
            typeId: NodeTypeId(category: "IO", name: "GraphOutput"),
            displayName: "Summary",
            parameterValues: [
                "outputName": .text("summary")
            ]
        )
        graph.addNode(summaryOutput)

        // Connect
        _ = graph.connect(from: audioInput.id, port: "value", to: asrNode.id, port: "audio")
        _ = graph.connect(from: asrNode.id, port: "text", to: summarizeNode.id, port: "text")
        _ = graph.connect(from: asrNode.id, port: "text", to: transcriptOutput.id, port: "value")
        _ = graph.connect(from: summarizeNode.id, port: "summary", to: summaryOutput.id, port: "value")

        return graph
    }
}

// MARK: - Graph Executor Runner

/// High-level runner for executing pipelines (direct GrapheneEngine interaction).
public actor GraphExecutorRunner {
    private let engine: GrapheneEngine
    private let profiler: GrapheneProfiler
    private let streamingManager: StreamingManager

    public init(
        engine: GrapheneEngine? = nil,
        profiler: GrapheneProfiler = .shared
    ) {
        self.engine = engine ?? GrapheneEngine()
        self.profiler = profiler
        self.streamingManager = StreamingManager()
    }

    /// Run a pipeline with text input and get text output.
    public func runTextToText(
        graph: NodeGraph,
        input: String,
        inputName: String = "prompt",
        outputName: String = "response"
    ) async throws -> String {
        let inputs: [String: AnyPortValue] = [
            inputName: AnyPortValue(TextPort(input))
        ]

        let result = try await engine.execute(graph: graph, inputs: inputs)

        guard let output = result.outputs[outputName]?.as(TextPort.self)?.value else {
            throw PipelineError.missingOutput(outputName)
        }

        return output
    }

    /// Run a pipeline with streaming output.
    public func runStreaming(
        graph: NodeGraph,
        inputs: [String: AnyPortValue]
    ) async -> ThrowingTransformSequence<AsyncThrowingStream<StreamingGraphOutput, Error>, PipelineStreamEvent> {
        let stream = await engine.executeStreaming(graph: graph, inputs: inputs)
        return ThrowingTransformSequence(base: stream) { output -> PipelineStreamEvent in
            switch output {
            case .nodeStarted(let nodeId, let name):
                return .nodeStarted(nodeId: nodeId, name: name)
            case .nodeProgress(let nodeId, let progress, let message):
                return .progress(nodeId: nodeId, progress: progress, message: message)
            case .nodeChunk(let nodeId, let portName, let value):
                return .chunk(nodeId: nodeId, portName: portName, value: value)
            case .nodeCompleted(let nodeId, let time):
                return .nodeCompleted(nodeId: nodeId, time: time)
            case .complete(let result):
                return .complete(result: result)
            }
        }
    }

    /// Run with full profiling.
    public func runWithProfiling(
        graph: NodeGraph,
        inputs: [String: AnyPortValue]
    ) async throws -> (result: GraphExecutionResult, trace: ExecutionTrace?) {
        _ = await profiler.startExecution(graphId: graph.id)

        do {
            let result = try await engine.execute(graph: graph, inputs: inputs)

            let trace = await profiler.finishExecution(
                graphId: graph.id,
                status: .success,
                cacheHits: result.cacheHits,
                cacheMisses: result.cacheMisses
            )

            return (result, trace)
        } catch {
            _ = await profiler.finishExecution(
                graphId: graph.id,
                status: .failed,
                cacheHits: 0,
                cacheMisses: 0
            )
            throw error
        }
    }
}

/// Events from streaming pipeline execution.
public enum PipelineStreamEvent: Sendable {
    case nodeStarted(nodeId: NodeInstanceId, name: String)
    case progress(nodeId: NodeInstanceId, progress: Double, message: String?)
    case chunk(nodeId: NodeInstanceId, portName: String, value: AnyPortValue)
    case nodeCompleted(nodeId: NodeInstanceId, time: TimeInterval)
    case complete(result: GraphExecutionResult)
}

/// Errors from pipeline execution.
public enum PipelineError: Error, LocalizedError {
    case missingOutput(String)
    case invalidInput(String)
    case graphValidationFailed([GraphValidator.ValidationError])

    public var errorDescription: String? {
        switch self {
        case .missingOutput(let name):
            return "Missing expected output: \(name)"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .graphValidationFailed(let errors):
            return "Graph validation failed: \(errors.map { $0.localizedDescription }.joined(separator: ", "))"
        }
    }
}

// MARK: - Stream helpers

/// An AsyncSequence that transforms each element of an async base sequence.
public struct ThrowingTransformSequence<Base: AsyncSequence, Output>: AsyncSequence {
    public typealias Element = Output

    public struct AsyncIterator: AsyncIteratorProtocol {
        var baseIterator: Base.AsyncIterator
        let transform: @Sendable (Base.Element) throws -> Output

        public mutating func next() async throws -> Output? {
            guard let element = try await baseIterator.next() else { return nil }
            return try transform(element)
        }
    }

    let base: Base
    let transform: @Sendable (Base.Element) throws -> Output

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(baseIterator: base.makeAsyncIterator(), transform: transform)
    }
}

extension ThrowingTransformSequence: Sendable where Base: Sendable, Output: Sendable {}

// MARK: - Quick Start Examples

/// Examples demonstrating pipeline usage.
public struct PipelineExamples {

    /// Example: Simple question answering
    public static func questionAnswering() async throws {
        let factory = PipelineFactory()
        let runner = GraphExecutorRunner()

        // Create a simple Q&A pipeline
        let graph = try await factory.createSimpleTextGeneration(
            systemPrompt: "You are a helpful assistant. Answer questions concisely."
        )

        // Run it
        let answer = try await runner.runTextToText(
            graph: graph,
            input: "What is the capital of France?"
        )

        print("Answer: \(answer)")
    }

    /// Example: Document summarization
    public static func summarization() async throws {
        let factory = PipelineFactory()
        let runner = GraphExecutorRunner()

        let graph = try await factory.createSummarization(style: "bullets")

        let summary = try await runner.runTextToText(
            graph: graph,
            input: "Long document text here...",
            inputName: "text",
            outputName: "summary"
        )

        print("Summary:\n\(summary)")
    }

    /// Example: Build custom pipeline
    public static func customPipeline() async throws {
        var graph = NodeGraph(name: "Custom Pipeline")

        // Add nodes manually
        let input = NodeInstance(
            typeId: NodeTypeId(category: "Text", name: "TextInput"),
            parameterValues: ["value": .text("Hello, world!")]
        )
        graph.addNode(input)

        let upper = NodeInstance(
            typeId: NodeTypeId(category: "Text", name: "TextTemplate"),
            parameterValues: ["template": .text("PROCESSED: {text}")]
        )
        graph.addNode(upper)

        _ = graph.connect(from: input.id, port: "text", to: upper.id, port: "variables")

        // Execute
        let engine = GrapheneEngine()
        let result = try await engine.execute(graph: graph)

        print("Result: \(result.outputs)")
    }
}
