//
//  SandboxedOrchestrator.swift
//  AnigmaAppMac
//
//  Orchestrates parallel agent execution in isolated sandboxes with governed merge resolution.
//

import Foundation
import AnigmaClientKit
import CryptoKit
import AnigmaHostMac
import MLWorkerCommon
import ContractsCore

// MARK: - Sandbox Manager

/// Manages isolated git worktree sandboxes for parallel agent execution
@MainActor
final class WorktreeSandboxManager {

    struct Sandbox: Identifiable {
        let id: UUID
        let agentName: String
        let workTreePath: URL
        let branchName: String
        let createdAt: Date
        var status: SandboxStatus
        var filesModified: Set<String>
        var commitHash: String?
    }

    enum SandboxStatus {
        case preparing
        case ready
        case executing
        case completed
        case failed(Error)
        case merging
        case merged
    }

    private var activeSandboxes: [UUID: Sandbox] = [:]
    private let fileManager = FileManager.default

    /// Create an isolated sandbox for an agent using git worktree
    func createSandbox(
        for agentName: String,
        from workspace: RepoWorkspace
    ) async throws -> Sandbox {
        let sandboxId = UUID()
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let branchName = "anigma/sandbox/\(agentName)/\(timestamp)"

        // Create temporary directory for worktree
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("anigma-sandboxes")
            .appendingPathComponent(sandboxId.uuidString)

        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create git worktree
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = [
            "worktree", "add",
            "-b", branchName,
            tempDir.path,
            "HEAD"
        ]
        process.currentDirectoryURL = workspace.rootURL

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw SandboxError.creationFailed(errorMsg)
        }

        let sandbox = Sandbox(
            id: sandboxId,
            agentName: agentName,
            workTreePath: tempDir,
            branchName: branchName,
            createdAt: Date(),
            status: .ready,
            filesModified: [],
            commitHash: nil
        )

        activeSandboxes[sandboxId] = sandbox
        return sandbox
    }

    /// Track file modifications in a sandbox
    func trackModifications(in sandboxId: UUID) async throws -> Set<String> {
        guard var sandbox = activeSandboxes[sandboxId] else {
            throw SandboxError.notFound
        }

        // Get git status to find modified files
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["status", "--porcelain"]
        process.currentDirectoryURL = sandbox.workTreePath

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""

        var modifiedFiles = Set<String>()
        for line in output.split(separator: "\n") {
            // Parse git status format: "XY filename"
            let parts = line.split(separator: " ", maxSplits: 1)
            if parts.count == 2 {
                modifiedFiles.insert(String(parts[1]))
            }
        }

        sandbox.filesModified = modifiedFiles
        activeSandboxes[sandboxId] = sandbox

        return modifiedFiles
    }

    /// Commit changes in a sandbox
    func commitChanges(in sandboxId: UUID, message: String) async throws -> String {
        guard var sandbox = activeSandboxes[sandboxId] else {
            throw SandboxError.notFound
        }

        // Stage all changes
        let addProcess = Process()
        addProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        addProcess.arguments = ["add", "-A"]
        addProcess.currentDirectoryURL = sandbox.workTreePath
        try addProcess.run()
        addProcess.waitUntilExit()

        // Commit
        let commitProcess = Process()
        commitProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        commitProcess.arguments = ["commit", "-m", message]
        commitProcess.currentDirectoryURL = sandbox.workTreePath

        let outputPipe = Pipe()
        commitProcess.standardOutput = outputPipe

        try commitProcess.run()
        commitProcess.waitUntilExit()

        // Get commit hash
        let hashProcess = Process()
        hashProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        hashProcess.arguments = ["rev-parse", "HEAD"]
        hashProcess.currentDirectoryURL = sandbox.workTreePath

        let hashPipe = Pipe()
        hashProcess.standardOutput = hashPipe

        try hashProcess.run()
        hashProcess.waitUntilExit()

        let hashData = hashPipe.fileHandleForReading.readDataToEndOfFile()
        let commitHash = String(data: hashData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        sandbox.commitHash = commitHash
        activeSandboxes[sandboxId] = sandbox

        return commitHash
    }

    /// Clean up a sandbox and remove worktree
    func cleanupSandbox(_ sandboxId: UUID, workspace: RepoWorkspace) async throws {
        guard let sandbox = activeSandboxes[sandboxId] else { return }

        // Remove git worktree
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["worktree", "remove", "--force", sandbox.workTreePath.path]
        process.currentDirectoryURL = workspace.rootURL

        try? process.run()
        process.waitUntilExit()

        // Delete branch if not merged
        let branchProcess = Process()
        branchProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        branchProcess.arguments = ["branch", "-D", sandbox.branchName]
        branchProcess.currentDirectoryURL = workspace.rootURL

        try? branchProcess.run()
        branchProcess.waitUntilExit()

        // Remove temp directory
        try? fileManager.removeItem(at: sandbox.workTreePath)

        activeSandboxes.removeValue(forKey: sandboxId)
    }

    func getSandbox(_ id: UUID) -> Sandbox? {
        activeSandboxes[id]
    }

    func updateStatus(_ id: UUID, status: SandboxStatus) {
        activeSandboxes[id]?.status = status
    }
}

