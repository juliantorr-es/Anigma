import FoundationContracts
import ContractsCore
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Governance Mode

public enum GovernanceMode: String, CaseIterable, Codable, Sendable {
    case local
    case verify
    case trusted
    case off
    
    public var displayName: String {
        switch self {
        case .local:
            return "Local"
        case .verify:
            return "Verify"
        case .trusted:
            return "Trusted"
        case .off:
            return "Off"
        }
    }
    
    public var description: String {
        switch self {
        case .local:
            return "Processing happens on-device by default."
        case .verify:
            return "Verification receipts required for all results."
        case .trusted:
            return "Running on a verified, trusted remote host."
        case .off:
            return "Ungoverned mode. No verification receipts."
        }
    }
}

// MARK: - Access Gates

public enum AccessGates {
    public static func canAccessWorkerQueue(role: String) -> Bool {
        // Allow worker, admin, developer roles to access worker queue
        return role == "worker" || role == "admin" || role == "developer"
    }
    
    public static func canAccessAdminConsole(role: String, adminSurfacesEnabled: Bool) -> Bool {
        guard adminSurfacesEnabled else { return false }
        return role == "admin"
    }
    
    public static func canAccessDeveloperTools(role: String, developerToolsEnabled: Bool) -> Bool {
        guard developerToolsEnabled else { return false }
        return role == "developer" || role == "admin"
    }
}

// MARK: - Minimal client-side compatibility surface for the host SDK.
public protocol AnigmaClient: Sendable {}

public protocol HostCapabilities: Sendable {}

// MARK: - Core Receipt Type

public struct CoreReceipt: Identifiable, Codable, Sendable {
    public let id: String
    public var rawValue: String { id }
    public let operationType: String
    public let timestamp: Date
    public let summary: String?
    public let metadata: [String: String]
    
    public init(id: String, operationType: String = "unknown", timestamp: Date = Date(), summary: String? = nil, metadata: [String: String] = [:]) {
        self.id = id
        self.operationType = operationType
        self.timestamp = timestamp
        self.summary = summary
        self.metadata = metadata
        
        // Initialize other properties with defaults
        self.ref = ReceiptRef(id: id, timestamp: timestamp)
        self.status = .success
        self.seal = nil
        self.ledgerLink = nil
    }
    
    public struct ReceiptRef: Codable, Sendable {
        public let id: String
        public let timestamp: Date
        public let intentHash: String
        
        public init(id: String, timestamp: Date = Date(), intentHash: String = "") {
            self.id = id
            self.timestamp = timestamp
            self.intentHash = intentHash
        }
    }
    
    public enum ReceiptStatus: String, Codable, Sendable {
        case success
        case failure
        case pending
    }
    
    public let ref: ReceiptRef
    public let status: ReceiptStatus
    public let seal: String?
    public let ledgerLink: String?
    
    public init(rawValue: String, ref: ReceiptRef? = nil, status: ReceiptStatus = .pending, seal: String? = nil, ledgerLink: String? = nil) {
        self.id = rawValue
        self.ref = ref ?? ReceiptRef(id: rawValue)
        self.status = status
        self.seal = seal
        self.ledgerLink = ledgerLink
        
        // Initialize other required properties
        self.operationType = "unknown"
        self.timestamp = Date()
        self.summary = nil
        self.metadata = [:]
    }
    
    public var previousReceiptHash: String? { nil }
}

// MARK: - Receipt Type (alias)

public typealias Receipt = CoreReceipt

// MARK: - Assistant Types

public struct AssistantState: Codable, Sendable {
    public let id: String
    public let name: String
    public let status: String
    
    public init(id: String = "default", name: String = "Assistant", status: String = "ready") {
        self.id = id
        self.name = name
        self.status = status
    }
}

public struct ToolAvailability: Codable, Sendable {
    public let name: String
    public let available: Bool
    public let version: String?
    
    public init(name: String, available: Bool = true, version: String? = nil) {
        self.name = name
        self.available = available
        self.version = version
    }
}

