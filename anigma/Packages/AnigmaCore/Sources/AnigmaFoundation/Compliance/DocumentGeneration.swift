//
//  DocumentGeneration.swift
//  AnigmaCore
//
//  Auto-generation of compliance documentation from live system state.
//  Produces SSP, POA&M, VPAT/ACR, and ConMon deliverables.
//
//  Design principle: Documents are views over the control registry and evidence,
//  not separate artifacts that drift from reality.
//

import AnigmaPrimitives
import Foundation
import ContractsCore

// MARK: - Document Types

/// Types of compliance documents that can be generated.
public enum ComplianceDocumentType: String, Sendable, Codable {
    /// System Security Plan (FedRAMP SSP).
    case systemSecurityPlan = "ssp"

    /// Plan of Action and Milestones.
    case poam = "poam"

    /// Voluntary Product Accessibility Template / Accessibility Conformance Report.
    case vpat = "vpat"

    /// Continuous Monitoring Report.
    case conMonReport = "conmon"

    /// Control Implementation Summary.
    case controlSummary = "control_summary"

    /// Security Assessment Report.
    case sar = "sar"

    /// Authorization Package.
    case authorizationPackage = "auth_package"
}

/// Output format for documents.
public enum DocumentFormat: String, Sendable, Codable {
    /// Markdown (human-readable, Codex-compatible).
    case markdown = "markdown"

    /// JSON (machine-readable).
    case json = "json"

    /// OSCAL JSON format.
    case oscal = "oscal"

    /// HTML.
    case html = "html"
}

// MARK: - Document Context

/// Context for document generation.
public struct DocumentGenerationContext: Sendable {
    /// Tenant for which to generate.
    public let tenantId: String

    /// Environment.
    public let environmentId: String

    /// Framework to use.
    public let frameworkId: String

    /// Baseline level (for FedRAMP).
    public let baseline: ControlBaseline?

    /// Time period for evidence.
    public let periodStart: Date
    public let periodEnd: Date

    /// Who is generating.
    public let generatedBy: UUID

    /// Organization information.
    public let organization: OrganizationInfo

    /// System information.
    public let system: SystemInfo

    public init(
        tenantId: String,
        environmentId: String,
        frameworkId: String = "NIST-800-53-R5",
        baseline: ControlBaseline? = .moderate,
        periodStart: Date,
        periodEnd: Date,
        generatedBy: UUID,
        organization: OrganizationInfo,
        system: SystemInfo
    ) {
        self.tenantId = tenantId
        self.environmentId = environmentId
        self.frameworkId = frameworkId
        self.baseline = baseline
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.generatedBy = generatedBy
        self.organization = organization
        self.system = system
    }
}

/// Organization information for documents.
public struct OrganizationInfo: Sendable, Codable {
    public let name: String
    public let abbreviation: String?
    public let address: String?
    public let phone: String?
    public let email: String?
    public let website: String?

    public init(
        name: String,
        abbreviation: String? = nil,
        address: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        website: String? = nil
    ) {
        self.name = name
        self.abbreviation = abbreviation
        self.address = address
        self.phone = phone
        self.email = email
        self.website = website
    }
}

/// System information for documents.
public struct SystemInfo: Sendable, Codable {
    public let name: String
    public let abbreviation: String?
    public let version: String
    public let description: String
    public let systemType: String
    public let deploymentModel: String
    public let serviceModel: String
    public let authorizationBoundary: String

    public init(
        name: String,
        abbreviation: String? = nil,
        version: String,
        description: String,
        systemType: String = "Major Application",
        deploymentModel: String = "Private Cloud",
        serviceModel: String = "SaaS",
        authorizationBoundary: String
    ) {
        self.name = name
        self.abbreviation = abbreviation
        self.version = version
        self.description = description
        self.systemType = systemType
        self.deploymentModel = deploymentModel
        self.serviceModel = serviceModel
        self.authorizationBoundary = authorizationBoundary
    }
}

// MARK: - Generated Document

/// A generated compliance document.
public struct GeneratedDocument: Sendable, Identifiable {
    /// Unique document ID.
    public let documentId: UUID

    /// Document type.
    public let documentType: ComplianceDocumentType