// MARK: - Conflict Resolution Engine

/// Resolves conflicts between parallel agent changes using local LLM
@MainActor
final class ConflictResolver {

    struct ConflictAnalysis {
        let file: String
        let conflictMarkers: [ConflictMarker]
        let sandboxSources: [UUID: String] // sandbox -> version
        let recommendation: Resolution
        let reasoning: String
    }

    struct ConflictMarker {
        let startLine: Int
        let endLine: Int
        let branches: [String]
        let content: [String: String] // branch -> content
    }

    enum Resolution {
        case acceptLeft
        case acceptRight
        case merge(String) // Custom merged content
        case manual // Requires human intervention
    }

    /// Analyze conflicts between sandbox changes
    func analyzeConflicts(
        file: String,
        sandboxes: [WorktreeSandboxManager.Sandbox]
    ) async throws -> ConflictAnalysis {
        // Read file content from each sandbox
        var versions: [UUID: String] = [:]

        for sandbox in sandboxes {
            let filePath = sandbox.workTreePath.appendingPathComponent(file)
            if FileManager.default.fileExists(atPath: filePath.path) {
                let content = try String(contentsOf: filePath, encoding: .utf8)
                versions[sandbox.id] = content
            }
        }

        // Detect if versions differ
        let uniqueVersions = Set(versions.values)
        if uniqueVersions.count == 1 {
            // No conflict - all agents produced same result
            return ConflictAnalysis(
                file: file,
                conflictMarkers: [],
                sandboxSources: versions,
                recommendation: .acceptLeft, // Doesn't matter, they're identical
                reasoning: "All agents produced identical changes"
            )
        }

        // Use local LLM to resolve semantic conflicts
        return try await resolveWithLLM(file: file, versions: versions, sandboxes: sandboxes)
    }

