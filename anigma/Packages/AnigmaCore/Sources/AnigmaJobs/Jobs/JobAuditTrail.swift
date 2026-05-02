//
//  JobAuditTrail.swift
//  AnigmaCore
//
//  Comprehensive job history and audit trail system.
//

import AnigmaFoundation
import AnigmaGovernance
import Foundation
import AnigmaPrimitives

/// Comprehensive job audit trail system for compliance and debugging.
public actor JobAuditTrail {
    // MARK: - Configuration
    private let maxAuditEntries: Int
    private let retentionPeriod: TimeInterval
    private let persistence: JobAuditPersistence?
    
    // MARK: - State
    private var auditEntries: [JobAuditEntry] = []
    private var entryIndex: [JobId: [JobAuditEntry]] = [:]
    private var lastCleanup = Date()
    private let cleanupInterval: TimeInterval = 3600 // 1 hour
    
    // Background tasks
    private var persistenceTask: Task<Void, Never>?
    
    public init(
        maxAuditEntries: Int = 50000,
        retentionPeriod: TimeInterval = 86400 * 30, // 30 days
        persistence: JobAuditPersistence? = nil
    ) {
        self.maxAuditEntries = maxAuditEntries
        self.retentionPeriod = retentionPeriod
        self.persistence = persistence
        
        // Load existing entries from persistence if available
        Task {
            await loadExistingEntries()
        }
    }
    
    // MARK: - Audit Entry Recording
    
    /// Record job submission.
    public func recordJobSubmission(_ job: Job, submittedBy: String? = nil) async {
        let entry = JobAuditEntry(
            id: UUID().uuidString,
            jobId: job.id,
            timestamp: Date(),
            eventType: .jobSubmitted,
            userId: submittedBy,
            data: [
                "jobId": job.id.raw,
                "jobType": job.typeId,
                "priority": job.priority.rawValue,
                "inputRefs": job.inputRefs.map { $0.raw },
                "metadata": job.metadata,
                "submittedBy": submittedBy as Any
            ]
        )
        
        await addEntry(entry)
    }
    
    /// Record job status change.
    public func recordStatusChange(
        jobId: JobId,
        oldStatus: JobStatus,
        newStatus: JobStatus,
        reason: String? = nil,
        userId: String? = nil
    ) async {
        let entry = JobAuditEntry(
            id: UUID().uuidString,
            jobId: jobId,
            timestamp: Date(),
            eventType: .statusChange,
            userId: userId,
            data: [
                "jobId": jobId.raw,
                "oldStatus": oldStatus.rawValue,
                "newStatus": newStatus.rawValue,
                "reason": reason as Any,
                "userId": userId as Any
            ]
        )
        
        await addEntry(entry)
    }
    
    /// Record job execution attempt.
    public func recordExecutionAttempt(
        jobId: JobId,
        attemptNumber: Int,
        workerId: String? = nil,
        systemInfo: [String: Any]? = nil
    ) async {
        let entry = JobAuditEntry(
            id: UUID().uuidString,
            jobId: jobId,
            timestamp: Date(),
            eventType: .executionAttempt,
            data: [
                "jobId": jobId.raw,
                "attemptNumber": attemptNumber,
                "workerId": workerId as Any,
                "systemInfo": systemInfo as Any
            ]
        )
        
        await addEntry(entry)
    }
    
    /// Record job completion.
    public func recordJobCompletion(
        jobId: JobId,
        result: JobResult,
        executionTime: Int64,
        outputCount: Int
    ) async {
        let entry = JobAuditEntry(
            id: UUID().uuidString,
            jobId: jobId,
            timestamp: Date(),
            eventType: .jobCompleted,
            data: [
                "jobId": jobId.raw,
                "outcome": result.outcome.rawValue,
                "executionTimeMs": executionTime,
                "actionsApplied": result.actionsApplied,
                "outputCount": outputCount,
                "summary": result.summary as Any,
                "outputRefs": result.outputRefs.map { $0.raw }
            ]
        )
        
        await addEntry(entry)
    }
    
    /// Record job failure.
    public func recordJobFailure(
        jobId: JobId,
        error: Error,
        attemptNumber: Int,
        errorClassification: JobErrorClassification? = nil
    ) async {
        let entry = JobAuditEntry(
            id: UUID().uuidString,
            jobId: jobId,
            timestamp: Date(),
            eventType: .jobFailed,
            data: [
                "jobId": jobId.raw,
                "error": error.localizedDescription,
                "errorType": String(describing: type(of: error)),
                "attemptNumber": attemptNumber,
                "errorClassification": errorClassification?.rawValue as Any
            ]
        )
        
        await addEntry(entry)
    }
    
    /// Record job timeout.
    public func recordJobTimeout(
        jobId: JobId,
        timeoutDuration: TimeInterval,
        progress: Double? = nil
    ) async {
        let entry = JobAuditEntry(
            id: UUID().uuidString,
            jobId: jobId,
            timestamp: Date(),
            eventType: .jobTimeout,
            data: [
                "jobId": jobId.raw,
                "timeoutDuration": timeoutDuration,
                "progress": progress as Any
            ]
        )
        
        await addEntry(entry)
    }
    
    /// Record job retry.
    public func recordJobRetry(
        jobId: JobId,
        retryReason: String,
        backoffDelay: TimeInterval,
        nextRetryAt: Date
    ) async {
        let entry = JobAuditEntry(
            id: UUID().uuidString,
            jobId: jobId,
            timestamp: Date(),
            eventType: .jobRetry,
            data: [
                "jobId": jobId.raw,
                "retryReason": retryReason,
                "backoffDelay": backoffDelay,
                "nextRetryAt": nextRetryAt.timeIntervalSince1970
            ]
        )
        
        await addEntry(entry)
    }
    
    /// Record job cancellation.
    public func recordJobCancellation(
        jobId: JobId,
        cancelledBy: String? = nil,
        reason: String? = nil
    ) async {
        let entry = JobAuditEntry(
            id: UUID().uuidString,
            jobId: jobId,
            timestamp: Date(),
            eventType: .jobCancelled,
            userId: cancelledBy,
            data: [
                "jobId": jobId.raw,
                "cancelledBy": cancelledBy as Any,
                "reason": reason as Any
            ]
        )
        
        await addEntry(entry)
    }
    
    /// Record system event affecting jobs.
    public func recordSystemEvent(
        eventType: AuditEventType,
        description: String,
        affectedJobs: [JobId] = [],
        systemInfo: [String: Any] = [:],
        userId: String? = nil
    ) async {
        let entry = JobAuditEntry(
            id: UUID().uuidString,
            jobId: nil, // System-wide event
            timestamp: Date(),
            eventType: eventType,
            userId: userId,
            data: [
                "description": description,
                "affectedJobs": affectedJobs.map { $0.raw },
                "systemInfo": systemInfo,
                "userId": userId as Any
            ]
        )
        
        await addEntry(entry)
    }
    
    /// Record security event.
    public func recordSecurityEvent(
        jobId: JobId?,
        eventType: String,
        description: String,
        severity: String,
        source: String,
        userId: String? = nil
    ) async {
        let entry = JobAuditEntry(
            id: UUID().uuidString,
            jobId: jobId,
            timestamp: Date(),
            eventType: .securityEvent,
            userId: userId,
            data: [
                "jobId": jobId?.raw as Any,
                "securityEventType": eventType,
                "description": description,
                "severity": severity,
                "source": source,
                "userId": userId as Any
            ]
        )
        
        await addEntry(entry)
    }
    
    // MARK: - Audit Trail Queries
    
    /// Get complete audit trail for a specific job.
    public func getJobAuditTrail(_ jobId: JobId) async -> [JobAuditEntry] {
        return entryIndex[jobId] ?? []
    }
    
    /// Get audit entries with filtering and pagination.
    public func getAuditEntries(
        eventType: AuditEventType? = nil,
        userId: String? = nil,
        jobId: JobId? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        limit: Int? = nil,
        offset: Int = 0
    ) async -> [JobAuditEntry] {
        var filtered = auditEntries
        
        // Filter by event type
        if let eventType = eventType {
            filtered = filtered.filter { $0.eventType == eventType }
        }
        
        // Filter by user
        if let userId = userId {
            filtered = filtered.filter { $0.userId == userId }
        }
        
        // Filter by job
        if let jobId = jobId {
            filtered = filtered.filter { $0.jobId == jobId }
        }
        
        // Filter by date range
        if let startDate = startDate {
            filtered = filtered.filter { $0.timestamp >= startDate }
        }
        
        if let endDate = endDate {
            filtered = filtered.filter { $0.timestamp <= endDate }
        }
        
        // Sort by timestamp (newest first)
        filtered.sort { $0.timestamp > $1.timestamp }
        
        // Apply pagination
        let startIndex = min(offset, filtered.count)
        let endIndex = limit.map { min(startIndex + $0, filtered.count) } ?? filtered.count
        
        return Array(filtered[startIndex..<endIndex])
    }
    
    /// Get audit statistics.
    public func getAuditStatistics(timeRange: TimeRange? = nil) async -> AuditStatistics {
        let cutoff = timeRange.map { getCutoffDate(for: $0) } ?? Date.distantPast
        let relevantEntries = auditEntries.filter { $0.timestamp >= cutoff }
        
        let eventCounts = Dictionary(grouping: relevantEntries) { $0.eventType }
            .mapValues { $0.count }
        
        let userCounts = Dictionary(grouping: relevantEntries.compactMap { $0.userId }, by: { $0 })
            .mapValues { $0.count }
        
        let recentFailures = relevantEntries.filter { 
            $0.eventType == .jobFailed && $0.timestamp >= Date().addingTimeInterval(-86400)
        }.count
        
        let averageExecutionTime = calculateAverageExecutionTime(from: relevantEntries)
        let uniqueJobs = Set(relevantEntries.compactMap { $0.jobId }).count
        
        return AuditStatistics(
            totalEntries: relevantEntries.count,
            eventCounts: eventCounts,
            userCounts: userCounts,
            recentFailures: recentFailures,
            averageExecutionTime: averageExecutionTime,
            uniqueJobs: uniqueJobs,
            timeRange: timeRange
        )
    }
    
    /// Generate compliance report.
    public func generateComplianceReport(
        startDate: Date,
        endDate: Date,
        regulations: [ComplianceRegulation] = []
    ) async -> ComplianceReport {
        let entries = await getAuditEntries(
            startDate: startDate,
            endDate: endDate
        )
        
        var regulationResults: [ComplianceRegulation: ComplianceResult] = [:]
        
        for regulation in regulations {
            let result = await checkCompliance(regulation: regulation, entries: entries)
            regulationResults[regulation] = result
        }
        
        return ComplianceReport(
            startDate: startDate,
            endDate: endDate,
            totalEntries: entries.count,
            regulationResults: regulationResults,
            generatedAt: Date()
        )
    }
    
    /// Export audit trail.
    public func exportAuditTrail(
        startDate: Date? = nil,
        endDate: Date? = nil,
        format: ExportFormat = .json
    ) async -> Data {
        let entries = await getAuditEntries(
            startDate: startDate,
            endDate: endDate
        )
        
        switch format {
        case .json:
            return try! JSONEncoder().encode(entries)
        case .csv:
            return generateCSV(from: entries)
        case .auditlog:
            return generateAuditLogFormat(from: entries)
        case .prometheus:
            return Data() // Prometheus format not suitable for audit logs
        }
    }
    
    // MARK: - Internal Methods
    
    private func addEntry(_ entry: JobAuditEntry) async {
        // Add to in-memory storage
        auditEntries.append(entry)
        
        // Update index
        if let jobId = entry.jobId {
            if entryIndex[jobId] == nil {
                entryIndex[jobId] = []
            }
            entryIndex[jobId]?.append(entry)
        }
        
        // Enforce size limits
        if auditEntries.count > maxAuditEntries {
            let removed = auditEntries.removeFirst()
            
            // Update index
            if let jobId = removed.jobId {
                entryIndex[jobId]?.removeAll { $0.id == removed.id }
                if entryIndex[jobId]?.isEmpty == true {
                    entryIndex.removeValue(forKey: jobId)
                }
            }
        }
        
        // Persist asynchronously
        if let persistence = persistence {
            Task {
                try? await persistence.save(entry: entry)
            }
        }
        
        // Periodic cleanup
        let now = Date()
        if now.timeIntervalSince(lastCleanup) > cleanupInterval {
            Task {
                await performCleanup()
                lastCleanup = now
            }
        }
    }
    
    private func performCleanup() async {
        let cutoff = Date().addingTimeInterval(-retentionPeriod)
        auditEntries.removeAll { $0.timestamp < cutoff }
        
        // Clean up index
        for (jobId, entries) in entryIndex {
            let filtered = entries.filter { $0.timestamp >= cutoff }
            if filtered.isEmpty {
                entryIndex.removeValue(forKey: jobId)
            } else {
                entryIndex[jobId] = filtered
            }
        }
    }
    
    private func loadExistingEntries() async {
        guard let persistence = persistence else { return }
        
        do {
            let entries = try await persistence.loadEntries(
                since: Date().addingTimeInterval(-retentionPeriod)
            )
            
            for entry in entries {
                auditEntries.append(entry)
                
                if let jobId = entry.jobId {
                    if entryIndex[jobId] == nil {
                        entryIndex[jobId] = []
                    }
                    entryIndex[jobId]?.append(entry)
                }
            }
            
            await logAuditLoadSuccess(count: entries.count)
        } catch {
            await logAuditLoadFailure(error: error)
        }
    }
    
    private func logAuditLoadSuccess(count: Int) async {
        logInfo("Loaded \(count) audit entries")
    }
    
    private func logAuditLoadFailure(error: Error) async {
        logError("Failed to load audit entries: \(error.localizedDescription)")
    }
    
    private func getCutoffDate(for timeRange: TimeRange) -> Date {
        switch timeRange {
        case .lastHour:
            return Date().addingTimeInterval(-3600)
        case .last24Hours:
            return Date().addingTimeInterval(-86400)
        case .last7Days:
            return Date().addingTimeInterval(-86400 * 7)
        case .last30Days:
            return Date().addingTimeInterval(-86400 * 30)
        }
    }
    
    private func calculateAverageExecutionTime(from entries: [JobAuditEntry]) -> TimeInterval {
        let completionEntries = entries.filter { 
            $0.eventType == .jobCompleted && $0.data["executionTimeMs"] != nil
        }
        
        guard !completionEntries.isEmpty else { return 0 }
        
        let totalTime = completionEntries.compactMap { entry in
            entry.data["executionTimeMs"] as? Int64
        }.reduce(0, +)
        
        return TimeInterval(totalTime) / Double(completionEntries.count) / 1000.0
    }
    
    private func checkCompliance(regulation: ComplianceRegulation, entries: [JobAuditEntry]) async -> ComplianceResult {
        var violations: [String] = []
        var score = 100.0
        
        switch regulation {
        case .dataRetention:
            // Check if entries are retained for required period
            let cutoff = Date().addingTimeInterval(-86400 * 365) // 1 year
            let oldEntries = entries.filter { $0.timestamp < cutoff }
            if oldEntries.isEmpty {
                violations.append("No entries older than 1 year found")
                score -= 50
            }
            
        case .accessLogging:
            // Check if all actions have user attribution
            let entriesWithoutUser = entries.filter { 
                $0.eventType.requiresUser && $0.userId == nil
            }
            if !entriesWithoutUser.isEmpty {
                violations.append("\(entriesWithoutUser.count) entries lack user attribution")
                score -= Double(entriesWithoutUser.count) * 5
            }
            
        case .changeTracking:
            // Check if status changes are properly logged
            let statusChanges = entries.filter { $0.eventType == .statusChange }
            if statusChanges.isEmpty {
                violations.append("No status change events found")
                score -= 30
            }
        }
        
        return ComplianceResult(
            regulation: regulation,
            score: max(0, score),
            violations: violations,
            passed: score >= 70
        )
    }
    
    private func generateCSV(from entries: [JobAuditEntry]) -> Data {
        var csv = "Timestamp,JobID,EventType,UserID,Data\n"
        
        for entry in entries {
            csv += "\(entry.timestamp.iso8601),"
            csv += "\(entry.jobId?.raw ?? ""),"
            csv += "\(entry.eventType.rawValue),"
            csv += "\(entry.userId ?? ""),"
            csv += "\"\(String(describing: entry.data).replacingOccurrences(of: "\"", with: "\"\""))\"\n"
        }
        
        return csv.data(using: .utf8) ?? Data()
    }
    
    private func generateAuditLogFormat(from entries: [JobAuditEntry]) -> Data {
        var log = ""
        
        for entry in entries {
            log += "[\(entry.timestamp.iso8601)] "
            log += "JOB:\(entry.jobId?.raw ?? "SYSTEM") "
            log += "EVENT:\(entry.eventType.rawValue) "
            if let userId = entry.userId {
                log += "USER:\(userId) "
            }
            log += "DATA:\(entry.data)\n"
        }
        
        return log.data(using: .utf8) ?? Data()
    }
}

