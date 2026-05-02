import Foundation

// MARK: - Feedback Service Protocol
public protocol FeedbackServiceProtocol: Sendable {
    func submitFeedback(_ feedback: FeedbackEntry) async throws
    func updateFeedback(_ feedback: FeedbackEntry) async throws
    func getFeedback(id: UUID) async -> FeedbackEntry?
    func getAllFeedback() async -> [FeedbackEntry]
    func getFeedbackByCategory(_ category: FeedbackCategory) async -> [FeedbackEntry]
    func getFeedbackByStatus(_ status: FeedbackStatus) async -> [FeedbackEntry]
    func analyzeFeedback(_ feedbackId: UUID) async throws -> FeedbackAnalysis
    func getTrendAnalysis(for timeRange: TimeRange) async -> FeedbackTrendAnalysis?
    func updateFeedbackStatus(id: UUID, status: FeedbackStatus) async throws
}

// MARK: - Feedback Service Implementation
@MainActor
public final class FeedbackService: FeedbackServiceProtocol {
    private let feedbackStore: InMemoryFeedbackStore
    private let analysisEngine: FeedbackAnalysisEngine
    private let trendAnalyzer: TrendAnalyzer
    
    // MARK: - Configuration
    private let configuration: FeedbackConfiguration
    
    public init(configuration: FeedbackConfiguration = .default) {
        self.configuration = configuration
        self.feedbackStore = InMemoryFeedbackStore(maxEntries: configuration.maxStoredFeedback)
        self.analysisEngine = FeedbackAnalysisEngine()
        self.trendAnalyzer = TrendAnalyzer()
    }
    
    // MARK: - FeedbackServiceProtocol
    public func submitFeedback(_ feedback: FeedbackEntry) async throws {
        try feedbackStore.addFeedback(feedback)
        
        // Auto-analyze feedback if enabled
        if configuration.autoAnalysis {
            _ = try await analyzeFeedback(feedback.id)
        }
        
        // Forward to AnigmaDaemonCore if configured
        if configuration.forwardToDaemonCore {
            // Integration with AnigmaDaemonCore would happen here
        }
    }
    
    public func updateFeedback(_ feedback: FeedbackEntry) async throws {
        try feedbackStore.updateFeedback(feedback)
    }
    
    public func getFeedback(id: UUID) async -> FeedbackEntry? {
        feedbackStore.getFeedback(id: id)
    }
    
    public func getAllFeedback() async -> [FeedbackEntry] {
        feedbackStore.getAllFeedback()
    }
    
    public func getFeedbackByCategory(_ category: FeedbackCategory) async -> [FeedbackEntry] {
        feedbackStore.getFeedbackByCategory(category)
    }
    
    public func getFeedbackByStatus(_ status: FeedbackStatus) async -> [FeedbackEntry] {
        feedbackStore.getFeedbackByStatus(status)
    }
    
    public func analyzeFeedback(_ feedbackId: UUID) async throws -> FeedbackAnalysis {
        guard let feedback = feedbackStore.getFeedback(id: feedbackId) else {
            throw FeedbackServiceError.feedbackNotFound
        }
        
        return await analysisEngine.analyze(feedback)
    }
    
    public func getTrendAnalysis(for timeRange: TimeRange) async -> FeedbackTrendAnalysis? {
        let interval = timeRange.dateInterval
        let feedback = feedbackStore.getFeedbackInDateRange(interval)
        
        guard !feedback.isEmpty else { return nil }
        
        return await trendAnalyzer.analyze(feedback: feedback, timeRange: timeRange)
    }
    
    public func updateFeedbackStatus(id: UUID, status: FeedbackStatus) async throws {
        guard var feedback = feedbackStore.getFeedback(id: id) else {
            throw FeedbackServiceError.feedbackNotFound
        }
        
        feedback.updateStatus(status)
        try feedbackStore.updateFeedback(feedback)
        
        // Auto-notify relevant teams for urgent feedback
        if status == .open && feedback.priority.level >= FeedbackPriority.high.level {
            NotificationCenter.default.post(
                name: .urgentFeedbackSubmitted,
                object: feedback
            )
        }
    }
    
    // MARK: - Public Methods
    public func searchFeedback(query: String) async -> [FeedbackEntry] {
        feedbackStore.searchFeedback(query: query)
    }
    
    public func getRelatedFeedback(for feedbackId: UUID) async -> [FeedbackEntry] {
        guard let feedback = feedbackStore.getFeedback(id: feedbackId) else {
            return []
        }
        
        return feedbackStore.getRelatedFeedback(to: feedback)
    }
    
