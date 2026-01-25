//
//  AINodes.swift
//  AnigmaCore
//
//  AI and ML node types for the Graphene pipeline.
//
//  Provides nodes for:
//  - LLM inference (text generation, chat)
//  - Embeddings and semantic search
//  - Image generation and processing
//  - Audio processing (TTS, ASR)
//  - Vision and OCR
//
//  These nodes integrate with Anigma's inference plane for
//  optimal execution on Apple Silicon (GPU, ANE, CPU).
//

import Foundation
import InferenceCore
import TextChunkingCapsule
import AnigmaNativeShims

// MARK: - AI Node Registration

/// Registers all AI-related nodes with the registry.
public struct AINodeRegistrar {

    public static func registerAll(registry: NodeRegistry, inference: InferencePlane) async {
        await registerLLMNodes(registry: registry, inference: inference)
        await registerEmbeddingNodes(registry: registry, inference: inference)
        await registerVisionNodes(registry: registry)
        await registerAudioNodes(registry: registry)
        await registerRAGNodes(registry: registry, inference: inference)
    }

    // MARK: - LLM Nodes

    private static func registerLLMNodes(registry: NodeRegistry, inference: InferencePlane) async {
        // Text Generation node
        let textGen = NodeDescriptor(
            typeId: NodeTypeId(category: "AI/LLM", name: "TextGeneration"),
            displayName: "Text Generation",
            description: "Generate text using a language model",
            category: "AI/LLM",
            inputs: [
                InputPortDef(name: "prompt", type: TextPort.self),
                InputPortDef(name: "systemPrompt", type: TextPort.self, isRequired: false)
            ],
            outputs: [
                OutputPortDef(name: "response", type: TextPort.self),
                OutputPortDef(name: "tokens", type: NumberPort.self)
            ],
            parameters: [
                NodeParameter(name: "model", type: .model, defaultValue: .model(identifier: "llama-3.2-3b")),
                NodeParameter(name: "maxTokens", type: .integer, defaultValue: .integer(512)),
                NodeParameter(name: "temperature", type: .number, defaultValue: .number(0.7)),
                NodeParameter(name: "topP", type: .number, defaultValue: .number(0.9)),
                NodeParameter(name: "localOnly", type: .boolean, defaultValue: .boolean(true))
            ],
            executionHint: .neural
        )
        await registry.register(descriptor: textGen, executor: TextGenerationExecutor(inference: inference))

        // Chat node (multi-turn conversation)
        let chat = NodeDescriptor(
            typeId: NodeTypeId(category: "AI/LLM", name: "Chat"),
            displayName: "Chat",
            description: "Multi-turn conversation with a language model",
            category: "AI/LLM",
            inputs: [
                InputPortDef(name: "userMessage", type: TextPort.self),
                InputPortDef(name: "history", type: JsonPort.self, isRequired: false),
                InputPortDef(name: "systemPrompt", type: TextPort.self, isRequired: false)
            ],
            outputs: [
                OutputPortDef(name: "response", type: TextPort.self),
                OutputPortDef(name: "updatedHistory", type: JsonPort.self)
            ],
            parameters: [
                NodeParameter(name: "model", type: .model, defaultValue: .model(identifier: "llama-3.2-3b")),
                NodeParameter(name: "maxTokens", type: .integer, defaultValue: .integer(512)),
                NodeParameter(name: "temperature", type: .number, defaultValue: .number(0.7))
            ],
            executionHint: .neural
        )
        await registry.register(descriptor: chat, executor: ChatExecutor(inference: inference))

        // Text Summarization node
        let summarize = NodeDescriptor(
            typeId: NodeTypeId(category: "AI/LLM", name: "Summarize"),
            displayName: "Summarize",
            description: "Summarize text content",
            category: "AI/LLM",
            inputs: [
                InputPortDef(name: "text", type: TextPort.self)
            ],
            outputs: [
                OutputPortDef(name: "summary", type: TextPort.self)
            ],
            parameters: [
                NodeParameter(name: "model", type: .model, defaultValue: .model(identifier: "llama-3.2-3b")),
                NodeParameter(name: "style", type: .choice, defaultValue: .choice("concise", options: ["concise", "detailed", "bullets", "one_sentence"])),
                NodeParameter(name: "maxLength", type: .integer, defaultValue: .integer(200))
            ],
            executionHint: .neural
        )
        await registry.register(descriptor: summarize, executor: SummarizeExecutor(inference: inference))
    }

