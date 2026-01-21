//
//  ModelIngestion.swift
//  HarmoniaModule
//
//  Automated model ingestion pipeline.
//  Handles download, conversion, validation, and registration.
//

import AnigmaCore
import Foundation

// MARK: - Model Source

/// Source for ingesting a model.
public enum ModelSource: Sendable {
    /// HuggingFace repository.
    case huggingFace(repo: String, revision: String?)

    /// Local file path.
    case localFile(URL)

    /// Remote URL.
    case remoteURL(URL)

    /// Ollama model name.
    case ollama(name: String)
}

/// Target format for model conversion.
public enum ConversionTarget: String, Sendable, CaseIterable {
    case gguf
    case mlx
    case coreml
    case ollama
    case remote
}

// MARK: - Ingestion Request

/// Request to ingest a model.
public struct IngestionRequest: Sendable, Identifiable {
    public let id: String
    public let source: ModelSource
    public let targetFormats: Set<ConversionTarget>
    public let tenantId: String
    public let priority: IngestionPriority
    public let metadata: IngestionMetadata

    public init(
        id: String = UUID().uuidString,
        source: ModelSource,
        targetFormats: Set<ConversionTarget> = [.gguf, .mlx],
        tenantId: String,
        priority: IngestionPriority = .normal,
        metadata: IngestionMetadata = IngestionMetadata()
    ) {
        self.id = id
        self.source = source
        self.targetFormats = targetFormats
        self.tenantId = tenantId
        self.priority = priority
        self.metadata = metadata
    }
}

/// Priority for ingestion.
public enum IngestionPriority: Int, Sendable, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case urgent = 3

    public static func < (lhs: IngestionPriority, rhs: IngestionPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Additional metadata for ingestion.
public struct IngestionMetadata: Sendable {
    public var displayName: String?
    public var description: String?
    public var tags: [String]
    public var qualityTierHint: QualityTier?
    public var taskHints: [InferenceTaskKind]

    public init(
        displayName: String? = nil,
        description: String? = nil,
        tags: [String] = [],
        qualityTierHint: QualityTier? = nil,
        taskHints: [InferenceTaskKind] = []
    ) {
        self.displayName = displayName
        self.description = description
        self.tags = tags
        self.qualityTierHint = qualityTierHint
        self.taskHints = taskHints
    }
}

// MARK: - Ingestion Result

/// Result of model ingestion.
public struct IngestionResult: Sendable {
    public let requestId: String
    public let status: IngestionStatus
    public let models: [ModelDescriptor]
    public let validationResults: [ModelValidationResult]
    public let benchmarkResults: BenchmarkResults?
    public let duration: Duration
    public let errors: [IngestionError]

    public var isSuccess: Bool {
        status == .completed && !models.isEmpty
    }
}

/// Status of ingestion.
public enum IngestionStatus: String, Sendable {
    case queued
    case downloading
    case converting
    case validating
    case benchmarking
    case registering
    case completed
    case failed
}

/// Validation result for a model.
public struct ModelValidationResult: Sendable {
    public let format: ConversionTarget
    public let passed: Bool
    public let checks: [ModelValidationCheck]
}

/// Individual validation check.
public struct ModelValidationCheck: Sendable {
    public let name: String
    public let passed: Bool
    public let message: String?
}

/// Benchmark results for a model.
public struct BenchmarkResults: Sendable {
    public let tokensPerSecond: Double
    public let timeToFirstToken: Duration
    public let memoryUsage: Int
    public let qualityScore: Double?
}

/// Errors during ingestion.
public enum IngestionError: Error, LocalizedError, Sendable {
    case downloadFailed(reason: String)
    case conversionFailed(format: ConversionTarget, reason: String)
    case validationFailed(reason: String)
    case registrationFailed(reason: String)
    case unsupportedSource
    case tenantQuotaExceeded
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .conversionFailed(let format, let reason):
            return "Conversion to \(format) failed: \(reason)"
        case .validationFailed(let reason):
            return "Validation failed: \(reason)"
        case .registrationFailed(let reason):
            return "Registration failed: \(reason)"
        case .unsupportedSource:
            return "Unsupported model source"
        case .tenantQuotaExceeded:
            return "Tenant model quota exceeded"
        case .cancelled:
            return "Ingestion cancelled"
        }
    }
}

