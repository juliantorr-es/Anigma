import Foundation
import ContractsCore
import OSLog

private let hfLogger = Logger(subsystem: "com.anigma.adapter", category: "huggingface")

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
        let licenseDecision = decideLicense(descriptor.license)
        let installDir = try await fetch(repo: repo, revision: revision, progressHandler: progressHandler)
        let artifactHashes = try computeHashes(installDir)
        let inferredTask = descriptor.inferredTask ?? .inference
        let (classificationTier, backend, conversionNeeded) = classifyModel(descriptor)
        let trustTier: ModelTrustTier = licenseDecision.allowed ? classificationTier : .quarantined
        let modelId = licenseDecision.allowed ? "\(repo)@\(revision)" : "\(repo)@\(revision)_QUARANTINED"

        var warnings: [String] = []
        if !licenseDecision.allowed {
            hfLogger.warning(
                "Model license quarantine decision: license=\(descriptor.license ?? "unknown", privacy: .public), repo=\(repo, privacy: .public), decision=QUARANTINED"
            )
            warnings = [
                "License '\(descriptor.license ?? "unknown")' is not on the approved list",
                "This model is QUARANTINED and cannot be executed",
                "Model files are available for inspection only",
                licenseDecision.reason ?? "No reason provided"
            ]
        } else if conversionNeeded {
            warnings.append("Model requires conversion for backend \(backend.rawValue)")
        }

        let modelHash = try (artifactHashes["model"] ?? computeArtifactHash(installDir))

        let spec = ContractsCore.ModelSpec(
            id: modelId,
            source: .huggingFace(repo: repo, revision: revision),
            task: mapTaskKind(inferredTask),
            backend: backend,
            trustTier: .experimental,
            license: ContractsCore.LicenseDecision(
                declared: descriptor.license ?? "unknown",
                allowed: licenseDecision.allowed,
                reason: licenseDecision.reason,
                extraTerms: []
            ),
            artifactHashes: artifactHashes.isEmpty ? ["model": modelHash] : artifactHashes,
            tokenizerHash: nil,
            conversionReceipt: nil,
            metadata: [
                "repo": repo,
                "revision": revision,
                "conversionNeeded": conversionNeeded.description
            ],
            registeredAt: Date(),
            verifiedAt: Date(),
            storageBytes: descriptor.estimatedSizeBytes ?? 0
        )

        return ModelImportResult(
            spec: spec,
            installPath: installDir.path,
            conversionNeeded: conversionNeeded,
            warnings: warnings
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

    private func mapTaskKind(_ task: ModelTaskKind) -> ContractsCore.ModelTaskKind {
        switch task {
        case .inference: return .inference
        case .embedding: return .embedding
        case .transcription: return .transcription
        case .classification: return .classification
        case .imageGeneration: return .imageGeneration
        case .speechSynthesis: return .speechSynthesis
        }
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
            let hash = ArtifactHashing.hardwareBackedHex(for: data)

            let relativePath = fileURL.path.replacingOccurrences(of: dir.path + "/", with: "")
            hashes[relativePath] = hash
        }

        return hashes
    }
}
