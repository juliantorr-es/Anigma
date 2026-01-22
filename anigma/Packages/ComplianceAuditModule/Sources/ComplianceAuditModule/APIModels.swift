import Foundation
import ContractsCore
import AnigmaPrimitives

// MARK: - API Request Models

/// Request to generate a new audit report
public struct CreateReportRequest: Codable, Sendable {
    public let filters: AuditReportFilters
    public let formats: [ExportFormat]
    public let title: String?
    public let description: String?
    public let notifyOnCompletion: Bool
    public let notificationEmails: [String]
    
    public init(
        filters: AuditReportFilters,
        formats: [ExportFormat] = [.pdf, .csv],
        title: String? = nil,
        description: String? = nil,
        notifyOnCompletion: Bool = false,
        notificationEmails: [String] = []
    ) {
        self.filters = filters
        self.formats = formats
        self.title = title
        self.description = description
        self.notifyOnCompletion = notifyOnCompletion
        self.notificationEmails = notificationEmails
    }
}

/// Request to list reports with pagination and filtering
public struct ListReportsRequest: Codable, Sendable {
    public let limit: Int
    public let offset: Int
    public let status: ReportStatus?
    public let sortBy: ReportSortField
    public let sortOrder: SortOrder
    public let dateFrom: Date?
    public let dateTo: Date?
    public let userId: String?
    
    public init(
        limit: Int = 50,
        offset: Int = 0,
        status: ReportStatus? = nil,
        sortBy: ReportSortField = .generatedAt,
        sortOrder: SortOrder = .descending,
        dateFrom: Date? = nil,
        dateTo: Date? = nil,
        userId: String? = nil
    ) {
        self.limit = min(limit, 100) // Max 100 per page
        self.offset = offset
        self.status = status
        self.sortBy = sortBy
        self.sortOrder = sortOrder
        self.dateFrom = dateFrom
        self.dateTo = dateTo
        self.userId = userId
    }
}

/// Request to create a scheduled report
public struct CreateScheduledReportRequest: Codable, Sendable {
    public let name: String
    public let description: String?
    public let reportType: ScheduledReportType
    public let schedule: ReportSchedule
    public let formats: [ExportFormat]
    public let recipients: [String]
    public let enabled: Bool
    public let retentionDays: Int?
    
    public init(
        name: String,
        description: String? = nil,
        reportType: ScheduledReportType,
        schedule: ReportSchedule,
        formats: [ExportFormat] = [.pdf, .csv],
        recipients: [String] = [],
        enabled: Bool = true,
        retentionDays: Int? = nil
    ) {
        self.name = name
        self.description = description
        self.reportType = reportType
        self.schedule = schedule
        self.formats = formats
        self.recipients = recipients
        self.enabled = enabled
        self.retentionDays = retentionDays
    }
}

/// Request for analytics trends
public struct AnalyticsTrendRequest: Codable, Sendable {
    public let metricType: TrendMetricType
    public let dateRange: ClosedRange<Date>
    public let interval: TrendInterval
    public let eventType: AuditEventType?
    public let operationType: String?
    
    public init(
        metricType: TrendMetricType,
        dateRange: ClosedRange<Date>,
        interval: TrendInterval,
        eventType: AuditEventType? = nil,
        operationType: String? = nil
    ) {
        self.metricType = metricType
        self.dateRange = dateRange
        self.interval = interval
        self.eventType = eventType
        self.operationType = operationType
    }
}

/// Request for compliance metrics
public struct ComplianceMetricsRequest: Codable, Sendable {
    public let dateRange: ClosedRange<Date>
    public let includeDetails: Bool
    public let complianceFlags: [String]?
    public let eventTypes: [AuditEventType]?
    
    public init(
        dateRange: ClosedRange<Date>,
        includeDetails: Bool = false,
        complianceFlags: [String]? = nil,
        eventTypes: [AuditEventType]? = nil
    ) {
        self.dateRange = dateRange
        self.includeDetails = includeDetails
        self.complianceFlags = complianceFlags
        self.eventTypes = eventTypes
    }
}

/// Request to update audit configuration
public struct UpdateAuditConfigurationRequest: Codable, Sendable {
    public let enabled: Bool?
    public let defaultRetentionDays: Int?
    public let bufferSize: Int?
    public let flushIntervalSeconds: TimeInterval?
    public let requiredComplianceFlags: [String]?
    public let excludedEventTypes: [AuditEventType]?
    public let piiDetectionEnabled: Bool?
    public let encryptionEnabled: Bool?
    
