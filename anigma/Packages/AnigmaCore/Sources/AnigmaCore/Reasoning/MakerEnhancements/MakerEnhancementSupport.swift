//
//  MakerEnhancementSupport.swift
//  AnigmaCore
//
//  Helper utilities for deterministic encoding and resource sizing.
//

import Foundation
import CryptoKit

enum MakerReceiptEncoding {
    static func canonicalData<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    static func sha256Hex(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func hashCanonical<T: Encodable>(_ value: T) throws -> String {
        let data = try canonicalData(value)
        return sha256Hex(of: data)
    }
}

struct MakerResourceSample: Sendable {
    let bytes: Int
    let lines: Int
}

enum MakerResourceSizer {
    static func measure(text: String) -> MakerResourceSample {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).count
        return MakerResourceSample(bytes: text.utf8.count, lines: lines)
    }

    static func measure(data: Data) -> MakerResourceSample {
        let text = String(decoding: data, as: UTF8.self)
        return measure(text: text)
    }

    static func exceeds(text: String, limits: MakerResourceLimits) -> Bool {
        let sample = measure(text: text)
        return sample.bytes > limits.maxBytes || sample.lines > limits.maxLines
    }

    static func exceeds(texts: [String], limits: MakerResourceLimits) -> Bool {
        for text in texts {
            if exceeds(text: text, limits: limits) {
                return true
            }
        }
        return false
    }
}
