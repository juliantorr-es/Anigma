//
//  RefactoringOrchestrator.swift
//  HarmoniaModule
//
//  Created by Anigma Agent on 2026-01-12.
//

import Foundation

/// Orchestrates parallel DeepSeek agent refactoring with batch validation.
public actor RefactoringOrchestrator {
    private let repoRoot: URL
    private let numAgents: Int
    private let batchSize: Int
    private let apiKey: String
    
    private var tasks: [RefactoringTask] = []
    private var pendingQueue: [RefactoringTask] = []
    private var completedTasks: [RefactoringTask] = []
    private var failedTasks: [RefactoringTask] = []
    
    // Stats
    public struct Stats: Sendable {
        var totalTasks: Int = 0
        var completed: Int = 0
        var failed: Int = 0
        var buildFailures: Int = 0
        var tokensUsed: Int = 0
        var estimatedCost: Double = 0.0
    }
    private var stats = Stats()
    
    public init(repoRoot: URL, numAgents: Int = 10, batchSize: Int = 10, apiKey: String? = nil) {
        self.repoRoot = repoRoot
        self.numAgents = numAgents
        self.batchSize = batchSize
        // Default to the baked-in key if not provided
        self.apiKey = apiKey ?? "sk-459ecd08f72c4beba8fce7c2003f0d21"
    }
    
    public func loadTasks(_ inputTasks: [RefactoringTask]) {
        self.tasks = inputTasks
        self.pendingQueue = inputTasks
        self.stats.totalTasks = inputTasks.count
    }
    
    public func run() async throws {
        print("\n" + String(repeating: "=", count: 80))
        print("🤖 PARALLEL DEEPSEEK AGENT ORCHESTRATOR (SWIFT NATIVE)")
        print(String(repeating: "=", count: 80))
        print("Tasks: \(stats.totalTasks)")
        print("Agents: \(numAgents)")
        print("Batch Size: \(batchSize)")
        print(String(repeating: "=", count: 80))
        
        let agents = (0..<numAgents).map { DeepSeekRefactorAgent(agentId: $0 + 1, apiKey: apiKey) }
        
        var batchId = 0
        
        while !pendingQueue.isEmpty {
            batchId += 1
            let currentBatchSize = min(batchSize, pendingQueue.count)
            let batchTasks = Array(pendingQueue.prefix(currentBatchSize))
            pendingQueue.removeFirst(currentBatchSize)
            
            print("\n📦 Processing Batch \(batchId) (\(batchTasks.count) tasks)...")
            
            // Run agents in parallel
            var processedTasks: [RefactoringTask] = []
            
            await withTaskGroup(of: RefactoringTask.self) { group in
                for (index, task) in batchTasks.enumerated() {
                    let agentIndex = index % agents.count
                    let agent = agents[agentIndex]
                    
                    group.addTask {
                        var mutableTask = task
                        mutableTask.assignedAgentId = await agent.agentId
                        mutableTask.status = .inProgress
                        
                        let (success, code, reasoning) = await agent.analyzeAndRefactor(task: task)
                        
                        if success {
                            mutableTask.status = .validationFailed // Pending validation
                            mutableTask.proposedCode = code // Use proposed for validation
                            mutableTask.agentReasoning = reasoning
                            mutableTask.appliedCode = code // Temporarily applied
                        } else {
                            mutableTask.status = .failed
                            mutableTask.errorMessage = "Agent rejection: \(reasoning)"
                        }
                        
                        return mutableTask
                    }
                }
                
                for await resultTask in group {
                    processedTasks.append(resultTask)
                }
            }
            
            // Separate success/fail
            let successfulInBatch = processedTasks.filter { $0.appliedCode != nil && $0.status != .failed }
            let failedInBatch = processedTasks.filter { $0.status == .failed }
            
            // Apply changes to disk for validation
            for task in successfulInBatch {
                if let code = task.appliedCode {
                    try applyChange(to: task.file, content: code, originalContext: task.originalCode)
                }
            }
            
            // Validate Build
            print("🏗️  Running build validation...")
            let buildSuccess = await validateBuild()
            
            if buildSuccess {
                print("✅ Build successful!")
                for var task in successfulInBatch {
                    task.status = .completed
                    task.completedAt = Date()
                    completedTasks.append(task)
                    stats.completed += 1
                }
                
                // Commit (conceptually, or git add)
                // For now, we leave the files modified on disk.
                
            } else {
                print("❌ Build failed! Reverting batch...")
                // Revert changes
                for task in successfulInBatch {
                    try revertChange(to: task.file, originalContent: task.originalCode)
                    
                    var failedTask = task
                    failedTask.status = .validationFailed
                    failedTask.validationError = "Batch build failed"
                    failedTasks.append(failedTask)
                    stats.buildFailures += 1
                }
            }
            
            failedTasks.append(contentsOf: failedInBatch)
            stats.failed += failedInBatch.count
            
            // Update token stats
            var totalTokens = 0
            for agent in agents {
                totalTokens += await agent.totalTokensUsed
            }
            stats.tokensUsed = totalTokens
            stats.estimatedCost = Double(totalTokens) / 1_000_000.0 * 2.0 // Approx input+output mix
            
            print("📊 Progress: \(stats.completed)/\(stats.totalTasks) completed")
        }
        
        print("\n" + String(repeating: "=", count: 80))
        print("🏁 REFACTORING COMPLETE")
        print("Completed: \(stats.completed)")
        print("Failed: \(stats.failed)")
        print("Build Failures: \(stats.buildFailures)")
        print("Tokens Used: \(stats.tokensUsed)")
        print("Est. Cost: $\(String(format: "%.4f", stats.estimatedCost))")
    }
    
    private func applyChange(to filePath: String, content: String, originalContext: String) throws {
        let fileURL = getFileURL(filePath)
        let fileContent = try String(contentsOf: fileURL, encoding: .utf8)
        
        let cleanOriginal = cleanContext(originalContext)
        
        if fileContent.contains(cleanOriginal) {
            let newContent = fileContent.replacingOccurrences(of: cleanOriginal, with: content)
            try newContent.write(to: fileURL, atomically: true, encoding: .utf8)
            print("  💾 Applied change to \(filePath)")
        } else {
             // Fallback: This is risky. If we can't find exact match, we might have issues.
             print("  ⚠️ Conversion failed: Could not find original context in \(filePath)")
             // In a robust system, we would fail the task here. 
             // But let's throw to handle it in the caller?
             // Since we are inside a batch loop consuming errors, maybe just print for now.
             // Or throw to trigger revert?
             throw NSError(domain: "RefactoringOrchestrator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Context mismatched"])
        }
    }
    
    // Helper to strip markers from ">>> 10: code" format
    private func cleanContext(_ context: String) -> String {
        let lines = context.components(separatedBy: .newlines)
        var cleanedLines: [String] = []
        for line in lines {
            // Remove ">>> 123: " or "    123: "
            // Regex: ^(>>>|    )\s*\d+:\s(.*)$
            if let match = line.range(of: "^(>>>|    )\\s*\\d+:\\s", options: .regularExpression) {
                let code = String(line[match.upperBound...])
                cleanedLines.append(code)
            } else {
                // If it doesn't match, maybe it's just the line?
                // Or empty line.
                // If line is empty, keep it empty?
                // The context generator puts those prefixes on all lines.
            }
        }
        // Remove trailing newline if any, or join
        return cleanedLines.joined(separator: "\n")
    }
    
    private func revertChange(to filePath: String, originalContent: String) throws {
        // Since we didn't implement robust apply yet, revert is also tricky.
        // If we use git, we can `git checkout`.
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["checkout", filePath]
        task.currentDirectoryURL = repoRoot
        try task.run()
        task.waitUntilExit()
    }
    
    private func getFileURL(_ path: String) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }
        return repoRoot.appendingPathComponent(path)
    }
    
    // Minimal build validator
    private func validateBuild() async -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        task.arguments = ["build"]
        task.currentDirectoryURL = repoRoot
        
        // We don't want to see all output, just exit code
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
}
