import Foundation

#if canImport(Metal)
@preconcurrency import Metal
#endif

public enum SaturatedHeartbeatPacketType: UInt32, Sendable, Codable {
    case start = 1
    case heartbeat = 2
    case end = 3
    case violation = 4
}

public enum SaturatedHeartbeatPayloadHashSubstrate: String, Sendable, Codable {
    case cpuFallback
    case metalDigest
    case inKernelDigest
}

public struct SaturatedHeartbeatPayloadHash: Sendable, Equatable, Codable {
    public let bytes: [UInt8]
    public let substrate: SaturatedHeartbeatPayloadHashSubstrate

    public init(bytes: [UInt8], substrate: SaturatedHeartbeatPayloadHashSubstrate) {
        self.bytes = Array(bytes.prefix(SaturatedHeartbeatPacket.hashLength))
            + Array(repeating: 0, count: max(0, SaturatedHeartbeatPacket.hashLength - bytes.count))
        self.substrate = substrate
    }
}

public struct SaturatedHeartbeatPacket: Sendable, Equatable, Codable {
    public static let encodedLength = 64
    public static let extendedEncodedLength = 72
    public static let hashLength = 32

    public let missionID: UUID
    public let packetType: SaturatedHeartbeatPacketType
    public let sequence: UInt32
    public let payloadHash: [UInt8]
    public let timestamp: UInt64
    public let powerWatts: Float
    public let opsPerJoule: Float

    public init(
        missionID: UUID,
        packetType: SaturatedHeartbeatPacketType,
        sequence: UInt32,
        payloadHash: [UInt8],
        timestamp: UInt64,
        powerWatts: Float = 0.0,
        opsPerJoule: Float = 0.0
    ) {
        self.missionID = missionID
        self.packetType = packetType
        self.sequence = sequence
        self.payloadHash = Array(payloadHash.prefix(Self.hashLength))
            + Array(repeating: 0, count: max(0, Self.hashLength - payloadHash.count))
        self.timestamp = timestamp
        self.powerWatts = powerWatts
        self.opsPerJoule = opsPerJoule
    }

    public static func payloadHash(
        for payload: Data,
        preferMetalDigest: Bool = true
    ) throws -> SaturatedHeartbeatPayloadHash {
        try payloadHash(
            for: [UInt8](payload),
            preferMetalDigest: preferMetalDigest
        )
    }

    public static func payloadHash(
        for payloadBytes: [UInt8],
        preferMetalDigest: Bool = true
    ) throws -> SaturatedHeartbeatPayloadHash {
        if preferMetalDigest {
            #if canImport(Metal)
            if let device = MTLCreateSystemDefaultDevice(),
               device.makeCommandQueue() != nil {
                let digest = try MetalBlake3Compression().digest(
                    inputBytes: payloadBytes,
                    useGPUIfAvailable: true
                )
                return SaturatedHeartbeatPayloadHash(
                    bytes: digest,
                    substrate: .metalDigest
                )
            }
            #endif
        }

        return SaturatedHeartbeatPayloadHash(
            bytes: Blake3Digest.digest(payloadBytes),
            substrate: .cpuFallback
        )
    }

    public func canonicalBinaryEncoding() -> Data {
        var data = Data(capacity: Self.extendedEncodedLength)
        data.append(uuidBytes(missionID))
        data.appendLittleEndian(packetType.rawValue)
        data.appendLittleEndian(sequence)
        data.append(contentsOf: payloadHash)
        data.appendLittleEndian(timestamp)
        data.appendLittleEndian(powerWatts)
        data.appendLittleEndian(opsPerJoule)
        return data
    }

    public init(decoding data: Data) throws {
        guard data.count >= Self.encodedLength else {
            throw SaturatedLoggingRingError.packetTooShort(data.count)
        }

        let bytes = [UInt8](data.prefix(max(Self.extendedEncodedLength, data.count)))
        let missionID = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
        let typeRaw = UInt32(littleEndianBytes: bytes[16..<20])
        guard let packetType = SaturatedHeartbeatPacketType(rawValue: typeRaw) else {
            throw SaturatedLoggingRingError.unknownPacketType(typeRaw)
        }

        let sequence = UInt32(littleEndianBytes: bytes[20..<24])
        let payloadHash = Array(bytes[24..<56])
        let timestamp = UInt64(littleEndianBytes: bytes[56..<64])
        
        var powerWatts: Float = 0.0
        var opsPerJoule: Float = 0.0
        
        if data.count >= Self.extendedEncodedLength {
            powerWatts = Float(littleEndianBytes: bytes[64..<68])
            opsPerJoule = Float(littleEndianBytes: bytes[68..<72])
        }

        self.init(
            missionID: missionID,
            packetType: packetType,
            sequence: sequence,
            payloadHash: payloadHash,
            timestamp: timestamp,
            powerWatts: powerWatts,
            opsPerJoule: opsPerJoule
        )
    }
}

extension Data {
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
}

extension UInt32 {
    init(littleEndianBytes bytes: ArraySlice<UInt8>) {
        self = bytes.enumerated().reduce(0) { partial, item in
            partial | (UInt32(item.element) << UInt32(item.offset * 8))
        }
    }
}

extension UInt64 {
    init(littleEndianBytes bytes: ArraySlice<UInt8>) {
        self = bytes.enumerated().reduce(0) { partial, item in
            partial | (UInt64(item.element) << UInt64(item.offset * 8))
        }
    }
}

extension Float {
    init(littleEndianBytes bytes: ArraySlice<UInt8>) {
        let uint32 = UInt32(littleEndianBytes: bytes)
        self = Float(bitPattern: uint32)
    }
}

private func uuidBytes(_ uuid: UUID) -> Data {
    var copy = uuid.uuid
    return Swift.withUnsafeBytes(of: &copy) { bytes in
        Data(bytes.bindMemory(to: UInt8.self))
    }
}
