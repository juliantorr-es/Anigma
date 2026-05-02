import Foundation
import ContractsCore
import AnigmaPrimitives
import DatabaseCore

// MARK: - Report Generation Service

/// Service for generating comprehensive compliance audit reports
public actor AuditReportGenerationService {
    
    // MARK: - Properties
    
    private let auditService: AuditLoggingService
    private let database: any DatabaseExecutor
    private let pdfExporter: PDFReportExporter
    private let csvExporter: CSVReportExporter
    private let jsonExporter: JSONReportExporter
    private let xmlExporter: XMLReportExporter
    
    // MARK: - Initialization
    
    public init(
        auditService: AuditLoggingService,
        database: any DatabaseExecutor,
        pdfExporter: PDFReportExporter = DefaultPDFReportExporter(),
        csvExporter: CSVReportExporter = DefaultCSVReportExporter(),
        jsonExporter: JSONReportExporter = DefaultJSONReportExporter(),
        xmlExporter: XMLReportExporter = DefaultXMLReportExporter()
    ) {
        self.auditService = auditService
        self.database = database
        self.pdfExporter = pdfExporter
        self.csvExporter = csvExporter
        self.jsonExporter = jsonExporter
        self.xmlExporter = xmlExporter
    }
    
    // MARK: - Public Interface
    
    /// Generate a comprehensive audit report
    public func generateReport(
        filters: AuditReportFilters,
        formats: [ExportFormat] = [.pdf, .csv],
        requestedBy: String
    ) async throws -> AuditReport {
        
        // Create report record
        let reportId = UUID()
        let report = AuditReport(
            id: reportId,
            generatedAt: Date(),
            generatedBy: requestedBy,
            filters: filters,
            summary: AuditReportSummary(
                totalEvents: 0,
                dateRange: filters.dateRange ?? Date()...Date(),
                uniqueUsers: 0,
                uniqueSessions: 0,
                eventCounts: [:],
                operationCounts: [:],
                userActivity: [:],
                complianceFlagCounts: [:],
                failureRate: 0.0
            ),
            events: [],
            exportFormats: formats
        )
        
        // Store report metadata
        try await storeReportMetadata(report, status: .generating)
        
        do {
            // Fetch events and generate summary
            let events = try await auditService.queryEvents(filters: filters)
            let summary = try await auditService.getStatistics(filters: filters)
            
            // Export in requested formats
            var exportPaths: [ExportFormat: String] = [:]
            
            for format in formats {
                let filePath = try await exportReport(
                    events: events,
                    summary: summary,
                    format: format,
                    reportId: reportId
                )
                exportPaths[format] = filePath
            }
            
            // Update report with generated data
            let completedReport = AuditReport(
                id: reportId,
                generatedAt: Date(),
                generatedBy: requestedBy,
                filters: filters,
                summary: summary,
                events: events,
                exportFormats: formats
            )
            
            // Update stored report
            try await updateReportMetadata(completedReport, exportPaths: exportPaths, status: .completed)
            
            return completedReport
            
        } catch {
            // Update report with error status
            try await updateReportMetadata(report, error: error.localizedDescription, status: .failed)
            throw error
        }
    }
    
    /// Get a previously generated report
    public func getReport(id: UUID) async throws -> AuditReport? {
        let sql = "SELECT * FROM audit_reports WHERE report_id = ?"
        let parameters: [DatabaseParameter] = [.text(id.uuidString)]

        guard let row = try await database.query(sql, parameters: parameters).first else {
            return nil
        }

        return try decodeReportFromDatabase(row)
    }
    
    /// List available reports
    public func listReports(
        limit: Int = 50,
        offset: Int = 0,
        status: ReportStatus? = nil
    ) async throws -> [AuditReport] {
        var whereClause = ""
        var parameters: [DatabaseParameter] = []
        
        if let status = status {
            whereClause = "WHERE status = ?"
            parameters.append(.text(status.rawValue))
        }
        
        let sql = """
        SELECT * FROM audit_reports 
        \(whereClause)
        ORDER BY generated_at DESC 
        LIMIT ? OFFSET ?
        """
        
        parameters.append(.int(limit))
        parameters.append(.int(offset))

        let rows = try await database.query(sql, parameters: parameters)
        return try rows.map { try decodeReportFromDatabase($0) }
    }
    
    /// Delete expired reports
    public func cleanupExpiredReports() async throws {
        let sql = """
        DELETE FROM audit_reports 
        WHERE expires_at IS NOT NULL AND expires_at < ?
        """
        
        let parameters: [DatabaseParameter] = [.int(Int(Date().timeIntervalSince1970))]
        try await database.execute(sql, parameters: parameters)
    }
    
    /// Generate scheduled compliance reports
    public func generateScheduledReport(
        type: ScheduledReportType,
        requestedBy: String
    ) async throws -> AuditReport {
        
        let filters = type.buildFilters()
        let formats = [ExportFormat.pdf, ExportFormat.csv]
        
        return try await generateReport(
            filters: filters,
            formats: formats,
            requestedBy: requestedBy
        )
    }
    
    // MARK: - Private Methods
    
    private func storeReportMetadata(_ report: AuditReport, status: ReportStatus) async throws {
        let sql = """
        INSERT INTO audit_reports (
            report_id, generated_at, generated_by, filters, summary, status
        ) VALUES (?, ?, ?, ?, ?, ?)
        """
        
        let parameters: [DatabaseParameter] = [
            .text(report.id.uuidString),
            .text(ISO8601DateFormatter().string(from: report.generatedAt)),
            .text(report.generatedBy),
            .text(try JSONEncoder().encode(report.filters).base64EncodedString()),
            .text(try JSONEncoder().encode(report.summary).base64EncodedString()),
            .text(status.rawValue)
        ]
        
        try await database.execute(sql, parameters: parameters)
    }
    
    private func updateReportMetadata(
        _ report: AuditReport,
        exportPaths: [ExportFormat: String] = [:],
        error: String? = nil,
        status: ReportStatus
    ) async throws {
        let sql = """
        UPDATE audit_reports 
        SET summary = ?, 
            file_path_pdf = COALESCE(?, file_path_pdf),
            file_path_csv = COALESCE(?, file_path_csv),
            file_path_json = COALESCE(?, file_path_json),
            file_path_xml = COALESCE(?, file_path_xml),
            status = ?,
            error_message = ?,
            expires_at = ?
        WHERE report_id = ?
        """
        
        let expiryDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())?
            .timeIntervalSince1970
        
        let parameters: [DatabaseParameter] = [
            .text(try JSONEncoder().encode(report.summary).base64EncodedString()),
            .text(exportPaths[.pdf] ?? ""),
            .text(exportPaths[.csv] ?? ""),
            .text(exportPaths[.json] ?? ""),
            .text(exportPaths[.xml] ?? ""),
            .text(status.rawValue),
            .text(error ?? ""),
            .int(expiryDate.map(Int.init) ?? 0),
            .text(report.id.uuidString)
        ]
        
        try await database.execute(sql, parameters: parameters)
    }
    
    private func exportReport(
        events: [AuditEvent],
        summary: AuditReportSummary,
        format: ExportFormat,
        reportId: UUID
    ) async throws -> String {
        
        let filePath = generateExportPath(format: format, reportId: reportId)
        
        switch format {
        case .pdf:
            try await pdfExporter.export(events: events, summary: summary, to: filePath)
        case .csv:
            try await csvExporter.export(events: events, summary: summary, to: filePath)
        case .json:
            try await jsonExporter.export(events: events, summary: summary, to: filePath)
        case .xml:
            try await xmlExporter.export(events: events, summary: summary, to: filePath)
        }
        
        return filePath
    }
    
    private func generateExportPath(format: ExportFormat, reportId: UUID) -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let reportsPath = documentsPath.appendingPathComponent("audit_reports")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: reportsPath, withIntermediateDirectories: true)
        
        let fileName = "audit_report_\(reportId.uuidString).\(format.rawValue)"
        return reportsPath.appendingPathComponent(fileName).path
    }
    
    private func decodeReportFromDatabase(_ row: DatabaseRow) throws -> AuditReport {
        let filters = try decodeJSON(AuditReportFilters.self, from: row.string(for: "filters"))
        let summary = try decodeJSON(AuditReportSummary.self, from: row.string(for: "summary"))
        let exportFormats = decodeExportFormats(
            pdf: row.string(for: "file_path_pdf"),
            csv: row.string(for: "file_path_csv"),
            json: row.string(for: "file_path_json"),
            xml: row.string(for: "file_path_xml")
        )

        return AuditReport(
            id: UUID(uuidString: row.string(for: "report_id") ?? "") ?? UUID(),
            generatedAt: decodeTimestamp(row.string(for: "generated_at")),
            generatedBy: row.string(for: "generated_by") ?? "unknown",
            filters: filters,
            summary: summary,
            events: [],
            exportFormats: exportFormats
        )
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, from encoded: String?) throws -> T {
        guard
            let encoded,
            let data = Data(base64Encoded: encoded)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func decodeExportFormats(
        pdf: String?,
        csv: String?,
        json: String?,
        xml: String?
    ) -> [ExportFormat] {
        var formats: [ExportFormat] = []
        if let pdf, !pdf.isEmpty { formats.append(.pdf) }
        if let csv, !csv.isEmpty { formats.append(.csv) }
        if let json, !json.isEmpty { formats.append(.json) }
        if let xml, !xml.isEmpty { formats.append(.xml) }
        return formats
    }

    private func decodeTimestamp(_ rawValue: String?) -> Date {
        guard let rawValue else { return Date() }
        if let timeInterval = TimeInterval(rawValue) {
            return Date(timeIntervalSince1970: timeInterval)
        }
        return ISO8601DateFormatter().date(from: rawValue) ?? Date()
    }
}

