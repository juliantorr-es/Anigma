// Copyright (c) 2025 Anigma
// Licensed under the MIT License

import Foundation
import HarmoniaModule
import AccessumModule
import ObservatoriumModule

// MARK: - Usage Examples & Integration Patterns

/// # Service Adapter Usage Examples
///
/// This file demonstrates practical usage patterns for AccessumServiceAdapter
/// and ObservatoriumServiceAdapter in HarmoniaModule workflows.

// MARK: - Example 1: Basic Adapter Setup

/// Setup adapters with automatic registration
func setupAdapters() async throws {
    let registry = ServiceRegistry()
    let factory = ServiceAdapterFactory(registry: registry)
    
    // Create and register all standard adapters
    _ = try await factory.createAllStandardAdapters()
    
    // Or create specific adapters
    let accessumAdapter = try await factory.createAccessumAdapter()
    let observatoriumAdapter = try await factory.createObservatoriumAdapter()
}

// MARK: - Example 2: Single Adapter Assessment Workflow

/// Perform accessibility assessment on HTML content
func assessContentWorkflow() async throws {
    let registry = ServiceRegistry()
    let adapter = AccessumServiceAdapter()
    try await registry.register(service: adapter)
    
    // Execute assessment action
    let assessmentInput: [String: AnyCodable] = [
        "content": .string("""
            <html>
            <head><title>Example Page</title></head>
            <body>
                <h1>Welcome</h1>
                <p>This is example content.</p>
            </body>
            </html>
            """),
        "wcagLevel": .string("AA")
    ]
    
    let result = try await adapter.execute(
        action: "assessContent",
        input: assessmentInput
    )
    
    // Process results
    if case .double(let score) = result["overallScore"] {
        print("Assessment score: \(score)")
    }
    
    if case .int(let issueCount) = result["colorContrastIssuesCount"] {
        print("Color contrast issues: \(issueCount)")
    }
}

// MARK: - Example 3: Client Management

/// Create and manage accessibility clients
func clientManagementWorkflow() async throws {
    let adapter = AccessumServiceAdapter()
    
    // Create a new client
    let createInput: [String: AnyCodable] = [
        "requirements": .dictionary([
            "wcagLevel": .string("AAA")
        ]),
        "preferences": .dictionary([
            "altTextGenerationEnabled": .bool(true),
            "screenReaderOptimized": .bool(true),
            "keyboardNavigationOptimized": .bool(true),
            "highContrastMode": .bool(false)
        ])
    ]
    
    let createResult = try await adapter.execute(
        action: "createClient",
        input: createInput
    )
    
    guard case .string(let clientId) = createResult["clientId"] else {
        throw NSError(domain: "ClientCreation", code: -1)
    }
    
    print("Created client: \(clientId)")
    
    // Update client preferences
    let updateInput: [String: AnyCodable] = [
        "clientId": .string(clientId),
        "preferences": .dictionary([
            "highContrastMode": .bool(true)
        ])
    ]
    
    let updateResult = try await adapter.execute(
        action: "updateClient",
        input: updateInput
    )
    
    if case .int(let fieldsUpdated) = updateResult["fieldsUpdated"] {
        print("Updated \(fieldsUpdated) fields")
    }
}

// MARK: - Example 4: Telemetry Recording

/// Record events and metrics to observatorium
func telemetryRecordingWorkflow() async throws {
    let adapter = ObservatoriumServiceAdapter()
    
    // Record a system event
    let eventInput: [String: AnyCodable] = [
        "type": .string("performanceMetric"),
        "source": .string("accessibility-module"),
        "data": .dictionary([
            "action": .string("assessment_completed"),
            "duration_ms": .string("1250")
        ]),
        "severity": .string("info")
    ]
    
    let eventResult = try await adapter.execute(
        action: "recordEvent",
        input: eventInput
    )
    
    if case .bool(let recorded) = eventResult["recorded"] {
        print("Event recorded: \(recorded)")
    }
    
    // Record a performance metric
    let metricInput: [String: AnyCodable] = [
        "name": .string("assessment_duration"),
        "value": .double(1250.5),
        "unit": .string("milliseconds"),
        "tags": .dictionary([
            "service": .string("accessum"),
            "wcag_level": .string("AA")
        ])
    ]
    
    let metricResult = try await adapter.execute(
        action: "recordMetric",
        input: metricInput
    )
    
    if case .string(let metricId) = metricResult["metricId"] {
        print("Metric recorded: \(metricId)")
    }
}

// MARK: - Example 5: Metrics Aggregation

/// Retrieve and analyze aggregated metrics
func metricsRetrievalWorkflow() async throws {
    let adapter = ObservatoriumServiceAdapter()
    
    // Get metrics for last 24 hours
    let metricsInput: [String: AnyCodable] = [
        "timeRange": .string("lastDay")
    ]
    
    let metricsResult = try await adapter.execute(
        action: "getMetrics",
        input: metricsInput
    )
    
    // Extract metrics
    if case .int(let eventCount) = metricsResult["eventCount"] {
        print("Total events: \(eventCount)")
    }
    
    if case .int(let errorCount) = metricsResult["errorCount"] {
        print("Error count: \(errorCount)")
    }
    
    if case .double(let avgResponseTime) = metricsResult["avgResponseTime"] {
        print("Average response time: \(avgResponseTime)ms")
    }
}

