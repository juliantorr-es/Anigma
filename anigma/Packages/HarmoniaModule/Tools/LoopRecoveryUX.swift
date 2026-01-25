//
//  LoopRecoveryUX.swift
//  HarmoniaModule
//
//  Phase 7.6: Loop recovery UX for agents.
//  Provides deterministic next action templates and recovery guidance when tool calls are blocked.
//

@preconcurrency import Foundation
import AnigmaPrimitives

/// Loop recovery UX that provides deterministic next actions for blocked tool calls.
public struct LoopRecoveryGuidance: Codable, Sendable {
    /// Human-readable problem description
    public let problemDescription: String

    /// The recovery strategy to apply
    public let recoveryStrategy: RecoveryStrategy

    /// Deterministic next action the agent should take
    public let nextActionTemplate: String

    /// Code example showing correct usage
    public let exampleCode: String

    /// List of validation checks before retry
    public let validationChecks: [ValidationCheck]

    /// Expected outcome after recovery
    public let expectedOutcome: String
}

/// Validation check for agent to perform before retry
public struct ValidationCheck: Codable, Sendable {
    /// Check description
    public let description: String

    /// Swift code snippet to perform check
    public let checkCode: String

    /// Expected result value
    public let expectedResult: String
}

/// Factory for creating loop recovery guidance
public enum LoopRecoveryFactory {
    /// Create recovery guidance based on recovery strategy
    public static func createGuidance(
        for strategy: RecoveryStrategy,
        toolName: String,
        lastAttemptDetails: String
    ) -> LoopRecoveryGuidance {
        switch strategy {
        case .requireUnifiedDiff:
            return createUnifiedDiffGuidance(toolName: toolName)
        case .requireByteRangePatch:
            return createByteRangePatchGuidance(toolName: toolName)
        case .requireFreshReadDelta:
            return createFreshReadDeltaGuidance(toolName: toolName)
        case .escalateToHuman:
            return createEscalateToHumanGuidance(toolName: toolName, details: lastAttemptDetails)
        }
    }

    // MARK: - Private Factory Methods

    private static func createUnifiedDiffGuidance(toolName: String) -> LoopRecoveryGuidance {
        return LoopRecoveryGuidance(
            problemDescription: "The apply_patch tool detected repeated failures applying the same patch. This typically indicates that the patch content does not match the file content.",
            recoveryStrategy: .requireUnifiedDiff,
            nextActionTemplate: """
1. Use read_file to get the current content of the file
2. Verify the content matches the expected state before the patch
3. If content differs, generate a new unified diff using git diff or similar
4. Apply the new patch with verify flag first (dry-run)
5. Only apply if dry-run succeeds
""",
            exampleCode: """
// Read the current file content
let currentContent = try await tools.readFile(
    filePath: "/path/to/file.swift"
)

// Compare with expected content
if !currentContent.contains("expected string") {
    // Content differs - need new patch
    let diff = try await tools.gitDiff(
        paths: ["/path/to/file.swift"]
    )
    // Generate unified diff from content
    let unifiedDiff = generateUnifiedDiff(
        original: expectedContent,
        modified: currentContent
    )
}

// Try again with unified diff
let result = try await tools.applyPatch(
    filePath: "/path/to/file.swift",
    patchContent: unifiedDiff,
    dryRun: true  // Verify first
)
""",
            validationChecks: [
                ValidationCheck(
                    description: "Verify file exists and is readable",
                    checkCode: "FileManager.default.fileExists(atPath: filePath)",
                    expectedResult: "true"
                ),
                ValidationCheck(
                    description: "Verify patch format is valid unified diff",
                    checkCode: "patchContent.contains(\"---\") && patchContent.contains(\"+++\")",
                    expectedResult: "true"
                ),
                ValidationCheck(
                    description: "Verify file content before patch matches patch expectations",
                    checkCode: "fileContent.contains(\"@@ -\") || validatePatchContext()",
                    expectedResult: "true"
                )
            ],
            expectedOutcome: "After applying the unified diff correctly, the file should contain the intended modifications without the patch failing again."
        )
    }

    private static func createByteRangePatchGuidance(toolName: String) -> LoopRecoveryGuidance {
        return LoopRecoveryGuidance(
            problemDescription: "The patch application failed with byte-range mismatches. This indicates that file size or byte positions changed.",
            recoveryStrategy: .requireByteRangePatch,
            nextActionTemplate: """
1. Get the exact byte position and length of the content to modify
2. Verify the byte range matches the actual file content
3. Generate a byte-range patch with exact start/length parameters
4. Apply with verification first
""",
            exampleCode: """
// Get file content to find exact byte positions
let content = try await tools.readFile(filePath: "/path/to/file.swift")
let targetString = "find this text"

if let range = content.range(of: targetString) {
    let startByte = content.distance(from: content.startIndex, to: range.lowerBound)
    let length = content.distance(from: range.lowerBound, to: range.upperBound)

    // Apply byte-range patch
    let result = try await tools.applyPatch(
        filePath: "/path/to/file.swift",
        patchContent: byteRangePatch(
            startByte: startByte,
            length: length,
            replacement: "replacement text"
        )
    )
}
""",
            validationChecks: [
                ValidationCheck(
                    description: "Verify exact byte position in file",
                    checkCode: "content[startByte..<(startByte+length)] == expectedContent",
                    expectedResult: "true"
                ),
                ValidationCheck(
                    description: "Verify replacement text is valid",
                    checkCode: "replacementText.count > 0 && !replacementText.contains(nullByte)",
                    expectedResult: "true"
                )
            ],
            expectedOutcome: "Byte-range patch applied successfully at the exact file positions."
        )
    }

