//
//  UIContracts.swift
//  ContractsCore
//
//  Contract definition for UIContracts in ContractsCore.
//

import AnigmaPrimitives
import Foundation

// MARK: - Identity Types

/// Unique identifier for a renderer surface (e.g., a window or webview).
/// Minted by the authority plane and bound to capability sets.
public struct SurfaceId: Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String

    public var description: String { rawValue }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static func generate() -> SurfaceId {
        SurfaceId(rawValue: UUID().uuidString.lowercased())
    }
}

/// Unique identifier for an actor (user or system principal).
public struct ActorId: Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String

    public var description: String { rawValue }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

// MARK: - Truth Objects

/// Presentation Intermediate Representation (IR).
/// The "Portable Truth Boundary" that describes the UI state without domain logic.
public struct PresentationIR: Sendable, Codable {
    /// Stable version of the IR schema.
    public let version: String

    /// Unique identifier for this specific version of the IR.
    /// Used for "Snapshot Pinning" in intents.
    /// Note: In Phase 8.1, this is authority-minted. The init value is a placeholder or suggestion.
    public let snapshotId: String

    /// Root node of the view tree.
    public let root: ViewNode

    /// Global state atoms bound to the UI.
    public let bindings: [BindingId: BindingValue]

    public init(
        version: String = "1.0.0",
        snapshotId: String? = nil,
        root: ViewNode,
        bindings: [BindingId: BindingValue] = [:]
    ) {
        self.version = version
        self.snapshotId = snapshotId ?? UUID().uuidString.lowercased()
        self.root = root
        self.bindings = bindings
    }

    // MARK: - Codable Implementation

    enum CodingKeys: String, CodingKey {
        case version, snapshotId, root, bindings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: .version)
        snapshotId = try container.decode(String.self, forKey: .snapshotId)
        root = try container.decode(ViewNode.self, forKey: .root)

        let rawBindings = try container.decode([String: BindingValue].self, forKey: .bindings)
        var newBindings: [BindingId: BindingValue] = [:]
        for (key, value) in rawBindings {
            newBindings[BindingId(rawValue: key)] = value
        }
        self.bindings = newBindings
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(snapshotId, forKey: .snapshotId)
        try container.encode(root, forKey: .root)

        // Convert to [String: BindingValue] to ensure JSON Object representation.
        // This allows .sortedKeys to work deterministically.
        var rawBindings: [String: BindingValue] = [:]
        for (key, value) in bindings {
            rawBindings[key.rawValue] = value
        }
        try container.encode(rawBindings, forKey: .bindings)
    }
}

/// A node in the Presentation IR view tree.
public struct ViewNode: Sendable, Codable {
    public var id: String
    public var type: String  // e.g., "Stack", "Button", "Text"
    public var properties: [String: BindingValue]
    public var children: [ViewNode]

    /// Action references reachable from this node.
    public var actions: [ActionRef]

    public init(
        id: String,
        type: String,
        properties: [String: BindingValue] = [:],
        children: [ViewNode] = [],
        actions: [ActionRef] = []
    ) {
        self.id = id
        self.type = type
        self.properties = properties
        self.children = children
        self.actions = actions
    }
}

/// Opaque, stable reference to an action reachable from the UI.
public struct ActionRef: Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String

    /// The action family this ref belongs to (e.g., "core", "fs", "ai").
    /// Used for capability gating.
    public let family: String

    public var description: String { "\(family):\(rawValue)" }

    public init(rawValue: String, family: String) {
        self.rawValue = rawValue
        self.family = family
    }
}

/// Identifier for a UI binding atom.
public struct BindingId: Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String

    public var description: String { rawValue }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

/// Value of a binding atom, supporting basic serializable types.
public enum BindingValue: Sendable, Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([BindingValue])
    case object([String: BindingValue])
}

/// A user intent emitted by a renderer.
public struct ActionIntent: Sendable, Codable {
    public struct Header: Sendable, Codable {
        public let surfaceId: SurfaceId
        public let actorId: ActorId
        public let capabilityToken: String
        public let irSnapshotId: String  // Pinning to a specific IR version
        public let timestamp: Int64  // ms since epoch for canonical stability
        public let nonce: String

        public init(
            surfaceId: SurfaceId,
            actorId: ActorId,
            capabilityToken: String,
            irSnapshotId: String,
            timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
            nonce: String = UUID().uuidString
        ) {
            self.surfaceId = surfaceId
            self.actorId = actorId
            self.capabilityToken = capabilityToken
            self.irSnapshotId = irSnapshotId
            self.timestamp = timestamp
            self.nonce = nonce
        }
    }

    public let header: Header
    public let action: ActionRef
    public let parameters: [String: BindingValue]

    public init(header: Header, action: ActionRef, parameters: [String: BindingValue] = [:]) {
        self.header = header
        self.action = action
        self.parameters = parameters
    }
}

/// A reference to a receipt, the immutable source of truth for an intent's outcome.
public struct ReceiptRef: Hashable, Sendable, Codable {
    public let id: String
    public let intentHash: String
    public let timestamp: Int64

    public init(
        id: String, intentHash: String,
        timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.id = id
        self.intentHash = intentHash
        self.timestamp = timestamp
    }
}

/// A structured seal proving the authenticity of a receipt.
public enum ReceiptSeal: Sendable, Codable {
    case unsigned(hash: String)  // For lightweight/local receipts
    case signed(signature: String, keyId: String)  // For governed receipts
}

/// The immutable source of truth for an intent's outcome.
public struct Receipt: Sendable, Codable {
    public enum Status: String, Sendable, Codable {
        case success = "SUCCESS"
        case failure = "FAILURE"
        case blocked = "BLOCKED"
    }

