import Foundation

// MARK: - Enhanced CSV Exporter

/// Professional CSV report generator for compliance audit reports
public class EnhancedCSVReportExporter {
    
    // MARK: - Properties
    
    private let configuration: CSVConfiguration
    private let dateFormatter: DateFormatter
    private let numberFormatter: NumberFormatter
    
    // MARK: - Initialization
    
    public init(configuration: CSVConfiguration = CSVConfiguration.default) {
        self.configuration = configuration
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        self.dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        self.numberFormatter = NumberFormatter()
        self.numberFormatter.numberStyle = .decimal
        self.numberFormatter.maximumFractionDigits = 2
    }
    
    // MARK: - Public Interface
    
    /// Export audit events and summary to comprehensive CSV files
    public func export(
        events: [AuditEvent],
        summary: AuditReportSummary,
        to filePath: String
    ) async throws {
        
        // Create directory if it doesn't exist
        let directoryURL = URL(fileURLWithPath: filePath).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        
        // Generate main events CSV
        let eventsCSVPath = generateEventsCSVPath(from: filePath)
        try await exportEvents(events, to: eventsCSVPath)
        
        // Generate summary CSV
        let summaryCSVPath = generateSummaryCSVPath(from: filePath)
        try await exportSummary(summary, to: summaryCSVPath)
        
        // Generate detailed breakdown CSVs
        if configuration.includeDetailedBreakdowns {
            try await exportDetailedBreakdowns(events: events, baseFilePath: filePath)
        }
        
        // Generate index file
        try await generateIndexFile(
            mainFile: eventsCSVPath,
            summaryFile: summaryCSVPath,
            baseFilePath: filePath,
            summary: summary
        )
    }
    
    // MARK: - Export Methods
    
    private func exportEvents(_ events: [AuditEvent], to filePath: String) async throws {
        var csvContent = ""
        
        // Add header row with BOM for proper UTF-8 handling
        if configuration.includeBOM {
            csvContent = "\u{FEFF}"
        }
        
        // Add metadata header
        csvContent += generateMetadataHeader(events: events)
        
        // Add column headers
        csvContent += buildEventHeaderRow()
        
        // Add event data rows
        for event in events {
            csvContent += buildEventDataRow(from: event)
        }
        
        // Add footer
        if configuration.includeFooter {
            csvContent += generateFooter(events: events)
        }
        
        try csvContent.write(toFile: filePath, atomically: true, encoding: .utf8)
    }
    
    private func exportSummary(_ summary: AuditReportSummary, to filePath: String) async throws {
        var csvContent = ""
        
        if configuration.includeBOM {
            csvContent = "\u{FEFF}"
        }
        
        // Summary sections
        csvContent += "COMPLIANCE AUDIT REPORT SUMMARY\n"
        csvContent += "Generated: \(dateFormatter.string(from: Date()))\n\n"
        
        // Overall statistics
        csvContent += "OVERALL STATISTICS\n"
        csvContent += "Metric,Value,Percentage\n"
        csvContent += "Total Events,\(summary.totalEvents),100%\n"
        
        for (eventType, count) in summary.eventCounts.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let percentage = Double(count) / Double(summary.totalEvents) * 100
            csvContent += "\(eventType.rawValue),\(count),\(String(format: "%.2f", percentage))%\n"
        }
        
        csvContent += "\n"
        
        // User statistics
        csvContent += "USER STATISTICS\n"
        csvContent += "Unique Users,\(summary.uniqueUsers)\n"
        csvContent += "Unique Sessions,\(summary.uniqueSessions)\n"
        csvContent += "Average Events per User,\(String(format: "%.2f", Double(summary.totalEvents) / Double(summary.uniqueUsers)))\n"
        csvContent += "\n"
        
        // Compliance statistics
        csvContent += "COMPLIANCE STATISTICS\n"
        csvContent += "Failure Rate,\(String(format: "%.2f", summary.failureRate * 100))%\n"
        csvContent += "Success Rate,\(String(format: "%.2f", (1 - summary.failureRate) * 100))%\n"
        
        if let avgTime = summary.averageResponseTime {
            csvContent += "Average Response Time (ms),\(String(format: "%.2f", avgTime))\n"
        }
        
        if let totalCost = summary.totalCost {
            csvContent += "Total Cost,$\(totalCost)\n"
        }
        
        csvContent += "\n"
        
