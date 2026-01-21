//
//  ProviderRegistry.swift
//  AnigmaCLIProviders
//
//  Provider discovery and availability checks.
//

import Foundation
import AnigmaCLICore

public enum ProviderKind: String, Codable, Sendable {
    case local
    case cliWrapper
    case cloud
}

public enum ProviderCapability: String, Codable, Sendable, CaseIterable, Hashable {
    case chat
    case embeddings
    case tools
    case streaming
    case codeEditing
    case shell
}

public struct ProviderDescriptor: Sendable, Codable, Hashable {
    public let id: String
    public let displayName: String
    public let kind: ProviderKind
    public let capabilities: Set<ProviderCapability>
    public let priority: Int

    public init(
        id: String,
        displayName: String,
        kind: ProviderKind,
        capabilities: Set<ProviderCapability>,
        priority: Int
    ) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.capabilities = capabilities
        self.priority = priority
    }
}

public struct ProviderStatus: Sendable, Codable, Hashable {
    public let descriptor: ProviderDescriptor
    public let available: Bool
    public let reason: String?
    public let resolvedPath: String?

    public init(
        descriptor: ProviderDescriptor,
        available: Bool,
        reason: String? = nil,
        resolvedPath: String? = nil
    ) {
        self.descriptor = descriptor
        self.available = available
        self.reason = reason
        self.resolvedPath = resolvedPath
    }
}

public struct ProviderConfiguration: Sendable {
    public let environment: [String: String]
    public let externalCLIsEnabled: Bool
    public let cloudEnabled: Bool

    public init(
        environment: [String: String],
        externalCLIsEnabled: Bool,
        cloudEnabled: Bool
    ) {
        self.environment = environment
        self.externalCLIsEnabled = externalCLIsEnabled
        self.cloudEnabled = cloudEnabled
    }

    public static func fromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> ProviderConfiguration {
        let externalEnabled = ProviderConfiguration.boolValue(from: environment, key: "ANIGMA_EXTERNAL_CLIS_ENABLE", defaultValue: true)
        let cloudEnabled = ProviderConfiguration.boolValue(from: environment, key: "ANIGMA_CLOUD_ENABLE", defaultValue: true)
        return ProviderConfiguration(
            environment: environment,
            externalCLIsEnabled: externalEnabled,
            cloudEnabled: cloudEnabled
        )
    }

    private static func boolValue(from environment: [String: String], key: String, defaultValue: Bool) -> Bool {
        guard let raw = environment[key]?.lowercased(), !raw.isEmpty else {
            return defaultValue
        }
        switch raw {
        case "1", "true", "yes", "y", "on":
            return true
        case "0", "false", "no", "n", "off":
            return false
        default:
            return defaultValue
        }
    }
}

public struct ExecutableLocator: Sendable {
    private let pathEntries: [String]

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        let pathValue = environment["PATH"] ?? ""
        self.pathEntries = pathValue.split(separator: ":").map { String($0) }
    }

    public func resolveExecutable(_ candidates: [String]) -> URL? {
        for candidate in candidates {
            if let resolved = resolveExecutable(candidate) {
                return resolved
            }
        }
        return nil
    }

    public func resolveExecutable(_ nameOrPath: String) -> URL? {
        let fileManager = FileManager.default
        if nameOrPath.contains("/") {
            let url = URL(fileURLWithPath: nameOrPath)
            return fileManager.isExecutableFile(atPath: url.path) ? url : nil
        }

        for path in pathEntries {
            let url = URL(fileURLWithPath: path).appendingPathComponent(nameOrPath)
            if fileManager.isExecutableFile(atPath: url.path) {
                return url
            }
        }

        return nil
    }
}

public struct ProviderRegistry: Sendable {
    private let configuration: ProviderConfiguration
    private let locator: ExecutableLocator

    public init(
        environment: [String: String] = CLIEnvironment.mergedEnvironment(),
        locator: ExecutableLocator? = nil
    ) {
        self.configuration = ProviderConfiguration.fromEnvironment(environment)
        self.locator = locator ?? ExecutableLocator(environment: environment)
    }

    public func statuses() -> [ProviderStatus] {
        let local = localProviders()
        let wrappers = externalCLIProviders()
        let cloud = cloudProviders()
        let statuses = local + wrappers + cloud
        return statuses.sorted { $0.descriptor.priority < $1.descriptor.priority }
    }

