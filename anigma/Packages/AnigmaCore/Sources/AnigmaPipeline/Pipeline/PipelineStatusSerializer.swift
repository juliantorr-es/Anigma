//
//  PipelineStatusSerializer.swift
//  AnigmaCore
//
//  [Brief description of file purpose]
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import InferenceCore
import ContractsCore
import DatabaseCore
import Foundation

/// Stable JSON encoder/decoder for pipeline status snapshots.
public enum PipelineStatusSerializer {
    public static func encode(status: PipelineStatus) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(status)
    }

    public static func decode(data: Data) throws -> PipelineStatus {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PipelineStatus.self, from: data)
    }
}
