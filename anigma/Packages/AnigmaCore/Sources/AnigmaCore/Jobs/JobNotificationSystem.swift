//
//  JobNotificationSystem.swift
//  AnigmaCore
//
//  Real-time job status notification system.
//

import Foundation
import AnigmaPrimitives

/// Comprehensive job notification system for real-time status updates.
public actor JobNotificationSystem {
    // MARK: - Configuration
    private let maxSubscriptions: Int
    private let notificationHistorySize: Int
    
    // MARK: - State
    private var subscriptions: [JobNotificationSubscription] = []
    private var notificationHistory: [JobNotification] = []
    private var deliveryHandlers: [NotificationDeliveryMethod: NotificationDeliveryHandler] = [:]
    
    // Notification queues for different delivery methods
    private var emailQueue: [JobNotification] = []
    private var webhookQueue: [JobNotification] = []
    private var pushQueue: [JobNotification] = []
    
    // Background tasks
    private var deliveryTask: Task<Void, Never>?
    
    public init(
        maxSubscriptions: Int = 1000,
        notificationHistorySize: Int = 10000
    ) {
        self.maxSubscriptions = maxSubscriptions
        self.notificationHistorySize = notificationHistorySize
        
        deliveryHandlers[.email] = EmailNotificationHandler()
        deliveryHandlers[.webhook] = WebhookNotificationHandler()
        deliveryHandlers[.push] = PushNotificationHandler()
    }
    
    // MARK: - Subscription Management
    
    /// Subscribe to job notifications with specific filters.
    public func subscribe(_ subscription: JobNotificationSubscription) async throws {
        guard subscriptions.count < maxSubscriptions else {
            throw NotificationError.tooManySubscriptions
        }
        
        // Validate subscription
        guard validateSubscription(subscription) else {
            throw NotificationError.invalidSubscription
        }
        
        // Check for duplicate
        if !subscriptions.contains(where: { $0.id == subscription.id }) {
            subscriptions.append(subscription)
            
            // Send confirmation notification
            let confirmation = JobNotification(
                id: UUID().uuidString,
                type: .subscriptionConfirmed,
                jobId: nil,
                jobType: nil,
                userId: nil,
                timestamp: Date(),
                title: "Subscription Confirmed",
                message: "You are now subscribed to job notifications",
                data: ["subscriptionId": subscription.id.uuidString]
            )
            
            await deliverNotification(confirmation, to: [subscription])
        }
    }
    
    /// Unsubscribe from notifications.
    public func unsubscribe(subscriptionId: UUID) async {
        subscriptions.removeAll { $0.id == subscriptionId }
    }
    
    /// Update subscription preferences.
    public func updateSubscription(_ subscription: JobNotificationSubscription) async throws {
        guard let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) else {
            throw NotificationError.subscriptionNotFound
        }
        
        guard validateSubscription(subscription) else {
            throw NotificationError.invalidSubscription
        }
        
        subscriptions[index] = subscription
    }
    
    // MARK: - Notification Delivery
    
    /// Send a job status change notification.
    public func notifyJobStatusChange(
        jobId: JobId,
        oldStatus: JobStatus,
        newStatus: JobStatus,
        jobType: String,
        error: String? = nil,
        userId: String? = nil
    ) async {
        let notification = JobNotification(
            id: UUID().uuidString,
            type: .statusChange,
            jobId: jobId,
            jobType: jobType,
            userId: userId,
            timestamp: Date(),
            title: "Job Status Changed",
            message: "Job \(jobId.raw) changed from \(oldStatus.rawValue) to \(newStatus.rawValue)",
            data: [
                "jobId": jobId.raw,
                "oldStatus": oldStatus.rawValue,
                "newStatus": newStatus.rawValue,
                "jobType": jobType,
                "error": error as Any
            ]
        )
        
        await broadcastNotification(notification)
    }
    
    /// Send a job completion notification.
    public func notifyJobCompleted(
        jobId: JobId,
        jobType: String,
        outcome: JobOutcome,
        duration: Int64,
        userId: String? = nil
    ) async {
        let notification = JobNotification(
            id: UUID().uuidString,
            type: .completion,
            jobId: jobId,
            jobType: jobType,
            userId: userId,
            timestamp: Date(),
            title: "Job Completed",
            message: "Job \(jobId.raw) completed with outcome: \(outcome.rawValue)",
            data: [
                "jobId": jobId.raw,
                "outcome": outcome.rawValue,
                "duration": duration,
                "jobType": jobType
            ]
        )
        
        await broadcastNotification(notification)
    }
    
    /// Send a job failure notification.
    public func notifyJobFailed(
        jobId: JobId,
        jobType: String,
        error: String,
        userId: String? = nil
    ) async {
        let notification = JobNotification(
            id: UUID().uuidString,
            type: .failure,
            jobId: jobId,
            jobType: jobType,
            userId: userId,
            timestamp: Date(),
            title: "Job Failed",
            message: "Job \(jobId.raw) failed: \(error)",
            data: [
                "jobId": jobId.raw,
                "error": error,
                "jobType": jobType
            ]
        )
        
        await broadcastNotification(notification)
    }
    
    /// Send a job timeout notification.
    public func notifyJobTimeout(
        jobId: JobId,
        jobType: String,
        timeoutDuration: TimeInterval,
        userId: String? = nil
    ) async {
        let notification = JobNotification(
            id: UUID().uuidString,
            type: .timeout,
            jobId: jobId,
            jobType: jobType,
            userId: userId,
            timestamp: Date(),
            title: "Job Timed Out",
            message: "Job \(jobId.raw) timed out after \(timeoutDuration) seconds",
            data: [
                "jobId": jobId.raw,
                "timeoutDuration": timeoutDuration,
                "jobType": jobType
            ]
        )
        
        await broadcastNotification(notification)
    }
    
    /// Send a system-level notification.
    public func notifySystemEvent(
        title: String,
        message: String,
        severity: NotificationSeverity = .info,
        data: [String: Any] = [:]
    ) async {
        let notification = JobNotification(
            id: UUID().uuidString,
            type: .systemEvent,
            jobId: nil,
            jobType: nil,
            userId: nil,
            timestamp: Date(),
            title: title,
            message: message,
            severity: severity,
            data: data
        )
        
        await broadcastNotification(notification)
    }
    
    // MARK: - Internal Methods
    
    private func broadcastNotification(_ notification: JobNotification) async {
        // Add to history
        notificationHistory.append(notification)
        if notificationHistory.count > notificationHistorySize {
            notificationHistory.removeFirst()
        }
        
        // Find matching subscriptions
        let matchingSubscriptions = subscriptions.filter { subscription in
            matchesSubscription(notification: notification, subscription: subscription)
        }
        
        // Deliver to matching subscriptions
        await deliverNotification(notification, to: matchingSubscriptions)
        
        // Also send system notifications to admin subscribers
        if notification.type == .systemEvent {
            let adminSubscriptions = subscriptions.filter { $0.receiveSystemNotifications }
            await deliverNotification(notification, to: adminSubscriptions)
        }
    }
    
    private func deliverNotification(_ notification: JobNotification, to subscriptions: [JobNotificationSubscription]) async {
        let groupedSubscriptions = Dictionary(grouping: subscriptions) { $0.deliveryMethod }
        
        for (method, methodSubscriptions) in groupedSubscriptions {
            if let handler = deliveryHandlers[method] {
                do {
                    try await handler.deliver(notification: notification, to: methodSubscriptions)
                } catch {
                    print("Failed to deliver notification via \(method): \(error)")
                }
            }
        }
    }
    
    private func matchesSubscription(notification: JobNotification, subscription: JobNotificationSubscription) -> Bool {
        // Check if user matches
        if let userId = notification.userId, !subscription.userIds.isEmpty {
            guard subscription.userIds.contains(userId) else { return false }
        }
        
        // Check if job type matches
        if let jobType = notification.jobType, !subscription.jobTypes.isEmpty {
            guard subscription.jobTypes.contains(jobType) else { return false }
        }
        
        // Check if notification type matches
        guard subscription.notificationTypes.contains(notification.type) else { return false }
        
        // Check if severity matches
        if let severity = notification.severity {
            guard subscription.severityLevels.contains(severity) else { return false }
        }
        
        return true
    }
    
    private func validateSubscription(_ subscription: JobNotificationSubscription) -> Bool {
        // Validate delivery method specific requirements
        switch subscription.deliveryMethod {
        case .email:
            return !subscription.emailAddress.isEmpty
        case .webhook:
            guard let url = URL(string: subscription.webhookUrl) else { return false }
            return url.scheme == "http" || url.scheme == "https"
        case .push:
            return !subscription.pushToken.isEmpty
        }
    }
    
    private func setupDefaultDeliveryHandlers() {
        deliveryHandlers[.email] = EmailNotificationHandler()
        deliveryHandlers[.webhook] = WebhookNotificationHandler()
        deliveryHandlers[.push] = PushNotificationHandler()
    }
    
    // MARK: - Public Queries
    
    /// Get notification history for a user or job.
    public func getNotificationHistory(
        userId: String? = nil,
        jobId: JobId? = nil,
        limit: Int? = nil
    ) async -> [JobNotification] {
        var filtered = notificationHistory
        
        if let userId = userId {
            filtered = filtered.filter { $0.userId == userId }
        }
        
        if let jobId = jobId {
            filtered = filtered.filter { $0.jobId == jobId }
        }
        
        filtered = filtered.sorted { $0.timestamp > $1.timestamp }
        
        if let limit = limit {
            filtered = Array(filtered.prefix(limit))
        }
        
        return filtered
    }
    
    /// Get all subscriptions.
    public func getSubscriptions(userId: String? = nil) -> [JobNotificationSubscription] {
        if let userId = userId {
            return subscriptions.filter { $0.userIds.contains(userId) }
        }
        return subscriptions
    }
    
    /// Start background delivery tasks.
    public func start() async {
        if deliveryTask == nil {
            deliveryTask = Task {
                await deliveryLoop()
            }
        }
    }
    
    /// Stop background delivery tasks.
    public func stop() async {
        deliveryTask?.cancel()
        deliveryTask = nil
    }
    
    private func deliveryLoop() async {
        while !Task.isCancelled {
            // Process email queue
            if !emailQueue.isEmpty {
                let batch = Array(emailQueue.prefix(10))
                emailQueue.removeFirst(min(batch.count, emailQueue.count))
                // Process email batch...
            }
            
            // Process webhook queue
            if !webhookQueue.isEmpty {
                let batch = Array(webhookQueue.prefix(50))
                webhookQueue.removeFirst(min(batch.count, webhookQueue.count))
                // Process webhook batch...
            }
            
            // Sleep briefly between batches
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                break
            }
        }
    }
}

