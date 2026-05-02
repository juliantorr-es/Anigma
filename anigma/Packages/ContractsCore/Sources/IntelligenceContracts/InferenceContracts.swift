//
//  InferenceContracts.swift
//  ContractsCore
//
//  Portable inference contracts defining models and tensors.
//

import Foundation

public struct TensorReference: Sendable, Codable, Hashable {
    public let id: String
    public let shape: [Int]
    public let dataType: String
    public let dataHash: String
    
    public init(id: String, shape: [Int], dataType: String, dataHash: String) {
        self.id = id
        self.shape = shape
        self.dataType = dataType
        self.dataHash = dataHash
    }
}

public struct ModelReference: Sendable, Codable, Hashable {
    public let id: String
    public let modelHash: String
    public let backendHint: String?
    
    public init(id: String, modelHash: String, backendHint: String? = nil) {
        self.id = id
        self.modelHash = modelHash
        self.backendHint = backendHint
    }
}

public struct ModelInputDescriptor: Sendable, Codable, Hashable {
    public let name: String
    public let tensor: TensorReference
    
    public init(name: String, tensor: TensorReference) {
        self.name = name
        self.tensor = tensor
    }
}

public struct ModelOutputDescriptor: Sendable, Codable, Hashable {
    public let name: String
    public let tensor: TensorReference
    
    public init(name: String, tensor: TensorReference) {
        self.name = name
        self.tensor = tensor
    }
}

public struct PortableInferenceRequest: Sendable, Codable, Hashable {
    public let requestId: String
    public let model: ModelReference
    public let inputs: [ModelInputDescriptor]
    
    public init(requestId: String, model: ModelReference, inputs: [ModelInputDescriptor]) {
        self.requestId = requestId
        self.model = model
        self.inputs = inputs
    }
}

public struct InferenceOutputBundle: Sendable, Codable, Hashable {
    public let requestId: String
    public let outputs: [ModelOutputDescriptor]
    
    public init(requestId: String, outputs: [ModelOutputDescriptor]) {
        self.requestId = requestId
        self.outputs = outputs
    }
}

public struct InferenceReceipt: Sendable, Codable, Hashable {
    public let requestId: String
    public let modelHash: String
    public let backend: String
    public let computeUnit: String
    public let osVersion: String
    public let executionTimeMs: Int
    
    public init(requestId: String, modelHash: String, backend: String, computeUnit: String, osVersion: String, executionTimeMs: Int) {
        self.requestId = requestId
        self.modelHash = modelHash
        self.backend = backend
        self.computeUnit = computeUnit
        self.osVersion = osVersion
        self.executionTimeMs = executionTimeMs
    }
}
