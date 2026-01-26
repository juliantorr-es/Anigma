import XCTest
@testable import TelemetryCore

final class CapsuleDiagnosticsTests: XCTestCase {
    var diagnostics: DefaultCapsuleDiagnostics!
    
    override func setUp() {
        super.setUp()
        diagnostics = DefaultCapsuleDiagnostics()
        CorrelationIDContext.clear()
    }
    
    override func tearDown() {
        super.tearDown()
        CorrelationIDContext.clear()
    }
    
    // MARK: - Span Tests
    
    func testSpanCreation() {
        let span = diagnostics.beginSpan(
            name: "test_span",
            category: "test.category",
            correlationID: "test-123"
        )
        
        XCTAssertEqual(span.name, "test_span")
        XCTAssertEqual(span.category, "test.category")
        XCTAssertEqual(span.correlationID, "test-123")
        XCTAssertNotNil(span.startTime)
        XCTAssertNil(span.endTime)
        XCTAssertNil(span.status)
    }
    
    func testSpanTiming() {
        let span = diagnostics.beginSpan(
            name: "timed_span",
            category: "test.category",
            correlationID: "test-456"
        )
        
        XCTAssertNil(span.duration)
        
        // Simulate some work
        usleep(100_000) // 100ms
        
        span.end(status: .ok)
        
        XCTAssertNotNil(span.endTime)
        XCTAssertEqual(span.status, .ok)
        XCTAssertNotNil(span.duration)
        XCTAssertGreaterThan(span.duration ?? 0, 0.05) // At least 50ms
    }
    
    func testSpanTags() {
        let span = diagnostics.beginSpan(
            name: "tagged_span",
            category: "test.category",
            correlationID: "test-789",
            tags: ["initial": "value"]
        )
        
        XCTAssertEqual(span.tags["initial"], "value")
        
        span.addTag(key: "added", value: "tag")
        XCTAssertEqual(span.tags["added"], "tag")
    }
    
    // MARK: - Event Tests
    
    func testEventCreation() {
        diagnostics.event(
            level: .info,
            category: "test.event",
            message: "Test message",
            correlationID: "event-123"
        )
        
        let events = diagnostics.getAllEvents()
        XCTAssertEqual(events.count, 1)
        
        let event = events[0]
        XCTAssertEqual(event.level, .info)
        XCTAssertEqual(event.category, "test.event")
        XCTAssertEqual(event.message, "Test message")
        XCTAssertEqual(event.correlationID, "event-123")
    }
    
    func testEventWithTags() {
        diagnostics.event(
            level: .warning,
            category: "test.event",
            message: "Warning message",
            correlationID: "event-456",
            tags: ["severity": "high", "service": "capsule"]
        )
        
        let events = diagnostics.getAllEvents()
        let event = events[0]
        
        XCTAssertEqual(event.tags["severity"], "high")
        XCTAssertEqual(event.tags["service"], "capsule")
    }
    
    func testAutomaticCorrelationID() {
        CorrelationIDContext.setCurrent("auto-correlation-123")
        
        diagnostics.event(
            level: .info,
            category: "test.event",
            message: "Auto correlation test",
            correlationID: nil // Should use context
        )
        
        let events = diagnostics.getAllEvents()
        XCTAssertEqual(events[0].correlationID, "auto-correlation-123")
    }
    
    func testGetEventsSinceDate() {
        usleep(100_000) // 100ms
        
        diagnostics.event(
            level: .info,
            category: "test.event",
            message: "Event 1",
            correlationID: "test-1"
        )
        
        usleep(100_000) // 100ms
        let middleDate = Date()
        usleep(100_000) // 100ms
        
        diagnostics.event(
            level: .info,
            category: "test.event",
            message: "Event 2",
            correlationID: "test-2"
        )
        
        // Get events since middle date
        let recentEvents = diagnostics.getEvents(since: middleDate)
        XCTAssertEqual(recentEvents.count, 1)
        XCTAssertEqual(recentEvents[0].message, "Event 2")
    }
    
    func testClearEvents() {
        diagnostics.event(
            level: .info,
            category: "test.event",
            message: "Event 1",
            correlationID: "test-1"
        )
        
        diagnostics.event(
            level: .info,
            category: "test.event",
            message: "Event 2",
            correlationID: "test-2"
        )
        
        XCTAssertEqual(diagnostics.getAllEvents().count, 2)
        
        diagnostics.clearEvents()
        XCTAssertEqual(diagnostics.getAllEvents().count, 0)
    }
    
    // MARK: - Max Events Test
    
