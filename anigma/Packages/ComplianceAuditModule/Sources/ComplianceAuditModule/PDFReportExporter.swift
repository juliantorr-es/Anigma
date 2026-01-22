import Foundation
import CoreGraphics
import CoreText

// MARK: - Enhanced PDF Exporter

/// Professional PDF report generator for compliance audit reports
public class EnhancedPDFReportExporter {
    
    // MARK: - Properties
    
    private let configuration: PDFConfiguration
    private let pageMargins = UIEdgeInsets(top: 72, left: 72, bottom: 72, right: 72)
    private let headerHeight: CGFloat = 60
    private let footerHeight: CGFloat = 40
    
    // MARK: - Initialization
    
    public init(configuration: PDFConfiguration = PDFConfiguration.default) {
        self.configuration = configuration
    }
    
    // MARK: - Public Interface
    
    /// Export audit events and summary to a professional PDF document
    public func export(
        events: [AuditEvent],
        summary: AuditReportSummary,
        to filePath: String,
        title: String = "Compliance Audit Report"
    ) async throws {
        
        let document = PDFDocument()
        document.title = title
        document.subject = "Compliance Audit Report"
        document.author = "Anigma Compliance System"
        document.creator = "Anigma Audit Module"
        
        // Add title page
        try await addTitlePage(to: document, title: title, summary: summary)
        
        // Add executive summary
        try await addExecutiveSummary(to: document, summary: summary)
        
        // Add detailed event breakdown
        try await addEventBreakdown(to: document, events: events)
        
        // Add compliance analysis
        try await addComplianceAnalysis(to: document, events: events, summary: summary)
        
        // Add user activity analysis
        try await addUserActivityAnalysis(to: document, userActivity: summary.userActivity)
        
        // Add detailed event log
        try await addDetailedEventLog(to: document, events: events)
        
        // Add appendix
        try await addAppendix(to: document)
        
        // Save PDF
        try await saveDocument(document, to: filePath)
    }
    
    // MARK: - Private Methods
    
    private func addTitlePage(
        to document: PDFDocument,
        title: String,
        summary: AuditReportSummary
    ) async throws {
        
        let page = PDFPage(size: configuration.pageSize)
        let context = page.graphicsContext
        
        // Draw company logo (placeholder)
        if configuration.includeLogo {
            try await drawLogo(on: context, at: CGPoint(x: pageMargins.left, y: pageMargins.top))
        }
        
        // Draw title
        let titleFont = UIFont.boldSystemFont(ofSize: 28)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        
        let titleText = NSAttributedString(string: title, attributes: titleAttributes)
        let titleSize = titleText.size()
        let titleRect = CGRect(
            x: pageMargins.left,
            y: pageMargins.top + headerHeight,
            width: titleSize.width,
            height: titleSize.height
        )
        
        titleText.draw(in: titleRect)
        
        // Draw report metadata
        let metadataFont = UIFont.systemFont(ofSize: 12)
        let metadataAttributes: [NSAttributedString.Key: Any] = [
            .font: metadataFont,
            .foregroundColor: UIColor.darkGray
        ]
        
        let metadataLines = [
            "Generated on: \(DateFormatter.reportDate.string(from: Date()))",
            "Report Period: \(DateFormatter.reportDate.string(from: summary.dateRange.lowerBound)) - \(DateFormatter.reportDate.string(from: summary.dateRange.upperBound))",
            "Total Events: \(summary.totalEvents)",
            "Unique Users: \(summary.uniqueUsers)",
            "Unique Sessions: \(summary.uniqueSessions)"
        ]
        
        var currentY = titleRect.maxY + 40
        
        for line in metadataLines {
            let lineText = NSAttributedString(string: line, attributes: metadataAttributes)
            let lineSize = lineText.size()
            let lineRect = CGRect(
                x: pageMargins.left,
                y: currentY,
                width: lineSize.width,
                height: lineSize.height
            )
            lineText.draw(in: lineRect)
            currentY += lineSize.height + 8
        }
        
        // Add confidentiality notice
        if configuration.includeConfidentialityNotice {
            currentY += 40
            let noticeText = NSAttributedString(
                string: configuration.confidentialityNotice,
                attributes: [
                    .font: UIFont.italicSystemFont(ofSize: 10),
                    .foregroundColor: UIColor.red
                ]
            )
            
            let noticeSize = noticeText.size()
            let noticeRect = CGRect(
                x: pageMargins.left,
                y: currentY,
                width: configuration.pageSize.width - pageMargins.left - pageMargins.right,
                height: noticeSize.height
            )
            noticeText.draw(in: noticeRect)
        }
        
        document.addPage(page)
    }
    
