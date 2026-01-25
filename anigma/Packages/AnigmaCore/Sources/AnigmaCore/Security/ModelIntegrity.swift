//
//  ModelIntegrity.swift
//  AnigmaCore
//
//  Model integrity and anti-tampering infrastructure.
//  Protects against data poisoning, model drift, and adversarial attacks.
//
//  This addresses critical AI/ML vulnerabilities:
//  - Data poisoning attacks that corrupt training data
//  - Model drift that degrades accuracy over time
//  - Adversarial inputs designed to bypass detection
//
//  Design principles:
//  - Continuous monitoring of model behavior
//  - Statistical anomaly detection for inputs
//  - Baseline comparison for drift detection
//  - Cryptographic verification of model artifacts
//

import Foundation
import ContractsCore
import CryptoKit

// MARK: - Model Registration

/// Represents a registered ML model with integrity metadata.
public struct RegisteredModel: Sendable, Codable, Identifiable {
    public let id: UUID

    /// Human-readable name.
    public let name: String

    /// Version identifier.
    public let version: String

    /// SHA-256 hash of the model weights/parameters.
    public let modelHash: String

    /// When the model was registered.
    public let registeredAt: Date

    /// Who registered the model.
    public let registeredBy: String

    /// Expected input schema description.
    public let inputSchema: String

    /// Expected output schema description.
    public let outputSchema: String

    /// Baseline performance metrics at registration.
    public let baselineMetrics: ModelMetrics

    /// Tags for categorization.
    public let tags: Set<String>

    /// Whether this model is currently active.
    public var isActive: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        version: String,
        modelHash: String,
        registeredAt: Date = Date(),
        registeredBy: String,
        inputSchema: String,
        outputSchema: String,
        baselineMetrics: ModelMetrics,
        tags: Set<String> = [],
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.modelHash = modelHash
        self.registeredAt = registeredAt
        self.registeredBy = registeredBy
        self.inputSchema = inputSchema
        self.outputSchema = outputSchema
        self.baselineMetrics = baselineMetrics
        self.tags = tags
        self.isActive = isActive
    }
}

/// Performance metrics for a model.
public struct ModelMetrics: Sendable, Codable {
    /// Accuracy on validation set (0.0 - 1.0).
    public let accuracy: Double?

    /// Precision metric.
    public let precision: Double?

    /// Recall metric.
    public let recall: Double?

    /// F1 score.
    public let f1Score: Double?

    /// Average inference latency in milliseconds.
    public let averageLatencyMs: Double?

    /// 95th percentile latency.
    public let p95LatencyMs: Double?

    /// False positive rate.
    public let falsePositiveRate: Double?

    /// False negative rate.
    public let falseNegativeRate: Double?

    /// Custom metrics.
    public let custom: [String: Double]

    public init(
        accuracy: Double? = nil,
        precision: Double? = nil,
        recall: Double? = nil,
        f1Score: Double? = nil,
        averageLatencyMs: Double? = nil,
        p95LatencyMs: Double? = nil,
        falsePositiveRate: Double? = nil,
        falseNegativeRate: Double? = nil,
        custom: [String: Double] = [:]
    ) {
        self.accuracy = accuracy
        self.precision = precision
        self.recall = recall
        self.f1Score = f1Score
        self.averageLatencyMs = averageLatencyMs
        self.p95LatencyMs = p95LatencyMs
        self.falsePositiveRate = falsePositiveRate
        self.falseNegativeRate = falseNegativeRate
        self.custom = custom
    }
}

// MARK: - Drift Detection

/// Types of drift that can be detected.
public enum DriftType: String, Sendable, Codable {
    /// Input data distribution has changed.
    case dataDrift = "DATA_DRIFT"

    /// Model predictions are drifting from baseline.
    case conceptDrift = "CONCEPT_DRIFT"

    /// Model performance is degrading.
    case performanceDrift = "PERFORMANCE_DRIFT"

    /// Input features are outside expected ranges.
    case featureDrift = "FEATURE_DRIFT"
}

/// A detected drift event.
public struct DriftEvent: Sendable, Codable, Identifiable {
    public let id: UUID

    /// The model experiencing drift.
    public let modelId: UUID

