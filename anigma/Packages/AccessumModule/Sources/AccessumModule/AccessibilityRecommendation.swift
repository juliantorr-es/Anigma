// Copyright (c) 2025 Anigma
// Licensed under the MIT License

import Foundation

/// Accessibility improvement recommendation
public struct AccessibilityRecommendation: Codable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let description: String
    public let priority: RecommendationPriority
    public let category: RecommendationCategory
    public let wcagCriteria: [String]
    public let implementationSteps: [String]
    public let estimatedEffort: EffortLevel
    public let impactScore: Double
    public let createdAt: Date
    
    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        priority: RecommendationPriority,
        category: RecommendationCategory,
        wcagCriteria: [String],
        implementationSteps: [String],
        estimatedEffort: EffortLevel,
        impactScore: Double,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.priority = priority
        self.category = category
        self.wcagCriteria = wcagCriteria
        self.implementationSteps = implementationSteps
        self.estimatedEffort = estimatedEffort
        self.impactScore = impactScore
        self.createdAt = createdAt
    }
}

/// Recommendation priority levels
public enum RecommendationPriority: String, Codable, CaseIterable, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

/// Recommendation categories
public enum RecommendationCategory: String, Codable, CaseIterable, Sendable {
    case screenReader = "screen_reader"
    case keyboardNavigation = "keyboard_navigation"
    case colorContrast = "color_contrast"
    case imageAltText = "image_alt_text"
    case formAccessibility = "form_accessibility"
    case headingStructure = "heading_structure"
    case linkAccessibility = "link_accessibility"
    case mediaAccessibility = "media_accessibility"
    case tableAccessibility = "table_accessibility"
}

/// Implementation effort levels
public enum EffortLevel: String, Codable, CaseIterable, Sendable {
    case minimal = "minimal"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case extensive = "extensive"
}
