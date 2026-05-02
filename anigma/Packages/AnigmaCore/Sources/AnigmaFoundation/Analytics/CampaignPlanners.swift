//
//  CampaignPlanners.swift
//  AnigmaCore
//
//  Concrete campaign planners for self-improvement recommendations.
//

import AnigmaPrimitives
import Foundation
import ContractsCore
public struct FailureAnalysisPlanner: CampaignPlanner {
    public func plan(from patterns: [DetectedPattern]) async throws -> [CampaignRecommendation] {
        var campaigns: [CampaignRecommendation] = []

        // Filter for failure patterns
        let failurePatterns = patterns.filter { $0.type == .repeatedFailure }

        for pattern in failurePatterns {
            // Analyze failure pattern
            let analysis = analyzeFailurePattern(pattern)

            // Generate improvement actions
            let actions = generateFailureActions(analysis)

            let campaign = CampaignRecommendation(
                id: CampaignId.generate(),
                type: .failureAnalysis,
                priority: determineFailurePriority(pattern),
                title: "Fix repeated failure: \(analysis.fingerprint)",
                description: "Address systematic failures in '\(analysis.operation)' with fingerprint '\(analysis.fingerprint)'",
                rationale: "Repeated failures indicate systematic issues that need root cause analysis",
                suggestedActions: actions,
                estimatedImpact: CampaignImpact(
                    successProbability: 0.7,
                    expectedBenefit: "Reduce failure rate by 80%",
                    riskReduction: "Eliminate systematic failure patterns",
                    resourceRequirement: ResourceEstimate(
                        cpuTime: 4 * 3600,  // 4 hours
                        memoryBytes: 1024 * 1024 * 1024,  // 1GB
                        diskBytes: 100 * 1024 * 1024,  // 100MB
                        networkBytes: 0
                    ),
                    timeToImplement: 7 * 24 * 3600  // 7 days
                ),
                sourcePatterns: [pattern.id],
                metadata: CampaignMetadata(
                    version: "1.0",
                    author: "FailureAnalysisPlanner",
                    tags: ["failure", "systematic", "root_cause"],
                    context: [
                        "failure_count": "\(pattern.metadata.frequency)",
                        "fingerprint": analysis.fingerprint,
                        "operation": analysis.operation,
                        "affected_traces": "\(pattern.affectedTraces.count)"
                    ]
                )
            )

            campaigns.append(campaign)
        }

        return campaigns
    }

    private func analyzeFailurePattern(_ pattern: DetectedPattern) -> FailureAnalysis {
        let affectedTraces = pattern.affectedTraces.compactMap { _ in
            // In production, this would retrieve the actual traces
            nil as String?  // Placeholder for MVP
        }

        // Extract operation from context
        let operation = pattern.metadata.context["operation"] ?? "unknown"

        // Extract fingerprint
        let fingerprint = pattern.metadata.context["fingerprint"] ?? ""

        return FailureAnalysis(
            fingerprint: fingerprint,
            operation: operation,
            frequency: pattern.metadata.frequency,
            severity: pattern.metadata.severity,
            affectedTraces: affectedTraces,
            timeSpan: calculateTimeSpan(pattern)
        )
    }