    public func availableProviders(required: Set<ProviderCapability> = []) -> [ProviderDescriptor] {
        statuses()
            .filter { $0.available }
            .map(\.descriptor)
            .filter { required.isSubset(of: $0.capabilities) }
            .sorted { $0.priority < $1.priority }
    }

    private func localProviders() -> [ProviderStatus] {
        let entries: [(ProviderDescriptor, [String], String?)] = [
            (
                ProviderDescriptor(
                    id: "local-mlx",
                    displayName: "MLX Local",
                    kind: .local,
                    capabilities: [.chat, .tools, .streaming, .codeEditing],
                    priority: 0
                ),
                ["mlx-run", "mlx"],
                "ANIGMA_MLX_PATH"
            ),
            (
                ProviderDescriptor(
                    id: "local-llama-cpp",
                    displayName: "llama.cpp Local",
                    kind: .local,
                    capabilities: [.chat, .tools, .streaming, .codeEditing],
                    priority: 0
                ),
                ["llama", "llama-cli", "llama.cpp"],
                "ANIGMA_LLAMACPP_PATH"
            ),
            (
                ProviderDescriptor(
                    id: "local-ollama",
                    displayName: "Ollama Local",
                    kind: .local,
                    capabilities: [.chat, .embeddings, .tools, .streaming],
                    priority: 0
                ),
                ["ollama"],
                "ANIGMA_OLLAMA_PATH"
            )
        ]

        return entries.map { descriptor, binaries, overrideKey in
            let overridePath = overrideKey.flatMap { configuration.environment[$0] }
            if let overridePath, let resolved = locator.resolveExecutable(overridePath) {
                return ProviderStatus(
                    descriptor: descriptor,
                    available: true,
                    resolvedPath: resolved.path
                )
            }

            if let resolved = locator.resolveExecutable(binaries) {
                return ProviderStatus(
                    descriptor: descriptor,
                    available: true,
                    resolvedPath: resolved.path
                )
            }

            return ProviderStatus(
                descriptor: descriptor,
                available: false,
                reason: "Executable not found on PATH.",
                resolvedPath: nil
            )
        }
    }

    private func externalCLIProviders() -> [ProviderStatus] {
        let disabledReason = "External CLIs disabled by ANIGMA_EXTERNAL_CLIS_ENABLE."
        let entries: [(ProviderDescriptor, [String])] = [
            (
                ProviderDescriptor(
                    id: "cli-codex",
                    displayName: "Codex CLI",
                    kind: .cliWrapper,
                    capabilities: [.chat, .tools, .streaming, .codeEditing, .shell],
                    priority: 1
                ),
                ["codex"]
            ),
            (
                ProviderDescriptor(
                    id: "cli-claude",
                    displayName: "Claude CLI",
                    kind: .cliWrapper,
                    capabilities: [.chat, .tools, .streaming, .codeEditing, .shell],
                    priority: 1
                ),
                ["claude"]
            ),
            (
                ProviderDescriptor(
                    id: "cli-gemini",
                    displayName: "Gemini CLI",
                    kind: .cliWrapper,
                    capabilities: [.chat, .tools, .streaming, .codeEditing],
                    priority: 1
                ),
                ["gemini"]
            ),
            (
                ProviderDescriptor(
                    id: "cli-opencode",
                    displayName: "OpenCode CLI",
                    kind: .cliWrapper,
                    capabilities: [.chat, .tools, .streaming, .codeEditing, .shell],
                    priority: 1
                ),
                ["opencode"]
            ),
            (
                ProviderDescriptor(
                    id: "cli-letta",
                    displayName: "Letta CLI",
                    kind: .cliWrapper,
                    capabilities: [.chat, .tools, .streaming, .codeEditing],
                    priority: 1
                ),
                ["letta"]
            )
        ]

        return entries.map { descriptor, binaries in
            guard configuration.externalCLIsEnabled else {
                return ProviderStatus(
                    descriptor: descriptor,
                    available: false,
                    reason: disabledReason
                )
            }
            if let resolved = locator.resolveExecutable(binaries) {
                return ProviderStatus(
                    descriptor: descriptor,
                    available: true,
                    resolvedPath: resolved.path
                )
            }
            return ProviderStatus(
                descriptor: descriptor,
                available: false,
                reason: "Executable not found on PATH.",
                resolvedPath: nil
            )
        }
    }

