//
//  ResearchGate.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Research
//
//  The bouncer that says "no papers, no module."
//  Wired into StepEngine as upstream dependency.
//

import Foundation
import AnigmaCore
import HarmoniaModule

// MARK: - Research Gate

/// Gate that enforces research requirements before allowing work.
/// Integrated with StepEngine to block module creation without adequate research.
public actor ResearchGate {
    private let registry: ResearchRegistry
    private let doctrinePack: ResearchDoctrinePack
    private let adequacyCalculator: ResearchAdequacyCalculator
    private let securityEvents: SecurityEventsManager

    /// Initialize with dependencies.
    public init(
        registry: ResearchRegistry,
        doctrinePack: ResearchDoctrinePack = ResearchDoctrinePack(),
        securityEvents: SecurityEventsManager = SecurityEventsManager()
    ) {
        self.registry = registry
        self.doctrinePack = doctrinePack
        self.adequacyCalculator = ResearchAdequacyCalculator(doctrinePack: doctrinePack)
        self.securityEvents = securityEvents
    }

    // MARK: - Module Proposal Checking

    /// Check if a module proposal has adequate research.
    /// Returns the adequate research bundle if available, nil otherwise.
    public func checkModuleProposal(_ proposal: ModuleProposal) async throws -> ResearchBundle? {
        // Check if research is required for this proposal
        guard doctrinePack.requiresResearch(for: proposal.moduleType, changes: proposal.changes) else {
            return nil  // Research not required
        }

        // Create topic spec from proposal
        let topicSpec = TopicSpec(
            moduleName: proposal.name,
            purpose: proposal.description,
            scope: proposal.scope,
            doctrineTags: proposal.doctrineTags,
            constraints: proposal.constraints,
            searchKeywords: proposal.keywords,
            maxPapers: 20,
            minYear: proposal.requiresRecentResearch ? Calendar.current.component(.year, from: Date()) - 5 : nil
        )

        // Check for existing adequate research
        if let existingBundle = try await getAdequateResearchBundle(for: topicSpec) {
            return existingBundle
        }

        // No adequate research found
        return nil
    }

    /// Get adequate research bundle for a topic, creating research task if needed.
    private func getAdequateResearchBundle(for topicSpec: TopicSpec) async throws -> ResearchBundle? {
        // Check registry for existing adequate research
        if let bundle = try registry.getLatestAdequateBundle(for: topicSpec) {
            return bundle
        }

        // Check for pending research tasks
        let pendingTasks = try registry.getPendingResearchTasks(limit: 5)
        let hasPendingTask = pendingTasks.contains { task in
            task.topicSpec.moduleName == topicSpec.moduleName &&
            task.topicSpec.purpose == topicSpec.purpose
        }

        if !hasPendingTask {
            // Create research task
            let researchTask = ResearchTask(
                topicSpec: topicSpec,
                projectId: nil,  // Will be set by caller
                moduleId: nil,   // Will be set by caller
                status: .pending,
                priority: .high
            )

            try registry.saveResearchTask(researchTask)
        }

        return nil
    }

    // MARK: - Research Adequacy Enforcement

    /// Check if research is adequate for a given bundle.
    /// Returns violations if inadequate, empty array if adequate.
    public func checkResearchAdequacy(_ bundle: ResearchBundle) -> [DoctrineViolation] {
        return ResearchDoctrinePack.checkAdequacy(bundle)
    }

    /// Create research debt tasks for inadequate research.
    public func createResearchDebtTasks(for bundle: ResearchBundle, blockedEntityId: UUID, blockedEntityType: String) -> [ResearchDebtTask] {
        return doctrinePack.generateDebtTasks(for: bundle, blockedEntityId: blockedEntityId, blockedEntityType: blockedEntityType)
    }

    /// Block module creation due to inadequate research.
    /// Creates research debt tasks and returns blocking result.
    public func blockModuleCreation(
        moduleProposal: ModuleProposal,
        researchBundle: ResearchBundle?,
        projectId: UUID? = nil
    ) -> ResearchBlockingResult {
        let moduleId = UUID()  // Generate ID for the blocked module

        if let bundle = researchBundle {
            // Research exists but is inadequate
            let violations = checkResearchAdequacy(bundle)
            let debtTasks = createResearchDebtTasks(for: bundle, blockedEntityId: moduleId, blockedEntityType: "module")

            // Log security event for each violation
            for violation in violations {
                securityEvents.logResearchInadequate(
                    moduleId: moduleProposal.name,
                    researchBundleId: bundle.id.uuidString,
                    adequacyScore: adequacyCalculator.calculateAdequacyScore(bundle),
                    ruleId: violation.ruleId,
                    reason: violation.context
                )
            }

            // Save debt tasks
            for debtTask in debtTasks {
                try? registry.saveResearchDebtTask(debtTask)
            }

            return ResearchBlockingResult(
                isBlocked: true,
                reason: .researchInadequate(violations: violations),
                researchBundleId: bundle.id,
                debtTasks: debtTasks,
                recommendations: adequacyCalculator.generateRecommendations(bundle)
            )
        } else {
            // No research at all
            let topicSpec = TopicSpec(
                moduleName: moduleProposal.name,
                purpose: moduleProposal.description,
                scope: moduleProposal.scope,
                doctrineTags: moduleProposal.doctrineTags,
                constraints: moduleProposal.constraints,
                searchKeywords: moduleProposal.keywords
            )

            // Log security event for missing research
            securityEvents.logResearchInadequate(
                moduleId: moduleProposal.name,
                researchBundleId: nil,
                adequacyScore: 0.0,
                ruleId: "research-required",
                reason: "No research found for module proposal"
            )

            // Create research task
            let researchTask = ResearchTask(
                topicSpec: topicSpec,
                projectId: projectId,
                moduleId: moduleId,
                status: .pending,
                priority: .high
            )

            try? registry.saveResearchTask(researchTask)

            return ResearchBlockingResult(
                isBlocked: true,
                reason: .noResearch,
                researchBundleId: nil,
                debtTasks: [],
                recommendations: ["Research required: \(topicSpec.moduleName)"]
            )

            // Create research task
            let researchTask = ResearchTask(
                topicSpec: topicSpec,
                projectId: projectId,
                moduleId: moduleId,
                status: .pending,
                priority: .high
            )

            try? registry.saveResearchTask(researchTask)

            return ResearchBlockingResult(
                isBlocked: true,
                reason: .noResearch,
                researchBundleId: nil,
                debtTasks: [],
                recommendations: [
                    ResearchRecommendation(
                        priority: .critical,
                        action: "Conduct literature research",
                        reason: "No research found for module '\(moduleProposal.name)'",
                        suggestedQueries: topicSpec.generateQueries()
                    )
                ]
            )
        }
    }

    // MARK: - Integration with StepEngine

    /// Hook for StepEngine to check research before scheduling work.
    public func checkBeforeScheduling(task: any TaskProtocol) -> ResearchCheckResult {
        guard let moduleTask = task as? (any ModuleCreationTask) else {
            return ResearchCheckResult.allowed  // Not a module creation task
        }

        do {
            // Check if research is required
            guard doctrinePack.requiresResearch(for: moduleTask.moduleType, changes: moduleTask.changes) else {
                return ResearchCheckResult.allowed
            }

            // Check for adequate research
            let topicSpec = TopicSpec(
                moduleName: moduleTask.moduleName,
                purpose: moduleTask.description,
                scope: moduleTask.scope,
                doctrineTags: moduleTask.doctrineTags,
                constraints: moduleTask.constraints,
                searchKeywords: moduleTask.keywords
            )

            if try registry.hasAdequateResearch(for: topicSpec) {
                return ResearchCheckResult.allowed
            } else {
                return ResearchCheckResult.blocked(reason: "No adequate research for module '\(moduleTask.moduleName)'")
            }
        } catch {
            return ResearchCheckResult.error(error)
        }
    }

    /// Schedule research task before module creation.
    public func scheduleResearchBeforeModuleCreation(
        moduleTask: any ModuleCreationTask,
        projectId: UUID?
    ) -> ResearchTask {
        let topicSpec = TopicSpec(
            moduleName: moduleTask.moduleName,
            purpose: moduleTask.description,
            scope: moduleTask.scope,
            doctrineTags: moduleTask.doctrineTags,
            constraints: moduleTask.constraints,
            searchKeywords: moduleTask.keywords,
            maxPapers: 20,
            minYear: moduleTask.requiresRecentResearch ? Calendar.current.component(.year, from: Date()) - 5 : nil
        )

        let researchTask = ResearchTask(
            topicSpec: topicSpec,
            projectId: projectId,
            moduleId: moduleTask.moduleId,
            status: .pending,
            priority: moduleTask.priority
        )

        try? registry.saveResearchTask(researchTask)
        return researchTask
    }

    // MARK: - Research Progress Tracking

    /// Get research status for a module.
    public func getResearchStatus(for moduleId: UUID) throws -> ResearchStatus {
        // Check for completed research bundle
        let pendingTasks = try registry.getPendingResearchTasks(limit: 100)
        let moduleTasks = pendingTasks.filter { $0.moduleId == moduleId }

        if let completedTask = moduleTasks.first(where: { $0.status == .completed && $0.researchBundleId != nil }) {
            if let bundleId = completedTask.researchBundleId, let bundle = try registry.getBundle(id: bundleId) {
                let violations = checkResearchAdequacy(bundle)
                let isAdequate = violations.isEmpty

                return ResearchStatus(
                    hasResearch: true,
                    isAdequate: isAdequate,
                    researchBundleId: bundleId,
                    violations: violations,
                    adequacyScore: bundle.adequacyScore
                )
            }
        }

        // Check for pending research
        if let pendingTask = moduleTasks.first(where: { $0.status == .pending || $0.status == .running }) {
            return ResearchStatus(
                hasResearch: false,
                isAdequate: false,
                researchBundleId: nil,
                violations: [],
                adequacyScore: 0.0,
                researchTaskId: pendingTask.id,
                researchTaskStatus: pendingTask.status
            )
        }

        // No research at all
        return ResearchStatus(
            hasResearch: false,
            isAdequate: false,
            researchBundleId: nil,
            violations: [],
            adequacyScore: 0.0
        )
    }

    /// Get all blocked modules due to research debt.
    public func getBlockedModules() throws -> [BlockedModule] {
        let debtTasks = try registry.getUnresolvedDebtTasks(limit: 100)

        return debtTasks.compactMap { debtTask in
            guard debtTask.blockedEntityType == "module" else {
                return nil
            }

            let bundle = try? registry.getBundle(id: debtTask.researchBundleId)

            return BlockedModule(
                moduleId: debtTask.blockedEntityId,
                researchBundleId: debtTask.researchBundleId,
                reason: debtTask.reason,
                requiredActions: debtTask.requiredActions,
                researchBundle: bundle,
                debtTaskId: debtTask.id,
                createdAt: debtTask.createdAt
            )
        }
    }

    // MARK: - Research Completion Handling

    /// Handle completion of research task.
    public func handleResearchCompletion(taskId: UUID, bundle: ResearchBundle?) throws -> ResearchCompletionResult {
        // Get the research task
        // Note: In a real implementation, we'd fetch the task from registry
        // For now, we'll assume it exists and update it

        guard let bundle = bundle else {
            // Research failed
            return ResearchCompletionResult(
                success: false,
                researchBundleId: nil,
                violations: [],
                isAdequate: false,
                debtTasks: []
            )
        }

        // Check adequacy
        let violations = checkResearchAdequacy(bundle)
        let isAdequate = violations.isEmpty

        // Save the bundle
        try registry.saveBundle(bundle)

        var debtTasks: [ResearchDebtTask] = []
        if !isAdequate, let moduleId = bundle.topicSpec.moduleName.data(using: .utf8)?.withUnsafeBytes({ UUID(uuid: $0.load(as: uuid_t.self)) }) {
            // Create debt tasks for inadequate research
            debtTasks = createResearchDebtTasks(
                for: bundle,
                blockedEntityId: moduleId,
                blockedEntityType: "module"
            )

            for debtTask in debtTasks {
                try registry.saveResearchDebtTask(debtTask)
            }
        }

        return ResearchCompletionResult(
            success: true,
            researchBundleId: bundle.id,
            violations: violations,
            isAdequate: isAdequate,
            debtTasks: debtTasks
        )
    }
}