    private func generateFailureActions(_ analysis: FailureAnalysis) -> [SuggestedAction] {
        var actions: [SuggestedAction] = []

        // Root cause analysis action
        actions.append(SuggestedAction(
            id: "root_cause_analysis",
            type: ContractsCore.ActionType.analyze,
            description: "Perform root cause analysis of systematic failures",
            parameters: [
                "analysis_type": "root_cause",
                "fingerprint": analysis.fingerprint,
                "operation": analysis.operation
            ],
            estimatedEffort: EffortEstimate(
                hours: 8,
                complexity: .complex,
                risk: .medium,
                requiredSkills: ["debugging", "system_analysis", "domain_knowledge"]
            ),
            prerequisites: ["access_to_logs", "failure_data"]
        ))

        // Code review action
        actions.append(SuggestedAction(
            id: "code_review",
            type: ContractsCore.ActionType.validate,
            description: "Review code for systematic issues",
            parameters: [
                "review_type": "systematic_failure",
                "focus_area": analysis.operation
            ],
            estimatedEffort: EffortEstimate(
                hours: 4,
                complexity: .medium,
                risk: .low,
                requiredSkills: ["code_review", analysis.operation]
            ),
            prerequisites: ["source_code_access", "review_criteria"]
        ))

        // Test improvement action
        actions.append(SuggestedAction(
            id: "improve_tests",
            type: ContractsCore.ActionType.test,
            description: "Add tests to catch systematic failures early",
            parameters: [
                "test_type": "regression",
                "target_pattern": analysis.fingerprint,
                "coverage_target": "95"
            ],
            estimatedEffort: EffortEstimate(
                hours: 6,
                complexity: .medium,
                risk: .low,
                requiredSkills: ["testing", analysis.operation]
            ),
            prerequisites: ["existing_tests", "test_framework"]
        ))

        // Monitoring enhancement action
        actions.append(SuggestedAction(
            id: "enhance_monitoring",
            type: .createEntity,
            description: "Add monitoring to detect failure patterns early",
            parameters: [
                "monitoring_type": "pattern_detection",
                "target_pattern": analysis.fingerprint,
                "alert_threshold": "3"
            ],
            estimatedEffort: EffortEstimate(
                hours: 3,
                complexity: .simple,
                risk: .low,
                requiredSkills: ["monitoring", "alerting"]
            ),
            prerequisites: ["monitoring_system", "alert_channels"]
        ))

        return actions
    }

    private func determineFailurePriority(_ pattern: DetectedPattern) -> CampaignPriority {
        // Higher priority for more frequent/severe failures
        let frequencyScore = min(Double(pattern.metadata.frequency) / 5.0, 1.0)
        let severityScore = pattern.metadata.severity == .high ? 1.0 : 0.5

        let combinedScore = (frequencyScore + severityScore) / 2.0

        if combinedScore >= 0.8 { return .critical }
        if combinedScore >= 0.6 { return .high }
        if combinedScore >= 0.4 { return .medium }
        return .low
    }

    private func calculateTimeSpan(_ pattern: DetectedPattern) -> TimeInterval {
        let first = pattern.metadata.firstOccurrence
        let last = pattern.metadata.lastOccurrence
        return last.timeIntervalSince(first)
    }
}

/// Planner for policy improvement campaigns
public struct PolicyImprovementPlanner: CampaignPlanner {
    public func plan(from patterns: [DetectedPattern]) async throws -> [CampaignRecommendation] {
        var campaigns: [CampaignRecommendation] = []

        // Filter for policy violation patterns
        let violationPatterns = patterns.filter { $0.type == .policyViolation }

        // Group violations by policy
        let policyGroups = Dictionary(grouping: violationPatterns) { pattern in
            pattern.metadata.context["policy"] ?? "unknown"
        }

        for (policy, violations) in policyGroups {
            // Analyze violation pattern
            let analysis = analyzeViolationPattern(policy: policy, violations: violations)

            // Generate improvement actions
            let actions = generatePolicyActions(analysis)

            let campaign = CampaignRecommendation(
                id: CampaignId.generate(),
                type: .policyImprovement,
                priority: determinePolicyPriority(analysis),
                title: "Improve policy: \(policy)",
                description: "Address systematic violations of policy '\(policy)' with \(violations.count) instances",
                rationale: "Systematic policy violations indicate unclear policies or implementation gaps",
                suggestedActions: actions,
                estimatedImpact: CampaignImpact(
                    successProbability: 0.8,
                    expectedBenefit: "Reduce policy violations by 90%",
                    riskReduction: "Clarify policy requirements and improve compliance",
                    resourceRequirement: ResourceEstimate(
                        cpuTime: 2 * 3600,  // 2 hours
                        memoryBytes: 512 * 1024 * 1024,  // 512MB
                        diskBytes: 10 * 1024 * 1024,  // 10MB
                        networkBytes: 0
                    ),
                    timeToImplement: 3 * 24 * 3600  // 3 days
                ),
                sourcePatterns: violations.map { $0.id },
                metadata: CampaignMetadata(
                    version: "1.0",
                    author: "PolicyImprovementPlanner",
                    tags: ["policy", "compliance", "governance"],
                    context: [
                        "policy": policy,
                        "violation_count": "\(violations.count)",
                        "violation_types": violations.map { violation in
                            violation.metadata.context["violation_types"] ?? "unknown"
                        }.joined(separator: ","),
                        "escalation_detected": "\(analysis.hasEscalation)"
                    ]
                )
            )

            campaigns.append(campaign)
        }

        return campaigns
    }

