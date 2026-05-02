//
//  JobManager.swift
//  AnigmaAppMac
//
//  Handles job submission, management, and simulation.
//  Extracted from AppStore.
//

import Foundation
import AnigmaClientKit
import AnigmaWork
import ContractsCore

enum SourceIngestionPathResolver {
    static func resolve(_ rawPath: String) -> URL? {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.isFileURL {
            return url.standardizedFileURL
        }

        if trimmed.contains("://") {
            return nil
        }

        let expanded = (trimmed as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded).standardizedFileURL
    }
}

@MainActor
final class JobManager {
    weak var store: AppStore?
    
    init(store: AppStore) {
        self.store = store
    }
    
    func submitJob(action: String, parameters: [String: BindingValue]) async {
        guard let store = store, let client = store.client else {
            print("Cannot submit job: client not initialized")
            return
        }

        // Intercept Agent Jobs (Phase 2)
        if action == "agent-refactor", let workspace = store.activeWorkspace {
            guard case let .string(profileIdStr)? = parameters["profile"],
                  let profileId = UUID(uuidString: profileIdStr),
                  let profile = store.agentProfiles.first(where: { $0.id == profileId })
            else {
                store.showToast(title: "Agent Error", subtitle: "Invalid profile", icon: "exclamationmark.triangle")
                return
            }

            let providerLabel = profile.binaryPath
                .map { URL(fileURLWithPath: $0).lastPathComponent }
                ?? store.agentProviders.first { $0.id == profile.providerId }?.displayName
                ?? profile.providerId
            store.showToast(title: "Agent Running", subtitle: "Executing \(providerLabel)...", icon: "brain")

            let runner = CLIAgentRunner()
            let instruction: String
            if case let .string(instr) = parameters["instruction"] {
                instruction = instr
            } else {
                instruction = "Refactor code"
            }

            do {
                // Clear previous logs
                self.store?.consoleLogs.removeAll()
                self.store?.consoleLogs.append(ConsoleEntry(timestamp: Date(), message: "Starting agent execution...", level: .info))

                var fullOutput = ""
                for try await line in try await runner.execute(profile: profile, instruction: instruction, context: workspace) {
                    self.store?.consoleLogs.append(ConsoleEntry(timestamp: Date(), message: line, level: .info))
                    fullOutput += line + "\n"
                }

                // Parse Diff
                let parser = ChangesetParser.shared
                let parsed = await parser.parseAgentResponse(fullOutput)

                if let diff = parsed.diff {
                    let changeSet = try await parser.parse(
                        diff: diff,
                        workspaceId: workspace.id,
                        authorId: profile.id,
                        jobDescription: instruction
                    )

                    self.store?.changeSets.append(changeSet)
                    self.store?.developWorkbenchTab = .review
                    self.store?.userSurface = .developChanges

                    store.showToast(title: "Changes Proposed", subtitle: "Review diff under 'Changes'", icon: "doc.text.magnifyingglass")
                } else {
                    store.showToast(title: "Agent Finished", subtitle: "No changes produced", icon: "checkmark.circle")
                }

            } catch {
                store.showToast(title: "Agent Failed", subtitle: error.localizedDescription, icon: "xmark.circle")
            }

            return
        }

        // --- General Intent Implementation ---
        let jobId = UUID()
        let jobTitle = action.uppercased().replacingOccurrences(of: "_", with: " ")
        let initialJob = AnigmaJob(
            id: jobId,
            title: jobTitle,
            message: "Initializing...",
            contextId: AppState.shared.currentContext?.id,
            status: .running,
            progress: 0.1,
            startedAt: Date()
        )
        store.localJobs.append(initialJob)

        store.showToast(
            title: "\(action.uppercased()) started",
            subtitle: "The engine is processing your request.",
            icon: "gearshape.fill"
        )

        Task {
            if action == "source_ingest" {
                let name: String
                if case let .string(n) = parameters["name"] {
                    name = n
                } else {
                    name = "Source"
                }
                
                var path: String?
                if case let .string(p) = parameters["path"] {
                    path = p
                }
                
                guard let path,
                      let url = SourceIngestionPathResolver.resolve(path) else {
                    await MainActor.run {
                        if let index = store.localJobs.firstIndex(where: { $0.id == jobId }) {
                            store.localJobs[index].status = .failed
                            store.localJobs[index].progress = 1.0
                            store.localJobs[index].completedAt = Date()
                            store.localJobs[index].message = "Missing or invalid local file path"
                        }
                        store.showError("Source ingest failed: missing or invalid local file path for \(name)")
                    }
                    return
                }

                store.intakeManager.handleIntake(url: url)
                // The job is now managed by IntakeManager.
                if let index = store.localJobs.firstIndex(where: { $0.id == jobId }) {
                    store.localJobs.remove(at: index)
                }
            } else if action == "web-capture" {
                var html: String?
                var title: String?
                
                if case let .string(h) = parameters["html"] { html = h }
                if case let .string(t) = parameters["title"] { title = t }
                
                guard let html = html,
                      let title = title
                else { return }

                await runSimulatedJob(id: jobId, stages: [
                    (0.2, "Parsing DOM structure..."),
                    (0.5, "Extracting semantics..."),
                    (0.8, "Persisting graph nodes...")
                ])

                // Skip WebContentExtractor for now - just save the HTML
                if let data = html.data(using: .utf8) {
                    await store.uploadArtifact(name: "\(title).html", data: data)
                }
            } else if action == "ocr" {
                await runSimulatedJob(id: jobId, stages: [
                    (0.3, "Extracting pixel data..."),
                    (0.6, "Applying OCR engine (Vision)..."),
                    (0.9, "Generating searchable layer...")
                ])
            } else if action == "translate" {
                await runSimulatedJob(id: jobId, stages: [
                    (0.4, "Mapping semantic structure..."),
                    (0.8, "Translating tokens...")
                ])
            } else if action == "summarize" {
                await runSimulatedJob(id: jobId, stages: [
                    (0.5, "Condensing information..."),
                    (0.8, "Formulating brief...")
                ])
            } else if action == "extract_deadlines" {
                await runSimulatedJob(id: jobId, stages: [
                    (0.4, "Scanning artifacts for date entities..."),
                    (0.7, "Validating temporal context...")
                ])
            } else if action == "verify_claims" {
                await runSimulatedJob(id: jobId, stages: [
                    (0.3, "Searching evidence ledger..."),
                    (0.6, "Applying consistency checks..."),
                    (0.9, "Calculating confidence score...")
                ])
            } else if action == "generate_response" {
                await runSimulatedJob(id: jobId, stages: [
                    (0.4, "Synthesizing research notes..."),
                    (0.8, "Formulating final report...")
                ])
            } else {
                // Default: Hand off to daemon
                _ = await client.submitIntent(action: action, parameters: parameters)

                // Artificial delay to feel "real" if it was too fast
                try? await Task.sleep(nanoseconds: 500_000_000)

                await MainActor.run {
                    if let index = store.localJobs.firstIndex(where: { $0.id == jobId }) {
                        store.localJobs[index].status = .completed
                        store.localJobs[index].progress = 1.0
                        store.localJobs[index].completedAt = Date()
                        store.localJobs[index].message = "Executed by Authority"
                    }
                }
            }
        }

        // Refresh jobs list
        if let workspaceId = store.selectedWorkspaceID {
          await store.selectWorkspace(workspaceId)
        }
    }