// MARK: - Supporting Types

/// Status of a report generation process
public enum ReportStatus: String, Codable, CaseIterable, Sendable {
    case pending = "pending"
    case generating = "generating"
    case completed = "completed"
    case failed = "failed"
}

/// Types of scheduled compliance reports
public enum ScheduledReportType: String, Codable, CaseIterable, Sendable {
    case dailySecurity = "daily_security"
    case weeklyActivity = "weekly_activity"
    case monthlyCompliance = "monthly_compliance"
    case quarterlyAudit = "quarterly_audit"
    case annualSummary = "annual_summary"
    
    func buildFilters() -> AuditReportFilters {
        let now = Date()
        let calendar = Calendar.current
        
        let dateRange: ClosedRange<Date>
        let eventTypes: [AuditEventType]?
        
        switch self {
        case .dailySecurity:
            dateRange = calendar.dateInterval(of: .day, for: now)!.range
            eventTypes = [.securityEvent, .governanceDecision]
        case .weeklyActivity:
            dateRange = calendar.dateInterval(of: .weekOfYear, for: now)!.range
            eventTypes = nil
        case .monthlyCompliance:
            dateRange = calendar.dateInterval(of: .month, for: now)!.range
            eventTypes = [.aiOperation, .documentAccess, .governanceDecision]
        case .quarterlyAudit:
            dateRange = calendar.dateInterval(of: .quarter, for: now)!.range
            eventTypes = nil
        case .annualSummary:
            dateRange = calendar.dateInterval(of: .year, for: now)!.range
            eventTypes = nil
        }
        
        return AuditReportFilters(
            dateRange: dateRange,
            eventTypes: eventTypes,
            includeMetadata: true,
            maxResults: 10000,
            sortBy: .timestamp,
            sortOrder: .descending
        )
    }
}

