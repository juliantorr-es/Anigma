import AnigmaPrimitives
import ContractsCore
import Foundation

public struct MacClientFactory {
    public static func makeClient(host: HostCapabilities) -> AnigmaClient {
        return MockAnigmaClient()
    }
}

private class MockAnigmaClient: AnigmaClient {
    var query: QueryAPI = MockQueryAPI()
    var command: CommandAPI = MockCommandAPI()
    var events: EventsAPI = MockEventsAPI()

    func submitIntent(action: String, parameters: [String: BindingValue]) async -> Receipt {
        return Receipt(
            ref: ReceiptRef(id: UUID().uuidString, intentHash: "mock-hash"),
            status: .success,
            outcome: .string("Mock execution of \(action)"),
            seal: .unsigned(hash: "mock-hash")
        )
    }
}

private class MockQueryAPI: QueryAPI {
    func listWorkspaces(cursor: String?, limit: Int) async throws -> Page<WorkspaceSummary> {
        return Page(
            items: [
                WorkspaceSummary(id: "ws1", name: "Workspace 1"),
                WorkspaceSummary(id: "ws2", name: "Workspace 2")
            ], cursor: nil)
    }

    func listArtifacts(workspaceID: WorkspaceID, cursor: String?, limit: Int) async throws -> Page<
        ArtifactSummary
    > {
        return Page(
            items: [
                ArtifactSummary(id: "art1", name: "Artifact 1"),
                ArtifactSummary(id: "art2", name: "Artifact 2")
            ], cursor: nil)
    }

    func listJobs(workspaceID: WorkspaceID, cursor: String?, limit: Int) async throws -> Page<
        JobSummary
    > {
        return Page(
            items: [
                JobSummary(id: "job1", name: "Job 1", status: "Completed"),
                JobSummary(id: "job2", name: "Job 2", status: "Running")
            ], cursor: nil)
    }

    func downloadArtifact(id: ArtifactID) async throws -> Data {
        return Data()
    }

    func getReceipt(hash: String) async throws -> Receipt {
        return Receipt(
            ref: ReceiptRef(id: "rcpt-\(hash)", intentHash: "intent-\(hash)"),
            status: .success,
            outcome: .string("Success outcome"),
            seal: .unsigned(hash: hash),
            previousReceiptHash: hash == "latest" ? "prev-hash" : nil
        )
    }

    func evaluateAction(intent: ActionIntent) async throws -> IntentEvaluation {
        return .allowed
    }
}

private class MockCommandAPI: CommandAPI {
    func createWorkspace(name: String) async throws -> WorkspaceID { "ws-new" }
    func updateWorkspace(id: WorkspaceID, name: String) async throws {}
    func deleteWorkspace(id: WorkspaceID) async throws {}
    func uploadArtifact(workspaceId: WorkspaceID, name: String, data: Data) async throws
        -> ArtifactID { "art-new" }
    func deleteArtifact(id: ArtifactID) async throws {}
    func cancelJob(id: JobID) async throws {}
    func deleteJob(id: JobID) async throws {}
    func verifyJob(id: JobID) async throws {}
    func evaluateAction(action: String, parameters: [String: BindingValue]) async throws
        -> IntentEvaluation {
        return .allowed
    }
}

private class MockEventsAPI: EventsAPI {
    func events() -> AsyncThrowingStream<AnigmaEvent, Error> {
        return AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}
