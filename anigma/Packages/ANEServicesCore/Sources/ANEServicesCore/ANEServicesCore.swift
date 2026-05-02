import Foundation

public enum ANEComputeUnit: String, Codable, Sendable, CaseIterable {
    case cpu
    case gpu
    case neuralEngine
    case all
}

public enum ANEExecutionPriority: String, Codable, Sendable {
    case realtime
    case interactive
    case background
}

public enum ANEGateStatus: String, Codable, Sendable {
    case open
    case gated
    case deprecated
    case experimental
}

public struct ANEGateInfo: Sendable, Codable, Hashable {
    public let status: ANEGateStatus
    public let reason: String?
    public let approvedBy: String?
    public let expiresAt: Date?

    public init(
        status: ANEGateStatus,
        reason: String? = nil,
        approvedBy: String? = nil,
        expiresAt: Date? = nil
    ) {
        self.status = status
        self.reason = reason
        self.approvedBy = approvedBy
        self.expiresAt = expiresAt
    }
}

public struct ANECapsuleDescriptor: Sendable, Codable, Hashable {
    public let id: String
    public let displayName: String
    public let version: String
    public let gate: ANEGateInfo
    public let supportedComputeUnits: Set<ANEComputeUnit>
    public let defaultComputeUnit: ANEComputeUnit
    public let tags: [String]

    public init(
        id: String,
        displayName: String,
        version: String,
        gate: ANEGateInfo,
        supportedComputeUnits: Set<ANEComputeUnit> = [.all],
        defaultComputeUnit: ANEComputeUnit = .all,
        tags: [String] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.version = version
        self.gate = gate
        self.supportedComputeUnits = supportedComputeUnits
        self.defaultComputeUnit = defaultComputeUnit
        self.tags = tags
    }
}

public struct ANERuntimeProfile: Sendable, Codable, Hashable {
    public let computeUnit: ANEComputeUnit
    public let allowFallback: Bool
    public let priority: ANEExecutionPriority
    public let maxInFlight: Int

    public init(
        computeUnit: ANEComputeUnit = .all,
        allowFallback: Bool = true,
        priority: ANEExecutionPriority = .interactive,
        maxInFlight: Int = 1
    ) {
        self.computeUnit = computeUnit
        self.allowFallback = allowFallback
        self.priority = priority
        self.maxInFlight = maxInFlight
    }
}

public protocol ANECapsule: Sendable {
    static var descriptor: ANECapsuleDescriptor { get }
    init()
}

public protocol ANECapsuleRunner: Sendable {
    associatedtype Input: Sendable
    associatedtype Output: Sendable

    func execute(_ input: Input, profile: ANERuntimeProfile) async throws -> Output
}

public enum ANEServiceError: Error, Sendable {
    case gated(String)
    case unsupportedComputeUnit
    case executionFailed(String)
}

public actor ANEServiceRegistry {
    private var descriptors: [String: ANECapsuleDescriptor] = [:]

    public init() {}

    public func register(_ descriptor: ANECapsuleDescriptor) {
        descriptors[descriptor.id] = descriptor
    }

    public func descriptor(for id: String) -> ANECapsuleDescriptor? {
        descriptors[id]
    }

    public func allDescriptors() -> [ANECapsuleDescriptor] {
        Array(descriptors.values).sorted { $0.displayName < $1.displayName }
    }

    public func gatedDescriptors() -> [ANECapsuleDescriptor] {
        descriptors.values.filter { $0.gate.status == .gated }
    }
}
