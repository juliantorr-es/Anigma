import XCTest
@testable import AnigmaClientKit

final class AnigmaClientKitContractTests: XCTestCase {
    
    var client: EnhancedAnigmaClient!
    
    override func setUp() {
        super.setUp()
        let config = EnhancedAnigmaClient.Configuration(
            host: "localhost",
            port: 8080,
            timeout: 5.0,
            retryCount: 1
        )
        client = EnhancedAnigmaClient(configuration: config)
    }
    
    override func tearDown() {
        client = nil
        super.tearDown()
    }
    
    // MARK: - Configuration Tests
    
    func testConfigurationDefaults() {
        let config = EnhancedAnigmaClient.Configuration()
        XCTAssertEqual(config.host, "localhost")
        XCTAssertEqual(config.port, 8080)
        XCTAssertEqual(config.scheme, "http")
        XCTAssertEqual(config.timeout, 30.0)
        XCTAssertNil(config.apiKey)
        XCTAssertEqual(config.retryCount, 3)
    }
    
    func testConfigurationCustomValues() {
        let config = EnhancedAnigmaClient.Configuration(
            host: "example.com",
            port: 9090,
            scheme: "https",
            timeout: 60.0,
            apiKey: "test-key",
            retryCount: 5
        )
        XCTAssertEqual(config.host, "example.com")
        XCTAssertEqual(config.port, 9090)
        XCTAssertEqual(config.scheme, "https")
        XCTAssertEqual(config.timeout, 60.0)
        XCTAssertEqual(config.apiKey, "test-key")
        XCTAssertEqual(config.retryCount, 5)
    }
    
    // MARK: - JobRequest Tests
    
    func testJobRequestDefaults() {
        let request = EnhancedAnigmaClient.JobRequest(
            action: "test",
            repoPath: "/path/to/repo",
            filePath: "/path/to/file",
            instruction: "test instruction"
        )
        
        XCTAssertEqual(request.action, "test")
        XCTAssertEqual(request.repoPath, "/path/to/repo")
        XCTAssertEqual(request.filePath, "/path/to/file")
        XCTAssertEqual(request.instruction, "test instruction")
        XCTAssertEqual(request.priority, .normal)
        XCTAssertEqual(request.metadata, [:])
    }
    
    func testJobRequestCustomValues() {
        let metadata = ["key": "value", "user": "test"]
        let request = EnhancedAnigmaClient.JobRequest(
            action: "test",
            repoPath: "/path/to/repo",
            filePath: "/path/to/file",
            instruction: "test instruction",
            priority: .high,
            metadata: metadata
        )
        
        XCTAssertEqual(request.action, "test")
        XCTAssertEqual(request.repoPath, "/path/to/repo")
        XCTAssertEqual(request.filePath, "/path/to/file")
        XCTAssertEqual(request.instruction, "test instruction")
        XCTAssertEqual(request.priority, .high)
        XCTAssertEqual(request.metadata, metadata)
    }
    
    // MARK: - JobRequest Codable Tests
    
    func testJobRequestEncoding() throws {
        let request = EnhancedAnigmaClient.JobRequest(
            action: "test",
            repoPath: "/path/to/repo",
            filePath: "/path/to/file",
            instruction: "test instruction",
            priority: .high,
            metadata: ["key": "value"]
        )
        
        let data = try JSONEncoder().encode(request)
        XCTAssertNotNil(data)
        
        let decoded = try JSONDecoder().decode(EnhancedAnigmaClient.JobRequest.self, from: data)
        XCTAssertEqual(decoded.action, request.action)
        XCTAssertEqual(decoded.repoPath, request.repoPath)
        XCTAssertEqual(decoded.filePath, request.filePath)
        XCTAssertEqual(decoded.instruction, request.instruction)
        XCTAssertEqual(decoded.priority, request.priority)
        XCTAssertEqual(decoded.metadata, request.metadata)
    }
    
    // MARK: - JobStatus Tests
    
