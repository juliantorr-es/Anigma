// Copyright (c) 2025 Anigma
// Licensed under the MIT License

import XCTest
import HarmoniaModule
import AccessumModule
import ObservatoriumModule

// MARK: - Adapter Integration Tests

final class AccessumServiceAdapterTests: XCTestCase {
    var adapter: AccessumServiceAdapter!
    var registry: ServiceRegistry!
    
    override func setUp() async throws {
        try await super.setUp()
        registry = ServiceRegistry()
        adapter = AccessumServiceAdapter()
    }
    
    // MARK: - Initialize Tests
    
    func testAdapterInitialization() async throws {
        XCTAssertEqual(adapter.serviceId, "accessum-service")
        XCTAssertEqual(adapter.descriptor.name, "Accessum Service")
        XCTAssertEqual(adapter.descriptor.capabilities.count, 3)
    }
    
    func testAdapterCapabilities() async {
        let capabilities = adapter.descriptor.capabilities
        let actions = Set(capabilities.map { $0.action })
        
        XCTAssertTrue(actions.contains("assessContent"))
        XCTAssertTrue(actions.contains("createClient"))
        XCTAssertTrue(actions.contains("updateClient"))
    }
    
    // MARK: - Action Tests
    
    func testAssessContentAction() async throws {
        let input: [String: AnyCodable] = [
            "content": .string("<html><body>Test content</body></html>"),
            "wcagLevel": .string("AA")
        ]
        
        let result = try await adapter.execute(action: "assessContent", input: input)
        
        XCTAssertNotNil(result["assessmentId"])
        XCTAssertNotNil(result["overallScore"])
        XCTAssertNotNil(result["wcagCompliance"])
        XCTAssertNotNil(result["screenReaderCompatible"])
        XCTAssertNotNil(result["keyboardAccessible"])
        XCTAssertNotNil(result["colorContrastIssuesCount"])
    }
    
    func testAssessContentMissingContent() async throws {
        let input: [String: AnyCodable] = [
            "wcagLevel": .string("AA")
        ]
        
        do {
            _ = try await adapter.execute(action: "assessContent", input: input)
            XCTFail("Should throw missingRequiredParameter error")
        } catch let error as AccessumAdapterError {
            if case .missingRequiredParameter(let param) = error {
                XCTAssertEqual(param, "content")
            } else {
                XCTFail("Expected missingRequiredParameter error")
            }
        }
    }
    
    func testCreateClientAction() async throws {
        let input: [String: AnyCodable] = [
            "requirements": .dictionary([
                "wcagLevel": .string("AAA")
            ]),
            "preferences": .dictionary([
                "altTextGenerationEnabled": .bool(true),
                "screenReaderOptimized": .bool(true)
            ])
        ]
        
        let result = try await adapter.execute(action: "createClient", input: input)
        
        XCTAssertNotNil(result["clientId"])
        XCTAssertNotNil(result["createdAt"])
        
        if case .string(let clientId) = result["clientId"] {
            // Verify UUID format
            XCTAssertNotNil(UUID(uuidString: clientId))
        } else {
            XCTFail("clientId should be a string")
        }
    }
    
    func testUpdateClientAction() async throws {
        // First create a client
        let createInput: [String: AnyCodable] = [:]
        let createResult = try await adapter.execute(action: "createClient", input: createInput)
        
        guard case .string(let clientId) = createResult["clientId"] else {
            XCTFail("Failed to create client")
            return
        }
        
        // Then update it
        let updateInput: [String: AnyCodable] = [
            "clientId": .string(clientId),
            "preferences": .dictionary([
                "highContrastMode": .bool(true)
            ])
        ]
        
        let updateResult = try await adapter.execute(action: "updateClient", input: updateInput)
        
        XCTAssertNotNil(updateResult["clientId"])
        if case .bool(let updated) = updateResult["updated"] {
            XCTAssertTrue(updated)
        } else {
            XCTFail("updated should be a boolean")
        }
    }
    
    func testUnknownAction() async throws {
        let input: [String: AnyCodable] = [:]
        
        do {
            _ = try await adapter.execute(action: "unknownAction", input: input)
            XCTFail("Should throw unknownAction error")
        } catch let error as AccessumAdapterError {
            if case .unknownAction(let action) = error {
                XCTAssertEqual(action, "unknownAction")
            } else {
                XCTFail("Expected unknownAction error")
            }
        }
    }
    
    // MARK: - Health Check Tests
    
    func testHealthCheck() async throws {
        let status = try await adapter.getHealth()
        
        XCTAssertNotEqual(status, .unknown)
        XCTAssertTrue([.healthy, .degraded, .unhealthy].contains(status))
    }
    
    // MARK: - Registration Tests
    
