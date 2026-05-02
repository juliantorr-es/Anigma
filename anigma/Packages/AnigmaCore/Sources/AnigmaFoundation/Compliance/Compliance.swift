//
//  Compliance.swift
//  AnigmaCore
//
//  Compliance infrastructure module for the Anigma platform.
//  Exports all compliance-related types and provides unified access.
//
//  This module provides:
//  - NIST SP 800-53 Rev.5 control catalog
//  - FedRAMP baseline overlays
//  - WCAG 2.1 / Section 508 accessibility controls
//  - Control implementation mapping
//  - Continuous monitoring with probes
//  - Auto-generated compliance documentation (SSP, POA&M, VPAT)
//

import AnigmaPrimitives
import Foundation
import ContractsCore

// MARK: - Compliance Module

/// The Compliance module provides complete compliance infrastructure for Anigma.
///
/// ## Overview
///
/// This module embeds compliance frameworks (NIST 800-53, FedRAMP, WCAG) as
/// native data structures, maps them to Anigma implementations, continuously
/// monitors control effectiveness, and auto-generates required documentation.
///
/// ## Components
///
/// ### Control Catalog (ControlCatalog.swift)
/// - `ComplianceFramework`: Framework definitions
/// - `ControlFamily`: Control families (AC, AU, CM, etc.)
/// - `ControlDefinition`: Individual control requirements
/// - `AccessibilityControlDefinition`: WCAG success criteria
/// - `NIST80053Controls`: Pre-defined NIST 800-53 controls
/// - `WCAGControls`: Pre-defined WCAG 2.1 success criteria
///
/// ### Control Implementation (ControlImplementation.swift)
/// - `ControlImplementation`: Maps controls to Anigma modules
/// - `EvidenceSource`: Evidence collection configuration
/// - `EvidenceArtifact`: Collected evidence
/// - `AnigmaControlImplementations`: Pre-defined implementations
///
/// ### Continuous Monitoring (ContinuousMonitoring.swift)
/// - `ControlProbe`: Control effectiveness monitors
/// - `ProbeResult`: Probe evaluation results
/// - `ContinuousMonitoringService`: Probe orchestration
/// - `StandardProbes`: Factory for standard security probes
/// - `AccessibilityProbes`: Factory for accessibility probes
///
/// ### Document Generation (DocumentGeneration.swift)
/// - `ComplianceDocumentGenerator`: Generates compliance documents
/// - `GeneratedDocument`: Generated document container
/// - `ControlRegistry`: Central control and implementation registry
///
/// ## Usage Example
///
/// ```swift
/// // Initialize compliance infrastructure
/// let compliance = await ComplianceModule.initialize(auditLog: auditLog)
///
/// // Register custom probes
/// await compliance.monitoringService.registerProbe(
///     StandardProbes.accountManagementProbe { ... }
/// )
///
/// // Run all probes
/// let results = await compliance.monitoringService.runAllProbes()
///
/// // Get overall compliance status
/// let status = await compliance.monitoringService.getOverallStatus()
///
/// // Generate SSP
/// let ssp = await compliance.documentGenerator.generateSSP(
///     context: context,
///     format: .markdown
/// )
///
/// // Get control coverage
/// let coverage = await compliance.controlRegistry.getCoverageStatistics(for: .moderate)
/// ```
///
/// ## Integration
///
/// The Compliance module integrates with:
/// - **Governance**: All compliance events are logged
/// - **Security**: Security controls map to implementations
/// - **Identity**: Identity controls for AC family
/// - **Observatorium**: Probe results feed into metrics
/// - **Codex**: Generated documents can be stored as pages
///
/// ## Thread Safety
///
/// All services are implemented as Swift actors for thread-safe access.
public enum ComplianceModule {
    /// Version of the compliance module.
    public static let version = "1.0.0"

    /// Supported compliance frameworks.
    public static let supportedFrameworks: [ComplianceFramework] = StandardFrameworks.all

