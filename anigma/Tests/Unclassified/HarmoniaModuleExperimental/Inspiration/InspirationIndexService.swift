//
//  InspirationIndexService.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Inspiration
//
//  Service that scans inspiration/ directory and indexes repositories.
//  Boring scanner, not LLM-wandering.
//

import Foundation
import HarmoniaModule

/// Service for indexing local inspiration repositories.
public actor InspirationIndexService {
    private let indexStore: InspirationIndexStore
    private let policy: InspirationPolicy
    private let scoutRegistry: InspirationScoutRegistry

    public init(
        indexStore: InspirationIndexStore,
        policy: InspirationPolicy? = nil,
        scoutRegistry: InspirationScoutRegistry = InspirationScoutRegistry()
    ) {
        self.indexStore = indexStore
        self.policy = policy ?? InspirationPolicy(
            sourceId: UUID(),
            licenseCompatibility: .unknown,
            maxCodeLines: 10,
            allowedUses: [.patternExtraction],
            attributionRequired: true
        )
        self.scoutRegistry = scoutRegistry
    }

    /// Scan and index all repositories in the inspiration directory.
    public func indexInspirationDirectory(at path: String) async throws -> [InspirationRepo] {
        let inspirationURL = URL(fileURLWithPath: path)

        // 1. Find all directories in inspiration/
        let repoURLs = try findRepositories(in: inspirationURL)

        var indexedRepos: [InspirationRepo] = []

        // 2. Process each repository
        for repoURL in repoURLs {
            do {
                let repo = try await indexRepository(at: repoURL, relativeTo: inspirationURL)
                indexedRepos.append(repo)

                // 3. Run scouts on the repository
                try await runScouts(on: repo)

            } catch {
                print("Failed to index repository at \(repoURL.path): \(error)")
                // Continue with other repos
            }
        }

        return indexedRepos
    }

    /// Index a single repository.
    public func indexRepository(at repoURL: URL, relativeTo inspirationURL: URL) async throws -> InspirationRepo {
        // 1. Get repository info
        let repoName = repoURL.lastPathComponent
        let relativePath = repoURL.relativePath(from: inspirationURL) ?? repoURL.path

        // 2. Detect license
        let license = try await detectLicense(in: repoURL)

        // 3. Get git info if available
        let (gitUrl, commitHash) = try await getGitInfo(for: repoURL)

        // 4. Check if repo already exists
        if let existingRepo = try await indexStore.getRepo(byPath: relativePath) {
            // Update existing repo
            let updatedRepo = InspirationRepo(
                id: existingRepo.id,
                name: repoName,
                path: relativePath,
                gitUrl: gitUrl ?? existingRepo.gitUrl,
                license: license ?? existingRepo.license,
                tags: existingRepo.tags,
                lastIndexed: Date(),
                commitHash: commitHash ?? existingRepo.commitHash
            )

            try await indexStore.saveRepo(updatedRepo)
            return updatedRepo
        } else {
            // Create new repo
            let newRepo = InspirationRepo(
                name: repoName,
                path: relativePath,
                gitUrl: gitUrl,
                license: license,
                tags: [],
                lastIndexed: Date(),
                commitHash: commitHash
            )

            try await indexStore.saveRepo(newRepo)
            return newRepo
        }
    }

    /// Run all scouts on a repository.
    public func runScouts(on repo: InspirationRepo) async throws {
        let projectRoot = FileManager.default.currentDirectoryPath

        // Run each scout
        for scout in scoutRegistry.getScouts() {
            do {
                let patterns = try await scout.scan(repo: repo, projectRoot: projectRoot, indexStore: indexStore)

                for pattern in patterns {
                    // Add repo ID to pattern
                    let patternWithRepo = InspirationPattern(
                        repoId: repo.id,
                        patternId: pattern.patternId,
                        kind: pattern.kind,
                        language: pattern.language,
                        astFingerprint: pattern.astFingerprint,
                        description: pattern.description,
                        exampleSnippet: pattern.exampleSnippet,
                        metadata: pattern.metadata,
                        discoveredAt: pattern.discoveredAt
                    )

                    try await indexStore.savePattern(patternWithRepo)
                }

            } catch {
                print("Scout \(type(of: scout)) failed for repo \(repo.name): \(error)")
                // Continue with other scouts
            }
        }
    }

    /// Find all repository directories in the inspiration directory.
    private func findRepositories(in directory: URL) throws -> [URL] {
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var repoURLs: [URL] = []

        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])

            if resourceValues.isDirectory == true {
                // Check if this directory contains a .git folder or other repo indicators
                if isRepositoryDirectory(fileURL) {
                    repoURLs.append(fileURL)
                    enumerator.skipDescendants() // Don't look inside repos
                }
            }
        }

        return repoURLs
    }

    /// Check if a directory appears to be a repository.
    private func isRepositoryDirectory(_ url: URL) -> Bool {
        let fileManager = FileManager.default

        // Check for common repository indicators
        let gitURL = url.appendingPathComponent(".git")
        if fileManager.fileExists(atPath: gitURL.path) {
            return true
        }

        // Check for other VCS directories
        let hgURL = url.appendingPathComponent(".hg")
        let svnURL = url.appendingPathComponent(".svn")

        if fileManager.fileExists(atPath: hgURL.path) || fileManager.fileExists(atPath: svnURL.path) {
            return true
        }

        // Check for package manifests
        let packageSwift = url.appendingPathComponent("Package.swift")
        let packageJSON = url.appendingPathComponent("package.json")
        let cargoToml = url.appendingPathComponent("Cargo.toml")
        let pyProjectToml = url.appendingPathComponent("pyproject.toml")

        if fileManager.fileExists(atPath: packageSwift.path) ||
           fileManager.fileExists(atPath: packageJSON.path) ||
           fileManager.fileExists(atPath: cargoToml.path) ||
           fileManager.fileExists(atPath: pyProjectToml.path) {
            return true
        }

        // Check for source directories
        let sourcesURL = url.appendingPathComponent("Sources")
        let srcURL = url.appendingPathComponent("src")

        if fileManager.fileExists(atPath: sourcesURL.path) || fileManager.fileExists(atPath: srcURL.path) {
            return true
        }

        return false
    }

    /// Detect license in a repository.
    private func detectLicense(in repoURL: URL) async throws -> String? {
        let fileManager = FileManager.default

        // Common license file names
        let licenseFiles = [
            "LICENSE",
            "LICENSE.txt",
            "LICENSE.md",
            "COPYING",
            "COPYING.txt",
            "LICENCE",
            "LICENCE.txt"
        ]

        for licenseFile in licenseFiles {
            let licenseURL = repoURL.appendingPathComponent(licenseFile)
            if fileManager.fileExists(atPath: licenseURL.path) {
                do {
                    let content = try String(contentsOf: licenseURL, encoding: .utf8)
                    return LicenseDetector.detectCompatibility(from: content).rawValue
                } catch {
                    // Continue to next license file
                    continue
                }
            }
        }

        // Check for license in README
        let readmeFiles = [
            "README",
            "README.md",
            "README.txt",
            "README.rst"
        ]

        for readmeFile in readmeFiles {
            let readmeURL = repoURL.appendingPathComponent(readmeFile)
            if fileManager.fileExists(atPath: readmeURL.path) {
                do {
                    let content = try String(contentsOf: readmeURL, encoding: .utf8)
                    let license = LicenseDetector.detectCompatibility(from: content)
                    if license != .unknown {
                        return license.rawValue
                    }
                } catch {
                    // Continue to next readme file
                    continue
                }
            }
        }

        return nil
    }

    /// Get git information for a repository.
    private func getGitInfo(for repoURL: URL) async throws -> (gitUrl: String?, commitHash: String?) {
        let fileManager = FileManager.default
        let gitURL = repoURL.appendingPathComponent(".git")

        guard fileManager.fileExists(atPath: gitURL.path) else {
            return (nil, nil)
        }

        // Get git remote URL
        let configURL = gitURL.appendingPathComponent("config")
        if fileManager.fileExists(atPath: configURL.path) {
            do {
                let configContent = try String(contentsOf: configURL, encoding: .utf8)
                let gitUrl = extractGitUrl(from: configContent)

                // Get current commit hash
                let headURL = gitURL.appendingPathComponent("HEAD")
                if fileManager.fileExists(atPath: headURL.path) {
                    let headContent = try String(contentsOf: headURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)

                    if headContent.hasPrefix("ref: ") {
                        let refPath = String(headContent.dropFirst(5))
                        let refURL = gitURL.appendingPathComponent(refPath)

                        if fileManager.fileExists(atPath: refURL.path) {
                            let commitHash = try String(contentsOf: refURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
                            return (gitUrl, commitHash)
                        }
                    } else {
                        // Detached HEAD
                        return (gitUrl, headContent)
                    }
                }

                return (gitUrl, nil)
            } catch {
                return (nil, nil)
            }
        }

        return (nil, nil)
    }

    /// Extract git URL from git config.
    private func extractGitUrl(from configContent: String) -> String? {
        let lines = configContent.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("url = ") {
                let url = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                return url
            }
        }

        return nil
    }

    /// Get all indexed repositories.
    public func getAllRepos() async throws -> [InspirationRepo] {
        return try await indexStore.getAllRepos()
    }

    /// Get patterns for a repository.
    public func getPatterns(forRepo repoId: UUID, kind: InspirationPattern.PatternKind? = nil) async throws -> [InspirationPattern] {
        return try await indexStore.getPatterns(forRepo: repoId, kind: kind)
    }

    /// Get patterns by kind.
    public func getPatternsByKind(_ kind: InspirationPattern.PatternKind) async throws -> [InspirationPattern] {
        return try await indexStore.getPatternsByKind(kind)
    }

    /// Check if a repository needs re-indexing.
    public func needsReindexing(_ repo: InspirationRepo) async throws -> Bool {
        let repoURL = URL(fileURLWithPath: repo.path)

        // Check if directory still exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: repoURL.path) else {
            return false // Can't reindex if it doesn't exist
        }

        // Check if git commit has changed
        let (_, currentCommitHash) = try await getGitInfo(for: repoURL)

        if let repoCommitHash = repo.commitHash,
           let currentCommitHash = currentCommitHash,
           repoCommitHash != currentCommitHash {
            return true
        }

        // Check if it's been more than 7 days since last index
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return repo.lastIndexed < sevenDaysAgo
    }

    /// Re-index repositories that need it.
    public func reindexIfNeeded() async throws -> [InspirationRepo] {
        let repos = try await indexStore.getAllRepos()
        var reindexedRepos: [InspirationRepo] = []

        for repo in repos {
            if try await needsReindexing(repo) {
                let repoURL = URL(fileURLWithPath: repo.path)
                let inspirationURL = repoURL.deletingLastPathComponent()

                let updatedRepo = try await indexRepository(at: repoURL, relativeTo: inspirationURL)
                try await runScouts(on: updatedRepo)

                reindexedRepos.append(updatedRepo)
            }
        }

        return reindexedRepos
    }
}

// MARK: - URL Extension

extension URL {
    /// Get relative path from base URL.
    func relativePath(from base: URL) -> String? {
        // Ensure both URLs are absolute
        guard self.isFileURL, base.isFileURL else {
            return nil
        }

        // Remove trailing slashes
        let selfPath = self.path.hasSuffix("/") ? String(self.path.dropLast()) : self.path
        let basePath = base.path.hasSuffix("/") ? String(base.path.dropLast()) : base.path

        // Check if self is contained within base
        guard selfPath.hasPrefix(basePath) else {
            return nil
        }

        // Get relative path
        let relativePath = String(selfPath.dropFirst(basePath.count))

        // Remove leading slash if present
        if relativePath.hasPrefix("/") {
            return String(relativePath.dropFirst())
        }

        return relativePath
    }
}
