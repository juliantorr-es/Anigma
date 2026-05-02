import Foundation
import ContractsCore
import AnigmaPrimitives

// MARK: - Audit Event Types

/// Categories of audit events for compliance tracking
public enum AuditEventType: String, Codable, CaseIterable, Sendable {
    case aiOperation = "ai_operation"
    case documentAccess = "document_access"
    case governanceDecision = "governance_decision"
    case systemEvent = "system_event"
    case userAction = "user_action"
    case securityEvent = "security_event"
    case automationTriggered = "automation_triggered"
    case automationExecuted = "automation_executed"
}

/// Specific AI operation types
public enum AIOperationType: String, Codable, CaseIterable, Sendable {
    case inference = "inference"
    case embedding = "embedding"
    case generation = "generation"
    case analysis = "analysis"
    case classification = "classification"
    case translation = "translation"
    case summarization = "summarization"
}

/// Document access types
public enum DocumentAccessType: String, Codable, CaseIterable, Sendable {
    case read = "read"
    case write = "write"
    case create = "create"
    case delete = "delete"
    case download = "download"
    case upload = "upload"
    case share = "share"
}

/// Governance decision types
public enum GovernanceDecisionType: String, Codable, CaseIterable, Sendable {
    case allowed = "allowed"
    case blocked = "blocked"
    case flagged = "flagged"
    case escalated = "escalated"
    case approved = "approved"
    case rejected = "rejected"
}

// MARK: - Core Audit Event

/// Comprehensive audit event record for compliance tracking
public struct AuditEvent: Sendable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let eventType: AuditEventType
    public let userId: String?
    public let sessionId: String?
    public let principal: String
    public let operationType: String?
    public let resourceId: String?
    public let resourceType: String?
    public let action: String
    public let result: String?
    public let details: [String: String]
    public let metadata: [String: String]
    public let ipAddress: String?
    public let userAgent: String?
    public let complianceFlags: [String]
    public let retentionPeriod: Int? // Days
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        eventType: AuditEventType,
        userId: String? = nil,
        sessionId: String? = nil,
        principal: String,
        operationType: String? = nil,
        resourceId: String? = nil,
        resourceType: String? = nil,
        action: String,
        result: String? = nil,
        details: [String: String] = [:],
        metadata: [String: String] = [:],
        ipAddress: String? = nil,
        userAgent: String? = nil,
        complianceFlags: [String] = [],
        retentionPeriod: Int? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.userId = userId
        self.sessionId = sessionId
        self.principal = principal
        self.operationType = operationType
        self.resourceId = resourceId
        self.resourceType = resourceType
        self.action = action
        self.result = result
        self.details = details
        self.metadata = metadata
        self.ipAddress = ipAddress
        self.userAgent = userAgent
        self.complianceFlags = complianceFlags
        self.retentionPeriod = retentionPeriod
    }
}

// MARK: - Specialized Audit Events

/// AI operation audit event with ML-specific metadata
public struct AIOperationAuditEvent: Sendable, Codable {
    public let baseEvent: AuditEvent
    public let aiOperationType: AIOperationType
    public let modelId: String
    public let modelVersion: String?
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let inferenceTimeMs: Int?
    public let confidence: Double?
    public let cost: Decimal?
    public let promptHash: String?
    public let responseHash: String?
    public let safetyFilters: [String]
    public let contentPolicyViolations: [String]
    
    public init(
        baseEvent: AuditEvent,
        aiOperationType: AIOperationType,
        modelId: String,
        modelVersion: String? = nil,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        inferenceTimeMs: Int? = nil,
        confidence: Double? = nil,
        cost: Decimal? = nil,
        promptHash: String? = nil,
        responseHash: String? = nil,
        safetyFilters: [String] = [],
        contentPolicyViolations: [String] = []
    ) {
        self.baseEvent = baseEvent
        self.aiOperationType = aiOperationType
        self.modelId = modelId
        self.modelVersion = modelVersion
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.inferenceTimeMs = inferenceTimeMs
        self.confidence = confidence
        self.cost = cost
        self.promptHash = promptHash
        self.responseHash = responseHash
        self.safetyFilters = safetyFilters
        self.contentPolicyViolations = contentPolicyViolations
    }
}

/// Document access audit event with file-specific metadata
public struct DocumentAccessAuditEvent: Sendable, Codable {
    public let baseEvent: AuditEvent
    public let accessType: DocumentAccessType
    public let documentPath: String
    public let documentHash: String?
    public let fileSize: Int64?
    public let mimeType: String?
    public let permissions: String?
    public let previousVersion: String?
    public let newVersion: String?
    public let accessReason: String?
    public let dataClassification: String?
    
    public init(
        baseEvent: AuditEvent,
        accessType: DocumentAccessType,
        documentPath: String,
        documentHash: String? = nil,
        fileSize: Int64? = nil,
        mimeType: String? = nil,
        permissions: String? = nil,
        previousVersion: String? = nil,
        newVersion: String? = nil,
        accessReason: String? = nil,
        dataClassification: String? = nil
    ) {
        self.baseEvent = baseEvent
        self.accessType = accessType
        self.documentPath = documentPath
        self.documentHash = documentHash
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.permissions = permissions
        self.previousVersion = previousVersion
        self.newVersion = newVersion
        self.accessReason = accessReason
        self.dataClassification = dataClassification
    }
}