    /// Initializes the complete compliance infrastructure.
    public static func initialize(auditLog: any AuditLogging) async -> ComplianceInfrastructure {
        let controlRegistry = ControlRegistry()
        let monitoringService = ContinuousMonitoringService()
        let documentGenerator = ComplianceDocumentGenerator(
            controlRegistry: controlRegistry,
            monitoringService: monitoringService
        )

        // Wire up audit logging
        await monitoringService.setAuditLog(auditLog)
        await documentGenerator.setAuditLog(auditLog)

        return ComplianceInfrastructure(
            controlRegistry: controlRegistry,
            monitoringService: monitoringService,
            documentGenerator: documentGenerator
        )
    }

    /// Gets summary of NIST 800-53 control coverage.
    public static func getNIST80053Summary() -> FrameworkSummary {
        FrameworkSummary(
            framework: StandardFrameworks.nist80053Rev5,
            totalControlFamilies: NIST80053Families.all.count,
            totalControls: NIST80053Controls.all.count,
            implementedControls: AnigmaControlImplementations.all.count
        )
    }

    /// Gets summary of WCAG 2.1 coverage.
    public static func getWCAG21Summary() -> FrameworkSummary {
        FrameworkSummary(
            framework: StandardFrameworks.wcag21,
            totalControlFamilies: 4, // Perceivable, Operable, Understandable, Robust
            totalControls: WCAGControls.all.count,
            implementedControls: 0 // Accessibility probes to be implemented
        )
    }
}

/// Container for all compliance infrastructure components.
public struct ComplianceInfrastructure: Sendable {
    /// Central registry for controls and implementations.
    public let controlRegistry: ControlRegistry

    /// Continuous monitoring service.
    public let monitoringService: ContinuousMonitoringService

    /// Document generator.
    public let documentGenerator: ComplianceDocumentGenerator
}

/// Summary of a compliance framework.
public struct FrameworkSummary: Sendable {
    public let framework: ComplianceFramework
    public let totalControlFamilies: Int
    public let totalControls: Int
    public let implementedControls: Int

    public var implementationPercentage: Double {
        totalControls > 0 ? Double(implementedControls) / Double(totalControls) * 100 : 0
    }
}

// MARK: - Compliance Service

/// High-level service for compliance operations.
public actor ComplianceService {
    private let infrastructure: ComplianceInfrastructure
    private var auditLog: (any AuditLogging)?

    public init(infrastructure: ComplianceInfrastructure) {
        self.infrastructure = infrastructure
    }

    /// Sets the audit log.
    public func setAuditLog(_ log: any AuditLogging) {
        self.auditLog = log
    }

    /// Runs a full compliance assessment.
    public func runAssessment(
        tenantId: String,
        environmentId: String,
        baseline: ControlBaseline = .moderate
    ) async -> ComplianceAssessment {
        // Run all probes
        let probeResults = await infrastructure.monitoringService.runAllProbes()

        // Get overall status
        let overallStatus = await infrastructure.monitoringService.getOverallStatus()

        // Get control status
        let controlStatus = await infrastructure.monitoringService.getControlStatus()

        // Get coverage stats
        let coverage = await infrastructure.controlRegistry.getCoverageStatistics(for: baseline)

        // Build assessment
        let assessment = ComplianceAssessment(
            assessmentId: UUID(),
            tenantId: tenantId,
            environmentId: environmentId,
            baseline: baseline,
            assessedAt: Date(),
            overallStatus: overallStatus,
            controlStatus: controlStatus,
            probeResults: probeResults,
            coverage: coverage
        )

        // Log assessment
        if let log = auditLog {
            try? await log.recordEvent(
                id: UUID(),
                type: ContractsCore.AuditEventType.policyEvaluated,
                principal: "compliance_service",
                module: "ComplianceService",
                description: "Compliance assessment completed: \(overallStatus.status.rawValue) (\(String(format: "%.1f", overallStatus.overallScore * 100))%)",
                metadata: [:]
            )
        }

        return assessment
    }

    /// Gets quick compliance status.
    public func getQuickStatus() async -> ComplianceStatus {
        await infrastructure.monitoringService.getOverallStatus()
    }

    /// Generates a compliance report package.
    public func generateReportPackage(
        context: DocumentGenerationContext
    ) async -> ComplianceReportPackage {
        let ssp = await infrastructure.documentGenerator.generateSSP(
            context: context,
            format: .markdown
        )

        let poam = await infrastructure.documentGenerator.generatePOAM(
            context: context,
            format: .markdown
        )

        let conmon = await infrastructure.documentGenerator.generateConMonReport(
            context: context,
            format: .markdown
        )

        return ComplianceReportPackage(
            packageId: UUID(),
            generatedAt: Date(),
            context: context,
            ssp: ssp,
            poam: poam,
            conMonReport: conmon
        )
    }

    /// Generates an accessibility report.
    public func generateAccessibilityReport(
        context: DocumentGenerationContext,
        wcagLevel: WCAGLevel = .aa
    ) async -> GeneratedDocument {
        await infrastructure.documentGenerator.generateVPAT(
            context: context,
            wcagLevel: wcagLevel,
            format: .markdown
        )
    }
}

