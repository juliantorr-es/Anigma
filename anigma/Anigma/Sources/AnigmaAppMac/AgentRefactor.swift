//
//  AgentRefactor.swift
//  AnigmaAppMac
//
//  Wrapper for submitting refactor jobs to the daemon.
//

import Foundation

struct AgentRefactor {
    let jobClient: DaemonJobClient

    func run(repoURL: URL, fileURL: URL, instruction: String) async throws -> DaemonJob {
        try await jobClient.submitRefactorJob(
            repoURL: repoURL,
            fileURL: fileURL,
            instruction: instruction
        )
    }
}