// MARK: - Supporting Types

/// Subscription configuration for job notifications.
public struct JobNotificationSubscription: Codable, Identifiable, Sendable {
    public let id: UUID
    public let userIds: Set<String>
    public let jobTypes: Set<String>
    public let notificationTypes: Set<NotificationType>
    public let severityLevels: Set<NotificationSeverity>
    public let deliveryMethod: NotificationDeliveryMethod
    public let emailAddress: String
    public let webhookUrl: String
    public let pushToken: String
    public let receiveSystemNotifications: Bool
    public let isActive: Bool
    
    public init(
        id: UUID = UUID(),
        userIds: Set<String> = [],
        jobTypes: Set<String> = [],
        notificationTypes: Set<NotificationType> = Set(NotificationType.allCases),
        severityLevels: Set<NotificationSeverity> = Set(NotificationSeverity.allCases),
        deliveryMethod: NotificationDeliveryMethod = .email,
        emailAddress: String = "",
        webhookUrl: String = "",
        pushToken: String = "",
        receiveSystemNotifications: Bool = false,
        isActive: Bool = true
    ) {
        self.id = id
        self.userIds = userIds
        self.jobTypes = jobTypes
        self.notificationTypes = notificationTypes
        self.severityLevels = severityLevels
        self.deliveryMethod = deliveryMethod
        self.emailAddress = emailAddress
        self.webhookUrl = webhookUrl
        self.pushToken = pushToken
        self.receiveSystemNotifications = receiveSystemNotifications
        self.isActive = isActive
    }
}

