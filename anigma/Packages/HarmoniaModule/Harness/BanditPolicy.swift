//
//  BanditPolicy.swift
//  HarmoniaModule
//
//  Simple multi-armed bandit policies for config tuning.
//  Epsilon-greedy and UCB1 for supervised "wiggle room."
//

import Foundation

// MARK: - Bandit Arm Statistics

/// Statistics for a single bandit arm (config).
public struct BanditArmStats: Sendable {
    public let configId: String
    public let pulls: Int
    public let totalReward: Double

    public var averageReward: Double {
        guard pulls > 0 else { return 0 }
        return totalReward / Double(pulls)
    }

    public init(configId: String, pulls: Int, totalReward: Double) {
        self.configId = configId
        self.pulls = pulls
        self.totalReward = totalReward
    }
}

// MARK: - Epsilon-Greedy Policy

/// Simple epsilon-greedy policy for exploration/exploitation trade-off.
public struct EpsilonGreedyPolicy: Sendable {
    public var baseEpsilon: Double
    public var minEpsilon: Double
    public var decayFactor: Double

    /// Creates an epsilon-greedy policy with optional decay.
    /// - Parameters:
    ///   - baseEpsilon: Starting epsilon value (default: 0.3)
    ///   - minEpsilon: Minimum epsilon after decay (default: 0.05)
    ///   - decayFactor: Decay factor per pull (default: 0.995)
    public init(
        baseEpsilon: Double = 0.3,
        minEpsilon: Double = 0.05,
        decayFactor: Double = 0.995
    ) {
        self.baseEpsilon = baseEpsilon
        self.minEpsilon = minEpsilon
        self.decayFactor = decayFactor
    }

    /// Computes epsilon decayed based on total pulls.
    /// Formula: epsilon = max(minEpsilon, baseEpsilon * (decayFactor ^ totalPulls))
    public func epsilon(forTotalPulls totalPulls: Int) -> Double {
        guard totalPulls > 0 else { return baseEpsilon }
        let decayed = baseEpsilon * pow(decayFactor, Double(totalPulls))
        return max(minEpsilon, decayed)
    }

    /// Current epsilon (for backward compatibility).
    public var epsilon: Double {
        baseEpsilon
    }

    /// Selects an arm using epsilon-greedy strategy.
    /// - Parameters:
    ///   - arms: Array of arm statistics
    ///   - rng: Random number generator
    /// - Returns: Selected config ID, or nil if no arms available
    public func selectArm(arms: [BanditArmStats], rng: inout RandomNumberGenerator) -> String? {
        guard !arms.isEmpty else { return nil }

        let totalPulls = arms.reduce(0) { $0 + $1.pulls }
        let currentEpsilon = epsilon(forTotalPulls: totalPulls)

        let r = Double.random(in: 0..<1, using: &rng)
        if r < currentEpsilon {
            // Explore: choose random arm
            let idx = Int.random(in: 0..<arms.count, using: &rng)
            return arms[idx].configId
        } else {
            // Exploit: choose arm with highest average reward
            return arms.max { $0.averageReward < $1.averageReward }?.configId
        }
    }

    /// Convenience method using SystemRandomNumberGenerator.
    public func selectArm(arms: [BanditArmStats]) -> String? {
        var rng: any RandomNumberGenerator = SystemRandomNumberGenerator()
        return selectArm(arms: arms, rng: &rng)
    }

    /// Selects an arm with explicit total pulls for epsilon calculation.
    public func selectArm(arms: [BanditArmStats], totalPulls: Int) -> String? {
        var rng: any RandomNumberGenerator = SystemRandomNumberGenerator()
        return selectArm(arms: arms, totalPulls: totalPulls, rng: &rng)
    }

    /// Selects an arm with explicit total pulls.
    public func selectArm(arms: [BanditArmStats], totalPulls: Int, rng: inout RandomNumberGenerator) -> String? {
        guard !arms.isEmpty else { return nil }

        let currentEpsilon = epsilon(forTotalPulls: totalPulls)

        let r = Double.random(in: 0..<1, using: &rng)
        if r < currentEpsilon {
            // Explore: choose random arm
            let idx = Int.random(in: 0..<arms.count, using: &rng)
            return arms[idx].configId
        } else {
            // Exploit: choose arm with highest average reward
            return arms.max { $0.averageReward < $1.averageReward }?.configId
        }
    }
}

// MARK: - UCB1 Policy

/// Upper Confidence Bound (UCB1) policy for bandit selection.
public struct UCB1Policy: Sendable {
    public var explorationConstant: Double

    public init(explorationConstant: Double = 2.0) {
        self.explorationConstant = explorationConstant
    }

    /// Selects an arm using UCB1 strategy.
    /// - Parameter arms: Array of arm statistics
    /// - Returns: Selected config ID, or nil if no arms available
    public func selectArm(arms: [BanditArmStats]) -> String? {
        guard !arms.isEmpty else { return nil }

        let totalPulls = arms.reduce(0) { $0 + $1.pulls }
        let totalPullsDouble = Double(max(totalPulls, 1))

        return arms.max { a, b in
            let va = ucbValue(arm: a, totalPulls: totalPullsDouble)
            let vb = ucbValue(arm: b, totalPulls: totalPullsDouble)
            return va < vb
        }?.configId
    }

