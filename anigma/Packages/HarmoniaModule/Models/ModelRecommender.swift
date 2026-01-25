//
//  ModelRecommender.swift
//  HarmoniaModule
//
//  ML-ready model selection and optimization recommendations.
//

import AnigmaPrimitives
import DatabaseCore
@preconcurrency import Foundation

/// Model recommendation for a use case
public struct ModelRecommendation: Sendable, Codable {
    public let recommendationId: String
    public let modelId: String
    public let modelName: String
    public let reasoning: String
    public let score: Double  // 0-1
    public let pros: [String]
    public let cons: [String]
    public let costEstimate: String
    public let preferredFor: [String]
    public let performanceRating: String  // low, medium, high, excellent

    public init(
        recommendationId: String,
        modelId: String,
        modelName: String,
        reasoning: String,
        score: Double,
        pros: [String],
        cons: [String],
        costEstimate: String,
        preferredFor: [String],
        performanceRating: String
    ) {
        self.recommendationId = recommendationId
        self.modelId = modelId
        self.modelName = modelName
        self.reasoning = reasoning
        self.score = score
        self.pros = pros
        self.cons = cons
        self.costEstimate = costEstimate
        self.preferredFor = preferredFor
        self.performanceRating = performanceRating
    }
}

/// Query for model selection
public struct ModelSelectionQuery: Sendable, Codable {
    public let queryId: String
    public let useCase: String  // e.g., "code_generation", "summarization", "qa"
    public let maxLatencyMs: Int?
    public let minAccuracy: Double?
    public let maxMemoryMB: Int?
    public let preferSpeed: Bool
    public let preferAccuracy: Bool
    public let budgetConstraint: String?  // "low", "medium", "high"

    public init(
        queryId: String = UUID().uuidString,
        useCase: String,
        maxLatencyMs: Int? = nil,
        minAccuracy: Double? = nil,
        maxMemoryMB: Int? = nil,
        preferSpeed: Bool = false,
        preferAccuracy: Bool = false,
        budgetConstraint: String? = nil
    ) {
        self.queryId = queryId
        self.useCase = useCase
        self.maxLatencyMs = maxLatencyMs
        self.minAccuracy = minAccuracy
        self.maxMemoryMB = maxMemoryMB
        self.preferSpeed = preferSpeed
        self.preferAccuracy = preferAccuracy
        self.budgetConstraint = budgetConstraint
    }
}

/// Model selection result set
public struct ModelSelectionResult: Sendable, Codable {
    public let resultId: String
    public let query: ModelSelectionQuery
    public let recommendations: [ModelRecommendation]
    public let topChoice: ModelRecommendation?
    public let runTime: TimeInterval
    public let considerationFactors: [String]

    public init(
        resultId: String,
        query: ModelSelectionQuery,
        recommendations: [ModelRecommendation],
        topChoice: ModelRecommendation?,
        runTime: TimeInterval,
        considerationFactors: [String]
    ) {
        self.resultId = resultId
        self.query = query
        self.recommendations = recommendations
        self.topChoice = topChoice
        self.runTime = runTime
        self.considerationFactors = considerationFactors
    }
}

/// Optimization suggestion for a model
public struct OptimizationSuggestion: Sendable, Codable {
    public let suggestionId: String
    public let modelId: String
    public let optimization: String  // e.g., "quantization", "pruning", "distillation"
    public let expectedGain: String  // e.g., "30% faster", "50% smaller"
    public let complexity: String  // low, medium, high
    public let estimatedTimeMinutes: Int
    public let riskLevel: String  // low, medium, high
    public let recommendations: [String]

    public init(
        suggestionId: String,
        modelId: String,
        optimization: String,
        expectedGain: String,
        complexity: String,
        estimatedTimeMinutes: Int,
        riskLevel: String,
        recommendations: [String]
    ) {
        self.suggestionId = suggestionId
        self.modelId = modelId
        self.optimization = optimization
        self.expectedGain = expectedGain
        self.complexity = complexity
        self.estimatedTimeMinutes = estimatedTimeMinutes
        self.riskLevel = riskLevel
        self.recommendations = recommendations
    }
}