    private func analyzeViolationPattern(policy: String, violations: [DetectedPattern]) -> ViolationAnalysis {
        let violationTypes = violations.compactMap { violation in
            violation.metadata.context["violation_types"]?.components(separatedBy: ",") ?? []
        }.flatMap { $0 }.filter { !$0.isEmpty }

        // Check for escalation pattern
        let hasEscalation = violations.contains { violation in
            violation.metadata.context["is_increasing"] == "true"
        }

        // Calculate violation frequency
        let totalViolations = violations.map { $0.metadata.frequency }.reduce(0, +)

        return ViolationAnalysis(
            policy: policy,
            violationTypes: Array(Set(violationTypes)),
            totalViolations: totalViolations,
            hasEscalation: hasEscalation,
            severity: violations.first?.metadata.severity ?? .medium,
            timeSpan: calculateViolationTimeSpan(violations)
        )
    }

    private func generatePolicyActions(_ analysis: ViolationAnalysis) -> [SuggestedAction] {
        var actions: [SuggestedAction] = []

        // Policy clarification action
        actions.append(SuggestedAction(
            id: "clarify_policy",
            type: ContractsCore.ActionType.updateEntity,
            description: "Clarify ambiguous policy language",
            parameters: [
                "policy": analysis.policy,
                "clarification_type": "language",
                "target_violations": analysis.violationTypes.joined(separator: ",")
            ],
            estimatedEffort: EffortEstimate(
                hours: 4,
                complexity: .medium,
                risk: .low,
                requiredSkills: ["policy_writing", "legal_review", "domain_knowledge"]
            ),
            prerequisites: ["policy_document", "stakeholder_input"]
        ))

        // Policy education action
        actions.append(SuggestedAction(
            id: "educate_users",
            type: .createEntity,
            description: "Create education materials for policy compliance",
            parameters: [
                "education_type": "policy_training",
                "target_policy": analysis.policy,
                "common_violations": analysis.violationTypes.joined(separator: ",")
            ],
            estimatedEffort: EffortEstimate(
                hours: 6,
                complexity: .simple,
                risk: .low,
                requiredSkills: ["training_development", "documentation"]
            ),
            prerequisites: ["training_platform", "content_review"]
        ))

        // Automated enforcement action
        actions.append(SuggestedAction(
            id: "automate_enforcement",
            type: .createEntity,
            description: "Implement automated policy enforcement checks",
            parameters: [
                "enforcement_type": "automated",
                "target_policy": analysis.policy,
                "violation_types": analysis.violationTypes.joined(separator: ",")
            ],
            estimatedEffort: EffortEstimate(
                hours: 8,
                complexity: .complex,
                risk: .medium,
                requiredSkills: ["automation", "policy_engine", "testing"]
            ),
            prerequisites: ["policy_engine_access", "test_environment"]
        ))

        // Monitoring enhancement action
        actions.append(SuggestedAction(
            id: "enhance_monitoring",
            type: .createEntity,
            description: "Enhance monitoring for policy compliance",
            parameters: [
                "monitoring_type": "policy_compliance",
                "target_policy": analysis.policy,
                "alert_threshold": "5"
            ],
            estimatedEffort: EffortEstimate(
                hours: 3,
                complexity: .simple,
                risk: .low,
                requiredSkills: ["monitoring", "alerting"]
            ),
            prerequisites: ["monitoring_system", "policy_database"]
        ))

        return actions
    }

