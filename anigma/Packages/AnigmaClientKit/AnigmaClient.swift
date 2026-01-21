import AnigmaPrimitives
import ContractsCore
import Foundation

// MARK: - Protocols

public protocol AnigmaClient {
    var query: QueryAPI { get }
    var command: CommandAPI { get }
    var events: EventsAPI { get }

    /// Submits an intent for execution. Returns a receipt.
    func submitIntent(action: String, parameters: [String: BindingValue]) async -> Receipt
}

public protocol CommandAPI {
    @discardableResult
    func createWorkspace(name: String) async throws -> WorkspaceID
    func updateWorkspace(id: WorkspaceID, name: String) async throws
    func deleteWorkspace(id: WorkspaceID) async throws

    @discardableResult
    func uploadArtifact(workspaceId: WorkspaceID, name: String, data: Data) async throws
        -> ArtifactID
    func deleteArtifact(id: ArtifactID) async throws

    func cancelJob(id: JobID) async throws
    func deleteJob(id: JobID) async throws
    func verifyJob(id: JobID) async throws

    func evaluateAction(action: String, parameters: [String: BindingValue]) async throws
        -> IntentEvaluation
}

public protocol QueryAPI {
    func listWorkspaces(cursor: String?, limit: Int) async throws -> Page<WorkspaceSummary>
    func listArtifacts(workspaceID: WorkspaceID, cursor: String?, limit: Int) async throws -> Page<
        ArtifactSummary
    >
    func listJobs(workspaceID: WorkspaceID, cursor: String?, limit: Int) async throws -> Page<
        JobSummary
    >

    func downloadArtifact(id: ArtifactID) async throws -> Data
    func getReceipt(hash: String) async throws -> Receipt
    func evaluateAction(intent: ActionIntent) async throws -> IntentEvaluation
}

public protocol EventsAPI {
    func events() -> AsyncThrowingStream<AnigmaEvent, Error>
}

public protocol HostCapabilities {}

// MARK: - Structs & Enums

public struct WorkspaceSummary: Identifiable, Hashable, Codable, Sendable {
    public let id: WorkspaceID
    public let name: String

    public init(id: WorkspaceID, name: String) {
        self.id = id
        self.name = name
    }
}

public struct ArtifactSummary: Identifiable, Hashable, Codable, Sendable {
    public let id: ArtifactID
    public let name: String
    public let type: String
    public let createdAt: Date

    public init(id: ArtifactID, name: String, type: String = "unknown", createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.type = type
        self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(ArtifactID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = (try? container.decode(String.self, forKey: .type)) ?? "unknown"
        createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
    }
}

public struct JobSummary: Sendable, Codable, Identifiable {
    public let id: JobID
    public let name: String
    public let status: String
    public let isTrusted: Bool
    public let finalReceiptHash: String?
    public let createdAt: Date

    public init(
        id: JobID, name: String, status: String, isTrusted: Bool = false,
        finalReceiptHash: String? = nil, createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.isTrusted = isTrusted
        self.finalReceiptHash = finalReceiptHash
        self.createdAt = createdAt
    }

    public var isTerminal: Bool {
        status.uppercased() == "SUCCEEDED" || status.uppercased() == "FAILED"
            || status.uppercased() == "CANCELED"
    }
}

public enum InspectorSelection: Hashable, Sendable {
    case artifact(id: ArtifactID)
    case job(id: JobID)
    case receipt(hash: String)
    case entity(id: String)
}

public struct AnigmaEvent {
    // Placeholder
    public init() {}
}

public struct Page<T: Sendable>: Sendable {
    public let items: [T]
    public let cursor: String?

    public init(items: [T], cursor: String?) {
        self.items = items
        self.cursor = cursor
    }
}

// MARK: - Type Aliases

public typealias WorkspaceID = String
public typealias ArtifactID = String
public typealias JobID = String
public typealias ReceiptID = String
