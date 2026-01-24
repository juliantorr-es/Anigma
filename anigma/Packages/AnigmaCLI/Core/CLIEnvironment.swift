//
//  CLIEnvironment.swift
//  AnigmaCLICore
//
//  Helpers for building CLI-wide environments that merge process defaults with Keychain-backed secrets.
//

import Foundation

public struct CLIEnvironment {
    private static let providerSecretKeys: [String] = [
        "OPENAI_API_KEY",
        "ANTHROPIC_API_KEY",
        "DEEPSEEK_API_KEY",
        "GOOGLE_API_KEY",
        "GEMINI_API_KEY",
        "VERCEL_API_KEY",
        "VERCEL_AI_API_KEY",
        "HUGGINGFACE_API_TOKEN",
        "HF_TOKEN",
        "OLLAMA_API_KEY",
        "OLLAMA_CLOUD_TOKEN",
        "AZURE_OPENAI_API_KEY",
        "AWS_ACCESS_KEY_ID",
        "GROQ_API_KEY"
    ]

    public static func defaultBaseDirectory() -> URL {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let dir = homeDir.appendingPathComponent(".anigma")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public static var defaultConfigPath: URL {
        defaultBaseDirectory().appendingPathComponent("config.json")
    }

    public static func mergedEnvironment(
        with overrides: [String: String] = [:],
        baseDirectory: URL = defaultBaseDirectory()
    ) async -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        overrides.forEach { environment[$0] = $1 }

        for key in providerSecretKeys {
            let currentValue = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard currentValue?.isEmpty ?? true else {
                continue
            }

            if let storedValue = try? await KeychainStore.retrieve(key: key, fallbackDirectory: baseDirectory),
               !storedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                environment[key] = storedValue.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return environment
    }
}