    private static func createFreshReadDeltaGuidance(toolName: String) -> LoopRecoveryGuidance {
        return LoopRecoveryGuidance(
            problemDescription: "The read operation is in a loop. You are reading the same file repeatedly without making changes. Read files once and process the content.",
            recoveryStrategy: .requireFreshReadDelta,
            nextActionTemplate: """
1. Read the file ONCE and store the content
2. Process the content completely before any further reads
3. If modification needed, apply it with apply_patch
4. Do NOT re-read the same file in a loop
5. If iterative reads needed, add a 1-minute delay between reads and change the file content between reads
""",
            exampleCode: """
// CORRECT: Read once, process completely
let fileContent = try await tools.readFile(filePath: "/path/to/file.swift")
let modifiedContent = processContent(fileContent)
try await tools.applyPatch(
    filePath: "/path/to/file.swift",
    patchContent: generateDiff(fileContent, modifiedContent)
)

// WRONG: Don't do this loop
while someCondition {
    let content = try await tools.readFile(filePath: "/path/to/file.swift")  // ← Loop detected!
    // ...
}
""",
            validationChecks: [
                ValidationCheck(
                    description: "Check that you are not calling read_file in a loop without modification",
                    checkCode: "!callHistory.filter { $0.tool == \"read_file\" && $0.file == filePath }.count > 1",
                    expectedResult: "true"
                ),
                ValidationCheck(
                    description: "Verify file content actually changed between reads",
                    checkCode: "previousContent != currentContent",
                    expectedResult: "true"
                )
            ],
            expectedOutcome: "File read once, processed completely, and any necessary modifications applied in a single pass."
        )
    }

    private static func createEscalateToHumanGuidance(
        toolName: String,
        details: String
    ) -> LoopRecoveryGuidance {
        return LoopRecoveryGuidance(
            problemDescription: "The tool has failed repeatedly and cannot recover automatically. Human intervention is required.",
            recoveryStrategy: .escalateToHuman,
            nextActionTemplate: """
This situation requires human review. Please:

1. Stop automated retries immediately
2. Collect evidence:
   - Last 3 tool call attempts and their failures
   - Current file state
   - Expected target state
   - Evidence bundle (stored in .evidence/ directory)
3. Review the problem:
   - Is the approach correct?
   - Are the tool parameters valid?
   - Is the system state as expected?
4. Either:
   - Provide manual fix and continue
   - Change approach entirely
   - Report as bug if tool is malfunctioning
""",
            exampleCode: """
// When escalating, provide this context:
let escalationReport = LoopEscalationReport(
    toolName: "\(toolName)",
    failureCount: 3,
    lastErrorMessage: "\(details)",
    sessionId: sessionId,
    evidenceId: evidenceId,
    recommendedAction: "Human review required",
    suggestedAlternatives: [
        "Use different tool",
        "Change file format",
        "Split into multiple smaller changes"
    ]
)
print(escalationReport.prettyDescription())
""",
            validationChecks: [
                ValidationCheck(
                    description: "Verify evidence bundle exists for human review",
                    checkCode: "FileManager.default.fileExists(atPath: evidencePath)",
                    expectedResult: "true"
                )
            ],
            expectedOutcome: "Human reviews the evidence and makes a decision on how to proceed."
        )
    }
}

/// Report for escalation to human
public struct LoopEscalationReport: Codable, Sendable {
    public let toolName: String
    public let failureCount: Int
    public let lastErrorMessage: String
    public let sessionId: String
    public let evidenceId: String
    public let recommendedAction: String
    public let suggestedAlternatives: [String]

    public func prettyDescription() -> String {
        return """

        ╔════════════════════════════════════════════════════════════╗
        ║  LOOP ESCALATION REQUIRED                                  ║
        ╚════════════════════════════════════════════════════════════╝

        Tool: \(toolName)
        Failures: \(failureCount) attempts
        Session: \(sessionId)
        Evidence: \(evidenceId)

        Last Error:
        \(lastErrorMessage)

        Recommended Action:
        \(recommendedAction)

        Suggested Alternatives:
        \(suggestedAlternatives.enumerated().map { "\\(\($0.offset + 1)). \\($0.element)" }.joined(separator: "\\n"))

        Next Steps:
        1. Review the evidence bundle at .evidence/
        2. Analyze the failure pattern
        3. Choose appropriate recovery action
        4. Resume with new approach
        """
    }
}
