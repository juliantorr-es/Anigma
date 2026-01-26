import Foundation
import TelemetryCore
import XCTest

public final class TelemetryHarness {
    public let diagnostics: DefaultCapsuleDiagnostics

    public init(diagnostics: DefaultCapsuleDiagnostics = DefaultCapsuleDiagnostics()) {
        self.diagnostics = diagnostics
    }

    public var events: [DiagnosticEvent] {
        diagnostics.getAllEvents()
    }

    public func reset() {
        diagnostics.clearEvents()
    }

    public func assertEventCount(
        _ expected: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(events.count, expected, file: file, line: line)
    }

    public func assertLastEvent(
        level: DiagnosticLevel? = nil,
        category: String? = nil,
        correlationID: String? = nil,
        messageContains: String? = nil,
        metadata: [String: String]? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let event = events.last else {
            XCTFail("Expected a diagnostic event", file: file, line: line)
            return
        }

        if let level {
            XCTAssertEqual(event.level, level, file: file, line: line)
        }

        if let category {
            XCTAssertEqual(event.category, category, file: file, line: line)
        }

        if let correlationID {
            XCTAssertEqual(event.correlationID, correlationID, file: file, line: line)
        }

        if let messageContains {
            XCTAssertTrue(event.message.contains(messageContains), file: file, line: line)
        }

        if let metadata {
            for (key, value) in metadata {
                XCTAssertEqual(event.metadata[key], value, file: file, line: line)
            }
        }
    }

    public func assertMessageRedacted(
        event: DiagnosticEvent? = nil,
        deepClean: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let targetEvent = event ?? events.last else {
            XCTFail("Expected a diagnostic event", file: file, line: line)
            return
        }

        XCTAssertFalse(
            DiagnosticRedactionRules.containsSensitiveData(targetEvent.message, deepClean: deepClean),
            file: file,
            line: line
        )
    }

    public func assertMetadataRedacted(
        event: DiagnosticEvent? = nil,
        deepClean: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let targetEvent = event ?? events.last else {
            XCTFail("Expected a diagnostic event", file: file, line: line)
            return
        }

        for (key, value) in targetEvent.metadata {
            if DiagnosticRedactionRules.safeKeys.contains(key.lowercased()) {
                continue
            }

            XCTAssertFalse(
                DiagnosticRedactionRules.containsSensitiveData(value, deepClean: deepClean),
                file: file,
                line: line
            )
        }
    }
}