    private func resolveWithLLM(
        file: String,
        versions: [UUID: String],
        sandboxes: [WorktreeSandboxManager.Sandbox]
    ) async throws -> ConflictAnalysis {

        let client = MLWorkerClient()

        // Build prompt for LLM
        let versionsText = versions.map { sandboxId, content in
            let sandbox = sandboxes.first { $0.id == sandboxId }
            let agentName = sandbox?.agentName ?? "unknown"
            return """
            **Version from \(agentName) (sandbox \(sandboxId.uuidString.prefix(8))):**
            ```
            \(content)
            ```
            """
        }.joined(separator: "\n\n")

        let prompt = """
        You are a code conflict resolution expert. Multiple AI agents have modified the same file in parallel.
        Your job is to determine the best resolution strategy.

        File: \(file)

        \(versionsText)

        Analyze these versions and respond with JSON:
        {
            "recommendation": "accept_left" | "accept_right" | "merge" | "manual",
            "reasoning": "Explanation of why this is the best choice",
            "mergedContent": "If recommendation is 'merge', provide the merged result"
        }

        Criteria for decision:
        1. **Correctness**: Does one version have bugs or errors?
        2. **Completeness**: Does one version implement more of the requirements?
        3. **Code quality**: Better structure, naming, documentation?
        4. **Compatibility**: Which maintains better API compatibility?
        5. **Safety**: Which has better error handling or validation?

        If versions are semantically equivalent but stylistically different, prefer the left version.
        If they implement different valid approaches, recommend manual review.
        If you can create a superior merge combining best parts, provide merged content.
        """

        let promptHash = prompt.sha256Hash()
        let promptArtifact = ContractsCore.MLArtifactRef(
            path: "",
            hash: promptHash
        )

        let workerInputs = [MLWorkerCommon.MLArtifactRef(path: "", hash: promptHash)]

        let response = try await client.runTask(
            engine: "mlx",
            task: .chat,
            inputs: workerInputs,
            options: MLTaskOptions(
                seed: 42,
                maxTokens: 2048,
                temperature: 0.1,
                topP: 1.0,
                outputDirectory: nil
            )
        )

        guard let firstOutput = response.outputs.first else {
            throw ConflictError.resolutionFailed
        }

        let outputText = try String(contentsOfFile: firstOutput.path, encoding: String.Encoding.utf8)

        // Parse LLM response
        if let jsonData = outputText.data(using: String.Encoding.utf8) {
            let decoder = JSONDecoder()
            let resolution = try decoder.decode(ResolutionResponse.self, from: jsonData)

            let recommendedAction: Resolution
            switch resolution.recommendation {
            case "accept_left":
                recommendedAction = .acceptLeft
            case "accept_right":
                recommendedAction = .acceptRight
            case "merge":
                recommendedAction = .merge(resolution.mergedContent ?? "")
            case "manual":
                recommendedAction = .manual
            default:
                recommendedAction = .manual
            }

            return ConflictAnalysis(
                file: file,
                conflictMarkers: [],
                sandboxSources: versions,
                recommendation: recommendedAction,
                reasoning: resolution.reasoning
            )
        } else {
            throw ConflictError.resolutionFailed
        }
    }

    private struct ResolutionResponse: Codable {
        let recommendation: String
        let reasoning: String
        let mergedContent: String?
    }
}

// MARK: - Parallel Orchestrator

/// Orchestrates parallel agent execution with governed merge
@Observable
@MainActor
final class ParallelOrchestrator {

    struct ParallelPlan {
        let taskDescription: String
        let parallelTracks: [Track]
        let reasoning: String

        struct Track: Identifiable {
            let id: UUID
            let agent: CLIToolRegistry.Tool
            let subtask: String
            let expectedFiles: [String]
            var sandbox: WorktreeSandboxManager.Sandbox?
            var status: TrackStatus

            enum TrackStatus {
                case pending
                case sandboxing
                case executing
                case committing
                case completed
                case failed(Error)
            }
        }
    }

    var messages: [OrchestratorMessage] = []
    var currentPlan: ParallelPlan?
    var isProcessing: Bool = false

    private let sandboxManager = WorktreeSandboxManager()
    private let conflictResolver = ConflictResolver()
    private let cliRunner = CLIAgentRunner()

    /// Submit a task for parallel orchestration
    func submitParallelTask(_ task: String, workspace: RepoWorkspace) async {
        guard !isProcessing else { return }

        isProcessing = true
        addMessage(.user, task)

        do {
            // Step 1: Decompose into parallel subtasks
            addMessage(.orchestrator, "🧠 Decomposing task into parallel subtasks...")
            let plan = try await generateParallelPlan(for: task)
            currentPlan = plan

            addMessage(.orchestrator, """
            📋 **Parallel Execution Plan**

            \(plan.reasoning)

            **Parallel Tracks:**
            \(plan.parallelTracks.enumerated().map { i, track in
                "Track \(i + 1): [\(track.agent.displayName)] \(track.subtask)"
            }.joined(separator: "\n"))
            """)

            // Step 2: Create isolated sandboxes
            addMessage(.orchestrator, "🏗️ Creating isolated sandboxes for each agent...")
            var tracks = plan.parallelTracks

            for i in 0..<tracks.count {
                let sandbox = try await sandboxManager.createSandbox(
                    for: tracks[i].agent.rawValue,
                    from: workspace
                )
                tracks[i].sandbox = sandbox
                tracks[i].status = .sandboxing
            }

            addMessage(.orchestrator, "✅ All sandboxes ready. Executing agents in parallel...")

            // Step 3: Execute agents in parallel
            await withTaskGroup(of: (Int, Result<Void, Error>).self) { group in
                for (index, track) in tracks.enumerated() {
                    group.addTask {
                        do {
                            try await self.executeInSandbox(track: track, trackIndex: index, workspace: workspace)
                            return (index, .success(()))
                        } catch {
                            return (index, .failure(error))
                        }
                    }
                }

                for await (index, result) in group {
                    switch result {
                    case .success:
                        tracks[index].status = .completed
                        addMessage(.orchestrator, "✅ Track \(index + 1) completed")
                    case .failure(let error):
                        tracks[index].status = .failed(error)
                        addMessage(.orchestrator, "❌ Track \(index + 1) failed: \(error.localizedDescription)")
                    }
                }
            }

            // Step 4: Analyze and merge results
            addMessage(.orchestrator, "🔍 Analyzing changes and detecting conflicts...")
            try await mergeResults(tracks: tracks, workspace: workspace)

            addMessage(.orchestrator, "✅ Parallel execution and merge completed successfully")

        } catch {
            addMessage(.orchestrator, "❌ Parallel orchestration failed: \(error.localizedDescription)")
        }

        isProcessing = false
    }