    // MARK: - Embedding Nodes

    private static func registerEmbeddingNodes(registry: NodeRegistry, inference: InferencePlane) async {
        // Text Embedding node
        let textEmbed = NodeDescriptor(
            typeId: NodeTypeId(category: "AI/Embedding", name: "TextEmbedding"),
            displayName: "Text Embedding",
            description: "Generate vector embeddings from text",
            category: "AI/Embedding",
            inputs: [
                InputPortDef(name: "text", type: TextPort.self)
            ],
            outputs: [
                OutputPortDef(name: "embedding", type: TensorPort.self)
            ],
            parameters: [
                NodeParameter(name: "model", type: .model, defaultValue: .model(identifier: "nomic-embed-text")),
                NodeParameter(name: "normalize", type: .boolean, defaultValue: .boolean(true))
            ],
            executionHint: .neural
        )
        await registry.register(descriptor: textEmbed, executor: TextEmbeddingExecutor(inference: inference))

        // Semantic Search node
        let semanticSearch = NodeDescriptor(
            typeId: NodeTypeId(category: "AI/Embedding", name: "SemanticSearch"),
            displayName: "Semantic Search",
            description: "Search for similar content using embeddings",
            category: "AI/Embedding",
            inputs: [
                InputPortDef(name: "query", type: TextPort.self),
                InputPortDef(name: "corpus", type: JsonPort.self)
            ],
            outputs: [
                OutputPortDef(name: "results", type: JsonPort.self),
                OutputPortDef(name: "topResult", type: TextPort.self)
            ],
            parameters: [
                NodeParameter(name: "model", type: .model, defaultValue: .model(identifier: "nomic-embed-text")),
                NodeParameter(name: "topK", type: .integer, defaultValue: .integer(5)),
                NodeParameter(name: "threshold", type: .number, defaultValue: .number(0.7))
            ],
            executionHint: .neural
        )
        await registry.register(descriptor: semanticSearch, executor: SemanticSearchExecutor())
    }

    // MARK: - Vision Nodes

    private static func registerVisionNodes(registry: NodeRegistry) async {
        // Image Classification node
        let imageClassify = NodeDescriptor(
            typeId: NodeTypeId(category: "AI/Vision", name: "ImageClassification"),
            displayName: "Classify Image",
            description: "Classify image content",
            category: "AI/Vision",
            inputs: [
                InputPortDef(name: "image", type: ImagePort.self)
            ],
            outputs: [
                OutputPortDef(name: "labels", type: JsonPort.self),
                OutputPortDef(name: "topLabel", type: TextPort.self),
                OutputPortDef(name: "confidence", type: NumberPort.self)
            ],
            parameters: [
                NodeParameter(name: "model", type: .model, defaultValue: .model(identifier: "mobilenet-v3"))
            ],
            executionHint: .neural
        )
        await registry.register(descriptor: imageClassify, executor: ImageClassificationExecutor())

        // OCR node
        let ocr = NodeDescriptor(
            typeId: NodeTypeId(category: "AI/Vision", name: "OCR"),
            displayName: "OCR",
            description: "Extract text from images using optical character recognition",
            category: "AI/Vision",
            inputs: [
                InputPortDef(name: "image", type: ImagePort.self)
            ],
            outputs: [
                OutputPortDef(name: "text", type: TextPort.self),
                OutputPortDef(name: "blocks", type: JsonPort.self)
            ],
            parameters: [
                NodeParameter(name: "language", type: .choice, defaultValue: .choice("en", options: ["en", "es", "fr", "de", "zh", "ja", "auto"])),
                NodeParameter(name: "recognitionLevel", type: .choice, defaultValue: .choice("accurate", options: ["fast", "accurate"]))
            ],
            executionHint: .neural
        )
        await registry.register(descriptor: ocr, executor: OCRExecutor())

        // Image Description node (VLM)
        let imageDescribe = NodeDescriptor(
            typeId: NodeTypeId(category: "AI/Vision", name: "DescribeImage"),
            displayName: "Describe Image",
            description: "Generate a text description of an image using a vision-language model",
            category: "AI/Vision",
            inputs: [
                InputPortDef(name: "image", type: ImagePort.self),
                InputPortDef(name: "prompt", type: TextPort.self, isRequired: false)
            ],
            outputs: [
                OutputPortDef(name: "description", type: TextPort.self)
            ],
            parameters: [
                NodeParameter(name: "model", type: .model, defaultValue: .model(identifier: "llava-1.5-7b")),
                NodeParameter(name: "detail", type: .choice, defaultValue: .choice("balanced", options: ["brief", "balanced", "detailed"]))
            ],
            executionHint: .neural
        )
        await registry.register(descriptor: imageDescribe, executor: ImageDescriptionExecutor())
    }

