//
//  TechDebtCommand.swift
//  HarmoniaCLI
//
//  [Brief description of file purpose]
//

import ArgumentParser
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

    @OptionGroup var output: OutputOptions

    func run() async throws {
        let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let audit = TechDebtAudit(rootURL: rootURL)
        let report = try audit.runAudit()

        if output.format == .json {
            let payload = TechDebtAuditPayload(
                markers: report.markers,
                entries: report.entries,
                missingIDs: report.missingDocIDs.map { TechDebtIssue(id: $0.id, file: $0.file, line: $0.line, snippet: $0.snippet) },
                orphanedIDs: report.orphanedDocIDs.map { TechDebtEntryPayload(id: $0.id, title: $0.title, line: $0.line, metadata: $0.metadata) }
            )
            try OutputWriter.emit(command: "harmonia techdebt audit", payload: payload, format: .json, status: report.success ? "ok" : "error")
        } else {
            print("TechDebt audit: \(report.markers.count) STUB_TRACK markers, \(report.entries.count) TechDebt entries")
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

        if !report.success {
            throw CLIError(message: "TechDebt audit failed. See report above.")
        }
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