    public init(
        enabled: Bool? = nil,
        defaultRetentionDays: Int? = nil,
        bufferSize: Int? = nil,
        flushIntervalSeconds: TimeInterval? = nil,
        requiredComplianceFlags: [String]? = nil,
        excludedEventTypes: [AuditEventType]? = nil,
        piiDetectionEnabled: Bool? = nil,
        encryptionEnabled: Bool? = nil
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
    
    /// Fields that were actually changed in the request
    public var changedFields: [String] {
        var fields: [String] = []
        
        if enabled != nil { fields.append("enabled") }
        if defaultRetentionDays != nil { fields.append("defaultRetentionDays") }
        if bufferSize != nil { fields.append("bufferSize") }
        if flushIntervalSeconds != nil { fields.append("flushIntervalSeconds") }
        if requiredComplianceFlags != nil { fields.append("requiredComplianceFlags") }
        if excludedEventTypes != nil { fields.append("excludedEventTypes") }
        if piiDetectionEnabled != nil { fields.append("piiDetectionEnabled") }
        if encryptionEnabled != nil { fields.append("encryptionEnabled") }
        
        return fields
    }
}

// MARK: - API Response Models

/// Response for report generation
public struct ReportGenerationResponse: Codable, Sendable {
    public let reportId: UUID
    public let status: ReportStatus
    public let generatedAt: Date
    public let expiresAt: Date?
    public let downloadUrls: [ExportFormat: String]
    public let estimatedSize: String?
    public let estimatedTime: TimeInterval?
    
    public init(
        reportId: UUID,
        status: ReportStatus,
        generatedAt: Date,
        expiresAt: Date? = nil,
        downloadUrls: [ExportFormat: String] = [:],
        estimatedSize: String? = nil,
        estimatedTime: TimeInterval? = nil
    ) {
        self.reportId = reportId
        self.status = status
        self.generatedAt = generatedAt
        self.expiresAt = expiresAt
        self.downloadUrls = downloadUrls
        self.estimatedSize = estimatedSize
        self.estimatedTime = estimatedTime
    }
}

/// Response for listing reports
public struct ListReportsResponse: Codable, Sendable {
    public let reports: [ReportSummary]
    public let totalCount: Int
    public let hasMore: Bool
    public let pageInfo: PageInfo
    
    public init(reports: [ReportSummary], totalCount: Int, hasMore: Bool) {
        self.reports = reports
        self.totalCount = totalCount
        self.hasMore = hasMore
        self.pageInfo = PageInfo(
            currentPage: totalCount > 0 ? (reports.count + 49) / 50 : 1,
            totalItems: totalCount,
            itemsPerPage: min(50, totalCount)
        )
    }
}

/// Summary information for a report
public struct ReportSummary: Codable, Sendable {
    public let id: UUID
    public let title: String
    public let generatedAt: Date
    public let generatedBy: String
    public let status: ReportStatus
    public let eventCount: Int
    public let dateRange: ClosedRange<Date>
    public let formats: [ExportFormat]
    public let size: Int64?
    public let expiresAt: Date?
    
    public init(from report: AuditReport) {
        self.id = report.id
        self.title = "Compliance Audit Report"
        self.generatedAt = report.generatedAt
        self.generatedBy = report.generatedBy
        self.status = .completed // Would be stored with report
        self.eventCount = report.events.count
        self.dateRange = report.summary.dateRange
        self.formats = report.exportFormats
        self.size = nil // Would be calculated
        self.expiresAt = Calendar.current.date(byAdding: .day, value: 30, to: report.generatedAt)
    }
}

/// Detailed report information
public struct ReportDetail: Codable, Sendable {
    public let id: UUID
    public let title: String
    public let description: String?
    public let generatedAt: Date
    public let generatedBy: String
    public let status: ReportStatus
    public let filters: AuditReportFilters
    public let summary: ReportSummaryInfo
    public let downloadUrls: [ExportFormat: String]
    public let fileSizes: [ExportFormat: Int64]
    public let expiresAt: Date?
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(from report: AuditReport) {
        self.id = report.id
        self.title = "Compliance Audit Report"
        self.description = nil
        self.generatedAt = report.generatedAt
        self.generatedBy = report.generatedBy
        self.status = .completed
        self.filters = report.filters
        self.summary = ReportSummaryInfo(from: report.summary)
        self.downloadUrls = [:] // Would be generated
        self.fileSizes = [:] // Would be calculated
        self.expiresAt = Calendar.current.date(byAdding: .day, value: 30, to: report.generatedAt)
        self.createdAt = report.generatedAt
        self.updatedAt = report.generatedAt
    }
}

/// Summary information for report details
public struct ReportSummaryInfo: Codable, Sendable {
    public let totalEvents: Int
    public let dateRange: ClosedRange<Date>
    public let uniqueUsers: Int
    public let uniqueSessions: Int
    public let eventCounts: [String: Int]
    public let operationCounts: [String: Int]
    public let userActivity: [String: Int]
    public let complianceFlagCounts: [String: Int]
    public let failureRate: Double
    public let averageResponseTime: Double?
    public let totalCost: Decimal?
    
