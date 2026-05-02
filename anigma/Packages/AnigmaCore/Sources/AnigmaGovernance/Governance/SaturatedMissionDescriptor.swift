import AnigmaPrimitives
import Foundation
import CryptoKit

public enum SaturatedMissionDescriptorError: Error, Equatable, Sendable {
    case unsupportedHashPolicyVersion(UInt16)
    case atlasRangeCountOverflow(Int)
    case descriptorHashPolicyMismatch(expected: SaturatedMissionDescriptorHashPolicy, provided: SaturatedMissionDescriptorHashPolicy)
    case invalidEncoding
}

public enum SaturatedMissionSignatureAlgorithm: UInt16, Sendable, Codable {
    case ed25519 = 1
}

public enum SaturatedMissionDescriptorHashPolicy: UInt16, Sendable, Codable {
    /// Tier-1 descriptor hash policy for descriptor header version 1.
    case sha256Tier1V1 = 1
    /// Reserved policy identifier for a future BLAKE3-based descriptor signature policy.
    case blake3Tier1V2 = 2

    public static func policy(forDescriptorVersion version: UInt16) throws -> SaturatedMissionDescriptorHashPolicy {
        switch version {
        case 1, 2:
            return .blake3Tier1V2
        default:
            throw SaturatedMissionDescriptorError.unsupportedHashPolicyVersion(version)
        }
    }

    fileprivate func digest(_ data: Data) throws -> Data {
        switch self {
        case .sha256Tier1V1:
            return Data(SHA256.hash(data: data))
        case .blake3Tier1V2:
            return Data(BLAKE3Digest.digest(data))
        }
    }
}

public struct SaturatedMissionDescriptorHeader: Sendable, Equatable, Codable {
    public static let magic = "ANMS"
    public static let encodedLength = 32

    public let version: UInt16
    public let algorithm: SaturatedMissionSignatureAlgorithm
    public let issuedAtUnixMilliseconds: UInt64
    public let expiresAtUnixMilliseconds: UInt64
    public let reserved: UInt64

    public init(
        version: UInt16 = 1,
        algorithm: SaturatedMissionSignatureAlgorithm = .ed25519,
        issuedAtUnixMilliseconds: UInt64,
        expiresAtUnixMilliseconds: UInt64,
        reserved: UInt64 = 0
    ) {
        self.version = version
        self.algorithm = algorithm
        self.issuedAtUnixMilliseconds = issuedAtUnixMilliseconds
        self.expiresAtUnixMilliseconds = expiresAtUnixMilliseconds
        self.reserved = reserved
    }
}

public struct SaturatedMissionDescriptorIdentityContext: Sendable, Equatable, Codable {
    public static let encodedLength = 64

    public let missionID: UUID
    public let correlationID: UUID
    public let principalID: String
    public let projectID: String

    public init(
        missionID: UUID,
        correlationID: UUID,
        principalID: String,
        projectID: String
    ) {
        self.missionID = missionID
        self.correlationID = correlationID
        self.principalID = principalID
        self.projectID = projectID
    }
}

public struct SaturatedMissionDescriptorResourceBoundaries: Sendable, Equatable, Codable {
    public static let encodedLength = 64
    private static let reservedLength = 24

    public let timeBudgetMilliseconds: UInt64
    public let tokenBudget: UInt64
    public let capabilityBits: UInt32
    public let thermalLimit: UInt32
    public let energyBudgetJoules: UInt64
    public let maxPowerWatts: Float
    public let reserved: [UInt8]

    public init(
        timeBudgetMilliseconds: UInt64,
        tokenBudget: UInt64,
        capabilityBits: UInt32,
        thermalLimit: UInt32,
        energyBudgetJoules: UInt64 = 0,
        maxPowerWatts: Float = 0.0,
        reserved: [UInt8] = []
    ) {
        self.timeBudgetMilliseconds = timeBudgetMilliseconds
        self.tokenBudget = tokenBudget
        self.capabilityBits = capabilityBits
        self.thermalLimit = thermalLimit
        self.energyBudgetJoules = energyBudgetJoules
        self.maxPowerWatts = maxPowerWatts
        self.reserved = SaturatedMissionDescriptorResourceBoundaries.normalizeReserved(reserved)
    }

    private static func normalizeReserved(_ bytes: [UInt8]) -> [UInt8] {
        let trimmed = Array(bytes.prefix(reservedLength))
        guard trimmed.count < reservedLength else { return trimmed }
        return trimmed + Array(repeating: 0, count: reservedLength - trimmed.count)
    }
}

public struct SaturatedMemoryAtlasRange: Sendable, Equatable, Codable {
    public static let encodedLength = 24

    public let atlasID: UInt64
    public let offset: UInt64
    public let length: UInt64

    public init(atlasID: UInt64, offset: UInt64, length: UInt64) {
        self.atlasID = atlasID
        self.offset = offset
        self.length = length
    }
}