    /// Type of drift detected.
    public let driftType: DriftType

    /// Severity (0.0 = minor, 1.0 = critical).
    public let severity: Double

    /// Description of the drift.
    public let description: String

    /// The metric that drifted.
    public let affectedMetric: String

    /// Baseline value.
    public let baselineValue: Double

    /// Current observed value.
    public let currentValue: Double

    /// Threshold that was exceeded.
    public let threshold: Double

    /// When the drift was detected.
    public let detectedAt: Date

    /// Recommended actions.
    public let recommendations: [String]

    public init(
        id: UUID = UUID(),
        modelId: UUID,
        driftType: DriftType,
        severity: Double,
        description: String,
        affectedMetric: String,
        baselineValue: Double,
        currentValue: Double,
        threshold: Double,
        detectedAt: Date = Date(),
        recommendations: [String] = []
    ) {
        self.id = id
        self.modelId = modelId
        self.driftType = driftType
        self.severity = min(1.0, max(0.0, severity))
        self.description = description
        self.affectedMetric = affectedMetric
        self.baselineValue = baselineValue
        self.currentValue = currentValue
        self.threshold = threshold
        self.detectedAt = detectedAt
        self.recommendations = recommendations
    }
}

// MARK: - Poisoning Detection

/// Types of data poisoning attacks.
public enum PoisoningType: String, Sendable, Codable {
    /// Intentional mislabeling of training data.
    case labelFlipping = "LABEL_FLIPPING"

    /// Injection of adversarial samples.
    case adversarialInjection = "ADVERSARIAL_INJECTION"

    /// Subtle modification of feature values.
    case featurePerturbation = "FEATURE_PERTURBATION"

    /// Backdoor triggers embedded in data.
    case backdoorInsertion = "BACKDOOR_INSERTION"

    /// Gradual shifting of data distribution.
    case gradualPoisoning = "GRADUAL_POISONING"
}

/// A detected poisoning attempt.
public struct PoisoningAlert: Sendable, Codable, Identifiable {
    public let id: UUID

    /// The model targeted.
    public let modelId: UUID

    /// Type of poisoning detected.
    public let poisoningType: PoisoningType

    /// Confidence in the detection (0.0 - 1.0).
    public let confidence: Double

    /// Description of the detected attack.
    public let description: String

    /// Evidence supporting the detection.
    public let evidence: [String]

    /// Affected data samples (if known).
    public let affectedSamples: Int?

    /// When detected.
    public let detectedAt: Date

    /// Whether the attack was blocked.
    public let wasBlocked: Bool

    /// Remediation steps taken.
    public let remediationSteps: [String]

    public init(
        id: UUID = UUID(),
        modelId: UUID,
        poisoningType: PoisoningType,
        confidence: Double,
        description: String,
        evidence: [String] = [],
        affectedSamples: Int? = nil,
        detectedAt: Date = Date(),
        wasBlocked: Bool = false,
        remediationSteps: [String] = []
    ) {
        self.id = id
        self.modelId = modelId
        self.poisoningType = poisoningType
        self.confidence = min(1.0, max(0.0, confidence))
        self.description = description
        self.evidence = evidence
        self.affectedSamples = affectedSamples
        self.detectedAt = detectedAt
        self.wasBlocked = wasBlocked
        self.remediationSteps = remediationSteps
    }
}

// MARK: - Input Validation

/// Validates inputs against expected schemas and detects anomalies.
public struct InputValidator: Sendable {
    /// Statistical bounds for numeric features.
    public struct FeatureBounds: Sendable, Codable {
        public let min: Double
        public let max: Double
        public let mean: Double
        public let stdDev: Double

        public init(min: Double, max: Double, mean: Double, stdDev: Double) {
            self.min = min
            self.max = max
            self.mean = mean
            self.stdDev = stdDev
        }

        /// Checks if a value is within acceptable bounds.
        public func isValid(_ value: Double, sigmas: Double = 3.0) -> Bool {
            // Basic range check
            guard value >= min && value <= max else { return false }

            // Statistical check (within N standard deviations)
            let deviation = Swift.abs(value - mean) / stdDev
            return deviation <= sigmas
        }