    /// Output format.
    public let format: DocumentFormat

    /// Document title.
    public let title: String

    /// Document version.
    public let version: String

    /// When generated.
    public let generatedAt: Date

    /// Generation context.
    public let context: DocumentGenerationContext

    /// Document content.
    public let content: String

    /// Sections within the document.
    public let sections: [DocumentSection]

    /// Metadata.
    public let metadata: [String: String]

    /// Content hash for integrity.
    public let contentHash: String

    public var id: UUID { documentId }

    public init(
        documentId: UUID = UUID(),
        documentType: ComplianceDocumentType,
        format: DocumentFormat,
        title: String,
        version: String,
        context: DocumentGenerationContext,
        content: String,
        sections: [DocumentSection] = [],
        metadata: [String: String] = [:]
    ) {
        self.documentId = documentId
        self.documentType = documentType
        self.format = format
        self.title = title
        self.version = version
        self.generatedAt = Date()
        self.context = context
        self.content = content
        self.sections = sections
        self.metadata = metadata

        // Simple hash for integrity
        self.contentHash = String(content.hashValue)
    }
}

/// A section within a document.
public struct DocumentSection: Sendable {
    public let sectionId: String
    public let title: String
    public let content: String
    public let subsections: [DocumentSection]

    public init(
        sectionId: String,
        title: String,
        content: String,
        subsections: [DocumentSection] = []
    ) {
        self.sectionId = sectionId
        self.title = title
        self.content = content
        self.subsections = subsections
    }
}

// MARK: - Document Generator