    private func determinePolicyPriority(_ analysis: ViolationAnalysis) -> CampaignPriority {
        // Higher priority for escalation and high frequency
        let escalationScore = analysis.hasEscalation ? 0.5 : 0.0
        let frequencyScore = min(Double(analysis.totalViolations) / 10.0, 1.0)
        let severityScore = analysis.severity == .high ? 0.5 : 0.25

        let combinedScore = escalationScore + frequencyScore + severityScore

        if combinedScore >= 1.25 { return .critical }
        if combinedScore >= 0.75 { return .high }
        if combinedScore >= 0.5 { return .medium }
        return .low
    }

    private func calculateViolationTimeSpan(_ violations: [DetectedPattern]) -> TimeInterval {
        let timestamps = violations.compactMap { $0.metadata.firstOccurrence }
        guard timestamps.count >= 2 else { return 0 }

        let sorted = timestamps.sorted()
        return sorted.last!.timeIntervalSince(sorted.first!)
    }
}

/// Planner for performance optimization campaigns
public struct PerformanceOptimizationPlanner: CampaignPlanner {
    public func plan(from patterns: [DetectedPattern]) async throws -> [CampaignRecommendation] {
        var campaigns: [CampaignRecommendation] = []

        // Filter for performance degradation patterns
        let performancePatterns = patterns.filter { $0.type == .performanceDegradation }

        for pattern in performancePatterns {
            // Analyze performance pattern
            let analysis = analyzePerformancePattern(pattern)

            // Generate optimization actions
            let actions = generatePerformanceActions(analysis)

            let campaign = CampaignRecommendation(
                id: CampaignId.generate(),
                type: .performanceOptimization,
                priority: determinePerformancePriority(analysis),
                title: "Optimize performance: \(analysis.operation)",
                description: "Address performance degradation in '\(analysis.operation)' with trend slope \(String(format: "%.2f", analysis.trend.slope))",
                rationale: "Performance degradation indicates resource bottlenecks or inefficiencies",
                suggestedActions: actions,
                estimatedImpact: CampaignImpact(
                    successProbability: 0.75,
                    expectedBenefit: "Improve performance by 50%",
                    riskReduction: "Eliminate performance bottlenecks",
                    resourceRequirement: ResourceEstimate(
                        cpuTime: 6 * 3600,  // 6 hours
                        memoryBytes: 2048 * 1024 * 1024,  // 2GB
                        diskBytes: 50 * 1024 * 1024,  // 50MB
                        networkBytes: 0
                    ),
                    timeToImplement: 5 * 24 * 3600  // 5 days
                ),
                sourcePatterns: [pattern.id],
                metadata: CampaignMetadata(
                    version: "1.0",
                    author: "PerformanceOptimizationPlanner",
                    tags: ["performance", "optimization", "bottleneck"],
                    context: [
                        "operation": analysis.operation,
                        "trend_slope": String(format: "%.2f", analysis.trend.slope),
                        "trend_correlation": String(format: "%.2f", analysis.trend.correlation),
                        "avg_duration": String(format: "%.2f", analysis.trend.averageDuration),
                        "recent_duration": String(format: "%.2f", analysis.trend.recentDuration),
                        "degradation_strength": "\(analysis.degradationStrength)"
                    ]
                )
            )

            campaigns.append(campaign)
        }

        return campaigns
    }

