// Copyright (c) 2025 Anigma
// Licensed under the MIT License

import Foundation

/// Model representing accessibility client requirements and assessment history
public struct AccessibilityClient: Codable, Identifiable, Sendable {
    public let id: UUID
    public var requirements: AccessibilityRequirements
    public var preferences: AccessibilityPreferences
    public var assessmentHistory: [AccessibilityAssessment]
    public var recommendations: [AccessibilityRecommendation]
    
    public init(
        id: UUID = UUID(),
        requirements: AccessibilityRequirements = AccessibilityRequirements(),
        preferences: AccessibilityPreferences = AccessibilityPreferences(),
        assessmentHistory: [AccessibilityAssessment] = [],
        recommendations: [AccessibilityRecommendation] = []
    ) {
        self.id = id
        self.requirements = requirements
        self.preferences = preferences
        self.assessmentHistory = assessmentHistory
        self.recommendations = recommendations
    }
}

/// Accessibility requirements based on WCAG standards
public struct AccessibilityRequirements: Codable, Sendable {
    public var wcagLevel: WCAGComplianceLevel
    public var screenReaderSupport: Bool
    public var keyboardNavigation: Bool
    public var colorBlindnessSupport: Bool
    public var highContrastMode: Bool
    
    public init(
        wcagLevel: WCAGComplianceLevel = .AA,
        screenReaderSupport: Bool = true,
        keyboardNavigation: Bool = true,
        colorBlindnessSupport: Bool = true,
        highContrastMode: Bool = false
    ) {
        self.wcagLevel = wcagLevel
        self.screenReaderSupport = screenReaderSupport
        self.keyboardNavigation = keyboardNavigation
        self.colorBlindnessSupport = colorBlindnessSupport
        self.highContrastMode = highContrastMode
    }
}

/// User preferences for accessibility features
public struct AccessibilityPreferences: Codable, Sendable {
    public var preferredLanguage: String
    public var altTextGenerationEnabled: Bool
    public var automaticAssessment: Bool
    public var notificationLevel: NotificationLevel
    
    public init(
        preferredLanguage: String = "en",
        altTextGenerationEnabled: Bool = true,
        automaticAssessment: Bool = false,
        notificationLevel: NotificationLevel = .summary
    ) {
        self.preferredLanguage = preferredLanguage
        self.altTextGenerationEnabled = altTextGenerationEnabled
        self.automaticAssessment = automaticAssessment
        self.notificationLevel = notificationLevel
    }
}

/// WCAG compliance levels
public enum WCAGComplianceLevel: String, Codable, CaseIterable, Sendable {
    case A = "A"
    case AA = "AA"
    case AAA = "AAA"
}

/// Notification levels for accessibility alerts
public enum NotificationLevel: String, Codable, CaseIterable, Sendable {
    case detailed = "detailed"
    case summary = "summary"
    case critical = "critical"
}