    // MARK: - Audio Nodes

    private static func registerAudioNodes(registry: NodeRegistry) async {
        // Speech-to-Text node
        let speechToText = NodeDescriptor(
            typeId: NodeTypeId(category: "AI/Audio", name: "SpeechToText"),
            displayName: "Speech to Text",
            description: "Transcribe audio to text using ASR",
            category: "AI/Audio",
            inputs: [
                InputPortDef(name: "audio", type: AudioPort.self)
            ],
            outputs: [
                OutputPortDef(name: "text", type: TextPort.self),
                OutputPortDef(name: "segments", type: JsonPort.self)
            ],
            parameters: [
                NodeParameter(name: "model", type: .model, defaultValue: .model(identifier: "whisper-large-v3")),
                NodeParameter(name: "language", type: .choice, defaultValue: .choice("auto", options: ["auto", "en", "es", "fr", "de", "zh", "ja"])),
                NodeParameter(name: "translateToEnglish", type: .boolean, defaultValue: .boolean(false))
            ],
            executionHint: .neural
        )
        await registry.register(descriptor: speechToText, executor: SpeechToTextExecutor())

        // Text-to-Speech node
        let textToSpeech = NodeDescriptor(
            typeId: NodeTypeId(category: "AI/Audio", name: "TextToSpeech"),
            displayName: "Text to Speech",
            description: "Synthesize speech from text",
            category: "AI/Audio",
            inputs: [
                InputPortDef(name: "text", type: TextPort.self)
            ],
            outputs: [
                OutputPortDef(name: "audio", type: AudioPort.self)
            ],
            parameters: [
                NodeParameter(name: "model", type: .model, defaultValue: .model(identifier: "kokoro-tts")),
                NodeParameter(name: "voice", type: .choice, defaultValue: .choice("default", options: ["default", "male", "female", "neutral"])),
                NodeParameter(name: "speed", type: .number, defaultValue: .number(1.0))
            ],
            executionHint: .neural
        )
        await registry.register(descriptor: textToSpeech, executor: TextToSpeechExecutor())
    }

    // MARK: - RAG Nodes

    private static func registerRAGNodes(registry: NodeRegistry, inference: InferencePlane) async {
        // Document Chunker node
        let chunker = NodeDescriptor(
            typeId: NodeTypeId(category: "AI/RAG", name: "DocumentChunker"),
            displayName: "Chunk Document",
            description: "Split a document into chunks for embedding",
            category: "AI/RAG",
            inputs: [
                InputPortDef(name: "document", type: TextPort.self)
            ],
            outputs: [
                OutputPortDef(name: "chunks", type: JsonPort.self)
            ],
            parameters: [
                NodeParameter(name: "strategy", type: .choice, defaultValue: .choice("semantic", options: ["fixed", "sentence", "paragraph", "semantic"])),
                NodeParameter(name: "chunkSize", type: .integer, defaultValue: .integer(512)),
                NodeParameter(name: "overlap", type: .integer, defaultValue: .integer(50))
            ],
            executionHint: .cpu
        )
        await registry.register(descriptor: chunker, executor: DocumentChunkerExecutor())

        // RAG Query node
        let ragQuery = NodeDescriptor(
            typeId: NodeTypeId(category: "AI/RAG", name: "RAGQuery"),
            displayName: "RAG Query",
            description: "Answer questions using retrieval-augmented generation",
            category: "AI/RAG",
            inputs: [
                InputPortDef(name: "query", type: TextPort.self),
                InputPortDef(name: "documents", type: JsonPort.self)
            ],
            outputs: [
                OutputPortDef(name: "answer", type: TextPort.self),
                OutputPortDef(name: "sources", type: JsonPort.self)
            ],
            parameters: [
                NodeParameter(name: "model", type: .model, defaultValue: .model(identifier: "llama-3.2-3b")),
                NodeParameter(name: "embedModel", type: .model, defaultValue: .model(identifier: "nomic-embed-text")),
                NodeParameter(name: "topK", type: .integer, defaultValue: .integer(3)),
                NodeParameter(name: "includeSourceQuotes", type: .boolean, defaultValue: .boolean(true))
            ],
            executionHint: .neural
        )
        await registry.register(descriptor: ragQuery, executor: RAGQueryExecutor(inference: inference))
    }
}

