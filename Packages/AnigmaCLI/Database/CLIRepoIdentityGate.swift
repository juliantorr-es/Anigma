import Foundation

/// RepoIdentity Gate Integration for anigma-cli
/// Enforces repository identity verification before mutations
public actor CLIRepoIdentityGate {

    // MARK: - Models

    public struct RepoIdentity: Codable, Sendable {
        public let path: String
        public let remote: String?
        public let branch: String
        public let commitHash: String
        public let isClean: Bool
        public let timestamp: Date

        public var fingerprint: String {
            "\(path):\(remote ?? "local"):\(branch):\(commitHash)"
        }
    }

    public struct GateResult: Sendable {
        public let allowed: Bool
        public let reason: String
        public let identity: RepoIdentity?
    }

    // MARK: - Properties

    private let dbPath: String
    private var verifiedIdentities: [String: RepoIdentity]
    private var allowedWorktrees: Set<String>

    // MARK: - Initialization

    public init(dbPath: String) {
        self.dbPath = dbPath
        self.verifiedIdentities = [:]
        self.allowedWorktrees = []
    }

    // MARK: - Identity Verification

    public func verifyIdentity(at path: String) async throws -> RepoIdentity {
        let identity = try await extractIdentity(at: path)

        // Cache verified identity
        verifiedIdentities[identity.fingerprint] = identity

        return identity
    }

    public func checkIdentity(at path: String) -> GateResult {
        guard let identity = try? extractIdentitySync(at: path) else {
            return GateResult(
                allowed: false,
                reason: "Failed to extract repository identity",
                identity: nil
            )
        }

        // Check if path is in allowed worktrees
        let normalizedPath = normalizePath(path)
        if !allowedWorktrees.contains(normalizedPath) {
            return GateResult(
                allowed: false,
                reason: "Path not in allowed worktrees: \(normalizedPath)",
                identity: identity
            )
        }

        // Verify identity hasn't changed
        if let cached = verifiedIdentities[identity.fingerprint] {
            if cached.commitHash != identity.commitHash {
                return GateResult(
                    allowed: false,
                    reason: "Repository state changed (commit hash mismatch)",
                    identity: identity
                )
            }
        }

        return GateResult(
            allowed: true,
            reason: "Identity verified",
            identity: identity
        )
    }

    // MARK: - Mutation Guards

    public func guardFileWrite(path: String) async throws -> GateResult {
        let repoPath = try findRepositoryRoot(for: path)
        return checkIdentity(at: repoPath)
    }

    public func guardFileDelete(path: String) async throws -> GateResult {
        let repoPath = try findRepositoryRoot(for: path)
        return checkIdentity(at: repoPath)
    }

    public func guardGitOperation(path: String, operation: String) async throws -> GateResult {
        let result = checkIdentity(at: path)

        if !result.allowed {
            return result
        }

        // Additional checks for mutating operations
        let mutatingOps = ["commit", "push", "merge", "rebase", "reset", "checkout"]
        if mutatingOps.contains(where: { operation.lowercased().contains($0) }) {
            if let identity = result.identity, !identity.isClean {
                return GateResult(
                    allowed: false,
                    reason: "Repository has uncommitted changes",
                    identity: identity
                )
            }
        }

        return result
    }

    // MARK: - Worktree Management

    public func allowWorktree(_ path: String) async throws {
        _ = try await verifyIdentity(at: path)
        let normalizedPath = normalizePath(path)
        allowedWorktrees.insert(normalizedPath)

        // Store in database
        try await persistWorktreeAllowlist()
    }

    public func denyWorktree(_ path: String) {
        let normalizedPath = normalizePath(path)
        allowedWorktrees.remove(normalizedPath)
    }

    public func listAllowedWorktrees() -> Set<String> {
        return allowedWorktrees
    }

    public func isWorktreeAllowed(_ path: String) -> Bool {
        let normalizedPath = normalizePath(path)
        return allowedWorktrees.contains(normalizedPath)
    }

    // MARK: - Private Helpers

    private func normalizePath(_ path: String) -> String {
        return (path as NSString).expandingTildeInPath.replacingOccurrences(of: "//", with: "/")
    }

    // MARK: - Identity Extraction

    private func extractIdentity(at path: String) async throws -> RepoIdentity {
        return try extractIdentitySync(at: path)
    }

    private func extractIdentitySync(at path: String) throws -> RepoIdentity {
        let fm = FileManager.default

        // Check if directory exists
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw RepoIdentityError.notADirectory(path)
        }

        // Check if it's a git repository
        let gitPath = (path as NSString).appendingPathComponent(".git")
        guard fm.fileExists(atPath: gitPath) else {
            throw RepoIdentityError.notAGitRepository(path)
        }

        // Extract git information
        let remote = try? executeGitCommand(["remote", "get-url", "origin"], at: path)
        let branch = try executeGitCommand(["rev-parse", "--abbrev-ref", "HEAD"], at: path)
        let commitHash = try executeGitCommand(["rev-parse", "HEAD"], at: path)
        let status = try executeGitCommand(["status", "--porcelain"], at: path)

        return RepoIdentity(
            path: path,
            remote: remote?.trimmingCharacters(in: .whitespacesAndNewlines),
            branch: branch.trimmingCharacters(in: .whitespacesAndNewlines),
            commitHash: commitHash.trimmingCharacters(in: .whitespacesAndNewlines),
            isClean: status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            timestamp: Date()
        )
    }

    private func findRepositoryRoot(for path: String) throws -> String {
        var currentPath = (path as NSString).deletingLastPathComponent
        let fm = FileManager.default

        while currentPath != "/" {
            let gitPath = (currentPath as NSString).appendingPathComponent(".git")
            if fm.fileExists(atPath: gitPath) {
                return currentPath
            }
            currentPath = (currentPath as NSString).deletingLastPathComponent
        }

        throw RepoIdentityError.notInRepository(path)
    }

    private func executeGitCommand(_ args: [String], at path: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: path)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw RepoIdentityError.gitCommandFailed(args.joined(separator: " "))
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func persistWorktreeAllowlist() async throws {
        let db = try await openDatabase()

        let createTable = """
        CREATE TABLE IF NOT EXISTS allowed_worktrees (
            path TEXT PRIMARY KEY,
            added_at TEXT NOT NULL
        )
        """

        _ = try await db.execute(createTable)

        for path in allowedWorktrees {
            let insert = """
            INSERT OR REPLACE INTO allowed_worktrees (path, added_at)
            VALUES (?, ?)
            """
            _ = try await db.execute(insert, parameters: [.text(path), .text(ISO8601DateFormatter().string(from: Date()))])
        }
    }

    private func loadWorktreeAllowlist() async throws {
        let db = try await openDatabase()

        let query = "SELECT path FROM allowed_worktrees"
        let rows = try await db.query(query)

        for row in rows {
            if let path = row["path"]?.asString {
                allowedWorktrees.insert(path)
            }
        }
    }

    private func openDatabase() async throws -> CLIDatabaseActor {
        let db = CLIDatabaseActor(config: CLIDatabaseConfig(databasePath: dbPath))
        try await db.open()
        return db
    }
}

// MARK: - Errors

enum RepoIdentityError: Error, LocalizedError {
    case notADirectory(String)
    case notAGitRepository(String)
    case notInRepository(String)
    case gitCommandFailed(String)

    var errorDescription: String? {
        switch self {
        case .notADirectory(let path):
            return "Not a directory: \(path)"
        case .notAGitRepository(let path):
            return "Not a git repository: \(path)"
        case .notInRepository(let path):
            return "File not in a git repository: \(path)"
        case .gitCommandFailed(let command):
            return "Git command failed: \(command)"
        }
    }
}
