// Copyright (c) 2025 Anigma
// Licensed under the MIT License

import Foundation

/// Comprehensive accessibility assessment result
public struct AccessibilityAssessment: Codable, Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let contentId: String?
    public let wcagCompliance: WCAGComplianceResult
    public let screenReaderCompatibility: ScreenReaderResult
    public let keyboardNavigationResult: KeyboardNavigationResult
    public let colorContrastIssues: [ColorContrastIssue]
    public let altTextSuggestions: [AltTextSuggestion]
    public let overallScore: Double
    public let status: AssessmentStatus
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        contentId: String? = nil,
        wcagCompliance: WCAGComplianceResult,
        screenReaderCompatibility: ScreenReaderResult,
        keyboardNavigationResult: KeyboardNavigationResult,
        colorContrastIssues: [ColorContrastIssue] = [],
        altTextSuggestions: [AltTextSuggestion] = [],
        overallScore: Double,
        status: AssessmentStatus = .completed
    ) {
        self.id = id
        self.timestamp = timestamp
        self.contentId = contentId
        self.wcagCompliance = wcagCompliance
        self.screenReaderCompatibility = screenReaderCompatibility
        self.keyboardNavigationResult = keyboardNavigationResult
        self.colorContrastIssues = colorContrastIssues
        self.altTextSuggestions = altTextSuggestions
        self.overallScore = overallScore
        self.status = status
    }
}

/// WCAG compliance assessment result
public struct WCAGComplianceResult: Codable, Sendable {
    public let level: WCAGComplianceLevel
    public let passedCriteria: [WCAGCriterion]
    public let failedCriteria: [WCAGCriterion]
    public let compliancePercentage: Double
    
    public init(
        level: WCAGComplianceLevel,
        passedCriteria: [WCAGCriterion],
        failedCriteria: [WCAGCriterion]
    ) {
        self.level = level
        self.passedCriteria = passedCriteria
        self.failedCriteria = failedCriteria
        let totalCriteria = passedCriteria.count + failedCriteria.count
        self.compliancePercentage = totalCriteria > 0 ? Double(passedCriteria.count) / Double(totalCriteria) * 100.0 : 0.0
    }
}

/// Individual WCAG criterion
public struct WCAGCriterion: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let level: WCAGComplianceLevel
    public let passed: Bool
    public let notes: String?
    
    public init(id: String, title: String, description: String, level: WCAGComplianceLevel, passed: Bool, notes: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.level = level
        self.passed = passed
        self.notes = notes
    }
}

/// Screen reader compatibility result
public struct ScreenReaderResult: Codable, Sendable {
    public let compatible: Bool
    public let issues: [ScreenReaderIssue]
    public let recommendations: [String]
    
    public init(compatible: Bool, issues: [ScreenReaderIssue] = [], recommendations: [String] = []) {
        self.compatible = compatible
        self.issues = issues
        self.recommendations = recommendations
    }
}

/// Screen reader specific issue
public struct ScreenReaderIssue: Codable, Identifiable, Sendable {
    public let id: UUID = UUID()
    public let element: String
    public let issue: String
    public let severity: IssueSeverity
    public let suggestion: String
    
    public init(element: String, issue: String, severity: IssueSeverity, suggestion: String) {
        self.element = element
        self.issue = issue
        self.severity = severity
        self.suggestion = suggestion
    }
}

/// Keyboard navigation assessment result
public struct KeyboardNavigationResult: Codable, Sendable {
    public let accessible: Bool
    public let focusableElements: [FocusableElement]
    public let tabOrderIssues: [TabOrderIssue]
    public let shortcutsAvailable: [KeyboardShortcut]
    
    public init(
        accessible: Bool,
        focusableElements: [FocusableElement] = [],
        tabOrderIssues: [TabOrderIssue] = [],
        shortcutsAvailable: [KeyboardShortcut] = []
    ) {
        self.accessible = accessible
        self.focusableElements = focusableElements
        self.tabOrderIssues = tabOrderIssues
        self.shortcutsAvailable = shortcutsAvailable
    }
}

/// Focusable element in keyboard navigation
public struct FocusableElement: Codable, Identifiable, Sendable {
    public let id: UUID = UUID()
    public let elementType: String
    public let selector: String
    public let tabIndex: Int
    public let hasAriaLabel: Bool
    
    public init(elementType: String, selector: String, tabIndex: Int, hasAriaLabel: Bool) {
        self.elementType = elementType
        self.selector = selector
        self.tabIndex = tabIndex
        self.hasAriaLabel = hasAriaLabel
    }
}

/// Tab order issue
public struct TabOrderIssue: Codable, Identifiable, Sendable {
    public let id: UUID = UUID()
    public let expectedOrder: Int
    public let actualOrder: Int
    public let element: String
    public let severity: IssueSeverity
    
    public init(expectedOrder: Int, actualOrder: Int, element: String, severity: IssueSeverity) {
        self.expectedOrder = expectedOrder
        self.actualOrder = actualOrder
        self.element = element
        self.severity = severity
    }
}

/// Color contrast issue
public struct ColorContrastIssue: Codable, Identifiable, Sendable {
    public let id: UUID = UUID()
    public let foregroundColor: String
    public let backgroundColor: String
    public let contrastRatio: Double
    public let requiredRatio: Double
    public let wcagLevel: WCAGComplianceLevel
    public let element: String
    
    public init(
        foregroundColor: String,
        backgroundColor: String,
        contrastRatio: Double,
        requiredRatio: Double,
        wcagLevel: WCAGComplianceLevel,
        element: String
    ) {
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.contrastRatio = contrastRatio
        self.requiredRatio = requiredRatio
        self.wcagLevel = wcagLevel
        self.element = element
    }
}

/// Alt text suggestion for images
public struct AltTextSuggestion: Codable, Identifiable, Sendable {
    public let id: UUID = UUID()
    public let imageSelector: String
    public let suggestedAltText: String
    public let confidence: Double
    public let source: AltTextSource
    
    public init(imageSelector: String, suggestedAltText: String, confidence: Double, source: AltTextSource) {
        self.imageSelector = imageSelector
        self.suggestedAltText = suggestedAltText
        self.confidence = confidence
        self.source = source
    }
}

/// Source of alt text generation
public enum AltTextSource: String, Codable, Sendable {
    case aiGenerated = "ai_generated"
    case manual = "manual"
    case ocr = "ocr"
}

/// Keyboard shortcut
public struct KeyboardShortcut: Codable, Sendable {
    public let key: String
    public let modifiers: [String]
    public let action: String
    public let description: String
    
    public init(key: String, modifiers: [String], action: String, description: String) {
        self.key = key
        self.modifiers = modifiers
        self.action = action
        self.description = description
    }
}

/// Assessment status
public enum AssessmentStatus: String, Codable, Sendable, CaseIterable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"
}

/// Issue severity levels
public enum IssueSeverity: String, Codable, CaseIterable, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}
