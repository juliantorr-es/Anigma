import Foundation
import ContractsCore
import AnigmaPrimitives
import DatabaseCore

// MARK: - Audit Logging Service

/// Service responsible for capturing and storing audit events for compliance
public actor AuditLoggingService {
    
    // MARK: - Properties
    
    private let database: any DatabaseExecutor
    private let configuration: AuditConfiguration
    private let eventBuffer: [AuditEvent]
    private let bufferSize = 100
    private let flushInterval: TimeInterval = 60 // seconds
    
    // MARK: - Initialization
    
    public init(database: any DatabaseExecutor, configuration: AuditConfiguration = AuditConfiguration.default) {
        self.database = database
        self.configuration = configuration
        self.eventBuffer = []
    }
    
    // MARK: - Public Interface
    
    /// Log a general audit event
    public func logEvent(_ event: AuditEvent) async throws {
        guard configuration.enabled else { return }
        
        let enrichedEvent = enrichEvent(event)
        
        // Buffer events for batch processing
        var buffer = eventBuffer
        buffer.append(enrichedEvent)
        
        if buffer.count >= bufferSize {
            try await flushEvents(buffer)
            buffer.removeAll()
        }
    }
    
    /// Log an AI operation event
    public func logAIOperation(_ event: AIOperationAuditEvent) async throws {
        guard configuration.enabled else { return }
        
        // Convert to base audit event and log
        try await logEvent(event.baseEvent)
        
        // Store AI-specific metadata in dedicated table
        try await storeAIOperationMetadata(event)
    }
    
    /// Log a document access event
    public func logDocumentAccess(_ event: DocumentAccessAuditEvent) async throws {
        guard configuration.enabled else { return }
        
        // Convert to base audit event and log
        try await logEvent(event.baseEvent)
        
        // Store document-specific metadata in dedicated table
        try await storeDocumentAccessMetadata(event)
    }
    
    /// Log a governance decision event
    public func logGovernanceDecision(_ event: GovernanceDecisionAuditEvent) async throws {
        guard configuration.enabled else { return }
        
        // Convert to base audit event and log
        try await logEvent(event.baseEvent)
        
        // Store governance-specific metadata in dedicated table
        try await storeGovernanceDecisionMetadata(event)
    }
    
    /// Query audit events with filters
    public func queryEvents(filters: AuditReportFilters) async throws -> [AuditEvent] {
        let rows = try await database.query("""
        SELECT * FROM audit_events
        ORDER BY timestamp DESC
        """)
        let events = rows.map { decodeAuditEvent($0) }
        return applyFilters(filters, to: events)
    }
    
    /// Get audit event statistics
    public func getStatistics(filters: AuditReportFilters?) async throws -> AuditReportSummary {
        let activeFilters = filters ?? AuditReportFilters()
        let events = try await queryEvents(filters: activeFilters)
        return buildStatistics(from: events, filters: activeFilters)
    }
    
    /// Flush buffered events to database
    public func flushEvents() async throws {
        guard !eventBuffer.isEmpty else { return }
        try await flushEvents(eventBuffer)
    }
    
    // MARK: - Private Methods
    
    private func enrichEvent(_ event: AuditEvent) -> AuditEvent {
        var enrichedEvent = event
        
        // Add default compliance flags based on event type
        var flags = event.complianceFlags
        
        switch event.eventType {
        case .aiOperation:
            flags.append("ml_operations")
            flags.append("data_processing")
        case .documentAccess:
            flags.append("file_access")
            if event.action.contains("delete") || event.action.contains("modify") {
                flags.append("data_modification")
            }
        case .governanceDecision:
            flags.append("policy_enforcement")
        case .securityEvent:
            flags.append("security_monitoring")
        case .systemEvent:
            flags.append("system_operations")
        case .userAction:
            flags.append("user_activity")
        case .automationTriggered, .automationExecuted:
            flags.append("automation_monitoring")
        }
        
        // Add retention period based on compliance flags
        let retentionPeriod = calculateRetentionPeriod(for: flags)
        
        enrichedEvent = AuditEvent(
            id: event.id,
            timestamp: event.timestamp,
            eventType: event.eventType,
            userId: event.userId,
            sessionId: event.sessionId,
            principal: event.principal,
            operationType: event.operationType,
            resourceId: event.resourceId,
            resourceType: event.resourceType,
            action: event.action,
            result: event.result,
            details: event.details,
            metadata: event.metadata,
            ipAddress: event.ipAddress,
            userAgent: event.userAgent,
            complianceFlags: flags,
            retentionPeriod: retentionPeriod
        )
        
        return enrichedEvent
    }
    
    private func calculateRetentionPeriod(for flags: [String]) -> Int {
        // Base retention period in days
        var retentionDays = configuration.defaultRetentionDays
        
        // Extend retention for critical compliance flags
        if flags.contains("security_monitoring") {
            retentionDays = max(retentionDays, 2555) // 7 years
        }
        if flags.contains("policy_enforcement") {
            retentionDays = max(retentionDays, 1825) // 5 years
        }
        if flags.contains("data_modification") {
            retentionDays = max(retentionDays, 1095) // 3 years
        }
        
        return retentionDays
    }
    
    private func flushEvents(_ events: [AuditEvent]) async throws {
        for event in events {
            try await storeAuditEvent(event)
        }
    }
    
    private func storeAuditEvent(_ event: AuditEvent) async throws {
        let sql = """
        INSERT INTO audit_events (
            id, timestamp, event_type, user_id, session_id, principal,
            operation_type, resource_id, resource_type, action, result,
            details, metadata, ip_address, user_agent, compliance_flags,
            retention_period
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        let parameters: [DatabaseParameter] = [
            .text(event.id.uuidString),
            .text(ISO8601DateFormatter().string(from: event.timestamp)),
            .text(event.eventType.rawValue),
            .text(event.userId ?? ""),
            .text(event.sessionId ?? ""),
            .text(event.principal),
            .text(event.operationType ?? ""),
            .text(event.resourceId ?? ""),
            .text(event.resourceType ?? ""),
            .text(event.action),
            .text(event.result ?? ""),
            .text(try JSONEncoder().encode(event.details).base64EncodedString()),
            .text(try JSONEncoder().encode(event.metadata).base64EncodedString()),
            .text(event.ipAddress ?? ""),
            .text(event.userAgent ?? ""),
            .text(try JSONEncoder().encode(event.complianceFlags).base64EncodedString()),
            .int(event.retentionPeriod ?? 0)
        ]
        
        try await database.execute(sql, parameters: parameters)
    }
    
    private func storeAIOperationMetadata(_ event: AIOperationAuditEvent) async throws {
        let sql = """
        INSERT INTO ai_operation_metadata (
            audit_event_id, ai_operation_type, model_id, model_version,
            input_tokens, output_tokens, inference_time_ms, confidence,
            cost, prompt_hash, response_hash, safety_filters,
            content_policy_violations
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        let parameters: [DatabaseParameter] = [
            .text(event.baseEvent.id.uuidString),
            .text(event.aiOperationType.rawValue),
            .text(event.modelId),
            .text(event.modelVersion ?? ""),
            .int(event.inputTokens ?? 0),
            .int(event.outputTokens ?? 0),
            .int(event.inferenceTimeMs ?? 0),
            .double(event.confidence ?? 0),
            .text(event.cost?.description ?? ""),
            .text(event.promptHash ?? ""),
            .text(event.responseHash ?? ""),
            .text(try JSONEncoder().encode(event.safetyFilters).base64EncodedString()),
            .text(try JSONEncoder().encode(event.contentPolicyViolations).base64EncodedString())
        ]
        
        try await database.execute(sql, parameters: parameters)
    }
    
    private func storeDocumentAccessMetadata(_ event: DocumentAccessAuditEvent) async throws {
        let sql = """
        INSERT INTO document_access_metadata (
            audit_event_id, access_type, document_path, document_hash,
            file_size, mime_type, permissions, previous_version,
            new_version, access_reason, data_classification
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        let parameters: [DatabaseParameter] = [
            .text(event.baseEvent.id.uuidString),
            .text(event.accessType.rawValue),
            .text(event.documentPath),
            .text(event.documentHash ?? ""),
            .int(event.fileSize.map(Int.init) ?? 0),
            .text(event.mimeType ?? ""),
            .text(event.permissions ?? ""),
            .text(event.previousVersion ?? ""),
            .text(event.newVersion ?? ""),
            .text(event.accessReason ?? ""),
            .text(event.dataClassification ?? "")
        ]
        
        try await database.execute(sql, parameters: parameters)
    }
    
    private func storeGovernanceDecisionMetadata(_ event: GovernanceDecisionAuditEvent) async throws {
        let sql = """
        INSERT INTO governance_decision_metadata (
            audit_event_id, decision_type, policy_id, policy_version,
            rule_ids, risk_score, blocking_factors, approval_chain,
            justification, appeals_process, automated_review
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        let parameters: [DatabaseParameter] = [
            .text(event.baseEvent.id.uuidString),
            .text(event.decisionType.rawValue),
            .text(event.policyId ?? ""),
            .text(event.policyVersion ?? ""),
            .text(try JSONEncoder().encode(event.ruleIds).base64EncodedString()),
            .double(event.riskScore ?? 0),
            .text(try JSONEncoder().encode(event.blockingFactors).base64EncodedString()),
            .text(try JSONEncoder().encode(event.approvalChain).base64EncodedString()),
            .text(event.justification ?? ""),
            .text(event.appealsProcess ?? ""),
            .int(event.automatedReview.map { $0 ? 1 : 0 } ?? 0)
        ]
        
        try await database.execute(sql, parameters: parameters)
    }
    
    private func buildQuery(_ filters: AuditReportFilters) -> String {
        var conditions: [String] = []
        var parameters: [String] = []
        
        if let dateRange = filters.dateRange {
            conditions.append("timestamp BETWEEN ? AND ?")
            parameters.append(ISO8601DateFormatter().string(from: dateRange.lowerBound))
            parameters.append(ISO8601DateFormatter().string(from: dateRange.upperBound))
        }
        
        if let userIds = filters.userIds, !userIds.isEmpty {
            let placeholders = userIds.map { _ in "?" }.joined(separator: ", ")
            conditions.append("user_id IN (\(placeholders))")
            parameters.append(contentsOf: userIds)
        }
        
        if let sessionIds = filters.sessionIds, !sessionIds.isEmpty {
            let placeholders = sessionIds.map { _ in "?" }.joined(separator: ", ")
            conditions.append("session_id IN (\(placeholders))")
            parameters.append(contentsOf: sessionIds)
        }
        
        if let eventTypes = filters.eventTypes, !eventTypes.isEmpty {
            let placeholders = eventTypes.map { _ in "?" }.joined(separator: ", ")
            conditions.append("event_type IN (\(placeholders))")
            parameters.append(contentsOf: eventTypes.map { $0.rawValue })
        }
        
        let whereClause = conditions.isEmpty ? "" : "WHERE \(conditions.joined(separator: " AND "))"
        let orderClause = "ORDER BY \(filters.sortBy.rawValue) \(filters.sortOrder.rawValue)"
        let limitClause = filters.maxResults.map { "LIMIT \($0)" } ?? ""
        
        return """
        SELECT * FROM audit_events 
        \(whereClause)
        \(orderClause)
        \(limitClause)
        """
    }
    
    private func buildStatisticsQuery(_ filters: AuditReportFilters) -> String {
        return """
        SELECT 
            COUNT(*) as total_events,
            MIN(timestamp) as min_timestamp,
            MAX(timestamp) as max_timestamp,
            COUNT(DISTINCT user_id) as unique_users,
            COUNT(DISTINCT session_id) as unique_sessions,
            event_type,
            operation_type,
            user_id,
            compliance_flags
        FROM audit_events 
        WHERE timestamp BETWEEN COALESCE(?, timestamp) AND COALESCE(?, timestamp)
        GROUP BY event_type, operation_type, user_id
        """
    }
    
    private func decodeAuditEvent(_ row: DatabaseRow) -> AuditEvent {
        let details = decodeStringDictionary(from: row.string(for: "details"))
        let metadata = decodeStringDictionary(from: row.string(for: "metadata"))
        let flags = decodeStringArray(from: row.string(for: "compliance_flags"))
        let timestamp = decodeTimestamp(row.string(for: "timestamp"))

        return AuditEvent(
            id: UUID(uuidString: row.string(for: "id") ?? "") ?? UUID(),
            timestamp: timestamp,
            eventType: AuditEventType(rawValue: row.string(for: "event_type") ?? "") ?? .systemEvent,
            userId: row.string(for: "user_id"),
            sessionId: row.string(for: "session_id"),
            principal: row.string(for: "principal") ?? "unknown",
            operationType: row.string(for: "operation_type"),
            resourceId: row.string(for: "resource_id"),
            resourceType: row.string(for: "resource_type"),
            action: row.string(for: "action") ?? "unknown",
            result: row.string(for: "result"),
            details: details,
            metadata: metadata,
            ipAddress: row.string(for: "ip_address"),
            userAgent: row.string(for: "user_agent"),
            complianceFlags: flags,
            retentionPeriod: row.int(for: "retention_period")
        )
    }
    
    private func buildStatistics(from events: [AuditEvent], filters: AuditReportFilters) -> AuditReportSummary {
        let totalEvents = events.count
        let timestamps = events.map(\.timestamp).sorted()
        let defaultRange = Date()...Date()
        let dateRange: ClosedRange<Date>
        if let lower = timestamps.first, let upper = timestamps.last {
            dateRange = lower...upper
        } else if let filterRange = filters.dateRange {
            dateRange = filterRange
        } else {
            dateRange = defaultRange
        }

        let uniqueUsers = Set(events.compactMap(\.userId)).count
        let uniqueSessions = Set(events.compactMap(\.sessionId)).count

        var eventCounts: [AuditEventType: Int] = [:]
        var operationCounts: [String: Int] = [:]
        var userActivity: [String: Int] = [:]
        var complianceFlagCounts: [String: Int] = [:]

        for event in events {
            eventCounts[event.eventType, default: 0] += 1
            if let operationType = event.operationType {
                operationCounts[operationType, default: 0] += 1
            }
            userActivity[event.principal, default: 0] += 1
            for flag in event.complianceFlags {
                complianceFlagCounts[flag, default: 0] += 1
            }
        }

        return AuditReportSummary(
            totalEvents: totalEvents,
            dateRange: dateRange,
            uniqueUsers: uniqueUsers,
            uniqueSessions: uniqueSessions,
            eventCounts: eventCounts,
            operationCounts: operationCounts,
            userActivity: userActivity,
            complianceFlagCounts: complianceFlagCounts,
            failureRate: 0,
            averageResponseTime: nil,
            totalCost: nil
        )
    }

    private func applyFilters(_ filters: AuditReportFilters, to events: [AuditEvent]) -> [AuditEvent] {
        events.filter { event in
            if let dateRange = filters.dateRange, !dateRange.contains(event.timestamp) {
                return false
            }
            if let userIds = filters.userIds, !userIds.isEmpty {
                guard let userId = event.userId, userIds.contains(userId) else {
                    return false
                }
            }
            if let sessionIds = filters.sessionIds, !sessionIds.isEmpty {
                guard let sessionId = event.sessionId, sessionIds.contains(sessionId) else {
                    return false
                }
            }
            if let eventTypes = filters.eventTypes, !eventTypes.isEmpty, !eventTypes.contains(event.eventType) {
                return false
            }
            if let operationTypes = filters.operationTypes, !operationTypes.isEmpty {
                guard let operationType = event.operationType, operationTypes.contains(operationType) else {
                    return false
                }
            }
            if let resourceTypes = filters.resourceTypes, !resourceTypes.isEmpty {
                guard let resourceType = event.resourceType, resourceTypes.contains(resourceType) else {
                    return false
                }
            }
            if let principals = filters.principals, !principals.isEmpty, !principals.contains(event.principal) {
                return false
            }
            if let complianceFlags = filters.complianceFlags, !complianceFlags.isEmpty, !Set(complianceFlags).isSubset(of: Set(event.complianceFlags)) {
                return false
            }
            return true
        }
    }

    private func decodeStringArray(from encoded: String?) -> [String] {
        guard
            let encoded,
            let data = Data(base64Encoded: encoded),
            let decoded = try? JSONDecoder().decode([String].self, from: data)
        else {
            return []
        }
        return decoded
    }

    private func decodeStringDictionary(from encoded: String?) -> [String: String] {
        guard
            let encoded,
            let data = Data(base64Encoded: encoded),
            let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return [:]
        }
        return decoded
    }

    private func decodeTimestamp(_ rawValue: String?) -> Date {
        guard let rawValue else { return Date() }
        if let timeInterval = TimeInterval(rawValue) {
            return Date(timeIntervalSince1970: timeInterval)
        }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: rawValue) ?? Date()
    }
}