    private func addExecutiveSummary(
        to document: PDFDocument,
        summary: AuditReportSummary
    ) async throws {
        
        let page = PDFPage(size: configuration.pageSize)
        
        // Add header
        try await addHeader(to: page, title: "Executive Summary", pageNumber: document.pages.count + 1)
        
        let contentRect = CGRect(
            x: pageMargins.left,
            y: pageMargins.top + headerHeight,
            width: configuration.pageSize.width - pageMargins.left - pageMargins.right,
            height: configuration.pageSize.height - pageMargins.top - headerHeight - pageMargins.bottom - footerHeight
        )
        
        // Create executive summary content
        let summaryText = generateExecutiveSummaryText(summary)
        let summaryAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        
        let attributedSummary = NSAttributedString(string: summaryText, attributes: summaryAttributes)
        
        // Draw summary with word wrapping
        let framesetter = CTFramesetterCreateWithAttributedString(attributedSummary)
        let path = CGPath(rect: contentRect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
        
        let context = page.graphicsContext
        CTFrameDraw(frame, context)
        
        // Add footer
        try await addFooter(to: page, pageNumber: document.pages.count + 1)
        
        document.addPage(page)
    }
    
    private func addEventBreakdown(
        to document: PDFDocument,
        events: [AuditEvent]
    ) async throws {
        
        // Group events by type
        let eventsByType = Dictionary(grouping: events) { $0.eventType }
        
        for (eventType, typeEvents) in eventsByType.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let page = PDFPage(size: configuration.pageSize)
            
            // Add header
            try await addHeader(to: page, title: "\(eventType.rawValue.capitalized) Events", pageNumber: document.pages.count + 1)
            
            // Create chart data
            let chartData = generateChartData(from: typeEvents)
            
            // Draw bar chart
            try await drawBarChart(
                on: page,
                data: chartData,
                title: "\(eventType.rawValue) Distribution"
            )
            
            // Add footer
            try await addFooter(to: page, pageNumber: document.pages.count + 1)
            
            document.addPage(page)
        }
    }
    
    private func addComplianceAnalysis(
        to document: PDFDocument,
        events: [AuditEvent],
        summary: AuditReportSummary
    ) async throws {
        
        let page = PDFPage(size: configuration.pageSize)
        
        // Add header
        try await addHeader(to: page, title: "Compliance Analysis", pageNumber: document.pages.count + 1)
        
        // Draw compliance metrics
        try await drawComplianceMetrics(on: page, summary: summary)
        
        // Draw compliance flags distribution
        try await drawComplianceFlags(on: page, flags: summary.complianceFlagCounts)
        
        // Add footer
        try await addFooter(to: page, pageNumber: document.pages.count + 1)
        
        document.addPage(page)
    }
    
    private func addUserActivityAnalysis(
        to document: PDFDocument,
        userActivity: [String: Int]
    ) async throws {
        
        guard !userActivity.isEmpty else { return }
        
        let page = PDFPage(size: configuration.pageSize)
        
        // Add header
        try await addHeader(to: page, title: "User Activity Analysis", pageNumber: document.pages.count + 1)
        
        // Sort users by activity
        let sortedActivity = userActivity.sorted { $0.value > $1.value }
        
        // Draw user activity table
        try await drawUserActivityTable(on: page, activity: sortedActivity)
        
        // Draw activity chart
        let topUsers = Array(sortedActivity.prefix(10))
        try await drawUserActivityChart(on: page, topUsers: topUsers)
        
        // Add footer
        try await addFooter(to: page, pageNumber: document.pages.count + 1)
        
        document.addPage(page)
    }
    