// MARK: - Supporting Types

/// Individual audit trail entry.
public struct JobAuditEntry: Codable, Identifiable, Sendable {
    public let id: String
    public let jobId: JobId?
    public let timestamp: Date
    public let eventType: AuditEventType
    public let userId: String?
    nonisolated(unsafe) public let data: [String: Any]
    
    public init(
        id: String,
        jobId: JobId?,
        timestamp: Date,
        eventType: AuditEventType,
        userId: String? = nil,
        data: [String: Any] = [:]
    ) {
        self.id = id
        self.jobId = jobId
        self.timestamp = timestamp
        self.eventType = eventType
        self.userId = userId
        self.data = data
    }
}

/// Types of audit events.
public enum AuditEventType: String, Codable, CaseIterable, Sendable {
    case jobSubmitted
    case statusChange
    case executionAttempt
    case jobCompleted
    case jobFailed
    case jobTimeout
    case jobRetry
    case jobCancelled
    case systemEvent
    case securityEvent
    
    /// Whether this event type requires user attribution.
    public var requiresUser: Bool {
        switch self {
        case .jobSubmitted, .jobCancelled, .securityEvent:
            return true
        default:
            return false
        }
    }
}

/// Audit statistics.
public struct AuditStatistics: Codable, Sendable {
    public let totalEntries: Int
    public let eventCounts: [AuditEventType: Int]
    public let userCounts: [String: Int]
    public let recentFailures: Int
    public let averageExecutionTime: TimeInterval
    public let uniqueJobs: Int
    public let timeRange: TimeRange?
}