// MARK: - Workspace Types

public struct WorkspaceSummary: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let createdAt: Date?
    
    public init(id: String, name: String, description: String? = nil, createdAt: Date? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.createdAt = createdAt
    }
}

// MARK: - Governance Types

public struct GovernanceTelemetryEntry: Codable, Sendable, Identifiable {
    public var id: String { "\(timestamp.timeIntervalSince1970)-\(eventType)" }
    public let timestamp: Date
    public let eventType: String
    public let module: String
    public let details: [String: String]

    public init(timestamp: Date, eventType: String, module: String, details: [String: String]) {
        self.timestamp = timestamp
        self.eventType = eventType
        self.module = module
        self.details = details
    }
}

public struct GovernanceStatus: Codable, Sendable {
    public let mode: String
    public let violations: Int
    public let lastChecked: Date?
}

// MARK: - Model Search Types

public struct HFSearchResult: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let modelId: String
    public let name: String?
    public let description: String?
    public let size: Int?
    
    public init(id: String, modelId: String, name: String? = nil, description: String? = nil, size: Int? = nil) {
        self.id = id
        self.modelId = modelId
        self.name = name
        self.description = description
        self.size = size
    }
}

public protocol QueryAPI: Sendable {
    func listWorkspaces(cursor: String?, limit: Int) async throws -> Page<WorkspaceSummary>
    func listArtifacts(workspaceID: WorkspaceID, cursor: String?, limit: Int) async throws -> Page<ArtifactSummary>
    func listJobs(workspaceID: WorkspaceID, cursor: String?, limit: Int) async throws -> Page<JobSummary>
    func downloadArtifact(id: ArtifactID) async throws -> Data
    func getReceipt(hash: String) async throws -> CoreReceipt
    func evaluateAction(intent: ActionIntent) async throws -> IntentEvaluation
}

public protocol CommandAPI: Sendable {
    func createWorkspace(name: String) async throws -> WorkspaceID
    func updateWorkspace(id: WorkspaceID, name: String) async throws
    func deleteWorkspace(id: WorkspaceID) async throws
    func uploadArtifact(workspaceId: WorkspaceID, name: String, data: Data) async throws -> ArtifactID
    func deleteArtifact(id: ArtifactID) async throws
    func cancelJob(id: JobID) async throws
    func deleteJob(id: JobID) async throws
    func verifyJob(id: JobID) async throws
    func evaluateAction(action: String, parameters: [String: BindingValue]) async throws -> IntentEvaluation
}

public protocol EventsAPI: Sendable {
    func events() -> AsyncThrowingStream<AnigmaEvent, Error>
}

public protocol AuthorityRouting: Sendable {}

public struct Page<Item: Codable & Sendable>: Codable, Sendable {
    public let items: [Item]
    public let cursor: String?

    public init(items: [Item] = [], cursor: String? = nil) {
        self.items = items
        self.cursor = cursor
    }
}

public struct ArtifactSummary: Codable, Sendable, Identifiable {
    public let id: ArtifactID
    public let name: String
    public let type: String
    public let createdAt: Date

    public init(id: ArtifactID, name: String, type: String = "data", createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.type = type
        self.createdAt = createdAt
    }
}

public struct JobSummary: Codable, Sendable, Identifiable {
    public let id: JobID
    public let name: String
    public let status: String
    public let isTrusted: Bool
    public let finalReceiptHash: String?
    public let createdAt: Date

    public init(id: JobID, name: String, status: String, isTrusted: Bool, finalReceiptHash: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.status = status
        self.isTrusted = isTrusted
        self.finalReceiptHash = finalReceiptHash
        self.createdAt = createdAt
    }
}

public struct AnigmaEvent: Codable, Sendable {
    public init() {}
}

public typealias WorkspaceID = String
public typealias ArtifactID = String
public typealias JobID = String

