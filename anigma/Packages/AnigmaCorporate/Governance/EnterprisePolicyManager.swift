//
//  EnterprisePolicyManager.swift
//  AnigmaCorporate
//
//  Enforces policies defined by Managed App Configuration.
//

import Foundation
import AnigmaSystemSpine

public struct EnterprisePolicy: Sendable {
    public let allowExternalTools: Bool
    public let forceLocalOnly: Bool
    public let retentionDays: Int?
    public let allowedConnectors: [String]? // nil means all
    public let requireBiometrics: Bool

    public static let defaults = EnterprisePolicy(
        allowExternalTools: true,
        forceLocalOnly: false,
        retentionDays: nil,
        allowedConnectors: nil,
        requireBiometrics: false
    )
}

public actor EnterprisePolicyManager {
    private let configReader: ManagedConfigurationReader

    public init(configReader: ManagedConfigurationReader = .shared) {
        self.configReader = configReader
    }

    public func currentPolicy() async -> EnterprisePolicy {
        let allowExternal: Bool? = await configReader.getValue(forKey: "allowExternalTools")
        let forceLocal: Bool? = await configReader.getValue(forKey: "forceLocalOnly")
        let retention: Int? = await configReader.getValue(forKey: "retentionDays")
        let connectors: [String]? = await configReader.getValue(forKey: "allowedConnectors")
        let biometrics: Bool? = await configReader.getValue(forKey: "requireBiometrics")

        return EnterprisePolicy(
            allowExternalTools: allowExternal ?? true,
            forceLocalOnly: forceLocal ?? false,
            retentionDays: retention,
            allowedConnectors: connectors,
            requireBiometrics: biometrics ?? false
        )
    }
}