    public func generateSatisfactionReport() async -> SatisfactionReport? {
        let feedback = feedbackStore.getAllFeedback()
        return await analysisEngine.generateSatisfactionReport(from: feedback)
    }
}

// MARK: - Feedback Configuration
public struct FeedbackConfiguration: Sendable {
    public let maxStoredFeedback: Int
    public let autoAnalysis: Bool
    public let forwardToDaemonCore: Bool
    public let retentionPeriod: TimeInterval
    
    public static let `default` = FeedbackConfiguration(
        maxStoredFeedback: 50000,
        autoAnalysis: true,
        forwardToDaemonCore: true,
        retentionPeriod: 365 * 24 * 3600 // 1 year
    )
    
    public init(
        maxStoredFeedback: Int,
        autoAnalysis: Bool,
        forwardToDaemonCore: Bool,
        retentionPeriod: TimeInterval
    ) {
        self.maxStoredFeedback = maxStoredFeedback
        self.autoAnalysis = autoAnalysis
        self.forwardToDaemonCore = forwardToDaemonCore
        self.retentionPeriod = retentionPeriod
    }
}

// MARK: - Satisfaction Report
public struct SatisfactionReport: Codable, Sendable {
    public let period: DateInterval
    public let totalFeedback: Int
    public let averageSatisfactionScore: Double
    public let satisfactionTrend: SatisfactionTrend
    public let categoryScores: [FeedbackCategory: Double]
    public let improvementAreas: [String]
    
    public init(
        period: DateInterval,
        totalFeedback: Int,
        averageSatisfactionScore: Double,
        satisfactionTrend: SatisfactionTrend,
        categoryScores: [FeedbackCategory: Double],
        improvementAreas: [String]
    ) {
        self.period = period
        self.totalFeedback = totalFeedback
        self.averageSatisfactionScore = averageSatisfactionScore
        self.satisfactionTrend = satisfactionTrend
        self.categoryScores = categoryScores
        self.improvementAreas = improvementAreas
    }
}

// MARK: - Satisfaction Trend
public enum SatisfactionTrend: String, Codable, CaseIterable, Sendable {
    case improving = "improving"
    case declining = "declining"
    case stable = "stable"
}

// MARK: - In-Memory Feedback Store
@MainActor
private final class InMemoryFeedbackStore {
    private var feedback: [UUID: FeedbackEntry] = [:]
    private let maxEntries: Int
    
    init(maxEntries: Int) {
        self.maxEntries = maxEntries
    }
    
    func addFeedback(_ entry: FeedbackEntry) throws {
        guard feedback[entry.id] == nil else {
            throw FeedbackServiceError.feedbackAlreadyExists
        }
        
        feedback[entry.id] = entry
        
        // Cleanup old entries if we exceed the limit
        if feedback.count > maxEntries {
            let sortedFeedback = feedback.values.sorted { $0.createdAt < $1.createdAt }
            let excessCount = feedback.count - maxEntries
            
            for entry in sortedFeedback.prefix(excessCount) {
                feedback.removeValue(forKey: entry.id)
            }
        }
    }
    
    func updateFeedback(_ entry: FeedbackEntry) throws {
        guard feedback[entry.id] != nil else {
            throw FeedbackServiceError.feedbackNotFound
        }
        feedback[entry.id] = entry
    }
    
    func getFeedback(id: UUID) -> FeedbackEntry? {
        feedback[id]
    }
    
    func getAllFeedback() -> [FeedbackEntry] {
        Array(feedback.values).sorted { $0.createdAt > $1.createdAt }
    }
    
    func getFeedbackByCategory(_ category: FeedbackCategory) -> [FeedbackEntry] {
        feedback.values.filter { $0.category == category }.sorted { $0.createdAt > $1.createdAt }
    }
    
    func getFeedbackByStatus(_ status: FeedbackStatus) -> [FeedbackEntry] {
        feedback.values.filter { $0.status == status }.sorted { $0.createdAt > $1.createdAt }
    }
    
    func getFeedbackInDateRange(_ interval: DateInterval) -> [FeedbackEntry] {
        feedback.values.filter { interval.contains($0.createdAt) }.sorted { $0.createdAt > $1.createdAt }
    }
    
