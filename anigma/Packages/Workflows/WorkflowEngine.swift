import Foundation
import DataCore
import DataEngine
import AnigmaSystemSpine

public actor WorkflowEngine {
    private let dataEngine: DataEngine
    private let jobEngine: JobEngine

    /// Event subscription IDs for cleanup
    private var eventSubscriptionIds: [UUID] = []

    public init(dataEngine: DataEngine, jobEngine: JobEngine) {
        self.dataEngine = dataEngine
        self.jobEngine = jobEngine
        
        // Setup event subscriptions
        Task { await setupEventSubscriptions() }
    }
    
    deinit {
        // Cleanup event subscriptions
        Task { await cleanupEventSubscriptions() }
    }

    public func execute(workflow: WorkflowDefinition, context: String) async throws -> WorkflowResult {
        var artifacts: [Artifact] = []
        let receipts: [CoreReceipt] = []

        // Execution state tracking
        var lastArtifact: Artifact?
        var knownArtifacts: [String: Artifact] = [:]

        // Execute workflow steps with artifact passing
        for step in workflow.steps {
            switch step {
            case .ingest(let source):
                print("Executing ingest step for \(source)")
                // Simulate ingestion producing a raw artifact
                let artifact = Artifact(
                    id: UUID().uuidString,
                    type: .raw,
                    contentHash: "hash_\(source.hashValue)",
                    metadata: ["source": "\(source)", "context": context]
                )
                artifacts.append(artifact)
                knownArtifacts[artifact.id] = artifact
                lastArtifact = artifact

            case .profile:
                print("Executing profile step")
                if let input = lastArtifact {
                    let artifact = Artifact(
                        id: UUID().uuidString,
                        type: .profile,
                        contentHash: "profile_\(input.contentHash)",
                        metadata: ["parent_id": input.id]
                    )
                    artifacts.append(artifact)
                    knownArtifacts[artifact.id] = artifact
                    lastArtifact = artifact
                }

            case .transform(let transform):
                print("Executing transform step: \(transform.id)")
                if let input = lastArtifact {
                    let artifact = Artifact(
                        id: UUID().uuidString,
                        type: .transform,
                        contentHash: "transform_\(transform.id)_\(input.contentHash)",
                        metadata: ["parent_id": input.id, "transform_id": transform.id]
                    )
                    artifacts.append(artifact)
                    knownArtifacts[artifact.id] = artifact
                    lastArtifact = artifact
                }

            case .query(let viewSpec):
                print("Executing query step: \(viewSpec.query)")
                if let input = lastArtifact {
                     let artifact = Artifact(
                         id: UUID().uuidString,
                         type: .viewSpec,
                         contentHash: "query_\(viewSpec.query.hashValue)",
                         metadata: ["parent_id": input.id, "query": viewSpec.query]
                     )
                     artifacts.append(artifact)
                     lastArtifact = artifact
                 }

            case .render(let viewSpec):
                print("Executing render step: \(viewSpec.query)")
                if let input = lastArtifact {
                     let artifact = Artifact(
                         id: UUID().uuidString,
                         type: .render,
                         contentHash: "render_\(viewSpec.query.hashValue)",
                         metadata: ["parent_id": input.id]
                     )
                     artifacts.append(artifact)
                     lastArtifact = artifact
                 }

            case .export(let format):
                print("Executing export step: \(format)")
                // Export side-effect
            }
        }

        return WorkflowResult(workflowId: workflow.id, artifacts: artifacts, receipts: receipts)
    }
}
