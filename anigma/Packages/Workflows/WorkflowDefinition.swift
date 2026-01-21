import Foundation
import DataCore
import DataEngine

public struct WorkflowDefinition: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let steps: [WorkflowStep]

    public init(id: String, name: String, description: String, steps: [WorkflowStep]) {
        self.id = id
        self.name = name
        self.description = description
        self.steps = steps
    }
}

public enum WorkflowStep: Sendable {
    case ingest(source: URL)
    case profile
    case transform(TransformIR)
    case query(ViewSpec)
    case render(ViewSpec)
    case export(format: String)
}

public struct WorkflowResult: Sendable {
    public let workflowId: String
    public let artifacts: [Artifact]
    public let receipts: [Receipt]
}
