import Foundation
import ContractsCore
import AnigmaPrimitives
import DatabaseCore
import Hummingbird

// MARK: - Compliance Audit API Controller

/// REST API controller for compliance audit reports
public class ComplianceAuditAPIController {
    
    // MARK: - Properties
    
    private let reportService: AuditReportGenerationService
    private let auditService: AuditLoggingService
    private let authService: AuthenticationService
    private let rateLimiter: APIRateLimiter
    
    // MARK: - Initialization
    
    public init(
        reportService: AuditReportGenerationService,
        auditService: AuditLoggingService,
        authService: AuthenticationService,
        rateLimiter: APIRateLimiter = APIRateLimiter()
    ) {
        self.reportService = reportService
        self.auditService = auditService
        self.authService = authService
        self.rateLimiter = rateLimiter
    }
    
    // MARK: - Public Interface
    
    /// Register API routes
    public func registerRoutes(with router: Router) {
        // Report generation endpoints
        router.post("/api/v1/audit/reports", use: generateReport)
        router.get("/api/v1/audit/reports", use: listReports)
        router.get("/api/v1/audit/reports/:id", use: getReport)
        router.get("/api/v1/audit/reports/:id/download", use: downloadReport)
        router.delete("/api/v1/audit/reports/:id", use: deleteReport)
        
        // Scheduled report endpoints
        router.post("/api/v1/audit/reports/scheduled", use: createScheduledReport)
        router.get("/api/v1/audit/reports/scheduled", use: listScheduledReports)
        router.get("/api/v1/audit/reports/scheduled/:type", use: generateScheduledReport)
        
        // Analytics endpoints
        router.get("/api/v1/audit/analytics/summary", use: getAnalyticsSummary)
        router.get("/api/v1/audit/analytics/trends", use: getAnalyticsTrends)
        router.get("/api/v1/audit/analytics/compliance", use: getComplianceMetrics)
        
        // Configuration endpoints
        router.get("/api/v1/audit/config", use: getAuditConfiguration)
        router.put("/api/v1/audit/config", use: updateAuditConfiguration)
        
        // Health check endpoint
        router.get("/api/v1/audit/health", use: healthCheck)
    }
    
    // MARK: - Report Generation Endpoints
    
    /// Generate a new audit report
    /// POST /api/v1/audit/reports
    private func generateReport(
        request: Request,
        context: some RequestContext
    ) async throws -> Response {
        
        // Authenticate request
        let user = try await authService.authenticate(request: request)
        
        // Rate limiting
        try await rateLimiter.checkLimit(for: user.id, endpoint: "generate_report")
        
        // Parse request body
        let createRequest = try await request.decode(as: CreateReportRequest.self)
        
        // Validate filters
        try validateReportFilters(createRequest.filters)
        
        // Generate report
        let report = try await reportService.generateReport(
            filters: createRequest.filters,
            formats: createRequest.formats,
            requestedBy: user.id
        )
        
        // Log the report generation
        try await auditService.logEvent(AuditEvent(
            eventType: .userAction,
            userId: user.id,
            principal: user.id,
            action: "generate_audit_report",
            resourceId: report.id.uuidString,
            resourceType: "audit_report",
            result: "success",
            details: [
                "report_id": report.id.uuidString,
                "formats": createRequest.formats.map(\.rawValue).joined(separator: ","),
                "filters_count": String(createRequest.filters.eventTypes?.count ?? 0)
            ]
        ))
        
        let response = ReportGenerationResponse(
            reportId: report.id,
            status: .completed,
            generatedAt: report.generatedAt,
            expiresAt: Calendar.current.date(byAdding: .day, value: 30, to: report.generatedAt),
            downloadUrls: generateDownloadURLs(for: report.id, formats: createRequest.formats)
        )
        
        return try await response.encodeResponse(status: .created, for: request)
    }
    
    /// List available reports
    /// GET /api/v1/audit/reports
    private func listReports(
        request: Request,
        context: some RequestContext
    ) async throws -> Response {
        
        let user = try await authService.authenticate(request: request)
        
        // Parse query parameters
        let listRequest = try decodeListReportsRequest(from: request)
        
        // Fetch reports
        let reports = try await reportService.listReports(
            limit: listRequest.limit,
            offset: listRequest.offset,
            status: listRequest.status
        )
        
        // Filter reports based on user permissions
        let filteredReports = filterReportsForUser(reports, user: user)
        
        let response = ListReportsResponse(
            reports: filteredReports.map { ReportSummary(from: $0) },
            totalCount: filteredReports.count,
            hasMore: filteredReports.count == listRequest.limit
        )
        
        return try await response.encodeResponse(for: request)
    }
    
