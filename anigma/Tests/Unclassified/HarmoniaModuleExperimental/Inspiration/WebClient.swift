//
//  WebClient.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Inspiration
//
//  Web client layer for GitHub and HuggingFace integration.
//  Deterministic, not LLM-wandering - fetches repos and models as data sources.
//

import Foundation
import HarmoniaModule

/// Configuration for web clients.
public struct WebClientConfig: Sendable, Codable {
    public let githubToken: String?
    public let huggingfaceToken: String?
    public let rateLimitDelay: TimeInterval
    public let maxRetries: Int
    public let timeout: TimeInterval

    public init(
        githubToken: String? = nil,
        huggingfaceToken: String? = nil,
        rateLimitDelay: TimeInterval = 1.0,
        maxRetries: Int = 3,
        timeout: TimeInterval = 30.0
    ) {
        self.githubToken = githubToken
        self.huggingfaceToken = huggingfaceToken
        self.rateLimitDelay = rateLimitDelay
        self.maxRetries = maxRetries
        self.timeout = timeout
    }
}

/// Represents a GitHub repository for inspiration indexing.
public struct GitHubRepo: Sendable, Codable {
    public let id: Int
    public let name: String
    public let fullName: String
    public let description: String?
    public let htmlUrl: String
    public let cloneUrl: String
    public let sshUrl: String
    public let defaultBranch: String
    public let language: String?
    public let license: GitHubLicense?
    public let stars: Int
    public let forks: Int
    public let updatedAt: Date
    public let topics: [String]

    public struct GitHubLicense: Sendable, Codable {
        public let key: String
        public let name: String
        public let spdxId: String
        public let url: String?

        public init(key: String, name: String, spdxId: String, url: String?) {
            self.key = key
            self.name = name
            self.spdxId = spdxId
            self.url = url
        }
    }

    public init(
        id: Int,
        name: String,
        fullName: String,
        description: String? = nil,
        htmlUrl: String,
        cloneUrl: String,
        sshUrl: String,
        defaultBranch: String,
        language: String? = nil,
        license: GitHubLicense? = nil,
        stars: Int,
        forks: Int,
        updatedAt: Date,
        topics: [String] = []
    ) {
        self.id = id
        self.name = name
        self.fullName = fullName
        self.description = description
        self.htmlUrl = htmlUrl
        self.cloneUrl = cloneUrl
        self.sshUrl = sshUrl
        self.defaultBranch = defaultBranch
        self.language = language
        self.license = license
        self.stars = stars
        self.forks = forks
        self.updatedAt = updatedAt
        self.topics = topics
    }
}

/// Represents a HuggingFace model for inspiration indexing.
public struct HuggingFaceModel: Sendable, Codable {
    public let id: String
    public let author: String?
    public let lastModified: Date
    public let tags: [String]
    public let downloads: Int
    public let likes: Int
    public let pipelineTag: String?
    public let libraryName: String?
    public let modelCard: String?

    public init(
        id: String,
        author: String? = nil,
        lastModified: Date,
        tags: [String] = [],
        downloads: Int = 0,
        likes: Int = 0,
        pipelineTag: String? = nil,
        libraryName: String? = nil,
        modelCard: String? = nil
    ) {
        self.id = id
        self.author = author
        self.lastModified = lastModified
        self.tags = tags
        self.downloads = downloads
        self.likes = likes
        self.pipelineTag = pipelineTag
        self.libraryName = libraryName
        self.modelCard = modelCard
    }
}

/// Errors for web client operations.
public enum WebClientError: Error, Sendable {
    case networkError(Error)
    case httpError(statusCode: Int)
    case rateLimited(retryAfter: TimeInterval?)
    case invalidResponse
    case authenticationRequired
    case timeout
    case invalidURL
}

/// Base protocol for web clients.
public protocol WebClient: Sendable {
    var config: WebClientConfig { get }

    func fetch<T: Decodable>(_ request: URLRequest) async throws -> T
    func fetchWithRetry<T: Decodable>(_ request: URLRequest) async throws -> T
}