// MARK: - Export Protocol

/// Protocol for report exporters
public protocol ReportExporter {
    func export(events: [AuditEvent], summary: AuditReportSummary, to filePath: String) async throws
}

// MARK: - Default Exporters (Placeholder Implementations)

public class DefaultPDFReportExporter: PDFReportExporter {
    public init() {}
    
    public func export(events: [AuditEvent], summary: AuditReportSummary, to filePath: String) async throws {
        // Placeholder implementation - would integrate with PDF generation library
        fatalError("PDF export implementation needed")
    }
}

public class DefaultCSVReportExporter: CSVReportExporter {
    public init() {}
    
    public func export(events: [AuditEvent], summary: AuditReportSummary, to filePath: String) async throws {
        var csvContent = "ID,Timestamp,Event Type,User ID,Session ID,Principal,Operation Type,Resource ID,Resource Type,Action,Result,Compliance Flags\n"
        
        for event in events {
            let row = [
                event.id.uuidString,
                ISO8601DateFormatter().string(from: event.timestamp),
                event.eventType.rawValue,
                event.userId ?? "",
                event.sessionId ?? "",
                event.principal,
                event.operationType ?? "",
                event.resourceId ?? "",
                event.resourceType ?? "",
                event.action,
                event.result ?? "",
                event.complianceFlags.joined(separator: ";")
            ].map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
                .joined(separator: ",")
            
            csvContent += row + "\n"
        }
        
        try csvContent.write(toFile: filePath, atomically: true, encoding: .utf8)
    }
}

public class DefaultJSONReportExporter: JSONReportExporter {
    public init() {}
    
    public func export(events: [AuditEvent], summary: AuditReportSummary, to filePath: String) async throws {
        let reportData = [
            "summary": try JSONDecoder().decode([String: Any].self, from: JSONEncoder().encode(summary)),
            "events": events
        ] as [String : Any]
        
        let jsonData = try JSONSerialization.data(withJSONObject: reportData, options: .prettyPrinted)
        try jsonData.write(to: URL(fileURLWithPath: filePath))
    }
}

public class DefaultXMLReportExporter: XMLReportExporter {
    public init() {}
    
    public func export(events: [AuditEvent], summary: AuditReportSummary, to filePath: String) async throws {
        // Placeholder implementation - would integrate with XML generation
        fatalError("XML export implementation needed")
    }
}

// Type aliases for protocol conformance
public typealias PDFReportExporter = ReportExporter
public typealias CSVReportExporter = ReportExporter
public typealias JSONReportExporter = ReportExporter
public typealias XMLReportExporter = ReportExporter