/// Compliance regulation types.
public enum ComplianceRegulation: String, Codable, CaseIterable, Sendable {
    case dataRetention = "Data Retention"
    case accessLogging = "Access Logging"
    case changeTracking = "Change Tracking"
}

/// Compliance check result.
public struct ComplianceResult: Codable, Sendable {
    public let regulation: ComplianceRegulation
    public let score: Double
    public let violations: [String]
    public let passed: Bool
}

/// Compliance report.
public struct ComplianceReport: Codable, Sendable {
    public let startDate: Date
    public let endDate: Date
    public let totalEntries: Int
    public let regulationResults: [ComplianceRegulation: ComplianceResult]
    public let generatedAt: Date
}

/// Protocol for audit trail persistence.
public protocol JobAuditPersistence: Sendable {
    func save(entry: JobAuditEntry) async throws
    func loadEntries(since: Date) async throws -> [JobAuditEntry]
    func deleteEntries(olderThan: Date) async throws
}

// MARK: - Extensions

extension Date {
    var iso8601: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}

// MARK: - Codable Extensions

extension JobAuditEntry {
    enum CodingKeys: String, CodingKey {
        case id, jobId, timestamp, eventType, userId, data
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        jobId = try container.decodeIfPresent(JobId.self, forKey: .jobId)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        eventType = try container.decode(AuditEventType.self, forKey: .eventType)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        
        // Decode data as JSON object
        let dataString = try container.decode(String.self, forKey: .data)
        let dataData = dataString.data(using: .utf8) ?? Data()
        data = try JSONSerialization.jsonObject(with: dataData) as? [String: Any] ?? [:]
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(jobId, forKey: .jobId)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(eventType, forKey: .eventType)
        try container.encodeIfPresent(userId, forKey: .userId)
        
        // Encode data as JSON string
        let dataData = try JSONSerialization.data(withJSONObject: data)
        let dataString = String(data: dataData, encoding: .utf8) ?? "{}"
        try container.encode(dataString, forKey: .data)
    }
}
