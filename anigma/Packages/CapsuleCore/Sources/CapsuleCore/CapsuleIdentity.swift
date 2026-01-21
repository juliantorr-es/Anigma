import Foundation
import AnigmaNativeShims

/// Represents a capsule's identity for auditability and versioning.
public struct CapsuleIdentity {
    public let capsuleId: String
    public let buildHash: String
    public let algoVersion: String
    public let determinismTier: DeterminismTier
    
    public enum DeterminismTier: UInt32 {
        case receiptGrade = 1
        case canonicalBoundary = 2
        
        public var description: String {
            switch self {
            case .receiptGrade:
                return "Tier 1 (Receipt-grade determinism)"
            case .canonicalBoundary:
                return "Tier 2 (Canonical boundary determinism)"
            }
        }
    }
    
    /// Create from C identity structure.
    public init(_ cIdentity: anigma_capsule_identity_t) {
        self.capsuleId = String(cString: cIdentity.capsule_id)
        self.buildHash = String(cString: cIdentity.build_hash)
        self.algoVersion = String(cString: cIdentity.algo_version)
        self.determinismTier = DeterminismTier(rawValue: cIdentity.determinism_tier) ?? .canonicalBoundary
    }
    
    /// Create with explicit values.
    public init(
        capsuleId: String,
        buildHash: String,
        algoVersion: String,
        determinismTier: DeterminismTier
    ) {
        self.capsuleId = capsuleId
        self.buildHash = buildHash
        self.algoVersion = algoVersion
        self.determinismTier = determinismTier
    }
    

    
    /// Execute a closure with C strings that are valid for the duration of the call.
    public func withCStrings<T>(_ body: (anigma_capsule_identity_t) throws -> T) rethrows -> T {
        try capsuleId.withCString { capsuleIdPtr in
            try buildHash.withCString { buildHashPtr in
                try algoVersion.withCString { algoVersionPtr in
                    let cIdentity = anigma_capsule_identity_t(
                        capsule_id: capsuleIdPtr,
                        build_hash: buildHashPtr,
                        algo_version: algoVersionPtr,
                        determinism_tier: determinismTier.rawValue
                    )
                    return try body(cIdentity)
                }
            }
        }
    }
}

/// Protocol for capsules that provide identity information.
public protocol IdentifiableCapsule {
    static var identity: CapsuleIdentity { get }
}

/// Extension to get identity from C function.
extension IdentifiableCapsule {
    /// Default implementation that calls `anigma_capsule_get_identity`.
    public static var identity: CapsuleIdentity {
        let cIdentity = anigma_capsule_get_identity()
        return CapsuleIdentity(cIdentity)
    }
}

/// Utility for generating build hashes.
public enum BuildHash {
    /// Generate a deterministic hash from source file contents.
    /// This is a placeholder implementation; real implementation would hash the compiled binary.
    public static func generate(fromSourcePaths paths: [String] = []) -> String {
        // In a real implementation, this would hash the compiled capsule binary
        // or use git commit hash for development builds.
        let timestamp = Int(Date().timeIntervalSince1970)
        let random = Int.random(in: 0...Int.max)
        return "dev_\(timestamp)_\(random)"
    }
    
    /// Generate a hash from a version string and compilation timestamp.
    public static func generate(version: String, timestamp: Date = Date()) -> String {
        let formatter = ISO8601DateFormatter()
        let timestampStr = formatter.string(from: timestamp)
        let combined = "\(version)_\(timestampStr)"
        // Simple hash for demonstration
        let hash = combined.utf8.reduce(0) { ($0 << 5) &- $0 &+ Int($1) }
        return String(format: "%08x", hash)
    }
}