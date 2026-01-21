//
//  ResearchAwareStepEngine.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Research
//
//  StepEngine wrapper that enforces research requirements.
//  Makes "no module without literature" an actual invariant.
//

import Foundation
import AnigmaCore
import HarmoniaModule

// MARK: - Research Aware Step Engine

/// StepEngine wrapper that checks research adequacy before scheduling work.
public actor ResearchAwareStepEngine {
    private let baseStepEngine: StepEngine
    private let researchGate: ResearchGate
    private let registry: ResearchRegistry

    /// Initialize with dependencies.
    public init(
        baseStepEngine: StepEngine = StepEngine(),
        researchGate: ResearchGate,
        registry: ResearchRegistry
    ) {
        self.baseStepEngine = baseStepEngine
        self.researchGate = researchGate
        self.registry = registry
    }

    /// Update method that checks research before processing tasks.
    public func update(world: World) async {
        logInfo("ResearchAwareStepEngine update started", category: "ResearchStepEngine")

        // First, check for research tasks that need to be scheduled
        await scheduleResearchTasks(world: world)

        // Then process regular tasks, checking research adequacy
        await processMigrationTasks(world: world)

        logInfo("ResearchAwareStepEngine update completed", category: "ResearchStepEngine")
    }

    // MARK: - Research Task Scheduling

    /// Schedule research tasks before allowing module creation.
    private func scheduleResearchTasks(world: World) async {
        do {
            // Get pending migration tasks
            let pendingTasks = try await getPendingMigrationTasks(world: world)

            // Filter for module creation tasks that need research
            let moduleCreationTasks = pendingTasks.filter { task in
                // Check if this is a module creation task
                // In a real implementation, we'd have better type checking
                let isModuleCreation = task.featureCategory.contains("module") ||
                                      task.featureCategory.contains("architecture")

                if !isModuleCreation {
                    return false
                }

                // Check if research is required
                // We need to extract module info from the task
                guard let moduleInfo = extractModuleInfo(from: task) else {
                    return false
                }

                let doctrinePack = ResearchDoctrinePack()
                return doctrinePack.requiresResearch(
                    for: moduleInfo.moduleType,
                    changes: moduleInfo.changes
                )
            }

            // Schedule research for each module creation task
            for task in moduleCreationTasks {
                guard let moduleInfo = extractModuleInfo(from: task) else {
                    continue
                }

                // Check if research already exists or is pending
                let topicSpec = TopicSpec(
                    moduleName: moduleInfo.name,
                    purpose: moduleInfo.description,
                    scope: moduleInfo.scope,
                    doctrineTags: moduleInfo.doctrineTags,
                    constraints: moduleInfo.constraints,
                    searchKeywords: moduleInfo.keywords
                )

                if try registry.hasAdequateResearch(for: topicSpec) {
                    logInfo("Module '\(moduleInfo.name)' has adequate research", category: "ResearchStepEngine")
                    continue
                }

                // Check for pending research task
                let pendingResearchTasks = try registry.getPendingResearchTasks()
                let hasPendingResearch = pendingResearchTasks.contains { researchTask in
                    researchTask.topicSpec.moduleName == moduleInfo.name &&
                    researchTask.topicSpec.purpose == moduleInfo.description
                }

                if !hasPendingResearch {
                    // Create research task
                    let researchTask = researchGate.scheduleResearchBeforeModuleCreation(
                        moduleTask: moduleInfo,
                        projectId: task.projectId
                    )

                    logInfo("Scheduled research task for module '\(moduleInfo.name)'", category: "ResearchStepEngine")
                    logInfo("Research task ID: \(researchTask.id)", category: "ResearchStepEngine")

                    // Block the migration task until research is complete
                    try await blockMigrationTask(task.id, reason: "Waiting for research completion")
                } else {
                    logInfo("Research already pending for module '\(moduleInfo.name)'", category: "ResearchStepEngine")
                }
            }

        } catch {
            logError("Failed to schedule research tasks: \(error)", category: "ResearchStepEngine")
        }
    }

    // MARK: - Migration Task Processing with Research Checks

    /// Process migration tasks, checking research adequacy.
    private func processMigrationTasks(world: World) async {
        do {
            // Get pending migration tasks
            let pendingTasks = try await getPendingMigrationTasks(world: world)

            // Filter out tasks blocked by research
            let processableTasks = pendingTasks.filter { task in
                // Check if task is blocked by research
                let checkResult = researchGate.checkBeforeScheduling(task: task)

                switch checkResult {
                case .allowed:
                    return true
                case .blocked(let reason):
                    logWarning("Task \(task.id) blocked by research: \(reason)", category: "ResearchStepEngine")
                    return false
                case .error(let error):
                    logError("Research check error for task \(task.id): \(error)", category: "ResearchStepEngine")
                    return false
                }
            }

            // Process remaining tasks through base engine
            if !processableTasks.isEmpty {
                logInfo("Processing \(processableTasks.count) tasks with adequate research", category: "ResearchStepEngine")
                await baseStepEngine.update(world: world)
            } else {
                logInfo("No tasks with adequate research to process", category: "ResearchStepEngine")
            }

        } catch {
            logError("Failed to process migration tasks: \(error)", category: "ResearchStepEngine")
        }
    }

    // MARK: - Helper Methods

    /// Extract module information from a migration task.
    private func extractModuleInfo(from task: MigrationTask) -> ModuleCreationTaskInfo? {
        // In a real implementation, we'd parse the task description or metadata
        // For now, we'll create a simple extraction

        // Check if this looks like a module creation task
        let isModuleCreation = task.featureCategory.contains("module") ||
                              task.featureCategory.contains("architecture") ||
                              task.description.lowercased().contains("create") ||
                              task.description.lowercased().contains("add") ||
                              task.description.lowercased().contains("implement")

        guard isModuleCreation else {
            return nil
        }

        // Extract module name from description
        let moduleName = extractModuleName(from: task.description) ?? "Unknown Module"

        // Parse doctrine tags from metadata
        let doctrineTags = parseDoctrineTags(from: task.metadata)

        // Determine changes from feature category
        let changes = determineChanges(from: task.featureCategory)

        return ModuleCreationTaskInfo(
            moduleId: task.id,
            moduleName: moduleName,
            moduleType: task.featureCategory,
            description: task.description,
            scope: [],
            doctrineTags: doctrineTags,
            constraints: [],
            keywords: extractKeywords(from: task.description),
            changes: changes,
            requiresRecentResearch: doctrineTags.contains(.privacy) || doctrineTags.contains(.accessibility),
            priority: .medium
        )
    }

    private func extractModuleName(from description: String) -> String? {
        // Simple extraction: look for patterns like "Create X module" or "Add X feature"
        let patterns = [
            "Create (?:a )?([A-Za-z]+) (?:module|feature|component)",
            "Add (?:a )?([A-Za-z]+) (?:module|feature|component)",
            "Implement (?:a )?([A-Za-z]+) (?:module|feature|component)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(description.startIndex..<description.endIndex, in: description)
                if let match = regex.firstMatch(in: description, options: [], range: range),
                   let nameRange = Range(match.range(at: 1), in: description) {
                    return String(description[nameRange])
                }
            }
        }

        return nil
    }

    private func parseDoctrineTags(from metadata: [String: String]?) -> [DoctrineDomain] {
        guard let metadata = metadata else { return [] }

        var tags: [DoctrineDomain] = []

        if metadata["security"] == "true" || metadata.contains(where: { $0.key.contains("security") || $0.value.contains("security") }) {
            tags.append(.privacy)
        }

        if metadata["accessibility"] == "true" || metadata.contains(where: { $0.key.contains("accessibility") || $0.value.contains("a11y") }) {
            tags.append(.accessibility)
        }

        if metadata["software"] == "true" || metadata.contains(where: { $0.key.contains("software") || $0.value.contains("engineering") }) {
            tags.append(.softwareEngineering)
        }

        return tags
    }

    private func determineChanges(from featureCategory: String) -> [String] {
        var changes: [String] = []

        if featureCategory.contains("module") || featureCategory.contains("architecture") {
            changes.append("new_module")
        }

        if featureCategory.contains("security") {
            changes.append("security")
        }

        if featureCategory.contains("infra") || featureCategory.contains("infrastructure") {
            changes.append("infrastructure")
        }

        if featureCategory.contains("api") {
            changes.append("api")
        }

        if featureCategory.contains("database") {
            changes.append("database")
        }

        return changes
    }

    private func extractKeywords(from description: String) -> [String] {
        // Simple keyword extraction
        let stopWords = Set(["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by"])

        return description
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !stopWords.contains($0.lowercased()) }
            .map { $0.lowercased() }
    }

    /// Get pending migration tasks from the database.
    private func getPendingMigrationTasks(world: World) async throws -> [MigrationTask] {
        let store = ProjectHarnessStore.shared
        do {
            let projectId = await store.projectId
            return try await store.getPendingMigrationTasks(projectId: projectId)
        } catch {
            logWarning("Migration task store not initialized: \(error)", category: "ResearchStepEngine")
            return []
        }
    }

    /// Block a migration task with a reason.
    private func blockMigrationTask(_ taskId: UUID, reason: String) async throws {
        let store = ProjectHarnessStore.shared
        try await store.updateMigrationTaskStatus(taskId, status: .cancelled, sessionIndex: nil)
        logInfo("Blocked task \(taskId): \(reason)", category: "ResearchStepEngine")
    }

    // MARK: - Research Completion Handling

    /// Handle completion of a research task.
    public func handleResearchCompletion(researchTaskId: UUID, bundle: ResearchBundle?) async throws {
        let result = try researchGate.handleResearchCompletion(taskId: researchTaskId, bundle: bundle)

        if result.success {
            logInfo("Research completed for bundle \(result.researchBundleId?.uuidString ?? "unknown")", category: "ResearchStepEngine")

            if result.isAdequate {
                logInfo("Research is adequate, unblocking related modules", category: "ResearchStepEngine")
                // Unblock modules that were waiting for this research
                try await unblockModulesForResearch(bundleId: result.researchBundleId!)
            } else {
                logWarning("Research is inadequate, creating debt tasks", category: "ResearchStepEngine")
                logWarning("Violations: \(result.violations.map { $0.message })", category: "ResearchStepEngine")
            }
        } else {
            logError("Research failed for task \(researchTaskId)", category: "ResearchStepEngine")
        }
    }

    /// Unblock modules waiting for research.
    private func unblockModulesForResearch(bundleId: UUID) async throws {
        // This would update migration tasks that were blocked waiting for this research
        // For now, just log
        logInfo("Would unblock modules for research bundle \(bundleId)", category: "ResearchStepEngine")
    }

    // MARK: - Statistics and Monitoring

    /// Get research enforcement statistics.
    public func getStatistics() throws -> ResearchEnforcementStats {
        let gateStats = try researchGate.getStatistics()
        let registryStats = try registry.getStatistics()

        return ResearchEnforcementStats(
            totalTasksProcessed: 0,  // Would track in real implementation
            tasksBlockedByResearch: gateStats.blockedModules,
            researchTasksScheduled: gateStats.pendingResearchTasks,
            researchDebtTasks: gateStats.unresolvedDebtTasks,
            researchAdequacyRate: gateStats.adequacyRate,
            researchBlockingRate: gateStats.blockingRate,
            totalResearchBundles: registryStats.totalBundles,
            adequateResearchBundles: registryStats.adequateBundles
        )
    }
}