    private func analyzePerformancePattern(_ pattern: DetectedPattern) -> PerformanceAnalysis {
        // Extract performance metrics from context
        let operation = pattern.metadata.context["operation"] ?? "unknown"
        let slope = Double(pattern.metadata.context["trend_slope"] ?? "0") ?? 0
        let correlation = Double(pattern.metadata.context["trend_correlation"] ?? "0") ?? 0
        let avgDuration = Double(pattern.metadata.context["avg_duration"] ?? "0") ?? 0
        let recentDuration = Double(pattern.metadata.context["recent_duration"] ?? "0") ?? 0

        // Calculate degradation strength
        let degradationStrength = calculateDegradationStrength(
            slope: slope,
            correlation: Swift.abs(correlation),
            avgDuration: avgDuration,
            recentDuration: recentDuration
        )

        return PerformanceAnalysis(
            operation: operation,
            trend: PerformanceTrend(
                isDegradation: slope > 0.1,
                slope: slope,
                correlation: correlation,
                averageDuration: avgDuration,
                recentDuration: recentDuration
            ),
            degradationStrength: degradationStrength
        )
    }

    private func generatePerformanceActions(_ analysis: PerformanceAnalysis) -> [SuggestedAction] {
        var actions: [SuggestedAction] = []

        // Performance profiling action
        actions.append(SuggestedAction(
            id: "profile_performance",
            type: ContractsCore.ActionType.analyze,
            description: "Profile performance to identify bottlenecks",
            parameters: [
                "profiling_type": "detailed",
                "target_operation": analysis.operation,
                "focus_areas": "cpu,memory,io"
            ],
            estimatedEffort: EffortEstimate(
                hours: 4,
                complexity: .medium,
                risk: .low,
                requiredSkills: ["profiling", "performance_analysis", analysis.operation]
            ),
            prerequisites: ["profiling_tools", "test_environment"]
        ))

        // Resource optimization action
        actions.append(SuggestedAction(
            id: "optimize_resources",
            type: ContractsCore.ActionType.updateEntity,
            description: "Optimize resource usage and allocation",
            parameters: [
                "optimization_type": "resource_efficiency",
                "target_operation": analysis.operation,
                "current_efficiency": String(format: "%.2f", 1.0 / analysis.trend.averageDuration)
            ],
            estimatedEffort: EffortEstimate(
                hours: 8,
                complexity: .complex,
                risk: .medium,
                requiredSkills: ["optimization", "resource_management", analysis.operation]
            ),
            prerequisites: ["resource_monitoring", "optimization_tools"]
        ))

        // Algorithm improvement action
        actions.append(SuggestedAction(
            id: "improve_algorithm",
            type: ContractsCore.ActionType.modifyFile,
            description: "Improve algorithm efficiency in '\(analysis.operation)'",
            parameters: [
                "improvement_type": "algorithmic",
                "target_operation": analysis.operation,
                "current_complexity": String(format: "O(n^%.1f)", analysis.trend.slope * 10)
            ],
            estimatedEffort: EffortEstimate(
                hours: 12,
                complexity: .expert,
                risk: .high,
                requiredSkills: ["algorithms", analysis.operation, "optimization"]
            ),
            prerequisites: ["algorithm_expertise", "performance_benchmarks"]
        ))

        // Caching action
        actions.append(SuggestedAction(
            id: "implement_caching",
            type: .createEntity,
            description: "Implement caching to improve performance",
            parameters: [
                "caching_type": "performance",
                "target_operation": analysis.operation,
                "cache_strategy": "lru_with_ttl"
            ],
            estimatedEffort: EffortEstimate(
                hours: 6,
                complexity: .medium,
                risk: .low,
                requiredSkills: ["caching", "performance_optimization"]
            ),
            prerequisites: ["cache_framework", "storage_analysis"]
        ))

        return actions
    }

    private func determinePerformancePriority(_ analysis: PerformanceAnalysis) -> CampaignPriority {
        // Higher priority for stronger degradation
        let degradationScore = analysis.degradationStrength

        if degradationScore >= 0.8 { return .critical }
        if degradationScore >= 0.6 { return .high }
        if degradationScore >= 0.4 { return .medium }
        return .low
    }

