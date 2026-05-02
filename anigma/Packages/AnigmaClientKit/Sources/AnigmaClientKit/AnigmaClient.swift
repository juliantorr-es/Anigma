/// Enhanced AnigmaClientKit provides comprehensive HTTP client for Anigma daemon API.
/// Includes job submission, async polling, result retrieval, error handling, and retry logic.

import Foundation

public struct EnhancedAnigmaClient {
    /// Configuration for the Anigma daemon connection
    public struct Configuration {
        public let host: String
        public let port: Int
        public let scheme: String
        public let timeout: TimeInterval
        public let apiKey: String?
        public let retryCount: Int
        
        public init(
            host: String = "localhost",
            port: Int = 8080,
            scheme: String = "http",
            timeout: TimeInterval = 30.0,
            apiKey: String? = nil,
            retryCount: Int = 3
        ) {
            self.host = host
            self.port = port
            self.scheme = scheme
            self.timeout = timeout
            self.apiKey = apiKey
            self.retryCount = retryCount
        }
    }
    
    /// Job submission request
    public struct JobRequest: Codable, Sendable {
        public let action: String
        public let repoPath: String
        public let filePath: String
        public let instruction: String
        public let priority: JobPriority
        public let metadata: [String: String]
        
        public init(
            action: String,
            repoPath: String,
            filePath: String,
            instruction: String,
            priority: JobPriority = .normal,
            metadata: [String: String] = [:]
        ) {
            self.action = action
            self.repoPath = repoPath
            self.filePath = filePath
            self.instruction = instruction
            self.priority = priority
            self.metadata = metadata
        }
    }
    
    /// Job priority levels
    public enum JobPriority: String, Codable, CaseIterable, Sendable {
        case low = "low"
        case normal = "normal"
        case high = "high"
        case urgent = "urgent"
    }
    
    /// Job status response
    public struct JobStatus: Codable, Sendable {
        public let jobId: String
        public let status: JobState
        public let progress: Double
        public let createdAt: Date
        public let updatedAt: Date
        public let estimatedCompletion: Date?
        public let errorMessage: String?
        
        public init(
            jobId: String,
            status: JobState,
            progress: Double,
            createdAt: Date,
            updatedAt: Date,
            estimatedCompletion: Date? = nil,
            errorMessage: String? = nil
        ) {
            self.jobId = jobId
            self.status = status
            self.progress = progress
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.estimatedCompletion = estimatedCompletion
            self.errorMessage = errorMessage
        }
    }
    
    /// Job state enumeration
    public enum JobState: String, Codable, CaseIterable, Sendable {
        case queued = "QUEUED"
        case running = "RUNNING"
        case completed = "COMPLETED"
        case failed = "FAILED"
        case cancelled = "CANCELLED"
    }
    
    /// Job result
    public struct JobResult: Codable, Sendable {
        public let jobId: String
        public let status: JobState
        public let output: String?
        public let artifacts: [Artifact]
        public let executionTime: TimeInterval
        public let error: String?
        
        public init(
            jobId: String,
            status: JobState,
            output: String? = nil,
            artifacts: [Artifact] = [],
            executionTime: TimeInterval,
            error: String? = nil
        ) {
            self.jobId = jobId
            self.status = status
            self.output = output
            self.artifacts = artifacts
            self.executionTime = executionTime
            self.error = error
        }
    }
    
    /// Artifact reference
    public struct Artifact: Codable, Sendable {
        public let id: String
        public let name: String
        public let type: String
        public let size: Int64
        public let url: String?
        
        public init(id: String, name: String, type: String, size: Int64, url: String? = nil) {
            self.id = id
            self.name = name
            self.type = type
            self.size = size
            self.url = url
        }
    }
    
