//
//  CutoverCommands.swift
//  HarmoniaV2CLI
//
//  Export commands for PostgreSQL cutover bundles.
//

import ArgumentParser
import DatabaseCore
import Foundation

struct CutoverCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "cutover",
            abstract: "Export a source database as a PostgreSQL cutover bundle",
            subcommands: [
                ExportCommand.self
            ]
        )
    }
}

struct ExportCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "export",
            abstract: "Generate a PostgreSQL-ready cutover manifest and seed script"
        )
    }

    @Argument(help: "Path to the source database to export")
    var source: String

    @Option(name: .shortAndLong, help: "Path to write the JSON manifest")
    var manifest: String?

    @Option(name: .shortAndLong, help: "Path to write the PostgreSQL seed script")
    var script: String?

    func run() async throws {
        let bundle = try await PostgresCutoverUtility.buildBundle(sourcePath: source)

        if let manifest {
            let url = URL(fileURLWithPath: manifest)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(bundle.manifest)
            try data.write(to: url, options: .atomic)
            print("🧾 Wrote manifest: \(url.path)")
        } else {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(bundle.manifest)
            print(String(data: data, encoding: .utf8) ?? "")
        }

        if let script {
            let url = URL(fileURLWithPath: script)
            guard let data = bundle.postgresScript.data(using: .utf8) else {
                throw ValidationError("Unable to encode PostgreSQL seed script as UTF-8")
            }
            try data.write(to: url, options: .atomic)
            print("📝 Wrote seed script: \(url.path)")
        } else {
            print("\n-- PostgreSQL seed script --")
            print(bundle.postgresScript)
        }

        print("\n✅ Tables exported: \(bundle.manifest.tables.count)")
        print("✅ Rows exported: \(bundle.manifest.totalRows)")
    }
}