    private func calculateDegradationStrength(
        slope: Double,
        correlation: Double,
        avgDuration: Double,
        recentDuration: Double
    ) -> Double {
        // Combine multiple factors for degradation strength
        let slopeScore = min(Swift.abs(slope) / 0.5, 1.0)  // Normalize slope
        let correlationScore = correlation  // Higher correlation = more consistent trend
        let durationRatio = recentDuration / max(avgDuration, 1.0)  // Recent vs average

        return (slopeScore + correlationScore + durationRatio) / 3.0
    }
}

/// Planner for resource scaling campaigns
public struct ResourceScalingPlanner: CampaignPlanner {
    public func plan(from patterns: [DetectedPattern]) async throws -> [CampaignRecommendation] {
        var campaigns: [CampaignRecommendation] = []

        // Filter for resource exhaustion patterns
        let exhaustionPatterns = patterns.filter { $0.type == .resourceExhaustion }

        // Group by resource type
        let resourceGroups = Dictionary(grouping: exhaustionPatterns) { pattern in
            pattern.metadata.context["resource_type"] ?? "unknown"
        }

        for (resourceType, patterns) in resourceGroups {
            // Analyze resource pattern
            let analysis = analyzeResourcePattern(resourceType: resourceType, patterns: patterns)

            // Generate scaling actions
            let actions = generateResourceActions(analysis)

            let campaign = CampaignRecommendation(
                id: CampaignId.generate(),
                type: .resourceScaling,
                priority: determineResourcePriority(analysis),
                title: "Scale resources: \(resourceType)",
                description: "Address resource exhaustion for '\(resourceType)' with \(patterns.count) instances",
                rationale: "Resource exhaustion indicates insufficient capacity or inefficient usage",
                suggestedActions: actions,
                estimatedImpact: CampaignImpact(
                    successProbability: 0.8,
                    expectedBenefit: "Eliminate resource exhaustion by 95%",
                    riskReduction: "Ensure adequate resource capacity",
                    resourceRequirement: ResourceEstimate(
                        cpuTime: 4 * 3600,  // 4 hours
                        memoryBytes: 1024 * 1024 * 1024,  // 1GB
                        diskBytes: 20 * 1024 * 1024,  // 20MB
                        networkBytes: 0
                    ),
                    timeToImplement: 2 * 24 * 3600  // 2 days
                ),
                sourcePatterns: patterns.map { $0.id },
                metadata: CampaignMetadata(
                    version: "1.0",
                    author: "ResourceScalingPlanner",
                    tags: ["resources", "scaling", "capacity"],
                    context: [
                        "resource_type": resourceType,
                        "exhaustion_count": "\(patterns.count)",
                        "avg_time_to_exhaustion": "\(analysis.avgTimeToExhaustion)",
                        "is_frequent": "\(analysis.isFrequent)"
                    ]
                )
            )

            campaigns.append(campaign)
        }

        return campaigns
    }

    private func analyzeResourcePattern(resourceType: String, patterns: [DetectedPattern]) -> ResourceAnalysis {
        let totalExhaustions = patterns.map { $0.metadata.frequency }.reduce(0, +)
        let avgTimeToExhaustion = patterns.compactMap { pattern in
            pattern.metadata.context["avg_time_to_exhaustion"].flatMap(Double.init)
        }.reduce(0, +) / Double(patterns.count)

        let isFrequent = patterns.contains { pattern in
            pattern.metadata.context["is_frequent"] == "true"
        }

        return ResourceAnalysis(
            resourceType: resourceType,
            totalExhaustions: totalExhaustions,
            avgTimeToExhaustion: avgTimeToExhaustion,
            isFrequent: isFrequent,
            severity: patterns.first?.metadata.severity ?? .medium
        )
    }

