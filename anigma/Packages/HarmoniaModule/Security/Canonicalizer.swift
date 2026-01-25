//
//  Canonicalizer.swift
//  HarmoniaModule
//
//  [Brief description of file purpose]
//

import ContractsCore
import DatabaseCore
@preconcurrency import Foundation

public struct Canonicalizer {

    /// Create canonical JSON representation for signing
    public static func canonicalJSON(_ data: Any) throws -> Data {
        // Convert to JSON with strict canonicalization rules
        let jsonData = try JSONSerialization.data(
            withJSONObject: data,
            options: [
                .sortedKeys,  // Alphabetical key ordering
                .fragmentsAllowed,  // Ensure consistent fragment handling
                .withoutEscapingSlashes  // Consistent slash handling
            ])

        // Apply additional canonicalization for JSON
        return try canonicalizeJSONBytes(jsonData)
    }

    /// Create canonical binary representation for evidence heads
    public static func canonicalEvidenceHead(_ evidence: EvidenceHeadInfo) throws -> Data {
        var data = Data()

        // Use fixed-width, big-endian encoding for all fields
        data.append(canonicalString(evidence.eventId))
        data.append(canonicalString(evidence.headHash))
        data.append(canonicalInt64(evidence.timestamp))
        data.append(canonicalString(evidence.lastActor))

        return data
    }

    /// Create canonical bundle manifest bytes
    public static func canonicalBundleManifest(_ manifest: RedactedBundleManifest) throws -> Data {
        var data = Data()

        // Header with fixed-width fields
        data.append(canonicalString(manifest.bundleId))
        data.append(canonicalString(manifest.originalBundleId))
        data.append(canonicalString(manifest.redactionSessionId))
        data.append(canonicalInt64(manifest.createdAt))
        data.append(canonicalString(manifest.createdBy))
        data.append(canonicalString(manifest.bundleType))

        // Hashes (always 32 bytes for SHA256)
        data.append(try hexToData(manifest.originalManifestHash))
        data.append(try hexToData(manifest.auditTrailHash))

        return data
    }

    /// Canonical string encoding (UTF-8 with length prefix)
    private static func canonicalString(_ string: String) -> Data {
        let stringData = string.data(using: .utf8) ?? Data()
        var result = Data()

        // 4-byte length prefix (big-endian)
        let length = UInt32(stringData.count)
        result.append(contentsOf: withUnsafeBytes(of: length.bigEndian) { Array($0) })

        // UTF-8 encoded string
        result.append(stringData)

        return result
    }

    /// Canonical 64-bit integer encoding (big-endian)
    private static func canonicalInt64(_ value: Int) -> Data {
        let uintValue = UInt64(value)
        return withUnsafeBytes(of: uintValue.bigEndian) { Data($0) }
    }

    /// Additional JSON canonicalization for edge cases
    private static func canonicalizeJSONBytes(_ data: Data) throws -> Data {
        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return data
        }

        // Ensure consistent number formatting
        json = canonicalizeNumbers(json)

        // Re-serialize with strict options
        return try JSONSerialization.data(
            withJSONObject: json,
            options: [
                .sortedKeys,
                .withoutEscapingSlashes
            ])
    }

    /// Canonicalize number formatting (no scientific notation, consistent precision)
    private static func canonicalizeNumbers(_ json: [String: Any]) -> [String: Any] {
        var result = json

        for (key, value) in result {
            if let number = value as? NSNumber {
                // Convert to string with consistent formatting
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                formatter.maximumFractionDigits = 10
                formatter.usesSignificantDigits = false

                if let formatted = formatter.string(from: number) {
                    // Store as string to preserve formatting
                    result[key] = formatted
                }
            } else if let dict = value as? [String: Any] {
                result[key] = canonicalizeNumbers(dict)
            } else if let array = value as? [Any] {
                result[key] = canonicalizeNumbersInArray(array)
            }
        }

        return result
    }

    private static func canonicalizeNumbersInArray(_ array: [Any]) -> [Any] {
        return array.map { item in
            if let number = item as? NSNumber {
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                formatter.maximumFractionDigits = 10
                return formatter.string(from: number) ?? item
            } else if let dict = item as? [String: Any] {
                return canonicalizeNumbers(dict)
            } else if let subArray = item as? [Any] {
                return canonicalizeNumbersInArray(subArray)
            }
            return item
        }
    }

    /// Convert hex string to data with validation
    private static func hexToData(_ hex: String) throws -> Data {
        let cleanHex = hex.lowercased().replacingOccurrences(of: "0x", with: "")
        guard cleanHex.count % 2 == 0 else {
            throw CanonicalizationError.invalidHexLength(hex)
        }

        var data = Data()
        var index = cleanHex.startIndex

        while index < cleanHex.endIndex {
            let nextIndex = cleanHex.index(index, offsetBy: 2)
            let byteString = String(cleanHex[index..<nextIndex])

            guard let byte = UInt8(byteString, radix: 16) else {
                throw CanonicalizationError.invalidHexByte(byteString)
            }

            data.append(byte)
            index = nextIndex
        }

        return data
    }
}

enum CanonicalizationError: Error, LocalizedError {
    case invalidHexLength(String)
    case invalidHexByte(String)

    public var errorDescription: String? {
        switch self {
        case .invalidHexLength(let hex):
            return "Invalid hex length: \(hex)"
        case .invalidHexByte(let byte):
            return "Invalid hex byte: \(byte)"
        }
    }
}