    func testAdapterRegistration() async throws {
        try await registry.register(service: adapter)
        
        let retrievedAdapter = try await registry.getService(id: adapter.serviceId)
        XCTAssertEqual(retrievedAdapter.serviceId, adapter.serviceId)
    }
    
    func testCapabilityLookup() async throws {
        try await registry.register(service: adapter)
        
        let capability = try await registry.getCapability(
            serviceId: adapter.serviceId,
            action: "assessContent"
        )
        
        XCTAssertEqual(capability.action, "assessContent")
        XCTAssertEqual(capability.timeout, 30.0)
    }
}

// MARK: - Observatorium Service Adapter Tests

final class ObservatoriumServiceAdapterTests: XCTestCase {
    var adapter: ObservatoriumServiceAdapter!
    var registry: ServiceRegistry!
    
    override func setUp() async throws {
        try await super.setUp()
        registry = ServiceRegistry()
        adapter = ObservatoriumServiceAdapter()
    }
    
    // MARK: - Initialize Tests
    
    func testAdapterInitialization() async throws {
        XCTAssertEqual(adapter.serviceId, "observatorium-service")
        XCTAssertEqual(adapter.descriptor.name, "Observatorium Service")
        XCTAssertEqual(adapter.descriptor.capabilities.count, 5)
    }
    
    func testAdapterCapabilities() async {
        let capabilities = adapter.descriptor.capabilities
        let actions = Set(capabilities.map { $0.action })
        
        XCTAssertTrue(actions.contains("recordEvent"))
        XCTAssertTrue(actions.contains("recordMetric"))
        XCTAssertTrue(actions.contains("getMetrics"))
        XCTAssertTrue(actions.contains("createAlert"))
        XCTAssertTrue(actions.contains("getActiveAlerts"))
    }
    
    // MARK: - Action Tests
    
    func testRecordEventAction() async throws {
        let input: [String: AnyCodable] = [
            "type": .string("error"),
            "source": .string("test-service"),
            "data": .dictionary([
                "message": .string("Test error"),
                "code": .string("ERR_TEST")
            ]),
            "severity": .string("error")
        ]
        
        let result = try await adapter.execute(action: "recordEvent", input: input)
        
        XCTAssertNotNil(result["eventId"])
        if case .bool(let recorded) = result["recorded"] {
            XCTAssertTrue(recorded)
        } else {
            XCTFail("recorded should be a boolean")
        }
    }
    
    func testRecordEventMissingType() async throws {
        let input: [String: AnyCodable] = [
            "source": .string("test-service")
        ]
        
        do {
            _ = try await adapter.execute(action: "recordEvent", input: input)
            XCTFail("Should throw missingRequiredParameter error")
        } catch let error as ObservatoriumAdapterError {
            if case .missingRequiredParameter(let param) = error {
                XCTAssertEqual(param, "type")
            } else {
                XCTFail("Expected missingRequiredParameter error")
            }
        }
    }
    
    func testRecordMetricAction() async throws {
        let input: [String: AnyCodable] = [
            "name": .string("response_time"),
            "value": .double(125.5),
            "unit": .string("ms"),
            "tags": .dictionary([
                "endpoint": .string("/api/assess")
            ])
        ]
        
        let result = try await adapter.execute(action: "recordMetric", input: input)
        
        XCTAssertNotNil(result["metricId"])
        if case .bool(let recorded) = result["recorded"] {
            XCTAssertTrue(recorded)
        } else {
            XCTFail("recorded should be a boolean")
        }
        
        if case .double(let value) = result["value"] {
            XCTAssertEqual(value, 125.5)
        } else {
            XCTFail("value should be a double")
        }
    }
    
    func testGetMetricsAction() async throws {
        // First record some metrics
        let metricInput: [String: AnyCodable] = [
            "name": .string("test_metric"),
            "value": .double(42.0)
        ]
        _ = try await adapter.execute(action: "recordMetric", input: metricInput)
        
        // Then get metrics
        let getInput: [String: AnyCodable] = [
            "timeRange": .string("lastDay")
        ]
        
        let result = try await adapter.execute(action: "getMetrics", input: getInput)
        
        XCTAssertNotNil(result["timeRange"])
        XCTAssertNotNil(result["eventCount"])
        XCTAssertNotNil(result["errorCount"])
        XCTAssertNotNil(result["avgResponseTime"])
    }
    
    func testCreateAlertAction() async throws {
        let input: [String: AnyCodable] = [
            "name": .string("High Error Rate"),
            "condition": .string("errorCount > 10"),
            "severity": .string("critical"),
            "message": .string("Error rate exceeded threshold")
        ]
        
        let result = try await adapter.execute(action: "createAlert", input: input)
        
        XCTAssertNotNil(result["ruleId"])
        if case .bool(let created) = result["created"] {
            XCTAssertTrue(created)
        } else {
            XCTFail("created should be a boolean")
        }
    }
    
