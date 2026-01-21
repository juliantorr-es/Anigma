//
//  ApplyPatchTool.swift
//  HarmoniaModule
//
//  Governed apply_patch tool with verification, rollback, auditing, and pre-flight validation.
//  Includes Swift concurrency checks, Sendable conformance, data race detection, and best practices.
//

import AnigmaPrimitives
import DatabaseCore
import Foundation

public struct ApplyPatchTool: Sendable {
    private let repoRoot: String
    private let dbPath: String
    private let enablePreFlightValidation: Bool
    private let progressCallback: ToolProgressCallback?

    public init(
        repoRoot: String = FileManager.default.currentDirectoryPath,
        dbPath: String? = nil,
        enablePreFlightValidation: Bool = true,
        progressCallback: ToolProgressCallback? = nil
    ) {
        self.repoRoot = repoRoot
        self.dbPath = dbPath ?? Self.defaultDatabasePath()
        self.enablePreFlightValidation = enablePreFlightValidation
        self.progressCallback = progressCallback
    }

    public func execute(_ request: ToolCallRequest, session: SessionContext) async
        -> ToolCallResponse {
        let patchId = UUID().uuidString
        let paramsData = Data(request.parameters.utf8)
        let parameters =
            (try? JSONSerialization.jsonObject(with: paramsData) as? [String: Any]) ?? [:]

        guard let patchContent = parameters["patch"] as? String else {
            return failureResponse(
                toolName: request.toolName,
                patchId: patchId,
                message: "Missing required parameter: patch"
            )
        }

        let targetFiles = parameters["target_files"] as? [String] ?? []
        let rollbackOnFailure = parameters["rollback_on_failure"] as? Bool ?? true
        let skipValidation = parameters["skip_validation"] as? Bool ?? false
        let normalizedTargets = Set(targetFiles.map(normalizePath))

        for path in normalizedTargets {
            if !isSafeRelativePath(path) {
                return failureResponse(
                    toolName: request.toolName,
                    patchId: patchId,
                    message: "Security violation: invalid target file path \(path)"
                )
            }
        }

        let parsedTargets = parsePatchTargets(patchContent)
        if parsedTargets.isEmpty {
            return failureResponse(
                toolName: request.toolName,
                patchId: patchId,
                message: "Patch content does not include any file targets"
            )
        }

        var filePatches: [String: String] = [:]
        for target in parsedTargets {
            let normalized = normalizePath(target.filePath)
            if !isSafeRelativePath(normalized) {
                return failureResponse(
                    toolName: request.toolName,
                    patchId: patchId,
                    message: "Security violation: invalid patch file path \(normalized)"
                )
            }
            if let existing = filePatches[normalized] {
                filePatches[normalized] = existing + "\n" + target.patchContent
            } else {
                filePatches[normalized] = target.patchContent
            }
        }

        if !normalizedTargets.isEmpty {
            let patchFiles = Set(filePatches.keys)
            let unauthorized = patchFiles.subtracting(normalizedTargets)
            if !unauthorized.isEmpty {
                return failureResponse(
                    toolName: request.toolName,
                    patchId: patchId,
                    message: "Patch touches files outside target_files: \(unauthorized.sorted().joined(separator: ", "))"
                )
            }
        }

        let affectedFiles = filePatches.keys.sorted()

        await progressCallback?(1, 4, "Prepared patch for \(affectedFiles.count) files")

        var beforeSnapshots: [String: FileSnapshot] = [:]
        do {
            for file in affectedFiles {
                beforeSnapshots[file] = try captureSnapshot(for: file, requireUTF8: true)
            }
        } catch {
            return failureResponse(
                toolName: request.toolName,
                patchId: patchId,
                message: "Failed to read before-state: \(error.localizedDescription)"
            )
        }

        let tempPatchURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString + ".patch")

        do {
            try patchContent.write(to: tempPatchURL, atomically: true, encoding: .utf8)
        } catch {
            return failureResponse(
                toolName: request.toolName,
                patchId: patchId,
                message: "Failed to write patch file: \(error.localizedDescription)"
            )
        }

