//
//  GranularCapability.swift
//  ContractsCore
//
//  Fine-grained capabilities for zero-trust security.
//

import FoundationContracts
import AnigmaPrimitives
import Foundation

// MARK: - Granular Capabilities

/// Fine-grained capabilities for zero-trust security.
/// Each capability is a small verb describing exactly what can be done.
public enum GranularCapability: String, Sendable, Codable, Hashable, CaseIterable {
    // MARK: - Filesystem Capabilities

    /// Read files within the project directory.
    case fsReadProject = "fs.read.project"

    /// Write to source files (modify existing code).
    case fsWriteSource = "fs.write.source"

    /// Write to generated files (output, logs, temp).
    case fsWriteGenerated = "fs.write.generated"

    /// Write to temporary files only.
    case fsWriteTemp = "fs.write.temp"

    /// Delete files within the project.
    case fsDeleteProject = "fs.delete.project"

    /// List directory contents.
    case fsListDirectory = "fs.list.directory"

    // MARK: - Network Capabilities

    /// Read from GitHub API (public repos, issues, etc.).
    case netGitHubApiRead = "net.github.api.read"

    /// Write to GitHub API (create issues, PRs, etc.).
    case netGitHubApiWrite = "net.github.api.write"

    /// Access OpenAI API (chat completions).
    case netOpenAiApi = "net.openai.api"

    /// Access HuggingFace API (models, datasets).
    case netHuggingfaceApi = "net.huggingface.api"

    /// Access raw.githubusercontent.com (inspiration repos).
    case netRawGithub = "net.raw.github"

    /// Generic HTTP GET requests (whitelisted domains).
    case netHttpGet = "net.http.get"

    /// Generic HTTP POST requests (whitelisted domains).
    case netHttpPost = "net.http.post"

    // MARK: - LLM/Model Capabilities

    /// Use local LLM models (on-device).
    case llmLocal = "llm.local"

    /// Use remote LLM models (API calls).
    case llmRemote = "llm.remote"

    /// Use remote LLM with code execution context.
    case llmRemoteWithCode = "llm.remote.with-code"

    /// Use local embedding models.
    case llmLocalEmbeddings = "llm.local.embeddings"

    // MARK: - Secret Capabilities

    /// Read vault encryption keys.
    case secretsReadVaultKey = "secrets.read.vault-key"

    /// Write project-specific tokens.
    case secretsWriteProjectToken = "secrets.write.project-token"

    /// Read API keys for external services.
    case secretsReadApiKey = "secrets.read.api-key"

    /// Rotate/update secrets.
    case secretsRotate = "secrets.rotate"

    // MARK: - Tool/Execution Capabilities

    /// Execute Swift code (compilation/runtime).
    case executeSwift = "execute.swift"

    /// Execute shell commands (restricted).
    case executeShell = "execute.shell"

    /// Execute Python scripts (if available).
    case executePython = "execute.python"

    /// Spawn child processes.
    case executeProcess = "execute.process"

    // MARK: - Git Capabilities

    /// Read git repository (clone, fetch, status).
    case gitRead = "git.read"

    /// Write to git repository (commit, push, tag).
    case gitWrite = "git.write"

    /// Create/merge branches.
    case gitBranch = "git.branch"

    /// Rewrite history (rebase, amend).
    case gitRewrite = "git.rewrite"

    // MARK: - System Capabilities

    /// Access system information (CPU, memory, disk).
    case systemInfo = "system.info"

    /// Access user home directory.
    case systemHome = "system.home"

    /// Access system keychain.
    case systemKeychain = "system.keychain"

    /// Access network configuration.
    case systemNetwork = "system.network"

    public var description: String {
        switch self {
        case .fsReadProject: return "Read project files"
        case .fsWriteSource: return "Write source code files"
        case .fsWriteGenerated: return "Write generated files"
        case .fsWriteTemp: return "Write temporary files"
        case .fsDeleteProject: return "Delete project files"
        case .fsListDirectory: return "List directory contents"
        case .netGitHubApiRead: return "Read from GitHub API"
        case .netGitHubApiWrite: return "Write to GitHub API"
        case .netOpenAiApi: return "Access OpenAI API"
        case .netHuggingfaceApi: return "Access HuggingFace API"
        case .netRawGithub: return "Access raw GitHub content"
        case .netHttpGet: return "HTTP GET requests"
        case .netHttpPost: return "HTTP POST requests"
        case .llmLocal: return "Use local LLM models"
        case .llmRemote: return "Use remote LLM models"
        case .llmRemoteWithCode: return "Use remote LLM with code"
        case .llmLocalEmbeddings: return "Use local embedding models"
        case .secretsReadVaultKey: return "Read vault encryption keys"
        case .secretsWriteProjectToken: return "Write project tokens"
        case .secretsReadApiKey: return "Read API keys"
        case .secretsRotate: return "Rotate secrets"
        case .executeSwift: return "Execute Swift code"
        case .executeShell: return "Execute shell commands"
        case .executePython: return "Execute Python scripts"
        case .executeProcess: return "Spawn child processes"
        case .gitRead: return "Read git repository"
        case .gitWrite: return "Write to git repository"
        case .gitBranch: return "Create/merge git branches"
        case .gitRewrite: return "Rewrite git history"
        case .systemInfo: return "Access system information"
        case .systemHome: return "Access user home directory"
        case .systemKeychain: return "Access system keychain"
        case .systemNetwork: return "Access network configuration"
        }
    }