public struct SaturatedMissionDescriptor: Sendable, Equatable, Codable {
    public let header: SaturatedMissionDescriptorHeader
    public let identityContext: SaturatedMissionDescriptorIdentityContext
    public let resourceBoundaries: SaturatedMissionDescriptorResourceBoundaries
    public let atlasRanges: [SaturatedMemoryAtlasRange]

    public init(
        header: SaturatedMissionDescriptorHeader,
        identityContext: SaturatedMissionDescriptorIdentityContext,
        resourceBoundaries: SaturatedMissionDescriptorResourceBoundaries,
        atlasRanges: [SaturatedMemoryAtlasRange]
    ) {
        self.header = header
        self.identityContext = identityContext
        self.resourceBoundaries = resourceBoundaries
        self.atlasRanges = atlasRanges
    }

    public static let `default` = SaturatedMissionDescriptor(
        header: SaturatedMissionDescriptorHeader(
            issuedAtUnixMilliseconds: 1_700_000_000_000,
            expiresAtUnixMilliseconds: 1_700_000_360_000
        ),
        identityContext: SaturatedMissionDescriptorIdentityContext(
            missionID: UUID(uuidString: "00112233-4455-6677-8899-aabbccddeeff") ?? UUID(),
            correlationID: UUID(uuidString: "ffeeddcc-bbaa-9988-7766-554433221100") ?? UUID(),
            principalID: "default-principal",
            projectID: "default-project"
        ),
        resourceBoundaries: SaturatedMissionDescriptorResourceBoundaries(
            timeBudgetMilliseconds: 60_000,
            tokenBudget: 16_384,
            capabilityBits: 0,
            thermalLimit: 72,
            energyBudgetJoules: 250,
            maxPowerWatts: 35.0
        ),
        atlasRanges: []
    )

    public func canonicalBinaryEncoding() throws -> Data {
        guard atlasRanges.count <= Int(UInt32.max) else {
            throw SaturatedMissionDescriptorError.atlasRangeCountOverflow(atlasRanges.count)
        }

        let size =
            SaturatedMissionDescriptorHeader.encodedLength +
            SaturatedMissionDescriptorIdentityContext.encodedLength +
            SaturatedMissionDescriptorResourceBoundaries.encodedLength +
            (atlasRanges.count * SaturatedMemoryAtlasRange.encodedLength)
        var data = Data(capacity: size)

        data.append(contentsOf: SaturatedMissionDescriptorHeader.magic.utf8)
        data.appendLittleEndian(header.version)
        data.appendLittleEndian(header.algorithm.rawValue)
        data.appendLittleEndian(header.issuedAtUnixMilliseconds)
        data.appendLittleEndian(header.expiresAtUnixMilliseconds)
        data.appendLittleEndian(header.reserved)

        data.append(uuidBytes(identityContext.missionID))
        data.append(uuidBytes(identityContext.correlationID))
        data.append(identityContext.principalID.fixedWidthUTF8(length: 16))
        data.append(identityContext.projectID.fixedWidthUTF8(length: 16))

        data.appendLittleEndian(resourceBoundaries.timeBudgetMilliseconds)
        data.appendLittleEndian(resourceBoundaries.tokenBudget)
        data.appendLittleEndian(UInt32(atlasRanges.count))
        data.appendLittleEndian(resourceBoundaries.capabilityBits)
        data.appendLittleEndian(resourceBoundaries.thermalLimit)
        data.appendLittleEndian(resourceBoundaries.energyBudgetJoules)
        data.appendLittleEndian(resourceBoundaries.maxPowerWatts)
        data.append(contentsOf: resourceBoundaries.reserved)

        for range in atlasRanges {
            data.appendLittleEndian(range.atlasID)
            data.appendLittleEndian(range.offset)
            data.appendLittleEndian(range.length)
        }

        return data
    }

    public func descriptorHash() throws -> Data {
        let policy = try descriptorHashPolicy()
        return try descriptorHash(using: policy)
    }

    public func descriptorHash(using policy: SaturatedMissionDescriptorHashPolicy) throws -> Data {
        let expectedPolicy = try descriptorHashPolicy()
        guard expectedPolicy == policy else {
            throw SaturatedMissionDescriptorError.descriptorHashPolicyMismatch(
                expected: expectedPolicy,
                provided: policy
            )
        }

        let encoded = try canonicalBinaryEncoding()
        return try policy.digest(encoded)
    }

    public func descriptorHashPolicy() throws -> SaturatedMissionDescriptorHashPolicy {
        try SaturatedMissionDescriptorHashPolicy.policy(forDescriptorVersion: header.version)
    }

    public func descriptorHashHex() throws -> String {
        try descriptorHash().hexEncodedString()
    }
}

public struct SaturatedMissionDescriptorSignature: Sendable, Equatable, Codable {
    public let algorithm: SaturatedMissionSignatureAlgorithm
    public let descriptorHashPolicy: SaturatedMissionDescriptorHashPolicy
    public let keyID: String
    public let signatureBytes: Data

