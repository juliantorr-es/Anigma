//
//  DaemonServer+SimplifiedANEScheduling.swift
//  AnigmaDaemonCore
//

import Foundation

extension DaemonServer {
    public func scheduleJobWithSimplifiedANE(
        spec: JobSpec,
        clientId: String,
        artifactPaths: [String]? = nil
    ) async throws -> (jobId: String, schedulingDecision: SimplifiedSchedulingDecision?) {
        _ = artifactPaths
        let jobId = try await jobQueue.submit(spec: spec, clientId: clientId)
        return (jobId, nil)
    }
}