/// Default implementation of WebClient.
public actor DefaultWebClient: WebClient {
    public let config: WebClientConfig
    private let session: URLSession
    private let decoder: JSONDecoder

    private var lastRequestTime: Date = .distantPast
    private let rateLimitQueue = DispatchQueue(label: "com.anigma.webclient.ratelimit")

    public init(config: WebClientConfig) {
        self.config = config

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.timeout
        sessionConfig.timeoutIntervalForResource = config.timeout * 2
        sessionConfig.httpAdditionalHeaders = [
            "User-Agent": "Anigma/1.0 (https://github.com/anigma-ai/anigma)"
        ]

        self.session = URLSession(configuration: sessionConfig)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    public func fetch<T: Decodable>(_ request: URLRequest) async throws -> T {
        // Respect rate limiting
        try await enforceRateLimit()

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebClientError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return try decoder.decode(T.self, from: data)
        case 401, 403:
            throw WebClientError.authenticationRequired
        case 429:
            let retryAfter = extractRetryAfter(from: httpResponse)
            throw WebClientError.rateLimited(retryAfter: retryAfter)
        case 408, 504:
            throw WebClientError.timeout
        default:
            throw WebClientError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    public func fetchWithRetry<T: Decodable>(_ request: URLRequest) async throws -> T {
        var lastError: Error?

        for attempt in 0..<config.maxRetries {
            do {
                return try await fetch(request)
            } catch WebClientError.rateLimited(let retryAfter) {
                let delay = retryAfter ?? Double(attempt + 1) * 2.0
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                lastError = error
                continue
            } catch WebClientError.timeout {
                if attempt < config.maxRetries - 1 {
                    try await Task.sleep(nanoseconds: UInt64(Double(attempt + 1) * 1_000_000_000))
                    lastError = error
                    continue
                }
                throw error
            } catch {
                throw error
            }
        }

        throw lastError ?? WebClientError.networkError(NSError(domain: "WebClient", code: -1, userInfo: nil))
    }

    private func enforceRateLimit() async throws {
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)

        if timeSinceLastRequest < config.rateLimitDelay {
            let delay = config.rateLimitDelay - timeSinceLastRequest
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        lastRequestTime = Date()
    }

    private func extractRetryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        guard let retryAfterString = response.value(forHTTPHeaderField: "Retry-After") else {
            return nil
        }

        if let seconds = Int(retryAfterString) {
            return TimeInterval(seconds)
        }

        // Try to parse as HTTP date
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"

        if let date = formatter.date(from: retryAfterString) {
            return date.timeIntervalSince(Date())
        }

        return nil
    }
}

/// GitHub API client for fetching repositories.
public actor GitHubClient {
    private let webClient: WebClient
    guard let baseURL = URL(string: "https://api.github.com") else {
        fatalError("Failed to unwrap baseURL")
    }

    public init(webClient: WebClient) {
        self.webClient = webClient
    }

    /// Fetch repository information.
    public func fetchRepo(owner: String, repo: String) async throws -> GitHubRepo {
        let url = baseURL.appendingPathComponent("repos/\(owner)/\(repo)")
        var request = URLRequest(url: url)

        if let token = (webClient.config.githubToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        return try await webClient.fetchWithRetry(request)
    }

    /// Search for repositories by query.
    public func searchRepos(query: String, language: String? = nil, limit: Int = 10) async throws -> [GitHubRepo] {
        var searchQuery = query
        if let language = language {
            searchQuery += " language:\(language)"
        }

        let url = baseURL.appendingPathComponent("search/repositories")
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            fatalError("Failed to unwrap components")
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: searchQuery),
            URLQueryItem(name: "per_page", value: "\(min(limit, 100))"),
            URLQueryItem(name: "sort", value: "stars"),
            URLQueryItem(name: "order", value: "desc")
        ]

        var request = URLRequest(url: components.url!)

        if let token = (webClient.config.githubToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        struct SearchResponse: Decodable {
            let items: [GitHubRepo]
        }

        let response: SearchResponse = try await webClient.fetchWithRetry(request)
        return Array(response.items.prefix(limit))
    }

    /// Fetch repository README content.
    public func fetchReadme(owner: String, repo: String, branch: String? = nil) async throws -> String {
        let url = baseURL.appendingPathComponent("repos/\(owner)/\(repo)/readme")
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            fatalError("Failed to unwrap components")
        }

        if let branch = branch {
            components.queryItems = [URLQueryItem(name: "ref", value: branch)]
        }

        var request = URLRequest(url: components.url!)

        if let token = (webClient.config.githubToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.setValue("application/vnd.github.v3.raw", forHTTPHeaderField: "Accept")

        struct ReadmeResponse: Decodable {
            let content: String
            let encoding: String
        }

        let response: ReadmeResponse = try await webClient.fetchWithRetry(request)

        guard response.encoding == "base64" else {
            throw WebClientError.invalidResponse
        }

        guard let data = Data(base64Encoded: response.content) else {
            throw WebClientError.invalidResponse
        }

        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Clone a repository to local inspiration directory.
    public func cloneToInspiration(repo: GitHubRepo, destinationPath: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["clone", repo.cloneUrl, destinationPath]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = try errorPipe.fileHandleForReading.readToEnd() ?? Data()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "Git", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: "Git clone failed: \(errorString)"
            ])
        }

        return destinationPath
    }
}