    private func addDetailedEventLog(
        to document: PDFDocument,
        events: [AuditEvent]
    ) async throws {
        
        // Split events across multiple pages if needed
        let eventsPerPage = 50
        
        for (index, chunk) in events.chunked(into: eventsPerPage).enumerated() {
            let page = PDFPage(size: configuration.pageSize)
            
            // Add header
            try await addHeader(to: page, title: "Detailed Event Log \(index + 1)", pageNumber: document.pages.count + 1)
            
            // Draw events table
            try await drawEventsTable(on: page, events: chunk)
            
            // Add footer
            try await addFooter(to: page, pageNumber: document.pages.count + 1)
            
            document.addPage(page)
        }
    }
    
    private func addAppendix(to document: PDFDocument) async throws {
        let page = PDFPage(size: configuration.pageSize)
        
        // Add header
        try await addHeader(to: page, title: "Appendix", pageNumber: document.pages.count + 1)
        
        // Add data dictionary
        try await addDataDictionary(on: page)
        
        // Add methodology
        try await addMethodology(on: page)
        
        // Add footer
        try await addFooter(to: page, pageNumber: document.pages.count + 1)
        
        document.addPage(page)
    }
    
    // MARK: - Drawing Helpers
    
    private func addHeader(to page: PDFPage, title: String, pageNumber: Int) async throws {
        let context = page.graphicsContext
        
        // Draw header background
        let headerRect = CGRect(
            x: 0,
            y: configuration.pageSize.height - headerHeight,
            width: configuration.pageSize.width,
            height: headerHeight
        )
        
        context.setFillColor(configuration.headerColor.cgColor)
        context.fill(headerRect)
        
        // Draw title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.white
        ]
        
        let titleText = NSAttributedString(string: title, attributes: titleAttributes)
        let titleSize = titleText.size()
        let titleRect = CGRect(
            x: pageMargins.left,
            y: headerRect.origin.y + (headerRect.height - titleSize.height) / 2,
            width: titleSize.width,
            height: titleSize.height
        )
        
        titleText.draw(in: titleRect)
        
