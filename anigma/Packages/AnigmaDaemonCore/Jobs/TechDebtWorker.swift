//
//  TechDebtWorker.swift
//  AnigmaDaemonCore
//
//  Worker for auditing technical debt markers in the codebase.
//

import Foundation
import AnigmaCore
import TechDebtAudit
import ContractsCore

/// Configuration for technical debt audit job.
public struct TechDebtConfig: Codable, Sendable {
    public let repoRoot: String
    
    public init(repoRoot: String) {
        self.repoRoot = repoRoot
    }
}

/// Worker that audits technical debt markers.
public struct TechDebtWorker: JobWorker {
    public static let kind = "audit.tech_debt"
    
    public init() {}
    
    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        // 1. Decode Configuration
        let auditConfig = try JSONDecoder().decode(TechDebtConfig.self, from: config)
        
        // 2. Prepare Audit
        let auditor = TechDebtAudit(rootURL: URL(fileURLWithPath: auditConfig.repoRoot))
        
        // 3. Run Audit
        let report = try auditor.runAudit()
        
        // 4. Package Results
        let resultData = try JSONEncoder().encode(TechDebtAuditReportPayload(report))
        return [
            JobOutputPayload(
                data: resultData,
                mediaType: "application/json",
                kind: "tech_debt.report"
            )
        ]
    }
}

private struct TechDebtAuditReportPayload: Codable, Sendable {
    let markers: [StubMarker]
    let entries: [TechDebtEntry]
    let missingDocIDs: [TechDebtIssue]
    let orphanedDocIDs: [TechDebtEntryPayload]
    let success: Bool

    init(_ report: TechDebtAuditReport) {
        self.markers = report.markers
        self.entries = report.entries
        self.missingDocIDs = report.missingDocIDs
        self.orphanedDocIDs = report.orphanedDocIDs
        self.success = report.success
    }
}