/// Individual job notification.
public struct JobNotification: Codable, Identifiable, Sendable {
    public let id: String
    public let type: NotificationType
    public let jobId: JobId?
    public let jobType: String?
    public let userId: String?
    public let timestamp: Date
    public let title: String
    public let message: String
    public let severity: NotificationSeverity?
    nonisolated(unsafe) public let data: [String: Any]
    
    public init(
        id: String = UUID().uuidString,
        type: NotificationType,
        jobId: JobId? = nil,
        jobType: String? = nil,
        userId: String? = nil,
        timestamp: Date = Date(),
        title: String,
        message: String,
        severity: NotificationSeverity? = nil,
        data: [String: Any] = [:]
    ) {
        self.id = id
        self.type = type
        self.jobId = jobId
        self.jobType = jobType
        self.userId = userId
        self.timestamp = timestamp
        self.title = title
        self.message = message
        self.severity = severity
        self.data = data
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, jobId, jobType, userId, timestamp, title, message, severity, data
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(NotificationType.self, forKey: .type)
        jobId = try container.decodeIfPresent(JobId.self, forKey: .jobId)
        jobType = try container.decodeIfPresent(String.self, forKey: .jobType)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        title = try container.decode(String.self, forKey: .title)
        message = try container.decode(String.self, forKey: .message)
        severity = try container.decodeIfPresent(NotificationSeverity.self, forKey: .severity)
        
        let dataString = try container.decode(String.self, forKey: .data)
        let dataData = dataString.data(using: .utf8) ?? Data()
        data = try JSONSerialization.jsonObject(with: dataData) as? [String: Any] ?? [:]
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(jobId, forKey: .jobId)
        try container.encodeIfPresent(jobType, forKey: .jobType)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(title, forKey: .title)
        try container.encode(message, forKey: .message)
        try container.encodeIfPresent(severity, forKey: .severity)
        
        let dataData = try JSONSerialization.data(withJSONObject: data)
        let dataString = String(data: dataData, encoding: .utf8) ?? "{}"
        try container.encode(dataString, forKey: .data)
    }
}