// MARK: - AI Node Executors (Stubs)

struct TextGenerationExecutor: NodeExecutor {
    private let inference: InferencePlane

    init(inference: InferencePlane) {
        self.inference = inference
    }

    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        let prompt = inputs["prompt"]?.as(TextPort.self)?.value ?? ""
        let systemPrompt = inputs["systemPrompt"]?.as(TextPort.self)?.value ?? ""
        let modelID = instance.parameterValues["model"]?.modelIdentifier
        let maxTokens = instance.parameterValues["maxTokens"]?.intValue
        let temperature = instance.parameterValues["temperature"]?.numberValue
        let topP = instance.parameterValues["topP"]?.numberValue
        let localOnly = instance.parameterValues["localOnly"]?.boolValue

        var options: [String: InferenceOptionValue] = [:]
        if let maxTokens {
            options["maxTokens"] = .integer(maxTokens)
        }
        if let temperature {
            options["temperature"] = .number(temperature)
        }
        if let topP {
            options["topP"] = .number(topP)
        }
        if let localOnly {
            options["localOnly"] = .boolean(localOnly)
        }

        let input = systemPrompt.isEmpty
            ? prompt
            : "SYSTEM: \(systemPrompt)\nUSER: \(prompt)"

        let response = try await inference.perform(
            InferenceRequest(
                task: .textGeneration,
                input: input,
                modelID: modelID,
                options: options
            )
        )

        return [
            "response": AnyPortValue(TextPort(response.output)),
            "tokens": AnyPortValue(
                NumberPort(Double(response.output.split(separator: " ").count)))
        ]
    }
}

struct ChatExecutor: NodeExecutor {
    private let inference: InferencePlane

    init(inference: InferencePlane) {
        self.inference = inference
    }

    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        guard let userMessage = inputs["userMessage"]?.as(TextPort.self)?.value else {
            throw PipelineError.invalidInput("ChatExecutor requires 'userMessage' input.")
        }
        let modelID = instance.parameterValues["model"]?.modelIdentifier
        let maxTokens = instance.parameterValues["maxTokens"]?.intValue
        let temperature = instance.parameterValues["temperature"]?.numberValue
        let systemPrompt = inputs["systemPrompt"]?.as(TextPort.self)?.value

        // Construct input for ML Worker (e.g., simple message or formatted history)
        var chatInput = userMessage
        if let historyJson = try inputs["history"]?.as(JsonPort.self)?.dictionary(),
           let historyData = try? JSONSerialization.data(withJSONObject: historyJson, options: []),
           let historyString = String(data: historyData, encoding: .utf8) {
            chatInput = "HISTORY: \(historyString)\nUSER: \(userMessage)"
        }

        var options: [String: InferenceOptionValue] = [:]
        if let maxTokens {
            options["maxTokens"] = .integer(maxTokens)
        }
        if let temperature {
            options["temperature"] = .number(temperature)
        }
        if let systemPrompt, !systemPrompt.isEmpty {
            options["systemPrompt"] = .string(systemPrompt)
        }

        let response = try await inference.perform(
            InferenceRequest(
                task: .chat,
                input: chatInput,
                modelID: modelID,
                options: options
            )
        )

        // Update history (simplified: just append current turn)
        var updatedHistoryDict: [String: Any] = [
            "messages": [
                ["role": "user", "content": userMessage],
                ["role": "assistant", "content": response.output]
            ]
        ]
        if let existingHistory = try inputs["history"]?.as(JsonPort.self)?.dictionary() as? [String: Any],
           var existingMessages = existingHistory["messages"] as? [[String: String]] {
            existingMessages.append(contentsOf: updatedHistoryDict["messages"] as! [[String: String]])
            updatedHistoryDict["messages"] = existingMessages
        }
        let updatedHistory = try JsonPort(updatedHistoryDict)

        return [
            "response": AnyPortValue(TextPort(response.output)),
            "updatedHistory": AnyPortValue(updatedHistory)
        ]
    }
}

struct SummarizeExecutor: NodeExecutor {
    private let inference: InferencePlane

