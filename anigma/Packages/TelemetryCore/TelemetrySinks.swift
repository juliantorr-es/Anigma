//
//  TelemetrySinks.swift
//  AnigmaCore
//
//  Concrete telemetry output sinks.
//  These live in Tier 2 (Platform Runtime) as they perform execution and storage.
//

import Foundation

/// A file-based telemetry sink for local development.
public struct FileTelemetrySink: TelemetrySink {
    public let id: String
    public let isEnabled: Bool
    private let fileURL: URL
    private let wireEncoder: JSONEncoder

    public init(id: String = "file", fileURL: URL, enabled: Bool = true) {
        self.id = id
        self.isEnabled = enabled
        self.fileURL = fileURL
        self.wireEncoder = JSONEncoder()
        self.wireEncoder.outputFormatting = [.sortedKeys]
    }

    public func handle(_ event: WireRedactedEvent) async throws {
        guard isEnabled else { return }

        let data = try wireEncoder.encode(event)
        let line = (String(data: data, encoding: .utf8) ?? "{}") + "\n"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .utility).async {
                do {
                    if !FileManager.default.fileExists(atPath: self.fileURL.path) {
                        try "{}".write(to: self.fileURL, atomically: false, encoding: .utf8)
                    }
                    let fileHandle = try FileHandle(forWritingTo: self.fileURL)
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(line.data(using: .utf8) ?? Data())
                    fileHandle.closeFile()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func flush() async throws {}
}

/// A memory-based telemetry sink for testing and development.
public actor MemoryTelemetrySink: TelemetrySink {
    public let id: String
    public let isEnabled: Bool
    private var events: [WireRedactedEvent] = []
    private let maxEvents: Int

    public init(id: String = "memory", maxEvents: Int = 1000, enabled: Bool = true) {
        self.id = id
        self.isEnabled = enabled
        self.maxEvents = maxEvents
    }

    public func handle(_ event: WireRedactedEvent) async throws {
        guard isEnabled else { return }
        events.append(event)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }

    public func flush() async throws {}

    public func getAllEvents() -> [WireRedactedEvent] { events }
    public func clear() { events.removeAll() }
}

/// A console-based telemetry sink for development.
public struct ConsoleTelemetrySink: TelemetrySink {
    public let id: String
    public let isEnabled: Bool
    private let wireEncoder: JSONEncoder

    public init(id: String = "console", enabled: Bool = true) {
        self.id = id
        self.isEnabled = enabled
        self.wireEncoder = JSONEncoder()
        self.wireEncoder.outputFormatting = [.sortedKeys]
    }

    public func handle(_ event: WireRedactedEvent) async throws {
        guard isEnabled else { return }
        let data = try wireEncoder.encode(event)
        let jsonString = String(data: data, encoding: .utf8) ?? "{}"
        print("🔬 Telemetry: \(jsonString)")
    }

    public func flush() async throws {}
}

/// A composite sink that forwards to multiple sinks.
public actor CompositeTelemetrySink: TelemetrySink {
    public let id: String
    public let isEnabled: Bool
    private let sinks: [TelemetrySink]

    public init(id: String = "composite", sinks: [TelemetrySink], enabled: Bool = true) {
        self.id = id
        self.isEnabled = enabled
        self.sinks = sinks
    }

    public func handle(_ event: WireRedactedEvent) async throws {
        guard isEnabled else { return }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for sink in sinks {
                group.addTask {
                    if sink.isEnabled {
                        try await sink.handle(event)
                    }
                }
            }
            for try await _ in group {}
        }
    }

    public func flush() async throws {
        guard isEnabled else { return }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for sink in sinks {
                group.addTask {
                    if sink.isEnabled {
                        try await sink.flush()
                    }
                }
            }
            for try await _ in group {}
        }
    }
}