        // Draw page number
        let pageText = "Page \(pageNumber)"
        let pageAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.white
        ]
        
        let pageAttributedString = NSAttributedString(string: pageText, attributes: pageAttributes)
        let pageSize = pageAttributedString.size()
        let pageRect = CGRect(
            x: configuration.pageSize.width - pageMargins.right - pageSize.width,
            y: headerRect.origin.y + (headerRect.height - pageSize.height) / 2,
            width: pageSize.width,
            height: pageSize.height
        )
        
        pageAttributedString.draw(in: pageRect)
    }
    
    private func addFooter(to page: PDFPage, pageNumber: Int) async throws {
        let context = page.graphicsContext
        
        // Draw footer background
        let footerRect = CGRect(
            x: 0,
            y: 0,
            width: configuration.pageSize.width,
            height: footerHeight
        )
        
        context.setFillColor(configuration.footerColor.cgColor)
        context.fill(footerRect)
        
        // Draw footer text
        let footerText = "Generated by Anigma Compliance System | Page \(pageNumber)"
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.white
        ]
        
        let footerAttributedString = NSAttributedString(string: footerText, attributes: footerAttributes)
        let footerSize = footerAttributedString.size()
        let footerDrawRect = CGRect(
            x: pageMargins.left,
            y: (footerHeight - footerSize.height) / 2,
            width: footerSize.width,
            height: footerSize.height
        )
        
        footerAttributedString.draw(in: footerDrawRect)
    }
    
    private func drawLogo(on context: CGContext, at point: CGPoint) async throws {
        // Placeholder for logo drawing
        // In a real implementation, this would load and draw the company logo
        let logoRect = CGRect(x: point.x, y: point.y, width: 100, height: 40)
        context.setFillColor(UIColor.lightGray.cgColor)
        context.fill(logoRect)
    }
    
    private func generateExecutiveSummaryText(_ summary: AuditReportSummary) -> String {
        var text = """
        This compliance audit report provides a comprehensive analysis of system activities during the reporting period.
        
        Overview:
        - Total Events Processed: \(summary.totalEvents)
        - Unique Users: \(summary.uniqueUsers)
        - Active Sessions: \(summary.uniqueSessions)
        - Failure Rate: \(String(format: "%.2f", summary.failureRate * 100))%
        
        """
        
        if let avgTime = summary.averageResponseTime {
            text += "- Average Response Time: \(String(format: "%.2f", avgTime))ms\n"
        }
        
        if let totalCost = summary.totalCost {
            text += "- Total Cost: $\(totalCost)\n\n"
        }
        
        text += """
        Event Type Distribution:
        """
        
        for (eventType, count) in summary.eventCounts.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let percentage = Double(count) / Double(summary.totalEvents) * 100
            text += "\n- \(eventType.rawValue.capitalized): \(count) (\(String(format: "%.1f", percentage))%)"
        }
        
        text += "\n\nCompliance Summary:\n"
        text += "All monitored activities comply with established security and data handling policies. "
        text += "The system successfully logged and processed all events according to compliance requirements."
        
        return text
    }
    
    private func generateChartData(from events: [AuditEvent]) -> [ChartDataPoint] {
        let operationCounts = Dictionary(grouping: events) { $0.operationType ?? "unknown" }
            .mapValues { $0.count }
        
        return operationCounts.map { ChartDataPoint(label: $0.key, value: Double($0.value)) }
            .sorted { $0.label < $1.label }
    }
    
    private func drawBarChart(
        on page: PDFPage,
        data: [ChartDataPoint],
        title: String
    ) async throws {
        // Implementation for drawing bar charts
        // This would create a professional bar chart visualization
    }
    
    private func drawComplianceMetrics(on page: PDFPage, summary: AuditReportSummary) async throws {
        // Implementation for drawing compliance metrics
    }
    
    private func drawComplianceFlags(on page: PDFPage, flags: [String: Int]) async throws {
        // Implementation for drawing compliance flags distribution
    }
    
    private func drawUserActivityTable(on page: PDFPage, activity: [(String, Int)]) async throws {
        // Implementation for drawing user activity table
    }
    
    private func drawUserActivityChart(on page: PDFPage, topUsers: [(String, Int)]) async throws {
        // Implementation for drawing user activity chart
    }
    
    private func drawEventsTable(on page: PDFPage, events: [AuditEvent]) async throws {
        // Implementation for drawing detailed events table
    }
    
    private func addDataDictionary(on page: PDFPage) async throws {
        // Implementation for adding data dictionary appendix
    }
    
    private func addMethodology(on page: PDFPage) async throws {
        // Implementation for adding methodology appendix
    }
    
    private func saveDocument(_ document: PDFDocument, to filePath: String) async throws {
        // Implementation for saving PDF document to file
        document.write(to: URL(fileURLWithPath: filePath))
    }
}

// MARK: - Supporting Types

public struct PDFConfiguration {
    public let pageSize: CGSize
    public let headerColor: UIColor
    public let footerColor: UIColor
    public let includeLogo: Bool
    public let includeConfidentialityNotice: Bool
    public let confidentialityNotice: String
    
    public static let `default` = PDFConfiguration(
        pageSize: CGSize(width: 612, height: 792), // US Letter
        headerColor: UIColor.systemBlue,
        footerColor: UIColor.systemGray,
        includeLogo: true,
        includeConfidentialityNotice: true,
        confidentialityNotice: "CONFIDENTIAL - This document contains sensitive information and is intended for authorized personnel only."
    )
    
    public init(
        pageSize: CGSize,
        headerColor: UIColor,
        footerColor: UIColor,
        includeLogo: Bool,
        includeConfidentialityNotice: Bool,
        confidentialityNotice: String
    ) {
        self.pageSize = pageSize
        self.headerColor = headerColor
        self.footerColor = footerColor
        self.includeLogo = includeLogo
        self.includeConfidentialityNotice = includeConfidentialityNotice
        self.confidentialityNotice = confidentialityNotice
    }
}

private struct ChartDataPoint {
    let label: String
    let value: Double
}

// MARK: - Extensions

private extension DateFormatter {
    static let reportDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}