/// Basic HTTP client for interacting with the Anigma daemon API.
public struct HTTPAnigmaClient {
    /// Configuration for the Anigma daemon connection
    public struct Configuration {
        public let host: String
        public let port: Int
        public let scheme: String
        public let timeout: TimeInterval
        
        public init(
            host: String = "localhost",
            port: Int = 8080,
            scheme: String = "http",
            timeout: TimeInterval = 30.0
        ) {
            self.host = host
            self.port = port
            self.scheme = scheme
            self.timeout = timeout
        }
    }
    
    private let configuration: Configuration
    private let session: URLSession
    
    /// Initialize a new AnigmaClient
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout * 10
        self.session = URLSession(configuration: sessionConfig)
    }
    
    /// Build the base URL for API calls
    private func baseURL() -> URL? {
        let urlString = "\(configuration.scheme)://\(configuration.host):\(configuration.port)"
        return URL(string: urlString)
    }
}

// MARK: - AnigmaClient Extensions

extension AnigmaClient {
    /// Provides query API access for backward compatibility
    public var query: QueryAPI {
        DefaultQueryAPI()
    }
    
    /// Provides command API access for backward compatibility
    public var command: CommandAPI {
        DefaultCommandAPI()
    }
    
    /// Provides events API access for backward compatibility
    public var events: EventsAPI {
        DefaultEventsAPI()
    }
}

// MARK: - Default API Implementations (Stubs)

struct DefaultQueryAPI: QueryAPI {
    func listWorkspaces(cursor: String?, limit: Int) async throws -> Page<WorkspaceSummary> {
        throw ContractExecutionError.underlying(code: "not_implemented", message: "listWorkspaces not implemented in DefaultQueryAPI stub")
    }
    
    func listArtifacts(workspaceID: WorkspaceID, cursor: String?, limit: Int) async throws -> Page<ArtifactSummary> {
        throw ContractExecutionError.underlying(code: "not_implemented", message: "listArtifacts not implemented in DefaultQueryAPI stub")
    }
    
    func listJobs(workspaceID: WorkspaceID, cursor: String?, limit: Int) async throws -> Page<JobSummary> {
        throw ContractExecutionError.underlying(code: "not_implemented", message: "listJobs not implemented in DefaultQueryAPI stub")
    }
    
    func downloadArtifact(id: ArtifactID) async throws -> Data {
        throw ContractExecutionError.underlying(code: "not_implemented", message: "downloadArtifact not implemented in DefaultQueryAPI stub")
    }
    
    func getReceipt(hash: String) async throws -> CoreReceipt {
        throw ContractExecutionError.underlying(code: "not_implemented", message: "getReceipt not implemented in DefaultQueryAPI stub")
    }
    
    func evaluateAction(intent: ActionIntent) async throws -> IntentEvaluation {
        throw ContractExecutionError.underlying(code: "not_implemented", message: "evaluateAction not implemented in DefaultQueryAPI stub")
    }
}

struct DefaultCommandAPI: CommandAPI {
    func createWorkspace(name: String) async throws -> WorkspaceID {
        throw ContractExecutionError.underlying(code: "not_implemented", message: "createWorkspace not implemented in DefaultCommandAPI stub")
    }
    
    func updateWorkspace(id: WorkspaceID, name: String) async throws {
        throw ContractExecutionError.underlying(code: "not_implemented", message: "updateWorkspace not implemented in DefaultCommandAPI stub")
    }
    
    func deleteWorkspace(id: WorkspaceID) async throws {
        throw ContractExecutionError.underlying(code: "not_implemented", message: "deleteWorkspace not implemented in DefaultCommandAPI stub")
    }
    
    func uploadArtifact(workspaceId: WorkspaceID, name: String, data: Data) async throws -> ArtifactID {
        throw ContractExecutionError.underlying(code: "not_implemented", message: "uploadArtifact not implemented in DefaultCommandAPI stub")
    }
    
    func deleteArtifact(id: ArtifactID) async throws {
        throw ContractExecutionError.underlying(code: "not_implemented", message: "deleteArtifact not implemented in DefaultCommandAPI stub")
    }
    