    func testJobStatusInitialization() {
        let createdAt = Date()
        let updatedAt = Date().addingTimeInterval(60)
        let estimatedCompletion = Date().addingTimeInterval(3600)
        
        let status = EnhancedAnigmaClient.JobStatus(
            jobId: "test-job-123",
            status: .running,
            progress: 0.5,
            createdAt: createdAt,
            updatedAt: updatedAt,
            estimatedCompletion: estimatedCompletion,
            errorMessage: nil
        )
        
        XCTAssertEqual(status.jobId, "test-job-123")
        XCTAssertEqual(status.status, .running)
        XCTAssertEqual(status.progress, 0.5)
        XCTAssertEqual(status.createdAt, createdAt)
        XCTAssertEqual(status.updatedAt, updatedAt)
        XCTAssertEqual(status.estimatedCompletion, estimatedCompletion)
        XCTAssertNil(status.errorMessage)
    }
    
    func testJobStatusWithErrorMessage() {
        let status = EnhancedAnigmaClient.JobStatus(
            jobId: "test-job-123",
            status: .failed,
            progress: 0.25,
            createdAt: Date(),
            updatedAt: Date(),
            errorMessage: "Process failed"
        )
        
        XCTAssertEqual(status.status, .failed)
        XCTAssertEqual(status.errorMessage, "Process failed")
    }
    
    // MARK: - JobState Tests
    
    func testJobStateAllCases() {
        let states: [EnhancedAnigmaClient.JobState] = [.queued, .running, .completed, .failed, .cancelled]
        let rawValues = states.map { $0.rawValue }
        
        XCTAssertEqual(rawValues, ["QUEUED", "RUNNING", "COMPLETED", "FAILED", "CANCELLED"])
    }
    
    func testJobStateCodable() throws {
        let state = EnhancedAnigmaClient.JobState.running
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(EnhancedAnigmaClient.JobState.self, from: data)
        XCTAssertEqual(decoded, state)
    }
    
    // MARK: - JobResult Tests
    
