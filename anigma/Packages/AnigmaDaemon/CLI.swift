//
//  CLI.swift
//  AnigmaDaemon
//
//  Created as part of P0 Epic: Unify Under anigmad with Warm Subprocess Pooling (td-12f9d2)
//  Phase 2: Direct integration of HarmoniaV2CLI and AnigmaCLIExecutable (td-80575e)
//

import ArgumentParser
import Foundation
import HarmoniaV2CLIKernel
import HarmoniaRuntime
import AnigmaCore
import GovernanceCore

// MARK: - CLI Error

struct CLIError: Error, CustomStringConvertible {
    let message: String
    
    var description: String {
        return message
    }
}

// MARK: - Runtime Commands (from HarmoniaV2CLI)

struct RuntimeStatusCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Check HarmoniaRuntime health/status."
    )
    
    mutating func run() async throws {
        let status = HarmoniaRuntime.status()
        print("HarmoniaRuntime status")
        print("   Health: \(status.health.rawValue)")
        print("   Summary: \(status.summary)")
        print("   Query/session: \(status.querySession.rawValue)")
        print("   Memory/context: \(status.memoryContext.rawValue)")
        print("   Receipts/observability: \(status.receiptsObservability.rawValue)")
        print("   Orchestration: \(status.orchestration.rawValue)")
        if !status.notes.isEmpty {
            print("   Notes:")
            for note in status.notes {
                print("   - \(note)")
            }
        }
    }
}

struct RuntimeInferCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "infer",
        abstract: "Run inference computation (pure, no writes)"
    )
    
    @Argument(help: "Text to process")
    var text: String
    
    @Option(help: "User ID for context")
    var userId: String = "cli-user"
    
    mutating func run() async throws {
        print("Running HarmoniaRuntime inference...")
        
        do {
            let result = try await HarmoniaRuntime.query(text, userId: userId)
            
            print("Inference complete:")
            print("   Answer: \(result.answer)")
            print("   Sources: \(result.sources.joined(separator: ", "))")
            print("   Confidence: \(String(format: "%.2f", result.confidence))")
            
        } catch let error as HarmoniaError {
            if case .notImplemented(let msg) = error {
                print("Deferred: \(msg)")
                print("   Route: HarmoniaRuntime")
            } else {
                print("Inference failed: \(error)")
                throw ExitCode.failure
            }
        } catch {
            print("Inference failed: \(error)")
            throw ExitCode.failure
        }
    }
}

struct RuntimeRememberCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "remember",
        abstract: "Store a memory through HarmoniaRuntime."
    )
    
    @Argument(help: "Memory content")
    var content: String
    
    @Option(help: "User ID")
    var userId: String = "cli-user"
    
    @Option(help: "Source label")
    var source: String = "harmonia-cli"
    
    mutating func run() async throws {
        do {
            let memoryID = try await HarmoniaRuntime.remember(
                content: content,
                userId: userId,
                source: source
            )
            
            print("Memory stored")
            print("   ID: \(memoryID)")
            print("   Source: \(source)")
            print("   User: \(userId)")
        } catch {
            print("Failed to store memory: \(error)")
            throw ExitCode.failure
        }
    }
}

struct RuntimeToolCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "tool",
        abstract: "Execute a governed HarmoniaRuntime tool."
    )
    
    @Argument(help: "Registered tool name")
    var name: String
    
    @Option(name: .customLong("arg"), help: "Tool argument as key=value. May be repeated.")
    var rawArguments: [String] = []
    
    @Option(help: "User ID")
    var userId: String = "cli-user"
    
    @Option(help: "Policy context")
    var policyContext: String = "harmonia.cli.tool"
    
    mutating func run() async throws {
        let arguments: [String: String] = Dictionary(uniqueKeysWithValues: rawArguments.compactMap { raw -> (String, String)? in
            guard let separator = raw.firstIndex(of: "=") else { return nil }
            let key = String(raw[..<separator])
            let value = String(raw[raw.index(after: separator)...])
            return key.isEmpty ? nil : (key, value)
        })
        
        let result = try await HarmoniaRuntime.executeTool(
            name: name,
            arguments: arguments,
            userId: userId,
            policyContext: policyContext
        )
        
        print("HarmoniaRuntime tool")
        print("   Name: \(result.toolName)")
        print("   Success: \(result.success)")
        if let error = result.error, !error.isEmpty {
            print("   Error: \(error)")
        }
        if !result.output.isEmpty {
            print("   Output:")
            print(result.output)
        }
        
        if !result.success {
            throw ExitCode.failure
        }
    }
}

