//
//  HuggingFaceAdapter.swift
//  ModelRegistry
//
//  Source adapter for HuggingFace Hub: fetch, verify, describe only.
//  Does NOT promise to run every model - just ingest and classify safely.
//

import Foundation
import ContractsCore

/// HuggingFace Hub source adapter - fetch/verify/describe, not "run everything"
public actor HuggingFaceAdapter {
    private let artifactStore: URL
    private let httpClient: URLSession
    private let allowedLicenses: Set<String>

    public init(artifactStore: URL, allowedLicenses: Set<String>? = nil) {
        self.artifactStore = artifactStore
        self.httpClient = URLSession.shared
        self.allowedLicenses = allowedLicenses ?? defaultAllowedLicenses
    }

    // MARK: - Public API

    /// Describe a HuggingFace repo without downloading
    public func describe(repo: String, revision: String? = nil) async throws -> HFModelDescriptor {
        let effectiveRevision = revision ?? "main"
        let repoInfo = try await fetchRepoMetadata(repo: repo)

        // Infer task from tags and model metadata
        let inferredTask = inferTaskKind(from: repoInfo)

        // Detect compatible backends by scanning file list
        let files = try await listRepoFiles(repo: repo, revision: effectiveRevision)
        let backends = detectCompatibleBackends(files: files)

        let hasGGUF = files.contains { $0.hasSuffix(".gguf") }
        let hasMLX = files.contains { $0.contains("mlx") || $0.hasSuffix(".safetensors") }
        let hasSafetensors = files.contains { $0.hasSuffix(".safetensors") }

        return HFModelDescriptor(
            repoId: repo,
            revision: effectiveRevision,
            inferredTask: inferredTask,
            compatibleBackends: backends,
            license: repoInfo.license,
            safetensors: hasSafetensors,
            gguf: hasGGUF,
            mlx: hasMLX,
            estimatedSizeBytes: nil, // Would require HEAD requests on all files
            tags: repoInfo.tags
        )
    }

    /// Fetch model from HuggingFace, verify, and return import result
    public func fetchAndVerify(repo: String, revision: String? = nil, progressHandler: ((Double) -> Void)? = nil) async throws -> ModelImportResult {
        let effectiveRevision = revision ?? "main"
        let descriptor = try await describe(repo: repo, revision: effectiveRevision)

        // License gate - enforce at import time
        let licenseDecision = evaluateLicense(declared: descriptor.license)
        guard licenseDecision.allowed else {
            // Store but quarantine
            let spec = try await buildModelSpec(
                descriptor: descriptor,
                revision: effectiveRevision,
                artifactHashes: [:],
                licenseDecision: licenseDecision,
                trustTier: .quarantined
            )
            return ModelImportResult(
                spec: spec,
                installPath: "",
                conversionNeeded: false,
                warnings: ["Model quarantined: \(licenseDecision.reason ?? "license not allowed")"]
            )
        }

        // Download files
        let installPath = artifactStore.appendingPathComponent(repo.replacingOccurrences(of: "/", with: "_"))
        try FileManager.default.createDirectory(at: installPath, withIntermediateDirectories: true)

        let files = try await listRepoFiles(repo: repo, revision: effectiveRevision)
        var artifactHashes: [String: String] = [:]
        var downloadedFiles = 0

        for file in files {
            // Skip non-essential files
            guard shouldDownload(file) else { continue }

            let fileURL = try await downloadFile(
                repo: repo,
                revision: effectiveRevision,
                path: file,
                destination: installPath.appendingPathComponent(file)
            )

            // Compute and store hash
            let hash = try await computeFileSHA256(url: fileURL)
            artifactHashes[file] = hash

            downloadedFiles += 1
            progressHandler?(Double(downloadedFiles) / Double(files.count))
        }

        // Determine trust tier and conversion needs
        let trustTier: ModelTrustTier = descriptor.isRunnable ? .compatible : .experimental
        let conversionNeeded = !descriptor.mlx && !descriptor.gguf

        let spec = try await buildModelSpec(
            descriptor: descriptor,
            revision: effectiveRevision,
            artifactHashes: artifactHashes,
            licenseDecision: licenseDecision,
            trustTier: trustTier
        )

        var warnings: [String] = []
        if !descriptor.isRunnable {
            warnings.append("Model format not directly runnable - marked experimental")
        }
        if conversionNeeded {
            warnings.append("Conversion required before execution")
        }

        return ModelImportResult(
            spec: spec,
            installPath: installPath.path,
            conversionNeeded: conversionNeeded,
            warnings: warnings
        )
    }

    // MARK: - HuggingFace API Interaction

    private func fetchRepoMetadata(repo: String) async throws -> HFRepoInfo {
        guard let url = URL(string: "https://huggingface.co/api/models/\(repo)") else {
            fatalError("Failed to unwrap url")
        }
        let (data, response) = try await httpClient.data(from: url)

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw HFError.repoNotFound(repo)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(HFRepoInfo.self, from: data)
    }

    private func listRepoFiles(repo: String, revision: String) async throws -> [String] {
        guard let url = URL(string: "https://huggingface.co/api/models/\(repo)/tree/\(revision)") else {
            fatalError("Failed to unwrap url")
        }
        let (data, response) = try await httpClient.data(from: url)

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw HFError.fetchFailed("Failed to list files for \(repo)@\(revision)")
        }

        let decoder = JSONDecoder()
        let tree = try decoder.decode([HFFileEntry].self, from: data)
        return tree.filter { $0.type == "file" }.map { $0.path }
    }

    private func downloadFile(repo: String, revision: String, path: String, destination: URL) async throws -> URL {
        let urlString = "https://huggingface.co/\(repo)/resolve/\(revision)/\(path)"
        guard let url = URL(string: urlString) else {
            throw HFError.invalidURL(urlString)
        }

        let (tempURL, response) = try await httpClient.download(from: url)

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw HFError.downloadFailed(path)
        }

        // Move to destination
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: tempURL, to: destination)

        return destination
    }

    // MARK: - Classification Logic

    private func inferTaskKind(from info: HFRepoInfo) -> ModelTaskKind? {
        let tags = info.tags.map { $0.lowercased() }

        // Check pipeline tag first
        if let pipelineTag = info.pipelineTag {
            switch pipelineTag {
            case "text-generation", "text2text-generation":
                return .inference
            case "feature-extraction", "sentence-similarity":
                return .embedding
            case "automatic-speech-recognition":
                return .transcription
            case "text-classification", "image-classification":
                return .classification
            case "text-to-image", "image-to-image":
                return .imageGeneration
            case "text-to-speech":
                return .speechSynthesis
            default:
                break
            }
        }

        // Fallback to tag inference
        if tags.contains("text-generation") || tags.contains("causal-lm") {
            return .inference
        }
        if tags.contains("sentence-transformers") || tags.contains("feature-extraction") {
            return .embedding
        }
        if tags.contains("asr") || tags.contains("whisper") {
            return .transcription
        }
        if tags.contains("diffusion") || tags.contains("stable-diffusion") {
            return .imageGeneration
        }
        if tags.contains("tts") || tags.contains("text-to-speech") {
            return .speechSynthesis
        }

        return nil
    }

    private func detectCompatibleBackends(files: [String]) -> [MLBackend] {
        var backends: [MLBackend] = []

        // GGUF → llama.cpp backend
        if files.contains(where: { $0.hasSuffix(".gguf") }) {
            backends.append(.gguf)
        }

        // Safetensors could be MLX-compatible if it's a supported architecture
        if files.contains(where: { $0.hasSuffix(".safetensors") }) {
            backends.append(.mlx)
        }

        // CoreML models
        if files.contains(where: { $0.hasSuffix(".mlpackage") || $0.hasSuffix(".mlmodel") }) {
            backends.append(.coreml)
        }

        return backends
    }

    private func evaluateLicense(declared: String?) -> LicenseDecision {
        guard let license = declared else {
            return LicenseDecision(
                declared: "unknown",
                allowed: false,
                reason: "No license declared",
                timestamp: Date()
            )
        }

        let normalizedLicense = license.lowercased()
        let allowed = allowedLicenses.contains(normalizedLicense)

        return LicenseDecision(
            declared: license,
            allowed: allowed,
            reason: allowed ? nil : "License '\(license)' not in allowlist",
            timestamp: Date()
        )
    }

    private func shouldDownload(_ path: String) -> Bool {
        // Download model weights, tokenizer, config
        let essentialExtensions = [".gguf", ".safetensors", ".bin", ".json", ".txt", ".model", ".tiktoken"]
        let skipPatterns = [".md", ".gitattributes", ".git", "flax_model", "tf_model", "pytorch_model.bin.index"]

        // Skip README and git metadata
        if skipPatterns.contains(where: { path.contains($0) }) {
            return false
        }

        return essentialExtensions.contains { path.hasSuffix($0) }
    }

    private func buildModelSpec(
        descriptor: HFModelDescriptor,
        revision: String,
        artifactHashes: [String: String],
        licenseDecision: LicenseDecision,
        trustTier: ModelTrustTier
    ) async throws -> ModelSpec {
        let backend: MLBackend = descriptor.compatibleBackends.first ?? .mlx
        let task = descriptor.inferredTask ?? .inference

        let modelId = "\(descriptor.repoId)@\(revision)".replacingOccurrences(of: "/", with: "_")

        return ModelSpec(
            id: modelId,
            source: .huggingFace(repo: descriptor.repoId, revision: revision),
            task: task,
            backend: backend,
            trustTier: trustTier,
            license: licenseDecision,
            artifactHashes: artifactHashes,
            tokenizerHash: nil, // Computed separately if needed
            conversionReceipt: nil,
            metadata: [
                "hf_tags": descriptor.tags.joined(separator: ","),
                "hf_safetensors": String(descriptor.safetensors),
                "hf_gguf": String(descriptor.gguf),
                "hf_mlx": String(descriptor.mlx)
            ],
            storageBytes: 0 // Will be updated by registry
        )
    }

    private func computeFileSHA256(url: URL) async throws -> String {
        let data = try Data(contentsOf: url)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - HuggingFace API Models

private struct HFRepoInfo: Codable {
    let modelId: String
    let tags: [String]
    let pipelineTag: String?
    let library: String?
    let license: String?

    private enum CodingKeys: String, CodingKey {
        case modelId, tags, library, license
        case pipelineTag = "pipeline_tag"
    }
}

private struct HFFileEntry: Codable {
    let path: String
    let type: String
    let size: Int64?
}

// MARK: - Errors

public enum HFError: Error {
    case repoNotFound(String)
    case fetchFailed(String)
    case downloadFailed(String)
    case invalidURL(String)
}

// MARK: - Default Allowed Licenses

private let defaultAllowedLicenses: Set<String> = [
    "apache-2.0",
    "mit",
    "bsd-3-clause",
    "bsd-2-clause",
    "cc-by-4.0",
    "cc-by-sa-4.0",
    "openrail",
    "llama2",
    "llama3",
    "gemma"
]

import CommonCrypto