        defer { try? FileManager.default.removeItem(at: tempPatchURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/patch")
        process.currentDirectoryURL = URL(fileURLWithPath: repoRoot)
        process.arguments = ["-p1", "-i", tempPatchURL.path]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            return failureResponse(
                toolName: request.toolName,
                patchId: patchId,
                message: "Process execution error: \(error.localizedDescription)"
            )
        }

        process.waitUntilExit()

        await progressCallback?(2, 4, "Patch command completed")

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let exitCode = Int(process.terminationStatus)
        let stderrText = String(data: errorData, encoding: .utf8) ?? ""

        let db = DatabaseActor(dbPath: dbPath)
        let verifier = PatchVerifier(dbActor: db)
        let auditor = PatchAuditor(dbActor: db)
        let rollbackManager = RollbackManager(dbActor: db)

        var verificationResults: [PatchFileVerification] = []
        var snapshots: [PatchFileSnapshot] = []
        var hasVerificationFailure = false
        var recordedFiles = Set<String>()

        await progressCallback?(3, 4, "Verifying patch results")

        for file in affectedFiles {
            let beforeSnapshot = beforeSnapshots[file] ?? FileSnapshot.empty(filePath: file, repoRoot: repoRoot)
            let afterSnapshot = captureSnapshotSafe(for: file)

            let verification: PatchVerificationResult
            if let beforeContent = beforeSnapshot.content,
               let afterContent = afterSnapshot.content {
                do {
                    verification = try await verifier.verify(
                        patchContent: filePatches[file] ?? patchContent,
                        originalContent: beforeContent,
                        patchedContent: afterContent
                    )
                } catch {
                    verification = verificationFailure(
                        filePath: file,
                        beforeHash: beforeSnapshot.hash,
                        afterHash: afterSnapshot.hash,
                        message: "Verification failed: \(error.localizedDescription)"
                    )
                }
            } else {
                verification = verificationFailure(
                    filePath: file,
                    beforeHash: beforeSnapshot.hash,
                    afterHash: afterSnapshot.hash,
                    message: "Unable to decode file content for verification"
                )
            }

            if !verification.isValid {
                hasVerificationFailure = true
            }

            let outcome = (exitCode == 0 && verification.isValid) ? "success" :
                (verification.partiallyApplied ? "partial" : "failure")

            try? await auditor.logAction(
                action: "apply",
                actor: session.agentId,
                targetFile: file,
                patchId: patchId,
                beforeState: verification.beforeHash,
                afterState: verification.afterHash,
                outcome: outcome,
                details: "exit_code=\(exitCode)"
            )

            if exitCode == 0 && verification.isValid {
                try? await rollbackManager.recordPatchApplication(
                    patchId: patchId,
                    targetFile: file,
                    beforeHash: verification.beforeHash,
                    afterHash: verification.afterHash,
                    appliedBy: session.agentId
                )
                recordedFiles.insert(file)
            }

            verificationResults.append(PatchFileVerification(filePath: file, verification: verification))
            snapshots.append(PatchFileSnapshot(
                filePath: file,
                beforeHash: beforeSnapshot.hash,
                afterHash: afterSnapshot.hash,
                sizeBytesBefore: beforeSnapshot.sizeBytes,
                sizeBytesAfter: afterSnapshot.sizeBytes,
                existedBefore: beforeSnapshot.existed,
                existsAfter: afterSnapshot.existed
            ))
        }

        // STEP 4: Pre-flight validation (Swift concurrency, Sendable, best practices)
        var validationResult: SwiftValidationResult?
        var validationFailed = false

        if enablePreFlightValidation && !skipValidation && exitCode == 0 && !hasVerificationFailure {
            // Only validate Swift files
            let swiftFiles = affectedFiles.filter { $0.hasSuffix(".swift") }

            if !swiftFiles.isEmpty {
                let validator = SwiftCodeValidator(workingDirectory: repoRoot)

                do {
                    validationResult = try await validator.validate(affectedFiles: swiftFiles)

                    if !validationResult!.isValid {
                        validationFailed = true

                        try? await auditor.logAction(
                            action: "validation_failed",
                            actor: session.agentId,
                            targetFile: swiftFiles.joined(separator: ", "),
                            patchId: patchId,
                            beforeState: "",
                            afterState: "",
                            outcome: "failure",
                            details: "Swift validation failed: \(validationResult!.issues.count) issues"
                        )
                    }
                } catch {
                    // Validation error - log but don't block
                    try? await auditor.logAction(
                        action: "validation_error",
                        actor: session.agentId,
                        targetFile: swiftFiles.joined(separator: ", "),
                        patchId: patchId,
                        beforeState: "",
                        afterState: "",
                        outcome: "error",
                        details: "Validation error: \(error.localizedDescription)"
                    )
                }
            }
        }

        var rollbackSummary: PatchRollbackSummary?
        if rollbackOnFailure && (exitCode != 0 || hasVerificationFailure || validationFailed) {
            var restoredFiles: [String] = []

            for file in affectedFiles {
                let beforeSnapshot = beforeSnapshots[file] ?? FileSnapshot.empty(filePath: file, repoRoot: repoRoot)
                restoreSnapshot(beforeSnapshot)
                restoredFiles.append(file)

                if recordedFiles.contains(file) {
                    _ = try? await rollbackManager.rollbackPatch(
                        patchId: patchId,
                        targetFile: file,
                        currentContent: beforeSnapshot.content ?? ""
                    )
                }

                try? await auditor.logAction(
                    action: "rollback",
                    actor: session.agentId,
                    targetFile: file,
                    patchId: patchId,
                    beforeState: beforeSnapshot.hash,
                    afterState: beforeSnapshot.hash,
                    outcome: "success",
                    details: "rollback_on_failure"
                )
            }

            let rollbackReason: String
            if validationFailed {
                rollbackReason = "swift_validation_failed"
            } else if exitCode == 0 {
                rollbackReason = "verification_failed"
            } else {
                rollbackReason = "patch_failed"
            }

            rollbackSummary = PatchRollbackSummary(
                performed: true,
                restoredFiles: restoredFiles,
                reason: rollbackReason
            )
        }

        let patchDiagnostic = detectPatchDiagnostic(stderr: stderrText, exitCode: exitCode)

        let resultPayload = ApplyPatchResult(
            patchId: patchId,
            exitCode: exitCode,
            stdout: String(data: outputData, encoding: .utf8) ?? "",
            stderr: stderrText,
            snapshots: snapshots,
            verifications: verificationResults,
            rollback: rollbackSummary,
            validation: validationResult,
            patchDiagnosis: patchDiagnostic,
            error: nil
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let resultData = (try? encoder.encode(resultPayload)) ?? Data()

        let status: ToolCallStatus = (exitCode == 0 && !hasVerificationFailure && !validationFailed) ? .success : .failed

        var diagnosis: String?
        if status == .failed {
            if let patchDiagnostic = patchDiagnostic {
                diagnosis = patchDiagnostic
            } else if validationFailed {
                diagnosis = "Patch applied but Swift validation failed - see validation issues for details"
            } else if hasVerificationFailure {
                diagnosis = "Patch application failed or did not verify cleanly"
            } else {
                diagnosis = "Patch application failed"
            }
        }

        await progressCallback?(4, 4, "Patch complete")

        return ToolCallResponse(
            status: status,
            result: resultData,
            toolName: request.toolName,
            diagnosis: diagnosis
        )

    }

    private func failureResponse(
        toolName: String,
        patchId: String,
        message: String
    ) -> ToolCallResponse {
        let resultPayload = ApplyPatchResult(
            patchId: patchId,
            exitCode: -1,
            stdout: "",
            stderr: "",
            snapshots: [],
            verifications: [],
            rollback: nil,
            validation: nil,
            patchDiagnosis: message,
            error: message
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let resultData = (try? encoder.encode(resultPayload)) ?? Data()

        return ToolCallResponse(
            status: .failed,
            result: resultData,
            toolName: toolName,
            diagnosis: message
        )
    }

    private func captureSnapshot(for filePath: String, requireUTF8: Bool) throws -> FileSnapshot {
        let fullPath = URL(
            fileURLWithPath: filePath,
            relativeTo: URL(fileURLWithPath: repoRoot)
        ).path

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fullPath) {
            let data = try Data(contentsOf: URL(fileURLWithPath: fullPath))
            let content = String(data: data, encoding: .utf8)
            if requireUTF8 && content == nil {
                throw PatchError.invalidEncoding(filePath)
            }
            return FileSnapshot(
                filePath: filePath,
                fullPath: fullPath,
                existed: true,
                data: data,
                content: content,
                hash: ContentHashing.computeSHA256(data),
                sizeBytes: data.count
            )
        }

        return FileSnapshot(
            filePath: filePath,
            fullPath: fullPath,
            existed: false,
            data: Data(),
            content: "",
            hash: ContentHashing.computeSHA256(Data()),
            sizeBytes: 0
        )
    }

    private func captureSnapshotSafe(for filePath: String) -> FileSnapshot {
        (try? captureSnapshot(for: filePath, requireUTF8: false))
            ?? FileSnapshot.empty(filePath: filePath, repoRoot: repoRoot)
    }

    private func restoreSnapshot(_ snapshot: FileSnapshot) {
        let fileManager = FileManager.default
        if snapshot.existed {
            let url = URL(fileURLWithPath: snapshot.fullPath)
            let directory = url.deletingLastPathComponent()
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try? snapshot.data.write(to: url, options: .atomic)
        } else if fileManager.fileExists(atPath: snapshot.fullPath) {
            try? fileManager.removeItem(atPath: snapshot.fullPath)
        }
    }

    private func parsePatchTargets(_ patch: String) -> [PatchTarget] {
        let lines = patch.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var targets: [PatchTarget] = []
        var currentLines: [String] = []
        var currentFile: String?
        var fallbackFile: String?

        func commitCurrent() {
            guard let file = currentFile ?? fallbackFile else {
                currentLines.removeAll()
                currentFile = nil
                fallbackFile = nil
                return
            }

            let content = currentLines.joined(separator: "\n")
            targets.append(PatchTarget(filePath: file, patchContent: content))
            currentLines.removeAll()
            currentFile = nil
            fallbackFile = nil
        }

        for line in lines {
            if line.hasPrefix("diff --git ") {
                if !currentLines.isEmpty {
                    commitCurrent()
                }
                currentLines = [line]
                currentFile = nil
                fallbackFile = parseDiffGitLine(line)
                continue
            }

            if line.hasPrefix("--- ") {
                if currentLines.isEmpty {
                    currentLines = [line]
                } else {
                    currentLines.append(line)
                }
                if let headerPath = parseHeaderLine(line) {
                    fallbackFile = fallbackFile ?? headerPath
                }
                continue
            }

            if line.hasPrefix("+++ ") {
                if currentLines.isEmpty {
                    currentLines = [line]
                } else {
                    currentLines.append(line)
                }
                if let headerPath = parseHeaderLine(line) {
                    currentFile = headerPath
                }
                continue
            }

            if !currentLines.isEmpty {
                currentLines.append(line)
            }
        }

        if !currentLines.isEmpty {
            commitCurrent()
        }

        return targets
    }

    private func parseDiffGitLine(_ line: String) -> String? {
        let parts = line.split(separator: " ")
        guard parts.count >= 4 else { return nil }
        let rawPath = String(parts[3])
        let normalized = normalizePath(rawPath)
        return normalized == "/dev/null" ? nil : normalized
    }

    private func parseHeaderLine(_ line: String) -> String? {
        guard line.count > 4 else { return nil }
        let start = line.index(line.startIndex, offsetBy: 4)
        let tail = line[start...]
        let tabSplit = tail.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: true)
        let first = tabSplit.first ?? Substring(tail)
        let spaceSplit = first.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let rawPath = String(spaceSplit.first ?? first)
        let normalized = normalizePath(rawPath)
        return normalized == "/dev/null" ? nil : normalized
    }

