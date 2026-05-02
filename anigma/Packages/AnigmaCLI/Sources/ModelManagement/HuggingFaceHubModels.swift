//
//  HuggingFaceHubModels.swift
//  AnigmaCLI
//
//  Data models for HuggingFace Hub API responses.
//

import Foundation

public struct HFSearchResult: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let author: String
    public let downloads: Int
    public let likes: Int
    public let tags: [String]
    public let pipelineTag: String?
    public let libraryName: String?
    public let modelType: String?
    public let size: Int64?
    public let lastModified: Date?

    public var formattedSize: String {
        guard let size = size else { return "Unknown" }
        return formatBytes(size)
    }

    public var taskType: ModelTaskType? {
        guard let pipelineTag = pipelineTag?.lowercased() else { return nil }
        if pipelineTag.contains("text-generation") || pipelineTag.contains("causal-lm") {
            return .textGeneration
        }
        if pipelineTag.contains("feature-extraction") || pipelineTag.contains("sentence-similarity") {
            return .embedding
        }
        if pipelineTag.contains("text-classification") {
            return .classification
        }
        if pipelineTag.contains("automatic-speech-recognition") {
            return .transcription
        }
        if pipelineTag.contains("text-to-image") {
            return .imageGeneration
        }
        if pipelineTag.contains("text-to-speech") {
            return .speechSynthesis
        }
        return nil
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        return String(format: "%.1f %@", value, units[unitIndex])
    }

    public enum CodingKeys: String, CodingKey {
        case id
        case author
        case downloads
        case likes
        case tags
        case pipelineTag = "pipeline_tag"
        case libraryName = "library_name"
        case modelType = "model_type"
        case size
        case lastModified = "last_modified"
    }
}

public struct HFModelDetail: Sendable {
    public let repo: String
    public let revision: String
    public let files: [HFFileInfo]
    public let license: String?
    public let licenseUrl: String?
    public let tags: [String]
    public let totalSize: Int64
    public let modelType: String?
    public let pipelineTag: String?
    public let libraryName: String?
    public let downloads: Int
    public let likes: Int
    public let modelCard: String?
    public let compatibleBackends: [MLBackend]

    public var formattedSize: String {
        formatBytes(totalSize)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        return String(format: "%.1f %@", value, units[unitIndex])
    }
}

public struct HFFileInfo: Identifiable, Codable, Sendable {
    public let id: String
    public let path: String
    public let size: Int64?
    public let type: String
    public let oid: String?
    public let lfs: HFLFSInfo?

    public var isFile: Bool { type == "file" }
    public var isFolder: Bool { type == "folder" }

    public var formattedSize: String {
        guard let size = size else { return "-" }
        let units = ["B", "KB", "MB", "GB"]
        var value = Double(size)
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        return String(format: "%.1f %@", value, units[unitIndex])
    }
}

public struct HFLFSInfo: Codable, Sendable {
    public let pointerSize: Int?
    public let sha256: String?

    public enum CodingKeys: String, CodingKey {
        case pointerSize = "pointer_size"
        case sha256
    }
}

public struct HFSearchFilter: Sendable {
    public var query: String
    public var task: ModelTaskType?
    public var library: String?
    public var sort: String?
    public var direction: String?
    public var limit: Int
    public var author: String?
    public var tags: [String]
    public var requiresToken: Bool

    public init(
        query: String = "",
        task: ModelTaskType? = nil,
        library: String? = nil,
        sort: String? = "downloads",
        direction: String? = "desc",
        limit: Int = 20,
        author: String? = nil,
        tags: [String] = [],
        requiresToken: Bool = false
    ) {
        self.query = query
        self.task = task
        self.library = library
        self.sort = sort
        self.direction = direction
        self.limit = limit
        self.author = author
        self.tags = tags
        self.requiresToken = requiresToken
    }

    public var queryParameters: [URLQueryItem] {
        var items: [URLQueryItem] = []

        if !query.isEmpty {
            items.append(URLQueryItem(name: "search", value: query))
        }

        if let task = task {
            items.append(URLQueryItem(name: "pipeline_tag", value: task.pipelineTag))
        }

        if let library = library {
            items.append(URLQueryItem(name: "library_name", value: library))
        }

        if let sort = sort {
            items.append(URLQueryItem(name: "sort", value: sort))
        }

        if let direction = direction {
            items.append(URLQueryItem(name: "direction", value: direction))
        }

        items.append(URLQueryItem(name: "limit", value: String(limit)))

        if let author = author {
            items.append(URLQueryItem(name: "author", value: author))
        }

        for tag in tags {
            items.append(URLQueryItem(name: "tags", value: tag))
        }

        return items
    }

    public var cacheKey: String {
        let components = [
            query,
            task?.pipelineTag ?? "",
            library ?? "",
            sort ?? "",
            direction ?? "",
            String(limit),
            author ?? "",
            tags.joined(separator: ",")
        ]
        return components.joined(separator: "|")
    }
}

public enum ModelTaskType: String, Sendable, CaseIterable {
    case textGeneration = "text-generation"
    case embedding = "feature-extraction"
    case classification = "text-classification"
    case transcription = "automatic-speech-recognition"
    case imageGeneration = "text-to-image"
    case speechSynthesis = "text-to-speech"

    public var pipelineTag: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .textGeneration: return "Text Generation"
        case .embedding: return "Embeddings"
        case .classification: return "Classification"
        case .transcription: return "Speech Recognition"
        case .imageGeneration: return "Image Generation"
        case .speechSynthesis: return "Speech Synthesis"
        }
    }

    public var icon: String {
        switch self {
        case .textGeneration: return "text.bubble"
        case .embedding: return "point.3.connected.trianglepath.dotted"
        case .classification: return "list.bullet.clipboard"
        case .transcription: return "waveform"
        case .imageGeneration: return "photo"
        case .speechSynthesis: return "speaker.wave.2"
        }
    }
}

public enum MLBackend: String, Sendable, CaseIterable {
    case mlx = "mlx"
    case gguf = "gguf"
    case coreml = "coreml"
    case safetensors = "safetensors"

    public var displayName: String {
        switch self {
        case .mlx: return "MLX"
        case .gguf: return "GGUF"
        case .coreml: return "CoreML"
        case .safetensors: return "Safetensors"
        }
    }

    public var icon: String {
        switch self {
        case .mlx: return "cpu"
        case .gguf: return "doc.text"
        case .coreml: return "sparkles"
        case .safetensors: return "lock.shield"
        }
    }
}