// MARK: - Example 6: Alert Management

/// Create and manage alerts
func alertManagementWorkflow() async throws {
    let adapter = ObservatoriumServiceAdapter()
    
    // Create alert rule
    let createAlertInput: [String: AnyCodable] = [
        "name": .string("High Assessment Failure Rate"),
        "condition": .string("failure_rate > 0.1"),
        "severity": .string("high"),
        "message": .string("More than 10% of assessments are failing")
    ]
    
    let createResult = try await adapter.execute(
        action: "createAlert",
        input: createAlertInput
    )
    
    if case .string(let ruleId) = createResult["ruleId"] {
        print("Created alert rule: \(ruleId)")
    }
    
    // Get active alerts
    let getAlertsInput: [String: AnyCodable] = [
        "severity": .string("critical")
    ]
    
    let alertsResult = try await adapter.execute(
        action: "getActiveAlerts",
        input: getAlertsInput
    )
    
    if case .int(let alertCount) = alertsResult["count"] {
        print("Active critical alerts: \(alertCount)")
    }
    
    if case .array(let alerts) = alertsResult["alerts"] {
        for alert in alerts {
            if case .dictionary(let alertData) = alert {
                if case .string(let alertName) = alertData["name"] {
                    print("Alert: \(alertName)")
                }
            }
        }
    }
}

// MARK: - Example 7: Multi-Adapter Workflow

/// Combined workflow using both Accessum and Observatorium adapters
func combinedWorkflow() async throws {
    let registry = ServiceRegistry()
    let factory = ServiceAdapterFactory(registry: registry)
    
    // Create both adapters
    let accessumAdapter = try await factory.createAccessumAdapter()
    let observatoriumAdapter = try await factory.createObservatoriumAdapter()
    
    // Step 1: Assess content
    print("Step 1: Assessing content...")
    let assessInput: [String: AnyCodable] = [
        "content": .string("<p>Test content</p>"),
        "wcagLevel": .string("AA")
    ]
    
    let assessResult = try await accessumAdapter.execute(
        action: "assessContent",
        input: assessInput
    )
    
    // Step 2: Record assessment in telemetry
    print("Step 2: Recording assessment metrics...")
    
    if case .double(let score) = assessResult["overallScore"] {
        let metricInput: [String: AnyCodable] = [
            "name": .string("accessibility_score"),
            "value": .double(score),
            "unit": .string("percentage"),
            "tags": .dictionary([
                "module": .string("accessum"),
                "workflow": .string("combined")
            ])
        ]
        
        _ = try await observatoriumAdapter.execute(
            action: "recordMetric",
            input: metricInput
        )
    }
    
    // Step 3: Record success event
    print("Step 3: Recording completion event...")
    let eventInput: [String: AnyCodable] = [
        "type": .string("performanceMetric"),
        "source": .string("combined-workflow"),
        "data": .dictionary([
            "workflow": .string("assessment_with_telemetry"),
            "status": .string("completed")
        ]),
        "severity": .string("info")
    ]
    
    _ = try await observatoriumAdapter.execute(
        action: "recordEvent",
        input: eventInput
    )
}

// MARK: - Example 8: Error Handling Patterns

/// Demonstrate error handling for adapters
func errorHandlingWorkflow() async {
    let adapter = AccessumServiceAdapter()
    
    // Missing required parameter
    let invalidInput: [String: AnyCodable] = [
        "wcagLevel": .string("AA")
        // Missing required "content" parameter
    ]
    
    do {
        _ = try await adapter.execute(
            action: "assessContent",
            input: invalidInput
        )
    } catch let error as AccessumAdapterError {
        switch error {
        case .missingRequiredParameter(let param):
            print("Error: Missing parameter '\(param)'")
        case .assessmentFailed(let reason):
            print("Assessment failed: \(reason)")
        default:
            print("Adapter error: \(error.localizedDescription)")
        }
    } catch {
        print("Unexpected error: \(error)")
    }
    
    // Unknown action
    do {
        _ = try await adapter.execute(
            action: "unknownAction",
            input: [:]
        )
    } catch let error as AccessumAdapterError {
        if case .unknownAction(let action) = error {
            print("Unknown action: \(action)")
        }
    } catch {
        print("Error: \(error)")
    }
}

// MARK: - Example 9: Health Monitoring

