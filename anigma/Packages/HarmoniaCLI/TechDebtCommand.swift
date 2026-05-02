//
//  TechDebtCommand.swift
//  HarmoniaCLI
//
//  [Brief description of file purpose]
//

import ArgumentParser
import DatabaseCore
import Foundation
import TechDebtAudit

struct TechDebt: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "techdebt",
        abstract: "Tech debt tracking utilities",
        subcommands: [Audit.self]
    )
}

struct Audit: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "audit",
        abstract: "Verify STUB_TRACK markers are tracked in Docs/TechDebt.md"
    )

    @Option(name: .shortAndLong, help: "Path to doctrine database")
    var dbPath: String = DatabaseConfiguration.defaultDatabasePath()

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let audit = TechDebtAudit(rootURL: rootURL)
        let report = try audit.runAudit()

        // Get doctrine counts
        let doctrine = DoctrineCommands(dbPath: dbPath)
        let doctrineCounts = try? await doctrine.getSummaryCounts()

        let critical = doctrineCounts?.severity["critical"] ?? 0
        let high = (doctrineCounts?.severity["high"] ?? 0) + report.missingDocIDs.count
        let medium = doctrineCounts?.severity["medium"] ?? 0
        let low = (doctrineCounts?.severity["low"] ?? 0) + report.orphanedDocIDs.count
        
        var categories = doctrineCounts?.rules ?? [:]
        if report.missingDocIDs.count > 0 {
            categories["Documentation Gap"] = report.missingDocIDs.count
        }
        if report.orphanedDocIDs.count > 0 {
            categories["Orphaned Documentation"] = report.orphanedDocIDs.count
        }

        if output.format == .json {
            let response = TechDebtAuditResponse(
                totalIssues: critical + high + medium + low,
                criticalIssues: critical,
                highIssues: high,
                mediumIssues: medium,
                lowIssues: low,
                categories: categories
            )
            try OutputWriter.emit(command: "harmonia techdebt audit", payload: response, format: .json, status: "ok")
        } else {
            print("TechDebt audit: \(report.markers.count) STUB_TRACK markers, \(report.entries.count) TechDebt entries")
            if let dc = doctrineCounts {
                print("Doctrine: \(dc.severity.values.reduce(0, +)) violations found")
            }
            
            if !report.missingDocIDs.isEmpty {
                print("\nMissing TechDebt entries (code markers without doc):")
                for marker in report.missingDocIDs {
                    print("  - \(marker.id) in \(marker.file):\(marker.line)")
                }
            }
            if !report.orphanedDocIDs.isEmpty {
                print("\nOrphaned TechDebt entries (doc IDs without code markers):")
                for entry in report.orphanedDocIDs {
                    print("  - \(entry.id) (line \(entry.line))")
                }
            }
            if report.success {
                print("\n✅ TechDebt audit passed.")
            }
        }

        // We no longer throw an error here because the command is now about reporting state, 
        // and we want the client to receive the JSON report even if there are issues.
    }
}

struct TechDebtIssue: Encodable {
    let id: String
    let file: String
    let line: Int
    let snippet: String
}

struct TechDebtEntryPayload: Encodable {
    let id: String
    let title: String?
    let line: Int
    let metadata: String
}

struct TechDebtAuditPayload: Encodable {
    let markers: [StubMarker]
    let entries: [TechDebtEntry]
    let missingIDs: [TechDebtIssue]
    let orphanedIDs: [TechDebtEntryPayload]
}