        /// Gets the anomaly score for a value (higher = more anomalous).
        public func anomalyScore(_ value: Double) -> Double {
            if value < min || value > max {
                return 1.0
            }

            guard stdDev > 0 else { return 0 }

            let deviation = Swift.abs(value - mean) / stdDev
            // Normalize to 0-1 range (3 sigmas = 1.0)
            return Swift.min(1.0, deviation / 3.0)
        }
    }

    /// Feature bounds by name.
    public let featureBounds: [String: FeatureBounds]

    /// Required features.
    public let requiredFeatures: Set<String>

    public init(
        featureBounds: [String: FeatureBounds] = [:],
        requiredFeatures: Set<String> = []
    ) {
        self.featureBounds = featureBounds
        self.requiredFeatures = requiredFeatures
    }

    /// Validates an input and returns validation result.
    public func validate(_ input: [String: Double]) -> InputValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        var anomalyScores: [String: Double] = [:]

        // Check required features
        for required in requiredFeatures {
            if input[required] == nil {
                errors.append("Missing required feature: \(required)")
            }
        }

        // Check feature bounds
        for (feature, value) in input {
            if let bounds = featureBounds[feature] {
                let score = bounds.anomalyScore(value)
                anomalyScores[feature] = score

                if score >= 1.0 {
                    errors.append("Feature '\(feature)' out of bounds: \(value)")
                } else if score >= 0.7 {
                    warnings.append("Feature '\(feature)' is unusual: \(value) (anomaly score: \(String(format: "%.2f", score)))")
                }
            }
        }

        // Calculate overall anomaly score
        let totalScore = anomalyScores.isEmpty ? 0 : anomalyScores.values.reduce(0, +) / Double(anomalyScores.count)

        return InputValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings,
            anomalyScores: anomalyScores,
            overallAnomalyScore: totalScore
        )
    }
}

/// Result of input validation.
public struct InputValidationResult: Sendable {
    public let isValid: Bool
    public let errors: [String]
    public let warnings: [String]
    public let anomalyScores: [String: Double]
    public let overallAnomalyScore: Double

    public var isPotentiallyMalicious: Bool {
        overallAnomalyScore >= 0.8
    }
}

// MARK: - Model Integrity Manager

