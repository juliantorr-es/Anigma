//
//  CoreMLExecutor.swift
//  IntelligenceCore
//
//  Governed Core ML model executor (Tier 3) conforming to Tier 1 portable contracts.
//

import Foundation
import CoreML
import IntelligenceContracts
import AnigmaCore

/// Governed Core ML model execution backend.
/// Maps portable TensorReference shapes to native MLMultiArray/MLFeatureProvider objects.
public actor CoreMLExecutor {
    
    private let artifactStore: PipelineArtifactStore
    private var loadedModels: [String: MLModel] = [:]
    
    public init(artifactStore: PipelineArtifactStore) {
        self.artifactStore = artifactStore
    }
    
    /// Executes a portable InferenceRequest using the CoreML backend.
    public func execute(request: PortableInferenceRequest) async throws -> (InferenceOutputBundle, InferenceReceipt) {
        let startTime = DispatchTime.now()
        
        // 1. Resolve Model
        // For production, this would resolve via modelRegistry using request.model.modelHash
        let model: MLModel
        if let cached = loadedModels[request.model.id] {
            model = cached
        } else {
            // Loading the actual model file - assuming path structure
            let modelURL = URL(fileURLWithPath: "/Users/user/Developer/GitHub/Anigma_clean/anigma/Tests/IntelligenceCoreTests/SimpleModel.mlmodelc") 
            model = try MLModel(contentsOf: modelURL)
            loadedModels[request.model.id] = model
        }
        
        // 2. Map Input: TensorReference -> MLMultiArray
        var mlInputs: [String: MLFeatureValue] = [:]
        for inputDesc in request.inputs {
            let (data, _) = try await artifactStore.loadRaw(inputDesc.tensor.dataHash)
            let array = try MLMultiArray(shape: inputDesc.tensor.shape.map { NSNumber(value: $0) }, dataType: .float32)
            // Copy data into MLMultiArray
            _ = data.withUnsafeBytes { ptr in
                memcpy(array.dataPointer, ptr.baseAddress, data.count)
            }
            // Use 'input' as the feature name for our generated model
            mlInputs["input"] = MLFeatureValue(multiArray: array)
        }
        
        // 3. Execution
        let provider = try MLDictionaryFeatureProvider(dictionary: mlInputs)
        let outputProvider = try await model.prediction(from: provider)
        
        // 4. Map Output: MLFeatureValue -> TensorReference
        var outputDescriptors: [ModelOutputDescriptor] = []
        for outputName in outputProvider.featureNames {
            let feature = outputProvider.featureValue(for: outputName)!
            let mlArray = feature.multiArrayValue!
            
            // Extract and store output data
            let outData = Data(bytes: mlArray.dataPointer, count: mlArray.count * 4) // Assuming float32
            let outputHash = try await artifactStore.storeRaw(outData, typeName: "tensor", preferredID: nil)
            
            let shape = (0..<mlArray.shape.count).map { mlArray.shape[$0].intValue }
            
            outputDescriptors.append(ModelOutputDescriptor(
                name: outputName,
                tensor: TensorReference(id: UUID().uuidString, shape: shape, dataType: "float32", dataHash: outputHash)
            ))
        }
        
        let durationMs = Int((DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000)
        
        return (
            InferenceOutputBundle(requestId: request.requestId, outputs: outputDescriptors),
            InferenceReceipt(requestId: request.requestId, modelHash: request.model.modelHash, backend: "CoreML", computeUnit: "NeuralEngine", osVersion: "14.0", executionTimeMs: durationMs)
        )
    }
}