/// Governance decision audit event with policy-specific metadata
public struct GovernanceDecisionAuditEvent: Sendable, Codable {
    public let baseEvent: AuditEvent
    public let decisionType: GovernanceDecisionType
    public let policyId: String?
    public let policyVersion: String?
    public let ruleIds: [String]
    public let riskScore: Double?
    public let blockingFactors: [String]
    public let approvalChain: [String]
    public let justification: String?
    public let appealsProcess: String?
    public let automatedReview: Bool?
    
    public init(
        baseEvent: AuditEvent,
        decisionType: GovernanceDecisionType,
        policyId: String? = nil,
        policyVersion: String? = nil,
        ruleIds: [String] = [],
        riskScore: Double? = nil,
        blockingFactors: [String] = [],
        approvalChain: [String] = [],
        justification: String? = nil,
        appealsProcess: String? = nil,
        automatedReview: Bool? = nil
    ) {
        self.baseEvent = baseEvent
        self.decisionType = decisionType
        self.policyId = policyId
        self.policyVersion = policyVersion
        self.ruleIds = ruleIds
        self.riskScore = riskScore
        self.blockingFactors = blockingFactors
        self.approvalChain = approvalChain
        self.justification = justification
        self.appealsProcess = appealsProcess
        self.automatedReview = automatedReview
    }
}

// MARK: - Report Filters

/// Filters for generating audit reports
public struct AuditReportFilters: Sendable, Codable {
    public let dateRange: ClosedRange<Date>?
    public let userIds: [String]?
    public let sessionIds: [String]?
    public let eventTypes: [AuditEventType]?
    public let operationTypes: [String]?
    public let resourceTypes: [String]?
    public let principals: [String]?
    public let complianceFlags: [String]?
    public let includeMetadata: Bool
    public let maxResults: Int?
    public let sortBy: AuditSortField
    public let sortOrder: SortOrder
    
    public init(
        dateRange: ClosedRange<Date>? = nil,
        userIds: [String]? = nil,
        sessionIds: [String]? = nil,
        eventTypes: [AuditEventType]? = nil,
        operationTypes: [String]? = nil,
        resourceTypes: [String]? = nil,
        principals: [String]? = nil,
        complianceFlags: [String]? = nil,
        includeMetadata: Bool = false,
        maxResults: Int? = nil,
        sortBy: AuditSortField = .timestamp,
        sortOrder: SortOrder = .descending
    ) {
        self.dateRange = dateRange
        self.userIds = userIds
        self.sessionIds = sessionIds
        self.eventTypes = eventTypes
        self.operationTypes = operationTypes
        self.resourceTypes = resourceTypes
        self.principals = principals
        self.complianceFlags = complianceFlags
        self.includeMetadata = includeMetadata
        self.maxResults = maxResults
        self.sortBy = sortBy
        self.sortOrder = sortOrder
    }
}

/// Sortable fields for audit reports
public enum AuditSortField: String, Codable, CaseIterable, Sendable {
    case timestamp = "timestamp"
    case eventType = "event_type"
    case userId = "user_id"
    case principal = "principal"
    case action = "action"
    case result = "result"
}

/// Sort order
public enum SortOrder: String, Codable, CaseIterable, Sendable {
    case ascending = "asc"
    case descending = "desc"
}

// MARK: - Report Generation

/// Generated audit report with statistics
public struct AuditReport: Sendable, Codable {
    public let id: UUID
    public let generatedAt: Date
    public let generatedBy: String
    public let filters: AuditReportFilters
    public let summary: AuditReportSummary
    public let events: [AuditEvent]
    public let exportFormats: [ExportFormat]
    
    public init(
        id: UUID = UUID(),
        generatedAt: Date = Date(),
        generatedBy: String,
        filters: AuditReportFilters,
        summary: AuditReportSummary,
        events: [AuditEvent],
        exportFormats: [ExportFormat] = []
    ) {
        self.id = id
        self.generatedAt = generatedAt
        self.generatedBy = generatedBy
        self.filters = filters
        self.summary = summary
        self.events = events
        self.exportFormats = exportFormats
    }
}

/// Summary statistics for audit reports
public struct AuditReportSummary: Sendable, Codable {
    public let totalEvents: Int
    public let dateRange: ClosedRange<Date>
    public let uniqueUsers: Int
    public let uniqueSessions: Int
    public let eventCounts: [AuditEventType: Int]
    public let operationCounts: [String: Int]
    public let userActivity: [String: Int] // userId -> event count
    public let complianceFlagCounts: [String: Int]
    public let failureRate: Double
    public let averageResponseTime: Double? // ms
    public let totalCost: Decimal?
    
    public init(
        totalEvents: Int,
        dateRange: ClosedRange<Date>,
        uniqueUsers: Int,
        uniqueSessions: Int,
        eventCounts: [AuditEventType: Int],
        operationCounts: [String: Int],
        userActivity: [String: Int],
        complianceFlagCounts: [String: Int],
        failureRate: Double,
        averageResponseTime: Double? = nil,
        totalCost: Decimal? = nil
    ) {
        self.totalEvents = totalEvents
        self.dateRange = dateRange
        self.uniqueUsers = uniqueUsers
        self.uniqueSessions = uniqueSessions
        self.eventCounts = eventCounts
        self.operationCounts = operationCounts
        self.userActivity = userActivity
        self.complianceFlagCounts = complianceFlagCounts
        self.failureRate = failureRate
        self.averageResponseTime = averageResponseTime
        self.totalCost = totalCost
    }
}

/// Export formats for audit reports
public enum ExportFormat: String, Codable, CaseIterable, Sendable {
    case pdf = "pdf"
    case csv = "csv"
    case json = "json"
    case xml = "xml"
}