    func searchFeedback(query: String) -> [FeedbackEntry] {
        feedback.values.filter { entry in
            entry.title.localizedCaseInsensitiveContains(query) ||
            entry.description.localizedCaseInsensitiveContains(query)
        }.sorted { $0.createdAt > $1.createdAt }
    }
    
    func getRelatedFeedback(to feedbackEntry: FeedbackEntry) -> [FeedbackEntry] {
        let allFeedback = Array(feedback.values)
        
        let categoryMatches = allFeedback.filter { $0.category == feedbackEntry.category }
        let typeMatches = allFeedback.filter { $0.type == feedbackEntry.type }
        let titleMatches = allFeedback.filter { 
            $0.id != feedbackEntry.id && 
            $0.title.localizedCaseInsensitiveContains(feedbackEntry.title)
        }
        
        var allMatches = Set<UUID>()
        categoryMatches.forEach { allMatches.insert($0.id) }
        typeMatches.forEach { allMatches.insert($0.id) }
        titleMatches.forEach { allMatches.insert($0.id) }
        allMatches.remove(feedbackEntry.id)
        
        return allMatches.compactMap { self.feedback[$0] }
            .sorted { $0.createdAt > $1.createdAt }
    }
}

// MARK: - Feedback Analysis Engine
@MainActor
private final class FeedbackAnalysisEngine {
    func analyze(_ feedback: FeedbackEntry) async -> FeedbackAnalysis {
        // Simulate sentiment analysis
        let sentiment = analyzeSentiment(feedback.description)
        
        // Extract key phrases (simplified)
        let keyPhrases = extractKeyPhrases(from: feedback.description)
        
        // Categorize content
        let categorization = categorizeContent(feedback.description)
        
        // Suggest actions based on content
        let suggestedActions = suggestActions(for: feedback)
        
        // Find related feedback
        let relatedFeedback = findRelatedFeedback(for: feedback)
        
        return FeedbackAnalysis(
            feedbackId: feedback.id,
            sentiment: sentiment,
            keyPhrases: keyPhrases,
            categorization: categorization,
            suggestedActions: suggestedActions,
            relatedFeedback: relatedFeedback
        )
    }
    
    func generateSatisfactionReport(from feedback: [FeedbackEntry]) async -> SatisfactionReport? {
        guard !feedback.isEmpty else { return nil }
        
        // Calculate satisfaction scores (simplified)
        let sentimentScores = feedback.map { entry in
            // This would use actual sentiment analysis in a real implementation
            Double.random(in: 0.0...1.0)
        }
        
        let averageScore = sentimentScores.reduce(0, +) / Double(sentimentScores.count)
        
        // Categorize by feedback category
        var categoryScores: [FeedbackCategory: Double] = [:]
        for category in FeedbackCategory.allCases {
            let categoryFeedback = feedback.filter { $0.category == category }
            if !categoryFeedback.isEmpty {
                categoryScores[category] = Double.random(in: 0.0...1.0)
            }
        }
        
        // Identify improvement areas (simplified)
        let improvementAreas = categoryScores.compactMap { category, score in
            score < 0.5 ? category.rawValue : nil
        }
        
        // Determine trend (simplified)
        let trend: SatisfactionTrend = averageScore > 0.7 ? .improving : averageScore < 0.3 ? .declining : .stable
        
        let now = Date()
        let period = DateInterval(start: now.addingTimeInterval(-30 * 24 * 3600), end: now)
        
        return SatisfactionReport(
            period: period,
            totalFeedback: feedback.count,
            averageSatisfactionScore: averageScore,
            satisfactionTrend: trend,
            categoryScores: categoryScores,
            improvementAreas: improvementAreas
        )
    }
    
    // MARK: - Private Analysis Methods
    private func analyzeSentiment(_ text: String) -> SentimentScore {
        // Simplified sentiment analysis
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        let positiveWords = ["good", "great", "excellent", "amazing", "love", "perfect", "wonderful"]
        let negativeWords = ["bad", "terrible", "awful", "hate", "worst", "horrible", "disappointing"]
        
        let positiveCount = words.filter { positiveWords.contains($0) }.count
        let negativeCount = words.filter { negativeWords.contains($0) }.count
        let totalWords = words.count
        
        let positive = Double(positiveCount) / Double(totalWords)
        let negative = Double(negativeCount) / Double(totalWords)
        let neutral = 1.0 - positive - negative
        let compound = positive - negative
        
        return SentimentScore(
            positive: positive,
            negative: negative,
            neutral: max(0, neutral),
            compound: compound
        )
    }
    
