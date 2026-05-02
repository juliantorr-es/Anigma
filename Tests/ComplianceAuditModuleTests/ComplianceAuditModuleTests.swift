//
//  ComplianceAuditModuleTests.swift
//  ComplianceAuditModuleTests
//
//  Comprehensive test suite for compliance audit functionality
//

import Foundation
import Testing

// MARK: - Audit Models Tests

/// Test suite for audit data models
struct AuditModelsTests {
    
    init() {
        print("🧪 Setting up AuditModelsTests")
    }
    
    // MARK: - AuditEvent Tests
    
    @Test func testAuditEventInitialization() {
        print("🔍 Testing AuditEvent initialization...")
        
        let event = AuditEvent(
            eventType: .aiOperation,
            userId: "user123",
            sessionId: "session456",
            principal: "test-user",
            operationType: "inference",
            resourceId: "model789",
            resourceType: "ai_model",
            action: "generate_response",
            result: "success"
        )
        
        #expect(event.eventType == .aiOperation)
        #expect(event.userId == "user123")
        #expect(event.sessionId == "session456")
        #expect(event.principal == "test-user")
        #expect(event.operationType == "inference")
        #expect(event.resourceId == "model789")
        #expect(event.resourceType == "ai_model")
        #expect(event.action == "generate_response")
        #expect(event.result == "success")
        #expect(event.details.isEmpty)
        #expect(event.metadata.isEmpty)
        #expect(event.complianceFlags.isEmpty)
    }
    
    @Test func testAuditEventWithComplianceFlags() {
        print("🔍 Testing AuditEvent with compliance flags...")
        
        let event = AuditEvent(
            eventType: .documentAccess,
            userId: "user123",
            principal: "test-user",
            action: "read_document",
            result: "success",
            complianceFlags: ["file_access", "data_modification"]
        )
        
        #expect(event.complianceFlags.count == 2)
        #expect(event.complianceFlags.contains("file_access"))
        #expect(event.complianceFlags.contains("data_modification"))
    }
    
    // MARK: - AIOperationAuditEvent Tests
    
    @Test func testAIOperationAuditEvent() {
        print("🔍 Testing AIOperationAuditEvent...")
        
        let baseEvent = AuditEvent(
            eventType: .aiOperation,
            userId: "user123",
            principal: "test-user",
            action: "inference",
            result: "success"
        )
        
        let aiEvent = AIOperationAuditEvent(
            baseEvent: baseEvent,
            aiOperationType: .inference,
            modelId: "gpt-4",
            modelVersion: "1.0.0",
            inputTokens: 100,
            outputTokens: 50,
            inferenceTimeMs: 2500,
            confidence: 0.95,
            cost: Decimal(string: "0.002")
        )
        
        #expect(aiEvent.aiOperationType == .inference)
        #expect(aiEvent.modelId == "gpt-4")
        #expect(aiEvent.modelVersion == "1.0.0")
        #expect(aiEvent.inputTokens == 100)
        #expect(aiEvent.outputTokens == 50)
        #expect(aiEvent.inferenceTimeMs == 2500)
        #expect(aiEvent.confidence == 0.95)
        #expect(aiEvent.cost == Decimal(string: "0.002"))
        #expect(aiEvent.safetyFilters.isEmpty)
        #expect(aiEvent.contentPolicyViolations.isEmpty)
    }
    
    // MARK: - DocumentAccessAuditEvent Tests
    
    @Test func testDocumentAccessAuditEvent() {
        print("🔍 Testing DocumentAccessAuditEvent...")
        
        let baseEvent = AuditEvent(
            eventType: .documentAccess,
            userId: "user123",
            principal: "test-user",
            action: "read_file",
            result: "success"
        )
        
        let docEvent = DocumentAccessAuditEvent(
            baseEvent: baseEvent,
            accessType: .read,
            documentPath: "/documents/important.pdf",
            documentHash: "sha256:abc123",
            fileSize: 1024000,
            mimeType: "application/pdf",
            accessReason: "compliance_review"
        )
        
        #expect(docEvent.accessType == .read)
        #expect(docEvent.documentPath == "/documents/important.pdf")
        #expect(docEvent.documentHash == "sha256:abc123")
        #expect(docEvent.fileSize == 1024000)
        #expect(docEvent.mimeType == "application/pdf")
        #expect(docEvent.accessReason == "compliance_review")
    }
    