    /// Get a specific report
    /// GET /api/v1/audit/reports/:id
    private func getReport(
        request: Request,
        context: some RequestContext
    ) async throws -> Response {
        
        let user = try await authService.authenticate(request: request)
        
        // Extract report ID from URL
        guard let reportIdString = request.parameters.get("id"),
              let reportId = UUID(uuidString: reportIdString) else {
            throw APIError.invalidParameter("id")
        }
        
        // Fetch report
        guard let report = try await reportService.getReport(id: reportId) else {
            throw APIError.notFound("Report not found")
        }
        
        // Check user permissions
        guard canUserAccessReport(report, user: user) else {
            throw APIError.forbidden("Access denied")
        }
        
        let response = ReportDetail(from: report)
        return try await response.encodeResponse(for: request)
    }
    
    /// Download report files
    /// GET /api/v1/audit/reports/:id/download
    private func downloadReport(
        request: Request,
        context: some RequestContext
    ) async throws -> Response {
        
        let user = try await authService.authenticate(request: request)
        
        // Extract parameters
        guard let reportIdString = request.parameters.get("id"),
              let reportId = UUID(uuidString: reportIdString),
              let formatString = request.uri.queryParameters.get("format"),
              let format = ExportFormat(rawValue: formatString) else {
            throw APIError.invalidParameter("Invalid report ID or format")
        }
        
        // Fetch report
        guard let report = try await reportService.getReport(id: reportId) else {
            throw APIError.notFound("Report not found")
        }
        
        // Check permissions
        guard canUserAccessReport(report, user: user) else {
            throw APIError.forbidden("Access denied")
        }
        
        // Check if format is available
        guard report.exportFormats.contains(format) else {
            throw APIError.invalidParameter("Format not available for this report")
        }
        
        // Get file path and serve file
        let filePath = try getReportFilePath(reportId: reportId, format: format)
        
        // Log download
        try await auditService.logEvent(AuditEvent(
            eventType: .userAction,
            userId: user.id,
            principal: user.id,
            action: "download_audit_report",
            resourceId: reportId.uuidString,
            resourceType: "audit_report",
            result: "success",
            details: [
                "report_id": reportId.uuidString,
                "format": format.rawValue
            ]
        ))
        
        return try await serveFile(at: filePath, format: format, for: request)
    }
    
    /// Delete a report
    /// DELETE /api/v1/audit/reports/:id
    private func deleteReport(
        request: Request,
        context: some RequestContext
    ) async throws -> Response {
        
        let user = try await authService.authenticate(request: request)
        
        // Extract report ID
        guard let reportIdString = request.parameters.get("id"),
              let reportId = UUID(uuidString: reportIdString) else {
            throw APIError.invalidParameter("id")
        }
        
        // Fetch report
        guard let report = try await reportService.getReport(id: reportId) else {
            throw APIError.notFound("Report not found")
        }
        
        // Check if user can delete (admin or report owner)
        guard user.isAdmin || report.generatedBy == user.id else {
            throw APIError.forbidden("Only administrators or report owners can delete reports")
        }
        
        // Delete report files
        try await deleteReportFiles(reportId: reportId, formats: report.exportFormats)
        
        // Log deletion
        try await auditService.logEvent(AuditEvent(
            eventType: .userAction,
            userId: user.id,
            principal: user.id,
            action: "delete_audit_report",
            resourceId: reportId.uuidString,
            resourceType: "audit_report",
            result: "success",
            details: ["report_id": reportId.uuidString]
        ))
        
        return Response(status: .noContent)
    }
    
    // MARK: - Scheduled Reports Endpoints
    
    /// Create a scheduled report
    /// POST /api/v1/audit/reports/scheduled
    private func createScheduledReport(
        request: Request,
        context: some RequestContext
    ) async throws -> Response {
        
        let user = try await authService.authenticate(request: request)
        
        // Only admins can create scheduled reports
        guard user.isAdmin else {
            throw APIError.forbidden("Administrators only")
        }
        
        let createRequest = try await request.decode(as: CreateScheduledReportRequest.self)
        
        // Validate schedule
        try validateScheduledReportRequest(createRequest)
        
        // Create scheduled report configuration
        let scheduledReport = try await createScheduledReportConfiguration(
            request: createRequest,
            createdBy: user.id
        )
        
        let response = ScheduledReportResponse(from: scheduledReport)
        return try await response.encodeResponse(status: .created, for: request)
    }
    