// MARK: - Supporting Types

/// Result of research adequacy check.
public enum ResearchCheckResult: Sendable {
    case allowed
    case blocked(reason: String)
    case error(Error)

    public var isAllowed: Bool {
        switch self {
        case .allowed:
            return true
        case .blocked, .error:
            return false
        }
    }
}

/// Result of blocking module creation.
public struct ResearchBlockingResult: Sendable {
    public let isBlocked: Bool
    public let reason: BlockingReason
    public let researchBundleId: UUID?
    public let debtTasks: [ResearchDebtTask]
    public let recommendations: [ResearchRecommendation]

    public enum BlockingReason: Sendable {
        case noResearch
        case researchInadequate(violations: [DoctrineViolation])
    }
}

/// Status of research for a module.
public struct ResearchStatus: Sendable {
    public let hasResearch: Bool
    public let isAdequate: Bool
    public let researchBundleId: UUID?
    public let violations: [DoctrineViolation]
    public let adequacyScore: Double
    public let researchTaskId: UUID?
    public let researchTaskStatus: ResearchTask.TaskStatus?

    public init(
        hasResearch: Bool,
        isAdequate: Bool,
        researchBundleId: UUID? = nil,
        violations: [DoctrineViolation] = [],
        adequacyScore: Double = 0.0,
        researchTaskId: UUID? = nil,
        researchTaskStatus: ResearchTask.TaskStatus? = nil
    ) {
        self.hasResearch = hasResearch
        self.isAdequate = isAdequate
        self.researchBundleId = researchBundleId
        self.violations = violations
        self.adequacyScore = adequacyScore
        self.researchTaskId = researchTaskId
        self.researchTaskStatus = researchTaskStatus
    }
}