struct RuntimeDocumentCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "document",
        abstract: "Run HarmoniaRuntime document-analysis lane."
    )
    
    @Argument(help: "Document-analysis objective")
    var objective: String
    
    @Option(help: "User ID")
    var userId: String = "cli-user"
    
    @Option(help: "Policy context")
    var policyContext: String = "harmonia.cli.document"
    
    mutating func run() async throws {
        let result = try await HarmoniaRuntime.executePhase9(
            objective: objective,
            userId: userId,
            policyContext: policyContext
        )
        
        print("HarmoniaRuntime document analysis")
        print("   Disposition: \(result.disposition.rawValue)")
        print("   Reason: \(result.reasonCode.rawValue)")
        print("   Summary: \(result.summary)")
        if !result.nextActions.isEmpty {
            print("   Next actions:")
            for action in result.nextActions {
                print("   - \(action)")
            }
        }
        print("   Receipt: \(result.receipt.receiptID)")
        
        if result.disposition == .failed {
            throw ExitCode.failure
        }
    }
}

struct RuntimePolicyCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "policy",
        abstract: "Evaluate a HarmoniaRuntime governance policy decision."
    )
    
    @Option(help: "Principal requesting action")
    var principal: String
    
    @Option(help: "Resource being accessed")
    var resource: String
    
    @Option(help: "Action being evaluated")
    var action: String
    
    @Option(name: .customLong("attr"), help: "Policy attribute as key=value. May be repeated.")
    var rawAttributes: [String] = []
    
    @Option(help: "User ID")
    var userId: String = "cli-user"
    
    @Option(help: "Policy context")
    var policyContext: String = "harmonia.cli.policy"
    
    mutating func run() async throws {
        let attributes: [String: String] = Dictionary(uniqueKeysWithValues: rawAttributes.compactMap { raw -> (String, String)? in
            guard let separator = raw.firstIndex(of: "=") else { return nil }
            let key = String(raw[..<separator])
            let value = String(raw[raw.index(after: separator)...])
            return key.isEmpty ? nil : (key, value)
        })
        
        let result = try await HarmoniaRuntime.evaluatePolicy(
            principal: principal,
            resource: resource,
            action: action,
            userId: userId,
            policyContext: policyContext,
            attributes: attributes
        )
        
        print("HarmoniaRuntime policy")
        print("   Decision: \(result.decision.rawValue)")
        print("   Reason: \(result.reasonCode.rawValue)")
        print("   Regulated: \(result.regulatedDecision)")
        print("   Summary: \(result.summary)")
        print("   Receipt: \(result.receipt.receiptID)")
        if let recovery = result.recoverySuggestion, !recovery.isEmpty {
            print("   Recovery: \(recovery)")
        }
        
        if result.decision != .allow {
            throw ExitCode.failure
        }
    }
}

// MARK: - Mode Commands (from HarmoniaV2CLI)

