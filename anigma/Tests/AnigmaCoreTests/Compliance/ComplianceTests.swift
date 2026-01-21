//
//  ComplianceTests.swift
//  AnigmaCoreTests
//
//  Tests for the Compliance module.
//

import XCTest
@testable import AnigmaCore

final class ComplianceTests: XCTestCase {

    // MARK: - Control Catalog Tests

    func testNIST80053ControlsExist() {
        let controls = NIST80053Controls.all
        XCTAssertFalse(controls.isEmpty, "Should have NIST 800-53 controls defined")
        XCTAssertGreaterThan(controls.count, 30, "Should have significant control coverage")
    }

    func testControlFamiliesExist() {
        let families = NIST80053Families.all
        XCTAssertEqual(families.count, 20, "Should have 20 NIST 800-53 control families")

        // Verify key families
        XCTAssertNotNil(families.first { $0.familyId == "AC" })
        XCTAssertNotNil(families.first { $0.familyId == "AU" })
        XCTAssertNotNil(families.first { $0.familyId == "CM" })
        XCTAssertNotNil(families.first { $0.familyId == "SC" })
    }

    func testControlBaselines() {
        let lowControls = NIST80053Controls.controlsForBaseline(.low)
        let moderateControls = NIST80053Controls.controlsForBaseline(.moderate)
        let highControls = NIST80053Controls.controlsForBaseline(.high)

        XCTAssertFalse(lowControls.isEmpty, "Should have low baseline controls")
        XCTAssertGreaterThanOrEqual(moderateControls.count, lowControls.count, "Moderate should include more controls than low")
        XCTAssertGreaterThanOrEqual(highControls.count, moderateControls.count, "High should include more controls than moderate")
    }

    func testControlDefinitionStructure() {
        let ac2 = NIST80053Controls.AC2

        XCTAssertEqual(ac2.controlId, "AC-2")
        XCTAssertEqual(ac2.familyId, "AC")
        XCTAssertEqual(ac2.frameworkId, "NIST-800-53-R5")
        XCTAssertEqual(ac2.title, "Account Management")
        XCTAssertFalse(ac2.statement.isEmpty)
        XCTAssertTrue(ac2.baselines.contains(.low))
        XCTAssertTrue(ac2.baselines.contains(.moderate))
        XCTAssertTrue(ac2.baselines.contains(.high))
        XCTAssertEqual(ac2.priority, .p1)
        XCTAssertFalse(ac2.parameters.isEmpty)
    }

    func testControlEnhancements() {
        let ac2_1 = NIST80053Controls.AC2_1

        XCTAssertEqual(ac2_1.controlId, "AC-2(1)")
        XCTAssertEqual(ac2_1.parentControlId, "AC-2")
        XCTAssertTrue(ac2_1.isEnhancement)
        XCTAssertFalse(ac2_1.baselines.contains(.low))
        XCTAssertTrue(ac2_1.baselines.contains(.moderate))
    }

    // MARK: - WCAG Tests

    func testWCAGControlsExist() {
        let controls = WCAGControls.all
        XCTAssertFalse(controls.isEmpty, "Should have WCAG controls defined")
    }

    func testWCAGLevels() {
        let levelA = WCAGControls.controlsForLevel(.a)
        let levelAA = WCAGControls.controlsForLevel(.aa)
        let levelAAA = WCAGControls.controlsForLevel(.aaa)

        XCTAssertFalse(levelA.isEmpty)
        XCTAssertGreaterThanOrEqual(levelAA.count, levelA.count)
        XCTAssertGreaterThanOrEqual(levelAAA.count, levelAA.count)
    }

    func testWCAGPrinciples() {
        let controls = WCAGControls.all

        let perceivable = controls.filter { $0.principle == .perceivable }
        let operable = controls.filter { $0.principle == .operable }
        let understandable = controls.filter { $0.principle == .understandable }
        let robust = controls.filter { $0.principle == .robust }

        XCTAssertFalse(perceivable.isEmpty)
        XCTAssertFalse(operable.isEmpty)
        XCTAssertFalse(understandable.isEmpty)
        XCTAssertFalse(robust.isEmpty)
    }

    // MARK: - Control Implementation Tests

    func testAnigmaImplementationsExist() {
        let implementations = AnigmaControlImplementations.all
        XCTAssertFalse(implementations.isEmpty, "Should have control implementations")
    }