/// Module blocked by research debt.
public struct BlockedModule: Sendable {
    public let moduleId: UUID
    public let researchBundleId: UUID
    public let reason: String
    public let requiredActions: [String]
    public let researchBundle: ResearchBundle?
    public let debtTaskId: UUID
    public let createdAt: Date
}

/// Result of research completion.
public struct ResearchCompletionResult: Sendable {
    public let success: Bool
    public let researchBundleId: UUID?
    public let violations: [DoctrineViolation]
    public let isAdequate: Bool
    public let debtTasks: [ResearchDebtTask]
}

// MARK: - Protocol for Module Creation Tasks

/// Protocol for tasks that create modules.
public protocol ModuleCreationTask: TaskProtocol {
    var moduleId: UUID { get }
    var moduleName: String { get }
    var moduleType: String { get }
    var description: String { get }
    var scope: [String] { get }
    var doctrineTags: [DoctrineDomain] { get }
    var constraints: [String] { get }
    var keywords: [String] { get }
    var changes: [String] { get }
    var requiresRecentResearch: Bool { get }
    var priority: ResearchTask.TaskPriority { get }
}

// MARK: - Module Proposal (Example)

/// Example module proposal structure.
public struct ModuleProposal: Sendable {
    public let name: String
    public let description: String
    public let moduleType: String
    public let scope: [String]
    public let doctrineTags: [DoctrineDomain]
    public let constraints: [String]
    public let keywords: [String]
    public let changes: [String]
    public let requiresRecentResearch: Bool

