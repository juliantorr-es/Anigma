//
//  HuggingFaceHubClient.swift
//  AnigmaCLI
//
//  REST API client for HuggingFace Hub with authentication and caching.
//

import Foundation
import AnigmaCore

public actor HuggingFaceHubClient {
    private let session: URLSession
    private let baseURL = "https://huggingface.co/api"
    private let keychain: HuggingFaceKeychain
    private let cache: ModelSearchCache
    private let decoder: JSONDecoder

    public init(keychain: HuggingFaceKeychain, cache: ModelSearchCache) {
        self.keychain = keychain
        self.cache = cache

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func searchModels(
        query: String,
        filter: HFSearchFilter,
        bypassCache: Bool = false
    ) async throws -> [HFSearchResult] {
        let effectiveFilter = HFSearchFilter(
            query: query,
            task: filter.task,
            library: filter.library,
            sort: filter.sort,
            direction: filter.direction,
            limit: filter.limit,
            author: filter.author,
            tags: filter.tags,
            requiresToken: filter.requiresToken
        )

        if !bypassCache, let cached = await cache.get(query: query, filters: effectiveFilter.cacheKey) {
            return cached
        }

        var urlComponents = URLComponents(string: "\(baseURL)/models")
        urlComponents?.queryItems = effectiveFilter.queryParameters

        guard let url = urlComponents?.url else {
            throw HFAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        await addAuthHeaders(to: &request)

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HFAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw HFAPIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        let results = try decoder.decode([HFSearchResult].self, from: data)

        await cache.store(query: query, filters: effectiveFilter.cacheKey, results: results)

        return results
    }

    public func getModelInfo(repo: String, revision: String = "main") async throws -> HFModelDetail {
        let url = URL(string: "\(baseURL)/models/\(repo)")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        await addAuthHeaders(to: &request)

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw HFAPIError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1, data: data)
        }

        let info = try decoder.decode(HFModelInfoResponse.self, from: data)

        let files = try await listModelFiles(repo: repo, revision: revision)

        let backends = determineCompatibleBackends(files: files, pipelineTag: info.pipelineTag)

        return HFModelDetail(
            repo: repo,
            revision: revision,
            files: files,
            license: info.license,
            licenseUrl: info.licenseUrl,
            tags: info.tags,
            totalSize: files.compactMap { $0.size }.reduce(0, +),
            modelType: info.modelType,
            pipelineTag: info.pipelineTag,
            libraryName: info.libraryName,
            downloads: info.downloads,
            likes: info.likes,
            modelCard: nil,
            compatibleBackends: backends
        )
    }

    public func listModelFiles(repo: String, revision: String = "main") async throws -> [HFFileInfo] {
        let urlString = "\(baseURL)/models/\(repo)/tree/\(revision)"
        guard let url = URL(string: urlString) else {
            throw HFAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        await addAuthHeaders(to: &request)

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw HFAPIError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1, data: data)
        }

        return try decoder.decode([HFFileInfo].self, from: data)
    }

    public func getFileSize(repo: String, revision: String = "main", path: String) async throws -> Int64? {
        let urlString = "\(baseURL)/models/\(repo)/tree/\(revision)"
        guard let url = URL(string: urlString) else {
            throw HFAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("HEAD", forHTTPMethodField: "HEAD")
        await addAuthHeaders(to: &request)

        let (_, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse,
              let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length") else {
            return nil
        }

        return Int64(contentLength)
    }

    private func addAuthHeaders(to request: inout URLRequest) async {
        if let token = await keychain.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("Anigma/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            throw HFAPIError.networkError(error)
        } catch {
            throw HFAPIError.requestFailed(error)
        }
    }

    private func determineCompatibleBackends(files: [HFFileInfo], pipelineTag: String?) -> [MLBackend] {
        var backends: Set<MLBackend> = []

        for file in files {
            let path = file.path.lowercased()

            if path.contains(".gguf") || path.contains(".ggml") {
                backends.insert(.gguf)
            }
            if path.contains(".safetensors") {
                backends.insert(.safetensors)
            }
            if path.contains("mlx") || path.contains(".weight") {
                backends.insert(.mlx)
            }
        }

        if pipelineTag != nil {
            backends.insert(.coreml)
        }

        return Array(backends)
    }
}

public enum HFAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
    case networkError(URLError)
    case requestFailed(Error)
    case decodingError(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, _):
            return "HTTP error: \(statusCode)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}

private struct HFModelInfoResponse: Codable {
    let id: String
    let author: String?
    let downloads: Int
    let likes: Int
    let tags: [String]
    let pipelineTag: String?
    let libraryName: String?
    let modelType: String?
    let license: String?
    let licenseUrl: String?
}