    // MARK: - GovernanceDecisionAuditEvent Tests
    
    @Test func testGovernanceDecisionAuditEvent() {
        print("🔍 Testing GovernanceDecisionAuditEvent...")
        
        let baseEvent = AuditEvent(
            eventType: .governanceDecision,
            userId: "system",
            principal: "governance_engine",
            action: "evaluate_request",
            result: "blocked"
        )
        
        let govEvent = GovernanceDecisionAuditEvent(
            baseEvent: baseEvent,
            decisionType: .blocked,
            policyId: "data_protection_policy",
            policyVersion: "2.1.0",
            ruleIds: ["rule1", "rule2"],
            riskScore: 0.85,
            blockingFactors: ["sensitive_data"],
            approvalChain: ["auto_review"],
            justification: "Request contains PII and requires additional approval"
        )
        
        #expect(govEvent.decisionType == .blocked)
        #expect(govEvent.policyId == "data_protection_policy")
        #expect(govEvent.policyVersion == "2.1.0")
        #expect(govEvent.ruleIds == ["rule1", "rule2"])
        #expect(govEvent.riskScore == 0.85)
        #expect(govEvent.blockingFactors == ["sensitive_data"])
        #expect(govEvent.approvalChain == ["auto_review"])
        #expect(govEvent.justification == "Request contains PII and requires additional approval")
    }
    
    // MARK: - AuditReportFilters Tests
    
    @Test func testAuditReportFilters() {
        print("🔍 Testing AuditReportFilters...")
        
        let dateRange = Date()...Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        let filters = AuditReportFilters(
            dateRange: dateRange,
            userIds: ["user1", "user2"],
            eventTypes: [.aiOperation, .documentAccess],
            includeMetadata: true,
            maxResults: 1000,
            sortBy: .timestamp,
            sortOrder: .descending
        )
        
        #expect(filters.dateRange != nil)
        #expect(filters.userIds?.count == 2)
        #expect(filters.eventTypes?.count == 2)
        #expect(filters.includeMetadata)
        #expect(filters.maxResults == 1000)
        #expect(filters.sortBy == .timestamp)
        #expect(filters.sortOrder == .descending)
    }
    
    @Test func testAuditReportFiltersDefaultValues() {
        print("🔍 Testing AuditReportFilters default values...")
        
        let filters = AuditReportFilters()
        
        #expect(filters.dateRange == nil)
        #expect(filters.userIds == nil)
        #expect(filters.eventTypes == nil)
        #expect(!filters.includeMetadata)
        #expect(filters.maxResults == nil)
        #expect(filters.sortBy == .timestamp)
        #expect(filters.sortOrder == .descending)
    }
    
    // MARK: - AuditReportSummary Tests
    
    @Test func testAuditReportSummary() {
        print("🔍 Testing AuditReportSummary...")
        
        let dateRange = Date()...Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let summary = AuditReportSummary(
            totalEvents: 1000,
            dateRange: dateRange,
            uniqueUsers: 50,
            uniqueSessions: 75,
            eventCounts: [.aiOperation: 500, .documentAccess: 300, .governanceDecision: 200],
            operationCounts: ["inference": 400, "read": 350, "evaluate": 250],
            userActivity: ["user1": 100, "user2": 80, "user3": 60],
            complianceFlagCounts: ["ml_operations": 500, "file_access": 300, "policy_enforcement": 200],
            failureRate: 0.05,
            averageResponseTime: 150.5,
            totalCost: Decimal(string: "25.50")
        )
        
        #expect(summary.totalEvents == 1000)
        #expect(summary.uniqueUsers == 50)
        #expect(summary.uniqueSessions == 75)
        #expect(summary.eventCounts[.aiOperation] == 500)
        #expect(summary.operationCounts["inference"] == 400)
        #expect(summary.userActivity["user1"] == 100)
        #expect(summary.complianceFlagCounts["ml_operations"] == 500)
        #expect(summary.failureRate == 0.05)
        #expect(summary.averageResponseTime == 150.5)
        #expect(summary.totalCost == Decimal(string: "25.50"))
    }
}