    private func extractKeyPhrases(from text: String) -> [String] {
        // Simplified key phrase extraction
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }
        
        // Common technical terms that might be important
        let technicalTerms = ["performance", "crash", "bug", "ui", "interface", "slow", "fast", "memory", "cpu", "network"]
        
        return words.filter { technicalTerms.contains($0) }
            .removingDuplicates()
    }
    
    private func categorizeContent(_ text: String) -> [String: Double] {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        var categories: [String: Double] = [:]
        
        // Performance related
        let performanceWords = ["slow", "fast", "performance", "speed", "memory", "cpu"]
        categories["performance"] = Double(words.filter { performanceWords.contains($0) }.count) / Double(words.count)
        
        // UI related
        let uiWords = ["interface", "design", "layout", "button", "menu", "window"]
        categories["ui"] = Double(words.filter { uiWords.contains($0) }.count) / Double(words.count)
        
        // Functionality related
        let functionWords = ["feature", "function", "work", "broken", "doesn't", "failed"]
        categories["functionality"] = Double(words.filter { functionWords.contains($0) }.count) / Double(words.count)
        
        return categories
    }
    
    private func suggestActions(for feedback: FeedbackEntry) -> [String] {
        var actions: [String] = []
        
        switch feedback.category {
        case .performance:
            actions.append("Investigate performance bottlenecks")
            actions.append("Consider optimization strategies")
        case .ui:
            actions.append("Review user interface design")
            actions.append("Consider usability improvements")
        case .functionality:
            actions.append("Analyze feature implementation")
            actions.append("Test functionality thoroughly")
        case .crash:
            actions.append("Immediate crash investigation required")
            actions.append("Review error handling")
        case .security:
            actions.append("Security assessment required")
            actions.append("Review access controls")
        default:
            actions.append("General review recommended")
        }
        
        switch feedback.priority {
        case .urgent, .high:
            actions.insert("Prioritize this feedback", at: 0)
        default:
            break
        }
        
        return actions
    }
    
    private func findRelatedFeedback(for feedback: FeedbackEntry) -> [UUID] {
        // This would be implemented with actual similarity algorithms
        // For now, return empty array
        return []
    }
}

// MARK: - Trend Analyzer
@MainActor
private final class TrendAnalyzer {
    func analyze(feedback: [FeedbackEntry], timeRange: TimeRange) async -> FeedbackTrendAnalysis {
        let categoryBreakdown = Dictionary(grouping: feedback) { $0.category }
            .mapValues { $0.count }
        
        let priorityBreakdown = Dictionary(grouping: feedback) { $0.priority }
            .mapValues { $0.count }
        
        let statusBreakdown = Dictionary(grouping: feedback) { $0.status }
            .mapValues { $0.count }
        
        // Calculate average resolution time for resolved feedback
        let resolvedFeedback = feedback.filter { $0.resolvedAt != nil && $0.status == .resolved }
        let averageResolutionTime = resolvedFeedback.isEmpty ? 0 : 
            resolvedFeedback.reduce(0) { total, entry in
                total + (entry.resolvedAt?.timeIntervalSince(entry.createdAt) ?? 0)
            } / Double(resolvedFeedback.count)
        
        // Identify top issues
        let issueCounts = Dictionary(grouping: feedback) { $0.title }
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(5)
            .reduce(into: [String: Int]()) { result, item in
                result[item.key] = item.value
            }
        
        return FeedbackTrendAnalysis(
            period: timeRange.dateInterval,
            totalFeedback: feedback.count,
            categoryBreakdown: categoryBreakdown,
            priorityBreakdown: priorityBreakdown,
            statusBreakdown: statusBreakdown,
            averageResolutionTime: averageResolutionTime,
            topIssues: issueCounts,
            satisfactionScore: nil
        )
    }
}

// MARK: - Array Extension
private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let urgentFeedbackSubmitted = Notification.Name("urgentFeedbackSubmitted")
}

// MARK: - Feedback Service Error
public enum FeedbackServiceError: Error, LocalizedError {
    case feedbackNotFound
    case feedbackAlreadyExists
    case analysisFailed
    case invalidFeedback
    
    public var errorDescription: String? {
        switch self {
        case .feedbackNotFound:
            return "Feedback not found"
        case .feedbackAlreadyExists:
            return "Feedback already exists"
        case .analysisFailed:
            return "Failed to analyze feedback"
        case .invalidFeedback:
            return "Invalid feedback data"
        }
    }
}