    private func normalizePath(_ path: String) -> String {
        if path.hasPrefix("a/") || path.hasPrefix("b/") {
            return String(path.dropFirst(2))
        }
        if path.hasPrefix("./") {
            return String(path.dropFirst(2))
        }
        return path
    }

    private func isSafeRelativePath(_ path: String) -> Bool {
        if path.isEmpty { return false }
        if path.hasPrefix("/") || path.hasPrefix("~") { return false }
        let components = path.split(separator: "/")
        if components.contains("..") { return false }
        return true
    }

    private func verificationFailure(
        filePath: String,
        beforeHash: String,
        afterHash: String,
        message: String
    ) -> PatchVerificationResult {
        let issue = VerificationIssue(
            type: .conflictingChanges,
            location: filePath,
            severity: "high",
            description: message
        )
        return PatchVerificationResult(
            isValid: false,
            beforeHash: beforeHash,
            afterHash: afterHash,
            matchedLines: 0,
            failedLines: 0,
            partiallyApplied: false,
            issues: [issue],
            remediations: []
        )
    }

    private static func defaultDatabasePath() -> String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSHomeDirectory())

        let anigmaDir = appSupport.appendingPathComponent("Anigma")
        try? FileManager.default.createDirectory(at: anigmaDir, withIntermediateDirectories: true)

        return anigmaDir.appendingPathComponent("patches.sqlite").path
    }
}