    public init(
        name: String,
        description: String,
        moduleType: String,
        scope: [String] = [],
        doctrineTags: [DoctrineDomain] = [],
        constraints: [String] = [],
        keywords: [String] = [],
        changes: [String] = [],
        requiresRecentResearch: Bool = false
    ) {
        self.name = name
        self.description = description
        self.moduleType = moduleType
        self.scope = scope
        self.doctrineTags = doctrineTags
        self.constraints = constraints
        self.keywords = keywords
        self.changes = changes
        self.requiresRecentResearch = requiresRecentResearch
    }
}

// MARK: - Integration with Existing Systems

extension ResearchGate {
    /// Register research gate with the security spine.
    public static func registerWithSecuritySpine() {
        Task {
            await Logger.shared.info(
                "ResearchGate registered with security spine",
                category: "ResearchGate"
            )
        }
    }

    /// Get research statistics.
    public func getStatistics() throws -> ResearchGateStatistics {
        let registryStats = try registry.getStatistics()
        let blockedModules = try getBlockedModules()

        return ResearchGateStatistics(
            totalBundles: registryStats.totalBundles,
            adequateBundles: registryStats.adequateBundles,
            expiredBundles: registryStats.expiredBundles,
            totalPapers: registryStats.totalPapers,
            recentBundles: registryStats.recentBundles,
            blockedModules: blockedModules.count,
            pendingResearchTasks: try registry.getPendingResearchTasks().count,
            unresolvedDebtTasks: try registry.getUnresolvedDebtTasks().count
        )
    }
}

/// Statistics for research gate.
public struct ResearchGateStatistics: Sendable {
    public let totalBundles: Int
    public let adequateBundles: Int
    public let expiredBundles: Int
    public let totalPapers: Int
    public let recentBundles: Int
    public let blockedModules: Int
    public let pendingResearchTasks: Int
    public let unresolvedDebtTasks: Int

    public var adequacyRate: Double {
        guard totalBundles > 0 else { return 0.0 }
        return Double(adequateBundles) / Double(totalBundles)
    }

    public var blockingRate: Double {
        guard totalBundles > 0 else { return 0.0 }
        return Double(blockedModules) / Double(totalBundles)
    }
}