    func runSimulatedJob(id: UUID, stages: [(Double, String)]) async {
        guard let store = store else { return }
        
        for (prog, msg) in stages {
            await MainActor.run {
                store.updateJob(id: id, progress: prog, message: msg)
            }
            // Random delay between 0.5s and 1.5s
            let delay = UInt64.random(in: 500_000_000...1_500_000_000)
            try? await Task.sleep(nanoseconds: delay)
        }

        await MainActor.run {
            if let index = store.localJobs.firstIndex(where: { $0.id == id }) {
                store.localJobs[index].status = .completed
                store.localJobs[index].progress = 1.0
                store.localJobs[index].completedAt = Date()
                store.localJobs[index].message = "Operation Complete"
            }
        }
    }

    func cancelJob(id: JobID) async {
        guard let store = store, let client = store.client else { return }

        do {
            try await client.command.cancelJob(id: id)
        } catch {
            print("Error cancelling job: \(error)")
        }
    }

    func deleteJob(id: JobID) async {
        guard let store = store, let client = store.client else { return }

        do {
            try await client.command.deleteJob(id: id)
            if let workspaceId = store.selectedWorkspaceID {
                await store.workspaceStore.selectWorkspace(workspaceId)
            }
        } catch {
            print("Error deleting job: \(error)")
        }
    }

    func verifyJob(id: JobID) async {
        guard let store = store, let client = store.client else { return }

        do {
            try await client.command.verifyJob(id: id)
        } catch {
            print("Error verifying job: \(error)")
        }
    }
}