    /// List scheduled reports
    /// GET /api/v1/audit/reports/scheduled
    private func listScheduledReports(
        request: Request,
        context: some RequestContext
    ) async throws -> Response {
        
        let user = try await authService.authenticate(request: request)
        
        let scheduledReports = try await fetchScheduledReports(for: user)
        let response = ListScheduledReportsResponse(scheduledReports: scheduledReports)
        
        return try await response.encodeResponse(for: request)
    }
    
    /// Generate scheduled report on demand
    /// GET /api/v1/audit/reports/scheduled/:type
    private func generateScheduledReport(
        request: Request,
        context: some RequestContext
    ) async throws -> Response {
        
        let user = try await authService.authenticate(request: request)
        
        // Extract report type
        guard let typeString = request.parameters.get("type"),
              let reportType = ScheduledReportType(rawValue: typeString) else {
            throw APIError.invalidParameter("type")
        }
        
        // Generate report
        let report = try await reportService.generateScheduledReport(
            type: reportType,
            requestedBy: user.id
        )
        
        let response = ReportGenerationResponse(
            reportId: report.id,
            status: .completed,
            generatedAt: report.generatedAt,
            expiresAt: Calendar.current.date(byAdding: .day, value: 30, to: report.generatedAt),
            downloadUrls: generateDownloadURLs(for: report.id, formats: report.exportFormats)
        )
        
        return try await response.encodeResponse(for: request)
    }
    
    // MARK: - Analytics Endpoints
    
    /// Get analytics summary
    /// GET /api/v1/audit/analytics/summary
    private func getAnalyticsSummary(
        request: Request,
        context: some RequestContext
    ) async throws -> Response {
        
        let user = try await authService.authenticate(request: request)
        
        // Parse date range from query parameters
        let dateRange = try parseDateRange(from: request)
        
        // Get summary statistics
        let filters = AuditReportFilters(dateRange: dateRange)
        let summary = try await auditService.getStatistics(filters: filters)
        
        let response = AnalyticsSummaryResponse(from: summary)
        return try await response.encodeResponse(for: request)
    }
    
    /// Get analytics trends
    /// GET /api/v1/audit/analytics/trends
    private func getAnalyticsTrends(
        request: Request,
        context: some RequestContext
    ) async throws -> Response {
        
        let user = try await authService.authenticate(request: request)
        
        // Parse trend parameters
        let trendRequest = try decodeTrendRequest(from: request)
        
        // Generate trend data
        let trendData = try await generateTrendData(request: trendRequest)
        
        let response = AnalyticsTrendsResponse(trends: trendData)
        return try await response.encodeResponse(for: request)
    }
    
    /// Get compliance metrics
    /// GET /api/v1/audit/analytics/compliance
    private func getComplianceMetrics(
        request: Request,
        context: some RequestContext
    ) async throws -> Response {
        
        let user = try await authService.authenticate(request: request)
        
        // Parse compliance request
        let complianceRequest = try decodeComplianceRequest(from: request)
        
        // Generate compliance metrics
        let metrics = try await generateComplianceMetrics(request: complianceRequest)
        
        let response = ComplianceMetricsResponse(metrics: metrics)
        return try await response.encodeResponse(for: request)
    }
    
    // MARK: - Configuration Endpoints
    
    /// Get audit configuration
    /// GET /api/v1/audit/config
    private func getAuditConfiguration(
        request: Request,
        context: some RequestContext
    ) async throws -> Response {
        
        let user = try await authService.authenticate(request: request)
        
        // Only admins can view configuration
        guard user.isAdmin else {
            throw APIError.forbidden("Administrators only")
        }
        
        let config = try await getAuditConfiguration()
        let response = AuditConfigurationResponse(from: config)
        
        return try await response.encodeResponse(for: request)
    }
    
