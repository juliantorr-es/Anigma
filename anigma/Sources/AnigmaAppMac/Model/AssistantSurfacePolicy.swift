//
//  AssistantSurfacePolicy.swift
//  AnigmaAppMac
//
//  Defines the disclosure capacity rules and calm surface defaults for the assistant.
//  Formalizes depth limits and routing rules for advanced details to ensure consistency across views.
//

import Foundation

// MARK: - Disclosure Sections

enum AssistantDisclosureSection {
    case sources
    case missingContext
    case nondeterminismReasons
}

// MARK: - Disclosure Capacity

struct AssistantDisclosureCapacityWindow {
    let visibleCount: Int
    let collapsedHiddenCount: Int
    let overflowCount: Int
}

struct AssistantDisclosureCapacityRules: Sendable, Codable, Hashable {
    let sourceDefaultCount: Int
    let sourceMaxCount: Int
    let missingContextDefaultCount: Int
    let missingContextMaxCount: Int
    let nondeterminismDefaultCount: Int
    let nondeterminismMaxCount: Int

    static let calmDefault = AssistantDisclosureCapacityRules(
        sourceDefaultCount: 3,
        sourceMaxCount: 8,
        missingContextDefaultCount: 2,
        missingContextMaxCount: 6,
        nondeterminismDefaultCount: 2,
        nondeterminismMaxCount: 6
    )
    
    static let `default` = calmDefault

    var validationIssues: [String] {
        issues(section: "sources", defaultCount: sourceDefaultCount, maxCount: sourceMaxCount)
            + issues(section: "missing-context", defaultCount: missingContextDefaultCount, maxCount: missingContextMaxCount)
            + issues(section: "nondeterminism-reasons", defaultCount: nondeterminismDefaultCount, maxCount: nondeterminismMaxCount)
    }

    func window(
        for section: AssistantDisclosureSection,
        totalCount: Int,
        revealAll: Bool
    ) -> AssistantDisclosureCapacityWindow {
        let (rawDefault, rawMax) = values(for: section)
        let maxCount = max(1, rawMax)
        let defaultCount = max(1, min(rawDefault, maxCount))
        let clampedTotal = max(0, totalCount)
        let cappedTotal = min(clampedTotal, maxCount)
        let collapsedVisible = min(defaultCount, cappedTotal)
        let visibleCount = revealAll ? cappedTotal : collapsedVisible
        let collapsedHiddenCount = max(0, cappedTotal - visibleCount)
        let overflowCount = max(0, clampedTotal - maxCount)

        return AssistantDisclosureCapacityWindow(
            visibleCount: visibleCount,
            collapsedHiddenCount: collapsedHiddenCount,
            overflowCount: overflowCount
        )
    }

    private func values(for section: AssistantDisclosureSection) -> (Int, Int) {
        switch section {
        case .sources:
            return (sourceDefaultCount, sourceMaxCount)
        case .missingContext:
            return (missingContextDefaultCount, missingContextMaxCount)
        case .nondeterminismReasons:
            return (nondeterminismDefaultCount, nondeterminismMaxCount)
        }
    }

    private func issues(section: String, defaultCount: Int, maxCount: Int) -> [String] {
        var results: [String] = []
        if defaultCount <= 0 {
            results.append("Disclosure capacity \(section) has invalid default \(defaultCount).")
        }
        if maxCount <= 0 {
            results.append("Disclosure capacity \(section) has invalid max \(maxCount).")
        }
        if defaultCount > maxCount {
            results.append("Disclosure capacity \(section) default \(defaultCount) exceeds max \(maxCount).")
        }
        return results
    }
}

// MARK: - Disclosure Depth

enum AssistantDisclosureDepth: Int, Comparable, Codable, Sendable, Hashable {
    case primary = 0    // Just the answer
    case supporting = 1 // Sources, confidence, missing context warnings
    case detailed = 2   // Source excerpts, metadata chips, determinism status
    case forensic = 3   // Replay hashes, token IDs, raw receipt details
    
    static func < (lhs: AssistantDisclosureDepth, rhs: AssistantDisclosureDepth) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct AssistantDisclosureDepthRules: Codable, Sendable, Hashable {
    let maxAutoRevealDepth: AssistantDisclosureDepth
    let allowManualRevealBeyondAuto: Bool
    
    static let calmDefault = AssistantDisclosureDepthRules(
        maxAutoRevealDepth: .supporting,
        allowManualRevealBeyondAuto: true
    )
    
    static let forensicDefault = AssistantDisclosureDepthRules(
        maxAutoRevealDepth: .forensic,
        allowManualRevealBeyondAuto: true
    )
}

// MARK: - Calm Surface Defaults

enum AssistantCalmSurfaceProfile: String, CaseIterable, Codable, Sendable, Hashable {
    case calmV1 = "calm-v1"
}

enum AssistantCalmSurfaceProfileSource: Equatable, Hashable, Codable, Sendable {
    case configured(AssistantCalmSurfaceProfile)
    case defaulted(AssistantCalmSurfaceProfile)
    case invalid(rawValue: String, fallback: AssistantCalmSurfaceProfile)
}

struct AssistantCalmSurfaceDefaults: Codable, Sendable, Hashable {
    static let profileDefaultsKey = "assistant.surface.defaults.profile"

    let profile: AssistantCalmSurfaceProfile
    let source: AssistantCalmSurfaceProfileSource
    let disclosureRules: AssistantDisclosureCapacityRules
    let disclosureDepthRules: AssistantDisclosureDepthRules
    let showMetadataByDefault: Bool
    let showSourceControlsByDefault: Bool
    let showReplayHashesByDefault: Bool

    var invalidProfileMessage: String? {
        guard case let .invalid(rawValue, fallback) = source else {
            return nil
        }
        return "Assistant surface profile \"\(rawValue)\" is invalid; using \(fallback.rawValue)."
    }

    static func resolve(userDefaults: UserDefaults = .standard) -> AssistantCalmSurfaceDefaults {
        resolve(profileRawValue: userDefaults.string(forKey: profileDefaultsKey))
    }

    static func resolve(
        profileRawValue: String?,
        defaultProfile: AssistantCalmSurfaceProfile = .calmV1
    ) -> AssistantCalmSurfaceDefaults {
        let trimmed = profileRawValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else {
            return defaults(for: defaultProfile, source: .defaulted(defaultProfile))
        }
        guard let profile = AssistantCalmSurfaceProfile(rawValue: trimmed) else {
            return defaults(
                for: defaultProfile,
                source: .invalid(rawValue: trimmed, fallback: defaultProfile)
            )
        }
        return defaults(for: profile, source: .configured(profile))
    }

    private static func defaults(
        for profile: AssistantCalmSurfaceProfile,
        source: AssistantCalmSurfaceProfileSource
    ) -> AssistantCalmSurfaceDefaults {
        switch profile {
        case .calmV1:
            return AssistantCalmSurfaceDefaults(
                profile: profile,
                source: source,
                disclosureRules: .calmDefault,
                disclosureDepthRules: .calmDefault,
                showMetadataByDefault: false,
                showSourceControlsByDefault: false,
                showReplayHashesByDefault: false
            )
        }
    }
}
