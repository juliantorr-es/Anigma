//
//  InferencePlaneAdapter.swift
//  AnigmaCore
//
//  Bridges MLWorkerInterface to the InferenceCore contract.
//

import Foundation
import InferenceCore

/// Adapter that exposes MLWorkerInterface behind the InferencePlane contract.
public struct MLWorkerInferencePlane: InferencePlane {
    private let mlWorker: MLWorkerInterface

    public init(mlWorker: MLWorkerInterface) {
        self.mlWorker = mlWorker
    }

    public func perform(_ request: InferenceRequest) async throws -> InferenceResponse {
        let options = mapOptions(request.options)

        switch request.task {
        case .textGeneration, .chat:
            let rawOutput = try await mlWorker.performMLTask(
                task: .chat,
                input: request.input,
                modelID: request.modelID,
                options: options
            )
            let output = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            return InferenceResponse(output: output)
        case .embedding:
            let rawOutput = try await mlWorker.performMLTask(
                task: .embedding,
                input: request.input,
                modelID: request.modelID,
                options: options
            )
            let output = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            return InferenceResponse(output: output)
        case .rerank:
            throw InferenceError.unavailable("Rerank task not supported by MLWorker adapter")
        }
    }

    private func mapOptions(_ options: [String: InferenceOptionValue]) -> [String: AnyHashable] {
        var mapped: [String: AnyHashable] = [:]
        for (key, value) in options {
            switch value {
            case .string(let string):
                mapped[key] = string
            case .number(let number):
                mapped[key] = number
            case .integer(let integer):
                mapped[key] = integer
            case .boolean(let bool):
                mapped[key] = bool
            }
        }
        return mapped
    }
}