    private func ucbValue(arm: BanditArmStats, totalPulls: Double) -> Double {
        if arm.pulls == 0 {
            return .infinity  // Never pulled arms get infinite value
        }
        let mean = arm.averageReward
        let n = Double(arm.pulls)
        return mean + explorationConstant * sqrt(2.0 * log(totalPulls) / n)
    }
}

// MARK: - Policy Factory

/// Factory for creating bandit policies.
public enum BanditPolicyFactory {
    /// Creates an epsilon-greedy policy with default parameters.
    public static func epsilonGreedy(
        baseEpsilon: Double = 0.3,
        minEpsilon: Double = 0.05,
        decayFactor: Double = 0.995
    ) -> EpsilonGreedyPolicy {
        EpsilonGreedyPolicy(
            baseEpsilon: baseEpsilon,
            minEpsilon: minEpsilon,
            decayFactor: decayFactor
        )
    }

    /// Creates a UCB1 policy with default parameters.
    public static func ucb1(explorationConstant: Double = 2.0) -> UCB1Policy {
        UCB1Policy(explorationConstant: explorationConstant)
    }

    /// Creates the default policy (epsilon-greedy with epsilon=0.1).
    public static func defaultPolicy() -> EpsilonGreedyPolicy {
        epsilonGreedy()
    }
}

// MARK: - Blessed Config Registry

/// Registry of blessed configs that the bandit can choose from.
/// These are fixed, vetted configs that obey all invariants.
public struct BlessedConfig: Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let featureCategories: [String]  // Which categories this config applies to
    public let parameters: [String: String]  // Config parameters as strings for Sendable safety
    public let tags: [String]  // Tags for governance filtering (canonical, system, sandbox, adversarial, etc.)
    public let isEnabled: Bool

    public init(
        id: String,
        name: String,
        description: String,
        featureCategories: [String],
        parameters: [String: String],
        tags: [String] = [],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.featureCategories = featureCategories
        self.parameters = parameters
        self.tags = tags
        self.isEnabled = isEnabled
    }
}

/// Registry of all blessed configs.
public enum BlessedConfigRegistry {
    /// Default configs for v1.
    public static let defaultConfigs: [BlessedConfig] = [
        // Conservative config for UI features
        BlessedConfig(
            id: "ui_conservative",
            name: "UI Conservative",
            description: "Conservative config for UI features: limited file changes, strict linting",
            featureCategories: ["ui", "frontend"],
            parameters: [
                "max_files_touched": "5",
                "require_lint_pass": "true",
                "max_edit_calls": "10",
                "analysis_ratio_target": "0.4"
            ],
            tags: ["canonical", "trusted"]
        ),

        // Balanced config for backend features
        BlessedConfig(
            id: "backend_balanced",
            name: "Backend Balanced",
            description: "Balanced config for backend features: moderate changes, focus on tests",
            featureCategories: ["backend", "api"],
            parameters: [
                "max_files_touched": "8",
                "require_tests": "true",
                "test_coverage_target": "0.7",
                "analysis_ratio_target": "0.3"
            ]
        ),

        // Aggressive config for refactoring
        BlessedConfig(
            id: "refactor_aggressive",
            name: "Refactor Aggressive",
            description: "Aggressive config for refactoring: many files, focus on analysis",
            featureCategories: ["refactor", "cleanup"],
            parameters: [
                "max_files_touched": "15",
                "analysis_ratio_target": "0.5",
                "allow_large_diffs": "true",
                "require_analysis_before_edit": "true"
            ]
        ),

        // Test-focused config
        BlessedConfig(
            id: "test_focused",
            name: "Test Focused",
            description: "Config focused on test writing and maintenance",
            featureCategories: ["tests", "test_coverage"],
            parameters: [
                "max_files_touched": "3",
                "require_tests": "true",
                "test_calls_min": "3",
                "analysis_ratio_target": "0.2"
            ]
        ),

        // Default fallback config
        BlessedConfig(
            id: "default",
            name: "Default",
            description: "Default config for unknown feature types",
            featureCategories: ["default", "unknown"],
            parameters: [
                "max_files_touched": "10",
                "analysis_ratio_target": "0.3",
                "require_lint_pass": "false",
                "require_tests": "false"
            ]
        )
    ]

    /// Gets blessed configs for a specific feature category.
    public static func configs(for category: String) -> [BlessedConfig] {
        defaultConfigs.filter { config in
            config.isEnabled && config.featureCategories.contains(category)
        }
    }

    /// Gets all config IDs for a category.
    public static func configIds(for category: String) -> [String] {
        configs(for: category).map(\.id)
    }

    /// Gets a config by ID.
    public static func config(withId id: String) -> BlessedConfig? {
        defaultConfigs.first { $0.id == id && $0.isEnabled }
    }
}
