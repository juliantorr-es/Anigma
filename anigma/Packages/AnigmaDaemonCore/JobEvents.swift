//
//  JobEvents.swift
//  AnigmaDaemonCore
//
//  Job event buffering and streaming.
//

import Foundation

public enum DaemonJobEventType: String, Sendable, Codable {
    case state = "STATE"
    case progress = "PROGRESS"
    case log = "LOG"
    case output = "OUTPUT"
}

public struct DaemonJobEvent: Sendable, Codable {
    public let jobId: String
    public let type: DaemonJobEventType
    public let message: String
    public let progressPermille: UInt32
    public let output: ArtifactRef?
    public let receiptHash: String?
    public let error: ErrorStatus?

    public init(
        jobId: String,
        type: DaemonJobEventType,
        message: String,
        progressPermille: UInt32,
        output: ArtifactRef? = nil,
        receiptHash: String? = nil,
        error: ErrorStatus? = nil
    ) {
        self.jobId = jobId
        self.type = type
        self.message = message
        self.progressPermille = progressPermille
        self.output = output
        self.receiptHash = receiptHash
        self.error = error
    }
}

public actor JobEventHub {
    private var buffers: [String: [DaemonJobEvent]] = [:]
    private var subscribers: [String: [UUID: AsyncStream<DaemonJobEvent>.Continuation]] = [:]
    private let maxBuffer: Int

    public init(maxBuffer: Int = 200) {
        self.maxBuffer = maxBuffer
    }

    public func record(_ event: DaemonJobEvent) {
        var buffer = buffers[event.jobId] ?? []
        buffer.append(event)
        if buffer.count > maxBuffer {
            buffer.removeFirst(buffer.count - maxBuffer)
        }
        buffers[event.jobId] = buffer

        if let listeners = subscribers[event.jobId] {
            for continuation in listeners.values {
                continuation.yield(event)
            }
        }
    }

    public func stream(jobId: String) -> AsyncStream<DaemonJobEvent> {
        AsyncStream { continuation in
            let id = UUID()
            let buffer = buffers[jobId] ?? []
            for event in buffer {
                continuation.yield(event)
            }
            if containsTerminalEvent(buffer) {
                continuation.finish()
                return
            }
            var listeners = subscribers[jobId] ?? [:]
            listeners[id] = continuation
            subscribers[jobId] = listeners
            continuation.onTermination = { _ in
                Task { await self.removeSubscriber(jobId: jobId, id: id) }
            }
        }
    }

    public func finish(jobId: String) {
        if let listeners = subscribers[jobId] {
            for continuation in listeners.values {
                continuation.finish()
            }
        }
        subscribers[jobId] = [:]
    }

    private func containsTerminalEvent(_ events: [DaemonJobEvent]) -> Bool {
        return events.contains { event in
            guard event.type == .state else { return false }
            return ["SUCCEEDED", "FAILED", "CANCELED"].contains(event.message)
        }
    }

    private func removeSubscriber(jobId: String, id: UUID) {
        var listeners = subscribers[jobId] ?? [:]
        listeners.removeValue(forKey: id)
        subscribers[jobId] = listeners
    }
}