    public init(
        algorithm: SaturatedMissionSignatureAlgorithm = .ed25519,
        descriptorHashPolicy: SaturatedMissionDescriptorHashPolicy = .sha256Tier1V1,
        keyID: String,
        signatureBytes: Data
    ) {
        self.algorithm = algorithm
        self.descriptorHashPolicy = descriptorHashPolicy
        self.keyID = keyID
        self.signatureBytes = signatureBytes
    }

    private enum CodingKeys: String, CodingKey {
        case algorithm
        case descriptorHashPolicy
        case keyID
        case signatureBytes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        algorithm = try container.decode(SaturatedMissionSignatureAlgorithm.self, forKey: .algorithm)
        descriptorHashPolicy = try container.decodeIfPresent(
            SaturatedMissionDescriptorHashPolicy.self,
            forKey: .descriptorHashPolicy
        ) ?? .sha256Tier1V1
        keyID = try container.decode(String.self, forKey: .keyID)
        signatureBytes = try container.decode(Data.self, forKey: .signatureBytes)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(algorithm, forKey: .algorithm)
        try container.encode(descriptorHashPolicy, forKey: .descriptorHashPolicy)
        try container.encode(keyID, forKey: .keyID)
        try container.encode(signatureBytes, forKey: .signatureBytes)
    }
}

public protocol SaturatedMissionDescriptorSigning: Sendable {
    func signDescriptorHash(_ descriptorHash: Data, keyID: String) throws -> SaturatedMissionDescriptorSignature
}

public protocol SaturatedMissionDescriptorVerifying: Sendable {
    func verifyDescriptorHash(_ descriptorHash: Data, signature: SaturatedMissionDescriptorSignature) throws -> Bool
}

public extension SaturatedMissionDescriptorSigning {
    func sign(
        _ descriptor: SaturatedMissionDescriptor,
        keyID: String
    ) throws -> SaturatedMissionDescriptorSignature {
        let policy = try descriptor.descriptorHashPolicy()
        let hash = try descriptor.descriptorHash(using: policy)
        let signature = try signDescriptorHash(hash, keyID: keyID)
        return SaturatedMissionDescriptorSignature(
            algorithm: signature.algorithm,
            descriptorHashPolicy: policy,
            keyID: signature.keyID,
            signatureBytes: signature.signatureBytes
        )
    }
}

public extension SaturatedMissionDescriptorVerifying {
    func verify(
        _ descriptor: SaturatedMissionDescriptor,
        signature: SaturatedMissionDescriptorSignature
    ) throws -> Bool {
        let expectedPolicy = try descriptor.descriptorHashPolicy()
        guard signature.descriptorHashPolicy == expectedPolicy else {
            return false
        }
        let hash = try descriptor.descriptorHash(using: signature.descriptorHashPolicy)
        return try verifyDescriptorHash(hash, signature: signature)
    }
}

#if canImport(CryptoKit)
public struct CryptoKitEd25519MissionDescriptorSigner: SaturatedMissionDescriptorSigning, Sendable {
    private let privateKey: Curve25519.Signing.PrivateKey

    public init(privateKey: Curve25519.Signing.PrivateKey) {
        self.privateKey = privateKey
    }

    public func signDescriptorHash(_ descriptorHash: Data, keyID: String) throws -> SaturatedMissionDescriptorSignature {
        let signature = try privateKey.signature(for: descriptorHash)
        return SaturatedMissionDescriptorSignature(
            algorithm: .ed25519,
            keyID: keyID,
            signatureBytes: signature
        )
    }
}

public struct CryptoKitEd25519MissionDescriptorVerifier: SaturatedMissionDescriptorVerifying, Sendable {
    private let publicKey: Curve25519.Signing.PublicKey

    public init(publicKey: Curve25519.Signing.PublicKey) {
        self.publicKey = publicKey
    }

    public func verifyDescriptorHash(_ descriptorHash: Data, signature: SaturatedMissionDescriptorSignature) throws -> Bool {
        guard signature.algorithm == .ed25519 else {
            return false
        }
        return publicKey.isValidSignature(signature.signatureBytes, for: descriptorHash)
    }
}
#endif

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
            append(bytes.bindMemory(to: UInt8.self))
        }
    }

    mutating func appendLittleEndian(_ value: Float) {
        var littleEndian = value
        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
            append(bytes.bindMemory(to: UInt8.self))
        }
    }

    func hexEncodedString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}

private extension String {
    func fixedWidthUTF8(length: Int) -> Data {
        var data = Data(utf8.prefix(length))
        if data.count < length {
            data.append(contentsOf: repeatElement(0, count: length - data.count))
        }
        return data
    }
}

private func uuidBytes(_ uuid: UUID) -> Data {
    var copy = uuid.uuid
    return withUnsafeBytes(of: &copy) { bytes in
        Data(bytes.bindMemory(to: UInt8.self))
    }
}
