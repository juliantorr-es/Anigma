import Foundation

public enum DataClassification: String, Codable {
    case publicData = "public"
    case internalUse = "internal"
    case confidential = "confidential"
    case restricted = "restricted"
}

public struct ConnectorPolicy: Codable {
    public let allowedConnectors: Set<String>
    public let allowedScopes: [String: Set<String>] // ConnectorID -> Scopes
    public let writeBackRequiresApproval: Bool
    public let maxDataClassification: DataClassification

    public init(allowedConnectors: Set<String>, allowedScopes: [String: Set<String>], writeBackRequiresApproval: Bool, maxDataClassification: DataClassification) {
        self.allowedConnectors = allowedConnectors
        self.allowedScopes = allowedScopes
        self.writeBackRequiresApproval = writeBackRequiresApproval
        self.maxDataClassification = maxDataClassification
    }
}

public class PolicyEngine {
    private var policies: [String: ConnectorPolicy] = [:] // TenantID -> Policy

    public init() {}

    public func setPolicy(_ policy: ConnectorPolicy, forTenant tenantId: String) {
        policies[tenantId] = policy
    }

    public func isConnectorAllowed(connectorId: String, forTenant tenantId: String) -> Bool {
        guard let policy = policies[tenantId] else { return false } // Default deny
        return policy.allowedConnectors.contains(connectorId)
    }

    public func areScopesAllowed(scopes: Set<String>, forConnector connectorId: String, tenantId: String) -> Bool {
        guard let policy = policies[tenantId] else { return false }
        guard let allowed = policy.allowedScopes[connectorId] else { return false }
        return scopes.isSubset(of: allowed)
    }

    public func canWriteBack(tenantId: String, classification: DataClassification) -> Bool {
        guard let policy = policies[tenantId] else { return false }
        // Simple hierarchy check
        let hierarchy: [DataClassification: Int] = [
            .publicData: 0,
            .internalUse: 1,
            .confidential: 2,
            .restricted: 3
        ]

        let policyLevel = hierarchy[policy.maxDataClassification] ?? 0
        let dataLevel = hierarchy[classification] ?? 3

        return dataLevel <= policyLevel
    }

    public func requiresApproval(tenantId: String) -> Bool {
        return policies[tenantId]?.writeBackRequiresApproval ?? true
    }
}