/// Result of a compliance assessment.
public struct ComplianceAssessment: Sendable {
    public let assessmentId: UUID
    public let tenantId: String
    public let environmentId: String
    public let baseline: ControlBaseline
    public let assessedAt: Date
    public let overallStatus: ComplianceStatus
    public let controlStatus: [String: ControlComplianceStatus]
    public let probeResults: [ProbeResult]
    public let coverage: ControlCoverageStats

    /// Whether the assessment passed (no failing controls).
    public var passed: Bool {
        overallStatus.status != .failing && overallStatus.status != .error
    }

    /// Controls that need attention.
    public var controlsNeedingAttention: [String] {
        controlStatus.filter { $0.value.status != .healthy }.map { $0.key }
    }
}

/// Package of compliance reports.
public struct ComplianceReportPackage: Sendable {
    public let packageId: UUID
    public let generatedAt: Date
    public let context: DocumentGenerationContext
    public let ssp: GeneratedDocument
    public let poam: GeneratedDocument
    public let conMonReport: GeneratedDocument
}

// MARK: - Compliance Dashboard Data

/// Data for compliance dashboard displays.
public struct ComplianceDashboardData: Sendable {
    public let timestamp: Date
    public let overallScore: Double
    public let overallStatus: ProbeStatus
    public let frameworkSummaries: [FrameworkSummary]
    public let controlsByFamily: [String: ControlFamilyStatus]
    public let recentProbeResults: [ProbeResult]
    public let openFindings: Int
    public let criticalFindings: Int
    public let coverageStats: ControlCoverageStats

    public init(
        overallScore: Double,
        overallStatus: ProbeStatus,
        frameworkSummaries: [FrameworkSummary],
        controlsByFamily: [String: ControlFamilyStatus],
        recentProbeResults: [ProbeResult],
        openFindings: Int,
        criticalFindings: Int,
        coverageStats: ControlCoverageStats
    ) {
        self.timestamp = Date()
        self.overallScore = overallScore
        self.overallStatus = overallStatus
        self.frameworkSummaries = frameworkSummaries
        self.controlsByFamily = controlsByFamily
        self.recentProbeResults = recentProbeResults
        self.openFindings = openFindings
        self.criticalFindings = criticalFindings
        self.coverageStats = coverageStats
    }
}

/// Status of a control family.
public struct ControlFamilyStatus: Sendable {
    public let familyId: String
    public let familyName: String
    public let totalControls: Int
    public let implementedCount: Int
    public let healthyCount: Int
    public let degradedCount: Int
    public let failingCount: Int
    public let averageScore: Double
}

// MARK: - Compliance Errors

/// Errors from compliance operations.
public enum ComplianceError: Error, LocalizedError, Sendable {
    case controlNotFound(controlId: String)
    case implementationNotFound(controlId: String)
    case probeNotFound(probeId: String)
    case documentGenerationFailed(reason: String)
    case assessmentFailed(reason: String)
    case invalidConfiguration(message: String)

    public var errorDescription: String? {
        switch self {
        case .controlNotFound(let id):
            return "Control not found: \(id)"
        case .implementationNotFound(let id):
            return "Implementation not found for control: \(id)"
        case .probeNotFound(let id):
            return "Probe not found: \(id)"
        case .documentGenerationFailed(let reason):
            return "Document generation failed: \(reason)"
        case .assessmentFailed(let reason):
            return "Assessment failed: \(reason)"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        }
    }
}
