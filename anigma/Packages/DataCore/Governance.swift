import Foundation

public enum RetentionPolicy: String, Codable, Sendable {
    case keepRaw
    case keepDerivedOnly
    case hashOnly
    case exclude
}

public struct DataGovernancePolicy: Codable, Sendable {
    public let retention: RetentionPolicy
    public let allowExternalTools: Bool
    public let requireApprovalForTransforms: Bool
    public let allowExports: Bool

    public init(retention: RetentionPolicy, allowExternalTools: Bool, requireApprovalForTransforms: Bool, allowExports: Bool) {
        self.retention = retention
        self.allowExternalTools = allowExternalTools
        self.requireApprovalForTransforms = requireApprovalForTransforms
        self.allowExports = allowExports
    }

    public static let strict = DataGovernancePolicy(
        retention: .hashOnly,
        allowExternalTools: false,
        requireApprovalForTransforms: true,
        allowExports: false
    )

    public static let standard = DataGovernancePolicy(
        retention: .keepDerivedOnly,
        allowExternalTools: true,
        requireApprovalForTransforms: true,
        allowExports: true
    )

    public static let open = DataGovernancePolicy(
        retention: .keepRaw,
        allowExternalTools: true,
        requireApprovalForTransforms: false,
        allowExports: true
    )
}

public struct GovernanceCheckResult: Sendable {
    public let allowed: Bool
    public let reason: String?
    public let requiredApproval: Bool
}