    /// Category for grouping related capabilities.
    public var category: CapabilityCategory {
        switch self {
        case .fsReadProject, .fsWriteSource, .fsWriteGenerated, .fsWriteTemp, .fsDeleteProject, .fsListDirectory:
            return .filesystem
        case .netGitHubApiRead, .netGitHubApiWrite, .netOpenAiApi, .netHuggingfaceApi, .netRawGithub, .netHttpGet, .netHttpPost:
            return .network
        case .llmLocal, .llmRemote, .llmRemoteWithCode, .llmLocalEmbeddings:
            return .llm
        case .secretsReadVaultKey, .secretsWriteProjectToken, .secretsReadApiKey, .secretsRotate:
            return .secrets
        case .executeSwift, .executeShell, .executePython, .executeProcess:
            return .execution
        case .gitRead, .gitWrite, .gitBranch, .gitRewrite:
            return .git
        case .systemInfo, .systemHome, .systemKeychain, .systemNetwork:
            return .system
        }
    }

    /// Default risk level for this capability.
    public var riskLevel: RiskLevel {
        switch self {
        case .fsReadProject, .fsListDirectory, .gitRead, .systemInfo:
            return .low
        case .fsWriteGenerated, .fsWriteTemp, .netGitHubApiRead, .netRawGithub, .netHttpGet, .llmLocal, .llmLocalEmbeddings, .executeSwift:
            return .medium
        case .fsWriteSource, .fsDeleteProject, .netGitHubApiWrite, .netOpenAiApi, .netHuggingfaceApi, .netHttpPost, .llmRemote, .llmRemoteWithCode, .executeShell, .executePython, .executeProcess, .gitWrite, .gitBranch, .secretsReadApiKey:
            return .high
        case .gitRewrite, .secretsReadVaultKey, .secretsWriteProjectToken, .secretsRotate, .systemHome, .systemKeychain, .systemNetwork:
            return .critical
        }
    }
}

/// Categories for grouping capabilities.
public enum CapabilityCategory: String, Sendable, Codable {
    case filesystem = "filesystem"
    case network = "network"
    case llm = "llm"
    case secrets = "secrets"
    case execution = "execution"
    case git = "git"
    case system = "system"
}

extension GranularCapability {
    /// Check if this capability implies another capability.
    public func implies(_ other: GranularCapability) -> Bool {
        // Some capabilities imply others (e.g., write implies read)
        let implications: [GranularCapability: Set<GranularCapability>] = [
            .fsWriteSource: [.fsReadProject, .fsListDirectory],
            .fsDeleteProject: [.fsReadProject, .fsListDirectory],
            .netGitHubApiWrite: [.netGitHubApiRead],
            .netHttpPost: [.netHttpGet],
            .llmRemoteWithCode: [.llmRemote],
            .gitWrite: [.gitRead],
            .gitRewrite: [.gitWrite, .gitRead],
            .secretsRotate: [.secretsReadVaultKey]
        ]

        return self == other || implications[self]?.contains(other) == true
    }

    /// Get all capabilities that this capability implies.
    public var impliedCapabilities: Set<GranularCapability> {
        var result = Set([self])

        // Recursively add implied capabilities
        var toProcess = [self]
        while let current = toProcess.popLast() {
            let implications: [GranularCapability: [GranularCapability]] = [
                .fsWriteSource: [.fsReadProject, .fsListDirectory],
                .fsDeleteProject: [.fsReadProject, .fsListDirectory],
                .netGitHubApiWrite: [.netGitHubApiRead],
                .netHttpPost: [.netHttpGet],
                .llmRemoteWithCode: [.llmRemote],
                .gitWrite: [.gitRead],
                .gitRewrite: [.gitWrite, .gitRead],
                .secretsRotate: [.secretsReadVaultKey]
            ]

            if let implied = implications[current] {
                for impliedCap in implied {
                    if !result.contains(impliedCap) {
                        result.insert(impliedCap)
                        toProcess.append(impliedCap)
                    }
                }
            }
        }

        return result
    }
}
