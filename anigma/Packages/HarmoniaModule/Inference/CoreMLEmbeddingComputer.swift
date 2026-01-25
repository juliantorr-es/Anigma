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

#if canImport(ModelRegistryModule)
import ModelRegistryModule
#endif

#if canImport(CoreML)
import CoreML
#endif

/// CoreML-backed embedding computer with task-based delegation.
/// Implements BufferEmbeddingCapability for Metal/MPS accelerated embedding.
public actor CoreMLEmbeddingComputer: BufferEmbeddingCapability, CapabilityProvider {
    /// Model cache: modelID -> loaded MLModel
    private var modelCache: [String: MLModel] = [:]
    /// Model dimension cache: modelID -> embedding dimension
    private var dimensionCache: [String: Int] = [:]
    /// Optional model registry for model path resolution
    #if canImport(ModelRegistryModule)
    private var modelRegistry: ModelRegistryModule?
    #endif
    
    public init() {}
    
    /// Initialize with model registry for path resolution
    #if canImport(ModelRegistryModule)
    public init(modelRegistry: ModelRegistryModule?) {
        self.modelRegistry = modelRegistry
    }
    #endif
    
    // MARK: - CapabilityProvider
    
    public let providerId: String = "anigma.provider.embedding.coreml"
    
    public var supportedCapabilities: [String] {
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
        
        // Process each token buffer sequentially (could be parallelized with TaskGroup)
        var embeddings: [[Float]] = []
        embeddings.reserveCapacity(tokenBuffers.count)
        
        for tokenBuffer in tokenBuffers {
            // Spawn a delegate task for each token buffer
            let embedding = try await Task { () -> [Float] in
                // Create a delegate for this specific computation
                let delegate = CoreMLTaskDelegate(model: model)
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
        
        // Resolve model path from registry or filesystem
        let modelPath = try await resolveModelPath(modelID: modelID, modelVersion: modelVersion)
        
        // Compile and load CoreML model
        let modelURL = URL(fileURLWithPath: modelPath)
        let compiledModelURL = try MLModel.compileModel(at: modelURL)
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all // Use CPU, GPU, ANE as available
        
        let model = try MLModel(contentsOf: compiledModelURL, configuration: configuration)
        
        // Cache the model
        modelCache[cacheKey] = model
        return model
    }
    
    private func resolveModelPath(modelID: String, modelVersion: String?) async throws -> String {
        let fileManager = FileManager.default
        
        // Strategy 1: Check if modelID is already a path to a CoreML model file
        let possibleExtensions = [".mlpackage", ".mlmodel"]
        
        for ext in possibleExtensions {
            let path = "\(modelID)\(ext)"
            if fileManager.fileExists(atPath: path) {
                return path
            }
        }
        
        // Strategy 2: Try to resolve via ModelRegistry (if available)
        #if canImport(ModelRegistryModule)
        if let registry = modelRegistry {
            do {
                // Try to get model by modelID only (latest version)
                let modelRecord = try await registry.getLatestModel(modelID: modelID)
                
                // Check if it's a CoreML backend
                guard modelRecord.backendKind == .coreml else {
                    throw CoreMLEmbeddingError.modelNotFound(
                        modelID: modelID,
                        modelVersion: modelVersion
                    )
                }
                
                // Check if it's a local source type (direct path)
                if modelRecord.source.type == "local" {
                    let localPath = modelRecord.source.identifier
                    if fileManager.fileExists(atPath: localPath) {
                        return localPath
                    } else {
                        throw CoreMLEmbeddingError.modelPathNotAccessible(
                            modelID: modelID,
                            path: localPath
                        )
                    }
                } else if modelRecord.source.type == "bundled" {
                    // Attempt to locate bundled CoreML model
                    let identifier = modelRecord.source.identifier
                    guard let path = resolveBundledModelPath(identifier: identifier) else {
                        throw CoreMLEmbeddingError.modelPathNotAccessible(
                            modelID: modelID,
                            path: "Bundle resource: \(identifier)"
                        )
                    }
                    return path
                } else {
                    // HuggingFace or other sources would need conversion to CoreML
                    throw CoreMLEmbeddingError.modelNotSupported(
                        modelID: modelID,
                        reason: "Source type '\(modelRecord.source.type)' requires conversion to CoreML"
                    )
                }
            } catch ModelRegistryError.modelIDNotFound {
                // Fall through to model not found error below
            }
        }
        #endif
        
        // Strategy 3: Model not found
        throw CoreMLEmbeddingError.modelNotFound(modelID: modelID, modelVersion: modelVersion)
    }
    
    private func resolveBundledModelPath(identifier: String) -> String? {
        let possibleExtensions = [".mlpackage", ".mlmodel"]
        
        // Try main bundle (app bundle)
        if let path = Bundle.main.path(forResource: identifier, ofType: nil) {
            return path
        }
        
        // Try with extensions
        for ext in possibleExtensions {
            let resource = identifier.hasSuffix(ext) ? identifier : identifier + ext
            if let path = Bundle.main.path(forResource: resource, ofType: nil) {
                return path
            }
        }
        
        // Try module bundle (SwiftPM resources)
        #if canImport(SwiftUI)
        let moduleBundle = Bundle.module
        if let path = moduleBundle.path(forResource: identifier, ofType: nil) {
            return path
        }
        
        for ext in possibleExtensions {
            let resource = identifier.hasSuffix(ext) ? identifier : identifier + ext
            if let path = moduleBundle.path(forResource: resource, ofType: nil) {
                return path
            }
        }
        #endif
        
        // Search all bundles
        let bundles = Bundle.allBundles + Bundle.allFrameworks
        for bundle in bundles {
            if let path = bundle.path(forResource: identifier, ofType: nil) {
                return path
            }
            for ext in possibleExtensions {
                let resource = identifier.hasSuffix(ext) ? identifier : identifier + ext
                if let path = bundle.path(forResource: resource, ofType: nil) {
                    return path
                }
            }
        }
        
        return nil
    }
    
    private func inferEmbeddingDimension(model: MLModel) throws -> Int {
        // Examine model output description
        let outputDescriptions = model.modelDescription.outputDescriptionsByName
        
        // Look for embedding output (common names: "embedding", "output", "features")
        let embeddingOutputNames = ["embedding", "output", "features", "last_hidden_state"]
        
        for outputName in embeddingOutputNames {
            if let output = outputDescriptions[outputName] {
                // For embedding models, output is typically multi-array with shape [1, dimension]
                if output.type == .multiArray {
                    if let shapeConstraint = output.multiArrayConstraint {
                        // Shape is typically [1, dimension] or [dimension]
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
        
        // Fallback: try to infer from first output
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
/// Task-specific delegate for CoreML embedding computation.
/// Each token buffer computation gets its own delegate actor.
private actor CoreMLTaskDelegate {
    private let model: MLModel
    
    init(model: MLModel) {
        self.model = model
    }
    
    func computeEmbedding(
        tokenBuffer: TokenBuffer,
        normalize: Bool
    ) async throws -> [Float] {
        // Prepare MLMultiArray inputs
        let inputArray = try prepareInputArray(tokenBuffer: tokenBuffer)
        let attentionMask = prepareAttentionMask(tokenBuffer: tokenBuffer)
        
        // Create feature provider
        let input = CoreMLEmbeddingInput(
            input_ids: inputArray,
            attention_mask: attentionMask
        )
        
        // Perform prediction
        let prediction = try await model.prediction(from: input)
        
        // Extract embedding output
        guard let embeddingFeature = prediction.featureValue(for: "embedding") else {
            throw CoreMLEmbeddingError.invalidOutput("Model output does not contain 'embedding' feature")
        }
        
        // Convert MLMultiArray to [Float]
        guard let multiArray = embeddingFeature.multiArrayValue else {
            throw CoreMLEmbeddingError.invalidOutput("Embedding output is not a multi-array")
        }
        
        let embedding = multiArray.toFloatArray()
        
        // Normalize if requested
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
    
    private func prepareAttentionMask(tokenBuffer: TokenBuffer) -> MLMultiArray {
        let sequenceLength = tokenBuffer.attentionMask.count
        let shape = [NSNumber(value: 1), NSNumber(value: sequenceLength)]
        
        // Note: Using float32 for attention mask as some models expect float
        guard let array = try? MLMultiArray(shape: shape, dataType: .float32) else {
            // Fallback to int32 if float32 fails
            guard let fallback = try? MLMultiArray(shape: shape, dataType: .int32) else {
                throw CoreMLEmbeddingError.inputPreparationFailed
            }
            for (i, maskValue) in tokenBuffer.attentionMask.enumerated() {
                fallback[i] = NSNumber(value: maskValue)
            }
            return fallback
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
#endif

// MARK: - CoreML Input/Output Types

#if canImport(CoreML)
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
#endif

// MARK: - MLMultiArray Extension

#if canImport(CoreML)
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
    case modelPathNotAccessible(modelID: String, path: String)
    case modelNotSupported(modelID: String, reason: String)
    case cannotInferDimension
    case inputPreparationFailed
    case invalidOutput(String)
    
    public var errorDescription: String? {
        switch self {
        case .coreMLNotAvailable:
            return "CoreML is not available on this platform"
        case .modelNotFound(let modelID, let modelVersion):
            let versionStr = modelVersion.map { " version \($0)" } ?? ""
            return "CoreML model '\(modelID)'\(versionStr) not found"
        case .modelPathNotAccessible(let modelID, let path):
            return "CoreML model '\(modelID)' path is not accessible: \(path)"
        case .modelNotSupported(let modelID, let reason):
            return "CoreML model '\(modelID)' not supported: \(reason)"
        case .cannotInferDimension:
            return "Cannot infer embedding dimension from model"
        case .inputPreparationFailed:
            return "Failed to prepare input tensor"
        case .invalidOutput(let reason):
            return "Invalid model output: \(reason)"
        }
    }
}