//
//  MLWorkerComponents.swift
//  HarmoniaModule
//
//  Components for marking ML tasks and results within the Harmonia ECS.
//

import AnigmaCore
import ContractsCore
import MLWorkerCommon

public struct MLTaskComponent: Component, Codable, Sendable {
    public let runId: String
    public let stepId: String
    public let taskId: String
    public let engine: MLWorkerEngine
    public let kind: MLTaskKind
    public let inputs: [MLArtifactRef]
    public let options: MLTaskOptions
    public var status: MLWorkerStatus
    public let deterministic: Bool

    public init(
        runId: String,
        stepId: String,
        taskId: String,
        engine: MLWorkerEngine,
        kind: MLTaskKind,
        inputs: [MLArtifactRef],
        options: MLTaskOptions = MLTaskOptions(seed: 42),
        status: MLWorkerStatus = .completed,
        deterministic: Bool = true
    ) {
        self.runId = runId
        self.stepId = stepId
        self.taskId = taskId
        self.engine = engine
        self.kind = kind
        self.inputs = inputs
        self.options = options
        self.status = status
        self.deterministic = deterministic
    }
}

public struct MLResultComponent: Component, Codable, Sendable {
    public let runId: String
    public let stepId: String
    public let taskId: String
    public let status: MLWorkerStatus
    public let outputs: [MLWorkerArtifact]
    public let metrics: ContractsCore.MLWorkerMetrics
    public let engineMeta: ContractsCore.MLWorkerEngineMetadata
    public let errorMessage: String?

    public init(
        runId: String,
        stepId: String,
        taskId: String,
        status: MLWorkerStatus,
        outputs: [MLWorkerArtifact],
        metrics: ContractsCore.MLWorkerMetrics,
        engineMeta: ContractsCore.MLWorkerEngineMetadata,
        errorMessage: String? = nil
    ) {
        self.runId = runId
        self.stepId = stepId
        self.taskId = taskId
        self.status = status
        self.outputs = outputs
        self.metrics = metrics
        self.engineMeta = engineMeta
        self.errorMessage = errorMessage
    }
}
