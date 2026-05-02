import Foundation
import CryptoKit
#if canImport(SaturationKit)
import SaturationKit
#endif

enum ArtifactHashing {
    static func hardwareBackedHex(for data: Data, preferMetalDigest: Bool = true) -> String {
        #if canImport(SaturationKit)
        if let digest = try? SaturatedHeartbeatPacket.payloadHash(
            for: data,
            preferMetalDigest: preferMetalDigest
        ) {
            return digest.bytes.hexString
        }
        #endif

        return legacyHex(for: data)
    }

    static func legacyHex(for data: Data) -> String {
        SHA256.hash(data: data).hexString
    }

    static func manifestHash(from fileHashes: [String: String], preferMetalDigest: Bool = true) -> String {
        let canonical = fileHashes
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key):\($0.value)" }
            .joined(separator: "|")
        return hardwareBackedHex(for: Data(canonical.utf8), preferMetalDigest: preferMetalDigest)
    }

    static func legacyManifestHash(from fileHashes: [String: String]) -> String {
        let canonical = fileHashes
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key):\($0.value)" }
            .joined(separator: "|")
        return legacyHex(for: Data(canonical.utf8))
    }

    static func matchesStoredHash(_ storedHash: String, data: Data, preferMetalDigest: Bool = true) -> Bool {
        hardwareBackedHex(for: data, preferMetalDigest: preferMetalDigest) == storedHash
            || legacyHex(for: data) == storedHash
    }
}

private extension Sequence where Element == UInt8 {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