    func testGetActiveAlertsAction() async throws {
        // Create an alert first
        let createInput: [String: AnyCodable] = [
            "name": .string("Test Alert"),
            "condition": .string("test"),
            "severity": .string("medium")
        ]
        _ = try await adapter.execute(action: "createAlert", input: createInput)
        
        // Get active alerts
        let getInput: [String: AnyCodable] = [:]
        let result = try await adapter.execute(action: "getActiveAlerts", input: getInput)
        
        XCTAssertNotNil(result["alerts"])
        XCTAssertNotNil(result["count"])
        XCTAssertNotNil(result["critical"])
    }
    
    // MARK: - Health Check Tests
    
    func testHealthCheck() async throws {
        let status = try await adapter.getHealth()
        
        XCTAssertNotEqual(status, .unknown)
        XCTAssertTrue([.healthy, .degraded, .unhealthy].contains(status))
    }
    
    // MARK: - Registration Tests
    
    func testAdapterRegistration() async throws {
        try await registry.register(service: adapter)
        
        let retrievedAdapter = try await registry.getService(id: adapter.serviceId)
        XCTAssertEqual(retrievedAdapter.serviceId, adapter.serviceId)
    }
}

// MARK: - Service Adapter Factory Tests

final class ServiceAdapterFactoryTests: XCTestCase {
    var factory: ServiceAdapterFactory!
    var registry: ServiceRegistry!
    
    override func setUp() async throws {
        try await super.setUp()
        registry = ServiceRegistry()
        factory = ServiceAdapterFactory(registry: registry)
    }
    
    // MARK: - Factory Creation Tests
    
    func testCreateAccessumAdapter() async throws {
        let adapter = try await factory.createAccessumAdapter()
        XCTAssertEqual(adapter.serviceId, "accessum-service")
        XCTAssertTrue(try await factory.hasAdapter("accessum-service"))
    }
    
    func testCreateObservatoriumAdapter() async throws {
        let adapter = try await factory.createObservatoriumAdapter()
        XCTAssertEqual(adapter.serviceId, "observatorium-service")
        XCTAssertTrue(try await factory.hasAdapter("observatorium-service"))
    }
    
    func testCreateAllStandardAdapters() async throws {
        let adapters = try await factory.createAllStandardAdapters()
        
        XCTAssertEqual(adapters.count, 2)
        XCTAssertNotNil(adapters["accessum-service"])
        XCTAssertNotNil(adapters["observatorium-service"])
    }
    
    // MARK: - Adapter Lookup Tests
    
    func testGetAdapter() async throws {
        let createdAdapter = try await factory.createAccessumAdapter()
        let retrievedAdapter = factory.getAdapter("accessum-service")
        
        XCTAssertNotNil(retrievedAdapter)
        XCTAssertEqual(createdAdapter.serviceId, retrievedAdapter?.serviceId)
    }
    
    func testHasAdapter() async throws {
        XCTAssertFalse(try await factory.hasAdapter("accessum-service"))
        
        _ = try await factory.createAccessumAdapter()
        XCTAssertTrue(try await factory.hasAdapter("accessum-service"))
    }
    
    func testGetAllAdapters() async throws {
        _ = try await factory.createAccessumAdapter()
        _ = try await factory.createObservatoriumAdapter()
        
        let adapters = factory.getAllAdapters()
        XCTAssertEqual(adapters.count, 2)
    }
    
    // MARK: - Health Management Tests
    
    func testCheckAllAdaptersHealth() async throws {
        _ = try await factory.createAllStandardAdapters()
        
        let healthStatuses = try await factory.checkAllAdaptersHealth()
        
        XCTAssertEqual(healthStatuses.count, 2)
        for (_, status) in healthStatuses {
            XCTAssertNotEqual(status, .unknown)
        }
    }
    
    func testCheckAdapterHealth() async throws {
        _ = try await factory.createAccessumAdapter()
        
        let status = try await factory.checkAdapterHealth("accessum-service")
        XCTAssertNotEqual(status, .unknown)
    }
    
    func testCheckNonexistentAdapterHealth() async throws {
        do {
            _ = try await factory.checkAdapterHealth("nonexistent")
            XCTFail("Should throw adapterNotFound error")
        } catch let error as ServiceAdapterFactory.FactoryError {
            if case .adapterNotFound(let serviceId) = error {
                XCTAssertEqual(serviceId, "nonexistent")
            } else {
                XCTFail("Expected adapterNotFound error")
            }
        }
    }
    
    // MARK: - Convenience Factory Methods Tests
    