    init(inference: InferencePlane) {
        self.inference = inference
    }

    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        let text = inputs["text"]?.as(TextPort.self)?.value ?? ""
        let modelID = instance.parameterValues["model"]?.modelIdentifier
        let maxLength = instance.parameterValues["maxLength"]?.intValue
        let style = instance.parameterValues["style"]?.stringValue ?? "concise"

        var options: [String: InferenceOptionValue] = [
            "style": .string(style)
        ]
        if let maxLength {
            options["maxLength"] = .integer(maxLength)
        }

        let prompt = "Summarize the following text (\(style)):\n\n\(text)"
        let response = try await inference.perform(
            InferenceRequest(
                task: .textGeneration,
                input: prompt,
                modelID: modelID,
                options: options
            )
        )

        return ["summary": AnyPortValue(TextPort(response.output))]
    }
}

struct TextEmbeddingExecutor: NodeExecutor {
    private let inference: InferencePlane

    init(inference: InferencePlane) {
        self.inference = inference
    }

    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        guard let text = inputs["text"]?.as(TextPort.self)?.value else {
            throw PipelineError.invalidInput("TextEmbeddingExecutor requires 'text' input.")
        }
        let modelID = instance.parameterValues["model"]?.modelIdentifier
        let normalize = instance.parameterValues["normalize"]?.boolValue ?? true

        let response = try await inference.perform(
            InferenceRequest(
                task: .embedding,
                input: text,
                modelID: modelID,
                options: ["normalize": .boolean(normalize)]
            )
        )

        // Parse the raw output (assuming space-separated floats)
        let embeddingFloats = response.output.split(separator: " ").compactMap { Float($0) }
        guard !embeddingFloats.isEmpty else {
            throw PipelineError.invalidInput("ML Worker returned empty or invalid embedding output.")
        }

        // Create a TensorPort from the embedding
        let storageKey = "embedding_\(UUID().uuidString)"
        let embedding = TensorPort(
            shape: [embeddingFloats.count],
            dtype: "float32",
            storageKey: storageKey
        )
        
        // Store the embedding vector in resource manager
        await context.resourceManager.allocate(key: storageKey, value: embeddingFloats)

        return ["embedding": AnyPortValue(embedding)]
    }
}

struct SemanticSearchExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        _ = inputs["query"]?.as(TextPort.self)?.value ?? ""
        throw PipelineError.invalidInput("Semantic search requires vector store integration.")
    }
}

struct ImageClassificationExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        throw PipelineError.invalidInput("Image classification requires a vision provider.")
    }
}

struct OCRExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        throw PipelineError.invalidInput("OCR requires a vision provider.")
    }
}

struct ImageDescriptionExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        throw PipelineError.invalidInput("Image description requires a vision-language model.")
    }
}

struct SpeechToTextExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        throw PipelineError.invalidInput("Speech-to-text requires an audio transcription provider.")
    }
}

struct TextToSpeechExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        _ = inputs["text"]?.as(TextPort.self)?.value ?? ""
        throw PipelineError.invalidInput("Text-to-speech requires an audio synthesis provider.")
    }
}

struct DocumentChunkerExecutor: NodeExecutor {
    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        let document = inputs["document"]?.as(TextPort.self)?.value ?? ""
        let chunkSize = instance.parameterValues["chunkSize"]?.intValue ?? 512
        
        // Convert to UTF-8 data for byte-level chunking
        let data = Data(document.utf8)
        
        // Compute average bytes per character for this text
        let avgBytesPerChar = max(1, data.count / document.count)
        
        // Convert character-based chunkSize to byte-based target size
        let targetBytes = chunkSize * avgBytesPerChar
        
        // Ensure reasonable bounds for chunk sizes
        let minBytes = max(64, targetBytes / 4)
        let maxBytes = min(targetBytes * 2, 16384)
        
        let config = TextChunkingConfig(
            targetChunkSize: targetBytes,
            minChunkSize: minBytes,
            maxChunkSize: maxBytes,
            windowSize: 48,
            determinismTier: 1
        )
        
        // Helper to convert byte offset to character offset
        func characterOffset(forByteOffset byteOffset: Int) -> Int {
            guard byteOffset >= 0 && byteOffset <= data.count else { return 0 }
            let utf8Index = document.utf8.index(document.utf8.startIndex, offsetBy: byteOffset)
            return document.distance(from: document.startIndex, to: utf8Index)
        }
        
