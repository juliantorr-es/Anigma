//
//  MaturityHelpers.swift
//  AnigmaCLIExecutable
//
//  Shared helpers for building maturity assessors with consistent workspace/build-log context.
//

import Foundation
import AnigmaCLIDatabase

func makeWorkspaceURL() -> URL {
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
}

func buildLogURLIfPresent(in workspace: URL) -> URL? {
    let potentialLog = workspace.appendingPathComponent("build.log")
    return FileManager.default.fileExists(atPath: potentialLog.path) ? potentialLog : nil
}

func makeMaturityAssessor(database: CLIDatabaseActor) -> MaturityAssessor {
    let workspace = makeWorkspaceURL()
    let buildLog = buildLogURLIfPresent(in: workspace)
    return MaturityAssessor(database: database, workspacePath: workspace, buildLogPath: buildLog)
}
