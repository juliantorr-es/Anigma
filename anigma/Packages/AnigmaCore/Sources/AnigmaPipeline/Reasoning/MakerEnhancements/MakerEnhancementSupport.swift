//
//  MakerEnhancementSupport.swift
//  AnigmaCore
//
//  Helper utilities for deterministic encoding and resource sizing.
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import ContractsCore
import InferenceCore
import Foundation
import CryptoKit

enum MakerReceiptEncoding {
    static func canonicalData<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    static func blake3Hex(of data: Data) -> String {
        return BLAKE3Digest.hex(of: data)
    }

    static func hashCanonical<T: Encodable>(_ value: T) throws -> String {
        let data = try canonicalData(value)
        return blake3Hex(of: data)
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