struct ModeSetCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Set governance operating mode"
    )
    
    enum Mode: String, ExpressibleByArgument {
        case readOnly
        case assistive
        case autopilot
        
        var operatingMode: OperatingMode {
            switch self {
            case .readOnly: return .readOnly
            case .assistive: return .assistive
            case .autopilot: return .autopilot
            }
        }
    }
    
    @Argument(help: "Operating mode")
    var mode: Mode
    
    @Option(help: "Project ID (omit for global)")
    var projectId: String?
    
    @Option(help: "Principal setting the mode")
    var principal: String = "cli-admin"
    
    @Option(help: "Database path")
    var databasePath: String?
    
    mutating func run() async throws {
        let dbPath = databasePath ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("harmonia-cli.db").path
        
        print("Setting governance mode...")
        print("   Mode: \(mode.rawValue)")
        print("   Scope: \(projectId ?? "global")")
        print("   Principal: \(principal)")
        
        do {
            let config = CLIKernelConfig(
                databasePath: dbPath,
                enforceGovernance: true
            )
            
            try await CLIKernel.runSetMode(
                mode: mode.operatingMode,
                projectId: projectId,
                principal: principal,
                databasePath: dbPath
            )
            
            print("Mode set successfully")
            
            if mode == .readOnly {
                print("   Effect: All writes will be DENIED")
            } else {
                print("   Effect: Writes allowed per policy")
            }
            
        } catch {
            print("Failed to set mode: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

struct ModeShowCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Show effective governance mode"
    )
    
    @Option(help: "Project ID (omit for global)")
    var projectId: String?
    
    @Option(help: "Database path")
    var databasePath: String?
    
    mutating func run() async throws {
        let dbPath = databasePath ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("harmonia-cli.db").path
        
        do {
            let result = try await CLIKernel.runShowMode(
                projectId: projectId,
                databasePath: dbPath
            )
            
            print("Governance Mode Status")
            print("   Scope: \(projectId ?? "global")")
            print("   Effective mode: \(result.effectiveMode)")
            print("   Source: \(result.source.rawValue)")
            
            if result.effectiveMode == .readOnly {
                print("All writes currently DENIED")
            } else {
                print("Writes allowed per policy")
            }
            
        } catch {
            print("Failed to query mode: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

struct ModeClearCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "clear",
        abstract: "Clear project mode override (revert to global)"
    )
    
    @Argument(help: "Project ID")
    var projectId: String
    
    @Option(help: "Principal clearing the mode")
    var principal: String = "cli-admin"
    
    @Option(help: "Database path")
    var databasePath: String?
    
    mutating func run() async throws {
        let dbPath = databasePath ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("harmonia-cli.db").path
        
        do {
            try await CLIKernel.runClearMode(
                projectId: projectId,
                principal: principal,
                databasePath: dbPath
            )
            
            print("Project override cleared")
            print("   Effect: Will now use global mode")
            
        } catch {
            print("Failed to clear mode: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

struct ModeCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "mode",
        abstract: "Manage governance operating modes",
        subcommands: [
            ModeSetCommand.self,
            ModeShowCommand.self,
            ModeClearCommand.self
        ]
    )
}

// MARK: - Chunk Commands (from HarmoniaV2CLI)

struct ChunkIndexCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "index",
        abstract: "Index content into chunks"
    )
    
    @Argument(help: "Content to index")
    var content: String
    
    @Option(help: "File path")
    var filePath: String = "/unknown"
    
    @Option(help: "Project ID")
    var projectId: String
    
    @Option(help: "User ID")
    var userId: String = "cli-user"
    
    @Option(help: "Database path")
    var databasePath: String?
    
    @Flag(help: "Show detailed failure explanation")
    var explain: Bool = false
    
    mutating func run() async throws {
        let dbPath = databasePath ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("harmonia-cli.db").path
        
        let config = CLIKernelConfig(databasePath: dbPath, enforceGovernance: true)
        
        print("Indexing chunks...")
        
        do {
            let result = try await CLIKernel.runIndexChunks(
                content: content,
                filePath: filePath,
                projectId: projectId,
                userId: userId,
                config: config
            )
            
            print("Indexed \(result.count) chunks")
            print("   IDs: \(result.chunkIds.joined(separator: ", "))")
            
        } catch let error as GovernanceError {
            if case .writeBlocked(let violation) = error {
                print("Governance DENIED chunking")
                print("   Reason: \(violation.summaryMessage)")
                
                if explain {
                    print("   Violation ID: \(violation.id.uuidString)")
                    print("   Mode Source: \(violation.evaluatedModeSource ?? "unknown")")
                    print("   Checks: \(violation.failedChecks.map { $0.message }.joined(separator: ", "))")
                }
                
                print("   No data was written (fail-closed)")
                throw ExitCode.failure
            }
            print("Governance Error: \(error.localizedDescription)")
            throw ExitCode.failure
        } catch {
            print("Indexing failed: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

struct ChunkRecallCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "recall",
        abstract: "Recall chunks by similarity"
    )
    
    @Argument(help: "Query text")
    var query: String
    
    @Option(help: "Project ID")
    var projectId: String
    
    @Option(help: "Limit results")
    var topK: Int = 5
    
    @Option(help: "Maximum rows to scan")
    var scanLimit: Int?
    
    @Option(help: "Database path")
    var databasePath: String?
    
    @Flag(help: "Show detailed stats")
    var explain: Bool = false
    
    mutating func run() async throws {
        let dbPath = databasePath ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("harmonia-cli.db").path
        
        let config = CLIKernelConfig(databasePath: dbPath, enforceGovernance: false)
        
        print("Recalling chunks...")
        print("   Query: \(query)")
        print("   Project: \(projectId)")
        print("   Top K: \(topK)")
        if let scanLimit = scanLimit {
            print("   Scan Limit: \(scanLimit)")
        }
        
        do {
            let result = try await CLIKernel.runRecallChunks(
                query: query,
                projectId: projectId,
                topK: topK,
                scanLimit: scanLimit,
                config: config
            )
            
            print("Found \(result.results.count) chunks:")
            for (index, item) in result.results.enumerated() {
                print("   \(index + 1). [\(String(format: "%.2f", item.similarity))] \(item.filePath):\(item.range)")
                print("      \"\(item.content.prefix(50))...\"")
            }
            
            if explain {
                print("Rows Scanned: \(result.stats?.rowsScanned ?? 0)")
            }
            
        } catch {
            print("Recall failed: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

struct ChunkCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "chunk",
        abstract: "Manage code chunks",
        subcommands: [ChunkIndexCommand.self, ChunkRecallCommand.self]
    )
}

// MARK: - Kill Switch Commands (from HarmoniaV2CLI)

struct KillSwitchSetCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Engage kill switch"
    )
    
    @Option(help: "Project ID (omit for global)")
    var projectId: String?
    
    @Option(help: "Reason for activation")
    var reason: String = "Manual activation"
    
    @Option(help: "Principal")
    var principal: String = "cli-admin"
    
    @Option(help: "Database path")
    var databasePath: String?
    
    mutating func run() async throws {
        let dbPath = databasePath ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("harmonia-cli.db").path
        
        let config = CLIKernelConfig(databasePath: dbPath, enforceGovernance: true)
        
        print("Engaging kill switch...")
        
        do {
            try await CLIKernel.runKillSwitchSet(
                projectId: projectId,
                reason: reason,
                principal: principal,
                databasePath: dbPath
            )
            print("Kill switch activated")
            print("   Scope: \(projectId ?? "GLOBAL")")
            print("   Reason: \(reason)")
            print("   Effect: All writes blocked immediately")
            
        } catch {
            print("Failed to engage kill switch: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

struct KillSwitchShowCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Show kill switch status"
    )
    
    @Option(help: "Project ID")
    var projectId: String?
    
    @Option(help: "Database path")
    var databasePath: String?
    
    mutating func run() async throws {
        let dbPath = databasePath ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("harmonia-cli.db").path
        
        do {
            let status = try await CLIKernel.runKillSwitchShow(
                projectId: projectId,
                databasePath: dbPath
            )
            
            print("Kill Switch Status")
            print("   Scope: \(projectId ?? "GLOBAL/Effect")")
            
            if status.active {
                print("ACTIVE (Writes Blocked)")
                print("   Reason: \(status.reason ?? "Unknown")")
            } else {
                print("INACTIVE (Normal Operation)")
            }
            
        } catch {
            print("Failed to show status: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

struct KillSwitchClearCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "clear",
        abstract: "Clear kill switch (restore writes)"
    )
    
    @Option(help: "Project ID (omit for global)")
    var projectId: String?
    
    @Option(help: "Principal")
    var principal: String = "cli-admin"
    
    @Option(help: "Database path")
    var databasePath: String?
    
    mutating func run() async throws {
        let dbPath = databasePath ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("harmonia-cli.db").path
        
        do {
            try await CLIKernel.runKillSwitchClear(
                projectId: projectId,
                principal: principal,
                databasePath: dbPath
            )
            print("Kill switch disengaged")
            print("   Scope: \(projectId ?? "GLOBAL")")
            print("   Effect: Writes restored (subject to operating mode)")
            
        } catch {
            print("Failed to clear kill switch: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

struct KillSwitchCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "kill-switch",
        abstract: "Emergency kill switch management",
        subcommands: [
            KillSwitchSetCommand.self,
            KillSwitchShowCommand.self,
            KillSwitchClearCommand.self
        ]
    )
}

// MARK: - Memory Commands (from HarmoniaV2CLI)

struct MemoAddCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "memo",
        abstract: "Add memory item (governed write, routes through Authorities)"
    )
    
    @Argument(help: "Memory content")
    var content: String
    
    @Option(help: "User ID")
    var userId: String = "cli-user"
    
    @Option(help: "Project ID for governance scoping")
    var projectId: String?
    
    @Option(help: "Session ID")
    var sessionId: String?
    
    @Flag(help: "Show detailed failure explanation")
    var explain: Bool = false
    
    mutating func run() async throws {
        print("Adding memory via HarmoniaV2 (governed)...")
        
        let tempDBPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("harmonia-cli.db").path
        
        let config = CLIKernelConfig(
            databasePath: tempDBPath,
            enforceGovernance: true
        )
        
        do {
            let result = try await CLIKernel.runMemo(
                content: content,
                userId: userId,
                projectId: projectId,
                sessionId: sessionId,
                config: config
            )
            
            print("Memory stored successfully!")
            print("   ID: \(result.memoryId)")
            print("   UserId: \(result.userId)")
            print("   ProjectId: \(result.projectId ?? "none")")
            print("   SessionId: \(result.sessionId)")
            print("   Content: \(content)")
            print("Governance check: PASSED")
        } catch let error as GovernanceError {
            if case .writeBlocked(let violation) = error {
                print("Governance DENIED write")
                print("   Reason: \(violation.summaryMessage)")
                
                if explain {
                    print("   Violation ID: \(violation.id.uuidString)")
                    print("   Mode Source: \(violation.evaluatedModeSource ?? "unknown")")
                    print("   Checks: \(violation.failedChecks.map { $0.message }.joined(separator: ", "))")
                } else {
                    print("   Checks: \(violation.failedChecks.map { $0.message }.joined(separator: ", "))")
                    print("   (Use --explain for full provenance)")
                }
                
                print("   No data was written (fail-closed)")
                throw ExitCode.failure
            }
            print("Governance Error: \(error.localizedDescription)")
            throw ExitCode.failure
        } catch {
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

struct RecallCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "recall",
        abstract: "Recall memories by semantic similarity (hybrid)"
    )
    
    @Argument(help: "Query text")
    var query: String
    
    @Option(help: "Project ID")
    var projectId: String
    
    @Option(help: "Limit results")
    var topK: Int = 5
    
    @Option(help: "Maximum rows to scan")
    var scanLimit: Int?
    
    @Option(help: "Database path")
    var databasePath: String?
    
    @Flag(help: "Show detailed provenance (ranking scores, timing)")
    var explain: Bool = false
    
    mutating func run() async throws {
        let dbPath = databasePath ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("harmonia-cli.db").path
        
        let config = CLIKernelConfig(databasePath: dbPath, enforceGovernance: false)
        
        print("Recalling memories...")
        print("   Query: \(query)")
        print("   Project: \(projectId)")
        print("   Top K: \(topK)")
        if let scanLimit = scanLimit {
            print("   Scan Limit: \(scanLimit)")
        }
        
        do {
            let result = try await CLIKernel.runHybridRecall(
                query: query,
                projectId: projectId,
                topK: topK,
                scanLimit: scanLimit,
                config: config
            )
            
            print("Found \(result.results.count) results (Total time: \(String(format: "%.3fs", result.totalTime))):")
            
            for (index, item) in result.results.enumerated() {
                let tags = item.tags.joined(separator: ", ")
                print("   \(index + 1). [\(tags)] \(item.content) (ID: \(item.id))")
                
                if explain {
                    print("      Score: \(String(format: "%.4f", item.score))")
                    if let vr = item.vectorRank { print("      Vector Rank: #\(vr)") }
                    if let fr = item.ftsRank { print("      FTS Rank: #\(fr)") }
                    if let rrf = item.rrfScore { print("      RRF Score: \(String(format: "%.4f", rrf))") }
                }
            }
            
            if explain {
                print("Timing Breakdown:")
                print("   Embedding: \(String(format: "%.3fs", result.embeddingTime))")
                print("   DB Query:  \(String(format: "%.3fs", result.dbQueryTime))")
                print("   Fusion:    \(String(format: "%.3fs", result.fusionTime))")
                
                print("Recall Stats:")
                print("   Rows Scanned: \(result.rowsScanned)")
                print("   Execution Time: \(String(format: "%.3fs", result.totalTime))")
            }
            
        } catch {
            print("Recall failed: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

// MARK: - Maintenance Commands (from HarmoniaV2CLI)

struct RebuildFTSCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "rebuild-fts",
        abstract: "Rebuild FTS index from source of truth"
    )
    
    @Option(help: "Project ID to rebuild (optional)")
    var projectId: String?
    
    @Option(help: "Database path")
    var databasePath: String?
    
    @Flag(help: "Show detailed failure explanation")
    var explain: Bool = false
    
    mutating func run() async throws {
        let dbPath = databasePath ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("harmonia-cli.db").path
        
        let config = CLIKernelConfig(databasePath: dbPath, enforceGovernance: true)
        
        print("Rebuilding FTS Index...")
        print("   Scope: \(projectId ?? "GLOBAL")")
        
        do {
            let count = try await CLIKernel.runRebuildFTS(
                projectId: projectId,
                config: config
            )
            
            print("FTS Rebuild Complete")
            print("   Rows affected: \(count)")
            
        } catch let error as GovernanceError {
            if case .writeBlocked(let violation) = error {
                print("Governance DENIED maintenance")
                print("   Reason: \(violation.summaryMessage)")
                
                if explain {
                    print("   Checks: \(violation.failedChecks.map { $0.message }.joined(separator: ", "))")
                }
                
                throw ExitCode.failure
            }
            throw ExitCode.failure
        } catch {
            print("Rebuild failed: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

struct MaintenanceCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "maintenance",
        abstract: "System maintenance tools",
        subcommands: [RebuildFTSCommand.self]
    )
}

// MARK: - CLI Command Structure

/// Main CLI command for anigmad
struct AnigmaCLI: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "anigmad",
        abstract: "Anigma Daemon - Unified entry point for all Anigma operations",
        subcommands: [
            // Runtime commands
            RuntimeStatusCommand.self,
            RuntimeInferCommand.self,
            RuntimeRememberCommand.self,
            RuntimeToolCommand.self,
            RuntimeDocumentCommand.self,
            RuntimePolicyCommand.self,
            
            // Memory commands
            MemoAddCommand.self,
            RecallCommand.self,
            
            // Mode commands
            ModeCommand.self,
            
            // Chunk commands
            ChunkCommand.self,
            
            // Kill switch commands
            KillSwitchCommand.self,
            
            // Maintenance commands
            MaintenanceCommand.self
        ],
        defaultSubcommand: nil
    )
    
    @Flag(name: [.customShort("h"), .long], help: "Show help for available commands")
    var showHelp = false
    
    mutating func run() async throws {
        if showHelp {
            print(AnigmaCLI.helpMessage())
        }
    }
}

// MARK: - Public API

/// Run CLI mode
func runCLI() async throws {
    var command = AnigmaCLI.parseOrExit()
    try await command.run()
}

/// Check if arguments indicate CLI mode
func isCLIMode(arguments: [String]) -> Bool {
    // CLI mode is indicated by subcommands like "cli", "infer", "status", etc.
    // or by not having daemon-specific flags
    
    let cliCommands = [
        "cli", "infer", "status", "remember", "tool", "document", "policy",
        "memo", "recall", "mode", "chunk", "kill-switch", "maintenance",
        "rebuild-fts", "set", "show", "clear", "index"
    ]
    
    // Check if any argument (after the program name) is a CLI command
    let args = Array(arguments.dropFirst())
    
    // Debug: print arguments
    // print("DEBUG: Checking CLI mode for args: \(args)")
    
    for arg in args {
        if cliCommands.contains(arg) {
            return true
        }
    }
    
    // Also check for help
    if args.contains("--help") || args.contains("-h") {
        return true
    }
    
    return false
}