    private func executeInSandbox(
        track: ParallelPlan.Track,
        trackIndex: Int,
        workspace: RepoWorkspace
    ) async throws {
        guard let sandbox = track.sandbox else {
            throw OrchestratorError.toolNotAvailable("Sandbox not created")
        }

        // Execute agent in sandbox workspace
        let process = Process()

        // Find agent binary (reuse discovery from LocalLLMOrchestrator)
        let availability = CLIToolRegistry.discoverAvailableTools()
            .first { $0.tool == track.agent && $0.isInstalled }

        guard let binaryPath = availability?.binaryPath else {
            throw OrchestratorError.toolNotAvailable(track.agent.displayName)
        }

        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = [track.subtask]
        process.currentDirectoryURL = sandbox.workTreePath

        var env = ProcessInfo.processInfo.environment
        env["ANIGMA_SANDBOX"] = sandbox.id.uuidString
        env["ANIGMA_TRACK"] = "\(trackIndex)"
        process.environment = env

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw OrchestratorError.toolFailed(track.agent.displayName, process.terminationStatus)
        }

        // Track modifications
        let modifiedFiles = try await sandboxManager.trackModifications(in: sandbox.id)
        addMessage(.tool, "Modified \(modifiedFiles.count) files: \(modifiedFiles.joined(separator: ", "))")

