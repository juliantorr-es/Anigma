//
//  DevelopState.swift
//  AnigmaAppMac
//
//  State container for the Develop surface.
//

import Foundation
import Observation

enum RepoNavigatorMode: String, CaseIterable, Identifiable {
    case files = "Files"
    case search = "Search"
    case changes = "Changes"
    case runs = "Runs"
    case review = "Review"
    case tasks = "Tasks"
    case agents = "Agents"

    var id: String { rawValue }
}

struct RepoFileNode: Identifiable, Hashable {
    let id: URL
    let url: URL
    let name: String
    let isDirectory: Bool
    let children: [RepoFileNode]?
}

struct RepoSearchResult: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let lineNumber: Int
    let preview: String
}

struct RepoChange: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let status: String
}

struct RepoTaskItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let lineNumber: Int
    let label: String
}

@MainActor
@Observable
final class DevelopState {
    var repoURL: URL?
    var repoBookmarkData: Data?
    var fileTree: [RepoFileNode] = []
    var selectedFileURL: URL?
    var navigatorMode: RepoNavigatorMode = .files
    var searchQuery: String = ""
    var searchResults: [RepoSearchResult] = []
    var changeSet: [RepoChange] = []
    var taskItems: [RepoTaskItem] = []
    var jobs: [DaemonJob] = []
    var agentInstruction: String = "Refactor this file for clarity and performance."
    var lastJobError: String?
    var isLoadingFiles = false
    var isSearching = false
    var isLoadingChanges = false
    var isLoadingTasks = false
    var isLoadingJobs = false

    let artifactService = DevelopumArtifactService()
    let jobClient = DaemonJobClient()

    private let bookmarkKey = "anigma.develop.repoBookmark"
    private var hasSecurityScopedAccess = false

    init() {
        restoreRepositoryFromBookmark()
    }

    func openRepository(url: URL) {
        stopAccessingRepo()
        repoURL = url
        selectedFileURL = nil
        storeBookmark(for: url)
        startAccessingRepo()
        refreshFileTree()
        Task {
            await refreshChanges()
            await refreshTasks()
        }
    }

    func refreshFileTree() {
        guard let repoURL else {
            fileTree = []
            return
        }

        isLoadingFiles = true
        let tree = buildFileTree(at: repoURL)
        fileTree = tree
        isLoadingFiles = false
    }

    func runSearch() async {
        guard repoURL != nil else {
            searchResults = []
            return
        }
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        let files = collectFileURLs(from: fileTree)
        let results = await Task.detached(priority: .userInitiated) { () -> [RepoSearchResult] in
            var matches: [RepoSearchResult] = []
            for fileURL in files {
                guard let match = searchFile(url: fileURL, query: query) else { continue }
                matches.append(match)
            }
            return matches
        }.value

        searchResults = results
        isSearching = false
    }

    func refreshChanges() async {
        guard let repoURL else {
            changeSet = []
            return
        }

        isLoadingChanges = true
        let output = runGitCommand(arguments: ["status", "--porcelain=1"], repoURL: repoURL) ?? ""
        let lines = output.split(separator: "\n")
        changeSet = lines.map { line in
            let status = line.prefix(2).trimmingCharacters(in: .whitespaces)
            let path = line.dropFirst(3)
            return RepoChange(path: String(path), status: status)
        }
        isLoadingChanges = false
    }

    func refreshTasks() async {
        guard repoURL != nil else {
            taskItems = []
            return
        }

        isLoadingTasks = true
        let files = collectFileURLs(from: fileTree)
        let tasks = await Task.detached(priority: .utility) { () -> [RepoTaskItem] in
            var items: [RepoTaskItem] = []
            for fileURL in files {
                let found = findTasks(in: fileURL)
                items.append(contentsOf: found)
            }
            return items
        }.value

        taskItems = tasks
        isLoadingTasks = false
    }

    func refreshJobs() async {
        isLoadingJobs = true
        do {
            jobs = try await jobClient.fetchJobs()
            lastJobError = nil
        } catch {
            lastJobError = error.localizedDescription
        }
        isLoadingJobs = false
    }