    func testImplementationStructure() {
        let ac2Impl = AnigmaControlImplementations.AC2_Implementation

        XCTAssertEqual(ac2Impl.controlId, "AC-2")
        XCTAssertEqual(ac2Impl.frameworkId, "NIST-800-53-R5")
        XCTAssertEqual(ac2Impl.implementationType, .technical)
        XCTAssertFalse(ac2Impl.implementingModules.isEmpty)
        XCTAssertFalse(ac2Impl.statement.isEmpty)
        XCTAssertFalse(ac2Impl.evidenceSources.isEmpty)
        XCTAssertEqual(ac2Impl.status, .implemented)
    }

    func testEvidenceSourceTypes() {
        let impl = AnigmaControlImplementations.AC2_Implementation

        let auditSource = impl.evidenceSources.first { $0.evidenceType == .auditLog }
        XCTAssertNotNil(auditSource)
        XCTAssertFalse(auditSource!.sourceId.isEmpty)
        XCTAssertFalse(auditSource!.description.isEmpty)
    }

    // MARK: - Control Registry Tests

    func testControlRegistryInitialization() async {
        let registry = ControlRegistry()

        // Check controls are loaded
        let ac2 = await registry.getControl("AC-2")
        XCTAssertNotNil(ac2)
        XCTAssertEqual(ac2?.controlId, "AC-2")

        // Check implementations are loaded
        let impl = await registry.getImplementation(for: "AC-2")
        XCTAssertNotNil(impl)
    }

    func testControlRegistryBaseline() async {
        let registry = ControlRegistry()

        let lowControls = await registry.getControlsForBaseline(.low)
        XCTAssertFalse(lowControls.isEmpty)
    }

    func testCoverageStatistics() async {
        let registry = ControlRegistry()

        let coverage = await registry.getCoverageStatistics(for: .moderate)

        XCTAssertGreaterThan(coverage.totalControls, 0)
        XCTAssertGreaterThanOrEqual(coverage.implemented, 0)
        XCTAssertGreaterThanOrEqual(coverage.compliancePercentage, 0)
        XCTAssertLessThanOrEqual(coverage.compliancePercentage, 100)
    }

    // MARK: - Continuous Monitoring Tests

    func testProbeRegistration() async {
        let service = ContinuousMonitoringService()

        let probe = ControlProbe(
            probeId: "test.probe",
            controlIds: ["AC-2"],
            name: "Test Probe",
            description: "A test probe",
            frequency: .hourly
        ) {
            return ProbeResult.healthy(
                probeId: "test.probe",
                summary: "All good"
            )
        }

        await service.registerProbe(probe)

        let probes = await service.getProbes()
        XCTAssertEqual(probes.count, 1)
        XCTAssertEqual(probes.first?.probeId, "test.probe")
    }