/// Generates compliance documents from system state.
public actor ComplianceDocumentGenerator {
    /// Control registry.
    private let controlRegistry: ControlRegistry

    /// Continuous monitoring service.
    private let monitoringService: ContinuousMonitoringService

    /// Audit log for recording generation.
    private var auditLog: (any AuditLogging)?

    public init(
        controlRegistry: ControlRegistry,
        monitoringService: ContinuousMonitoringService
    ) {
        self.controlRegistry = controlRegistry
        self.monitoringService = monitoringService
    }

    /// Sets the audit log.
    public func setAuditLog(_ log: any AuditLogging) {
        self.auditLog = log
    }

    // MARK: - SSP Generation

    /// Generates a System Security Plan.
    public func generateSSP(
        context: DocumentGenerationContext,
        format: DocumentFormat = .markdown
    ) async -> GeneratedDocument {
        let implementations = await controlRegistry.getImplementationsForFramework(context.frameworkId)
        let controlStatus = await monitoringService.getControlStatus()

        var sections: [DocumentSection] = []
        var content = ""

        // Title page
        let titleSection = generateSSPTitleSection(context: context)
        sections.append(titleSection)

        // System description
        let systemSection = generateSystemDescriptionSection(context: context)
        sections.append(systemSection)

        // Control implementation statements
        let controlSection = await generateControlImplementationSection(
            context: context,
            implementations: implementations,
            status: controlStatus
        )
        sections.append(controlSection)

        // Render content
        switch format {
        case .markdown:
            content = renderMarkdown(sections: sections, title: "System Security Plan")
        case .json:
            content = renderJSON(sections: sections)
        case .oscal:
            content = renderOSCAL(sections: sections, documentType: .systemSecurityPlan)
        case .html:
            content = renderHTML(sections: sections, title: "System Security Plan")
        }

        // Log generation
        if let log = auditLog {
            try? await log.recordEvent(
                id: UUID(),
                type: ContractsCore.AuditEventType.dataExported,
                principal: context.generatedBy.uuidString,
                module: "DocumentGeneration",
                description: "Generated SSP for \(context.tenantId)/\(context.environmentId)",
                metadata: [
                    "document_type": "SSP",
                    "tenant_id": context.tenantId,
                    "environment_id": context.environmentId
                ]
            )
        }

        return GeneratedDocument(
            documentType: .systemSecurityPlan,
            format: format,
            title: "System Security Plan - \(context.system.name)",
            version: "1.0",
            context: context,
            content: content,
            sections: sections,
            metadata: [
                "baseline": context.baseline?.rawValue ?? "moderate",
                "framework": context.frameworkId
            ]
        )
    }

    // MARK: - POA&M Generation

    /// Generates a Plan of Action and Milestones.
    public func generatePOAM(
        context: DocumentGenerationContext,
        format: DocumentFormat = .markdown
    ) async -> GeneratedDocument {
        let implementations = await controlRegistry.getImplementationsForFramework(context.frameworkId)
        let controlStatus = await monitoringService.getControlStatus()

        // Find controls that are not fully implemented
        var poamItems: [POAMItem] = []

        for impl in implementations {
            if impl.status != .implemented && impl.status != .notApplicable && impl.status != .inherited {
                let status = controlStatus[impl.controlId]
                let issues = status?.probeResults.flatMap { $0.issues } ?? []

                poamItems.append(POAMItem(
                    itemId: "POAM-\(impl.controlId)",
                    controlId: impl.controlId,
                    weakness: "Control \(impl.controlId) is \(impl.status.rawValue)",
                    risk: determineRisk(for: impl),
                    remediation: impl.notes ?? "Complete implementation of control requirements",
                    milestones: generateMilestones(for: impl),
                    scheduledCompletion: Date().addingTimeInterval(90 * 24 * 3600), // 90 days
                    status: .open,
                    issues: issues.map { $0.description }
                ))
            }
        }

        var sections: [DocumentSection] = []

        // Header section
        let headerSection = DocumentSection(
            sectionId: "header",
            title: "Plan of Action and Milestones",
            content: """
            **System Name:** \(context.system.name)
            **Organization:** \(context.organization.name)
            **Date:** \(formatDate(Date()))
            **Prepared By:** Anigma Compliance Module

            ## Summary

            Total POA&M Items: \(poamItems.count)
            - High Risk: \(poamItems.filter { $0.risk == .high }.count)
            - Medium Risk: \(poamItems.filter { $0.risk == .medium }.count)
            - Low Risk: \(poamItems.filter { $0.risk == .low }.count)
            """
        )
        sections.append(headerSection)

        // Items section
        let itemsContent = poamItems.map { item in
            """
            ### \(item.itemId): \(item.controlId)

            **Weakness:** \(item.weakness)
            **Risk Level:** \(item.risk.rawValue.capitalized)
            **Status:** \(item.status.rawValue.capitalized)
            **Scheduled Completion:** \(formatDate(item.scheduledCompletion))

            **Remediation Plan:**
            \(item.remediation)

            **Milestones:**
            \(item.milestones.enumerated().map { "  \($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

            """
        }.joined(separator: "\n---\n\n")

        let itemsSection = DocumentSection(
            sectionId: "items",
            title: "POA&M Items",
            content: itemsContent
        )
        sections.append(itemsSection)

        let content: String
        switch format {
        case .markdown:
            content = renderMarkdown(sections: sections, title: "Plan of Action and Milestones")
        case .json:
            content = renderJSON(sections: sections)
        case .oscal:
            content = renderOSCAL(sections: sections, documentType: .poam)
        case .html:
            content = renderHTML(sections: sections, title: "Plan of Action and Milestones")
        }

        return GeneratedDocument(
            documentType: .poam,
            format: format,
            title: "POA&M - \(context.system.name)",
            version: "1.0",
            context: context,
            content: content,
            sections: sections,
            metadata: ["item_count": String(poamItems.count)]
        )
    }

    // MARK: - VPAT/ACR Generation

    /// Generates a Voluntary Product Accessibility Template / Accessibility Conformance Report.
    public func generateVPAT(
        context: DocumentGenerationContext,
        wcagLevel: WCAGLevel = .aa,
        format: DocumentFormat = .markdown
    ) async -> GeneratedDocument {
        let accessibilityStatus = await monitoringService.getControlStatus()
        let wcagControls = WCAGControls.controlsForLevel(wcagLevel)

        var sections: [DocumentSection] = []

        // Product information
        let productSection = DocumentSection(
            sectionId: "product",
            title: "Product Information",
            content: """
            **Product Name:** \(context.system.name)
            **Product Version:** \(context.system.version)
            **Vendor:** \(context.organization.name)
            **Contact:** \(context.organization.email ?? "N/A")
            **Report Date:** \(formatDate(Date()))
            **WCAG Version:** 2.1
            **Conformance Level:** \(wcagLevel.rawValue)
            """
        )
        sections.append(productSection)

        // Evaluation methods
        let methodsSection = DocumentSection(
            sectionId: "methods",
            title: "Evaluation Methods",
            content: """
            This report is based on:
            - Automated accessibility testing integrated into the Anigma platform
            - Manual accessibility audits
            - Continuous monitoring via accessibility probes
            - User feedback and testing with assistive technologies
            """
        )
        sections.append(methodsSection)

        // WCAG criteria table
        var tableContent = """
        | Criterion | Title | Level | Support Level | Remarks |
        |-----------|-------|-------|---------------|---------|
        """

        for control in wcagControls {
            let status = accessibilityStatus[control.criterionId]
            let supportLevel = determineSupportLevel(status: status)
            let remarks = generateRemarks(for: control, status: status)

            tableContent += "\n| \(control.criterionId) | \(control.title) | \(control.level.rawValue) | \(supportLevel) | \(remarks) |"
        }

        let criteriaSection = DocumentSection(
            sectionId: "criteria",
            title: "WCAG 2.1 Conformance",
            content: tableContent
        )
        sections.append(criteriaSection)

        // Legal disclaimer
        let legalSection = DocumentSection(
            sectionId: "legal",
            title: "Legal Disclaimer",
            content: """
            This document is provided for informational purposes and represents the vendor's
            assessment of the product's accessibility at the time of evaluation. Accessibility
            features may vary based on configuration, deployment, and use case. This report
            does not constitute legal advice or guarantee compliance with any specific
            accessibility requirements.
            """
        )
        sections.append(legalSection)

        let content: String
        switch format {
        case .markdown:
            content = renderMarkdown(sections: sections, title: "Accessibility Conformance Report")
        case .json:
            content = renderJSON(sections: sections)
        case .oscal, .html:
            content = renderHTML(sections: sections, title: "Accessibility Conformance Report")
        }

        return GeneratedDocument(
            documentType: .vpat,
            format: format,
            title: "VPAT/ACR - \(context.system.name)",
            version: "1.0",
            context: context,
            content: content,
            sections: sections,
            metadata: [
                "wcag_version": "2.1",
                "wcag_level": wcagLevel.rawValue
            ]
        )
    }

    // MARK: - ConMon Report Generation

    /// Generates a Continuous Monitoring Report.
    public func generateConMonReport(
        context: DocumentGenerationContext,
        format: DocumentFormat = .markdown
    ) async -> GeneratedDocument {
        let overallStatus = await monitoringService.getOverallStatus()
        let controlStatus = await monitoringService.getControlStatus()
        let probeResults = await monitoringService.getAllLatestResults()

        var sections: [DocumentSection] = []

        // Executive summary
        let summarySection = DocumentSection(
            sectionId: "summary",
            title: "Executive Summary",
            content: """
            **Reporting Period:** \(formatDate(context.periodStart)) to \(formatDate(context.periodEnd))
            **System:** \(context.system.name)
            **Environment:** \(context.environmentId)

            ## Overall Status: \(overallStatus.status.rawValue.uppercased())

            **Compliance Score:** \(String(format: "%.1f", overallStatus.overallScore * 100))%

            | Status | Count |
            |--------|-------|
            | Healthy | \(overallStatus.healthyCount) |
            | Degraded | \(overallStatus.degradedCount) |
            | Failing | \(overallStatus.failingCount) |
            | Error | \(overallStatus.errorCount) |

            **Total Probes:** \(overallStatus.probeCount)
            """
        )
        sections.append(summarySection)

        // Control status details
        var controlContent = "## Control Status by Family\n\n"

        let statusByFamily = Dictionary(grouping: controlStatus.values) { status in
            String(status.controlId.prefix(2))
        }

        for (family, statuses) in statusByFamily.sorted(by: { $0.key < $1.key }) {
            let familyScore = statuses.map { $0.score }.reduce(0, +) / Double(statuses.count)
            controlContent += """

            ### \(family) Family

            **Average Score:** \(String(format: "%.1f", familyScore * 100))%

            | Control | Score | Status |
            |---------|-------|--------|
            """

            for status in statuses.sorted(by: { $0.controlId < $1.controlId }) {
                controlContent += "\n| \(status.controlId) | \(String(format: "%.0f", status.score * 100))% | \(status.status.rawValue) |"
            }

            controlContent += "\n"
        }

        let controlSection = DocumentSection(
            sectionId: "controls",
            title: "Control Status",
            content: controlContent
        )
        sections.append(controlSection)

        // Issues and findings
        let allIssues = probeResults.flatMap { $0.issues }
        var issuesContent = "## Outstanding Issues\n\n"

        let criticalIssues = allIssues.filter { $0.severity == .critical }
        let highIssues = allIssues.filter { $0.severity == .high }
        let mediumIssues = allIssues.filter { $0.severity == .medium }

        issuesContent += """
        **Summary:**
        - Critical: \(criticalIssues.count)
        - High: \(highIssues.count)
        - Medium: \(mediumIssues.count)

        """

        if !criticalIssues.isEmpty {
            issuesContent += "### Critical Issues\n\n"
            for issue in criticalIssues {
                issuesContent += "- **\(issue.description)**\n"
                if let remediation = issue.remediation {
                    issuesContent += "  - Remediation: \(remediation)\n"
                }
            }
        }

        if !highIssues.isEmpty {
            issuesContent += "\n### High Issues\n\n"
            for issue in highIssues {
                issuesContent += "- \(issue.description)\n"
            }
        }

        let issuesSection = DocumentSection(
            sectionId: "issues",
            title: "Issues and Findings",
            content: issuesContent
        )
        sections.append(issuesSection)

        let content: String
        switch format {
        case .markdown:
            content = renderMarkdown(sections: sections, title: "Continuous Monitoring Report")
        case .json:
            content = renderJSON(sections: sections)
        case .oscal:
            content = renderOSCAL(sections: sections, documentType: .conMonReport)
        case .html:
            content = renderHTML(sections: sections, title: "Continuous Monitoring Report")
        }

        return GeneratedDocument(
            documentType: .conMonReport,
            format: format,
            title: "ConMon Report - \(context.system.name)",
            version: "1.0",
            context: context,
            content: content,
            sections: sections,
            metadata: [
                "overall_score": String(format: "%.2f", overallStatus.overallScore),
                "probe_count": String(overallStatus.probeCount)
            ]
        )
    }

    // MARK: - Private Helpers

    private func generateSSPTitleSection(context: DocumentGenerationContext) -> DocumentSection {
        DocumentSection(
            sectionId: "title",
            title: "System Security Plan",
            content: """
            # System Security Plan

            **System Name:** \(context.system.name)
            **System Abbreviation:** \(context.system.abbreviation ?? "N/A")
            **System Version:** \(context.system.version)

            **Organization:** \(context.organization.name)
            **Prepared By:** Anigma Compliance Module
            **Date:** \(formatDate(Date()))

            **FedRAMP Baseline:** \(context.baseline?.rawValue.capitalized ?? "Moderate")
            """
        )
    }

    private func generateSystemDescriptionSection(context: DocumentGenerationContext) -> DocumentSection {
        DocumentSection(
            sectionId: "system_description",
            title: "System Description",
            content: """
            ## 1. System Description

            ### 1.1 System Overview

            \(context.system.description)

            ### 1.2 System Type

            **Type:** \(context.system.systemType)
            **Deployment Model:** \(context.system.deploymentModel)
            **Service Model:** \(context.system.serviceModel)

            ### 1.3 Authorization Boundary

            \(context.system.authorizationBoundary)

            ### 1.4 System Architecture

            The Anigma platform is built on a modular architecture with the following core components:

            - **AnigmaCore**: ECS engine, governance, security, and infrastructure
            - **Identity Module**: Principal management, authentication, authorization
            - **Security Module**: Cryptography, threat detection, policy enforcement
            - **Observatorium Module**: Telemetry, metrics, alerting
            - **Compliance Module**: Control mapping, continuous monitoring, documentation
            - **Domain Modules**: Pragma (work), Conexus (CRM), Codex (knowledge), Transcriptum (records)

            All data access is governed through SecuredWorld, WriteGate, and GovernanceController.
            """
        )
    }

    private func generateControlImplementationSection(
        context: DocumentGenerationContext,
        implementations: [ControlImplementation],
        status: [String: ControlComplianceStatus]
    ) async -> DocumentSection {
        var content = "## Control Implementation Statements\n\n"

        // Group by family
        let byFamily = Dictionary(grouping: implementations) { impl in
            String(impl.controlId.prefix(2))
        }

        for (family, impls) in byFamily.sorted(by: { $0.key < $1.key }) {
            let familyDef = NIST80053Families.all.first { $0.familyId == family }
            content += "### \(family) - \(familyDef?.name ?? "Unknown Family")\n\n"

            for impl in impls.sorted(by: { $0.controlId < $1.controlId }) {
                let controlStatus = status[impl.controlId]
                let statusEmoji = statusEmoji(for: impl.status)

                content += """
                #### \(impl.controlId) \(statusEmoji)

                **Implementation Status:** \(impl.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                **Implementation Type:** \(impl.implementationType.rawValue.capitalized)
                **Implementing Modules:** \(impl.implementingModules.joined(separator: ", "))

                **Implementation Statement:**

                \(impl.statement)

                """

                if !impl.parameterValues.isEmpty {
                    content += "**Organization-Defined Parameters:**\n\n"
                    for (param, value) in impl.parameterValues {
                        content += "- `\(param)`: \(value)\n"
                    }
                    content += "\n"
                }

                if let probeStatus = controlStatus {
                    content += "**Continuous Monitoring Status:** \(probeStatus.status.rawValue) (\(String(format: "%.0f", probeStatus.score * 100))%)\n\n"
                }

                content += "---\n\n"
            }
        }

        return DocumentSection(
            sectionId: "controls",
            title: "Control Implementation Statements",
            content: content
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private func statusEmoji(for status: ImplementationStatus) -> String {
        switch status {
        case .implemented: return "✅"
        case .partiallyImplemented: return "🟡"
        case .planned: return "📋"
        case .notApplicable: return "➖"
        case .inherited: return "↗️"
        case .degraded: return "⚠️"
        case .notImplemented: return "❌"
        }
    }

    private func determineRisk(for impl: ControlImplementation) -> POAMRisk {
        switch impl.status {
        case .notImplemented: return .high
        case .planned, .degraded: return .medium
        case .partiallyImplemented: return .low
        default: return .low
        }
    }

    private func generateMilestones(for impl: ControlImplementation) -> [String] {
        switch impl.status {
        case .planned:
            return [
                "Complete design and requirements analysis",
                "Implement control mechanisms",
                "Conduct testing and validation",
                "Deploy to production",
                "Document implementation"
            ]
        case .partiallyImplemented:
            return [
                "Identify gaps in current implementation",
                "Implement missing functionality",
                "Validate complete implementation",
                "Update documentation"
            ]
        case .degraded:
            return [
                "Investigate root cause of degradation",
                "Implement fixes",
                "Verify control effectiveness",
                "Monitor for stability"
            ]
        default:
            return ["Assess and plan remediation"]
        }
    }

    private func determineSupportLevel(status: ControlComplianceStatus?) -> String {
        guard let status = status else { return "Not Evaluated" }

        switch status.status {
        case .healthy: return "Supports"
        case .degraded: return "Partially Supports"
        case .failing: return "Does Not Support"
        case .error, .notApplicable: return "Not Applicable"
        }
    }

    private func generateRemarks(for control: AccessibilityControlDefinition, status: ControlComplianceStatus?) -> String {
        guard let status = status else {
            return "Evaluation pending"
        }

        let issues = status.probeResults.flatMap { $0.issues }
        if issues.isEmpty {
            return "Meets requirements"
        } else {
            return issues.first?.description ?? "See probe results for details"
        }
    }

    // MARK: - Rendering

    private func renderMarkdown(sections: [DocumentSection], title: String) -> String {
        var output = "# \(title)\n\n"
        output += "_Generated by Anigma Compliance Module on \(formatDate(Date()))_\n\n"
        output += "---\n\n"

        for section in sections {
            output += renderSectionMarkdown(section, level: 2)
        }

        return output
    }

    private func renderSectionMarkdown(_ section: DocumentSection, level: Int) -> String {
        let heading = String(repeating: "#", count: level)
        var output = "\(heading) \(section.title)\n\n"
        output += section.content + "\n\n"

        for subsection in section.subsections {
            output += renderSectionMarkdown(subsection, level: level + 1)
        }

        return output
    }

    private func renderJSON(sections: [DocumentSection]) -> String {
        let data: [String: Any] = [
            "generatedAt": ISO8601DateFormatter().string(from: Date()),
            "sections": sections.map { sectionToDict($0) }
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "{}"
    }

    private func sectionToDict(_ section: DocumentSection) -> [String: Any] {
        [
            "id": section.sectionId,
            "title": section.title,
            "content": section.content,
            "subsections": section.subsections.map { sectionToDict($0) }
        ]
    }

    private func renderOSCAL(sections: [DocumentSection], documentType: ComplianceDocumentType) -> String {
        // Simplified OSCAL structure
        let oscal: [String: Any] = [
            "document-type": documentType.rawValue,
            "metadata": [
                "title": sections.first?.title ?? "Compliance Document",
                "last-modified": ISO8601DateFormatter().string(from: Date()),
                "version": "1.0",
                "oscal-version": "1.0.0"
            ],
            "content": sections.map { sectionToDict($0) }
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: oscal, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "{}"
    }

    private func renderHTML(sections: [DocumentSection], title: String) -> String {
        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(title)</title>
            <style>
                body { font-family: system-ui, sans-serif; max-width: 1200px; margin: 0 auto; padding: 2rem; }
                h1 { color: #1a1a1a; border-bottom: 2px solid #0066cc; padding-bottom: 0.5rem; }
                h2 { color: #333; margin-top: 2rem; }
                h3 { color: #555; }
                table { border-collapse: collapse; width: 100%; margin: 1rem 0; }
                th, td { border: 1px solid #ddd; padding: 0.5rem; text-align: left; }
                th { background-color: #f5f5f5; }
                code { background-color: #f0f0f0; padding: 0.2rem 0.4rem; border-radius: 3px; }
                .timestamp { color: #666; font-style: italic; }
            </style>
        </head>
        <body>
            <h1>\(title)</h1>
            <p class="timestamp">Generated on \(formatDate(Date()))</p>
        """

        for section in sections {
            html += renderSectionHTML(section, level: 2)
        }

        html += """
        </body>
        </html>
        """

        return html
    }

    private func renderSectionHTML(_ section: DocumentSection, level: Int) -> String {
        let tag = min(level, 6)
        var html = "<h\(tag)>\(section.title)</h\(tag)>\n"

        // Convert markdown-ish content to HTML (simplified)
        let htmlContent = section.content
            .replacingOccurrences(of: "**", with: "<strong>")
            .replacingOccurrences(of: "\\*\\*", with: "</strong>")
            .replacingOccurrences(of: "\n\n", with: "</p><p>")
            .replacingOccurrences(of: "\n", with: "<br>")

        html += "<div>\(htmlContent)</div>\n"

        for subsection in section.subsections {
            html += renderSectionHTML(subsection, level: level + 1)
        }

        return html
    }
}

// MARK: - POA&M Types

/// A POA&M item.
public struct POAMItem: Sendable {
    public let itemId: String
    public let controlId: String
    public let weakness: String
    public let risk: POAMRisk
    public let remediation: String
    public let milestones: [String]
    public let scheduledCompletion: Date
    public let status: POAMStatus
    public let issues: [String]
}

/// POA&M risk level.
public enum POAMRisk: String, Sendable {
    case high = "high"
    case medium = "medium"
    case low = "low"
}

/// POA&M item status.
public enum POAMStatus: String, Sendable {
    case open = "open"
    case inProgress = "in_progress"
    case completed = "completed"
    case onHold = "on_hold"
}

// MARK: - Control Registry

/// Central registry for control definitions and implementations.
public actor ControlRegistry {
    /// Control definitions by ID.
    private var controlDefinitions: [String: ControlDefinition] = [:]

    /// Accessibility control definitions.
    private var accessibilityControls: [String: AccessibilityControlDefinition] = [:]

    /// Control implementations.
    private var implementations: [UUID: ControlImplementation] = [:]

    /// Implementation by control ID.
    private var implementationsByControl: [String: UUID] = [:]

    public init() {
        // Load standard controls
        for control in NIST80053Controls.all {
            controlDefinitions[control.controlId] = control
        }

        for control in WCAGControls.all {
            accessibilityControls[control.criterionId] = control
        }

        // Load standard implementations
        for impl in AnigmaControlImplementations.all {
            implementations[impl.implementationId] = impl
            implementationsByControl[impl.controlId] = impl.implementationId
        }
    }

    /// Gets a control definition.
    public func getControl(_ controlId: String) -> ControlDefinition? {
        controlDefinitions[controlId]
    }

    /// Gets all controls for a framework.
    public func getControlsForFramework(_ frameworkId: String) -> [ControlDefinition] {
        controlDefinitions.values.filter { $0.frameworkId == frameworkId }
    }

    /// Gets controls for a baseline.
    public func getControlsForBaseline(_ baseline: ControlBaseline) -> [ControlDefinition] {
        controlDefinitions.values.filter { $0.baselines.contains(baseline) }
    }

    /// Registers a control implementation.
    public func registerImplementation(_ implementation: ControlImplementation) {
        implementations[implementation.implementationId] = implementation
        implementationsByControl[implementation.controlId] = implementation.implementationId
    }

    /// Gets an implementation for a control.
    public func getImplementation(for controlId: String) -> ControlImplementation? {
        guard let implId = implementationsByControl[controlId] else { return nil }
        return implementations[implId]
    }

    /// Gets all implementations for a framework.
    public func getImplementationsForFramework(_ frameworkId: String) -> [ControlImplementation] {
        implementations.values.filter { $0.frameworkId == frameworkId }
    }

    /// Updates an implementation status.
    public func updateImplementationStatus(
        controlId: String,
        status: ImplementationStatus,
        notes: String? = nil
    ) {
        guard let implId = implementationsByControl[controlId],
              var impl = implementations[implId] else { return }

        impl.status = status
        impl.notes = notes
        impl.modifiedAt = Date()
        implementations[implId] = impl
    }

    /// Gets coverage statistics.
    public func getCoverageStatistics(for baseline: ControlBaseline) -> ControlCoverageStats {
        let baselineControls = getControlsForBaseline(baseline)
        let totalControls = baselineControls.count

        var implemented = 0
        var partial = 0
        var planned = 0
        var notImplemented = 0
        var inherited = 0
        var notApplicable = 0

        for control in baselineControls {
            if let impl = getImplementation(for: control.controlId) {
                switch impl.status {
                case .implemented: implemented += 1
                case .partiallyImplemented, .degraded: partial += 1
                case .planned: planned += 1
                case .inherited: inherited += 1
                case .notApplicable: notApplicable += 1
                case .notImplemented: notImplemented += 1
                }
            } else {
                notImplemented += 1
            }
        }

        return ControlCoverageStats(
            baseline: baseline,
            totalControls: totalControls,
            implemented: implemented,
            partiallyImplemented: partial,
            planned: planned,
            inherited: inherited,
            notApplicable: notApplicable,
            notImplemented: notImplemented
        )
    }
}

/// Control coverage statistics.
public struct ControlCoverageStats: Sendable {
    public let baseline: ControlBaseline
    public let totalControls: Int
    public let implemented: Int
    public let partiallyImplemented: Int
    public let planned: Int
    public let inherited: Int
    public let notApplicable: Int
    public let notImplemented: Int

    public var compliancePercentage: Double {
        let compliant = implemented + inherited + notApplicable
        return totalControls > 0 ? Double(compliant) / Double(totalControls) * 100 : 0
    }

    public var coveragePercentage: Double {
        let covered = implemented + partiallyImplemented + inherited + notApplicable
        return totalControls > 0 ? Double(covered) / Double(totalControls) * 100 : 0
    }
}