    func runAgentRefactor() async {
        guard let repoURL, let fileURL = selectedFileURL else {
            lastJobError = "Select a file before running the refactor agent."
            return
        }
        let instruction = agentInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty else {
            lastJobError = "Provide an instruction for the refactor agent."
            return
        }
        do {
            let agent = AgentRefactor(jobClient: jobClient)
            let job = try await agent.run(repoURL: repoURL, fileURL: fileURL, instruction: instruction)
            jobs.insert(job, at: 0)
            lastJobError = nil
        } catch {
            lastJobError = error.localizedDescription
        }
    }

    private func storeBookmark(for url: URL) {
        do {
            let data = try url.bookmarkData(options: [.withSecurityScope])
            UserDefaults.standard.set(data, forKey: bookmarkKey)
            repoBookmarkData = data
        } catch {
            lastJobError = "Failed to store repository bookmark: \(error.localizedDescription)"
        }
    }

    private func restoreRepositoryFromBookmark() {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return }
        var isStale = false
        do {
            let resolvedURL = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                storeBookmark(for: resolvedURL)
            }
            repoURL = resolvedURL
            repoBookmarkData = data
            selectedFileURL = nil
            startAccessingRepo()
            refreshFileTree()
            Task {
                await refreshChanges()
                await refreshTasks()
            }
        } catch {
            lastJobError = "Failed to restore repository bookmark: \(error.localizedDescription)"
        }
    }

    private func startAccessingRepo() {
        guard let repoURL, !hasSecurityScopedAccess else { return }
        hasSecurityScopedAccess = repoURL.startAccessingSecurityScopedResource()
    }

    private func stopAccessingRepo() {
        guard hasSecurityScopedAccess else { return }
        repoURL?.stopAccessingSecurityScopedResource()
        hasSecurityScopedAccess = false
    }

    private func buildFileTree(at url: URL) -> [RepoFileNode] {
        let fm = FileManager.default
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: options) else {
            return []
        }
        let nodes: [RepoFileNode] = contents.compactMap { itemURL in
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: itemURL.path, isDirectory: &isDirectory) else { return nil }
            if isDirectory.boolValue {
                let children = buildFileTree(at: itemURL)
                return RepoFileNode(
                    id: itemURL,
                    url: itemURL,
                    name: itemURL.lastPathComponent,
                    isDirectory: true,
                    children: children
                )
            }
            return RepoFileNode(
                id: itemURL,
                url: itemURL,
                name: itemURL.lastPathComponent,
                isDirectory: false,
                children: nil
            )
        }

        return nodes.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private func runGitCommand(arguments: [String], repoURL: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", repoURL.path] + arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}

private func collectFileURLs(from nodes: [RepoFileNode]) -> [URL] {
    var results: [URL] = []
    for node in nodes {
        if let children = node.children {
            results.append(contentsOf: collectFileURLs(from: children))
        } else {
            results.append(node.url)
        }
    }
    return results
}

private func searchFile(url: URL, query: String) -> RepoSearchResult? {
    guard let fileData = try? Data(contentsOf: url), fileData.count < 1_000_000 else { return nil }
    guard let text = String(data: fileData, encoding: .utf8) else { return nil }
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    for (index, line) in lines.enumerated() {
        if line.localizedCaseInsensitiveContains(query) {
            let preview = line.trimmingCharacters(in: .whitespaces)
            return RepoSearchResult(url: url, lineNumber: index + 1, preview: preview)
        }
    }
    return nil
}

private func findTasks(in url: URL) -> [RepoTaskItem] {
    guard let fileData = try? Data(contentsOf: url), fileData.count < 1_000_000 else { return [] }
    guard let text = String(data: fileData, encoding: .utf8) else { return [] }
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    var items: [RepoTaskItem] = []
    for (index, line) in lines.enumerated() {
        let content = String(line)
        if content.contains("TODO") || content.contains("FIXME") {
            items.append(
                RepoTaskItem(
                    url: url,
                    lineNumber: index + 1,
                    label: content.trimmingCharacters(in: .whitespaces)
                )
            )
        }
    }
    return items
}
