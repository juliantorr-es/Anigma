//
//  DevelopManager.swift
//  AnigmaAppMac
//
//  Handles develop mode operations, agent governance, and changeset management.
//  Extracted from AppStore.
//

import Foundation
import CryptoKit
import AnigmaClientKit
import AnigmaWork

@MainActor
final class DevelopManager {
    weak var store: AppStore?
    
    init(store: AppStore) {
        self.store = store
    }
    
    func applyChangeSet(_ changeSetId: UUID) async {
        guard let store = store,
              var changeSet = store.changeSets.first(where: { $0.id == changeSetId }),
              let workspace = store.repoWorkspaces.first(where: { $0.id == changeSet.workspaceId })
        else { return }

        changeSet.status = .applying
        if let index = store.changeSets.firstIndex(where: { $0.id == changeSetId }) {
            store.changeSets[index] = changeSet
        }

        store.showToast(title: "Applying Patch", subtitle: changeSet.title, icon: "arrow.down.doc")

        do {
            let git = GitService.shared

            // Apply each patch in the changeset
            for patch in changeSet.patches {
                try await git.applyPatch(diff: patch.diff, in: workspace.rootURL)
            }

            // Success - update status
            changeSet.status = .applied
            if let index = store.changeSets.firstIndex(where: { $0.id == changeSetId }) {
                store.changeSets[index] = changeSet
            }

            // Refresh workspace git state
            let updatedWorkspace = try await WorkspaceService.shared.refreshState(for: workspace)
            if let wsIndex = store.repoWorkspaces.firstIndex(where: { $0.id == workspace.id }) {
                store.repoWorkspaces[wsIndex] = updatedWorkspace
            }

            store.showToast(
                title: "Changes Applied",
                subtitle: "Git state updated",
                icon: "checkmark.circle.fill"
            )

        } catch {
            // Failure - mark as rejected or keep proposed
            changeSet.status = .rejected
            if let index = store.changeSets.firstIndex(where: { $0.id == changeSetId }) {
                store.changeSets[index] = changeSet
            }

            store.showToast(
                title: "Apply Failed",
                subtitle: error.localizedDescription,
                icon: "exclamationmark.triangle.fill"
            )
        }
    }

    func rejectChangeSet(_ changeSetId: UUID) async {
        guard let store = store,
              var changeSet = store.changeSets.first(where: { $0.id == changeSetId }) else { return }

        changeSet.status = .rejected
        if let index = store.changeSets.firstIndex(where: { $0.id == changeSetId }) {
            store.changeSets[index] = changeSet
        }

        store.showToast(title: "Change Rejected", subtitle: changeSet.title, icon: "xmark.circle.fill")
    }

    func runCheckProfile(name: String) async {
        guard let store = store else { return }
        store.showToast(title: "Check Started", subtitle: name, icon: "play.fill")
        await store.submitJob(action: "test", parameters: ["profile": .string(name)])
    }

    // MARK: - Agent Governance

    /// Known agent configurations for discovery
    private static let knownAgents: [(binary: String, id: String, display: String, caps: [AgentCapability])] = [
        ("gemini", "gemini-cli", "Gemini CLI", [.analyze, .patch]),
        ("claude", "claude-code", "Claude Code", [.analyze, .patch, .check]),
        ("aider", "aider", "Aider", [.analyze, .patch]),
        ("copilot", "github-copilot", "GitHub Copilot CLI", [.analyze])
    ]

    func discoverAgentProviders() async {
        guard let store = store else { return }
        var discovered: [AgentProvider] = []

        // Search paths: common install locations + PATH
        let searchPaths = buildSearchPaths()

        for agent in Self.knownAgents {
            if let binaryPath = findBinary(named: agent.binary, in: searchPaths) {
                let version = await extractVersion(from: binaryPath)

                discovered.append(AgentProvider(
                    id: agent.id,
                    displayName: agent.display,
                    binaryPath: binaryPath,
                    version: version,
                    capabilities: agent.caps,
                    trustRecord: nil,
                    isEnabled: false
                ))
            }
        }

        store.agentProviders = discovered
    }

    private func buildSearchPaths() -> [String] {
        var paths: [String] = [
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "\(NSHomeDirectory())/.local/bin",
            "\(NSHomeDirectory())/.cargo/bin"
        ]

        // Add PATH directories
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            paths.append(contentsOf: pathEnv.split(separator: ":").map(String.init))
        }

        return paths
    }

    private func findBinary(named name: String, in paths: [String]) -> String? {
        let fm = FileManager.default
        for dir in paths {
            let fullPath = "\(dir)/\(name)"
            if fm.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }
        return nil
    }

    private func extractVersion(from binaryPath: String) async -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["--version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Extract version number
                let pattern = #"(?:v|version\s*)?(\d+\.\d+(?:\.\d+)?)"#
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
                   let range = Range(match.range(at: 1), in: output) {
                    return String(output[range])
                }
            }
        } catch {
            print("Failed to extract version from \(binaryPath): \(error)")
        }
        return nil
    }

    func enableAgentProvider(_ providerId: String) async {
        guard let store = store,
              let index = store.agentProviders.firstIndex(where: { $0.id == providerId }) else { return }
        var provider = store.agentProviders[index]

        // Compute actual binary fingerprint
        let binaryHash = await computeBinaryHash(at: provider.binaryPath)
        let signingIdentity = await extractSigningIdentity(at: provider.binaryPath)

        provider.trustRecord = ToolTrustRecord(
            binaryHash: binaryHash,
            signingIdentity: signingIdentity,
            approvedAt: Date(),
            approvedBy: store.session.currentUserId ?? "local-user"
        )
        provider.isEnabled = true
        store.agentProviders[index] = provider

        store.showToast(title: "Tool Trusted", subtitle: "\(provider.displayName) fingerprinted and enabled.", icon: "checkmark.shield.fill")
    }

    private func computeBinaryHash(at path: String) async -> String {
        guard let data = FileManager.default.contents(atPath: path) else {
            return "sha256:unknown"
        }

        // Compute SHA-256 hash using CryptoKit
        let digest = SHA256.hash(data: data)
        let hashString = digest.compactMap { String(format: "%02x", $0) }.joined()
        return "sha256:\(hashString.prefix(16))"
    }

    private func extractSigningIdentity(at path: String) async -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-dv", path]

        let pipe = Pipe()
        process.standardError = pipe // codesign outputs to stderr
        process.standardOutput = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Look for "Authority=" line
                for line in output.split(separator: "\n") {
                    if line.hasPrefix("Authority=") {
                        return String(line.dropFirst("Authority=".count))
                    }
                }
            }
        } catch {
            print("Failed to extract signing identity: \(error)")
        }
        return nil
    }

    func runAgent(id: String, instruction: String) async {
        guard let store = store else { return }
        
        guard let workspaceId = store.activeWorkspaceID else {
            store.showToast(title: "No Workspace", subtitle: "Select a workspace first.", icon: "exclamationmark.triangle")
            return
        }

        do {
            _ = try await store.agentOrchestrator.execute(agentId: id, instruction: instruction, workspaceId: workspaceId, workingDirectory: store.activeWorkspace?.sandboxURL ?? store.activeWorkspace?.rootURL)
            store.showToast(title: "Agent Enqueued", subtitle: "Running in background.", icon: "paperplane.fill")
        } catch {
            store.showToast(title: "Agent Failed", subtitle: error.localizedDescription, icon: "xmark.circle")
        }
    }
}