        // Commit changes
        let commitMessage = "Anigma track \(trackIndex): \(track.subtask)"
        let commitHash = try await sandboxManager.commitChanges(in: sandbox.id, message: commitMessage)
        addMessage(.tool, "Committed as \(commitHash.prefix(8))")
    }

    private func mergeResults(tracks: [ParallelPlan.Track], workspace: RepoWorkspace) async throws {
        // Collect all modified files across sandboxes
        var allModifiedFiles = Set<String>()
        for track in tracks {
            if let sandbox = track.sandbox {
                allModifiedFiles.formUnion(sandbox.filesModified)
            }
        }

        addMessage(.orchestrator, "📊 Total files modified: \(allModifiedFiles.count)")

        // For each file, check if multiple sandboxes modified it
        var conflicts: [String: ConflictResolver.ConflictAnalysis] = [:]

        for file in allModifiedFiles {
            let sandboxesWithFile = tracks.compactMap { $0.sandbox }.filter { $0.filesModified.contains(file) }

            if sandboxesWithFile.count > 1 {
                addMessage(.orchestrator, "⚠️ Conflict detected in \(file) (modified by \(sandboxesWithFile.count) agents)")

                let analysis = try await conflictResolver.analyzeConflicts(
                    file: file,
                    sandboxes: sandboxesWithFile
                )
                conflicts[file] = analysis

                addMessage(.orchestrator, """
                **Resolution for \(file):**
                \(analysis.reasoning)
                Action: \(analysis.recommendation)
                """)
            }
        }

        // Apply resolutions and merge to main workspace
        for (file, analysis) in conflicts {
            try await applyResolution(file: file, analysis: analysis, workspace: workspace)
        }

        // Merge non-conflicting changes
        for track in tracks {
            guard let sandbox = track.sandbox else { continue }

            for file in sandbox.filesModified where conflicts[file] == nil {
                // No conflict - safe to merge
                try await copyFileToMain(
                    file: file,
                    from: sandbox.workTreePath,
                    to: workspace.rootURL
                )
            }
        }

        // Cleanup sandboxes
        for track in tracks {
            if let sandbox = track.sandbox {
                try await sandboxManager.cleanupSandbox(sandbox.id, workspace: workspace)
            }
        }
    }

    private func applyResolution(
        file: String,
        analysis: ConflictResolver.ConflictAnalysis,
        workspace: RepoWorkspace
    ) async throws {
        let targetPath = workspace.rootURL.appendingPathComponent(file)

        switch analysis.recommendation {
        case .acceptLeft:
            // Take first sandbox's version
            if let firstSandbox = analysis.sandboxSources.keys.first,
               let content = analysis.sandboxSources[firstSandbox] {
                try content.write(to: targetPath, atomically: true, encoding: .utf8)
            }

        case .acceptRight:
            // Take last sandbox's version
            if let lastSandbox = Array(analysis.sandboxSources.keys).last,
               let content = analysis.sandboxSources[lastSandbox] {
                try content.write(to: targetPath, atomically: true, encoding: .utf8)
            }

        case .merge(let mergedContent):
            // Use LLM-generated merge
            try mergedContent.write(to: targetPath, atomically: true, encoding: .utf8)

        case .manual:
            addMessage(.system, "⚠️ Manual resolution required for \(file) - creating conflict markers")
            // Create conflict markers for human review
            var conflictFile = "<<<<<<< CONFLICT\n"
            for (sandboxId, content) in analysis.sandboxSources {
                conflictFile += "=== Sandbox \(sandboxId.uuidString.prefix(8)) ===\n"
                conflictFile += content
                conflictFile += "\n"
            }
            conflictFile += ">>>>>>> END CONFLICT\n"
            try conflictFile.write(to: targetPath, atomically: true, encoding: .utf8)
        }
    }

    private func copyFileToMain(file: String, from: URL, to: URL) async throws {
        let sourcePath = from.appendingPathComponent(file)
        let destPath = to.appendingPathComponent(file)

        // Create parent directories if needed
        let destDir = destPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        // Copy file
        if FileManager.default.fileExists(atPath: destPath.path) {
            try FileManager.default.removeItem(at: destPath)
        }
        try FileManager.default.copyItem(at: sourcePath, to: destPath)
    }

    private func generateParallelPlan(for task: String) async throws -> ParallelPlan {
        _ = MLWorkerClient()

        _ = """
        You are a task decomposition expert. Break down this coding task into independent parallel subtasks
        that can be executed by different AI agents simultaneously.

        Task: \(task)

        Respond with JSON:
        {
            "taskDescription": "...",
            "reasoning": "Why this decomposition makes sense",
            "parallelTracks": [
                {
                    "agent": "codex|claude|gh-copilot|gemini",
                    "subtask": "Specific subtask for this agent",
                    "expectedFiles": ["file1.swift", "file2.swift"]
                }
            ]
        }

        Guidelines:
        - Minimize file overlap between tracks to reduce conflicts
        - Assign agents based on their strengths
        - Keep subtasks focused and independent
        - If task can't be parallelized, create a single track
        """

        // Similar LLM call as in LocalLLMOrchestrator
        // Simplified for brevity - reuse the same pattern

        // For now, return a mock plan
        return ParallelPlan(
            taskDescription: task,
            parallelTracks: [],
            reasoning: "Task decomposition not yet implemented"
        )
    }

    private func addMessage(_ role: OrchestratorMessage.Role, _ content: String) {
        messages.append(OrchestratorMessage(role: role, content: content))
    }
}

// MARK: - Errors

enum SandboxError: LocalizedError {
    case creationFailed(String)
    case notFound

    var errorDescription: String? {
        switch self {
        case .creationFailed(let msg):
            return "Sandbox creation failed: \(msg)"
        case .notFound:
            return "Sandbox not found"
        }
    }
}

enum ConflictError: LocalizedError {
    case resolutionFailed

    var errorDescription: String? {
        "Conflict resolution failed"
    }
}
