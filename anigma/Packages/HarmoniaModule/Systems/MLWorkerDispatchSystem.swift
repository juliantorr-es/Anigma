//
//  MLWorkerDispatchSystem.swift
//  HarmoniaModule
//
//  ECS system implementation for HarmoniaModule.
//

import DatabaseCore
//
//  MLWorkerDispatchSystem.swift
//  HarmoniaModule/Systems
//
//  Dispatches ML tasks through WorkerSupervisor and records results.
//

import AnigmaCore
import ContractsCore
@preconcurrency import Foundation
import MLWorkerCommon

public struct MLWorkerDispatchSystem: System {
    public var name: String { "MLWorkerDispatchSystem" }

    private let supervisor: WorkerSupervisor

    public init(supervisor: WorkerSupervisor = WorkerSupervisor()) {
        self.supervisor = supervisor
    }

    public func update(world: World) async {
        let tasks = await world.query(MLTaskComponent.self)
        for (entity, task) in tasks {
            guard await !world.hasComponent(entity, MLResultComponent.self) else {
                continue
            }

            let request = MLWorkerRequest(
                requestId: task.taskId,
                runId: task.runId,
                stepId: task.stepId,
                engine: task.engine,
                task: task.kind,
                inputs: task.inputs,
                options: task.options
            )

            do {
                let response = try await supervisor.dispatch(request: request)
                let artifacts: [MLWorkerArtifact] = response.outputs.map {
                    MLWorkerArtifact(path: $0.path, hash: $0.hash)
                }
                let metrics = response.metrics ?? ContractsCore.MLWorkerMetrics(durationMs: 0, tokensProcessed: 0, tokensGenerated: 0, memoryBytes: 0)
                let engineMeta = response.engineMeta ?? ContractsCore.MLWorkerEngineMetadata(
                    binaryHash: "unknown",
                    version: "unknown"
                )

                let result = MLResultComponent(
                    runId: task.runId,
                    stepId: task.stepId,
                    taskId: task.taskId,
                    status: response.status,
                    outputs: artifacts,
                    metrics: metrics,
                    engineMeta: engineMeta,
                    errorMessage: response.errorMessage
                )
                await world.addComponent(entity, result)
                logInfo("ML task \(task.taskId) completed with engine \(task.engine.rawValue)", category: "MLWorkerDispatchSystem")
            } catch {
                logError("ML task \(task.taskId) failed: \(error)", category: "MLWorkerDispatchSystem")
                let fallback = MLResultComponent(
                    runId: task.runId,
                    stepId: task.stepId,
                    taskId: task.taskId,
                    status: .failed,
                    outputs: [],
                    metrics: ContractsCore.MLWorkerMetrics(durationMs: 0, tokensProcessed: 0, tokensGenerated: 0, memoryBytes: 0),
                    engineMeta: ContractsCore.MLWorkerEngineMetadata(
                        binaryHash: "unknown",
                        version: "unknown"
                    ),
                    errorMessage: error.localizedDescription
                )
                await world.addComponent(entity, fallback)
            }
        }
    }
}
