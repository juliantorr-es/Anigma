//
//  ChangesetParser.swift
//  AnigmaAppMac
//
//  Parses agent output and raw diffs into structured ChangeSet objects.
//

import Foundation
import AnigmaClientKit

/// Parsed result from an agent's execution
struct AgentOutput {
    let diff: String?
    let reasoning: String
    let fileModifications: [String]
}

enum ChangesetParserError: LocalizedError {
    case invalidFormat
    case emptyDiff

    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "Could not parse the agent output format."
        case .emptyDiff: return "Agent produced no file changes."
        }
    }
}

actor ChangesetParser {
    static let shared = ChangesetParser()

    /// Parses a raw unified diff into a ChangeSet
    /// - Parameters:
    ///   - diff: The raw git diff output
    ///   - workspace: The workspace context
    ///   - jobDescription: Description of the job that produced this diff
    /// - Returns: A governed ChangeSet ready for review
    func parse(diff: String, workspaceId: UUID, authorId: UUID, jobDescription: String) throws -> ChangeSet {
        guard !diff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ChangesetParserError.emptyDiff
        }

        let id = UUID()
        let patch = Patch(
            id: UUID(),
            filePath: "Multiple Files", // Summary for now, ideally we parse per-file chunks
            diff: diff
        )

        return ChangeSet(
            id: id,
            workspaceId: workspaceId,
            title: "Proposed Changes",
            summary: jobDescription,
            patches: [patch],
            riskScore: 0.5,
            status: .proposed,
            generatedBy: authorId.uuidString,
            createdAt: Date()
        )
    }

    /// Parses structured XML/JSON output from an agent (Future proofing)
    /// Currently just extracts the diff block
    func parseAgentResponse(_ response: String) -> AgentOutput {
        // Naive extraction of ```diff ... ``` blocks or similar
        // For now, we assume the agent returns the diff directly or wrapped in markdown

        var diff = ""
        var reasoning = response

        if response.contains("```diff") {
            let components = response.components(separatedBy: "```diff")
            if components.count > 1 {
                let diffBlock = components[1].components(separatedBy: "```").first ?? ""
                diff = diffBlock.trimmingCharacters(in: .whitespacesAndNewlines)
                // Remove the diff from reasoning to keep it clean
                reasoning = response.replacingOccurrences(of: "```diff\(diffBlock)```", with: "[Diff Extracted]")
            }
        }

        return AgentOutput(diff: diff.isEmpty ? nil : diff, reasoning: reasoning, fileModifications: [])
    }
}