    func testProbeExecution() async {
        let service = ContinuousMonitoringService()

        var executionCount = 0
        let probe = ControlProbe(
            probeId: "test.probe",
            controlIds: ["AC-2"],
            name: "Test Probe",
            description: "A test probe",
            frequency: .hourly
        ) {
            executionCount += 1
            return ProbeResult.healthy(
                probeId: "test.probe",
                summary: "Execution \(executionCount)"
            )
        }

        await service.registerProbe(probe)

        let result = await service.runProbe("test.probe")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.status, .healthy)
        XCTAssertEqual(result?.score, 1.0)
        XCTAssertEqual(executionCount, 1)
    }

    func testOverallStatus() async {
        let service = ContinuousMonitoringService()

        // Add healthy probe
        await service.registerProbe(ControlProbe(
            probeId: "healthy.probe",
            controlIds: ["AC-2"],
            name: "Healthy",
            description: "Healthy probe"
        ) {
            return ProbeResult.healthy(probeId: "healthy.probe", summary: "OK")
        })

        // Add degraded probe
        await service.registerProbe(ControlProbe(
            probeId: "degraded.probe",
            controlIds: ["AU-2"],
            name: "Degraded",
            description: "Degraded probe"
        ) {
            return ProbeResult.degraded(
                probeId: "degraded.probe",
                score: 0.7,
                summary: "Some issues",
                issues: [ProbeIssue(severity: .medium, description: "Test issue")]
            )
        })

        _ = await service.runAllProbes()

        let status = await service.getOverallStatus()

        XCTAssertEqual(status.probeCount, 2)
        XCTAssertEqual(status.healthyCount, 1)
        XCTAssertEqual(status.degradedCount, 1)
        XCTAssertEqual(status.status, .degraded) // Worst case
    }

    func testControlStatus() async {
        let service = ContinuousMonitoringService()

        await service.registerProbe(ControlProbe(
            probeId: "ac2.probe",
            controlIds: ["AC-2"],
            name: "AC-2 Probe",
            description: "Tests AC-2"
        ) {
            return ProbeResult.healthy(probeId: "ac2.probe", summary: "OK")
        })

        _ = await service.runProbe("ac2.probe")

        let controlStatus = await service.getControlStatus()

        XCTAssertNotNil(controlStatus["AC-2"])
        XCTAssertEqual(controlStatus["AC-2"]?.status, .healthy)
    }

    // MARK: - Standard Probes Tests

    func testAccountManagementProbe() async {
        let probe = StandardProbes.accountManagementProbe {
            return (staleAccounts: 0, totalAccounts: 100, recentDeprovisionings: 5)
        }

        XCTAssertEqual(probe.probeId, "probe.ac2.account_review")
        XCTAssertTrue(probe.controlIds.contains("AC-2"))

        let result = try? await probe.evaluator()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.status, .healthy)
    }

    func testAuditIntegrityProbe() async {
        let probe = StandardProbes.auditIntegrityProbe {
            return (verified: true, entriesChecked: 1000, failures: 0)
        }

        let result = try? await probe.evaluator()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.status, .healthy)
        XCTAssertEqual(result?.score, 1.0)
    }

    func testAuditIntegrityProbeFailure() async {
        let probe = StandardProbes.auditIntegrityProbe {
            return (verified: false, entriesChecked: 1000, failures: 3)
        }

        let result = try? await probe.evaluator()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.status, .failing)
        XCTAssertEqual(result?.score, 0.0)
        XCTAssertFalse(result?.issues.isEmpty ?? true)
    }

    func testBackupComplianceProbe() async {
        let probe = StandardProbes.backupComplianceProbe {
            return (lastBackupAge: 3600, targetRPO: 86400, backupSuccess: true) // 1 hour old, 24 hour RPO
        }

        let result = try? await probe.evaluator()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.status, .healthy)
    }

    func testBackupComplianceProbeRPOBreach() async {
        let probe = StandardProbes.backupComplianceProbe {
            return (lastBackupAge: 172800, targetRPO: 86400, backupSuccess: true) // 48 hours old, 24 hour RPO
        }

        let result = try? await probe.evaluator()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.status, .failing)
        XCTAssertFalse(result?.issues.isEmpty ?? true)
    }

    // MARK: - Document Generation Tests

    func testSSPGeneration() async {
        let registry = ControlRegistry()
        let monitoring = ContinuousMonitoringService()
        let generator = ComplianceDocumentGenerator(
            controlRegistry: registry,
            monitoringService: monitoring
        )

        let context = DocumentGenerationContext(
            tenantId: "test-tenant",
            environmentId: "test-env",
            frameworkId: "NIST-800-53-R5",
            baseline: .moderate,
            periodStart: Date().addingTimeInterval(-30 * 24 * 3600),
            periodEnd: Date(),
            generatedBy: UUID(),
            organization: OrganizationInfo(name: "Test Organization"),
            system: SystemInfo(
                name: "Test System",
                version: "1.0",
                description: "A test system",
                authorizationBoundary: "Test boundary"
            )
        )

        let ssp = await generator.generateSSP(context: context, format: .markdown)

        XCTAssertEqual(ssp.documentType, .systemSecurityPlan)
        XCTAssertEqual(ssp.format, .markdown)
        XCTAssertFalse(ssp.content.isEmpty)
        XCTAssertTrue(ssp.content.contains("System Security Plan"))
        XCTAssertTrue(ssp.content.contains("Test System"))
    }

    func testPOAMGeneration() async {
        let registry = ControlRegistry()
        let monitoring = ContinuousMonitoringService()
        let generator = ComplianceDocumentGenerator(
            controlRegistry: registry,
            monitoringService: monitoring
        )

        let context = DocumentGenerationContext(
            tenantId: "test-tenant",
            environmentId: "test-env",
            periodStart: Date().addingTimeInterval(-30 * 24 * 3600),
            periodEnd: Date(),
            generatedBy: UUID(),
            organization: OrganizationInfo(name: "Test Org"),
            system: SystemInfo(name: "Test", version: "1.0", description: "Test", authorizationBoundary: "Test")
        )

        let poam = await generator.generatePOAM(context: context, format: .markdown)

        XCTAssertEqual(poam.documentType, .poam)
        XCTAssertFalse(poam.content.isEmpty)
        XCTAssertTrue(poam.content.contains("Plan of Action"))
    }

    func testVPATGeneration() async {
        let registry = ControlRegistry()
        let monitoring = ContinuousMonitoringService()
        let generator = ComplianceDocumentGenerator(
            controlRegistry: registry,
            monitoringService: monitoring
        )

        let context = DocumentGenerationContext(
            tenantId: "test-tenant",
            environmentId: "test-env",
            periodStart: Date().addingTimeInterval(-30 * 24 * 3600),
            periodEnd: Date(),
            generatedBy: UUID(),
            organization: OrganizationInfo(name: "Test Org"),
            system: SystemInfo(name: "Test", version: "1.0", description: "Test", authorizationBoundary: "Test")
        )

        let vpat = await generator.generateVPAT(context: context, wcagLevel: .aa, format: .markdown)

        XCTAssertEqual(vpat.documentType, .vpat)
        XCTAssertFalse(vpat.content.isEmpty)
        XCTAssertTrue(vpat.content.contains("Accessibility"))
        XCTAssertTrue(vpat.content.contains("WCAG"))
    }

    func testConMonReportGeneration() async {
        let registry = ControlRegistry()
        let monitoring = ContinuousMonitoringService()
        let generator = ComplianceDocumentGenerator(
            controlRegistry: registry,
            monitoringService: monitoring
        )

        // Add a probe and run it
        await monitoring.registerProbe(ControlProbe(
            probeId: "test.probe",
            controlIds: ["AC-2"],
            name: "Test",
            description: "Test"
        ) {
            return ProbeResult.healthy(probeId: "test.probe", summary: "OK")
        })
        _ = await monitoring.runAllProbes()

        let context = DocumentGenerationContext(
            tenantId: "test-tenant",
            environmentId: "test-env",
            periodStart: Date().addingTimeInterval(-30 * 24 * 3600),
            periodEnd: Date(),
            generatedBy: UUID(),
            organization: OrganizationInfo(name: "Test Org"),
            system: SystemInfo(name: "Test", version: "1.0", description: "Test", authorizationBoundary: "Test")
        )

        let report = await generator.generateConMonReport(context: context, format: .markdown)

        XCTAssertEqual(report.documentType, .conMonReport)
        XCTAssertFalse(report.content.isEmpty)
        XCTAssertTrue(report.content.contains("Continuous Monitoring"))
    }

    // MARK: - Compliance Module Integration Tests

    func testComplianceModuleInitialization() async {
        let auditLog = AuditLog()
        let infrastructure = await ComplianceModule.initialize(auditLog: auditLog)

        XCTAssertNotNil(infrastructure.controlRegistry)
        XCTAssertNotNil(infrastructure.monitoringService)
        XCTAssertNotNil(infrastructure.documentGenerator)
    }

    func testComplianceModuleSummaries() {
        let nistSummary = ComplianceModule.getNIST80053Summary()
        let wcagSummary = ComplianceModule.getWCAG21Summary()

        XCTAssertEqual(nistSummary.framework.frameworkId, "NIST-800-53-R5")
        XCTAssertGreaterThan(nistSummary.totalControls, 0)

        XCTAssertEqual(wcagSummary.framework.frameworkId, "WCAG-2.1")
        XCTAssertGreaterThan(wcagSummary.totalControls, 0)
    }

    func testComplianceServiceAssessment() async {
        let auditLog = AuditLog()
        let infrastructure = await ComplianceModule.initialize(auditLog: auditLog)
        let service = ComplianceService(infrastructure: infrastructure)

        // Register a probe
        await infrastructure.monitoringService.registerProbe(
            StandardProbes.auditIntegrityProbe {
                return (verified: true, entriesChecked: 100, failures: 0)
            }
        )

        let assessment = await service.runAssessment(
            tenantId: "test",
            environmentId: "test-env",
            baseline: .moderate
        )

        XCTAssertFalse(assessment.assessmentId.uuidString.isEmpty)
        XCTAssertEqual(assessment.tenantId, "test")
        XCTAssertEqual(assessment.baseline, .moderate)
    }

    // MARK: - ComplianceValue Tests

    func testComplianceValueEncoding() throws {
        let values: [String: ComplianceValue] = [
            "string": .string("test"),
            "int": .int(42),
            "double": .double(3.14),
            "bool": .bool(true),
            "null": .null,
            "array": .array([.int(1), .int(2)]),
            "dict": .dictionary(["nested": .string("value")])
        ]

        let data = try JSONEncoder().encode(values)
        let decoded = try JSONDecoder().decode([String: ComplianceValue].self, from: data)

        XCTAssertEqual(decoded["string"], .string("test"))
        XCTAssertEqual(decoded["int"], .int(42))
        XCTAssertEqual(decoded["bool"], .bool(true))
    }
}