    func cancelJob(id: JobID) async throws {
        throw ContractExecutionError.underlying(code: "not_implemented", message: "cancelJob not implemented in DefaultCommandAPI stub")
    }
    
    func deleteJob(id: JobID) async throws {
        throw ContractExecutionError.underlying(code: "not_implemented", message: "deleteJob not implemented in DefaultCommandAPI stub")
    }
    
    func verifyJob(id: JobID) async throws {
        throw ContractExecutionError.underlying(code: "not_implemented", message: "verifyJob not implemented in DefaultCommandAPI stub")
    }
    
    func evaluateAction(action: String, parameters: [String: BindingValue]) async throws -> IntentEvaluation {
        throw ContractExecutionError.underlying(code: "not_implemented", message: "evaluateAction not implemented in DefaultCommandAPI stub")
    }
}

struct DefaultEventsAPI: EventsAPI {
    func events() -> AsyncThrowingStream<AnigmaEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: ContractExecutionError.underlying(code: "not_implemented", message: "events not implemented in DefaultEventsAPI stub"))
        }
    }
}

// MARK: - HarmoniaClient Response Types (stub implementations)

public struct HarmoniaClientSearchResult: Codable {
    public let id: String
    public let name: String
    public let description: String?
}

public struct HarmoniaClientSearchResponse: Codable {
    public let query: String
    public let results: [HarmoniaClientSearchResult]
    public let totalMatches: Int
}

public struct HarmoniaClientTechDebtAuditResponse: Codable {
    public let debtScore: Double
    public let issues: [String]
}

public struct HarmoniaClientVaultStatusResponse: Codable {
    public let isHealthy: Bool
    public let receiptCount: Int
    public let diskUsage: Int64
    public let headHash: String?
    public let lastVerifiedAt: Date?
}

public struct HarmoniaClientVaultVerifyResponse: Codable {
    public let success: Bool
    public let message: String?
}

public struct HarmoniaClientVaultVerificationResponse: Codable {
    public let success: Bool
    public let message: String?
}

public struct HarmoniaClientVaultGCResponse: Codable {
    public let success: Bool
    public let deletedCount: Int
    public let reclaimedSpace: Int64
}

public struct HarmoniaClientDaemonStatusResponse: Codable {
    public let running: Bool
    public let version: String?
}

// MARK: - Response Types

struct PacksResponseData: Codable {
    let packs: [String]
    let totalCount: Int
}

struct ScanResponseData: Codable {
    let results: [String]
    let totalIssues: Int
}

struct ViolationStatsResponseData: Codable {
    let byDomain: [String: Int]
    let total: Int
}

// Doctrine Response Type Aliases
typealias PacksResponse = PacksResponseData
typealias ScanResponse = ScanResponseData
typealias ViolationStatsResponse = ViolationStatsResponseData

// MARK: - DoctrineClient Protocol and Stubs

protocol DoctrineClient {
    func getPacks() async throws -> PacksResponse
    func getPack(name: String) async throws -> [String: String]?
    func scan() async throws -> ScanResponse
    func getViolationStats() async throws -> ViolationStatsResponse
}

struct DefaultDoctrineClient: DoctrineClient {
    func getPacks() async throws -> PacksResponse {
        PacksResponseData(packs: [], totalCount: 0)
    }
    
    func getPack(name: String) async throws -> [String: String]? {
        nil
    }
    
    func scan() async throws -> ScanResponse {
        ScanResponseData(results: [], totalIssues: 0)
    }
    
    func getViolationStats() async throws -> ViolationStatsResponse {
        ViolationStatsResponseData(byDomain: [:], total: 0)
    }
}

// MARK: - Analysis Types

public enum AnalysisPhase: String, CaseIterable, Codable, Sendable {
    case idle
    case preparing
    case analyzing
    case computing
    case verifying
    case complete
    case error
    