/// Model recommender for intelligent selection
public actor ModelRecommender {
    private let dbActor: DatabaseActor?
    private var modelScores: [String: Double] = [:]
    private var selectionHistory: [ModelSelectionResult] = []
    private let maxHistorySize = 1000

    public init(dbActor: DatabaseActor? = nil) {
        self.dbActor = dbActor
    }

    /// Recommend models for a query
    public func recommendModels(
        query: ModelSelectionQuery,
        availableModels: [ModelInfo]
    ) -> ModelSelectionResult {
        let startTime = Date()

        var scoredModels: [(model: ModelInfo, score: Double)] = []

        for model in availableModels {
            let score = scoreModel(model: model, query: query)
            scoredModels.append((model, score))
        }

        // Sort by score (highest first)
        scoredModels.sort { $0.score > $1.score }

        // Convert to recommendations
        let recommendations = scoredModels.map { item in
            ModelRecommendation(
                recommendationId: UUID().uuidString,
                modelId: item.model.modelId,
                modelName: item.model.name,
                reasoning: generateReasoning(model: item.model, query: query, score: item.score),
                score: item.score,
                pros: generatePros(model: item.model, query: query),
                cons: generateCons(model: item.model, query: query),
                costEstimate: estimateCost(model: item.model),
                preferredFor: item.model.strengths,
                performanceRating: ratePerformance(model: item.model)
            )
        }

        let topChoice = recommendations.first
        let runTime = Date().timeIntervalSince(startTime)

        let result = ModelSelectionResult(
            resultId: UUID().uuidString,
            query: query,
            recommendations: recommendations,
            topChoice: topChoice,
            runTime: runTime,
            considerationFactors: generateConsiderationFactors(query: query)
        )

        // Store in history
        var history = selectionHistory
        history.append(result)
        if history.count > maxHistorySize {
            history = Array(history.suffix(maxHistorySize / 2))
        }
        selectionHistory = history

        return result
    }

    /// Get optimization suggestions for a model
    public func suggestOptimizations(model: ModelInfo) -> [OptimizationSuggestion] {
        var suggestions: [OptimizationSuggestion] = []

        // Quantization suggestion
        if model.sizeBytes > 1_000_000_000 {  // > 1GB
            suggestions.append(OptimizationSuggestion(
                suggestionId: UUID().uuidString,
                modelId: model.modelId,
                optimization: "Quantization (INT8)",
                expectedGain: "50-75% smaller, 2-4x faster",
                complexity: "low",
                estimatedTimeMinutes: 30,
                riskLevel: "low",
                recommendations: [
                    "Apply INT8 quantization to reduce model size",
                    "Test on representative data before production",
                    "Expect 0.5-2% accuracy loss"
                ]
            ))
        }

        // Pruning suggestion
        if model.parameterCount > 1_000_000_000 {  // > 1B parameters
            suggestions.append(OptimizationSuggestion(
                suggestionId: UUID().uuidString,
                modelId: model.modelId,
                optimization: "Structured Pruning",
                expectedGain: "30-40% smaller, 1.5-2.5x faster",
                complexity: "medium",
                estimatedTimeMinutes: 120,
                riskLevel: "medium",
                recommendations: [
                    "Remove redundant attention heads and layers",
                    "Fine-tune on task data after pruning",
                    "Expect 1-3% accuracy loss"
                ]
            ))
        }

        // Distillation suggestion
        if model.parameterCount > 100_000_000 {  // > 100M parameters
            suggestions.append(OptimizationSuggestion(
                suggestionId: UUID().uuidString,
                modelId: model.modelId,
                optimization: "Knowledge Distillation",
                expectedGain: "60-70% smaller student model",
                complexity: "high",
                estimatedTimeMinutes: 480,
                riskLevel: "medium",
                recommendations: [
                    "Train smaller student model using teacher knowledge",
                    "Use temperature=3-5 for soft targets",
                    "Can maintain 95%+ of original accuracy"
                ]
            ))
        }

        // LoRA fine-tuning suggestion
        if !model.supportsLoRA {
            suggestions.append(OptimizationSuggestion(
                suggestionId: UUID().uuidString,
                modelId: model.modelId,
                optimization: "LoRA Fine-tuning",
                expectedGain: "Task-specific adaptation with minimal overhead",
                complexity: "medium",
                estimatedTimeMinutes: 60,
                riskLevel: "low",
                recommendations: [
                    "Add LoRA adapters for task-specific optimization",
                    "Freeze base model weights",
                    "Only ~1-5% additional parameters"
                ]
            ))
        }

        return suggestions
    }

    /// Compare models on specific metrics
    public func compareModelsCost(models: [ModelInfo]) -> [String: Double] {
        var costs: [String: Double] = [:]

        for model in models {
            // Cost = (size in GB) * (inference latency in seconds) / accuracy
            let sizeGigabytes = Double(model.sizeBytes) / (1024 * 1024 * 1024)
            let estimatedLatency = Double(model.estimatedLatencyMs) / 1000.0
            let accuracy = model.estimatedAccuracy

            let cost = (sizeGigabytes * estimatedLatency) / max(0.1, accuracy)
            costs[model.modelId] = cost
        }

        return costs
    }

    /// Get selection recommendations for different constraints
    public func recommendByConstraint(
        constraint: String,  // "speed", "accuracy", "memory", "balanced"
        availableModels: [ModelInfo]
    ) -> [ModelRecommendation] {
        let query = ModelSelectionQuery(
            useCase: "general",
            preferSpeed: constraint == "speed",
            preferAccuracy: constraint == "accuracy"
        )

        return recommendModels(query: query, availableModels: availableModels).recommendations
    }

    // MARK: - Private Helpers

    private func scoreModel(model: ModelInfo, query: ModelSelectionQuery) -> Double {
        var score = 0.5  // Base score

        // Accuracy component (20%)
        if let minAccuracy = query.minAccuracy {
            if model.estimatedAccuracy >= minAccuracy {
                score += 0.2 * min(1.0, model.estimatedAccuracy / 0.95)
            } else {
                score -= 0.2
            }
        } else {
            score += 0.2 * model.estimatedAccuracy
        }

        // Latency component (25%)
        if let maxLatency = query.maxLatencyMs {
            if model.estimatedLatencyMs <= maxLatency {
                score += 0.25 * (1.0 - Double(model.estimatedLatencyMs) / Double(maxLatency))
            } else {
                score -= 0.25
            }
        } else if query.preferSpeed {
            score += 0.25 * max(0, 1.0 - Double(model.estimatedLatencyMs) / 1000.0)
        } else {
            score += 0.25 * 0.5  // Neutral
        }

        // Memory component (20%)
        if let maxMemory = query.maxMemoryMB {
            if model.estimatedMemoryMB <= maxMemory {
                score += 0.2 * (1.0 - Double(model.estimatedMemoryMB) / Double(maxMemory))
            } else {
                score -= 0.2
            }
        } else {
            score += 0.2 * max(0, 1.0 - Double(model.estimatedMemoryMB) / 16000.0)
        }

        // Use case match (20%)
        let useCaseMatch = model.strengths.contains(query.useCase) ? 0.8 : 0.4
        score += 0.2 * useCaseMatch

        // Budget constraint (15%, bonus)
        if let budget = query.budgetConstraint {
            let budgetScore = evaluateBudgetAlignment(model: model, budget: budget)
            score += 0.15 * budgetScore
        }

        return min(1.0, max(0.0, score))
    }

    private func generateReasoning(model: ModelInfo, query: ModelSelectionQuery, score: Double) -> String {
        var reasons: [String] = []

        if model.estimatedAccuracy > 0.9 {
            reasons.append("excellent accuracy (\(Int(model.estimatedAccuracy * 100))%)")
        }

        if model.estimatedLatencyMs < 100 {
            reasons.append("very fast (\(model.estimatedLatencyMs)ms)")
        } else if model.estimatedLatencyMs < 500 {
            reasons.append("good latency (\(model.estimatedLatencyMs)ms)")
        }

        if model.strengths.contains(query.useCase) {
            reasons.append("optimized for \(query.useCase)")
        }

        if reasons.isEmpty {
            reasons.append("balanced performance profile")
        }

        let reasonsText = reasons.joined(separator: ", ")
        return "Selected for: \(reasonsText)"
    }

    private func generatePros(model: ModelInfo, query: ModelSelectionQuery) -> [String] {
        var pros: [String] = []

        pros.append("Estimated accuracy: \(Int(model.estimatedAccuracy * 100))%")
        pros.append("Latency: \(model.estimatedLatencyMs)ms")
        pros.append("Size: \(model.sizeBytes / (1024 * 1024))MB")

        if model.strengths.contains(query.useCase) {
            pros.append("Optimized for \(query.useCase)")
        }

        if model.supportsQuantization {
            pros.append("Quantization support for faster inference")
        }

        if model.supportsLoRA {
            pros.append("LoRA fine-tuning available")
        }

        return pros
    }

    private func generateCons(model: ModelInfo, query: ModelSelectionQuery) -> [String] {
        var cons: [String] = []

        if model.estimatedLatencyMs > 500 {
            cons.append("High latency for real-time applications")
        }

        if model.estimatedMemoryMB > 8000 {
            cons.append("High memory footprint")
        }

        if !model.strengths.contains(query.useCase) {
            cons.append("Not specifically optimized for \(query.useCase)")
        }

        if model.isExperimental {
            cons.append("Experimental version - not recommended for production")
        }

        if cons.isEmpty {
            cons.append("Larger models may have slower convergence when fine-tuning")
        }

        return cons
    }

    private func estimateCost(model: ModelInfo) -> String {
        let sizeGB = Double(model.sizeBytes) / (1024 * 1024 * 1024)
        let latencySec = Double(model.estimatedLatencyMs) / 1000.0

        let estimatedCost = sizeGB * latencySec

        if estimatedCost < 1.0 {
            return "very low"
        } else if estimatedCost < 5.0 {
            return "low"
        } else if estimatedCost < 20.0 {
            return "moderate"
        } else {
            return "high"
        }
    }

    private func ratePerformance(model: ModelInfo) -> String {
        if model.estimatedAccuracy > 0.92 && model.estimatedLatencyMs < 200 {
            return "excellent"
        } else if model.estimatedAccuracy > 0.85 && model.estimatedLatencyMs < 500 {
            return "high"
        } else if model.estimatedAccuracy > 0.75 {
            return "medium"
        } else {
            return "low"
        }
    }

    private func generateConsiderationFactors(query: ModelSelectionQuery) -> [String] {
        var factors: [String] = []

        if query.maxLatencyMs != nil {
            factors.append("Latency constraint: \(query.maxLatencyMs ?? 0)ms")
        }

        if query.minAccuracy != nil {
            factors.append("Minimum accuracy: \(Int((query.minAccuracy ?? 0) * 100))%")
        }

        if query.maxMemoryMB != nil {
            factors.append("Memory limit: \(query.maxMemoryMB ?? 0)MB")
        }

        if query.preferSpeed {
            factors.append("Optimization: prioritize speed")
        }

        if query.preferAccuracy {
            factors.append("Optimization: prioritize accuracy")
        }

        return factors
    }

    private func evaluateBudgetAlignment(model: ModelInfo, budget: String) -> Double {
        let cost = (Double(model.sizeBytes) / (1024 * 1024 * 1024)) *
                   (Double(model.estimatedLatencyMs) / 1000.0)

        switch budget {
        case "low":
            return cost < 2.0 ? 1.0 : max(0, 1.0 - cost / 5.0)
        case "medium":
            return cost < 10.0 ? 1.0 : max(0, 1.0 - cost / 20.0)
        case "high":
            return 0.8  // Less important for high budget
        default:
            return 0.5
        }
    }
}