        do {
            // Use one-shot chunking
            let wrapper = try TextChunkingCapsuleWrapper(config: config)
            try wrapper.processBytes(data)
            try wrapper.finalize()
            
            // Extract chunks as Data slices
            let chunkData = try await wrapper.extractChunks(from: data)
            
            var chunks: [[String: Any]] = []
            var currentByteOffset = 0
            
            for chunk in chunkData {
                if let chunkString = String(data: chunk, encoding: .utf8) {
                    let charOffset = characterOffset(forByteOffset: currentByteOffset)
                    chunks.append(["text": chunkString, "offset": charOffset])
                    currentByteOffset += chunk.count
                } else {
                    // UTF-8 conversion failed, fall back to simple fixed-size chunking
                    return fallbackChunk(document: document, chunkSize: chunkSize)
                }
            }
            
            // If no chunks produced (empty document), return empty array
            let result = try JsonPort(["chunks": chunks])
            return ["chunks": AnyPortValue(result)]
            
        } catch {
            // Capsule failed, fall back to simple fixed-size chunking
            return fallbackChunk(document: document, chunkSize: chunkSize)
        }
    }
    
    private func fallbackChunk(document: String, chunkSize: Int) -> [String: AnyPortValue] {
        var chunks: [[String: Any]] = []
        var offset = 0
        while offset < document.count {
            let endIndex = min(offset + chunkSize, document.count)
            let startIdx = document.index(document.startIndex, offsetBy: offset)
            let endIdx = document.index(document.startIndex, offsetBy: endIndex)
            let chunk = String(document[startIdx..<endIdx])
            chunks.append(["text": chunk, "offset": offset])
            offset = endIndex
        }
        let result = try! JsonPort(["chunks": chunks])
        return ["chunks": AnyPortValue(result)]
    }
}

struct RAGQueryExecutor: NodeExecutor {
    private let inference: InferencePlane

    init(inference: InferencePlane) {
        self.inference = inference
    }

    func execute(
        descriptor: NodeDescriptor,
        instance: NodeInstance,
        inputs: [String: AnyPortValue],
        context: GrapheneExecutionContext
    ) async throws -> [String: AnyPortValue] {
        let query = inputs["query"]?.as(TextPort.self)?.value ?? ""
        let modelID = instance.parameterValues["model"]?.modelIdentifier
        let topK = instance.parameterValues["topK"]?.intValue ?? 3
        let includeQuotes = instance.parameterValues["includeSourceQuotes"]?.boolValue ?? true
        let documents = try inputs["documents"]?.as(JsonPort.self)?.dictionary()

        let prompt = buildRAGPrompt(
            query: query,
            documents: documents,
            topK: topK,
            includeQuotes: includeQuotes
        )

        let response = try await inference.perform(
            InferenceRequest(
                task: .textGeneration,
                input: prompt,
                modelID: modelID,
                options: [
                    "topK": .integer(topK),
                    "includeSourceQuotes": .boolean(includeQuotes)
                ]
            )
        )

        let sources = try JsonPort(["sources": extractSources(from: documents, limit: topK)])

        return [
            "answer": AnyPortValue(TextPort(response.output)),
            "sources": AnyPortValue(sources)
        ]
    }
}

private func buildRAGPrompt(
    query: String,
    documents: [String: Any]?,
    topK: Int,
    includeQuotes: Bool
) -> String {
    var prompt = "Answer the question using the provided documents.\n\nQuestion:\n\(query)\n\nDocuments:\n"
    if let list = documents?["documents"] as? [[String: Any]] {
        for (index, doc) in list.prefix(topK).enumerated() {
            let text = doc["text"] as? String ?? ""
            prompt += "Document \(index + 1):\n\(text)\n\n"
        }
    } else if let text = documents?["text"] as? String {
        prompt += text
    } else {
        prompt += "(no documents provided)"
    }
    if includeQuotes {
        prompt += "\nInclude short quotes when available."
    }
    return prompt
}

private func extractSources(from documents: [String: Any]?, limit: Int) -> [[String: Any]] {
    guard let list = documents?["documents"] as? [[String: Any]] else {
        return []
    }
    return list.prefix(limit).map { doc in
        [
            "text": doc["text"] as? String ?? "",
            "relevance": doc["score"] as? Double ?? 0.0
        ]
    }
}
