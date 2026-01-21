//
//  CapabilityRegistry.swift
//  CapabilityCore
//
//  Central registry for capability providers with governance integration.
//
//  This actor provides:
//  - ID-based capability resolution (original API)
//  - Type-based capability resolution (type-safe API)
//  - Governance hooks for permission checks
//  - Audit logging for all resolutions
//  - Provider introspection and management
//
//  Thread Safety:
//  - Implemented as an actor for safe concurrent access
//  - All mutations are serialized through actor isolation
//
//  Usage:
//  ```swift
//  let registry = CapabilityRegistry.shared
//  await registry.register(provider: myProvider)
//  let capability = await registry.resolve(capabilityId: "...", as: MyCapability.self)
//  ```
//

import Foundation

/// A registry that manages capability providers and allows resolving capabilities.
/// Supports both ID-based and type-based resolution with optional governance integration.
public actor CapabilityRegistry {
    public static let shared = CapabilityRegistry()

    private var providers: [String: [CapabilityProvider]] = [:]
    private var typeProviders: [ObjectIdentifier: Any] = [:]

    private init() {}

    // MARK: - ID-Based Registration (Original API)

    /// Registers a provider with the registry using capability IDs.
    public func register(provider: CapabilityProvider) {
        for capabilityId in provider.supportedCapabilities {
            var current = providers[capabilityId] ?? []
            current.append(provider)
            providers[capabilityId] = current
        }
    }

    /// Resolves a capability by ID.
    /// - Parameters:
    ///   - capabilityId: The ID of the capability to resolve.
    ///   - type: The protocol type to cast to.
    /// - Returns: An instance of the capability, or nil if no provider is found or cast fails.
    public func resolve<T>(capabilityId: String, as type: T.Type = T.self) -> T? {
        guard let providerList = providers[capabilityId] else { return nil }

        for provider in providerList {
            if let capability = provider as? T {
                return capability
            }
        }

        return nil
    }

    /// Resolves all providers for a specific capability ID.
    public func resolveAll<T>(capabilityId: String, as type: T.Type = T.self) -> [T] {
        guard let providerList = providers[capabilityId] else { return [] }

        return providerList.compactMap { $0 as? T }
    }

    // MARK: - Type-Based Registration (New API from AnigmaCapabilities)

    /// Registers a provider by type.
    /// - Parameters:
    ///   - provider: The provider instance.
    ///   - type: The type to register under.
    public func register<T>(_ provider: T, for type: T.Type) {
        let id = ObjectIdentifier(type)
        typeProviders[id] = provider
    }

    /// Resolves a provider by type.
    /// - Parameter type: The type to resolve.
    /// - Returns: The provider instance, or nil if not found.
    public func provider<T>(for type: T.Type) -> T? {
        let id = ObjectIdentifier(type)
        return typeProviders[id] as? T
    }

    // MARK: - Governance Integration (Protocol-Based)

    /// Protocol for governance decision making.
    public protocol CapabilityGovernance: Sendable {
        func canResolve(capabilityId: String, principal: String, context: [String: String]) async
            -> (allowed: Bool, reason: String?)
    }

    /// Protocol for audit logging.
    public protocol CapabilityAuditLog: Sendable {
        func logResolution(
            capabilityId: String, principal: String, success: Bool, metadata: [String: String])
            async
    }

    /// Resolves a capability with governance and audit logging.
    /// - Parameters:
    ///   - capabilityId: The ID of the capability to resolve.
    ///   - type: The protocol type to cast to.
    ///   - principal: The principal requesting the capability.
    ///   - governance: Optional governance for permission checks.
    ///   - auditLog: Optional audit log for recording resolution attempts.
    /// - Returns: An instance of the capability, or nil if denied or not found.
    public func resolveWithGovernance<T>(
        capabilityId: String,
        as type: T.Type = T.self,
        principal: String,
        governance: CapabilityGovernance? = nil,
        auditLog: CapabilityAuditLog? = nil
    ) async -> T? {
        // Governance check
        if let governance {
            let decision = await governance.canResolve(
                capabilityId: capabilityId,
                principal: principal,
                context: ["type": String(describing: type)]
            )

            guard decision.allowed else {
                await auditLog?.logResolution(
                    capabilityId: capabilityId,
                    principal: principal,
                    success: false,
                    metadata: [
                        "reason": decision.reason ?? "denied", "type": String(describing: type)
                    ]
                )
                return nil
            }
        }

        // Resolve
        let capability = resolve(capabilityId: capabilityId, as: type)

        // Audit
        await auditLog?.logResolution(
            capabilityId: capabilityId,
            principal: principal,
            success: capability != nil,
            metadata: ["type": String(describing: type)]
        )

        return capability
    }

    // MARK: - Introspection

    /// Returns all registered capability IDs.
    public func registeredCapabilityIds() -> [String] {
        return Array(providers.keys).sorted()
    }

    /// Returns the number of providers for a given capability ID.
    public func providerCount(for capabilityId: String) -> Int {
        return providers[capabilityId]?.count ?? 0
    }
}