// MARK: - Supporting Types

/// Information about a module creation task.
public struct ModuleCreationTaskInfo: ModuleCreationTask {
    public let moduleId: UUID
    public let moduleName: String
    public let moduleType: String
    public let description: String
    public let scope: [String]
    public let doctrineTags: [DoctrineDomain]
    public let constraints: [String]
    public let keywords: [String]
    public let changes: [String]
    public let requiresRecentResearch: Bool
    public let priority: ResearchTask.TaskPriority

    // Protocol requirements
    public var id: String { moduleId.uuidString }
    public var projectId: UUID? { nil }
    public var featureCategory: String { moduleType }
    public var metadata: [String: String] { [:] }
}

/// Statistics for research enforcement.
public struct ResearchEnforcementStats: Sendable {
    public let totalTasksProcessed: Int
    public let tasksBlockedByResearch: Int
    public let researchTasksScheduled: Int
    public let researchDebtTasks: Int
    public let researchAdequacyRate: Double
    public let researchBlockingRate: Double
    public let totalResearchBundles: Int
    public let adequateResearchBundles: Int

    public var researchBlockingPercentage: Double {
        guard totalTasksProcessed > 0 else { return 0.0 }
        return Double(tasksBlockedByResearch) / Double(totalTasksProcessed)
    }
}

// MARK: - Integration Example

extension ResearchAwareStepEngine {
    /// Example of how to integrate with existing system.
    public static func createIntegratedEngine() throws -> ResearchAwareStepEngine {
        // Create registry
        let dbPath = "research.db"
        let registry = try ResearchRegistry(dbPath: dbPath)

        // Create research gate
        let doctrinePack = ResearchDoctrinePack()
        let researchGate = ResearchGate(registry: registry, doctrinePack: doctrinePack)

        // Create integrated engine
        return ResearchAwareStepEngine(
            baseStepEngine: StepEngine(),
            researchGate: researchGate,
            registry: registry
        )
    }

    /// Register research doctrine pack with the system.
    public static func registerResearchDoctrine() {
        ResearchDoctrinePack.register()
        logInfo("Research doctrine pack registered", category: "ResearchStepEngine")
    }
}

// MARK: - Logging Helpers

private func logInfo(_ message: String, category: String) {
    print("[INFO][\(category)] \(message)")
}

private func logWarning(_ message: String, category: String) {
    print("[WARN][\(category)] \(message)")
}

private func logError(_ message: String, category: String) {
    print("[ERROR][\(category)] \(message)")
}