    /// Update audit configuration
    /// PUT /api/v1/audit/config
    private func updateAuditConfiguration(
        request: Request,
        context: some RequestContext
    ) async throws -> Response {
        
        let user = try await authService.authenticate(request: request)
        
        // Only admins can update configuration
        guard user.isAdmin else {
            throw APIError.forbidden("Administrators only")
        }
        
        let updateRequest = try await request.decode(as: UpdateAuditConfigurationRequest.self)
        
        // Validate and update configuration
        let updatedConfig = try await updateAuditConfiguration(request: updateRequest)
        
        // Log configuration change
        try await auditService.logEvent(AuditEvent(
            eventType: .systemEvent,
            userId: user.id,
            principal: user.id,
            action: "update_audit_configuration",
            result: "success",
            details: ["updated_fields": updateRequest.changedFields.joined(separator: ",")]
        ))
        
        let response = AuditConfigurationResponse(from: updatedConfig)
        return try await response.encodeResponse(for: request)
    }
    
    // MARK: - Health Check
    
    /// Health check endpoint
    /// GET /api/v1/audit/health
    private func healthCheck(
        request: Request,
        context: some RequestContext
    ) async throws -> Response {
        
        let healthStatus = try await performHealthCheck()
        let response = HealthCheckResponse(from: healthStatus)
        
        return try await response.encodeResponse(for: request)
    }
    
    // MARK: - Private Helper Methods
    
    private func validateReportFilters(_ filters: AuditReportFilters) throws {
        // Validate date range is not too large (e.g., max 1 year)
        if let dateRange = filters.dateRange {
            let days = dateRange.upperBound.timeIntervalSince(dateRange.lowerBound) / 86400
            if days > 365 {
                throw APIError.invalidParameter("Date range cannot exceed 1 year")
            }
        }
        
        // Validate max results
        if let maxResults = filters.maxResults, maxResults > 10000 {
            throw APIError.invalidParameter("Maximum results cannot exceed 10,000")
        }
    }
    
    private func filterReportsForUser(_ reports: [AuditReport], user: User) -> [AuditReport] {
        // Admins can see all reports, users can only see their own
        if user.isAdmin {
            return reports
        }
        return reports.filter { $0.generatedBy == user.id }
    }
    
    private func canUserAccessReport(_ report: AuditReport, user: User) -> Bool {
        // Admins can access all reports, users can only access their own
        return user.isAdmin || report.generatedBy == user.id
    }
    
    private func generateDownloadURLs(for reportId: UUID, formats: [ExportFormat]) -> [ExportFormat: String] {
        var urls: [ExportFormat: String] = [:]
        let baseURL = "/api/v1/audit/reports/\(reportId.uuidString)/download"
        
        for format in formats {
            urls[format] = "\(baseURL)?format=\(format.rawValue)"
        }
        
        return urls
    }
    
    private func getReportFilePath(reportId: UUID, format: ExportFormat) throws -> String {
        // Implementation to get the actual file path
        // This would depend on where reports are stored
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let reportsPath = documentsPath.appendingPathComponent("audit_reports")
        let fileName = "audit_report_\(reportId.uuidString).\(format.rawValue)"
        return reportsPath.appendingPathComponent(fileName).path
    }
    
    private func deleteReportFiles(reportId: UUID, formats: [ExportFormat]) async throws {
        for format in formats {
            let filePath = try getReportFilePath(reportId: reportId, format: format)
            try? FileManager.default.removeItem(atPath: filePath)
        }
    }
    
    private func serveFile(at filePath: String, format: ExportFormat, for request: Request) async throws -> Response {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw APIError.notFound("Report file not found")
        }
        
        let fileURL = URL(fileURLWithPath: filePath)
        let fileData = try Data(contentsOf: fileURL)
        
        let contentType: String
        switch format {
        case .pdf:
            contentType = "application/pdf"
        case .csv:
            contentType = "text/csv"
        case .json:
            contentType = "application/json"
        case .xml:
            contentType = "application/xml"
        }
        
        var headers: HTTPField.NameIndex = [:]
        headers[.contentType] = contentType
        headers[.contentDisposition] = "attachment; filename=\"\(fileURL.lastPathComponent)\""
        
        return Response(status: .ok, headers: HTTPFields(headers), body: .data(fileData))
    }
    
    // Additional private methods for validation, data generation, etc.
    // These would include implementations for the remaining functionality
}

// MARK: - Supporting Types

// Request/Response structures would go here
// Authentication service interface
// Rate limiting service interface
// Error handling types
// etc.