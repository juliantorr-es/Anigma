//
//  Sampling.swift
//  TelemetryCore
//
//  Sampling system that respects privacy posture and event sensitivity.
//  Implements probabilistic sampling with minimum guarantees for critical events.
//

import Foundation

/// Sampling system that respects privacy classifications.
public struct Sampling {
    /// Determines if an event should be sampled based on privacy classification.
    public static func shouldSample(_ event: TelemetryEvent) -> Bool {
        var rng = SystemRandomNumberGenerator()
        let rate = samplingRate(for: event.privacyClassification)

        // Critical events are always sampled regardless of rate
        if isCriticalEvent(event) {
            return true
        }

        // Probabilistic sampling
        return Double.random(in: 0...1, using: &rng) <= rate
    }

    /// Returns the sampling rate for a given privacy classification.
    private static func samplingRate(for classification: PrivacyClassification) -> Double {
        switch classification {
        case .public: return 1.0        // Always sample
        case .internal: return 0.1      // 10% sample
        case .restricted: return 0.01   // 1% sample
        }
    }

    /// Determines if an event is critical and should bypass sampling.
    private static func isCriticalEvent(_ event: TelemetryEvent) -> Bool {
        switch event.category {
        case .security:
            return true // Security events are always sampled
        case .error:
            // Critical error patterns
            if event.name.contains("critical") || event.name.contains("fatal") {
                return true
            }
            return false
        case .system:
            // System startup/shutdown are critical
            if event.name.contains("startup") || event.name.contains("shutdown") {
                return true
            }
            return false
        default:
            return false
        }
    }
}

/// Sampling configuration for different environments.
public struct SamplingConfiguration: Sendable, Codable {
    public let environment: Environment
    public let privacySamplingRates: [PrivacyClassification: Double]
    public let alwaysSampleCategories: Set<TelemetryCategory>
    public let minimumGuaranteedEvents: Int // Minimum events to always sample per hour

    public enum Environment: String, Sendable, Codable {
        case development
        case staging
        case production
    }

    public static let `default` = SamplingConfiguration(
        environment: .production,
        privacySamplingRates: [
            .public: 1.0,
            .internal: 0.1,
            .restricted: 0.01
        ],
        alwaysSampleCategories: [.security],
        minimumGuaranteedEvents: 100
    )

    public static let development = SamplingConfiguration(
        environment: .development,
        privacySamplingRates: [
            .public: 1.0,
            .internal: 1.0,
            .restricted: 0.1
        ],
        alwaysSampleCategories: [.security, .error, .system],
        minimumGuaranteedEvents: 1000
    )

    /// Gets the sampling rate for a privacy classification in this configuration.
    public func samplingRate(for classification: PrivacyClassification) -> Double {
        privacySamplingRates[classification] ?? 0.01 // Default to very conservative
    }

    /// Determines if an event category should always be sampled.
    public func shouldAlwaysSample(_ category: TelemetryCategory) -> Bool {
        alwaysSampleCategories.contains(category)
    }
}
