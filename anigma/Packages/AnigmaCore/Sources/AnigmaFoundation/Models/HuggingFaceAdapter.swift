//
//  HuggingFaceAdapter.swift
//  AnigmaCore
//
//  Source adapter for HuggingFace Hub: fetch, verify, describe models.
//  Consolidated from multiple implementations.
//

import Foundation
import ContractsCore
import AnigmaPrimitives
#if canImport(CryptoKit)
import CryptoKit
#endif

/// HuggingFace Hub source adapter - fetch/verify/describe
public actor HuggingFaceAdapter {
    private let cacheDir: URL
    private let httpClient: URLSession
    private let allowedLicenses: Set<String>

    public init(cacheDir: URL, allowedLicenses: Set<String>? = nil) {
        self.cacheDir = cacheDir
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
        let hasSafetensors = files.contains { $0.hasSuffix(".safetensors") }
        let hasMLX = files.contains { $0.contains("mlx") } || hasSafetensors

        return HFModelDescriptor(
            repoId: repo,
            revision: effectiveRevision,
            inferredTask: inferredTask,
            compatibleBackends: backends,
            license: repoInfo.license,
            safetensors: hasSafetensors,
            gguf: hasGGUF,
            mlx: hasMLX,
            estimatedSizeBytes: nil,
            tags: repoInfo.tags
        )
    }

    /// Fetch model from HuggingFace, verify, and return import result
    public func fetchAndVerify(repo: String, revision: String? = nil, progressHandler: (@Sendable (Double) -> Void)? = nil) async throws -> ModelImportResult {
        let effectiveRevision = revision ?? "main"
        let descriptor = try await describe(repo: repo, revision: effectiveRevision)

        // License gate
        let licenseDecision = evaluateLicense(declared: descriptor.license)
        
        // Download path
        let installPath = cacheDir.appendingPathComponent(repo.replacingOccurrences(of: "/", with: "_"))
        try FileManager.default.createDirectory(at: installPath, withIntermediateDirectories: true)

        let files = try await listRepoFiles(repo: repo, revision: effectiveRevision)
        var artifactHashes: [String: String] = [:]
        var downloadedFiles = 0
        
        let filteredFiles = files.filter { shouldDownload($0) }

        for file in filteredFiles {
            let destination = installPath.appendingPathComponent(file)
            
            // Check if already exists and hash matches
            if FileManager.default.fileExists(atPath: destination.path) {
                let existingHash = try await computeFileSHA256(url: destination)
                // In a real implementation, we'd check if this matches the remote hash if available
                artifactHashes[file] = existingHash
            } else {
                let fileURL = try await downloadFile(
                    repo: repo,
                    revision: effectiveRevision,
                    path: file,
                    destination: destination
                )
                let hash = try await computeFileSHA256(url: fileURL)
                artifactHashes[file] = hash
            }

            downloadedFiles += 1
            progressHandler?(Double(downloadedFiles) / Double(filteredFiles.count))
        }

        let trustTier: ModelTrustTier = licenseDecision.allowed ? (descriptor.isRunnable ? .compatible : .experimental) : .quarantined

        let spec = ModelSpec(
            id: "\(repo)@\(effectiveRevision)".replacingOccurrences(of: "/", with: "_"),
            source: .huggingFace(repo: repo, revision: effectiveRevision),
            task: descriptor.inferredTask ?? .inference,
            backend: descriptor.compatibleBackends.first ?? .mlx,
            trustTier: trustTier,
            license: licenseDecision,
            artifactHashes: artifactHashes,
            tokenizerHash: nil,
            conversionReceipt: nil,
            metadata: [
                "hf_tags": descriptor.tags.joined(separator: ","),
                "hf_safetensors": String(descriptor.safetensors),
                "hf_gguf": String(descriptor.gguf),
                "hf_mlx": String(descriptor.mlx)
            ],
            storageBytes: 0
        )

        return ModelImportResult(
            spec: spec,
            installPath: installPath.path,
            conversionNeeded: !descriptor.mlx && !descriptor.gguf,
            warnings: descriptor.isRunnable ? [] : ["Model format not directly runnable"]
        )
    }

    // MARK: - Private

    private func fetchRepoMetadata(repo: String) async throws -> HFRepoInfo {
        guard let url = URL(string: "https://huggingface.co/api/models/\(repo)") else {
            throw HFError.invalidURL(repo)
        }
        let (data, response) = try await httpClient.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw HFError.repoNotFound(repo)
        }
        return try JSONDecoder().decode(HFRepoInfo.self, from: data)
    }

    private func listRepoFiles(repo: String, revision: String) async throws -> [String] {
        guard let url = URL(string: "https://huggingface.co/api/models/\(repo)/tree/\(revision)") else {
            throw HFError.invalidURL(repo)
        }
        let (data, response) = try await httpClient.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw HFError.fetchFailed("Failed to list files for \(repo)")
        }
        let tree = try JSONDecoder().decode([HFFileEntry].self, from: data)
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

        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: tempURL, to: destination)

        return destination
    }

    private func inferTaskKind(from info: HFRepoInfo) -> ModelTaskKind? {
        if let pipelineTag = info.pipelineTag {
            switch pipelineTag {
            case "text-generation", "text2text-generation": return .inference
            case "feature-extraction", "sentence-similarity": return .embedding
            case "automatic-speech-recognition": return .transcription
            case "text-classification": return .classification
            default: break
            }
        }
        return nil
    }

    private func detectCompatibleBackends(files: [String]) -> [MLBackend] {
        var backends: [MLBackend] = []
        if files.contains(where: { $0.hasSuffix(".gguf") }) { backends.append(.gguf) }
        if files.contains(where: { $0.hasSuffix(".safetensors") }) { backends.append(.mlx) }
        if files.contains(where: { $0.hasSuffix(".mlpackage") }) { backends.append(.coreml) }
        return backends
    }

    private func evaluateLicense(declared: String?) -> LicenseDecision {
        let license = declared ?? "unknown"
        let allowed = allowedLicenses.contains(license.lowercased())
        return LicenseDecision(declared: license, allowed: allowed, reason: allowed ? nil : "License not in allowlist", timestamp: Date())
    }

    private func shouldDownload(_ path: String) -> Bool {
        let essential = [".gguf", ".safetensors", ".bin", ".json", ".txt", ".model"]
        return essential.contains { path.hasSuffix($0) } && !path.contains(".git")
    }

    /// Compute SHA256 hash of a file or directory.
    public func computeModelHash(at url: URL) async throws -> String {
        if FileManager.default.fileExists(atPath: url.path) {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                // For directory, hash all files and then hash the combined hashes
                let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
                var hashes: [String] = []
                while let fileURL = enumerator?.nextObject() as? URL {
                    let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                    if values.isRegularFile == true {
                        hashes.append(try await computeFileSHA256(url: fileURL))
                    }
                }
                let combined = hashes.sorted().joined().data(using: .utf8)!
                return SHA256.hash(data: combined).map { String(format: "%02x", $0) }.joined()
            } else {
                return try await computeFileSHA256(url: url)
            }
        }
        throw HFError.fetchFailed("Model path not found: \(url.path)")
    }

    private func computeFileSHA256(url: URL) async throws -> String {
        let data = try Data(contentsOf: url)
        #if canImport(CryptoKit)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
        #else
        return "sha256:unsupported"
        #endif
    }
}

// MARK: - Supporting Types

private struct HFRepoInfo: Codable {
    let modelId: String
    let tags: [String]
    let pipelineTag: String?
    let license: String?
    enum CodingKeys: String, CodingKey {
        case modelId = "id", tags, license
        case pipelineTag = "pipeline_tag"
    }
}

private struct HFFileEntry: Codable {
    let path: String
    let type: String
}

public enum HFError: Error {
    case repoNotFound(String)
    case fetchFailed(String)
    case downloadFailed(String)
    case invalidURL(String)
}

private let defaultAllowedLicenses: Set<String> = ["apache-2.0", "mit", "bsd-3-clause", "openrail", "llama2", "llama3"]