    func testJobResultSuccess() {
        let artifacts = [
            EnhancedAnigmaClient.Artifact(
                id: "artifact-1",
                name: "output.txt",
                type: "text",
                size: 1024,
                url: "http://example.com/output.txt"
            )
        ]
        
        let result = EnhancedAnigmaClient.JobResult(
            jobId: "test-job-123",
            status: .completed,
            output: "Process completed successfully",
            artifacts: artifacts,
            executionTime: 120.5
        )
        
        XCTAssertEqual(result.jobId, "test-job-123")
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.output, "Process completed successfully")
        XCTAssertEqual(result.artifacts.count, 1)
        XCTAssertEqual(result.artifacts.first?.id, "artifact-1")
        XCTAssertEqual(result.executionTime, 120.5)
        XCTAssertNil(result.error)
    }
    
    func testJobResultFailure() {
        let result = EnhancedAnigmaClient.JobResult(
            jobId: "test-job-123",
            status: .failed,
            output: nil,
            artifacts: [],
            executionTime: 45.2,
            error: "Timeout occurred"
        )
        
        XCTAssertEqual(result.status, .failed)
        XCTAssertNil(result.output)
        XCTAssertEqual(result.artifacts.count, 0)
        XCTAssertEqual(result.error, "Timeout occurred")
    }
    
    // MARK: - Artifact Tests
    
    func testArtifactInitialization() {
        let artifact = EnhancedAnigmaClient.Artifact(
            id: "artifact-1",
            name: "output.txt",
            type: "text",
            size: 1024,
            url: "http://example.com/output.txt"
        )
        
        XCTAssertEqual(artifact.id, "artifact-1")
        XCTAssertEqual(artifact.name, "output.txt")
        XCTAssertEqual(artifact.type, "text")
        XCTAssertEqual(artifact.size, 1024)
        XCTAssertEqual(artifact.url, "http://example.com/output.txt")
    }
    
    func testArtifactWithoutURL() {
        let artifact = EnhancedAnigmaClient.Artifact(
            id: "artifact-2",
            name: "data.json",
            type: "json",
            size: 512
        )
        
        XCTAssertNil(artifact.url)
    }
    
    // MARK: - ClientError Tests
    
    func testClientErrorDescriptions() {
        let errors: [EnhancedAnigmaClient.ClientError] = [
            .invalidURL,
            .networkError(NSError(domain: "test", code: 1, userInfo: nil)),
            .invalidResponse,
            .jobNotFound("job-123"),
            .serverError(500, "Internal error"),
            .timeout,
            .authenticationRequired,
            .rateLimited,
            .unknown(NSError(domain: "test", code: 2, userInfo: nil))
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    // MARK: - DaemonStatus Tests
    
    func testDaemonStatusInitialization() {
        let status = DaemonStatus(
            isRunning: true,
            uptime: 3600.0,
            activeJobs: 5,
            queuedJobs: 2,
            cpuUsage: 45.5,
            memoryUsage: 67.8,
            version: "1.0.0"
        )
        
        XCTAssertTrue(status.isRunning)
        XCTAssertEqual(status.uptime, 3600.0)
        XCTAssertEqual(status.activeJobs, 5)
        XCTAssertEqual(status.queuedJobs, 2)
        XCTAssertEqual(status.cpuUsage, 45.5)
        XCTAssertEqual(status.memoryUsage, 67.8)
        XCTAssertEqual(status.version, "1.0.0")
    }
    
    // MARK: - URL Construction Tests
    
    func testBaseURLConstruction() {
        let config = EnhancedAnigmaClient.Configuration(
            host: "example.com",
            port: 9090,
            scheme: "https"
        )
        let client = EnhancedAnigmaClient(configuration: config)
        
        // Test that baseURL construction doesn't crash
        // Since baseURL() is private, we test it indirectly through other methods
        XCTAssertNotNil(client)
    }
    
    // MARK: - Request Creation Tests
    
    func testJobRequestPriorityCases() {
        let priorities: [EnhancedAnigmaClient.JobPriority] = [.low, .normal, .high, .urgent]
        let rawValues = priorities.map { $0.rawValue }
        
        XCTAssertEqual(rawValues, ["low", "normal", "high", "urgent"])
    }
    
    func testJobRequestPriorityCodable() throws {
        let priority = EnhancedAnigmaClient.JobPriority.high
        let data = try JSONEncoder().encode(priority)
        let decoded = try JSONDecoder().decode(EnhancedAnigmaClient.JobPriority.self, from: data)
        XCTAssertEqual(decoded, priority)
    }
    
    // MARK: - Sendable Conformance Tests
    
    func testSendableConformance() {
        // Test that all public types conform to Sendable
        let jobRequest = EnhancedAnigmaClient.JobRequest(
            action: "test",
            repoPath: "/path",
            filePath: "/file",
            instruction: "test"
        )
        let jobStatus = EnhancedAnigmaClient.JobStatus(
            jobId: "123",
            status: .queued,
            progress: 0.0,
            createdAt: Date(),
            updatedAt: Date()
        )
        let jobResult = EnhancedAnigmaClient.JobResult(
            jobId: "123",
            status: .completed,
            executionTime: 0.0
        )
        let artifact = EnhancedAnigmaClient.Artifact(
            id: "1",
            name: "test",
            type: "test",
            size: 0
        )
        
        // These assignments should compile if types conform to Sendable
        let _: any Sendable = jobRequest
        let _: any Sendable = jobStatus
        let _: any Sendable = jobResult
        let _: any Sendable = artifact
        
        XCTAssertTrue(true) // Test passes if compilation succeeds
    }
    
    // MARK: - Edge Cases
    
    func testEmptyMetadata() {
        let request = EnhancedAnigmaClient.JobRequest(
            action: "test",
            repoPath: "/path",
            filePath: "/file",
            instruction: "test",
            metadata: [:]
        )
        
        XCTAssertTrue(request.metadata.isEmpty)
    }
    
    func testZeroProgress() {
        let status = EnhancedAnigmaClient.JobStatus(
            jobId: "123",
            status: .queued,
            progress: 0.0,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        XCTAssertEqual(status.progress, 0.0)
    }
    
    func testFullProgress() {
        let status = EnhancedAnigmaClient.JobStatus(
            jobId: "123",
            status: .completed,
            progress: 1.0,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        XCTAssertEqual(status.progress, 1.0)
    }
}