    func testCreateWithAllAdapters() async throws {
        let factory = try await ServiceAdapterFactory.createWithAllAdapters(registry: registry)
        
        XCTAssertTrue(try await factory.hasAdapter("accessum-service"))
        XCTAssertTrue(try await factory.hasAdapter("observatorium-service"))
    }
    
    func testCreateWithAccessumOnly() async throws {
        let factory = try await ServiceAdapterFactory.createWithAccessumOnly(registry: registry)
        
        XCTAssertTrue(try await factory.hasAdapter("accessum-service"))
        XCTAssertFalse(try await factory.hasAdapter("observatorium-service"))
    }
    
    func testCreateWithObservatoriumOnly() async throws {
        let factory = try await ServiceAdapterFactory.createWithObservatoriumOnly(registry: registry)
        
        XCTAssertFalse(try await factory.hasAdapter("accessum-service"))
        XCTAssertTrue(try await factory.hasAdapter("observatorium-service"))
    }
}

// MARK: - Workflow Integration Tests

final class AdapterWorkflowIntegrationTests: XCTestCase {
    var registry: ServiceRegistry!
    var factory: ServiceAdapterFactory!
    
    override func setUp() async throws {
        try await super.setUp()
        registry = ServiceRegistry()
        factory = ServiceAdapterFactory(registry: registry)
        _ = try await factory.createAllStandardAdapters()
    }
    
    // MARK: - Workflow Definition Tests
    
    func testWorkflowWithAccessumAdapter() async throws {
        let steps = [
            WorkflowStep(
                id: "assess",
                serviceId: "accessum-service",
                action: "assessContent",
                input: [
                    "content": .string("<p>Test</p>"),
                    "wcagLevel": .string("AA")
                ]
            )
        ]
        
        let definition = WorkflowDefinition(
            id: "test-workflow",
            name: "Assessment Workflow",
            steps: steps
        )
        
        XCTAssertEqual(definition.steps.count, 1)
        XCTAssertEqual(definition.steps[0].serviceId, "accessum-service")
        XCTAssertEqual(definition.steps[0].action, "assessContent")
    }
    
    func testWorkflowWithObservatoriumAdapter() async throws {
        let steps = [
            WorkflowStep(
                id: "record-event",
                serviceId: "observatorium-service",
                action: "recordEvent",
                input: [
                    "type": .string("error"),
                    "source": .string("test"),
                    "severity": .string("warning")
                ]
            ),
            WorkflowStep(
                id: "record-metric",
                serviceId: "observatorium-service",
                action: "recordMetric",
                input: [
                    "name": .string("test_metric"),
                    "value": .double(42.0)
                ],
                dependencies: ["record-event"]
            )
        ]
        
        let definition = WorkflowDefinition(
            id: "observatorium-workflow",
            name: "Telemetry Workflow",
            steps: steps
        )
        
        XCTAssertEqual(definition.steps.count, 2)
        XCTAssertEqual(definition.steps[1].dependencies, ["record-event"])
    }
    
    // MARK: - Multi-Adapter Workflow Tests
    
    func testCrossAdapterWorkflow() async throws {
        let steps = [
            WorkflowStep(
                id: "assess",
                serviceId: "accessum-service",
                action: "assessContent",
                input: [
                    "content": .string("<p>Test</p>")
                ]
            ),
            WorkflowStep(
                id: "record-result",
                serviceId: "observatorium-service",
                action: "recordEvent",
                input: [
                    "type": .string("performanceMetric"),
                    "source": .string("assessment-service"),
                    "severity": .string("info")
                ],
                dependencies: ["assess"]
            )
        ]
        
        let definition = WorkflowDefinition(
            id: "cross-adapter-workflow",
            name: "Assessment with Telemetry",
            steps: steps,
            parallelizable: false
        )
        
        XCTAssertEqual(definition.steps.count, 2)
        XCTAssertFalse(definition.parallelizable)
        XCTAssertEqual(definition.steps[1].dependencies?[0], "assess")
    }
}

// MARK: - Error Handling Tests

final class AdapterErrorHandlingTests: XCTestCase {
    var adapter: AccessumServiceAdapter!
    
    override func setUp() async throws {
        try await super.setUp()
        adapter = AccessumServiceAdapter()
    }
    
    func testAccessumAdapterErrors() {
        let unknownActionError = AccessumAdapterError.unknownAction("test")
        XCTAssertNotNil(unknownActionError.errorDescription)
        
        let missingParamError = AccessumAdapterError.missingRequiredParameter("content")
        XCTAssertNotNil(missingParamError.errorDescription)
        
        let noUpdatesError = AccessumAdapterError.noUpdatesProvided
        XCTAssertNotNil(noUpdatesError.errorDescription)
    }
}