/// HuggingFace API client for fetching model information.
public actor HuggingFaceClient {
    private let webClient: WebClient
    guard let baseURL = URL(string: "https://huggingface.co/api") else {
        fatalError("Failed to unwrap baseURL")
    }

    public init(webClient: WebClient) {
        self.webClient = webClient
    }

    /// Fetch model information.
    public func fetchModel(modelId: String) async throws -> HuggingFaceModel {
        let url = baseURL.appendingPathComponent("models/\(modelId)")
        var request = URLRequest(url: url)

        if let token = (webClient.config.huggingfaceToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return try await webClient.fetchWithRetry(request)
    }

    /// Search for models by query.
    public func searchModels(query: String, limit: Int = 10) async throws -> [HuggingFaceModel] {
        let url = baseURL.appendingPathComponent("models")
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            fatalError("Failed to unwrap components")
        }
        components.queryItems = [
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "limit", value: "\(min(limit, 100))"),
            URLQueryItem(name: "sort", value: "downloads"),
            URLQueryItem(name: "direction", value: "-1")
        ]

        var request = URLRequest(url: components.url!)

        if let token = (webClient.config.huggingfaceToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return try await webClient.fetchWithRetry(request)
    }

    /// Fetch model card content.
    public func fetchModelCard(modelId: String) async throws -> String {
        guard let url = URL(string: "https://huggingface.co/\(modelId)/raw/main/README.md") else {
            fatalError("Failed to unwrap url")
        }
        var request = URLRequest(url: url)

        if let token = (webClient.config.huggingfaceToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data = try await webClient.fetchWithRetry(request)
        return String(data: data, encoding: .utf8) ?? ""
    }
}

/// Service that orchestrates web clients for inspiration indexing.
public actor WebClientService {
    private let config: WebClientConfig
    private let webClient: WebClient
    private let gitHubClient: GitHubClient
    private let huggingFaceClient: HuggingFaceClient
    private let indexStore: InspirationIndexStore

    public init(config: WebClientConfig, indexStore: InspirationIndexStore) throws {
        self.config = config
        self.webClient = DefaultWebClient(config: config)
        self.gitHubClient = GitHubClient(webClient: webClient)
        self.huggingFaceClient = HuggingFaceClient(webClient: webClient)
        self.indexStore = indexStore
    }

    /// Import a GitHub repository into the inspiration directory.
    public func importGitHubRepo(owner: String, repo: String, inspirationPath: String) async throws -> InspirationRepo {
        // Fetch repo info
        let gitHubRepo = try await gitHubClient.fetchRepo(owner: owner, repo: repo)

        // Clone to inspiration directory
        let destinationPath = "\(inspirationPath)/\(owner)-\(repo)"
        let clonedPath = try await gitHubClient.cloneToInspiration(
            repo: gitHubRepo,
            destinationPath: destinationPath
        )

        // Create inspiration repo record
        let inspirationRepo = InspirationRepo(
            name: gitHubRepo.name,
            path: clonedPath,
            gitUrl: gitHubRepo.cloneUrl,
            license: gitHubRepo.license?.spdxId,
            tags: gitHubRepo.topics
        )

        try await indexStore.saveRepo(inspirationRepo)
        return inspirationRepo
    }

    /// Search and import relevant GitHub repositories.
    public func searchAndImportRepos(
        query: String,
        language: String? = nil,
        limit: Int = 5,
        inspirationPath: String
    ) async throws -> [InspirationRepo] {
        let repos = try await gitHubClient.searchRepos(
            query: query,
            language: language,
            limit: limit
        )

        var importedRepos: [InspirationRepo] = []

        for repo in repos {
            do {
                let imported = try await importGitHubRepo(
                    owner: repo.fullName.components(separatedBy: "/")[0],
                    repo: repo.name,
                    inspirationPath: inspirationPath
                )
                importedRepos.append(imported)

                // Rate limiting between imports
                try await Task.sleep(nanoseconds: UInt64(config.rateLimitDelay * 1_000_000_000))
            } catch {
                // Log error but continue with other repos
                print("Failed to import \(repo.fullName): \(error)")
            }
        }

        return importedRepos
    }

    /// Index a HuggingFace model as inspiration (metadata only, not weights).
    public func indexHuggingFaceModel(modelId: String) async throws -> InspirationPattern {
        let model = try await huggingFaceClient.fetchModel(modelId: modelId)

        // Create pattern for model architecture/usage
        let pattern = InspirationPattern(
            repoId: UUID(), // Not associated with a repo
            patternId: "huggingface-model-\(modelId)",
            kind: .architecture,
            language: "python", // Most HF models are Python
            description: "HuggingFace model: \(modelId)",
            exampleSnippet: """
            # Model: \(modelId)
            # Pipeline: \(model.pipelineTag ?? "unknown")
            # Library: \(model.libraryName ?? "transformers")
            # Tags: \(model.tags.joined(separator: ", "))
            """,
            metadata: [
                "model_id": modelId,
                "author": model.author ?? "unknown",
                "pipeline_tag": model.pipelineTag ?? "",
                "library_name": model.libraryName ?? "",
                "downloads": "\(model.downloads)",
                "likes": "\(model.likes)"
            ]
        )

        try await indexStore.savePattern(pattern)
        return pattern
    }

    /// Search and index relevant HuggingFace models.
    public func searchAndIndexModels(query: String, limit: Int = 5) async throws -> [InspirationPattern] {
        let models = try await huggingFaceClient.searchModels(query: query, limit: limit)

        var patterns: [InspirationPattern] = []

        for model in models {
            do {
                let pattern = try await indexHuggingFaceModel(modelId: model.id)
                patterns.append(pattern)

                // Rate limiting between indexing
                try await Task.sleep(nanoseconds: UInt64(config.rateLimitDelay * 1_000_000_000))
            } catch {
                print("Failed to index model \(model.id): \(error)")
            }
        }

        return patterns
    }
}
