import Foundation

/// Policy Engine for anigma-cli
/// Implements default-deny security model with allowlist-based approvals
public actor CLIPolicyEngine {

    // MARK: - Policy Models

    public enum PolicyDecision: Sendable {
        case allow
        case deny(reason: String)
        case requireApproval(operation: String)
    }

    public struct PolicyRule: Codable, Sendable {
        public let id: String
        public let name: String
        public let operation: OperationType
        public let pathPattern: String?
        public let action: PolicyAction
        public let priority: Int

        public enum OperationType: String, Codable, Sendable {
            case fileRead = "file_read"
            case fileWrite = "file_write"
            case fileDelete = "file_delete"
            case shellCommand = "shell_command"
            case gitOperation = "git_operation"
            case networkAccess = "network_access"
        }

        public enum PolicyAction: String, Codable, Sendable {
            case allow
            case deny
            case requireApproval = "require_approval"
        }
    }

    public struct PolicyConfig: Codable, Sendable {
        public var defaultAction: PolicyRule.PolicyAction
        public var allowedPaths: Set<String>
        public var deniedPaths: Set<String>
        public var requireApprovalPaths: Set<String>
        public var allowedCommands: Set<String>
        public var deniedCommands: Set<String>
        public var maxFileSize: Int64
        public var allowNetworkAccess: Bool

        public static var `default`: PolicyConfig {
            PolicyConfig(
                defaultAction: .requireApproval,
                allowedPaths: [],
                deniedPaths: [
                    "/etc",
                    "/System",
                    "/usr/bin",
                    "/usr/sbin",
                    "~/.ssh",
                    "~/.gnupg"
                ],
                requireApprovalPaths: [],
                allowedCommands: [
                    "git",
                    "swift",
                    "cat",
                    "ls",
                    "grep"
                ],
                deniedCommands: [
                    "rm -rf /",
                    "sudo",
                    "chmod 777"
                ],
                maxFileSize: 10_000_000, // 10MB
                allowNetworkAccess: false
            )
        }
    }

    // MARK: - Properties

    private let dbPath: String
    private var config: PolicyConfig
    private var rules: [PolicyRule]
    private var approvalCache: [String: PolicyDecision]

    // MARK: - Initialization

    public init(dbPath: String, config: PolicyConfig = .default) {
        self.dbPath = dbPath
        self.config = config
        self.rules = []
        self.approvalCache = [:]
    }

    // MARK: - Policy Evaluation

    public func evaluateFileRead(path: String) -> PolicyDecision {
        let normalizedPath = normalizePath(path)

        // Check denied paths first
        if isDeniedPath(normalizedPath) {
            return .deny(reason: "Path is in denied list")
        }

        // Check allowed paths
        if isAllowedPath(normalizedPath) {
            return .allow
        }

        // Check if approval required
        if requiresApproval(normalizedPath) {
            return .requireApproval(operation: "read \(normalizedPath)")
        }

        // Default action
        return applyDefaultAction(operation: "read \(normalizedPath)")
    }

    public func evaluateFileWrite(path: String, size: Int64) -> PolicyDecision {
        let normalizedPath = normalizePath(path)

        // Size limit check
        if size > config.maxFileSize {
            return .deny(reason: "File size \(size) exceeds limit \(config.maxFileSize)")
        }

        // Check denied paths
        if isDeniedPath(normalizedPath) {
            return .deny(reason: "Path is in denied list")
        }

        // Check allowed paths
        if isAllowedPath(normalizedPath) {
            return .allow
        }

        // Write operations always require approval by default
        return .requireApproval(operation: "write \(normalizedPath)")
    }

    public func evaluateFileDelete(path: String) -> PolicyDecision {
        let normalizedPath = normalizePath(path)

        // Delete always requires approval
        return .requireApproval(operation: "delete \(normalizedPath)")
    }

    public func evaluateShellCommand(command: String) -> PolicyDecision {
        let commandName = extractCommandName(command)

        // Check denied commands
        if isDeniedCommand(command) {
            return .deny(reason: "Command is in denied list")
        }

        // Check allowed commands
        if isAllowedCommand(commandName) {
            return .allow
        }

        // Default requires approval
        return .requireApproval(operation: "execute: \(command)")
    }

    public func evaluateGitOperation(operation: String, path: String) -> PolicyDecision {
        // Git operations in worktrees are generally allowed
        // But mutations (commit, push) require approval
        let mutatingOps = ["commit", "push", "merge", "rebase", "reset"]
        let op = operation.lowercased()

        if mutatingOps.contains(where: { op.contains($0) }) {
            return .requireApproval(operation: "git \(operation)")
        }

        return .allow
    }

    public func evaluateNetworkAccess(url: String) -> PolicyDecision {
        if !config.allowNetworkAccess {
            return .deny(reason: "Network access is disabled")
        }

        return .requireApproval(operation: "network access to \(url)")
    }

    // MARK: - Rule Management

    public func addRule(_ rule: PolicyRule) {
        rules.append(rule)
        rules.sort { $0.priority > $1.priority }
    }

    public func removeRule(id: String) {
        rules.removeAll { $0.id == id }
    }

    public func listRules() -> [PolicyRule] {
        return rules
    }

    // MARK: - Approval Management

    public func requestApproval(operation: String) async -> Bool {
        // Check cache first
        if let cached = approvalCache[operation] {
            if case .allow = cached {
                return true
            }
        }

        // In CLI context, we'd prompt the user
        // For now, return false (deny by default)
        print("⚠️  Approval required: \(operation)")
        print("   Run with --approve flag to allow this operation")
        return false
    }

    public func grantApproval(operation: String) {
        approvalCache[operation] = .allow
    }

    public func revokeApproval(operation: String) {
        approvalCache.removeValue(forKey: operation)
    }

    public func clearApprovalCache() {
        approvalCache.removeAll()
    }

    // MARK: - Path Management

    public func addAllowedPath(_ path: String) {
        config.allowedPaths.insert(normalizePath(path))
    }

    public func removeAllowedPath(_ path: String) {
        config.allowedPaths.remove(normalizePath(path))
    }

    public func addDeniedPath(_ path: String) {
        config.deniedPaths.insert(normalizePath(path))
    }

    public func removeDeniedPath(_ path: String) {
        config.deniedPaths.remove(normalizePath(path))
    }

    // MARK: - Command Management

    public func addAllowedCommand(_ command: String) {
        config.allowedCommands.insert(command)
    }

    public func removeAllowedCommand(_ command: String) {
        config.allowedCommands.remove(command)
    }

    public func addDeniedCommand(_ command: String) {
        config.deniedCommands.insert(command)
    }

    public func removeDeniedCommand(_ command: String) {
        config.deniedCommands.remove(command)
    }

    // MARK: - Helper Methods

    private func normalizePath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        return (expanded as NSString).standardizingPath
    }

    private func isDeniedPath(_ path: String) -> Bool {
        for deniedPath in config.deniedPaths {
            let normalized = normalizePath(deniedPath)
            if path.hasPrefix(normalized) {
                return true
            }
        }
        return false
    }

    private func isAllowedPath(_ path: String) -> Bool {
        for allowedPath in config.allowedPaths {
            let normalized = normalizePath(allowedPath)
            if path.hasPrefix(normalized) {
                return true
            }
        }
        return false
    }

    private func requiresApproval(_ path: String) -> Bool {
        for approvalPath in config.requireApprovalPaths {
            let normalized = normalizePath(approvalPath)
            if path.hasPrefix(normalized) {
                return true
            }
        }
        return false
    }

    private func extractCommandName(_ command: String) -> String {
        let components = command.trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
        return components.first ?? ""
    }

    private func isAllowedCommand(_ commandName: String) -> Bool {
        config.allowedCommands.contains(commandName)
    }

    private func isDeniedCommand(_ command: String) -> Bool {
        for denied in config.deniedCommands {
            if command.contains(denied) {
                return true
            }
        }
        return false
    }

    private func applyDefaultAction(operation: String) -> PolicyDecision {
        switch config.defaultAction {
        case .allow:
            return .allow
        case .deny:
            return .deny(reason: "Default deny policy")
        case .requireApproval:
            return .requireApproval(operation: operation)
        }
    }

    // MARK: - Persistence

    public func saveConfig() async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)

        let configPath = (dbPath as NSString).deletingLastPathComponent + "/policy.json"
        try data.write(to: URL(fileURLWithPath: configPath))
    }

    func loadConfig() async throws -> PolicyConfig {
        let configPath = (dbPath as NSString).deletingLastPathComponent + "/policy.json"
        let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
        let decoder = JSONDecoder()
        return try decoder.decode(PolicyConfig.self, from: data)
    }
}

// MARK: - PolicyConfig Extensions

extension CLIPolicyEngine.PolicyConfig {
    mutating func allowWorktree(_ path: String) {
        allowedPaths.insert(path)
    }

    mutating func denyWorktree(_ path: String) {
        deniedPaths.insert(path)
    }

    mutating func requireApprovalForWorktree(_ path: String) {
        requireApprovalPaths.insert(path)
    }
}
