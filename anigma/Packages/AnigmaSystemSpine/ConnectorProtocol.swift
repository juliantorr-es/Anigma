import Foundation

public protocol GovernanceIntent: Sendable, Codable {
    var id: UUID { get }
    var description: String { get }
}

public struct ExternalRef: Codable, Sendable {
    public let systemId: String
    public let externalId: String
    public let name: String
    public let type: String
    public let metadata: [String: String]

    public init(systemId: String, externalId: String, name: String, type: String, metadata: [String: String] = [:]) {
        self.systemId = systemId
        self.externalId = externalId
        self.name = name
        self.type = type
        self.metadata = metadata
    }
}

public struct ReceiptStruct: Codable, Sendable {
    public let id: String
    public let timestamp: Date
    public let actor: String
    public let action: String
    public let status: ReceiptStatus
    public let details: [String: String]

    public init(id: String, timestamp: Date, actor: String, action: String, status: ReceiptStatus, details: [String: String]) {
        self.id = id
        self.timestamp = timestamp
        self.actor = actor
        self.action = action
        self.status = status
        self.details = details
    }
}

public enum ReceiptStatus: String, Codable, Sendable {
    case success
    case failure
    case pending
}

public enum ConnectorType: String, Codable, Sendable {
    case microsoft365
    case googleWorkspace
    case slack
    case jira
    case serviceNow
    case docuSign
    case salesforce
    case confluence
    case lti
    case oneRoster
    case box
    case dropbox
    case clio
    case quickbooks
    case blackbaud
}

public struct ConnectorAccessToken: Sendable {
    public let value: String
    public let tokenType: String
    public let expiresAt: Date?

    public init(value: String, tokenType: String = "Bearer", expiresAt: Date? = nil) {
        self.value = value
        self.tokenType = tokenType
        self.expiresAt = expiresAt
    }

    public var authorizationHeaderValue: String {
        guard !tokenType.isEmpty else { return value }
        return "\(tokenType) \(value)"
    }

    public var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date() >= expiresAt
    }
}

public struct ConnectorOAuthConfiguration: Sendable {
    public let authorizationEndpoint: URL?
    public let tokenEndpoint: URL
    public let redirectURI: URL?
    public let scopes: [String]
    public let refreshLeeway: TimeInterval

    public init(
        authorizationEndpoint: URL? = nil,
        tokenEndpoint: URL,
        redirectURI: URL? = nil,
        scopes: [String],
        refreshLeeway: TimeInterval = 300
    ) {
        self.authorizationEndpoint = authorizationEndpoint
        self.tokenEndpoint = tokenEndpoint
        self.redirectURI = redirectURI
        self.scopes = scopes
        self.refreshLeeway = refreshLeeway
    }
}

public protocol ConnectorTokenProvider: Sendable {
    func accessToken(for config: ConnectorConfig) async throws -> ConnectorAccessToken
}

public struct ConnectorConfig: Sendable {
    public let type: ConnectorType
    public let tenantId: String
    public let clientId: String
    public let clientSecret: String?
    public let scopes: [String]
    public let apiEndpoint: URL
    public let accessToken: ConnectorAccessToken?
    public let tokenProvider: (any ConnectorTokenProvider)?
    public let tokenAccount: String?
    public let oauthConfiguration: ConnectorOAuthConfiguration?

    public init(
        type: ConnectorType,
        tenantId: String,
        clientId: String,
        clientSecret: String?,
        scopes: [String],
        apiEndpoint: URL,
        accessToken: ConnectorAccessToken? = nil,
        tokenProvider: (any ConnectorTokenProvider)? = nil,
        tokenAccount: String? = nil,
        oauthConfiguration: ConnectorOAuthConfiguration? = nil
    ) {
        self.type = type
        self.tenantId = tenantId
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.scopes = scopes
        self.apiEndpoint = apiEndpoint
        self.accessToken = accessToken
        self.tokenProvider = tokenProvider
        self.tokenAccount = tokenAccount
        self.oauthConfiguration = oauthConfiguration
    }
}

public struct ConnectorIdentity: Codable, Sendable {
    public let connectorType: ConnectorType
    public let version: String
    public let clientId: String
    public let tenantId: String
    public let userId: String
    public let grantedScopes: [String]

    public init(connectorType: ConnectorType, version: String, clientId: String, tenantId: String, userId: String, grantedScopes: [String]) {
        self.connectorType = connectorType
        self.version = version
        self.clientId = clientId
        self.tenantId = tenantId
        self.userId = userId
        self.grantedScopes = grantedScopes
    }
}

public struct PermissionScope: Codable, Sendable {
    public let connectedSources: [String] // e.g. ["Mailbox: user@example.com", "Drive: /Projects"]
    public let inclusions: [String]
    public let exclusions: [String]

    public init(connectedSources: [String], inclusions: [String], exclusions: [String]) {
        self.connectedSources = connectedSources
        self.inclusions = inclusions
        self.exclusions = exclusions
    }
}

public struct PolicyPosture: Codable, Sendable {
    public let isLocalOnly: Bool
    public let isNetworkAllowed: Bool
    public let retentionPolicy: String // e.g. "30days", "forever", "legal-hold"
    public let allowDerivedArtifacts: Bool

    public init(isLocalOnly: Bool, isNetworkAllowed: Bool, retentionPolicy: String, allowDerivedArtifacts: Bool) {
        self.isLocalOnly = isLocalOnly
        self.isNetworkAllowed = isNetworkAllowed
        self.retentionPolicy = retentionPolicy
        self.allowDerivedArtifacts = allowDerivedArtifacts
    }
}

public protocol ConnectorProtocol: Sendable {
    // Governance
    var identity: ConnectorIdentity { get async }
    var permissionScope: PermissionScope { get async }
    var policyPosture: PolicyPosture { get async }

    // Lifecycle
    func connect() async throws

    // Sync
    func sync(track: SyncTrackSnapshot) async throws

    // Write-back
    func execute(intent: any GovernanceIntent) async throws -> Data

    // Inventory & Artifacts (The "Contract")
    func sourceInventory() async throws -> [ExternalRef]
    // Note: Artifacts are produced via sync/jobs, not pulled directly usually, but we can expose a listing
}