// MARK: - Audit Configuration

/// Configuration for audit logging service
public struct AuditConfiguration: Sendable, Codable {
    public let enabled: Bool
    public let defaultRetentionDays: Int
    public let bufferSize: Int
    public let flushIntervalSeconds: TimeInterval
    public let requiredComplianceFlags: [String]
    public let excludedEventTypes: [AuditEventType]
    public let piiDetectionEnabled: Bool
    public let encryptionEnabled: Bool
    
    public static let `default` = AuditConfiguration(
        enabled: true,
        defaultRetentionDays: 1095, // 3 years
        bufferSize: 100,
        flushIntervalSeconds: 60,
        requiredComplianceFlags: [],
        excludedEventTypes: [],
        piiDetectionEnabled: true,
        encryptionEnabled: true
    )
    
    public init(
        enabled: Bool,
        defaultRetentionDays: Int,
        bufferSize: Int,
        flushIntervalSeconds: TimeInterval,
        requiredComplianceFlags: [String],
        excludedEventTypes: [AuditEventType],
        piiDetectionEnabled: Bool,
        encryptionEnabled: Bool
    ) {
        self.enabled = enabled
        self.defaultRetentionDays = defaultRetentionDays
        self.bufferSize = bufferSize
        self.flushIntervalSeconds = flushIntervalSeconds
        self.requiredComplianceFlags = requiredComplianceFlags
        self.excludedEventTypes = excludedEventTypes
        self.piiDetectionEnabled = piiDetectionEnabled
        self.encryptionEnabled = encryptionEnabled
    }
}
