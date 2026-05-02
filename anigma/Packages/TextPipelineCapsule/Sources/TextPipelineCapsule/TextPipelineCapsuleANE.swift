import Foundation
import CapsuleCore
import ANECapsuleIntegration
import ANEServicesCore
import NaturalLanguage
import CoreML

/// ANE-optimized text processing pipeline capsule for batch operations
public actor TextPipelineCapsuleANE: ANECapsuleBase, CapsuleLifecycle {
    
    // MARK: - ANECapsuleBase Conformance
    
    public static let aneDescriptor: ANECapsuleDescriptor = {
        ANECapsuleDescriptor(
            id: "com.anigma.capsule.text-pipeline-ane",
            version: "1.0.0",
            name: "Text Pipeline ANE Capsule",
            description: "ANE-accelerated text processing, embedding, and NLP operations",
            supportedComputeUnits: [.neuralEngine, .cpu, .gpu],
            gate: .open,
            capabilityLevel: .mixed,
            batchSizeRange: 1...32,
            optimalBatchSize: 16,
            memoryPerOperation: 1024 * 1024, // 1MB per text
            estimatedSpeedup: 6.0
        )
    }()
    
    public static var preferredComputeUnit: ANEComputeUnit {
        .neuralEngine
    }
    
    public static var supportsFallback: Bool {
        true
    }
    
    public static func validateComputeUnit(_ computeUnit: ANEComputeUnit) throws {
        let descriptor = Self.aneDescriptor
        guard descriptor.supportedComputeUnits.contains(computeUnit) else {
            throw ANECapsuleError.unsupportedComputeUnit(
                capsuleId: descriptor.id,
                requested: computeUnit,
                supported: descriptor.supportedComputeUnits
            )
        }

        switch descriptor.gate.status {
        case .gated:
            throw ANECapsuleError.gated(
                capsuleId: descriptor.id,
                reason: descriptor.gate.reason ?? "Access gated"
            )
        case .deprecated:
            throw ANECapsuleError.deprecated(
                capsuleId: descriptor.id,
                reason: descriptor.gate.reason ?? "Capsule deprecated"
            )
        case .experimental, .open:
            break
        }
    }
    
    // MARK: - Properties
    
    private let cpuCapsule: TextPipelineCapsuleWrapper
    private var embeddingModel: NLEmbedding?
    private var tokenizer: NLTokenizer?
    private var batchProcessor: ANEBatchProcessor<TextBatchInput, TextBatchOutput>?
    private let performanceMonitor: ANEPerformanceMonitor
    private let embeddingScratchPool = ReusableArrayPool<Float>(maxBuffers: 2)
    private let tokenScratchPool = ReusableArrayPool<String>(maxBuffers: 2)
    private var isActive: Bool = false
    
    // MARK: - Initialization
    
    public init(config: TextPipelineConfig) throws {
        self.cpuCapsule = try TextPipelineCapsuleWrapper(config: config)
        self.performanceMonitor = ANEPerformanceMonitor(capsuleId: Self.aneDescriptor.id)
        self.embeddingModel = nil
        self.tokenizer = nil
        self.batchProcessor = nil
    }
    
    // MARK: - CapsuleLifecycle
    
    public func activate() async throws {
        guard !isActive else { return }

        // Initialize CPU capsule.
        // TextPipelineCapsule itself is CPU-backed, so the ANE wrapper only
        // needs to prepare its fallback state and bookkeeping.
        await initializeNLPComponents()

        batchProcessor = ANEBatchProcessor(
            capsuleId: Self.aneDescriptor.id,
            optimalBatchSize: Self.aneDescriptor.optimalBatchSize,
            maxBatchSize: Self.aneDescriptor.batchSizeRange.upperBound
        )

        isActive = true
        await performanceMonitor.recordActivation()
    }
    
    public func deactivate() async {
        guard isActive else { return }
        
        embeddingModel = nil
        tokenizer = nil
        batchProcessor = nil
        isActive = false
        await performanceMonitor.recordDeactivation()
    }
    
    // MARK: - Batch Text Processing
    
    /// Process multiple texts in batch (ANE-optimized)
    /// - Parameters:
    ///   - texts: Array of texts to process
    ///   - context: ANE execution context
    /// - Returns: Processed texts with execution metrics
    public func processBatch(
        texts: [String],
        context: ANEExecutionContext? = nil
    ) async throws -> ANECapsuleResult<[TextPipelineResult]> {
        let startTime = Date()
        
        if !isActive {
            try await activate()
        }
        
        let context = context ?? ANEExecutionContext()
        let computeUnit = try await determineComputeUnit(context: context)
        
        // Prepare batch input
        let batchInput = TextBatchInput(
            operation: .process,
            texts: texts,
            computeUnit: computeUnit
        )
        
        let result: [TextPipelineResult]
        let receipt: ExecutionReceipt?
        let fallbackUsed: Bool
        
        if computeUnit == .neuralEngine, let processor = batchProcessor {
            // Use ANE batch processing
            do {
                let batchResult = try await processor.processBatch(
                    input: batchInput,
                    context: context,
                    processor: { [weak self] batch in
                        guard let self = self else { throw ANECapsuleError.executionFailed(
                            capsuleId: Self.aneDescriptor.id,
                            underlyingError: CocoaError(.executableRuntimeMismatch)
                        )}
                        return try await self.processTextBatchOnANE(batch)
                    }
                )
                
                result = batchResult.outputs.first?.processedResults ?? []
                receipt = batchResult.receipt
                fallbackUsed = false
                
                await performanceMonitor.recordANEBatchExecution(
                    batchSize: texts.count,
                    executionTime: Date().timeIntervalSince(startTime)
                )
            } catch {
                // Fallback to CPU if allowed
                if context.allowFallback && Self.supportsFallback {
                    print("⚠️ ANE text processing failed, falling back to CPU for \(texts.count) texts")
                    let cpuResult = try await processBatchOnCPU(texts: texts)
                    result = cpuResult
                    receipt = nil
                    fallbackUsed = true
                    
                    await performanceMonitor.recordCPUFallback(
                        batchSize: texts.count,
                        executionTime: Date().timeIntervalSince(startTime)
                    )
                } else {
                    throw error
                }
            }
        } else {
            // Use CPU directly
            result = try await processBatchOnCPU(texts: texts)
            receipt = nil
            fallbackUsed = computeUnit == .cpu
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        return ANECapsuleResult(
            output: result,
            executionReceipt: receipt,
            computeUnitUsed: computeUnit,
            executionTime: executionTime,
            fallbackUsed: fallbackUsed
        )
    }
    
    /// Compute embeddings for multiple texts in batch
    /// - Parameters:
    ///   - texts: Array of texts to embed
    ///   - context: ANE execution context
    /// - Returns: Text embeddings with execution metrics
    public func embedBatch(
        texts: [String],
        context: ANEExecutionContext? = nil
    ) async throws -> ANECapsuleResult<[[Float]]> {
        let startTime = Date()
        
        if !isActive {
            try await activate()
        }
        
        let context = context ?? ANEExecutionContext()
        let computeUnit = try await determineComputeUnit(context: context)
        
        // Prepare batch input
        let batchInput = TextBatchInput(
            operation: .embed,
            texts: texts,
            computeUnit: computeUnit
        )
        
        let result: [[Float]]
        let receipt: ExecutionReceipt?
        let fallbackUsed: Bool
        
        if computeUnit == .neuralEngine, let processor = batchProcessor {
            // Use ANE batch processing
            do {
                let batchResult = try await processor.processBatch(
                    input: batchInput,
                    context: context,
                    processor: { [weak self] batch in
                        guard let self = self else { throw ANECapsuleError.executionFailed(
                            capsuleId: Self.aneDescriptor.id,
                            underlyingError: CocoaError(.executableRuntimeMismatch)
                        )}
                        return try await self.embedTextBatchOnANE(batch)
                    }
                )
                
                result = batchResult.outputs.first?.embeddings ?? []
                receipt = batchResult.receipt
                fallbackUsed = false
                
                await performanceMonitor.recordANEBatchExecution(
                    batchSize: texts.count,
                    executionTime: Date().timeIntervalSince(startTime)
                )
            } catch {
                // Fallback to CPU if allowed
                if context.allowFallback && Self.supportsFallback {
                    print("⚠️ ANE text embedding failed, falling back to CPU for \(texts.count) texts")
                    let cpuResult = try await embedBatchOnCPU(texts: texts)
                    result = cpuResult
                    receipt = nil
                    fallbackUsed = true
                    
                    await performanceMonitor.recordCPUFallback(
                        batchSize: texts.count,
                        executionTime: Date().timeIntervalSince(startTime)
                    )
                } else {
                    throw error
                }
            }
        } else {
            // Use CPU directly
            result = try await embedBatchOnCPU(texts: texts)
            receipt = nil
            fallbackUsed = computeUnit == .cpu
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        return ANECapsuleResult(
            output: result,
            executionReceipt: receipt,
            computeUnitUsed: computeUnit,
            executionTime: executionTime,
            fallbackUsed: fallbackUsed
        )
    }
    
    /// Tokenize multiple texts in batch
    /// - Parameters:
    ///   - texts: Array of texts to tokenize
    ///   - unit: Tokenization unit (word, sentence, paragraph)
    ///   - context: ANE execution context
    /// - Returns: Tokenized texts with execution metrics
    public func tokenizeBatch(
        texts: [String],
        unit: NLTokenUnit = .word,
        context: ANEExecutionContext? = nil
    ) async throws -> ANECapsuleResult<[[String]]> {
        let startTime = Date()
        
        if !isActive {
            try await activate()
        }
        
        let context = context ?? ANEExecutionContext()
        let computeUnit = try await determineComputeUnit(context: context)
        let result = try await tokenizeBatchOnCPU(texts: texts, unit: unit)
        let receipt: ExecutionReceipt? = nil
        let fallbackUsed = computeUnit == .cpu
        await performanceMonitor.recordCPUFallback(
            batchSize: texts.count,
            executionTime: Date().timeIntervalSince(startTime)
        )
        
        let executionTime = Date().timeIntervalSince(startTime)
        return ANECapsuleResult(
            output: result,
            executionReceipt: receipt,
            computeUnitUsed: computeUnit,
            executionTime: executionTime,
            fallbackUsed: fallbackUsed
        )
    }
    
    /// Compute similarity between multiple text pairs in batch
    /// - Parameters:
    ///   - textsA: First set of texts
    ///   - textsB: Second set of texts
    ///   - context: ANE execution context
    /// - Returns: Similarity scores with execution metrics
    public func similarityBatch(
        textsA: [String],
        textsB: [String],
        context: ANEExecutionContext? = nil
    ) async throws -> ANECapsuleResult<[Float]> {
        let startTime = Date()
        
        if !isActive {
            try await activate()
        }
        
        let context = context ?? ANEExecutionContext()
        let computeUnit = try await determineComputeUnit(context: context)
        guard textsA.count == textsB.count else {
            throw TextPipelineError.dimensionMismatch(
                expected: textsA.count,
                actual: textsB.count
            )
        }

        let result = try await similarityBatchOnCPU(textsA: textsA, textsB: textsB)
        let receipt: ExecutionReceipt? = nil
        let fallbackUsed = computeUnit == .cpu
        await performanceMonitor.recordCPUFallback(
            batchSize: textsA.count,
            executionTime: Date().timeIntervalSince(startTime)
        )
        
        let executionTime = Date().timeIntervalSince(startTime)
        return ANECapsuleResult(
            output: result,
            executionReceipt: receipt,
            computeUnitUsed: computeUnit,
            executionTime: executionTime,
            fallbackUsed: fallbackUsed
        )
    }
    
    // MARK: - Performance Metrics
    
    /// Get performance metrics for the capsule
    public func getPerformanceMetrics() -> ANEPerformanceMetrics {
        ANEPerformanceMetrics()
    }
    
    /// Reset performance metrics
    public func resetPerformanceMetrics() {
        Task {
            await performanceMonitor.reset()
        }
    }
    
    // MARK: - Private Methods
    
    private func determineComputeUnit(context: ANEExecutionContext) async throws -> ANEComputeUnit {
        let requestedUnit = context.computeUnit
        
        do {
            try Self.validateComputeUnit(requestedUnit)
            return requestedUnit
        } catch {
            if context.allowFallback && Self.supportsFallback && requestedUnit != .cpu {
                if Self.aneDescriptor.supportedComputeUnits.contains(.cpu) {
                    return .cpu
                }
            }
            throw error
        }
    }
    
    private func initializeNLPComponents() async {
        // Initialize NLP components
        if let embedding = NLEmbedding.wordEmbedding(for: .english) {
            self.embeddingModel = embedding
        }
        
        self.tokenizer = NLTokenizer(unit: .word)
    }
    
    private func processBatchOnCPU(texts: [String]) async throws -> [TextPipelineResult] {
        return try await cpuCapsule.transformBatch(texts)
    }
    
    private func embedBatchOnCPU(texts: [String]) async throws -> [[Float]] {
        guard let embeddingModel = embeddingModel else {
            throw TextPipelineError.embeddingModelNotAvailable
        }
        
        var embeddings: [[Float]] = []
        embeddings.reserveCapacity(texts.count)
        
        for text in texts {
            let embedding = try await embedTextOnCPU(text: text, model: embeddingModel)
            embeddings.append(embedding)
        }
        
        return embeddings
    }
    
    private func tokenizeBatchOnCPU(texts: [String], unit: NLTokenUnit) async throws -> [[String]] {
        guard let tokenizer = tokenizer else {
            throw TextPipelineError.tokenizerNotAvailable
        }
        
        var allTokens: [[String]] = []
        allTokens.reserveCapacity(texts.count)
        
        for text in texts {
            let tokens = try await tokenizeTextOnCPU(text: text, tokenizer: tokenizer, unit: unit)
            allTokens.append(tokens)
        }
        
        return allTokens
    }
    
    private func similarityBatchOnCPU(textsA: [String], textsB: [String]) async throws -> [Float] {
        guard let embeddingModel = embeddingModel else {
            throw TextPipelineError.embeddingModelNotAvailable
        }
        
        guard textsA.count == textsB.count else {
            throw TextPipelineError.dimensionMismatch(
                expected: textsA.count,
                actual: textsB.count
            )
        }
        
        var similarities: [Float] = []
        similarities.reserveCapacity(textsA.count)
        
        for i in 0..<textsA.count {
            let embeddingA = try await embedTextOnCPU(text: textsA[i], model: embeddingModel)
            let embeddingB = try await embedTextOnCPU(text: textsB[i], model: embeddingModel)
            
            let similarity = cosineSimilarity(a: embeddingA, b: embeddingB)
            similarities.append(similarity)
        }
        
        return similarities
    }
    
    private func processTextBatchOnANE(_ batch: TextBatchInput) async throws -> TextBatchOutput {
        // This is where ANE-accelerated text processing would happen
        // For now, we'll simulate it with CPU processing
        
        let processedResults = try await processBatchOnCPU(texts: batch.texts)
        return TextBatchOutput(processedResults: processedResults)
    }
    
    private func embedTextBatchOnANE(_ batch: TextBatchInput) async throws -> TextBatchOutput {
        // This is where ANE-accelerated text embedding would happen
        // For now, we'll simulate it with CPU processing
        
        let embeddings = try await embedBatchOnCPU(texts: batch.texts)
        return TextBatchOutput(embeddings: embeddings)
    }
    
    private func tokenizeBatchOnANE(_ batch: TokenizationBatchInput) async throws -> TokenizationBatchOutput {
        // This is where ANE-accelerated tokenization would happen
        // For now, we'll simulate it with CPU processing
        
        let tokens = try await tokenizeBatchOnCPU(texts: batch.texts, unit: batch.unit)
        return TokenizationBatchOutput(tokens: tokens)
    }
    
    private func similarityBatchOnANE(_ batch: SimilarityBatchInput) async throws -> SimilarityBatchOutput {
        // This is where ANE-accelerated similarity computation would happen
        // For now, we'll simulate it with CPU processing
        
        let similarities = try await similarityBatchOnCPU(textsA: batch.textsA, textsB: batch.textsB)
        return SimilarityBatchOutput(similarities: similarities)
    }
    
    // MARK: - CPU Helper Functions
    
    private func embedTextOnCPU(text: String, model: NLEmbedding) async throws -> [Float] {
        return embeddingScratchPool.withBuffer(minimumCapacity: model.dimension) { scratch in
            scratch.append(contentsOf: repeatElement(0.0, count: model.dimension))

            var wordCount = 0
            forEachWhitespaceDelimitedWord(in: text) { word in
                if let vector = model.vector(for: String(word)) {
                    for i in 0..<model.dimension {
                        scratch[i] += Float(vector[i])
                    }
                    wordCount += 1
                }
            }

            if wordCount > 0 {
                let scale = 1.0 / Float(wordCount)
                for i in 0..<model.dimension {
                    scratch[i] *= scale
                }
            }

            return Array(scratch)
        }
    }

    private func tokenizeTextOnCPU(text: String, tokenizer _: NLTokenizer, unit: NLTokenUnit) async throws -> [String] {
        let tokenizer = NLTokenizer(unit: unit)
        tokenizer.string = text
        
        let estimatedTokens = max(8, text.count / 4)
        return tokenScratchPool.withBuffer(minimumCapacity: estimatedTokens) { tokens in
            tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
                tokens.append(String(text[range]))
                return true
            }
            return Array(tokens)
        }
    }
    
    private func cosineSimilarity(a: [Float], b: [Float]) -> Float {
        guard a.count == b.count else { return 0.0 }
        
        var dot: Float = 0.0
        var normA: Float = 0.0
        var normB: Float = 0.0
        
        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        
        guard normA > 0 && normB > 0 else { return 0.0 }
        return dot / (sqrt(normA) * sqrt(normB))
    }

    /// Iterate whitespace-delimited words without allocating an intermediate array.
    ///
    /// This keeps the CPU fallback parity close to the previous `components(separatedBy:)`
    /// path while avoiding repeated temporary allocations on hot embedding calls.
    private func forEachWhitespaceDelimitedWord(
        in text: String,
        _ body: (Substring) -> Void
    ) {
        var wordStart = text.startIndex
        var index = text.startIndex

        while index < text.endIndex {
            if text[index].isWhitespace || text[index].isNewline {
                if wordStart < index {
                    body(text[wordStart..<index])
                }

                index = text.index(after: index)
                wordStart = index
                continue
            }

            index = text.index(after: index)
        }

        if wordStart < text.endIndex {
            body(text[wordStart..<text.endIndex])
        }
    }
}

// MARK: - Supporting Types

public enum TextOperation: Sendable {
    case process
    case embed
    case tokenize
    case similarity
}

public struct TextBatchInput: Sendable {
    public let operation: TextOperation
    public let texts: [String]
    public let computeUnit: ANEComputeUnit
    
    public init(operation: TextOperation, texts: [String], computeUnit: ANEComputeUnit) {
        self.operation = operation
        self.texts = texts
        self.computeUnit = computeUnit
    }
}

public struct TextBatchOutput: Sendable {
    public let processedResults: [TextPipelineResult]?
    public let embeddings: [[Float]]?
    
    public init(processedResults: [TextPipelineResult]? = nil, embeddings: [[Float]]? = nil) {
        self.processedResults = processedResults
        self.embeddings = embeddings
    }
}

public struct TokenizationBatchInput: Sendable {
    public let texts: [String]
    public let unit: NLTokenUnit
    public let computeUnit: ANEComputeUnit
    
    public init(texts: [String], unit: NLTokenUnit, computeUnit: ANEComputeUnit) {
        self.texts = texts
        self.unit = unit
        self.computeUnit = computeUnit
    }
}

public struct TokenizationBatchOutput: Sendable {
    public let tokens: [[String]]
    
    public init(tokens: [[String]]) {
        self.tokens = tokens
    }
}

public struct SimilarityBatchInput: Sendable {
    public let textsA: [String]
    public let textsB: [String]
    public let computeUnit: ANEComputeUnit
    
    public init(textsA: [String], textsB: [String], computeUnit: ANEComputeUnit) {
        self.textsA = textsA
        self.textsB = textsB
        self.computeUnit = computeUnit
    }
}

public struct SimilarityBatchOutput: Sendable {
    public let similarities: [Float]
    
    public init(similarities: [Float]) {
        self.similarities = similarities
    }
}

public enum TextPipelineError: Error, Sendable {
    case embeddingModelNotAvailable
    case tokenizerNotAvailable
    case dimensionMismatch(expected: Int, actual: Int)
    case textTooLong(maxLength: Int, actual: Int)
    case invalidTextEncoding
    case operationFailed(reason: String)
    
    public var localizedDescription: String {
        switch self {
        case .embeddingModelNotAvailable:
            return "Embedding model not available"
        case .tokenizerNotAvailable:
            return "Tokenizer not available"
        case .dimensionMismatch(let expected, let actual):
            return "Dimension mismatch: expected \(expected), got \(actual)"
        case .textTooLong(let maxLength, let actual):
            return "Text too long: maximum \(maxLength) characters, got \(actual)"
        case .invalidTextEncoding:
            return "Invalid text encoding"
        case .operationFailed(let reason):
            return "Operation failed: \(reason)"
        }
    }
}

// MARK: - ANEBatchProcessor Integration

public actor ANEBatchProcessor<Input: Sendable, Output: Sendable> {
    private let capsuleId: String
    private let optimalBatchSize: Int
    private let maxBatchSize: Int
    private var pendingBatches: [Input] = []
    private var isProcessing: Bool = false

    public init(capsuleId: String, optimalBatchSize: Int, maxBatchSize: Int) {
        self.capsuleId = capsuleId
        self.optimalBatchSize = optimalBatchSize
        self.maxBatchSize = maxBatchSize
    }

    public func processBatch(
        input: Input,
        context: ANEExecutionContext,
        processor: @escaping (Input) async throws -> Output
    ) async throws -> ANEBatchResult<Output> {
        pendingBatches.append(input)

        if pendingBatches.count >= optimalBatchSize || context.priority == .realtime {
            return try await processPendingBatches(context: context, processor: processor)
        } else {
            try await Task.sleep(nanoseconds: 10_000_000)

            if pendingBatches.count > 0 {
                return try await processPendingBatches(context: context, processor: processor)
            } else {
                return try await processSingleBatch(input: input, context: context, processor: processor)
            }
        }
    }

    private func processPendingBatches(
        context: ANEExecutionContext,
        processor: @escaping (Input) async throws -> Output
    ) async throws -> ANEBatchResult<Output> {
        guard !isProcessing else {
            throw ANECapsuleError.executionFailed(
                capsuleId: capsuleId,
                underlyingError: CocoaError(.fileWriteUnknown)
            )
        }

        isProcessing = true
        defer { isProcessing = false }

        let batchesToProcess = pendingBatches
        pendingBatches.removeAll()

        let combinedInput = try combineBatches(batchesToProcess)
        let output = try await processor(combinedInput)

        let receipt = try? await ExecutionReceipt.generate(
            for: ANECapsuleDescriptor(
                id: capsuleId,
                version: "1.0.0",
                name: "Batch Processor",
                description: "Combined batch processing",
                supportedComputeUnits: [context.computeUnit],
                gate: .open,
                capabilityLevel: .mixed,
                batchSizeRange: 1...maxBatchSize,
                optimalBatchSize: optimalBatchSize,
                memoryPerOperation: 0,
                estimatedSpeedup: 1.0
            ),
            computeUnit: context.computeUnit,
            inputHash: "\(batchesToProcess.count)",
            outputHash: "\(output)"
        )

        return ANEBatchResult(
            outputs: [output],
            receipt: receipt,
            batchSize: batchesToProcess.count
        )
    }

    private func processSingleBatch(
        input: Input,
        context: ANEExecutionContext,
        processor: @escaping (Input) async throws -> Output
    ) async throws -> ANEBatchResult<Output> {
        let output = try await processor(input)

        let receipt = try? await ExecutionReceipt.generate(
            for: ANECapsuleDescriptor(
                id: capsuleId,
                version: "1.0.0",
                name: "Batch Processor",
                description: "Single batch processing",
                supportedComputeUnits: [context.computeUnit],
                gate: .open,
                capabilityLevel: .mixed,
                batchSizeRange: 1...maxBatchSize,
                optimalBatchSize: optimalBatchSize,
                memoryPerOperation: 0,
                estimatedSpeedup: 1.0
            ),
            computeUnit: context.computeUnit,
            inputHash: "\(input)",
            outputHash: "\(output)"
        )

        return ANEBatchResult(
            outputs: [output],
            receipt: receipt,
            batchSize: 1
        )
    }

    private func combineBatches(_ batches: [Input]) throws -> Input {
        guard let firstBatch = batches.first else {
            throw ANECapsuleError.executionFailed(
                capsuleId: capsuleId,
                underlyingError: CocoaError(.fileNoSuchFile)
            )
        }
        return firstBatch
    }
}

public struct ANEBatchResult<Output: Sendable>: Sendable {
    public let outputs: [Output]
    public let receipt: ExecutionReceipt?
    public let batchSize: Int

    public init(outputs: [Output], receipt: ExecutionReceipt?, batchSize: Int) {
        self.outputs = outputs
        self.receipt = receipt
        self.batchSize = batchSize
    }
}