/// Types of job notifications.
public enum NotificationType: String, Codable, CaseIterable, Sendable {
    case statusChange
    case completion

    case failure
    case timeout
    case retry
    case subscriptionConfirmed
    case systemEvent
}

/// Severity levels for notifications.
public enum NotificationSeverity: String, Codable, CaseIterable, Sendable {
    case info
    case warning
    case error
    case critical
}

/// Delivery methods for notifications.
public enum NotificationDeliveryMethod: String, Codable, CaseIterable, Sendable {
    case email
    case webhook
    case push
}

/// Handler for delivering notifications via specific methods.
public protocol NotificationDeliveryHandler: Sendable {
    func deliver(notification: JobNotification, to subscriptions: [JobNotificationSubscription]) async throws
}

// MARK: - Notification Handlers

/// Email notification handler.
public struct EmailNotificationHandler: NotificationDeliveryHandler {
    public init() {}
    
    public func deliver(notification: JobNotification, to subscriptions: [JobNotificationSubscription]) async throws {
        // Group by email address to avoid duplicates
        let emailGroups = Dictionary(grouping: subscriptions) { $0.emailAddress }
        
        for (emailAddress, emailSubscriptions) in emailGroups {
            // Send email (implementation depends on email service)
            print("Sending email to \(emailAddress): \(notification.title)")
        }
    }
}

/// Webhook notification handler.
public struct WebhookNotificationHandler: NotificationDeliveryHandler {
    public init() {}
    
    public func deliver(notification: JobNotification, to subscriptions: [JobNotificationSubscription]) async throws {
        // Group by webhook URL
        let webhookGroups = Dictionary(grouping: subscriptions) { $0.webhookUrl }
        
        for (webhookUrl, webhookSubscriptions) in webhookGroups {
            guard let url = URL(string: webhookUrl) else { continue }
            
            // Prepare webhook payload
            let payload: [String: Any] = [
                "notification": notification,
                "subscriptions": webhookSubscriptions.map { $0.id.uuidString }
            ]
            
            // Send webhook (implementation depends on HTTP client)
            _ = payload // Suppress unused variable warning until implementation is added
            print("Sending webhook to \(webhookUrl): \(notification.title)")
        }
    }
}

/// Push notification handler.
public struct PushNotificationHandler: NotificationDeliveryHandler {
    public init() {}
    
    public func deliver(notification: JobNotification, to subscriptions: [JobNotificationSubscription]) async throws {
        // Group by push token
        let tokenGroups = Dictionary(grouping: subscriptions) { $0.pushToken }
        
        for (pushToken, tokenSubscriptions) in tokenGroups {
            // Send push notification (implementation depends on push service)
            print("Sending push to token \(pushToken): \(notification.title)")
        }
    }
}

/// Notification-related errors.
public enum NotificationError: Error, LocalizedError {
    case tooManySubscriptions
    case subscriptionNotFound
    case invalidSubscription
    case deliveryFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .tooManySubscriptions:
            return "Maximum number of subscriptions reached"
        case .subscriptionNotFound:
            return "Subscription not found"
        case .invalidSubscription:
            return "Invalid subscription configuration"
        case .deliveryFailed(let message):
            return "Notification delivery failed: \(message)"
        }
    }
}

// MARK: - Extensions

extension JobNotification: Equatable {
    public static func == (lhs: JobNotification, rhs: JobNotification) -> Bool {
        return lhs.id == rhs.id
    }
}