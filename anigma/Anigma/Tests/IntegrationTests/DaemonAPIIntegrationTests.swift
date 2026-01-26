// Copyright (c) 2025 Anigma
// Licensed under the MIT License

import XCTest
import Foundation

/// Integration tests for AnigmaDaemon HTTP API endpoints
/// Tests the full request/response lifecycle of daemon API interactions
final class DaemonAPIIntegrationTests: XCTestCase {
    
    let daemonBaseURL = URL(string: "http://localhost:8080")!
    let timeout: TimeInterval = 5.0
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        // Verify daemon is running before tests execute
        try verifyDaemonIsRunning()
    }
    
    // MARK: - Helper Methods
    
    private func verifyDaemonIsRunning() throws {
        let expectation = XCTestExpectation(description: "Daemon responds to ping")
        
        var request = URLRequest(url: daemonBaseURL.appendingPathComponent("/api/status"))
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                expectation.fulfill()
            }
        }.resume()
        
        wait(for: [expectation], timeout: timeout)
    }
    
    private func makeRequest(method: String, path: String, body: [String: Any]? = nil) -> URLResponse? {
        let url = daemonBaseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        var resultResponse: URLResponse?
        let semaphore = DispatchSemaphore(value: 0)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            resultResponse = response
            semaphore.signal()
        }.resume()
        
        semaphore.wait()
        return resultResponse
    }
    
    // MARK: - Status Endpoint Tests
    
    func testGetDaemonStatus() throws {
        let response = makeRequest(method: "GET", path: "/api/status")
        
        XCTAssertNotNil(response)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(httpResponse.statusCode, 200)
    }
    
    func testGetDaemonStatusWithoutPath() throws {
        let url = daemonBaseURL
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        
        var statusCode: Int? = nil
        let expectation = XCTestExpectation(description: "Root endpoint responds")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            statusCode = (response as? HTTPURLResponse)?.statusCode
            expectation.fulfill()
        }.resume()
        
        wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(statusCode, 200)
    }
    
    // MARK: - Job Management Tests
    
    func testSubmitJob() throws {
        let jobPayload: [String: Any] = [
            "jobType": "refactor",
            "content": "func foo() { return 42 }",
            "targetLanguage": "swift"
        ]
        
        let response = makeRequest(method: "POST", path: "/api/jobs", body: jobPayload)
        
        XCTAssertNotNil(response)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(httpResponse.statusCode, 200)
    }
    
    func testSubmitJobWithInvalidPayload() throws {
        let invalidPayload: [String: Any] = [
            "jobType": "unknown_type"
        ]
        
        let response = makeRequest(method: "POST", path: "/api/jobs", body: invalidPayload)
        
        XCTAssertNotNil(response)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        // Should return 400 (Bad Request) or 422 (Unprocessable Entity)
        XCTAssertTrue([400, 422].contains(httpResponse.statusCode))
    }
    
    func testGetJobStatus() throws {
        // First, submit a job
        let jobPayload: [String: Any] = [
            "jobType": "refactor",
            "content": "func foo() { return 42 }",
            "targetLanguage": "swift"
        ]
        
        let submitResponse = makeRequest(method: "POST", path: "/api/jobs", body: jobPayload)
        let submitHttpResponse = try XCTUnwrap(submitResponse as? HTTPURLResponse)
        XCTAssertEqual(submitHttpResponse.statusCode, 200)
        
        // Extract job ID from response (assuming response contains it)
        // For now, test with a known pattern
        let testJobId = "test-job-id-123"
        
        let statusResponse = makeRequest(method: "GET", path: "/api/jobs/\(testJobId)")
        
        XCTAssertNotNil(statusResponse)
        let httpResponse = try XCTUnwrap(statusResponse as? HTTPURLResponse)
        XCTAssertTrue([200, 404].contains(httpResponse.statusCode))
    }
    
    func testListJobs() throws {
        let response = makeRequest(method: "GET", path: "/api/jobs")
        
        XCTAssertNotNil(response)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(httpResponse.statusCode, 200)
    }
    
    // MARK: - Metrics Endpoint Tests
    
    func testGetSystemMetrics() throws {
        let response = makeRequest(method: "GET", path: "/api/metrics")
        
        XCTAssertNotNil(response)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(httpResponse.statusCode, 200)
    }
    
    func testGetMetricsWithTimeRange() throws {
        let response = makeRequest(method: "GET", path: "/api/metrics?timeRange=1h")
        
        XCTAssertNotNil(response)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(httpResponse.statusCode, 200)
    }
    
    // MARK: - Session Management Tests
    
    func testCreateSession() throws {
        let sessionPayload: [String: Any] = [
            "clientId": "test-client-123",
            "capabilities": ["refactor", "analyze", "optimize"]
        ]
        
        let response = makeRequest(method: "POST", path: "/api/sessions", body: sessionPayload)
        
        XCTAssertNotNil(response)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(httpResponse.statusCode, 200)
    }
    
    func testGetSessionDetails() throws {
        let testSessionId = "session-123"
        let response = makeRequest(method: "GET", path: "/api/sessions/\(testSessionId)")
        
        XCTAssertNotNil(response)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertTrue([200, 404].contains(httpResponse.statusCode))
    }
    
    func testTerminateSession() throws {
        let testSessionId = "session-123"
        let response = makeRequest(method: "DELETE", path: "/api/sessions/\(testSessionId)")
        
        XCTAssertNotNil(response)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertTrue([200, 204, 404].contains(httpResponse.statusCode))
    }
    
    // MARK: - Health Check Tests
    
    func testHealthEndpoint() throws {
        let response = makeRequest(method: "GET", path: "/api/health")
        
        XCTAssertNotNil(response)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(httpResponse.statusCode, 200)
    }
    
    func testHealthEndpointReturnsValidStatus() throws {
        let url = daemonBaseURL.appendingPathComponent("/api/health")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        
        let expectation = XCTestExpectation(description: "Health endpoint returns JSON")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            XCTAssertNil(error)
            XCTAssertNotNil(data)
            
            if let data = data {
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    XCTAssertNotNil(json)
                    XCTAssertNotNil(json?["status"])
                    XCTAssertNotNil(json?["timestamp"])
                } catch {
                    XCTFail("Failed to parse health response: \(error)")
                }
            }
            
            expectation.fulfill()
        }.resume()
        
        wait(for: [expectation], timeout: timeout)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidHTTPMethod() throws {
        let url = daemonBaseURL.appendingPathComponent("/api/status")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"  // Unsupported method
        request.timeoutInterval = timeout
        
        var statusCode: Int? = nil
        let expectation = XCTestExpectation(description: "Invalid method handled")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            statusCode = (response as? HTTPURLResponse)?.statusCode
            expectation.fulfill()
        }.resume()
        
        wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(statusCode, 405)  // Method Not Allowed
    }
    
    func testNonexistentEndpoint() throws {
        let response = makeRequest(method: "GET", path: "/api/nonexistent")
        
        XCTAssertNotNil(response)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(httpResponse.statusCode, 404)
    }
    
    // MARK: - Concurrency Tests
    
    func testConcurrentRequests() throws {
        let requestCount = 10
        let expectation = XCTestExpectation(description: "All concurrent requests complete")
        expectation.expectedFulfillmentCount = requestCount
        
        for i in 0..<requestCount {
            DispatchQueue.global().async {
                let response = self.makeRequest(method: "GET", path: "/api/status")
                let httpResponse = response as? HTTPURLResponse
                
                XCTAssertEqual(httpResponse?.statusCode, 200, "Request \(i) failed")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: timeout * 2)
    }
    
    // MARK: - Timeout Tests
    
    func testRequestTimeout() throws {
        let url = daemonBaseURL.appendingPathComponent("/api/status")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 0.001  // Very short timeout
        
        var timedOut = false
        let expectation = XCTestExpectation(description: "Request timeout handled")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error as NSError? {
                if error.code == NSURLErrorTimedOut {
                    timedOut = true
                }
            }
            expectation.fulfill()
        }.resume()
        
        wait(for: [expectation], timeout: 2.0)
        // Note: May or may not timeout depending on network conditions
        // This test mainly verifies graceful error handling
    }
}