    public init(from summary: AuditReportSummary) {
        self.totalEvents = summary.totalEvents
        self.dateRange = summary.dateRange
        self.uniqueUsers = summary.uniqueUsers
        self.uniqueSessions = summary.uniqueSessions
        self.eventCounts = summary.eventCounts.mapKeys { $0.rawValue }
        self.operationCounts = summary.operationCounts
        self.userActivity = summary.userActivity
        self.complianceFlagCounts = summary.complianceFlagCounts
        self.failureRate = summary.failureRate
        self.averageResponseTime = summary.averageResponseTime
        self.totalCost = summary.totalCost
    }
}

/// Response for scheduled reports
public struct ScheduledReportResponse: Codable, Sendable {
    public let id: UUID
    public let name: String
    public let description: String?
    public let reportType: ScheduledReportType
    public let schedule: ReportSchedule
    public let formats: [ExportFormat]
    public let recipients: [String]
    public let enabled: Bool
    public let lastRun: Date?
    public let nextRun: Date?
    public let runCount: Int
    public let createdBy: String
    public let createdAt: Date
    
    public init(from scheduledReport: ScheduledReportConfiguration) {
        self.id = scheduledReport.id
        self.name = scheduledReport.name
        self.description = scheduledReport.description
        self.reportType = scheduledReport.reportType
        self.schedule = scheduledReport.schedule
        self.formats = scheduledReport.formats
        self.recipients = scheduledReport.recipients
        self.enabled = scheduledReport.enabled
        self.lastRun = scheduledReport.lastRun
        self.nextRun = scheduledReport.nextRun
        self.runCount = scheduledReport.runCount
        self.createdBy = scheduledReport.createdBy
        self.createdAt = scheduledReport.createdAt
    }
}

/// Response for listing scheduled reports
public struct ListScheduledReportsResponse: Codable, Sendable {
    public let scheduledReports: [ScheduledReportResponse]
    public let totalCount: Int
    
    public init(scheduledReports: [ScheduledReportResponse]) {
        self.scheduledReports = scheduledReports
        self.totalCount = scheduledReports.count
    }
}

/// Response for analytics summary
public struct AnalyticsSummaryResponse: Codable, Sendable {
    public let summary: ReportSummaryInfo
    public let period: ClosedRange<Date>
    public let trends: [TrendSummary]
    public let topMetrics: [MetricSummary]
    
    public init(from summary: AuditReportSummary) {
        self.summary = ReportSummaryInfo(from: summary)
        self.period = summary.dateRange
        self.trends = [] // Would be calculated
        self.topMetrics = [] // Would be calculated
    }
}

/// Response for analytics trends
public struct AnalyticsTrendsResponse: Codable, Sendable {
    public let trends: [TrendDataPoint]
    public let metadata: TrendMetadata
    
    public init(trends: [TrendDataPoint]) {
        self.trends = trends
        self.metadata = TrendMetadata(
            totalPoints: trends.count,
            startDate: trends.first?.timestamp ?? Date(),
            endDate: trends.last?.timestamp ?? Date(),
            interval: .daily
        )
    }
}

/// Response for compliance metrics
public struct ComplianceMetricsResponse: Codable, Sendable {
    public let metrics: ComplianceMetricsData
    public let period: ClosedRange<Date>
    public let complianceScore: Double
    public let violations: [ComplianceViolation]
    public let recommendations: [ComplianceRecommendation]
    
    public init(metrics: ComplianceMetricsData) {
        self.metrics = metrics
        self.period = metrics.period
        self.complianceScore = metrics.calculateComplianceScore()
        self.violations = metrics.violations
        self.recommendations = metrics.generateRecommendations()
    }
}

/// Response for audit configuration
public struct AuditConfigurationResponse: Codable, Sendable {
    public let configuration: AuditConfigurationData
    public let lastModified: Date
    public let modifiedBy: String
    public let version: String
    
    public init(from config: AuditConfigurationData) {
        self.configuration = config
        self.lastModified = config.lastModified
        self.modifiedBy = config.modifiedBy
        self.version = config.version
    }
}

/// Response for health check
public struct HealthCheckResponse: Codable, Sendable {
    public let status: HealthStatus
    public let timestamp: Date
    public let version: String
    public let uptime: TimeInterval
    public let components: [ComponentHealth]
    public let metrics: HealthMetrics
    
    public init(from health: SystemHealth) {
        self.status = health.overallStatus
        self.timestamp = health.timestamp
        self.version = health.version
        self.uptime = health.uptime
        self.components = health.components
        self.metrics = health.metrics
    }
}

// MARK: - Supporting Types

/// Pagination information
public struct PageInfo: Codable, Sendable {
    public let currentPage: Int
    public let totalItems: Int
    public let itemsPerPage: Int
    public let totalPages: Int
    