    private func generateResourceActions(_ analysis: ResourceAnalysis) -> [SuggestedAction] {
        var actions: [SuggestedAction] = []

        // Capacity increase action
        actions.append(SuggestedAction(
            id: "increase_capacity",
            type: ContractsCore.ActionType.updateEntity,
            description: "Increase \(analysis.resourceType) capacity",
            parameters: [
                "resource_type": analysis.resourceType,
                "current_capacity": "insufficient",
                "recommended_increase": "50"
            ],
            estimatedEffort: EffortEstimate(
                hours: 2,
                complexity: .simple,
                risk: .low,
                requiredSkills: ["resource_management", analysis.resourceType]
            ),
            prerequisites: ["resource_admin", "capacity_planning"]
        ))

        // Resource optimization action
        actions.append(SuggestedAction(
            id: "optimize_usage",
            type: ContractsCore.ActionType.updateEntity,
            description: "Optimize \(analysis.resourceType) usage efficiency",
            parameters: [
                "optimization_type": "efficiency",
                "resource_type": analysis.resourceType,
                "current_efficiency": String(format: "%.2f", 1.0 / analysis.avgTimeToExhaustion)
            ],
            estimatedEffort: EffortEstimate(
                hours: 6,
                complexity: .medium,
                risk: .medium,
                requiredSkills: ["optimization", analysis.resourceType]
            ),
            prerequisites: ["usage_monitoring", "optimization_tools"]
        ))

        // Load balancing action
        actions.append(SuggestedAction(
            id: "implement_load_balancing",
            type: .createEntity,
            description: "Implement load balancing for \(analysis.resourceType)",
            parameters: [
                "balancing_type": "resource_distribution",
                "resource_type": analysis.resourceType,
                "algorithm": "round_robin"
            ],
            estimatedEffort: EffortEstimate(
                hours: 8,
                complexity: .complex,
                risk: .medium,
                requiredSkills: ["load_balancing", "distributed_systems"]
            ),
            prerequisites: ["load_balancer", "multiple_instances"]
        ))

        // Monitoring enhancement action
        actions.append(SuggestedAction(
            id: "enhance_monitoring",
            type: .createEntity,
            description: "Enhance monitoring for \(analysis.resourceType) exhaustion",
            parameters: [
                "monitoring_type": "predictive",
                "resource_type": analysis.resourceType,
                "alert_threshold": "80"
            ],
            estimatedEffort: EffortEstimate(
                hours: 3,
                complexity: .simple,
                risk: .low,
                requiredSkills: ["monitoring", "alerting"]
            ),
            prerequisites: ["monitoring_system", "alert_configuration"]
        ))

        return actions
    }

    private func determineResourcePriority(_ analysis: ResourceAnalysis) -> CampaignPriority {
        // Higher priority for frequent and severe exhaustion
        let frequencyScore = analysis.isFrequent ? 0.5 : 0.0
        let severityScore = analysis.severity == .high ? 0.5 : 0.25

        let combinedScore = frequencyScore + severityScore

        if combinedScore >= 0.75 { return .critical }
        if combinedScore >= 0.5 { return .high }
        if combinedScore >= 0.25 { return .medium }
        return .low
    }
}

// MARK: - Supporting Types

/// Analysis of failure pattern
private struct FailureAnalysis {
    let fingerprint: String
    let operation: String
    let frequency: Int
    let severity: NormalizedSeverity
    let affectedTraces: [String?]  // Trace IDs
    let timeSpan: TimeInterval
}

/// Analysis of violation pattern
private struct ViolationAnalysis {
    let policy: String
    let violationTypes: [String]
    let totalViolations: Int
    let hasEscalation: Bool
    let severity: NormalizedSeverity
    let timeSpan: TimeInterval
}

/// Analysis of performance pattern
private struct PerformanceAnalysis {
    let operation: String
    let trend: PerformanceTrend
    let degradationStrength: Double
}

/// Analysis of resource pattern
private struct ResourceAnalysis {
    let resourceType: String
    let totalExhaustions: Int
    let avgTimeToExhaustion: Double
    let isFrequent: Bool
    let severity: NormalizedSeverity
}