// MARK: - Export Functionality Tests

/// Test suite for export functionality
struct ExportFunctionalityTests {
    
    init() {
        print("🧪 Setting up ExportFunctionalityTests")
    }
    
    @Test func testCSVConfiguration() {
        print("🔍 Testing CSV configuration...")
        
        let config = CSVConfiguration.default
        
        #expect(config.includeBOM)
        #expect(config.includeFooter)
        #expect(config.includeDetailedBreakdowns)
        #expect(config.delimiter == ",")
        #expect(config.encoding == .utf8)
    }
    
    @Test func testPDFConfiguration() {
        print("🔍 Testing PDF configuration...")
        
        let config = PDFConfiguration.default
        
        #expect(config.pageSize.width == 612)
        #expect(config.pageSize.height == 792)
        #expect(config.includeLogo)
        #expect(config.includeConfidentialityNotice)
        #expect(!config.confidentialityNotice.isEmpty)
    }
    
    @Test func testCSVFieldEscaping() {
        print("🔍 Testing CSV field escaping...")
        
        // Test escaping of fields with commas
        let fieldWithComma = "Field with, comma"
        let escaped = escapeCSVField(fieldWithComma)
        #expect(escaped == "\"Field with, comma\"")
        
        // Test escaping of fields with quotes
        let fieldWithQuote = "Field with \"quotes\""
        let escapedQuotes = escapeCSVField(fieldWithQuote)
        #expect(escapedQuotes == "\"Field with \"\"quotes\"\"\"")
        
        // Test escaping of fields with newlines
        let fieldWithNewline = "Field with\nnewline"
        let escapedNewline = escapeCSVField(fieldWithNewline)
        #expect(escapedNewline == "\"Field with\nnewline\"")
    }
}

// MARK: - Mock Database for Testing

/// Mock database implementation for testing
public class MockDatabaseActor {
    public var executedSQLStatements: [String] = []
    public var mockFetchResults: [[String: DatabaseValue]] = []
    
    public init() {}
    
    public func execute(_ sql: String, parameters: [DatabaseValue] = []) async throws {
        executedSQLStatements.append(sql)
        print("🗄️ Executed SQL: \(sql)")
    }
    
    public func fetchAll(_ sql: String, parameters: [DatabaseValue] = []) async throws -> [[String: DatabaseValue]] {
        executedSQLStatements.append(sql)
        print("🗄️ Fetched all with SQL: \(sql)")
        return mockFetchResults
    }
    
    public func fetchOne(_ sql: String, parameters: [DatabaseValue] = []) async throws -> [String: DatabaseValue]? {
        executedSQLStatements.append(sql)
        print("🗄️ Fetched one with SQL: \(sql)")
        return mockFetchResults.first
    }
}

// MARK: - Helper Functions

private func escapeCSVField(_ field: String) -> String {
    if field.isEmpty {
        return ""
    }
    
    // If field contains comma, newline, or quote, wrap in quotes and escape internal quotes
    if field.contains(",") || field.contains("\n") || field.contains("\"") {
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
    
    return field
}

// MARK: - DatabaseValue Mock

/// Mock database value for testing
public enum DatabaseValue {
    case text(String?)
    case integer(Int?)
    case real(Double?)
    case datetime(Date?)
    case blob(Data?)
}

// MARK: - Mock Extensions for Missing Types

extension DatabaseActor {
    public init() {
        // Mock initialization for testing
    }
}

extension AuditLoggingService {
    public init(database: MockDatabaseActor, configuration: AuditConfiguration) {
        // Mock initialization for testing
    }
    
    public func logEvent(_ event: AuditEvent) async throws {
        // Mock implementation
    }
    
    public func queryEvents(filters: AuditReportFilters) async throws -> [AuditEvent] {
        return []
    }
    
    public func getStatistics(filters: AuditReportFilters?) async throws -> AuditReportSummary {
        return AuditReportSummary(
            totalEvents: 0,
            dateRange: Date()...Date(),
            uniqueUsers: 0,
            uniqueSessions: 0,
            eventCounts: [:],
            operationCounts: [:],
            userActivity: [:],
            complianceFlagCounts: [:],
            failureRate: 0.0
        )
    }
}