// MARK: - Model Ingestion Service

/// Service for automated model ingestion.
public actor ModelIngestionService {
    private let registry: ModelRegistry
    private let storageRoot: URL
    private var queue: [IngestionRequest] = []
    private var inProgress: [String: IngestionStatus] = [:]
    private var completed: [String: IngestionResult] = [:]
    private let maxConcurrent = 2

    public init(registry: ModelRegistry, storageRoot: URL? = nil) {
        self.registry = registry
        self.storageRoot =
            storageRoot
            ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("anigma-models")
    }

    // MARK: - Queue Management

    /// Submits an ingestion request.
    public func submit(_ request: IngestionRequest) async -> String {
        queue.append(request)
        queue.sort { $0.priority > $1.priority }

        // Trigger processing
        Task {
            await processQueue()
        }

        return request.id
    }

    /// Gets the status of an ingestion request.
    public func status(for requestId: String) -> IngestionStatus? {
        if let result = completed[requestId] {
            return result.status
        }
        return inProgress[requestId]
    }

    /// Gets the result of a completed ingestion.
    public func result(for requestId: String) -> IngestionResult? {
        completed[requestId]
    }

    /// Cancels a queued ingestion.
    public func cancel(_ requestId: String) -> Bool {
        if let idx = queue.firstIndex(where: { $0.id == requestId }) {
            queue.remove(at: idx)
            return true
        }
        return false
    }

    // MARK: - Processing

    private func processQueue() async {
        while !queue.isEmpty && inProgress.count < maxConcurrent {
            let request = queue.removeFirst()
            inProgress[request.id] = .queued

            let result = await processRequest(request)
            completed[request.id] = result
            inProgress.removeValue(forKey: request.id)
        }
    }

    private func processRequest(_ request: IngestionRequest) async -> IngestionResult {
        let startTime = ContinuousClock.now
        var models: [ModelDescriptor] = []
        var validations: [ModelValidationResult] = []
        var errors: [IngestionError] = []
        var benchmarks: BenchmarkResults?

        // Step 1: Download
        inProgress[request.id] = .downloading
        let downloadResult = await download(source: request.source, tenantId: request.tenantId)

        guard case .success(let downloadedPath) = downloadResult else {
            if case .failure(let error) = downloadResult {
                errors.append(error)
            }
            return IngestionResult(
                requestId: request.id,
                status: .failed,
                models: [],
                validationResults: [],
                benchmarkResults: nil,
                duration: ContinuousClock.now - startTime,
                errors: errors
            )
        }

        // Step 2: Convert to target formats
        inProgress[request.id] = .converting
        for format in request.targetFormats {
            let convertResult = await convert(
                path: downloadedPath,
                to: format,
                request: request
            )

            switch convertResult {
            case .success(let descriptor):
                models.append(descriptor)
            case .failure(let error):
                errors.append(error)
            }
        }

        // Step 3: Validate
        inProgress[request.id] = .validating
        for model in models {
            let validation = await validate(model: model)
            validations.append(validation)
        }

        // Filter to only validated models
        let validModels = zip(models, validations)
            .filter { $0.1.passed }
            .map { $0.0 }

        // Step 4: Benchmark (optional, on first valid model)
        if let firstModel = validModels.first {
            inProgress[request.id] = .benchmarking
            benchmarks = await benchmark(model: firstModel)
        }

        // Step 5: Register
        inProgress[request.id] = .registering
        for model in validModels {
            await registry.register(model)
        }

        let finalStatus: IngestionStatus = validModels.isEmpty ? .failed : .completed

        return IngestionResult(
            requestId: request.id,
            status: finalStatus,
            models: validModels,
            validationResults: validations,
            benchmarkResults: benchmarks,
            duration: ContinuousClock.now - startTime,
            errors: errors
        )
    }

    // MARK: - Download

    private func download(source: ModelSource, tenantId: String) async -> Result<
        URL, IngestionError
    > {
        let tenantDir = storageRoot.appendingPathComponent(tenantId)

        do {
            try FileManager.default.createDirectory(
                at: tenantDir, withIntermediateDirectories: true)
        } catch {
            return .failure(.downloadFailed(reason: "Cannot create storage directory"))
        }

        switch source {
        case .localFile(let url):
            // Just verify it exists
            if FileManager.default.fileExists(atPath: url.path) {
                return .success(url)
            } else {
                return .failure(.downloadFailed(reason: "File not found"))
            }

        case .huggingFace(let repo, _):
            return .failure(
                .downloadFailed(reason: "HuggingFace download not configured for repo \(repo)"))

        case .remoteURL(let url):
            let filename = url.lastPathComponent
            let localPath = tenantDir.appendingPathComponent(filename)
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                try data.write(to: localPath, options: [.atomic])
                return .success(localPath)
            } catch {
                return .failure(
                    .downloadFailed(reason: "Download failed: \(error.localizedDescription)"))
            }

        case .ollama(let name):
            // For Ollama, no download needed - it manages its own
            let placeholderPath = tenantDir.appendingPathComponent("ollama_\(name).ref")
            FileManager.default.createFile(atPath: placeholderPath.path, contents: nil)
            return .success(placeholderPath)
        }
    }

    // MARK: - Conversion

    private func convert(
        path: URL,
        to format: ConversionTarget,
        request: IngestionRequest
    ) async -> Result<ModelDescriptor, IngestionError> {
        // In a real implementation, this would:
        // - For GGUF: run llama.cpp quantization
        // - For MLX: run mlx-lm conversion
        // - For CoreML: run coremltools conversion
        // - For Ollama: create modelfile and import

        let modelId = generateModelId(source: request.source, format: format)
        let outputPath = path.deletingLastPathComponent()
            .appendingPathComponent("\(modelId).\(format.rawValue)")

        if format == .remote {
            // Remote models are referenced directly
        } else {
            do {
                if FileManager.default.fileExists(atPath: outputPath.path) {
                    try FileManager.default.removeItem(at: outputPath)
                }
                try FileManager.default.copyItem(at: path, to: outputPath)
            } catch {
                return .failure(
                    .conversionFailed(
                        format: format,
                        reason: "Failed to stage model: \(error.localizedDescription)"))
            }
        }

        let descriptor = ModelDescriptor(
            id: modelId,
            displayName: request.metadata.displayName ?? modelId,
            family: extractFamily(from: request.source),
            version: "1.0",
            backend: backendForFormat(format),
            format: modelFormat(format),
            capabilities: inferCapabilities(request: request),
            resources: estimateResources(format: format),
            storageLocation: format == .remote ? path : outputPath
        )

        return .success(descriptor)
    }

    private func generateModelId(source: ModelSource, format: ConversionTarget) -> String {
        let base: String
        switch source {
        case .huggingFace(let repo, _):
            base = repo.split(separator: "/").last.map(String.init) ?? "unknown"
        case .localFile(let url):
            base = url.deletingPathExtension().lastPathComponent
        case .remoteURL(let url):
            base = url.deletingPathExtension().lastPathComponent
        case .ollama(let name):
            base = name
        }
        return "\(base)-\(format.rawValue)"
    }

    private func extractFamily(from source: ModelSource) -> String {
        switch source {
        case .huggingFace(let repo, _):
            let name = repo.lowercased()
            if name.contains("llama") { return "llama" }
            if name.contains("phi") { return "phi" }
            if name.contains("deepseek") { return "deepseek" }
            if name.contains("qwen") { return "qwen" }
            if name.contains("mistral") { return "mistral" }
            return "unknown"
        case .ollama(let name):
            return name.split(separator: ":").first.map(String.init) ?? name
        default:
            return "unknown"
        }
    }

    private func backendForFormat(_ format: ConversionTarget) -> BackendKind {
        switch format {
        case .gguf: return .llamaCpp
        case .mlx: return .mlx
        case .coreml: return .mlx  // CoreML often used with MLX
        case .ollama: return .ollama
        case .remote: return .remoteAPI
        }
    }

    private func modelFormat(_ target: ConversionTarget) -> ModelFormat {
        switch target {
        case .gguf: return .gguf
        case .mlx: return .mlx
        case .coreml: return .safetensors  // Use safetensors for CoreML
        case .ollama: return .ollama
        case .remote: return .remote
        }
    }

    private func inferCapabilities(request: IngestionRequest) -> CapabilityProfile {
        CapabilityProfile(
            supportedTasks: Set(
                request.metadata.taskHints.isEmpty
                    ? [.chat, .summarize]
                    : request.metadata.taskHints),
            maxContextWindow: 4096,
            languages: ["en"],
            supportsToolCalling: false,
            supportsVision: false,
            qualityTier: request.metadata.qualityTierHint ?? .base,
            capabilities: []
        )
    }

    private func estimateResources(format: ConversionTarget) -> ResourceProfile {
        // Rough estimates - real implementation would measure
        switch format {
        case .gguf:
            return ResourceProfile(
                vramRequired: 4.0,  // 4GB
                ramRequired: 8.0,
                preferredDevice: .gpu,
                expectedTokensPerSecond: 30,
                parameterCount: 7.0
            )
        case .mlx:
            return ResourceProfile(
                vramRequired: 4.0,
                ramRequired: 8.0,
                preferredDevice: .gpu,
                expectedTokensPerSecond: 40,
                parameterCount: 7.0
            )
        case .coreml:
            return ResourceProfile(
                vramRequired: 2.0,
                ramRequired: 4.0,
                preferredDevice: .ane,
                expectedTokensPerSecond: 50,
                parameterCount: 3.0
            )
        case .ollama:
            return ResourceProfile(
                vramRequired: 4.0,
                ramRequired: 8.0,
                preferredDevice: .gpu,
                expectedTokensPerSecond: 25,
                parameterCount: 7.0
            )
        case .remote:
            return ResourceProfile(
                vramRequired: 0.0,
                ramRequired: 0.0,
                preferredDevice: .any,
                expectedTokensPerSecond: 0.0,
                parameterCount: 0.0
            )
        }
    }

    // MARK: - Validation

    private func validate(model: ModelDescriptor) async -> ModelValidationResult {
        var checks: [ModelValidationCheck] = []

        // Check file exists
        let fileExists =
            model.storageLocation.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        checks.append(
            ModelValidationCheck(
                name: "file_exists",
                passed: fileExists,
                message: fileExists ? nil : "Model file not found"
            ))

        // Check format matches backend
        let formatMatch = isCompatible(format: model.format, backend: model.backend)
        checks.append(
            ModelValidationCheck(
                name: "format_backend_match",
                passed: formatMatch,
                message: formatMatch ? nil : "Format incompatible with backend"
            ))

        // Check capabilities are reasonable
        let hasCapabilities = !model.capabilities.supportedTasks.isEmpty
        checks.append(
            ModelValidationCheck(
                name: "has_capabilities",
                passed: hasCapabilities,
                message: hasCapabilities ? nil : "No supported tasks defined"
            ))

        let allPassed = checks.allSatisfy { $0.passed }

        return ModelValidationResult(
            format: conversionTarget(for: model.format),
            passed: allPassed,
            checks: checks
        )
    }

    private func isCompatible(format: ModelFormat, backend: BackendKind) -> Bool {
        switch (format, backend) {
        case (.gguf, .llamaCpp): return true
        case (.mlx, .mlx): return true
        case (.safetensors, .mlx): return true
        case (.ollama, .ollama): return true
        default: return false
        }
    }

    private func conversionTarget(for format: ModelFormat) -> ConversionTarget {
        switch format {
        case .gguf: return .gguf
        case .mlx: return .mlx
        case .safetensors: return .coreml
        case .ollama: return .ollama
        case .coreML: return .coreml
        case .remote: return .remote
        }
    }

    // MARK: - Benchmarking

    private func benchmark(model: ModelDescriptor) async -> BenchmarkResults {
        // Stub: would run actual inference benchmarks
        return BenchmarkResults(
            tokensPerSecond: model.resources.expectedTokensPerSecond,
            timeToFirstToken: .milliseconds(100),
            memoryUsage: Int(model.resources.vramRequired * 1024 * 1024 * 1024),
            qualityScore: nil
        )
    }

    // MARK: - Statistics

    /// Gets ingestion statistics.
    public func statistics() -> IngestionStatistics {
        IngestionStatistics(
            queuedCount: queue.count,
            inProgressCount: inProgress.count,
            completedCount: completed.count,
            successCount: completed.values.filter { $0.isSuccess }.count,
            failedCount: completed.values.filter { !$0.isSuccess }.count
        )
    }
}

/// Statistics about ingestion.
public struct IngestionStatistics: Sendable {
    public let queuedCount: Int
    public let inProgressCount: Int
    public let completedCount: Int
    public let successCount: Int
    public let failedCount: Int
}