    func testMaxEventsLimit() {
        let limitedDiagnostics = DefaultCapsuleDiagnostics(maxEvents: 10)
        
        for i in 0..<20 {
            limitedDiagnostics.event(
                level: .info,
                category: "test.event",
                message: "Event \(i)",
                correlationID: "test-\(i)"
            )
        }
        
        let events = limitedDiagnostics.getAllEvents()
        XCTAssertEqual(events.count, 10)
        
        // Should keep the most recent events
        XCTAssertEqual(events.first?.message, "Event 10")
        XCTAssertEqual(events.last?.message, "Event 19")
    }
    
    // MARK: - DiagnosticEvent Serialization Tests
    
    func testEventJSONSerialization() {
        let event = DiagnosticEvent(
            timestamp: Date(),
            level: .info,
            category: "test.category",
            message: "Test message",
            correlationID: "test-123",
            duration: 1.5,
            tags: ["key": "value"]
        )
        
        let json = event.toJSON()
        
        XCTAssertNotNil(json["timestamp"])
        XCTAssertEqual(json["level"] as? String, "info")
        XCTAssertEqual(json["category"] as? String, "test.category")
        XCTAssertEqual(json["message"] as? String, "Test message")
        XCTAssertEqual(json["correlationID"] as? String, "test-123")
        XCTAssertEqual(json["duration"] as? TimeInterval, 1.5)
        XCTAssertEqual(json["tags"] as? [String: String], ["key": "value"])
    }
    
    func testEventCodable() throws {
        let event = DiagnosticEvent(
            level: .warning,
            category: "test.codable",
            message: "Codable test",
            correlationID: "test-456",
            tags: ["encode": "test"]
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedEvent = try decoder.decode(DiagnosticEvent.self, from: data)
        
        XCTAssertEqual(decodedEvent.level, event.level)
        XCTAssertEqual(decodedEvent.category, event.category)
        XCTAssertEqual(decodedEvent.message, event.message)
        XCTAssertEqual(decodedEvent.correlationID, event.correlationID)
    }
}

// MARK: - Redaction Tests

final class DiagnosticRedactionTests: XCTestCase {
    
    func testPasswordRedaction() {
        let input = "User authenticated with password='supersecret123'"
        let sanitized = DiagnosticRedactionRules.sanitize(input)
        
        XCTAssertFalse(sanitized.contains("supersecret123"))
        XCTAssertTrue(sanitized.contains("[REDACTED_PASSWORD]"))
    }
    
    func testAPIKeyRedaction() {
        let input = "API key: sk_live_abc123def456ghi789jkl"
        let sanitized = DiagnosticRedactionRules.sanitize(input)
        
        XCTAssertFalse(sanitized.contains("sk_live_"))
        XCTAssertTrue(sanitized.contains("[REDACTED_API_KEY]"))
    }
    
    func testJWTTokenRedaction() {
        let input = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
        let sanitized = DiagnosticRedactionRules.sanitize(input)
        
        XCTAssertFalse(sanitized.contains("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"))
        XCTAssertTrue(sanitized.contains("[REDACTED_JWT_TOKEN]"))
    }
    
    func testAWSSecretRedaction() {
        let input = "aws_secret_access_key=wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY"
        let sanitized = DiagnosticRedactionRules.sanitize(input)
        
        XCTAssertFalse(sanitized.contains("wJalrXUtnFEMI"))
        XCTAssertTrue(sanitized.contains("[REDACTED_AWS_SECRET]"))
    }
    
    func testConnectionStringRedaction() {
        let input = "connection_string=postgresql://user:password@host:5432/database"
        let sanitized = DiagnosticRedactionRules.sanitize(input)
        
        XCTAssertFalse(sanitized.contains("postgresql://"))
        XCTAssertTrue(sanitized.contains("[REDACTED_CONNECTION_STRING]"))
    }
    
    func testEmailRedaction() {
        let input = "User logged in: john.doe@example.com"
        let sanitized = DiagnosticRedactionRules.sanitize(input)
        
        XCTAssertFalse(sanitized.contains("john.doe@example.com"))
        XCTAssertTrue(sanitized.contains("[REDACTED_EMAIL]"))
    }
    
    func testIPAddressRedaction() {
        let input = "Connected to server at 192.168.1.100"
        let sanitized = DiagnosticRedactionRules.sanitize(input)
        
        XCTAssertFalse(sanitized.contains("192.168.1.100"))
        XCTAssertTrue(sanitized.contains("[REDACTED_IP_ADDRESS]"))
    }
    
    func testMultipleRedactions() {
        let input = "password=secret123 and api_key=sk_live_xyz789 from user john@example.com"
        let sanitized = DiagnosticRedactionRules.sanitize(input)
        
        XCTAssertFalse(sanitized.contains("secret123"))
        XCTAssertFalse(sanitized.contains("sk_live_xyz789"))
        XCTAssertFalse(sanitized.contains("john@example.com"))
        
        XCTAssertTrue(sanitized.contains("[REDACTED_PASSWORD]"))
        XCTAssertTrue(sanitized.contains("[REDACTED_API_KEY]"))
        XCTAssertTrue(sanitized.contains("[REDACTED_EMAIL]"))
    }
    