    /// Client error types
    public enum ClientError: Error, LocalizedError {
        case invalidURL
        case networkError(Error)
        case invalidResponse
        case jobNotFound(String)
        case serverError(Int, String)
        case timeout
        case authenticationRequired
        case rateLimited
        case unknown(Error)
        
        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL configuration"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse:
                return "Invalid server response"
            case .jobNotFound(let jobId):
                return "Job not found: \(jobId)"
            case .serverError(let code, let message):
                return "Server error \(code): \(message)"
            case .timeout:
                return "Request timeout"
            case .authenticationRequired:
                return "Authentication required"
            case .rateLimited:
                return "Rate limited - please try again later"
            case .unknown(let error):
                return "Unknown error: \(error.localizedDescription)"
            }
        }
    }
    
    private let configuration: Configuration
    private let session: URLSession
    
    /// Initialize a new AnigmaClient
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout * 10
        self.session = URLSession(configuration: sessionConfig)
    }
    
    /// Build base URL for API calls
    private func baseURL() -> URL? {
        let urlString = "\(configuration.scheme)://\(configuration.host):\(configuration.port)"
        return URL(string: urlString)
    }
    
    /// Build request URL with path
    private func requestURL(path: String) -> URL? {
        guard let baseURL = baseURL() else { return nil }
        return baseURL.appendingPathComponent(path)
    }
    
    /// Create HTTP request with authentication
    private func createRequest(url: URL, method: String, body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let apiKey = configuration.apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
    
    /// Execute HTTP request with retry logic
    private func executeRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var lastError: Error?
        
        for attempt in 0...configuration.retryCount {
            do {
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ClientError.invalidResponse
                }
                
                // Handle different status codes
                switch httpResponse.statusCode {
                case 200...299:
                    return (data, httpResponse)
                case 401:
                    throw ClientError.authenticationRequired
                case 404:
                    throw ClientError.jobNotFound("Resource not found")
                case 429:
                    throw ClientError.rateLimited
                case 500...599:
                    throw ClientError.serverError(httpResponse.statusCode, "Internal server error")
                default:
                    throw ClientError.serverError(httpResponse.statusCode, "Unexpected status code")
                }
            } catch {
                lastError = error
                
                // Don't retry on authentication or client errors
                if let clientError = error as? ClientError {
                    switch clientError {
                    case .authenticationRequired, .invalidURL, .invalidResponse:
                        throw clientError
                    default:
                        break
                    }
                }
                
                // If this is the last attempt, throw the error
                if attempt == configuration.retryCount {
                    throw error
                }
                
                // Wait before retry (exponential backoff)
                let delay = TimeInterval(pow(2.0, Double(attempt))) * 0.1
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        throw lastError ?? ClientError.unknown(NSError(domain: "AnigmaClient", code: -1))
    }
    
    /// Submit a job to the daemon
    public func submitJob(_ request: JobRequest) async throws -> JobStatus {
        guard let url = requestURL(path: "jobs") else {
            throw ClientError.invalidURL
        }
        
        let body = try JSONEncoder().encode(request)
        let httpRequest = createRequest(url: url, method: "POST", body: body)
        
        let (data, _) = try await executeRequest(httpRequest)
        let jobStatus = try JSONDecoder().decode(JobStatus.self, from: data)
        
        return jobStatus
    }
    
    /// Get job status by ID
    public func getJobStatus(jobId: String) async throws -> JobStatus {
        guard let url = requestURL(path: "jobs/\(jobId)") else {
            throw ClientError.invalidURL
        }
        
        let request = createRequest(url: url, method: "GET")
        let (data, _) = try await executeRequest(request)
        let jobStatus = try JSONDecoder().decode(JobStatus.self, from: data)
        
        return jobStatus
    }
    
    /// Poll for job completion with configurable interval and timeout
    public func waitForJobCompletion(
        jobId: String,
        pollInterval: TimeInterval = 1.0,
        timeout: TimeInterval = 300.0
    ) async throws -> JobResult {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            let status = try await getJobStatus(jobId: jobId)
            
            switch status.status {
            case .completed:
                return try await getJobResult(jobId: jobId)
            case .failed, .cancelled:
                throw ClientError.serverError(500, status.errorMessage ?? "Job failed")
            case .queued, .running:
                // Continue polling
                try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            }
        }
        
        throw ClientError.timeout
    }
    
    /// Get job result
    public func getJobResult(jobId: String) async throws -> JobResult {
        guard let url = requestURL(path: "jobs/\(jobId)/result") else {
            throw ClientError.invalidURL
        }
        
        let request = createRequest(url: url, method: "GET")
        let (data, _) = try await executeRequest(request)
        let result = try JSONDecoder().decode(JobResult.self, from: data)
        
        return result
    }
    
    /// Cancel a job
    public func cancelJob(jobId: String) async throws -> JobStatus {
        guard let url = requestURL(path: "jobs/\(jobId)/cancel") else {
            throw ClientError.invalidURL
        }
        
        let request = createRequest(url: url, method: "POST")
        let (data, _) = try await executeRequest(request)
        let status = try JSONDecoder().decode(JobStatus.self, from: data)
        
        return status
    }
    
    /// List all jobs
    public func listJobs() async throws -> [JobStatus] {
        guard let url = requestURL(path: "jobs") else {
            throw ClientError.invalidURL
        }
        
        let request = createRequest(url: url, method: "GET")
        let (data, _) = try await executeRequest(request)
        let jobs = try JSONDecoder().decode([JobStatus].self, from: data)
        
        return jobs
    }
    
    /// Get daemon status
    public func getDaemonStatus() async throws -> DaemonStatus {
        guard let url = requestURL(path: "status") else {
            throw ClientError.invalidURL
        }
        
        let request = createRequest(url: url, method: "GET")
        let (data, _) = try await executeRequest(request)
        let status = try JSONDecoder().decode(DaemonStatus.self, from: data)
        
        return status
    }
    
    /// Health check
    public func healthCheck() async throws -> Bool {
        guard let url = requestURL(path: "health") else {
            throw ClientError.invalidURL
        }
        
        let request = createRequest(url: url, method: "GET")
        let (_, response) = try await executeRequest(request)
        
        return response.statusCode == 200
    }
}

/// Daemon status response
public struct DaemonStatus: Codable, Sendable {
    public let isRunning: Bool
    public let uptime: TimeInterval
    public let activeJobs: Int
    public let queuedJobs: Int
    public let cpuUsage: Double
    public let memoryUsage: Double
    public let version: String
    
    public init(
        isRunning: Bool,
        uptime: TimeInterval,
        activeJobs: Int,
        queuedJobs: Int,
        cpuUsage: Double,
        memoryUsage: Double,
        version: String
    ) {
        self.isRunning = isRunning
        self.uptime = uptime
        self.activeJobs = activeJobs
        self.queuedJobs = queuedJobs
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.version = version
    }
}
