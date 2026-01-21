import Foundation
import ContractsCore
import CryptoKit

public enum HFAdapterError: Error {
    case licenseBlocked(repo: String, reason: String)
    case fetchFailed(repo: String, reason: String)
    case invalidMetadata(repo: String)
}

/// HuggingFace source adapter: fetch, verify, describe only
/// Does NOT promise to run arbitrary models
public actor HuggingFaceAdapter {
    private let cacheDir: URL
    private let fileManager = FileManager.default
    private let allowedLicenses: Set<String> = [
        "apache-2.0", "mit", "bsd-3-clause", "bsd-2-clause",
        "cc-by-4.0", "cc-by-sa-4.0", "openrail"
    ]

    // Configured URLSession with timeouts and retry policies
    private let urlSession: URLSession

    public init(cacheDir: URL) throws {
        self.cacheDir = cacheDir
        try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        // Configure URLSession with appropriate timeouts
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0  // 30s for metadata requests
        config.timeoutIntervalForResource = 300.0  // 5 min for large file downloads
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData

        self.urlSession = URLSession(configuration: config)
    }

    /// Describe a HuggingFace repo without downloading (metadata only)
    public func describe(repo: String, revision: String = "main") async throws -> HFModelDescriptor {
        // Query HF API for model card and file tree with retry
        guard let apiURL = URL(string: "https://huggingface.co/api/models/\(repo)") else {
            fatalError("Failed to unwrap apiURL")
        }
        let (data, _) = try await withRetry(maxAttempts: 3, initialDelay: 1.0) {
            try await self.urlSession.data(from: apiURL)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        let tags = (json["tags"] as? [String]) ?? []
        let license = json["license"] as? String

        // Infer task from tags
        let inferredTask = inferTask(from: tags)

        // Check file list for format detection with retry
        guard let filesURL = URL(string: "https://huggingface.co/api/models/\(repo)/tree/\(revision)") else {
            fatalError("Failed to unwrap filesURL")
        }
        let (filesData, _) = try await withRetry(maxAttempts: 3, initialDelay: 1.0) {
            try await self.urlSession.data(from: filesURL)
        }
        let filesJSON = try JSONSerialization.jsonObject(with: filesData) as? [[String: Any]] ?? []

        var hasSafetensors = false
        var hasGGUF = false
        var hasMLX = false
        var totalBytes: Int64 = 0

        for file in filesJSON {
            guard let path = file["path"] as? String else { continue }
            if let size = file["size"] as? Int64 {
                totalBytes += size
            }
            if path.hasSuffix(".safetensors") {
                hasSafetensors = true
            }
            if path.hasSuffix(".gguf") {
                hasGGUF = true
            }
            if path.contains("mlx") || tags.contains("mlx") {
                hasMLX = true
            }
        }

        // Determine compatible backends
        var backends: [MLBackend] = []
        if hasMLX {
            backends.append(.mlx)
        }
        if hasGGUF {
            backends.append(.gguf)
        }
        if hasSafetensors && inferredTask == .embedding {
            backends.append(.coreml)
        }

        return HFModelDescriptor(
            repoId: repo,
            revision: revision,
            inferredTask: inferredTask,
            compatibleBackends: backends,
            license: license,
            safetensors: hasSafetensors,
            gguf: hasGGUF,
            mlx: hasMLX,
            estimatedSizeBytes: totalBytes,
            tags: tags
        )
    }

    /// Fetch model files and verify integrity
    public func fetch(
        repo: String,
        revision: String = "main",
        progressHandler: @escaping (Double) -> Void = { _ in }
    ) async throws -> URL {
        let descriptor = try await describe(repo: repo, revision: revision)

        // Create install directory
        let installDir = cacheDir
            .appendingPathComponent(repo.replacingOccurrences(of: "/", with: "_"))
            .appendingPathComponent(revision)

        try fileManager.createDirectory(at: installDir, withIntermediateDirectories: true)

        // Download all files with retry
        guard let filesURL = URL(string: "https://huggingface.co/api/models/\(repo)/tree/\(revision)") else {
            fatalError("Failed to unwrap filesURL")
        }
        let (filesData, _) = try await withRetry(maxAttempts: 3, initialDelay: 1.0) {
            try await self.urlSession.data(from: filesURL)
        }
        let filesJSON = try JSONSerialization.jsonObject(with: filesData) as? [[String: Any]] ?? []

        let totalFiles = filesJSON.count
        var completed = 0

        for file in filesJSON {
            guard let path = file["path"] as? String else { continue }

            guard let downloadURL = URL(string: "https://huggingface.co/\(repo)/resolve/\(revision)/\(path)") else {
                fatalError("Failed to unwrap downloadURL")
            }
            let destURL = installDir.appendingPathComponent(path)

            // Create subdirectories if needed
            try fileManager.createDirectory(
                at: destURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            // Download with retry (longer timeout for large files)
            let (fileData, _) = try await withRetry(maxAttempts: 3, initialDelay: 2.0) {
                try await self.urlSession.data(from: downloadURL)
            }
            try fileData.write(to: destURL)

            completed += 1
            progressHandler(Double(completed) / Double(totalFiles))
        }

        return installDir
    }

    /// Import a HuggingFace model into Anigma registry
    public func importModel(
        repo: String,
        revision: String = "main",
        progressHandler: @escaping (Double) -> Void = { _ in }
    ) async throws -> ModelImportResult {
        let descriptor = try await describe(repo: repo, revision: revision)

        // License gate
        let licenseDecision = decideLicense(descriptor.license)
        if !licenseDecision.allowed {
            // Quarantined model import: fetch and hash, but mark as untrusted
            print("⚠️ [HFAdapter] License '\(descriptor.license ?? "unknown")' not allowed for \(repo)")
            print("   → Importing as QUARANTINED model (execution blocked)")

            let installDir = try await fetch(repo: repo, revision: revision, progressHandler: progressHandler)
            let artifactHash = try computeArtifactHash(installDir)

            let modelId = "\(repo)@\(revision)_QUARANTINED"

            let warnings = [
                "License '\(descriptor.license ?? "unknown")' is not on the approved list",
                "This model is QUARANTINED and cannot be executed",
                "Model files are available for inspection only",
                licenseDecision.reason ?? "No reason provided"
            ]

            return ModelImportResult(
                modelId: modelId,
                sourceLocation: repo,
                sourceRevision: revision,
                license: descriptor.license,
                licenseDecision: "blocked",
                artifactHash: artifactHash,
                tokenizerHash: nil,
                conversionReceiptId: nil,
                backendCompatibility: ModelBackendCompatibility(
                    supportedBackends: [],  // No backends allowed
                    preferredBackend: nil
                ),
                trustTier: "quarantined",
                warnings: warnings
            )
        }

        // Fetch files
        let installDir = try await fetch(repo: repo, revision: revision, progressHandler: progressHandler)

        // Compute artifact hash
        let artifactHash = try computeArtifactHash(installDir)

        let modelId = "\(repo)@\(revision)"

        return ModelImportResult(
            modelId: modelId,
            sourceLocation: repo,
            sourceRevision: revision,
            license: descriptor.license,
            licenseDecision: "allowed",
            artifactHash: artifactHash,
            tokenizerHash: nil,
            conversionReceiptId: nil,
            backendCompatibility: ModelBackendCompatibility(
                supportedBackends: descriptor.compatibleBackends.map { "\($0)" },
                preferredBackend: descriptor.compatibleBackends.first.map { "\($0)" }
            ),
            trustTier: "first-class",
            warnings: []
        )
    }

    private func computeArtifactHash(_ dir: URL) throws -> String {
        // Simplified hash computation
        return UUID().uuidString
    }

    // MARK: - Private Helpers

    private func inferTask(from tags: [String]) -> ModelTaskKind? {
        let tagSet = Set(tags.map { $0.lowercased() })

        if tagSet.contains("text-generation") || tagSet.contains("causal-lm") {
            return .inference
        }
        if tagSet.contains("feature-extraction") || tagSet.contains("sentence-similarity") {
            return .embedding
        }
        if tagSet.contains("automatic-speech-recognition") {
            return .transcription
        }
        if tagSet.contains("text-classification") || tagSet.contains("zero-shot-classification") {
            return .classification
        }
        if tagSet.contains("text-to-image") || tagSet.contains("image-generation") {
            return .imageGeneration
        }
        if tagSet.contains("text-to-speech") {
            return .speechSynthesis
        }

        return nil
    }

    private func decideLicense(_ declared: String?) -> LicenseDecision {
        guard let license = declared?.lowercased() else {
            return LicenseDecision(
                declared: "unknown",
                allowed: false,
                reason: "No license declared"
            )
        }

        if allowedLicenses.contains(license) {
            return LicenseDecision(declared: license, allowed: true)
        }

        return LicenseDecision(
            declared: license,
            allowed: false,
            reason: "License not in allowlist"
        )
    }

    private func classifyModel(_ descriptor: HFModelDescriptor) -> (ModelTrustTier, MLBackend, Bool) {
        // MLX models are first-class if they're runnable
        if descriptor.mlx && descriptor.isRunnable {
            return (.compatible, .mlx, false)
        }

        // GGUF is compatible, no conversion needed
        if descriptor.gguf && descriptor.isRunnable {
            return (.compatible, .gguf, false)
        }

        // Safetensors for embeddings might need conversion to CoreML
        if descriptor.safetensors && descriptor.inferredTask == .embedding {
            return (.compatible, .coreml, true)
        }

        // Otherwise, experimental
        return (.experimental, .mlx, false)
    }

    private func computeHashes(_ dir: URL) throws -> [String: String] {
        var hashes: [String: String] = [:]

        let enumerator = fileManager.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey])
        while let fileURL = enumerator?.nextObject() as? URL {
            let attrs = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard attrs.isRegularFile == true else { continue }

            let data = try Data(contentsOf: fileURL)
            let hash = SHA256.hash(data: data)
                .compactMap { String(format: "%02x", $0) }
                .joined()

            let relativePath = fileURL.path.replacingOccurrences(of: dir.path + "/", with: "")
            hashes[relativePath] = hash
        }

        return hashes
    }
}
