//
//  CLIEventStream.swift
//  AnigmaCLIEventing
//
//  Event stream wiring for CLI orchestration.
//

import Foundation

public enum CLIEventKind: String, Codable, Sendable {
    case info
    case warning
    case error
    case progress
    case contractBuilt
    case routeDecision
    case governance
    case execution
}

public struct CLIEvent: Sendable, Codable, Hashable {
    public let id: UUID
    public let timestamp: Date
    public let kind: CLIEventKind
    public let message: String
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        kind: CLIEventKind,
        message: String,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.message = message
        self.metadata = metadata
    }
}

public actor CLIEventStream {
    private var continuations: [UUID: AsyncStream<CLIEvent>.Continuation] = [:]

    public init() {
    }

    public func subscribe() -> AsyncStream<CLIEvent> {
        let streamId = UUID()
        return AsyncStream { continuation in
            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.remove(streamId)
                }
            }
            Task {
                await self.add(continuation, id: streamId)
            }
        }
    }

    public func emit(_ event: CLIEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    public func finish() {
        for continuation in continuations.values {
            continuation.finish()
        }
        continuations.removeAll()
    }

    private func add(_ continuation: AsyncStream<CLIEvent>.Continuation, id: UUID) async {
        continuations[id] = continuation
    }

    private func remove(_ id: UUID) async {
        continuations.removeValue(forKey: id)
    }
}