    public var displayName: String {
        switch self {
        case .idle:
            return "Idle"
        case .preparing:
            return "Preparing"
        case .analyzing:
            return "Analyzing"
        case .computing:
            return "Computing"
        case .verifying:
            return "Verifying"
        case .complete:
            return "Complete"
        case .error:
            return "Error"
        }
    }
}

public struct AnalysisStatus: Codable, Sendable {
    public let phase: AnalysisPhase
    public let progress: Double // 0.0 to 1.0
    public let capsuleName: String?
    public let metalDevice: String?
    public let phaseName: String
    
    public init(
        phase: AnalysisPhase = .idle,
        progress: Double = 0.0,
        capsuleName: String? = nil,
        metalDevice: String? = nil,
        phaseName: String = "idle"
    ) {
        self.phase = phase
        self.progress = progress
        self.capsuleName = capsuleName
        self.metalDevice = metalDevice
        self.phaseName = phaseName
    }
    
    // Explicit Codable conformance
    enum CodingKeys: String, CodingKey {
        case phase, progress, capsuleName, metalDevice, phaseName
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(phase, forKey: .phase)
        try container.encode(progress, forKey: .progress)
        try container.encode(capsuleName, forKey: .capsuleName)
        try container.encode(metalDevice, forKey: .metalDevice)
        try container.encode(phaseName, forKey: .phaseName)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.phase = try container.decode(AnalysisPhase.self, forKey: .phase)
        self.progress = try container.decode(Double.self, forKey: .progress)
        self.capsuleName = try container.decodeIfPresent(String.self, forKey: .capsuleName)
        self.metalDevice = try container.decodeIfPresent(String.self, forKey: .metalDevice)
        self.phaseName = try container.decode(String.self, forKey: .phaseName)
    }
}

public struct AnalysisResult: Codable, Identifiable, Sendable {
    public let id: String
    public let output: String?
    public let confidence: Double
    
    public init(id: String = UUID().uuidString, output: String? = nil, confidence: Double = 0.0) {
        self.id = id
        self.output = output
        self.confidence = confidence
    }
}

public struct AnalysisReceipt: Codable, Identifiable, Sendable {
    public let id: String
    public let timestamp: Date
    public let operationType: String
    public let hash: String?
    
    public init(id: String = UUID().uuidString, timestamp: Date = Date(), operationType: String = "analysis", hash: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.operationType = operationType
        self.hash = hash
    }
}

public struct AnalysisSource: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let type: String
    
    public init(id: String = UUID().uuidString, name: String = "", type: String = "unknown") {
        self.id = id
        self.name = name
        self.type = type
    }
}

public struct Analysis: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String?
    public let description: String?
    public let computeStatus: AnalysisStatus?
    public let results: [AnalysisResult]
    public let receipts: [AnalysisReceipt]
    public let sources: [AnalysisSource]
    public let elapsedTime: Double
    public let createdAt: Date
    
    public init(
        id: String = UUID().uuidString,
        title: String? = nil,
        description: String? = nil,
        computeStatus: AnalysisStatus? = nil,
        results: [AnalysisResult] = [],
        receipts: [AnalysisReceipt] = [],
        sources: [AnalysisSource] = [],
        elapsedTime: Double = 0.0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.computeStatus = computeStatus
        self.results = results
        self.receipts = receipts
        self.sources = sources
        self.elapsedTime = elapsedTime
        self.createdAt = createdAt
    }
}

// MARK: - HuggingFace Keychain

public struct HuggingFaceKeychain: Sendable {
    private let keychainService = "com.anigma.huggingface"
    
    public init() {}
    
    public var hasToken: Bool {
        get async {
            await getToken() != nil
        }
    }
    
    public func getToken() async -> String? {
        // Stub implementation - returns nil (no token stored)
        nil
    }
    
    public func setToken(_ token: String) async throws {
        // Stub implementation - no-op
    }
    
    public func deleteToken() async throws {
        // Stub implementation - no-op
    }
}
