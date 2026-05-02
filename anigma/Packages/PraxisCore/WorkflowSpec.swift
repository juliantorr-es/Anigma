//
//  WorkflowSpec.swift
//  PraxisCore
//
//  [Brief description of file purpose]
//

import Foundation

/// Workflow stop states.
public enum WorkflowStopState: String, Codable, Sendable {
    case running
    case done
    case blocked
    case failed
}

/// Single workflow step definition.
public struct WorkflowStep: Codable, Sendable {
    public let id: String
    public let phaseId: String
    public let acceptanceRefs: [String]
    public let stopState: WorkflowStopState

    public init(id: String, phaseId: String, acceptanceRefs: [String], stopState: WorkflowStopState) {
        self.id = id
        self.phaseId = phaseId
        self.acceptanceRefs = acceptanceRefs
        self.stopState = stopState
    }
}

/// Workflow specification describing ordered steps.
public struct WorkflowSpec: Sendable {
    public let name: String
    public let steps: [WorkflowStep]

    public init(name: String, steps: [WorkflowStep]) {
        self.name = name
        self.steps = steps
    }

    public static func load(from url: URL) throws -> WorkflowSpec {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let definition = try decoder.decode(WorkflowSpecDefinition.self, from: data)
        return WorkflowSpec(name: definition.name, steps: definition.steps)
    }
}

private struct WorkflowSpecDefinition: Codable {
    let name: String
    let steps: [WorkflowStep]
}