/// Model information for selection
public struct ModelInfo: Sendable, Codable {
    public let modelId: String
    public let name: String
    public let provider: String
    public let sizeBytes: Int
    public let parameterCount: Int
    public let estimatedLatencyMs: Int
    public let estimatedMemoryMB: Int
    public let estimatedAccuracy: Double  // 0-1
    public let strengths: [String]
    public let supportsQuantization: Bool
    public let supportsLoRA: Bool
    public let isExperimental: Bool
    public let releaseDate: Date
    public let lastUpdateDate: Date

    public init(
        modelId: String,
        name: String,
        provider: String,
        sizeBytes: Int,
        parameterCount: Int,
        estimatedLatencyMs: Int,
        estimatedMemoryMB: Int,
        estimatedAccuracy: Double,
        strengths: [String],
        supportsQuantization: Bool,
        supportsLoRA: Bool,
        isExperimental: Bool,
        releaseDate: Date,
        lastUpdateDate: Date
    ) {
        self.modelId = modelId
        self.name = name
        self.provider = provider
        self.sizeBytes = sizeBytes
        self.parameterCount = parameterCount
        self.estimatedLatencyMs = estimatedLatencyMs
        self.estimatedMemoryMB = estimatedMemoryMB
        self.estimatedAccuracy = estimatedAccuracy
        self.strengths = strengths
        self.supportsQuantization = supportsQuantization
        self.supportsLoRA = supportsLoRA
        self.isExperimental = isExperimental
        self.releaseDate = releaseDate
        self.lastUpdateDate = lastUpdateDate
    }
}