/// Monitor adapter health and status
func healthMonitoringWorkflow() async throws {
    let registry = ServiceRegistry()
    let factory = ServiceAdapterFactory(registry: registry)
    
    // Create adapters
    _ = try await factory.createAllStandardAdapters()
    
    // Check individual adapter health
    let accessumHealth = try await factory.checkAdapterHealth("accessum-service")
    print("Accessum health: \(accessumHealth)")
    
    // Check all adapters
    let allHealth = try await factory.checkAllAdaptersHealth()
    for (serviceId, status) in allHealth {
        print("Service \(serviceId): \(status)")
    }
    
    // Monitor for degradation
    let observatoriumHealth = try await factory.checkAdapterHealth("observatorium-service")
    if observatoriumHealth == .unhealthy {
        print("Warning: Observatorium service is unhealthy!")
        // Take corrective action (reinitialize, alert, etc.)
    }
}

// MARK: - Example 10: Workflow Definition

/// Define workflows using adapters
func defineWorkflows() -> [WorkflowDefinition] {
    // Workflow 1: Assessment only
    let assessmentWorkflow = WorkflowDefinition(
        id: "assessment-workflow",
        name: "Content Accessibility Assessment",
        description: "Assess HTML content for WCAG AA compliance",
        steps: [
            WorkflowStep(
                id: "assess",
                serviceId: "accessum-service",
                action: "assessContent",
                input: [
                    "content": .string("<html>...</html>"),
                    "wcagLevel": .string("AA")
                ],
                timeout: 30.0
            )
        ]
    )
    
    // Workflow 2: Assessment with monitoring
    let monitoredWorkflow = WorkflowDefinition(
        id: "monitored-assessment",
        name: "Assessment with Telemetry",
        description: "Assess content and record metrics",
        steps: [
            WorkflowStep(
                id: "assess",
                serviceId: "accessum-service",
                action: "assessContent",
                input: [
                    "content": .string("<html>...</html>"),
                    "wcagLevel": .string("AA")
                ]
            ),
            WorkflowStep(
                id: "record-event",
                serviceId: "observatorium-service",
                action: "recordEvent",
                input: [
                    "type": .string("performanceMetric"),
                    "source": .string("assessment-service"),
                    "severity": .string("info")
                ],
                dependencies: ["assess"]
            ),
            WorkflowStep(
                id: "record-metric",
                serviceId: "observatorium-service",
                action: "recordMetric",
                input: [
                    "name": .string("assessment_completed"),
                    "value": .double(1.0)
                ],
                dependencies: ["assess"]
            )
        ],
        parallelizable: false,
        retryPolicy: RetryPolicy(maxRetries: 2)
    )
    
    // Workflow 3: Client management workflow
    let clientWorkflow = WorkflowDefinition(
        id: "client-management",
        name: "Client Accessibility Setup",
        steps: [
            WorkflowStep(
                id: "create-client",
                serviceId: "accessum-service",
                action: "createClient",
                input: [
                    "requirements": .dictionary([
                        "wcagLevel": .string("AAA")
                    ])
                ]
            ),
            WorkflowStep(
                id: "assess-for-client",
                serviceId: "accessum-service",
                action: "assessContent",
                input: [
                    "content": .string("<html>...</html>"),
                    "wcagLevel": .string("AAA")
                ],
                dependencies: ["create-client"]
            )
        ]
    )
    
    return [assessmentWorkflow, monitoredWorkflow, clientWorkflow]
}

// MARK: - Example 11: Batch Processing

/// Process multiple assessments efficiently
func batchProcessingWorkflow() async throws {
    let adapter = AccessumServiceAdapter()
    let observatoriumAdapter = ObservatoriumServiceAdapter()
    
    let contentItems = [
        "<p>Page 1</p>",
        "<p>Page 2</p>",
        "<p>Page 3</p>"
    ]
    
    var assessmentResults: [String] = []
    
    // Assess each item
    for (index, content) in contentItems.enumerated() {
        let input: [String: AnyCodable] = [
            "content": .string(content),
            "wcagLevel": .string("AA")
        ]
        
        let result = try await adapter.execute(
            action: "assessContent",
            input: input
        )
        
        if case .string(let assessmentId) = result["assessmentId"] {
            assessmentResults.append(assessmentId)
            
            // Record batch processing metric
            let metricInput: [String: AnyCodable] = [
                "name": .string("batch_assessment_progress"),
                "value": .double(Double(index + 1) / Double(contentItems.count)),
                "unit": .string("percentage"),
                "tags": .dictionary([
                    "batch_size": .string(String(contentItems.count)),
                    "index": .string(String(index + 1))
                ])
            ]
            
            _ = try await observatoriumAdapter.execute(
                action: "recordMetric",
                input: metricInput
            )
        }
    }
    
    print("Completed batch processing of \(assessmentResults.count) items")
}

// MARK: - Example 12: Custom Configuration

/// Use custom coordinators with adapters
func customConfigurationWorkflow() async throws {
    // Create custom coordinator with specific configuration
    let customCoordinator = AccessumCoordinator()
    
    // Create adapter with custom coordinator
    let registry = ServiceRegistry()
    let factory = ServiceAdapterFactory(registry: registry)
    
    let customAdapter = try await factory.createAccessumAdapter(
        coordinator: customCoordinator,
        autoRegister: true
    )
    
    print("Created adapter with ID: \(customAdapter.serviceId)")
}
