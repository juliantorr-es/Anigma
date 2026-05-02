import Foundation

// MARK: - Feedback Types
public enum FeedbackType: String, Codable, CaseIterable, Sendable {
    case userReport = "user_report"
    case automated = "automated"
    case performance = "performance"
    case error = "error"
    case suggestion = "suggestion"
    case bug = "bug"
}

// MARK: - Feedback Category
public enum FeedbackCategory: String, Codable, CaseIterable, Sendable {
    case ui = "ui"
    case performance = "performance"
    case functionality = "functionality"
    case crash = "crash"
    case security = "security"
    case documentation = "documentation"
    case other = "other"
}

// MARK: - Feedback Priority
public enum FeedbackPriority: String, Codable, CaseIterable, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    public var level: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .urgent: return 4
        }
    }
}

// MARK: - Feedback Status
public enum FeedbackStatus: String, Codable, CaseIterable, Sendable {
    case open = "open"
    case inProgress = "in_progress"
    case reviewed = "reviewed"
    case resolved = "resolved"
    case closed = "closed"
    case duplicate = "duplicate"
}

// MARK: - Feedback Entry
public struct FeedbackEntry: Codable, Identifiable, Sendable {
    public let id: UUID
    public let type: FeedbackType
    public let category: FeedbackCategory
    public let priority: FeedbackPriority
    public var status: FeedbackStatus
    public let title: String
    public let description: String
    public let source: String
    public let userId: String?
    public let sessionId: String?
    public let metadata: [String: String]
    public let attachments: [FeedbackAttachment]
    public let createdAt: Date
    public var updatedAt: Date
    public var resolvedAt: Date?
    
    public init(
        type: FeedbackType,
        category: FeedbackCategory,
        priority: FeedbackPriority,
        title: String,
        description: String,
        source: String,
        userId: String? = nil,
        sessionId: String? = nil,
        metadata: [String: String] = [:],
        attachments: [FeedbackAttachment] = []
    ) {
        self.id = UUID()
        self.type = type
        self.category = category
        self.priority = priority
        self.status = .open
        self.title = title
        self.description = description
        self.source = source
        self.userId = userId
        self.sessionId = sessionId
        self.metadata = metadata
        self.attachments = attachments
        self.createdAt = Date()
        self.updatedAt = Date()
        self.resolvedAt = nil
    }
    
    public mutating func updateStatus(_ newStatus: FeedbackStatus) {
        self.status = newStatus
        self.updatedAt = Date()
        if newStatus == .resolved {
            self.resolvedAt = Date()
        }
    }
}

// MARK: - Feedback Attachment
public struct FeedbackAttachment: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let type: String
    public let size: UInt64
    public let url: String?
    public let data: Data?
    
    public init(name: String, type: String, size: UInt64, url: String? = nil, data: Data? = nil) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.size = size
        self.url = url
        self.data = data
    }
}

// MARK: - Feedback Analysis
public struct FeedbackAnalysis: Codable, Sendable {
    public let feedbackId: UUID
    public let sentiment: SentimentScore
    public let keyPhrases: [String]
    public let categorization: [String: Double]
    public let suggestedActions: [String]
    public let relatedFeedback: [UUID]
    public let analyzedAt: Date
    
    public init(
        feedbackId: UUID,
        sentiment: SentimentScore,
        keyPhrases: [String],
        categorization: [String: Double],
        suggestedActions: [String],
        relatedFeedback: [UUID]
    ) {
        self.feedbackId = feedbackId
        self.sentiment = sentiment
        self.keyPhrases = keyPhrases
        self.categorization = categorization
        self.suggestedActions = suggestedActions
        self.relatedFeedback = relatedFeedback
        self.analyzedAt = Date()
    }
}

// MARK: - Sentiment Score
public struct SentimentScore: Codable, Sendable {
    public let positive: Double
    public let negative: Double
    public let neutral: Double
    public let compound: Double
    
    public var classification: SentimentClassification {
        if compound >= 0.5 {
            return .positive
        } else if compound <= -0.5 {
            return .negative
        } else {
            return .neutral
        }
    }
    
    public init(positive: Double, negative: Double, neutral: Double, compound: Double) {
        self.positive = positive
        self.negative = negative
        self.neutral = neutral
        self.compound = compound
    }
}

// MARK: - Sentiment Classification
public enum SentimentClassification: String, Codable, CaseIterable, Sendable {
    case positive = "positive"
    case negative = "negative"
    case neutral = "neutral"
}

// MARK: - Feedback Trend Analysis
public struct FeedbackTrendAnalysis: Codable, Sendable {
    public let period: DateInterval
    public let totalFeedback: Int
    public let categoryBreakdown: [FeedbackCategory: Int]
    public let priorityBreakdown: [FeedbackPriority: Int]
    public let statusBreakdown: [FeedbackStatus: Int]
    public let averageResolutionTime: TimeInterval
    public let topIssues: [String: Int]
    public let satisfactionScore: Double?
    
    public init(
        period: DateInterval,
        totalFeedback: Int,
        categoryBreakdown: [FeedbackCategory: Int],
        priorityBreakdown: [FeedbackPriority: Int],
        statusBreakdown: [FeedbackStatus: Int],
        averageResolutionTime: TimeInterval,
        topIssues: [String: Int],
        satisfactionScore: Double? = nil
    ) {
        self.period = period
        self.totalFeedback = totalFeedback
        self.categoryBreakdown = categoryBreakdown
        self.priorityBreakdown = priorityBreakdown
        self.statusBreakdown = statusBreakdown
        self.averageResolutionTime = averageResolutionTime
        self.topIssues = topIssues
        self.satisfactionScore = satisfactionScore
    }
}