    public init(currentPage: Int, totalItems: Int, itemsPerPage: Int) {
        self.currentPage = currentPage
        self.totalItems = totalItems
        self.itemsPerPage = itemsPerPage
        self.totalPages = (totalItems + itemsPerPage - 1) / itemsPerPage
    }
}

/// Report schedule configuration
public struct ReportSchedule: Codable, Sendable {
    public let frequency: ScheduleFrequency
    public let timeZone: String
    public let hour: Int
    public let minute: Int
    public let dayOfWeek: Int? // For weekly schedules
    public let dayOfMonth: Int? // For monthly schedules
    public let enabled: Bool
    
    public init(
        frequency: ScheduleFrequency,
        timeZone: String = "UTC",
        hour: Int = 9,
        minute: Int = 0,
        dayOfWeek: Int? = nil,
        dayOfMonth: Int? = nil,
        enabled: Bool = true
    ) {
        self.frequency = frequency
        self.timeZone = timeZone
        self.hour = hour
        self.minute = minute
        self.dayOfWeek = dayOfWeek
        self.dayOfMonth = dayOfMonth
        self.enabled = enabled
    }
}

/// Schedule frequency
public enum ScheduleFrequency: String, Codable, CaseIterable, Sendable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
}

/// Report sort fields
public enum ReportSortField: String, Codable, CaseIterable, Sendable {
    case generatedAt = "generated_at"
    case title = "title"
    case generatedBy = "generated_by"
    case status = "status"
    case eventCount = "event_count"
}

/// Trend metric types
public enum TrendMetricType: String, Codable, CaseIterable, Sendable {
    case eventCount = "event_count"
    case userActivity = "user_activity"
    case failureRate = "failure_rate"
    case responseTime = "response_time"
    case cost = "cost"
    case complianceScore = "compliance_score"
}

/// Trend intervals
public enum TrendInterval: String, Codable, CaseIterable, Sendable {
    case hourly = "hourly"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
}

/// Trend data point
public struct TrendDataPoint: Codable, Sendable {
    public let timestamp: Date
    public let value: Double
    public let metadata: [String: String]?
    
    public init(timestamp: Date, value: Double, metadata: [String: String]? = nil) {
        self.timestamp = timestamp
        self.value = value
        self.metadata = metadata
    }
}

/// Trend metadata
public struct TrendMetadata: Codable, Sendable {
    public let totalPoints: Int
    public let startDate: Date
    public let endDate: Date
    public let interval: TrendInterval
    
    public init(totalPoints: Int, startDate: Date, endDate: Date, interval: TrendInterval) {
        self.totalPoints = totalPoints
        self.startDate = startDate
        self.endDate = endDate
        self.interval = interval
    }
}

/// Trend summary
public struct TrendSummary: Codable, Sendable {
    public let metric: String
    public let change: Double
    public let changePercent: Double
    public let trend: TrendDirection
    
    public init(metric: String, change: Double, changePercent: Double, trend: TrendDirection) {
        self.metric = metric
        self.change = change
        self.changePercent = changePercent
        self.trend = trend
    }
}

/// Trend direction
public enum TrendDirection: String, Codable, CaseIterable, Sendable {
    case up = "up"
    case down = "down"
    case stable = "stable"
}

/// Metric summary
public struct MetricSummary: Codable, Sendable {
    public let name: String
    public let value: String
    public let description: String
    
    public init(name: String, value: String, description: String) {
        self.name = name
        self.value = value
        self.description = description
    }
}

/// Health status
public enum HealthStatus: String, Codable, CaseIterable, Sendable {
    case healthy = "healthy"
    case degraded = "degraded"
    case unhealthy = "unhealthy"
}

/// Component health
public struct ComponentHealth: Codable, Sendable {
    public let name: String
    public let status: HealthStatus
    public let message: String?
    public let responseTime: TimeInterval?
    public let lastCheck: Date
    
    public init(name: String, status: HealthStatus, message: String? = nil, responseTime: TimeInterval? = nil, lastCheck: Date = Date()) {
        self.name = name
        self.status = status
        self.message = message
        self.responseTime = responseTime
        self.lastCheck = lastCheck
    }
}

/// Health metrics
public struct HealthMetrics: Codable, Sendable {
    public let cpuUsage: Double
    public let memoryUsage: Double
    public let diskUsage: Double
    public let activeConnections: Int
    public let queuedJobs: Int
    
    public init(cpuUsage: Double, memoryUsage: Double, diskUsage: Double, activeConnections: Int, queuedJobs: Int) {
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.diskUsage = diskUsage
        self.activeConnections = activeConnections
        self.queuedJobs = queuedJobs
    }
}

// Additional supporting types would be defined here
// Including: ScheduledReportConfiguration, ComplianceMetricsData, etc.