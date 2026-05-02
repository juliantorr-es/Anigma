//
//  RefactorCommand.swift
//  HarmoniaCLI
//
//  Created by Anigma Agent on 2026-01-12.
//

import ArgumentParser
import Foundation
import HarmoniaModule
import HarmoniaV2Surface

public struct Refactor: AsyncParsableCommand {
    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "refactor",
            abstract: "Analyze and refactor code using AI agents",
            subcommands: [
                RefactorScan.self
            ]
        )
    }
    
    public init() {}
}

struct RefactorScan: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "scan",
            abstract: "Scan for SwiftLint violations and auto-refactor them"
        )
    }
    
    @Option(name: .shortAndLong, help: "Repository root path (defaults to current dir)")
    var path: String?
    
    @Option(name: .shortAndLong, help: "Number of parallel agents")
    var agents: Int = 10
    
    @Option(name: .shortAndLong, help: "Number of tasks per batch")
    var batchSize: Int = 10
    
    @Option(name: .shortAndLong, help: "Maximum number of tasks to process")
    var limit: Int = 1000
    
    @Option(name: .long, help: "DeepSeek API key (overrides default/env)")
    var apiKey: String?
    
    @Option(name: .long, help: "Filter by specific rule IDs (comma separated)")
    var rules: String?
    
    func run() async throws {
        print("🚀 Starting Refactor Scan...")
        
        // Determine repo root
        let repoRoot: URL
        if let path = path {
            repoRoot = URL(fileURLWithPath: path)
        } else {
            repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        }
        
        print("📂 Repository: \(repoRoot.path)")
        
        // 1. Scan
        let scanner = SwiftLintScanner(repoRoot: repoRoot)
        let ruleList = rules?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        let violations = try scanner.scanViolations(rules: ruleList, limit: limit)
        
        if violations.isEmpty {
            print("✅ No violations found.")
            return
        }
        
        let sessionId = Date().formatted(.iso8601).replacingOccurrences(of: ":", with: "-")
        let tasks = await scanner.generateRefactoringTasks(sessionId: sessionId)
        
        if tasks.isEmpty {
            print("⚠️ No refactoring tasks generated.")
            return
        }
        
        print("📋 Generated \(tasks.count) refactoring tasks.")
        
        // 2. Orchestrate
        let orchestrator = RefactoringOrchestrator(
            repoRoot: repoRoot,
            numAgents: agents,
            batchSize: batchSize,
            apiKey: apiKey
        )
        
        await orchestrator.loadTasks(tasks)
        
        print("⚡ Launching Orchestrator...")
        try await orchestrator.run()
    }
}