    func testContainsSensitiveData() {
        XCTAssertTrue(DiagnosticRedactionRules.containsSensitiveData("password=secret"))
        XCTAssertTrue(DiagnosticRedactionRules.containsSensitiveData("api_key=abc123"))
        XCTAssertFalse(DiagnosticRedactionRules.containsSensitiveData("normal log message"))
    }
    
    func testDetectPatterns() {
        let input = "password=secret123 and api_key=sk_live_xyz"
        let detected = DiagnosticRedactionRules.detectPatterns(input)
        
        XCTAssertGreaterThan(detected.count, 0)
        
        let patternNames = detected.map { $0.0 }
        XCTAssertTrue(patternNames.contains("PASSWORD"))
        XCTAssertTrue(patternNames.contains("API_KEY"))
    }
    
    func testNormalMessageNotRedacted() {
        let input = "Processing completed successfully for job-12345"
        let sanitized = DiagnosticRedactionRules.sanitize(input)
        
        XCTAssertEqual(input, sanitized)
    }
}

// MARK: - Correlation ID Tests

final class CorrelationIDContextTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        CorrelationIDContext.clear()
    }
    
    override func tearDown() {
        super.tearDown()
        CorrelationIDContext.clear()
    }
    
    func testDefaultCorrelationID() {
        let id1 = CorrelationIDContext.current
        XCTAssertNotNil(id1)
        XCTAssertFalse(id1.isEmpty)
    }
    
    func testSetCorrelationID() {
        CorrelationIDContext.setCurrent("test-123")
        XCTAssertEqual(CorrelationIDContext.current, "test-123")
    }
    
    func testCorrelationIDPersistence() {
        CorrelationIDContext.setCurrent("persistent-id")
        let id1 = CorrelationIDContext.current
        let _ = CorrelationIDContext.current
        
        XCTAssertEqual(id1, "persistent-id")
    }

    
    func testClearCorrelationID() {
        CorrelationIDContext.setCurrent("to-clear")
        CorrelationIDContext.clear()
        
        let id1 = CorrelationIDContext.current
        
        // After clear, should get a new ID each time
        XCTAssertNotEqual(id1, "to-clear")
    }
    
    func testTaskLocalCorrelationID() async {
        let testID = "task-local-123"
        
        await CorrelationIDContext.withID(testID) {
            XCTAssertEqual(CorrelationIDContext.current, testID)
            
            // Check propagation to child task
            let childTaskID = await Task {
                return CorrelationIDContext.current
            }.value
            
            XCTAssertEqual(childTaskID, testID)
        }
        
        // Outside of block, it should be different
        XCTAssertNotEqual(CorrelationIDContext.current, testID)
    }
}

// MARK: - Integration Tests

final class CapsuleDiagnosticsIntegrationTests: XCTestCase {
    var diagnostics: DefaultCapsuleDiagnostics!
    
    override func setUp() {
        super.setUp()
        diagnostics = DefaultCapsuleDiagnostics()
        CorrelationIDContext.clear()
    }
    
    override func tearDown() {
        super.tearDown()
        CorrelationIDContext.clear()
    }
    
    func testFullDiagnosticFlow() {
        // Set correlation ID for the operation
        CorrelationIDContext.setCurrent("job-integration-test")
        
        // Begin a span
        let span = diagnostics.beginSpan(
            name: "process",
            category: "textpipeline.unicode",
            tags: ["input_size": "1000"]
        )
        
        // Record events during processing
        diagnostics.event(
            level: .info,
            category: "textpipeline.unicode",
            message: "Started processing with password=test123",
            tags: ["step": "start"]
        )
        
        usleep(50_000) // 50ms
        
        span.addTag(key: "processed_count", value: "500")
        span.recordEvent(level: .info, message: "Halfway through processing")
        
        usleep(50_000) // 50ms
        
        diagnostics.event(
            level: .info,
            category: "textpipeline.unicode",
            message: "Completed processing",
            tags: ["step": "end"]
        )
        
        // End the span
        span.end(status: .ok)
        
        // Verify all events were recorded
        let events = diagnostics.getAllEvents()
        XCTAssertGreaterThanOrEqual(events.count, 2)
        
        // Verify redaction happened
        let firstEvent = events[0]
        XCTAssertTrue(firstEvent.message.contains("[REDACTED_PASSWORD]"))
        XCTAssertFalse(firstEvent.message.contains("test123"))
        
        // Verify correlation ID
        for event in events {
            XCTAssertEqual(event.correlationID, "job-integration-test")
        }
        
        // Verify JSON serialization
        for event in events {
            let json = event.toJSON()
            XCTAssertNotNil(json["timestamp"])
            XCTAssertNotNil(json["level"])
            XCTAssertNotNil(json["message"])
        }
    }
}
