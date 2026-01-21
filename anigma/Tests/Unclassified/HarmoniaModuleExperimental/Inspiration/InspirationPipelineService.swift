//
//  InspirationPipelineService.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Inspiration
//
//  Service that runs the inspiration pipeline to generate tasks.
//

import Foundation
import HarmoniaModule

private func logInfo(_ message: String, category: String) {
    print("[INFO][\(category)] \(message)")
}

private func logWarning(_ message: String, category: String) {
    print("[WARNING][\(category)] \(message)")
}

/// Service that runs the inspiration pipeline.
public actor InspirationPipelineService {
    private let indexStore: InspirationIndexStore
    private let stateStore: InspirationStateStore
    private let gatekeeper: InspirationGatekeeper

    public init(
        indexStore: InspirationIndexStore,
        stateStore: InspirationStateStore,
        gatekeeper: InspirationGatekeeper
    ) {
        self.indexStore = indexStore
        self.stateStore = stateStore
        self.gatekeeper = gatekeeper
    }

    /// Run the full inspiration pipeline.
    public func runPipeline() async throws -> [InspirationTask] {
        print("[INFO][InspirationPipelineService] Starting inspiration pipeline")

        // 1. Check for new patterns
        try await checkForNewPatterns()

        // 2. Generate proposals from patterns
        let newProposals = try await generateProposals()

        // 3. Generate tasks from proposals
        let newTasks = try await generateTasks(from: newProposals)

        // 4. Update pipeline state
        try await updatePipelineState(newProposals: newProposals.count, newTasks: newTasks.count)

        logInfo("Inspiration pipeline completed: \(newProposals.count) proposals, \(newTasks.count) tasks", category: "InspirationPipelineService")

        return newTasks
    }

    /// Check for new patterns and update proposals.
    private func checkForNewPatterns() async throws {
        logInfo("Checking for new patterns", category: "InspirationPipelineService")

        // Get all patterns
        let allKinds = InspirationPattern.PatternKind.allCases
        var totalPatterns = 0

        for kind in allKinds {
            let patterns = try await indexStore.getPatternsByKind(kind)
            totalPatterns += patterns.count
        }

        // Update last pattern check time
        try await stateStore.updateState(lastPatternCheck: Date())

        logInfo("Found \(totalPatterns) total patterns", category: "InspirationPipelineService")
    }

    /// Generate proposals from patterns.
    private func generateProposals() async throws -> [PatternProposal] {
        logInfo("Generating proposals from patterns", category: "InspirationPipelineService")

        // Get all patterns
        let allKinds = InspirationPattern.PatternKind.allCases
        var newProposals: [PatternProposal] = []

        for kind in allKinds {
            let patterns = try await indexStore.getPatternsByKind(kind)

            for pattern in patterns {
                // Check if proposal already exists for this pattern
                let existingProposals = try await indexStore.getProposals(forPattern: pattern.id)
                if !existingProposals.isEmpty {
                    continue // Skip patterns that already have proposals
                }

                // Generate proposal based on pattern kind
                let proposal = try await generateProposal(for: pattern)
                try await indexStore.saveProposal(proposal)
                newProposals.append(proposal)
            }
        }

        logInfo("Generated \(newProposals.count) new proposals", category: "InspirationPipelineService")
        return newProposals
    }

    /// Generate a proposal for a specific pattern.
    private func generateProposal(for pattern: InspirationPattern) async throws -> PatternProposal {
        // Determine target component based on pattern kind
        let targetComponent = determineTargetComponent(for: pattern)
        let proposalType = determineProposalType(for: pattern)
        let priority = determinePriority(for: pattern)

        let description = generateProposalDescription(for: pattern)
        let suggestedImplementation = generateSuggestedImplementation(for: pattern)

        return PatternProposal(
            patternId: pattern.id,
            targetComponent: targetComponent,
            proposalType: proposalType,
            description: description,
            suggestedImplementation: suggestedImplementation,
            priority: priority
        )
    }

    /// Determine target component for a pattern.
    private func determineTargetComponent(for pattern: InspirationPattern) -> String {
        switch pattern.kind {
        case .architecture:
            return "AnigmaCore/Architecture"
        case .astTraversal:
            return "AnigmaASTServices"
        case .ruleDesign:
            return "HarmoniaModule/MigrationRules"
        case .pipeline:
            return "AnigmaCore/Pipeline"
        case .caching:
            return "HarmoniaModule/Inference"
        case .cli:
            return "HarmoniaCLI"
        case .config:
            return "AnigmaCore/Utilities"
        case .tooling:
            return "HarmoniaModule/Tools"
        case .testing:
            return "Tests"
        case .documentation:
            return "Docs"
        }
    }

    /// Determine proposal type for a pattern.
    private func determineProposalType(for pattern: InspirationPattern) -> PatternProposal.ProposalType {
        switch pattern.kind {
        case .architecture:
            return .architectureChange
        case .astTraversal, .ruleDesign:
            return .newRule
        case .pipeline, .caching:
            return .optimization
        case .cli, .config, .tooling:
            return .newService
        case .testing, .documentation:
            return .refactor
        }
    }

    /// Determine priority for a pattern.
    private func determinePriority(for pattern: InspirationPattern) -> PatternProposal.Priority {
        // Higher priority for architecture and pipeline patterns
        switch pattern.kind {
        case .architecture, .pipeline:
            return .high
        case .astTraversal, .ruleDesign:
            return .medium
        case .caching, .cli:
            return .medium
        case .config, .tooling, .testing, .documentation:
            return .low
        }
    }

    /// Generate proposal description.
    private func generateProposalDescription(for pattern: InspirationPattern) -> String {
        return "Implement \(pattern.kind.rawValue) pattern: \(pattern.description)"
    }

    /// Generate suggested implementation.
    private func generateSuggestedImplementation(for pattern: InspirationPattern) -> String {
        return """
        Based on pattern from \(pattern.language) code.
        Example snippet:
        \(pattern.exampleSnippet)

        Apply this pattern to improve \(determineTargetComponent(for: pattern)).
        """
    }

    /// Generate tasks from proposals.
    private func generateTasks(from proposals: [PatternProposal]) async throws -> [InspirationTask] {
        logInfo("Generating tasks from \(proposals.count) proposals", category: "InspirationPipelineService")

        var newTasks: [InspirationTask] = []

        for proposal in proposals {
            // Check if task already exists for this proposal
            let existingTasks = try await stateStore.getTasks(byStatus: nil)
            if existingTasks.contains(where: { $0.proposalId == proposal.id }) {
                continue // Skip proposals that already have tasks
            }

            // Generate task based on proposal type
            let task = try await generateTask(for: proposal)
            try await stateStore.saveTask(task)
            newTasks.append(task)
        }

        logInfo("Generated \(newTasks.count) new tasks", category: "InspirationPipelineService")
        return newTasks
    }

    /// Generate a task for a specific proposal.
    private func generateTask(for proposal: PatternProposal) async throws -> InspirationTask {
        let taskType = determineTaskType(for: proposal)
        let description = generateTaskDescription(for: proposal)

        return InspirationTask(
            proposalId: proposal.id,
            taskType: taskType,
            description: description,
            targetComponent: proposal.targetComponent,
            priority: proposal.priority
        )
    }

    /// Determine task type for a proposal.
    private func determineTaskType(for proposal: PatternProposal) -> InspirationTask.TaskType {
        switch proposal.proposalType {
        case .newRule:
            return .implementRule
        case .refactor:
            return .refactorCode
        case .newService:
            return .addService
        case .architectureChange:
            return .updateArchitecture
        case .optimization:
            return .optimizePerformance
        }
    }

    /// Generate task description.
    private func generateTaskDescription(for proposal: PatternProposal) -> String {
        return "\(proposal.description) - \(proposal.suggestedImplementation)"
    }

    /// Update pipeline state with new counts.
    private func updatePipelineState(newProposals: Int, newTasks: Int) async throws {
        let currentState = try await stateStore.getState()

        let updatedState = InspirationPipelineState(
            id: currentState.id,
            lastPatternCheck: currentState.lastPatternCheck,
            pendingProposalCount: currentState.pendingProposalCount + newProposals,
            implementedProposalCount: currentState.implementedProposalCount,
            blockedProposalCount: currentState.blockedProposalCount,
            lastTaskGeneration: Date()
        )

        try await stateStore.saveState(updatedState)
    }

    /// Get pending tasks.
    public func getPendingTasks() async throws -> [InspirationTask] {
        return try await stateStore.getPendingTasks()
    }

    /// Get pipeline status.
    public func getStatus() async throws -> (InspirationPipelineState, Int) {
        let state = try await stateStore.getState()
        let pendingTasks = try await stateStore.getPendingTasks()
        return (state, pendingTasks.count)
    }

    /// Mark a task as completed.
    public func markTaskCompleted(_ taskId: UUID) async throws {
        try await stateStore.updateTaskStatus(taskId, status: .completed)

        // Update proposal status
        if let task = try await stateStore.getTask(byId: taskId) {
            // In a real implementation, we would update the proposal status
            // For now, just log it
            logInfo("Task \(taskId) marked as completed", category: "InspirationPipelineService")
        }
    }

    /// Mark a task as failed.
    public func markTaskFailed(_ taskId: UUID, errorMessage: String) async throws {
        try await stateStore.updateTaskStatus(taskId, status: .failed, errorMessage: errorMessage)
        logWarning("Task \(taskId) marked as failed: \(errorMessage)", category: "InspirationPipelineService")
    }

    /// Get task by ID.
    public func getTask(byId taskId: UUID) async throws -> InspirationTask? {
        return try await stateStore.getTask(byId: taskId)
    }

    /// Get all tasks.
    public func getAllTasks() async throws -> [InspirationTask] {
        return try await stateStore.getTasks(byStatus: nil)
    }
}
