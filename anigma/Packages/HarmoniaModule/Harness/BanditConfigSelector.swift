//
//  BanditConfigSelector.swift
//  HarmoniaModule
//
//  Helper for selecting configs using bandit learning.
//  Integrates with session flow to provide supervised "wiggle room."
//

import Foundation

// MARK: - Bandit Config Selector

/// Helper for selecting configs using bandit learning.
public actor BanditConfigSelector {
    private let store: ProjectHarnessStore
    private let policy: EpsilonGreedyPolicy

    public init(
        store: ProjectHarnessStore = .shared,
        policy: EpsilonGreedyPolicy = EpsilonGreedyPolicy()
    ) {
        self.store = store
        self.policy = policy
    }

    // MARK: - Public API

    /// Selects a config for a feature category.
    /// - Parameters:
    ///   - projectId: Project identifier
    ///   - featureCategory: Feature category (e.g., "ui", "backend")
    /// - Returns: Selected config ID
    public func selectConfig(
        projectId: UUID,
        featureCategory: String
    ) async throws -> String {
        return try await store.selectConfig(
            projectId: projectId,
            featureCategory: featureCategory,
            policy: policy
        )
    }

    /// Gets the best performing config for a category.
    /// - Parameters:
    ///   - projectId: Project identifier
    ///   - featureCategory: Feature category
    /// - Returns: Best config ID, or nil if insufficient data
    public func getBestConfig(
        projectId: UUID,
        featureCategory: String
    ) async throws -> String? {
        return try await store.getBestConfig(
            projectId: projectId,
            featureCategory: featureCategory
        )
    }

    /// Updates bandit stats after a session.
    /// - Parameters:
    ///   - projectId: Project identifier
    ///   - featureCategory: Feature category
    ///   - configId: Config ID used
    ///   - reward: Reward value (computed from session report)
    public func updateStats(
        projectId: UUID,
        featureCategory: String,
        configId: String,
        reward: Double
    ) async throws {
        try await store.updateBanditStats(
            projectId: projectId,
            featureCategory: featureCategory,
            configId: configId,
            reward: reward
        )
    }

    /// Gets bandit statistics for a project and category.
    /// - Parameters:
    ///   - projectId: Project identifier
    ///   - featureCategory: Feature category
    /// - Returns: Array of bandit arm statistics
    public func getStats(
        projectId: UUID,
        featureCategory: String
    ) async throws -> [BanditArmStats] {
        let blessedConfigs = BlessedConfigRegistry.configIds(for: featureCategory)
        return try await store.getBanditStats(
            projectId: projectId,
            featureCategory: featureCategory,
            configIds: blessedConfigs
        )
    }

    /// Resets bandit statistics for a project.
    /// - Parameters:
    ///   - projectId: Project identifier
    ///   - featureCategory: Feature category (optional, resets all if nil)
    public func resetStats(
        projectId: UUID,
        featureCategory: String? = nil
    ) async throws {
        try await store.resetBanditStats(
            projectId: projectId,
            featureCategory: featureCategory
        )
    }

    // MARK: - Session Integration Helpers

    /// Creates a session epilogue context with bandit-selected config.
    /// - Parameters:
    ///   - projectId: Project identifier
    ///   - sessionIndex: Session index
    ///   - featureId: Feature identifier (optional)
    ///   - sessionResult: Session result
    ///   - featureCategory: Feature category for config selection
    /// - Returns: Session epilogue context with selected config
    public func createEpilogueContext(
        projectId: UUID,
        sessionIndex: Int,
        featureId: UUID? = nil,
        sessionResult: CodingSessionResult,
        featureCategory: String
    ) async throws -> SessionEpilogueContext {
        let configId = try await selectConfig(
            projectId: projectId,
            featureCategory: featureCategory
        )

        return SessionEpilogueContext(
            projectId: projectId,
            sessionIndex: sessionIndex,
            featureId: featureId,
            sessionResult: sessionResult,
            configId: configId,
            featureCategory: featureCategory
        )
    }

    /// Updates bandit stats from a session report.
    /// - Parameter report: Session report with config and category
    public func updateFromReport(_ report: SessionReport) async throws {
        guard report.isValidForBanditLearning,
              let configId = report.configId,
              let featureCategory = report.featureCategory else {
            return
        }

        let reward = report.banditReward
        try await updateStats(
            projectId: report.projectId,
            featureCategory: featureCategory,
            configId: configId,
            reward: reward
        )
    }

    // MARK: - Analysis and Debugging

    /// Gets a summary of bandit performance for a project.
    /// - Parameter projectId: Project identifier
    /// - Returns: Formatted summary string
    public func getPerformanceSummary(projectId: UUID) async throws -> String {
        var summary = "🎰 BANDIT PERFORMANCE SUMMARY 🎰\n\n"

        // Get all categories from blessed configs
        let allCategories = Set(BlessedConfigRegistry.defaultConfigs.flatMap { $0.featureCategories })

        for category in allCategories.sorted() {
            let stats = try await getStats(
                projectId: projectId,
                featureCategory: category
            )

            summary += "📊 \(category.uppercased()):\n"

            if stats.isEmpty {
                summary += "  No data yet\n"
            } else {
                for stat in stats.sorted(by: { $0.averageReward > $1.averageReward }) {
                    let config = BlessedConfigRegistry.config(withId: stat.configId)
                    let configName = config?.name ?? stat.configId
                    summary += String(format: "  - %@: %.3f avg reward (%d pulls)\n", configName, stat.averageReward, stat.pulls)
                }
            }

            summary += "\n"
        }

        return summary
    }

    /// Gets recommendations for config tuning.
    /// - Parameter projectId: Project identifier
    /// - Returns: Array of recommendation strings
    public func getRecommendations(projectId: UUID) async throws -> [String] {
        var recommendations: [String] = []

        let allCategories = Set(BlessedConfigRegistry.defaultConfigs.flatMap { $0.featureCategories })

        for category in allCategories.sorted() {
            let stats = try await getStats(
                projectId: projectId,
                featureCategory: category
            )

            guard stats.count >= 2 else { continue }

            let sortedStats = stats.sorted { $0.averageReward > $1.averageReward }
            let best = sortedStats[0]
            guard let worst = sortedStats.last else {
                fatalError("Failed to unwrap worst")
            }

            // Only recommend if there's a clear winner (min 5 pulls each, >20% difference)
            if best.pulls >= 5 && worst.pulls >= 5 {
                let improvement = best.averageReward - worst.averageReward
                if improvement > 0.2 {
                    let bestConfig = BlessedConfigRegistry.config(withId: best.configId)
                    let worstConfig = BlessedConfigRegistry.config(withId: worst.configId)

                    recommendations.append("For \(category): \(bestConfig?.name ?? best.configId) outperforms \(worstConfig?.name ?? worst.configId) by \(String(format: "%.1f%%", improvement * 100))")
                }
            }
        }

        return recommendations
    }
}