private struct PatchTarget {
    let filePath: String
    let patchContent: String
}

private struct PatchFileVerification: Codable {
    let filePath: String
    let verification: PatchVerificationResult
}

private struct PatchFileSnapshot: Codable {
    let filePath: String
    let beforeHash: String
    let afterHash: String
    let sizeBytesBefore: Int
    let sizeBytesAfter: Int
    let existedBefore: Bool
    let existsAfter: Bool
}

private struct PatchRollbackSummary: Codable {
    let performed: Bool
    let restoredFiles: [String]
    let reason: String?
}

private struct ApplyPatchResult: Codable {
    let patchId: String
    let exitCode: Int
    let stdout: String
    let stderr: String
    let snapshots: [PatchFileSnapshot]
    let verifications: [PatchFileVerification]
    let rollback: PatchRollbackSummary?
    let validation: SwiftValidationResult?
    let patchDiagnosis: String?
    let error: String?
}

private struct FileSnapshot {
    let filePath: String
    let fullPath: String
    let existed: Bool
    let data: Data
    let content: String?
    let hash: String
    let sizeBytes: Int

    static func empty(filePath: String, repoRoot: String) -> FileSnapshot {
        let fullPath = URL(
            fileURLWithPath: filePath,
            relativeTo: URL(fileURLWithPath: repoRoot)
        ).path
        let emptyData = Data()
        return FileSnapshot(
            filePath: filePath,
            fullPath: fullPath,
            existed: false,
            data: emptyData,
            content: "",
            hash: ContentHashing.computeSHA256(emptyData),
            sizeBytes: 0
        )
    }
}

private enum PatchError: Error {
    case invalidEncoding(String)
}

extension PatchError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidEncoding(let filePath):
            return "Non-UTF8 content in \(filePath)"
        }
    }
}

private func detectPatchDiagnostic(stderr: String, exitCode: Int) -> String? {
    let normalized = stderr.lowercased()

    if normalized.contains("malformed patch") {
        return "Patch appears malformed; ensure the diff follows the standard unified format and includes context headers."
    }

    if normalized.contains("hunk") && normalized.contains("failed") {
        return "Patch hunks did not apply cleanly (the base files may have diverged). Refresh the touched files and try again."
    }

    if normalized.contains("failed at") || normalized.contains("offset") && normalized.contains("line") {
        return "Patch failed because the file contents changed after the patch was generated; update your workspace before rerunning."
    }

    if exitCode != 0 && normalized.isEmpty {
        return "Patch command exited with code \(exitCode) without stderr output."
    }

    return nil
}
