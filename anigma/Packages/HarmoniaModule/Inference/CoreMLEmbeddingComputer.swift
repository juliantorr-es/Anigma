//
//  CoreMLEmbeddingComputer.swift
//  HarmoniaModule
//
//  CoreML-backed implementation of BufferEmbeddingCapability.
//  Following "Swift governs, compute computes": tokenization happens in Swift,
//  embedding computation happens in CoreML with Metal/MPS acceleration.
//  Uses task-based delegation: spawns one delegate per embedding request.
//

@preconcurrency import Foundation
import ContractsCore
import CapabilityCore

#if canImport(CoreML)
import CoreML
#endif

/// CoreML-backed embedding computer with task-based delegation.
/// Implements BufferEmbeddingCapability for Metal/MPS accelerated embedding.
public actor CoreMLEmbeddingComputer: BufferEmbeddingCapability, CapabilityProvider {
    /// Model cache: modelID -> loaded MLModel
    #if canImport(CoreML)
    private var modelCache: [String: MLModel] = [:]
    #endif
    /// Model dimension cache: modelID -> embedding dimension
    private var dimensionCache: [String: Int] = [:]
    
    public init() {}
    
    // MARK: - CapabilityProvider
    
    public nonisolated let providerId: String = "anigma.provider.embedding.coreml"
    
    public nonisolated var supportedCapabilities: [String] {
        [BufferEmbeddingCapability.capabilityId]
    }
    
    // MARK: - BufferEmbeddingCapability
    
    public func computeEmbeddings(
        modelID: String,
        modelVersion: String?,
        tokenBuffers: [TokenBuffer],
        normalize: Bool
    ) async throws -> [[Float]] {
        #if canImport(CoreML)
        // Load model
        let model = try await loadModel(modelID: modelID, modelVersion: modelVersion)
        
        // Process each token buffer sequentially
        var embeddings: [[Float]] = []
        embeddings.reserveCapacity(tokenBuffers.count)
        
        for tokenBuffer in tokenBuffers {
            // Spawn a delegate task for each token buffer
            // Use a local copy of model to ensure isolation
            let modelCopy = model
            let embedding = try await Task { () -> [Float] in
                let delegate = CoreMLTaskDelegate(model: modelCopy)
                return try await delegate.computeEmbedding(
                    tokenBuffer: tokenBuffer,
                    normalize: normalize
                )
            }.value
            
            embeddings.append(embedding)
        }
        
        return embeddings
        #else
        throw CoreMLEmbeddingError.coreMLNotAvailable
        #endif
    }
    
    public func embeddingDimension(
        modelID: String,
        modelVersion: String?
    ) async throws -> Int {
        #if canImport(CoreML)
        let cacheKey = modelCacheKey(modelID: modelID, modelVersion: modelVersion)
        if let cached = dimensionCache[cacheKey] {
            return cached
        }
        
        // Load model to determine dimension
        let model = try await loadModel(modelID: modelID, modelVersion: modelVersion)
        let dimension = try inferEmbeddingDimension(model: model)
        
        // Cache dimension
        dimensionCache[cacheKey] = dimension
        return dimension
        #else
        throw CoreMLEmbeddingError.coreMLNotAvailable
        #endif
    }
    
    public func supportsModel(
        modelID: String,
        modelVersion: String?
    ) async -> Bool {
        do {
            _ = try await embeddingDimension(modelID: modelID, modelVersion: modelVersion)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Model Loading
    
    #if canImport(CoreML)
    private func loadModel(modelID: String, modelVersion: String?) async throws -> MLModel {
        let cacheKey = modelCacheKey(modelID: modelID, modelVersion: modelVersion)
        
        // Check cache
        if let cached = modelCache[cacheKey] {
            return cached
        }
        
        // Resolve model path from filesystem
        let modelPath = try await resolveModelPath(modelID: modelID, modelVersion: modelVersion)
        
        // Compile and load CoreML model
        let modelURL = URL(fileURLWithPath: modelPath)
        let compiledModelURL = try await MLModel.compileModel(at: modelURL)
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all 
        
        let model = try MLModel(contentsOf: compiledModelURL, configuration: configuration)
        
        // Cache the model
        modelCache[cacheKey] = model
        return model
    }
    
    private func resolveModelPath(modelID: String, modelVersion: String?) async throws -> String {
        let fileManager = FileManager.default
        
        // Check if modelID is already a path to a CoreML model file
        let possibleExtensions = [".mlpackage", ".mlmodel"]
        
        for ext in possibleExtensions {
            let path = "\(modelID)\(ext)"
            if fileManager.fileExists(atPath: path) {
                return path
            }
        }
        
        // Fallback or model registry integration could go here
        throw CoreMLEmbeddingError.modelNotFound(modelID: modelID, modelVersion: modelVersion)
    }
    
    private func inferEmbeddingDimension(model: MLModel) throws -> Int {
        let outputDescriptions = model.modelDescription.outputDescriptionsByName
        let embeddingOutputNames = ["embedding", "output", "features", "last_hidden_state"]
        
        for outputName in embeddingOutputNames {
            if let output = outputDescriptions[outputName] {
                if output.type == .multiArray {
                    if let shapeConstraint = output.multiArrayConstraint {
                        let shape = shapeConstraint.shape
                        if shape.count == 2 && shape[0] == 1 {
                            return shape[1].intValue
                        } else if shape.count == 1 {
                            return shape[0].intValue
                        }
                    }
                }
            }
        }
        
        if let firstOutput = outputDescriptions.values.first {
            if firstOutput.type == .multiArray,
               let shapeConstraint = firstOutput.multiArrayConstraint {
                let shape = shapeConstraint.shape
                if shape.count >= 1 {
                    return shape.last!.intValue
                }
            }
        }
        
        throw CoreMLEmbeddingError.cannotInferDimension
    }
    #endif
    
    // MARK: - Utility
    
    private func modelCacheKey(modelID: String, modelVersion: String?) -> String {
        if let version = modelVersion {
            return "\(modelID)@\(version)"
        }
        return modelID
    }
}

// MARK: - Task Delegate

#if canImport(CoreML)
private actor CoreMLTaskDelegate {
    private let model: MLModel
    
    init(model: MLModel) {
        self.model = model
    }
    
    func computeEmbedding(
        tokenBuffer: TokenBuffer,
        normalize: Bool
    ) async throws -> [Float] {
        let inputArray = try prepareInputArray(tokenBuffer: tokenBuffer)
        let attentionMask = try prepareAttentionMask(tokenBuffer: tokenBuffer)
        
        let input = CoreMLEmbeddingInput(
            input_ids: inputArray,
            attention_mask: attentionMask
        )
        
        let prediction = try await model.prediction(from: input)
        
        guard let embeddingFeature = prediction.featureValue(for: "embedding") else {
            throw CoreMLEmbeddingError.invalidOutput("Model output does not contain 'embedding' feature")
        }
        
        guard let multiArray = embeddingFeature.multiArrayValue else {
            throw CoreMLEmbeddingError.invalidOutput("Embedding output is not a multi-array")
        }
        
        let embedding = multiArray.toFloatArray()
        return normalize ? normalizeVector(embedding) : embedding
    }
    
    private func prepareInputArray(tokenBuffer: TokenBuffer) throws -> MLMultiArray {
        let sequenceLength = tokenBuffer.tokenIds.count
        let shape = [NSNumber(value: 1), NSNumber(value: sequenceLength)]
        
        guard let array = try? MLMultiArray(shape: shape, dataType: .int32) else {
            throw CoreMLEmbeddingError.inputPreparationFailed
        }
        
        for (i, tokenId) in tokenBuffer.tokenIds.enumerated() {
            array[i] = NSNumber(value: tokenId)
        }
        
        return array
    }
    
    private func prepareAttentionMask(tokenBuffer: TokenBuffer) throws -> MLMultiArray {
        let sequenceLength = tokenBuffer.attentionMask.count
        let shape = [NSNumber(value: 1), NSNumber(value: sequenceLength)]
        
        guard let array = try? MLMultiArray(shape: shape, dataType: .float32) else {
            throw CoreMLEmbeddingError.inputPreparationFailed
        }
        
        for (i, maskValue) in tokenBuffer.attentionMask.enumerated() {
            array[i] = NSNumber(value: Float(maskValue))
        }
        
        return array
    }
    
    private func normalizeVector(_ vector: [Float]) -> [Float] {
        let norm = sqrt(vector.reduce(0.0) { $0 + $1 * $1 })
        guard norm > 0 else { return vector }
        return vector.map { $0 / norm }
    }
}

private class CoreMLEmbeddingInput: NSObject, MLFeatureProvider {
    let input_ids: MLMultiArray
    let attention_mask: MLMultiArray
    
    var featureNames: Set<String> {
        return ["input_ids", "attention_mask"]
    }
    
    init(input_ids: MLMultiArray, attention_mask: MLMultiArray) {
        self.input_ids = input_ids
        self.attention_mask = attention_mask
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        switch featureName {
        case "input_ids":
            return MLFeatureValue(multiArray: input_ids)
        case "attention_mask":
            return MLFeatureValue(multiArray: attention_mask)
        default:
            return nil
        }
    }
}

extension MLMultiArray {
    func toFloatArray() -> [Float] {
        let count = self.count
        var floats = [Float](repeating: 0, count: count)
        for i in 0..<count {
            floats[i] = self[i].floatValue
        }
        return floats
    }
}
#endif

// MARK: - Errors

public enum CoreMLEmbeddingError: Error, LocalizedError {
    case coreMLNotAvailable
    case modelNotFound(modelID: String, modelVersion: String?)
    case inputPreparationFailed
    case invalidOutput(String)
    case cannotInferDimension
    
    public var errorDescription: String? {
        switch self {
        case .coreMLNotAvailable:
            return "CoreML is not available on this platform"
        case .modelNotFound(let modelID, let modelVersion):
            return "CoreML model '\(modelID)' not found"
        case .inputPreparationFailed:
            return "Failed to prepare input tensor"
        case .invalidOutput(let reason):
            return "Invalid model output: \(reason)"
        case .cannotInferDimension:
            return "Cannot infer embedding dimension"
        }
    }
}