    public let ref: ReceiptRef
    public let status: Status
    public let outcome: BindingValue
    public let seal: ReceiptSeal
    public let ledgerLink: String?  // URI to permanent governance record
    public let previousReceiptHash: String?

    public init(
        ref: ReceiptRef,
        status: Status,
        outcome: BindingValue,
        seal: ReceiptSeal,
        ledgerLink: String? = nil,
        previousReceiptHash: String? = nil
    ) {
        self.ref = ref
        self.status = status
        self.outcome = outcome
        self.seal = seal
        self.ledgerLink = ledgerLink
        self.previousReceiptHash = previousReceiptHash
    }
}

// MARK: - Enforcement Objects

/// A token representing a set of granted capabilities for a specific surface.
public struct CapabilityToken: Sendable, Codable {
    public let id: String
    public let surfaceId: SurfaceId
    public let actorId: ActorId
    public let allowedActionFamilies: [String]
    public let scopes: [Scope]
    public let expiresAt: Date

    public init(
        id: String = UUID().uuidString,
        surfaceId: SurfaceId,
        actorId: ActorId,
        allowedActionFamilies: [String],
        scopes: [Scope],
        expiresAt: Date
    ) {
        self.id = id
        self.surfaceId = surfaceId
        self.actorId = actorId
        self.allowedActionFamilies = allowedActionFamilies
        self.scopes = scopes
        self.expiresAt = expiresAt
    }
}

/// A scope that constrains a capability.
public struct Scope: Sendable, Codable {
    public enum Effect: String, Sendable, Codable {
        case allow
        case deny
    }

    public let resource: String  // e.g., "fs:/Users/user/Docs"
    public let action: String  // e.g., "read"
    public let effect: Effect

    public init(resource: String, action: String, effect: Effect) {
        self.resource = resource
        self.action = action
        self.effect = effect
    }
}

// MARK: - Enforcement Logic

extension PresentationIR {
    /// Checks if a specific ActionRef is reachable within this IR stated tree.
    /// This is the authority-plane "Deterministic Reachability" check.
    public func isReachable(_ action: ActionRef) -> Bool {
        return searchNode(root, for: action)
    }

    private func searchNode(_ node: ViewNode, for action: ActionRef) -> Bool {
        if node.actions.contains(action) {
            return true
        }
        for child in node.children {
            if searchNode(child, for: action) {
                return true
            }
        }
        return false
    }
}

extension CapabilityToken {
    /// Resolves whether a specific action on a resource is allowed given the scopes.
    /// Implements "Deny overrides Allow".
    public func checkScope(resource: String, action: String) -> Scope.Effect {
        var hasAllow = false

        for scope in scopes {
            let resourceMatch = isResourceMatch(target: resource, pattern: scope.resource)
            let actionMatch = (action == scope.action || scope.action == "*")

            if resourceMatch && actionMatch {
                if scope.effect == .deny {
                    return .deny  // Intermediate deny always wins
                }
                if scope.effect == .allow {
                    hasAllow = true
                }
            }
        }

        return hasAllow ? .allow : .deny
    }

    /// Implement segment-aware matching (URI-like).
    /// e.g. "fs:/a" matches "fs:/a/b" but not "fs:/ab"
    private func isResourceMatch(target: String, pattern: String) -> Bool {
        if pattern == "*" { return true }
        if target == pattern { return true }
        if target.hasPrefix(pattern.hasSuffix("/") ? pattern : pattern + "/") {
            return true
        }
        return false
    }

    /// Checks if the token is currently valid.
    public func isValid(at date: Date = Date()) -> Bool {
        return expiresAt > date
    }
}

// MARK: - Denial Rules

/// Deterministic denial codes for UI consistency.
public enum DenialCode: String, Sendable, Codable, Error {
    case schemaUnreachable = "SCHEMA_UNREACHABLE"
    case capabilityDenied = "CAPABILITY_DENIED"
    case scopeViolation = "SCOPE_VIOLATION"
    case transportFailed = "TRANSPORT_FAILED"
    case expiredToken = "EXPIRED_TOKEN"
    case invalidNonce = "INVALID_NONCE"
    case staleSnapshot = "STALE_SNAPSHOT"
    case resourceExhausted = "RESOURCE_EXHAUSTED"
    case invalidParameters = "INVALID_PARAMETERS"
}

/// The result of an authority-side evaluation of a user intent.
public enum IntentEvaluation: Sendable, Codable, Equatable {
    /// The action is permitted and can be submitted.
    case allowed
    /// The action is denied.
    case denied(reason: String)
    /// The action requires explicit user confirmation.
    case needsConfirmation(prompt: String)
}

// MARK: - Canonical Serialization

extension ActionIntent {
    /// Canonical JSON encoder for intents.
    public static var canonicalEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        // No date strategy needed if using Int64 for timestamp
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    public func encode() throws -> Data {
        try Self.canonicalEncoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> ActionIntent {
        let decoder = JSONDecoder()
        return try decoder.decode(ActionIntent.self, from: data)
    }
}

extension PresentationIR {
    public func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    /// Encodes the IR content with a normalized (empty) snapshotId.
    /// Used for "Proof of Content" hashing.
    public func contentOnlyEncode() throws -> Data {
        // Create a copy with empty snapshotId for stable content hashing
        // This ensures the hash depends only on the view tree and bindings
        let contentOnly = PresentationIR(
            version: self.version,
            snapshotId: "",  // Explicitly empty/ignored
            root: self.root,
            bindings: self.bindings
        )
        return try contentOnly.encode()
    }

    public static func decode(_ data: Data) throws -> PresentationIR {
        let decoder = JSONDecoder()
        return try decoder.decode(PresentationIR.self, from: data)
    }
}
