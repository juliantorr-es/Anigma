//
//  HarmoniaCommands.swift
//  HarmoniaCLI - HarmoniaV2 Integration
//
//  Proof-of-concept: runtime-controlled compute, write, governance, and orchestration entrypoints
//

import ArgumentParser
import Foundation
import HarmoniaRuntime

// MARK: - 1. Pure Compute Command (No Write)

struct InferCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "infer",
        abstract: "Run inference computation (pure, no writes)"
    )
    
    @Argument(help: "Text to process")
    var text: String
    
    @Option(help: "User ID for context")
    var userId: String = "cli-user"
    
    mutating func run() async throws {
        print("🧠 Running HarmoniaRuntime inference...")

        do {
            let result = try await HarmoniaRuntime.query(text, userId: userId)

            print("✅ Inference complete:")
            print("   Answer: \(result.answer)")
            if !result.sources.isEmpty {
                print("   Sources: \(result.sources.joined(separator: ", "))")
            }
            print("   Confidence: \(String(format: "%.2f", result.confidence))")
        } catch let HarmoniaRuntimeError.notConfigured(capability, reason) {
            print("⚠️  \(capability) unavailable: \(reason)")
            print("   The query path is routed through HarmoniaRuntime and still under migration.")
            throw ExitCode.failure
        }
    }
}

// MARK: - 2. Governed Write Command (Routed Through Authorities)

struct MemoAddCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "memo-add",
        abstract: "Add memory item (governed write, routes through Authorities)"
    )
    
    @Argument(help: "Memory content")
    var content: String
    
    @Option(help: "User ID")
    var userId: String = "cli-user"
    
    @Option(help: "Project ID for governance scoping")
    var projectId: String?
    
    mutating func run() async throws {
        print("💾 Adding memory via HarmoniaRuntime (governed)...")

        // This should route through Authorities (stubbed for now)
        // In production: facade.addMemory() → MemoryManager → DataAuthority → governance check
        do {
            // Placeholder: Real implementation needs Authority wiring
            print("⚠️  Memory write stubbed - needs Authority adapter wiring")
            print("   Would call: DataAuthority.store()")
            print("   Governance check: OperatingMode + KillSwitch")
            print("   Context: userId=\(userId), projectId=\(projectId ?? "none")")
            
            // Simulate governance check for demo
            print("   Mock result: Write would be governed ✅")
            
        } catch {
            print("❌ Memory add failed: \(error)")
            throw ExitCode.failure
        }
    }
}

// MARK: - 3. Mode Toggle Command (Governance Controller)

struct ModeCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "mode",
        abstract: "Set governance operating mode (readOnly|assistive|autopilot)"
    )
    
    enum Mode: String, ExpressibleByArgument {
        case readOnly
        case assistive
        case autopilot
    }
    
    @Argument(help: "Operating mode")
    var mode: Mode
    
    @Option(help: "Principal setting the mode")
    var principal: String = "cli-admin"
    
    mutating func run() async throws {
        print("🔒 Setting governance mode...")
        
        // This should call daemon's GovernanceController
        // For proof-of-concept, we'll show what would happen
        
        let modeStr = mode.rawValue
        print("   Mode: \(modeStr)")
        print("   Principal: \(principal)")
        
        // TODO: Wire to daemon IPC or in-process PlatformRuntime
        // For now, demonstrate the contract
        print("⚠️  Mode change stubbed - needs daemon IPC")
        print("   Would call: governanceController.setMode(.\(modeStr), by: \"\(principal)\")")
        print("   Effect: All writes checked against \(modeStr) mode")
        
        // In readOnly mode, memo-add should fail
        if mode == .readOnly {
            print("   Note: 'harmonia memo-add' will now be denied ❌")
        } else {
            print("   Note: 'harmonia memo-add' will be allowed ✅")
        }
    }
}

// MARK: - 4. Governed Phase9 Command (Runtime Facade)

struct Phase9Command: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "phase9",
        abstract: "Run governed Phase9 orchestration through HarmoniaConductor."
    )

    @Argument(help: "Objective to route through the Phase9 facade.")
    var objective: String

    @Option(help: "User ID for governance context")
    var userId: String = "cli-user"

    @Option(help: "Optional policy context for receipt metadata")
    var policyContext: String?

    @OptionGroup var output: OutputOptions

    mutating func run() async throws {
        let result = try await HarmoniaRuntime.executePhase9(
            objective: objective,
            userId: userId,
            policyContext: policyContext
        )

        switch output.format {
        case .text:
            print("🔄 Phase9 via HarmoniaConductor")
            print("   Disposition: \(result.disposition.rawValue)")
            print("   Summary: \(result.summary)")
            print("   Receipt: \(result.receipt.receiptID) [\(result.receipt.decision.rawValue)]")
            print("   Audit: \(result.auditEvent.correlationID)")
            if let errorDescription = result.errorDescription {
                print("   Error: \(errorDescription)")
            }
            if let recoverySuggestion = result.recoverySuggestion {
                print("   Recovery: \(recoverySuggestion)")
            }
            if !result.nextActions.isEmpty {
                print("   Next actions:")
                for action in result.nextActions {
                    print("     - \(action)")
                }
            }
        case .json:
            try OutputWriter.emit(
                command: "harmonia v2 phase9",
                payload: result,
                format: output.format,
                status: result.disposition == .failed ? "error" : "ok"
            )
        }

        if result.disposition == .failed {
            throw ExitCode.failure
        }
    }
}

// MARK: - HarmoniaV2 Command Group

struct HarmoniaV2Command: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "v2",
        abstract: "HarmoniaV2 commands (proof-of-concept)",
        subcommands: [
            InferCommand.self,
            MemoAddCommand.self,
            ModeCommand.self,
            Phase9Command.self,
            ReceiptTestCommand.self
        ]
    )
}