/// Central manager for model integrity and security.
public actor ModelIntegrityManager {
    private var registeredModels: [UUID: RegisteredModel] = [:]
    private var driftEvents: [DriftEvent] = []
    private var poisoningAlerts: [PoisoningAlert] = []
    private var inputValidators: [UUID: InputValidator] = [:]
    private var auditLog: (any AuditLogging)?

    // Drift detection thresholds
    private let accuracyDriftThreshold: Double = 0.05  // 5% accuracy drop
    private let latencyDriftThreshold: Double = 0.20   // 20% latency increase
    private let distributionDriftThreshold: Double = 0.10

    public init() {}

    /// Sets the audit log.
    public func setAuditLog(_ log: any AuditLogging) {
        self.auditLog = log
    }

    /// Registers a new model.
    public func registerModel(_ model: RegisteredModel) async {
        registeredModels[model.id] = model

        if let log = auditLog {
            try? await log.recordEvent(
                id: UUID(),
                type: ContractsCore.AuditEventType.dataCreated,
                principal: nil,
                module: "ModelIntegrityManager",
                description: "Model registered: \(model.name) v\(model.version)",
                metadata: [
                    "model_id": model.id.uuidString,
                    "model_hash": model.modelHash
                ]
            )
        }
    }

    /// Sets the input validator for a model.
    public func setValidator(_ validator: InputValidator, for modelId: UUID) {
        inputValidators[modelId] = validator
    }

    /// Verifies a model's integrity using its hash.
    public func verifyModelIntegrity(modelId: UUID, currentHash: String) async -> ModelIntegrityResult {
        guard let model = registeredModels[modelId] else {
            return ModelIntegrityResult(
                isValid: false,
                reason: "Model not registered",
                modelId: modelId
            )
        }

        let isValid = model.modelHash == currentHash

        if !isValid, let log = auditLog {
            try? await log.recordEvent(
                id: UUID(),
                type: ContractsCore.AuditEventType.policyViolation,
                principal: nil,
                module: "ModelIntegrityManager",
                description: "Model integrity check failed: hash mismatch",
                metadata: [
                    "model_id": modelId.uuidString,
                    "expected_hash": model.modelHash,
                    "actual_hash": currentHash
                ]
            )
        }

        return ModelIntegrityResult(
            isValid: isValid,
            reason: isValid ? "Hash matches registered value" : "Hash mismatch - model may be tampered",
            modelId: modelId,
            expectedHash: model.modelHash,
            actualHash: currentHash
        )
    }

    /// Validates input for a model.
    public func validateInput(modelId: UUID, input: [String: Double]) async -> InputValidationResult {
        guard let validator = inputValidators[modelId] else {
            // No validator registered, allow with warning
            return InputValidationResult(
                isValid: true,
                errors: [],
                warnings: ["No input validator registered for model"],
                anomalyScores: [:],
                overallAnomalyScore: 0
            )
        }

        let result = validator.validate(input)

        if result.isPotentiallyMalicious, let log = auditLog {
            try? await log.recordEvent(
                id: UUID(),
                type: ContractsCore.AuditEventType.policyViolation,
                principal: nil,
                module: "ModelIntegrityManager",
                description: "Potentially malicious input detected",
                metadata: [
                    "model_id": modelId.uuidString,
                    "anomaly_score": String(format: "%.2f", result.overallAnomalyScore)
                ]
            )
        }

        return result
    }

    /// Records current metrics and checks for drift.
    public func checkForDrift(
        modelId: UUID,
        currentMetrics: ModelMetrics
    ) async -> [DriftEvent] {
        guard let model = registeredModels[modelId] else {
            return []
        }

        var newDriftEvents: [DriftEvent] = []
        let baseline = model.baselineMetrics

        // Check accuracy drift
        if let baselineAcc = baseline.accuracy, let currentAcc = currentMetrics.accuracy {
            let drift = baselineAcc - currentAcc
            if drift > accuracyDriftThreshold {
                let event = DriftEvent(
                    modelId: modelId,
                    driftType: .performanceDrift,
                    severity: min(1.0, drift / accuracyDriftThreshold),
                    description: "Accuracy has degraded by \(String(format: "%.1f%%", drift * 100))",
                    affectedMetric: "accuracy",
                    baselineValue: baselineAcc,
                    currentValue: currentAcc,
                    threshold: accuracyDriftThreshold,
                    recommendations: [
                        "Review recent training data for quality issues",
                        "Consider retraining with verified clean data",
                        "Check for data distribution changes"
                    ]
                )
                newDriftEvents.append(event)
            }
        }

        // Check latency drift
        if let baselineLat = baseline.averageLatencyMs, let currentLat = currentMetrics.averageLatencyMs {
            let increase = (currentLat - baselineLat) / baselineLat
            if increase > latencyDriftThreshold {
                let event = DriftEvent(
                    modelId: modelId,
                    driftType: .performanceDrift,
                    severity: min(1.0, increase / latencyDriftThreshold),
                    description: "Latency has increased by \(String(format: "%.1f%%", increase * 100))",
                    affectedMetric: "latency",
                    baselineValue: baselineLat,
                    currentValue: currentLat,
                    threshold: latencyDriftThreshold,
                    recommendations: [
                        "Check system resource utilization",
                        "Review input data complexity",
                        "Consider model optimization"
                    ]
                )
                newDriftEvents.append(event)
            }
        }

        // Check false positive rate drift
        if let baselineFPR = baseline.falsePositiveRate, let currentFPR = currentMetrics.falsePositiveRate {
            let increase = currentFPR - baselineFPR
            if increase > distributionDriftThreshold {
                let event = DriftEvent(
                    modelId: modelId,
                    driftType: .conceptDrift,
                    severity: min(1.0, increase / distributionDriftThreshold),
                    description: "False positive rate has increased by \(String(format: "%.1f%%", increase * 100))",
                    affectedMetric: "false_positive_rate",
                    baselineValue: baselineFPR,
                    currentValue: currentFPR,
                    threshold: distributionDriftThreshold,
                    recommendations: [
                        "Review classification thresholds",
                        "Analyze recent false positives for patterns",
                        "Consider threshold adjustment or retraining"
                    ]
                )
                newDriftEvents.append(event)
            }
        }

        // Store and log events
        for event in newDriftEvents {
            driftEvents.append(event)

            if let log = auditLog {
                try? await log.recordEvent(
                    id: UUID(),
                    type: ContractsCore.AuditEventType.policyViolation,
                    principal: nil,
                    module: "ModelIntegrityManager",
                    description: "Model drift detected: \(event.driftType.rawValue)",
                    metadata: [
                        "model_id": modelId.uuidString,
                        "drift_type": event.driftType.rawValue,
                        "severity": String(format: "%.2f", event.severity),
                        "metric": event.affectedMetric
                    ]
                )
            }
        }

        return newDriftEvents
    }

    /// Records a poisoning alert.
    public func recordPoisoningAlert(_ alert: PoisoningAlert) async {
        poisoningAlerts.append(alert)

        if let log = auditLog {
            try? await log.recordEvent(
                id: UUID(),
                type: ContractsCore.AuditEventType.policyViolation,
                principal: nil,
                module: "ModelIntegrityManager",
                description: "Data poisoning detected: \(alert.poisoningType.rawValue)",
                metadata: [
                    "model_id": alert.modelId.uuidString,
                    "poisoning_type": alert.poisoningType.rawValue,
                    "confidence": String(format: "%.2f", alert.confidence),
                    "blocked": alert.wasBlocked ? "true" : "false"
                ]
            )
        }
    }

    /// Gets all drift events for a model.
    public func getDriftEvents(modelId: UUID? = nil, since: Date? = nil) -> [DriftEvent] {
        var results = driftEvents

        if let modelId = modelId {
            results = results.filter { $0.modelId == modelId }
        }

        if let since = since {
            results = results.filter { $0.detectedAt >= since }
        }

        return results.sorted { $0.detectedAt > $1.detectedAt }
    }

    /// Gets all poisoning alerts.
    public func getPoisoningAlerts(modelId: UUID? = nil, since: Date? = nil) -> [PoisoningAlert] {
        var results = poisoningAlerts

        if let modelId = modelId {
            results = results.filter { $0.modelId == modelId }
        }

        if let since = since {
            results = results.filter { $0.detectedAt >= since }
        }

        return results.sorted { $0.detectedAt > $1.detectedAt }
    }

    /// Gets a model by ID.
    public func getModel(_ id: UUID) -> RegisteredModel? {
        registeredModels[id]
    }

    /// Lists all registered models.
    public func listModels() -> [RegisteredModel] {
        Array(registeredModels.values)
    }

    /// Deactivates a model (e.g., after integrity failure).
    public func deactivateModel(_ id: UUID, reason: String) async {
        guard var model = registeredModels[id] else { return }

        model.isActive = false
        registeredModels[id] = model

        if let log = auditLog {
            try? await log.recordEvent(
                id: UUID(),
                type: ContractsCore.AuditEventType.custom,
                principal: nil,
                module: "ModelIntegrityManager",
                description: "Model deactivated: \(reason)",
                metadata: [
                    "model_id": id.uuidString,
                    "model_name": model.name,
                    "original_event_type": "systemStopped"
                ]
            )
        }
    }
}

/// Result of model integrity verification.
public struct ModelIntegrityResult: Sendable {
    public let isValid: Bool
    public let reason: String
    public let modelId: UUID
    public let expectedHash: String?
    public let actualHash: String?

    public init(
        isValid: Bool,
        reason: String,
        modelId: UUID,
        expectedHash: String? = nil,
        actualHash: String? = nil
    ) {
        self.isValid = isValid
        self.reason = reason
        self.modelId = modelId
        self.expectedHash = expectedHash
        self.actualHash = actualHash
    }
}

// MARK: - Model Hash Utilities

/// Utilities for computing model hashes.
public enum ModelHasher {
    /// Computes SHA-256 hash of model data.
    public static func computeHash(data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Computes SHA-256 hash of a file.
    public static func computeHash(fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        return computeHash(data: data)
    }
}
