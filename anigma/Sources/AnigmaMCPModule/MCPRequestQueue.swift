import Foundation

/// Represents a queued MCP request
public struct MCPQueuedRequest: Sendable {
    public let context: MCPRequestContext
    public let clientId: String

    init(context: MCPRequestContext) {
        self.context = context
        self.clientId = context.clientId
    }
}

/// Status of the request queue
public struct QueueStatus: Sendable {
    public let depth: Int
    public let maxDepth: Int
    public let loadPercentage: Double
    public let requestsByPriority: [RequestPriority: Int]
}

/// Central request queue with priority ordering and adaptive throttling
public actor MCPRequestQueue {
    private var queue: [MCPQueuedRequest] = []
    private let maxQueueDepth: Int
    private let warningQueueDepth: Int
    private let throttle: AdaptiveThrottle
    private var clientSessions: [String: MCPClientSession] = [:]

    public init(
        maxQueueDepth: Int = 50,
        warningQueueDepth: Int = 30
    ) {
        self.maxQueueDepth = maxQueueDepth
        self.warningQueueDepth = warningQueueDepth
        self.throttle = AdaptiveThrottle()
    }

    /// Attempts to enqueue a request
    public func enqueueRequest(_ context: MCPRequestContext) async -> (accepted: Bool, throttleHint: ThrottleHint?, reason: String?) {
        // Get or create client session
        let session: MCPClientSession
        if let existing = clientSessions[context.clientId] {
            session = existing
        } else {
            session = MCPClientSession(clientId: context.clientId)
            clientSessions[context.clientId] = session
        }

        // Check if client can accept more requests
        let canAccept = await session.canAcceptRequest()
        if !canAccept {
            let loadPercentage = Double(queue.count) / Double(maxQueueDepth)
            let throttleHint = ThrottleHint(loadPercentage: loadPercentage)
            return (false, throttleHint, "Client quota exceeded")
        }

        // Calculate current load
        let loadPercentage = Double(queue.count) / Double(maxQueueDepth)

        // Evaluate throttle decision
        let decision = await throttle.evaluateRequest(priority: context.priority, queueLoad: loadPercentage)

        if !decision.accept {
            return (false, decision.throttleHint, decision.reason)
        }

        // Add to queue (sorted by priority, then by insertion order)
        let queuedRequest = MCPQueuedRequest(context: context)
        queue.append(queuedRequest)
        queue.sort { a, b in
            if a.context.priority != b.context.priority {
                return a.context.priority > b.context.priority  // Higher priority first
            }
            return a.context.createdAt < b.context.createdAt  // FIFO within priority tier
        }

        // Record in client session
        Task {
            try? await session.recordRequestStart(context.requestId)
        }

        return (true, decision.throttleHint, nil)
    }

    /// Dequeues the next request (highest priority first)
    public func dequeueNextRequest() -> MCPQueuedRequest? {
        guard !queue.isEmpty else { return nil }
        return queue.removeFirst()
    }

    /// Records request completion in client session
    public func recordCompletion(_ requestId: MCPRequestId, clientId: String) {
        if let session = clientSessions[clientId] {
            Task {
                await session.recordRequestCompletion(requestId)
            }
        }
    }

    /// Gets current queue status
    public func getStatus() -> QueueStatus {
        let loadPercentage = Double(queue.count) / Double(maxQueueDepth)

        // Count by priority
        var byPriority: [RequestPriority: Int] = [:]
        for request in queue {
            byPriority[request.context.priority, default: 0] += 1
        }

        return QueueStatus(
            depth: queue.count,
            maxDepth: maxQueueDepth,
            loadPercentage: loadPercentage,
            requestsByPriority: byPriority
        )
    }

    /// Gets client session status
    public func getClientStatus(_ clientId: String) async -> ClientSessionStatus? {
        guard let session = clientSessions[clientId] else { return nil }
        return await session.getStatus()
    }

    /// Gets all client statuses
    public func getAllClientStatuses() async -> [ClientSessionStatus] {
        var statuses: [ClientSessionStatus] = []
        for (_, session) in clientSessions {
            let status = await session.getStatus()
            statuses.append(status)
        }
        return statuses
    }

    /// Cleanup: remove inactive client sessions
    public func cleanup() {
        let now = Date()
        let timeout: TimeInterval = 300  // 5 minutes

        for (clientId, session) in clientSessions {
            Task {
                let status = session.getStatus()
                if now.timeIntervalSince(status.lastActivityAt) > timeout {
                    self.removeClientSession(clientId)
                }
            }
        }
    }

    private func removeClientSession(_ clientId: String) {
        clientSessions.removeValue(forKey: clientId)
    }

    /// Purges excess requests if queue exceeds threshold
    public func purgeExcessRequests() -> Int {
        guard queue.count > maxQueueDepth else { return 0 }

        // Remove oldest low-priority requests
        var purged = 0
        while queue.count > maxQueueDepth && purged < 10 {
            // Find oldest low-priority request
            if let lowPriorityIndex = queue.firstIndex(where: { $0.context.priority == .low }) {
                queue.remove(at: lowPriorityIndex)
                purged += 1
            } else if let normalPriorityIndex = queue.firstIndex(where: { $0.context.priority == .normal }) {
                queue.remove(at: normalPriorityIndex)
                purged += 1
            } else {
                break
            }
        }

        return purged
    }
}