        // Compliance flags breakdown
        csvContent += "COMPLIANCE FLAGS BREAKDOWN\n"
        csvContent += "Flag,Count,Percentage\n"
        for (flag, count) in summary.complianceFlagCounts.sorted(by: { $0.key < $1.key }) {
            let percentage = Double(count) / Double(summary.totalEvents) * 100
            csvContent += "\(flag),\(count),\(String(format: "%.2f", percentage))%\n"
        }
        
        csvContent += "\n"
        
        // Top user activity
        csvContent += "TOP USER ACTIVITY\n"
        csvContent += "User ID,Event Count,Percentage\n"
        let sortedUsers = summary.userActivity.sorted { $0.value > $1.value }.prefix(10)
        for (userId, count) in sortedUsers {
            let percentage = Double(count) / Double(summary.totalEvents) * 100
            csvContent += "\(userId),\(count),\(String(format: "%.2f", percentage))%\n"
        }
        
        try csvContent.write(toFile: filePath, atomically: true, encoding: .utf8)
    }
    
    private func exportDetailedBreakdowns(events: [AuditEvent], baseFilePath: String) async throws {
        // AI Operations breakdown
        let aiEvents = events.filter { $0.eventType == .aiOperation }
        if !aiEvents.isEmpty {
            let aiPath = generateAIEventsCSVPath(from: baseFilePath)
            try await exportAIEvents(aiEvents, to: aiPath)
        }
        
        // Document Access breakdown
        let docEvents = events.filter { $0.eventType == .documentAccess }
        if !docEvents.isEmpty {
            let docPath = generateDocumentEventsCSVPath(from: baseFilePath)
            try await exportDocumentEvents(docEvents, to: docPath)
        }
        
        // Governance Decision breakdown
        let govEvents = events.filter { $0.eventType == .governanceDecision }
        if !govEvents.isEmpty {
            let govPath = generateGovernanceEventsCSVPath(from: baseFilePath)
            try await exportGovernanceEvents(govEvents, to: govPath)
        }
        
        // Security Events breakdown
        let secEvents = events.filter { $0.eventType == .securityEvent }
        if !secEvents.isEmpty {
            let secPath = generateSecurityEventsCSVPath(from: baseFilePath)
            try await exportSecurityEvents(secEvents, to: secPath)
        }
    }
    
    private func exportAIEvents(_ events: [AuditEvent], to filePath: String) async throws {
        var csvContent = ""
        
        if configuration.includeBOM {
            csvContent = "\u{FEFF}"
        }
        
        csvContent += "AI OPERATIONS DETAILED REPORT\n\n"
        csvContent += buildAIEventHeaderRow()
        
        for event in events {
            csvContent += buildAIEventDataRow(from: event)
        }
        
        try csvContent.write(toFile: filePath, atomically: true, encoding: .utf8)
    }
    
    private func exportDocumentEvents(_ events: [AuditEvent], to filePath: String) async throws {
        var csvContent = ""
        
        if configuration.includeBOM {
            csvContent = "\u{FEFF}"
        }
        
        csvContent += "DOCUMENT ACCESS DETAILED REPORT\n\n"
        csvContent += buildDocumentEventHeaderRow()
        
        for event in events {
            csvContent += buildDocumentEventDataRow(from: event)
        }
        
        try csvContent.write(toFile: filePath, atomically: true, encoding: .utf8)
    }
    
    private func exportGovernanceEvents(_ events: [AuditEvent], to filePath: String) async throws {
        var csvContent = ""
        
        if configuration.includeBOM {
            csvContent = "\u{FEFF}"
        }
        
        csvContent += "GOVERNANCE DECISIONS DETAILED REPORT\n\n"
        csvContent += buildGovernanceEventHeaderRow()
        
        for event in events {
            csvContent += buildGovernanceEventDataRow(from: event)
        }
        
        try csvContent.write(toFile: filePath, atomically: true, encoding: .utf8)
    }
    
    private func exportSecurityEvents(_ events: [AuditEvent], to filePath: String) async throws {
        var csvContent = ""
        
        if configuration.includeBOM {
            csvContent = "\u{FEFF}"
        }
        
        csvContent += "SECURITY EVENTS DETAILED REPORT\n\n"
        csvContent += buildSecurityEventHeaderRow()
        
        for event in events {
            csvContent += buildSecurityEventDataRow(from: event)
        }
        
        try csvContent.write(toFile: filePath, atomically: true, encoding: .utf8)
    }
    
    private func generateIndexFile(
        mainFile: String,
        summaryFile: String,
        baseFilePath: String,
        summary: AuditReportSummary
    ) async throws {
        
        let indexFilePath = generateIndexFilePath(from: baseFilePath)
        var indexContent = ""
        
        if configuration.includeBOM {
            indexContent = "\u{FEFF}"
        }
        
        indexContent += "COMPLIANCE AUDIT REPORT - FILE INDEX\n"
        indexContent += "Generated: \(dateFormatter.string(from: Date()))\n"
        indexContent += "Report Period: \(dateFormatter.string(from: summary.dateRange.lowerBound)) - \(dateFormatter.string(from: summary.dateRange.upperBound))\n\n"
        
        indexContent += "FILES INCLUDED:\n"
        indexContent += "Main Events Log,\(URL(fileURLWithPath: mainFile).lastPathComponent)\n"
        indexContent += "Summary Statistics,\(URL(fileURLWithPath: summaryFile).lastPathComponent)\n"
        
        // Add detailed breakdown files
        if configuration.includeDetailedBreakdowns {
            let eventsByType = Dictionary(grouping: summary.eventCounts.keys) { $0 }
            
            for eventType in eventsByType {
                let fileName = generateDetailedFileName(for: eventType, baseFilePath: baseFilePath)
                indexContent += "\(eventType.rawValue.capitalized) Detailed,\(URL(fileURLWithPath: fileName).lastPathComponent)\n"
            }
        }
        
        indexContent += "\nFILE DESCRIPTIONS:\n"
        indexContent += "Main Events Log,Complete log of all audit events with full details\n"
        indexContent += "Summary Statistics,Aggregated statistics and compliance metrics\n"
        
        if configuration.includeDetailedBreakdowns {
            indexContent += "Detailed Files,Type-specific breakdowns with additional metadata\n"
        }
        
        try indexContent.write(toFile: indexFilePath, atomically: true, encoding: .utf8)
    }
    
    // MARK: - CSV Building Methods
    
    private func generateMetadataHeader(events: [AuditEvent]) -> String {
        let dateRange = events.map(\.timestamp).sorted()
        let startDate = dateFormatter.string(from: dateRange.first ?? Date())
        let endDate = dateFormatter.string(from: dateRange.last ?? Date())
        let uniqueUsers = Set(events.compactMap(\.userId)).count
        let uniqueSessions = Set(events.compactMap(\.sessionId)).count
        
        var header = "COMPLIANCE AUDIT REPORT - EVENTS LOG\n"
        header += "Generated: \(dateFormatter.string(from: Date()))\n"
        header += "Report Period: \(startDate) - \(endDate)\n"
        header += "Total Events: \(events.count)\n"
        header += "Unique Users: \(uniqueUsers)\n"
        header += "Unique Sessions: \(uniqueSessions)\n"
        header += "Export Format: UTF-8 CSV\n\n"
        
        return header
    }
    
    private func buildEventHeaderRow() -> String {
        let columns = [
            "ID", "Timestamp", "Event Type", "User ID", "Session ID", "Principal",
            "Operation Type", "Resource ID", "Resource Type", "Action", "Result",
            "IP Address", "User Agent", "Compliance Flags", "Details", "Metadata"
        ]
        
        return columns.map { escapeCSVField($0) }.joined(separator: ",") + "\n"
    }
    
    private func buildEventDataRow(from event: AuditEvent) -> String {
        let fields = [
            event.id.uuidString,
            dateFormatter.string(from: event.timestamp),
            event.eventType.rawValue,
            event.userId ?? "",
            event.sessionId ?? "",
            event.principal,
            event.operationType ?? "",
            event.resourceId ?? "",
            event.resourceType ?? "",
            event.action,
            event.result ?? "",
            event.ipAddress ?? "",
            event.userAgent ?? "",
            event.complianceFlags.joined(separator: ";"),
            escapeCSVField(formatDictionary(event.details)),
            escapeCSVField(formatDictionary(event.metadata))
        ]
        
        return fields.map { escapeCSVField($0) }.joined(separator: ",") + "\n"
    }
    
    private func buildAIEventHeaderRow() -> String {
        let columns = [
            "Event ID", "Timestamp", "User ID", "Operation Type", "Model ID",
            "Model Version", "Input Tokens", "Output Tokens", "Inference Time (ms)",
            "Confidence", "Cost", "Safety Filters", "Policy Violations"
        ]
        
        return columns.map { escapeCSVField($0) }.joined(separator: ",") + "\n"
    }
    
    private func buildAIEventDataRow(from event: AuditEvent) -> String {
        // Extract AI-specific metadata from event details
        let modelId = event.details["model_id"] ?? ""
        let modelVersion = event.details["model_version"] ?? ""
        let inputTokens = event.details["input_tokens"] ?? ""
        let outputTokens = event.details["output_tokens"] ?? ""
        let inferenceTime = event.details["inference_time_ms"] ?? ""
        let confidence = event.details["confidence"] ?? ""
        let cost = event.details["cost"] ?? ""
        let safetyFilters = event.details["safety_filters"] ?? ""
        let policyViolations = event.details["content_policy_violations"] ?? ""
        
        let fields = [
            event.id.uuidString,
            dateFormatter.string(from: event.timestamp),
            event.userId ?? "",
            event.operationType ?? "",
            modelId,
            modelVersion,
            inputTokens,
            outputTokens,
            inferenceTime,
            confidence,
            cost,
            safetyFilters,
            policyViolations
        ]
        
        return fields.map { escapeCSVField($0) }.joined(separator: ",") + "\n"
    }
    
    private func buildDocumentEventHeaderRow() -> String {
        let columns = [
            "Event ID", "Timestamp", "User ID", "Access Type", "Document Path",
            "Document Hash", "File Size", "MIME Type", "Permissions", "Access Reason",
            "Data Classification", "Previous Version", "New Version"
        ]
        
        return columns.map { escapeCSVField($0) }.joined(separator: ",") + "\n"
    }
    
    private func buildDocumentEventDataRow(from event: AuditEvent) -> String {
        let accessType = event.details["access_type"] ?? ""
        let documentPath = event.details["document_path"] ?? ""
        let documentHash = event.details["document_hash"] ?? ""
        let fileSize = event.details["file_size"] ?? ""
        let mimeType = event.details["mime_type"] ?? ""
        let permissions = event.details["permissions"] ?? ""
        let accessReason = event.details["access_reason"] ?? ""
        let dataClassification = event.details["data_classification"] ?? ""
        let previousVersion = event.details["previous_version"] ?? ""
        let newVersion = event.details["new_version"] ?? ""
        
        let fields = [
            event.id.uuidString,
            dateFormatter.string(from: event.timestamp),
            event.userId ?? "",
            accessType,
            documentPath,
            documentHash,
            fileSize,
            mimeType,
            permissions,
            accessReason,
            dataClassification,
            previousVersion,
            newVersion
        ]
        
        return fields.map { escapeCSVField($0) }.joined(separator: ",") + "\n"
    }
    
    private func buildGovernanceEventHeaderRow() -> String {
        let columns = [
            "Event ID", "Timestamp", "User ID", "Decision Type", "Policy ID",
            "Policy Version", "Rule IDs", "Risk Score", "Blocking Factors",
            "Approval Chain", "Justification", "Automated Review"
        ]
        
        return columns.map { escapeCSVField($0) }.joined(separator: ",") + "\n"
    }
    
    private func buildGovernanceEventDataRow(from event: AuditEvent) -> String {
        let decisionType = event.details["decision_type"] ?? ""
        let policyId = event.details["policy_id"] ?? ""
        let policyVersion = event.details["policy_version"] ?? ""
        let ruleIds = event.details["rule_ids"] ?? ""
        let riskScore = event.details["risk_score"] ?? ""
        let blockingFactors = event.details["blocking_factors"] ?? ""
        let approvalChain = event.details["approval_chain"] ?? ""
        let justification = event.details["justification"] ?? ""
        let automatedReview = event.details["automated_review"] ?? ""
        
        let fields = [
            event.id.uuidString,
            dateFormatter.string(from: event.timestamp),
            event.userId ?? "",
            decisionType,
            policyId,
            policyVersion,
            ruleIds,
            riskScore,
            blockingFactors,
            approvalChain,
            justification,
            automatedReview
        ]
        
        return fields.map { escapeCSVField($0) }.joined(separator: ",") + "\n"
    }
    
    private func buildSecurityEventHeaderRow() -> String {
        let columns = [
            "Event ID", "Timestamp", "User ID", "Principal", "Security Event Type",
            "Threat Level", "Source IP", "Target Resource", "Action Taken", "Investigation Status"
        ]
        
        return columns.map { escapeCSVField($0) }.joined(separator: ",") + "\n"
    }
    
    private func buildSecurityEventDataRow(from event: AuditEvent) -> String {
        let securityType = event.details["security_event_type"] ?? ""
        let threatLevel = event.details["threat_level"] ?? ""
        let sourceIP = event.details["source_ip"] ?? ""
        let targetResource = event.details["target_resource"] ?? ""
        let actionTaken = event.details["action_taken"] ?? ""
        let investigationStatus = event.details["investigation_status"] ?? ""
        
        let fields = [
            event.id.uuidString,
            dateFormatter.string(from: event.timestamp),
            event.userId ?? "",
            event.principal,
            securityType,
            threatLevel,
            sourceIP,
            targetResource,
            actionTaken,
            investigationStatus
        ]
        
        return fields.map { escapeCSVField($0) }.joined(separator: ",") + "\n"
    }
    
    // MARK: - Utility Methods
    
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
    
    private func formatDictionary(_ dict: [String: String]) -> String {
        guard !dict.isEmpty else { return "" }
        
        return dict.map { key, value in
            "\(key):\(value)"
        }.joined(separator: "|")
    }
    
    private func generateFooter(events: [AuditEvent]) -> String {
        var footer = "\nEND OF REPORT\n"
        footer += "Total Records: \(events.count)\n"
        footer += "Export Completed: \(dateFormatter.string(from: Date()))\n"
        
        return footer
    }
    
    // MARK: - Path Generation
    
    private func generateEventsCSVPath(from basePath: String) -> String {
        let url = URL(fileURLWithPath: basePath)
        let name = url.deletingPathExtension().lastPathComponent
        let path = url.deletingLastPathComponent().appendingPathComponent("\(name)_events.csv")
        return path.path
    }
    
    private func generateSummaryCSVPath(from basePath: String) -> String {
        let url = URL(fileURLWithPath: basePath)
        let name = url.deletingPathExtension().lastPathComponent
        let path = url.deletingLastPathComponent().appendingPathComponent("\(name)_summary.csv")
        return path.path
    }
    
    private func generateIndexFilePath(from basePath: String) -> String {
        let url = URL(fileURLWithPath: basePath)
        let name = url.deletingPathExtension().lastPathComponent
        let path = url.deletingLastPathComponent().appendingPathComponent("\(name)_index.csv")
        return path.path
    }
    
    private func generateDetailedFileName(for eventType: AuditEventType, baseFilePath: String) -> String {
        let url = URL(fileURLWithPath: baseFilePath)
        let name = url.deletingPathExtension().lastPathComponent
        let path = url.deletingLastPathComponent().appendingPathComponent("\(name)_\(eventType.rawValue).csv")
        return path.path
    }
    
    private func generateAIEventsCSVPath(from basePath: String) -> String {
        return generateDetailedFileName(for: .aiOperation, baseFilePath: basePath)
    }
    
    private func generateDocumentEventsCSVPath(from basePath: String) -> String {
        return generateDetailedFileName(for: .documentAccess, baseFilePath: basePath)
    }
    
    private func generateGovernanceEventsCSVPath(from basePath: String) -> String {
        return generateDetailedFileName(for: .governanceDecision, baseFilePath: basePath)
    }
    
    private func generateSecurityEventsCSVPath(from basePath: String) -> String {
        return generateDetailedFileName(for: .securityEvent, baseFilePath: basePath)
    }
}

// MARK: - CSV Configuration

public struct CSVConfiguration {
    public let includeBOM: Bool
    public let includeFooter: Bool
    public let includeDetailedBreakdowns: Bool
    public let delimiter: String
    public let encoding: String.Encoding
    
    public static let `default` = CSVConfiguration(
        includeBOM: true,
        includeFooter: true,
        includeDetailedBreakdowns: true,
        delimiter: ",",
        encoding: .utf8
    )
    
    public init(
        includeBOM: Bool,
        includeFooter: Bool,
        includeDetailedBreakdowns: Bool,
        delimiter: String,
        encoding: String.Encoding
    ) {
        self.includeBOM = includeBOM
        self.includeFooter = includeFooter
        self.includeDetailedBreakdowns = includeDetailedBreakdowns
        self.delimiter = delimiter
        self.encoding = encoding
    }
}