    private func cloudProviders() -> [ProviderStatus] {
        let disabledReason = "Cloud providers disabled by ANIGMA_CLOUD_ENABLE."
        let entries: [(ProviderDescriptor, [String])] = [
            (
                ProviderDescriptor(
                    id: "cloud-anthropic",
                    displayName: "Anthropic",
                    kind: .cloud,
                    capabilities: [.chat, .tools, .streaming, .codeEditing],
                    priority: 2
                ),
                ["ANTHROPIC_API_KEY"]
            ),
            (
                ProviderDescriptor(
                    id: "cloud-openai",
                    displayName: "OpenAI",
                    kind: .cloud,
                    capabilities: [.chat, .tools, .streaming, .codeEditing, .embeddings],
                    priority: 2
                ),
                ["OPENAI_API_KEY"]
            ),
            (
                ProviderDescriptor(
                    id: "cloud-google",
                    displayName: "Google Gemini",
                    kind: .cloud,
                    capabilities: [.chat, .tools, .streaming, .codeEditing],
                    priority: 2
                ),
                ["GOOGLE_API_KEY", "GEMINI_API_KEY"]
            ),
            (
                ProviderDescriptor(
                    id: "cloud-deepseek",
                    displayName: "DeepSeek",
                    kind: .cloud,
                    capabilities: [.chat, .tools, .streaming, .codeEditing],
                    priority: 2
                ),
                ["DEEPSEEK_API_KEY"]
            ),
            (
                ProviderDescriptor(
                    id: "cloud-vercel",
                    displayName: "Vercel AI",
                    kind: .cloud,
                    capabilities: [.chat, .tools, .streaming],
                    priority: 2
                ),
                ["VERCEL_AI_API_KEY", "VERCEL_API_KEY"]
            ),
            (
                ProviderDescriptor(
                    id: "cloud-huggingface",
                    displayName: "Hugging Face",
                    kind: .cloud,
                    capabilities: [.chat, .embeddings],
                    priority: 2
                ),
                ["HUGGINGFACE_API_TOKEN", "HF_TOKEN"]
            ),
            (
                ProviderDescriptor(
                    id: "cloud-ollama",
                    displayName: "Ollama Cloud",
                    kind: .cloud,
                    capabilities: [.chat, .embeddings, .tools],
                    priority: 2
                ),
                ["OLLAMA_API_KEY", "OLLAMA_CLOUD_TOKEN"]
            ),
            (
                ProviderDescriptor(
                    id: "cloud-azure",
                    displayName: "Azure OpenAI",
                    kind: .cloud,
                    capabilities: [.chat, .tools, .streaming, .codeEditing, .embeddings],
                    priority: 2
                ),
                ["AZURE_OPENAI_API_KEY"]
            ),
            (
                ProviderDescriptor(
                    id: "cloud-aws",
                    displayName: "AWS Bedrock",
                    kind: .cloud,
                    capabilities: [.chat, .tools, .streaming, .codeEditing],
                    priority: 2
                ),
                ["AWS_ACCESS_KEY_ID"]
            ),
            (
                ProviderDescriptor(
                    id: "cloud-groq",
                    displayName: "Groq",
                    kind: .cloud,
                    capabilities: [.chat, .tools, .streaming, .codeEditing],
                    priority: 2
                ),
                ["GROQ_API_KEY"]
            )
        ]

        return entries.map { descriptor, envKeys in
            guard configuration.cloudEnabled else {
                return ProviderStatus(
                    descriptor: descriptor,
                    available: false,
                    reason: disabledReason
                )
            }

            let key = envKeys.first { key in
                if let value = configuration.environment[key], !value.isEmpty {
                    return true
                }
                return false
            }

            if key != nil {
                return ProviderStatus(
                    descriptor: descriptor,
                    available: true,
                    resolvedPath: nil
                )
            }

            return ProviderStatus(
                descriptor: descriptor,
                available: false,
                reason: "Missing API key environment variable.",
                resolvedPath: nil
            )
        }
    }
}
