//
//  ToolCommand.swift
//  HarmoniaCLI
//
//  Commands for auditing tool calls and manual loop recovery.
//

import AnigmaPrimitives
import ArgumentParser
import DatabaseCore
import Foundation
import HarmoniaModule
import HarmoniaV2Surface

struct ToolCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "tool",
            abstract: "Work with file-backed Harmonia tool calls and recovery.",
            subcommands: [Status.self, Recover.self, Trust.self]
        )
    }

    struct Trust: AsyncParsableCommand {
        static var configuration: CommandConfiguration {
            CommandConfiguration(
                commandName: "trust",
                abstract: "Manage trusted external tool binaries.",
                subcommands: [TrustAdd.self, TrustRemove.self, TrustList.self, TrustVerify.self]
            )
        }
    }

    struct TrustAdd: AsyncParsableCommand {
        static var configuration: CommandConfiguration { CommandConfiguration(commandName: "add") }

        @Argument(help: "Path to the tool binary.")
        var path: String

        mutating func run() async throws {
            let verifier = ExternalToolVerifier(repoRoot: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
            let tool = try await verifier.trust(path: path)
            print("✅ Trusted tool: \(tool.path)")
            print("   BLAKE3: \(tool.artifactHash)")
        }
    }

    struct TrustRemove: AsyncParsableCommand {
        static var configuration: CommandConfiguration { CommandConfiguration(commandName: "remove") }

        @Argument(help: "Path to the tool binary.")
        var path: String

        mutating func run() async throws {
            let verifier = ExternalToolVerifier(repoRoot: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
            try await verifier.revoke(path: path)
            print("✅ Revoked trust for: \(path)")
        }
    }

    struct TrustList: AsyncParsableCommand {
        static var configuration: CommandConfiguration { CommandConfiguration(commandName: "list") }

        mutating func run() async throws {
            let verifier = ExternalToolVerifier(repoRoot: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
            let tools = try await verifier.listTrustedTools()

            if tools.isEmpty {
                print("No trusted tools.")
                return
            }

            print("Trusted Tools:")
            for tool in tools {
                print("- \(tool.path)")
                print("  BLAKE3: \(tool.artifactHash)")
                print("  Added: \(tool.addedAt)")
                print("  By: \(tool.addedBy)")
                print("")
            }
        }
    }

    struct TrustVerify: AsyncParsableCommand {
        static var configuration: CommandConfiguration { CommandConfiguration(commandName: "verify") }

        @Argument(help: "Path to the tool binary.")
        var path: String

        mutating func run() async throws {
            let verifier = ExternalToolVerifier(repoRoot: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
            let isTrusted = try await verifier.verify(path: path)

            if isTrusted {
                print("✅ Tool is trusted and verified.")
            } else {
                print("❌ Tool is NOT trusted or hash mismatch.")
                throw ExitCode.failure
            }
        }
    }

    struct Status: AsyncParsableCommand {
        static var configuration: CommandConfiguration {
            CommandConfiguration(
                commandName: "status",
                abstract: "Show status and evidence for a specific tool call."
            )
        }

        @Argument(help: "The tool call ID (evidence_id) to inspect.")
        var toolCallId: String

        mutating func run() async throws {
            let db: any DatabaseExecutor = DatabaseActor(path: DatabaseConfiguration.defaultDatabasePath())
            try await db.open()

            let callRows = try await db.query(
                """
                    SELECT * FROM tool_calls WHERE id = ?
                """, parameters: [DatabaseParameter.text(toolCallId)])

            guard let call = callRows.first else {
                print("Error: Tool call not found: \(toolCallId)")
                return
            }

            print("🛠️ Tool Call: \(call.string(for: "tool_name") ?? "unknown")")
            print("  ID: \(toolCallId)")
            print("  Status: \(call.string(for: "status") ?? "unknown")")
            print("  Started: \(call.int(for: "started_at") ?? 0)")
            print("  Completed: \(call.int(for: "completed_at") ?? 0)")
            print("  Input Hash: \(call.string(for: "input_hash") ?? "none")")

            if let outputHash = call.string(for: "output_hash"), !outputHash.isEmpty {
                print("  Output Hash: \(outputHash)")
            }

            if let diagnosis = call.string(for: "error_signature"), !diagnosis.isEmpty {
                print("  Diagnosis: \(diagnosis)")
            }

            // Check for loop events
            let loopRows = try await db.query(
                """
                    SELECT * FROM loop_events WHERE tool_call_id = ?
                """, parameters: [DatabaseParameter.text(toolCallId)])

            if !loopRows.isEmpty {
                print("\n🔄 Loop Prevention Events:")
                for event in loopRows {
                    print("  - Type: \(event.string(for: "event_type") ?? "unknown")")
                    print("    Strategy: \(event.string(for: "recovery_strategy") ?? "none")")
                    if let justification = event.string(for: "manual_justification") {
                        print("    Unblocked: \(justification)")
                    }
                }
            }

            // Check for artifacts
            let artifacts = try await db.query(
                """
                    SELECT * FROM tool_call_artifacts WHERE tool_call_id = ?
                """, parameters: [DatabaseParameter.text(toolCallId)])

            if !artifacts.isEmpty {
                print("\n📦 Artifacts:")
                for artifact in artifacts {
                    print("  - Type: \(artifact.string(for: "artifact_type") ?? "unknown")")
                    print("    Path: \(artifact.string(for: "artifact_path") ?? "unknown")")
                    print("    Hash: \(artifact.string(for: "content_hash") ?? "unknown")")
                    print("    Size: \(artifact.int(for: "size_bytes") ?? 0) bytes")
                }
            }
        }
    }

    struct Recover: AsyncParsableCommand {
        static var configuration: CommandConfiguration {
            CommandConfiguration(
                commandName: "recover",
                abstract: "Manually unblock a tool call loop with a justification."
            )
        }

        @Argument(help: "The tool call ID to unblock.")
        var toolCallId: String

        @Option(name: .shortAndLong, help: "Reason for unblocking the loop.")
        var reason: String

        mutating func run() async throws {
            let db: any DatabaseExecutor = DatabaseActor(path: DatabaseConfiguration.defaultDatabasePath())
            try await db.open()

            // Verify the tool call exists
            let callRows = try await db.query(
                "SELECT id FROM tool_calls WHERE id = ?",
                parameters: [DatabaseParameter.text(toolCallId)])
            guard !callRows.isEmpty else {
                print("Error: Tool call not found: \(toolCallId)")
                return
            }

            // Find the most recent loop event for this call
            let loopRows = try await db.query(
                """
                    SELECT id FROM loop_events WHERE tool_call_id = ? ORDER BY created_at DESC LIMIT 1
                """, parameters: [DatabaseParameter.text(toolCallId)])

            guard let event = loopRows.first else {
                print("Error: No loop event found for tool call: \(toolCallId)")
                return
            }

            let eventId = event.string(for: "id") ?? ""

            // Update with manual justification and timestamp
            try await db.execute(
                """
                    UPDATE loop_events SET
                        manual_justification = ?,
                        unblocked_at = ?
                    WHERE id = ?
                """,
                parameters: [
                    DatabaseParameter.text(reason),
                    DatabaseParameter.int(Int(Date().timeIntervalSince1970)),
                    DatabaseParameter.text(eventId)
                ])

            print("✅ Manual recovery recorded for \(toolCallId).")
            print("   Justification: \(reason)")
        }
    }
}
