//
//  DevelopumBridgeTests.swift
//  DevelopumModuleTests
//
//  Tests for DevelopumBridge message serialization and processing.
//

import XCTest
@testable import AnigmaCore
@testable import DevelopumModule

final class DevelopumBridgeTests: XCTestCase {

    // MARK: - Message Type Tests

    func testMessageTypeEditorToSwiftCases() {
        XCTAssertEqual(DevelopumMessageType.editorReady.rawValue, "editorReady")
        XCTAssertEqual(DevelopumMessageType.fileOpened.rawValue, "fileOpened")
        XCTAssertEqual(DevelopumMessageType.fileClosed.rawValue, "fileClosed")
        XCTAssertEqual(DevelopumMessageType.cursorMoved.rawValue, "cursorMoved")
        XCTAssertEqual(DevelopumMessageType.selectionChanged.rawValue, "selectionChanged")
        XCTAssertEqual(DevelopumMessageType.viewportChanged.rawValue, "viewportChanged")
        XCTAssertEqual(DevelopumMessageType.contentChanged.rawValue, "contentChanged")
        XCTAssertEqual(DevelopumMessageType.saveRequest.rawValue, "saveRequest")
        XCTAssertEqual(DevelopumMessageType.searchRequest.rawValue, "searchRequest")
        XCTAssertEqual(DevelopumMessageType.findReferencesRequest.rawValue, "findReferencesRequest")
    }

    func testMessageTypeSwiftToEditorCases() {
        XCTAssertEqual(DevelopumMessageType.openFile.rawValue, "openFile")
        XCTAssertEqual(DevelopumMessageType.closeFile.rawValue, "closeFile")
        XCTAssertEqual(DevelopumMessageType.updateContent.rawValue, "updateContent")
        XCTAssertEqual(DevelopumMessageType.showMessage.rawValue, "showMessage")
        XCTAssertEqual(DevelopumMessageType.setCursor.rawValue, "setCursor")
        XCTAssertEqual(DevelopumMessageType.setSelection.rawValue, "setSelection")
        XCTAssertEqual(DevelopumMessageType.setViewport.rawValue, "setViewport")
        XCTAssertEqual(DevelopumMessageType.searchResults.rawValue, "searchResults")
        XCTAssertEqual(DevelopumMessageType.referencesResults.rawValue, "referencesResults")
        XCTAssertEqual(DevelopumMessageType.receiptNotification.rawValue, "receiptNotification")
    }

    // MARK: - Bridge Message Tests

    func testBridgeMessageInitialization() {
        let payload = EditorReadyPayload(editorId: "editor1", editorVersion: "0.35.0", capabilities: ["syntax", "completion"])
        let message = DevelopumBridgeMessage(
            type: .editorReady,
            sessionId: "session123",
            payload: .editorReady(payload)
        )

        XCTAssertEqual(message.version, .v1)
        XCTAssertEqual(message.type, .editorReady)
        XCTAssertFalse(message.messageId.isEmpty)
        XCTAssertEqual(message.sessionId, "session123")
        XCTAssertNil(message.repoId)
        XCTAssertGreaterThan(message.timestampMs, 0)
        XCTAssertEqual(try? message.payload.get(), payload)
    }

    func testBridgeMessageWithRepoId() {
        let payload = FileOpenedPayload(
            fileUri: "anigma://src/main.swift",
            filePath: "src/main.swift",
            languageId: "swift",
            contentHash: "abc123"
        )
        let message = DevelopumBridgeMessage(
            type: .fileOpened,
            sessionId: "session123",
            repoId: "repo-uuid-456",
            payload: .fileOpened(payload)
        )

        XCTAssertEqual(message.repoId, "repo-uuid-456")
    }

    func testBridgeMessageCodableRoundtrip() throws {
        let payload = SaveRequestPayload(
            fileUri: "anigma://test.swift",
            content: "print(\"Hello\")",
            contentHash: "sha256:def456"
        )
        let original = DevelopumBridgeMessage(
            type: .saveRequest,
            sessionId: "session789",
            repoId: "repo-uuid-123",
            payload: .saveRequest(payload)
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DevelopumBridgeMessage.self, from: data)

        XCTAssertEqual(original.version, decoded.version)
        XCTAssertEqual(original.type, decoded.type)
        XCTAssertEqual(original.sessionId, decoded.sessionId)
        XCTAssertEqual(original.repoId, decoded.repoId)

        let decodedPayload = try XCTUnwrap(try decoded.payload.get() as? SaveRequestPayload)
        XCTAssertEqual(decodedPayload.fileUri, payload.fileUri)
        XCTAssertEqual(decodedPayload.content, payload.content)
        XCTAssertEqual(decodedPayload.contentHash, payload.contentHash)
    }

    // MARK: - Payload Tests

    func testEditorReadyPayload() {
        let payload = EditorReadyPayload(
            editorId: "monaco-1",
            editorVersion: "0.34.1",
            capabilities: ["intellisense", "syntax", "minimap"]
        )

        XCTAssertEqual(payload.editorId, "monaco-1")
        XCTAssertEqual(payload.editorVersion, "0.34.1")
        XCTAssertEqual(payload.capabilities.count, 3)
    }

    func testFileOpenedPayload() {
        let payload = FileOpenedPayload(
            fileUri: "anigma://lib/utils.swift",
            filePath: "lib/utils.swift",
            languageId: "swift",
            contentHash: "sha256:abc"
        )

        XCTAssertEqual(payload.fileUri, "anigma://lib/utils.swift")
        XCTAssertEqual(payload.filePath, "lib/utils.swift")
        XCTAssertEqual(payload.languageId, "swift")
        XCTAssertEqual(payload.contentHash, "sha256:abc")
    }

    func testFileClosedPayload() {
        let payload = FileClosedPayload(
            fileUri: "anigma://test.swift",
            hadUnsavedChanges: true
        )

        XCTAssertEqual(payload.fileUri, "anigma://test.swift")
        XCTAssertTrue(payload.hadUnsavedChanges)
    }

    func testCursorMovedPayload() {
        let payload = CursorMovedPayload(
            fileUri: "anigma://main.swift",
            line: 42,
            column: 15
        )

        XCTAssertEqual(payload.fileUri, "anigma://main.swift")
        XCTAssertEqual(payload.line, 42)
        XCTAssertEqual(payload.column, 15)
    }

    func testSelectionChangedPayload() {
        let payload = SelectionChangedPayload(
            fileUri: "anigma://test.swift",
            startLine: 10,
            startColumn: 5,
            endLine: 15,
            endColumn: 20
        )

        XCTAssertEqual(payload.startLine, 10)
        XCTAssertEqual(payload.endLine, 15)
    }

    func testViewportChangedPayload() {
        let payload = ViewportChangedPayload(
            fileUri: "anigma://big.swift",
            topLine: 100,
            bottomLine: 150
        )

        XCTAssertEqual(payload.topLine, 100)
        XCTAssertEqual(payload.bottomLine, 150)
    }

    func testContentChangedPayload() {
        let payload = ContentChangedPayload(
            fileUri: "anigma://editable.swift",
            changes: "[{\"range\": {\"startLine\": 5}, \"text\": \"new line\"}]",
            contentHash: "sha256:new123",
            hasUnsavedChanges: true
        )

        XCTAssertTrue(payload.hasUnsavedChanges)
    }

    func testSaveRequestPayload() {
        let payload = SaveRequestPayload(
            fileUri: "anigma://save.swift",
            content: "final class Test {}",
            contentHash: "sha256:final"
        )

        XCTAssertEqual(payload.content, "final class Test {}")
    }

    func testSearchRequestPayload() {
        let payload = SearchRequestPayload(
            fileUri: nil,
            query: "func.*test",
            isRegex: true,
            matchCase: false,
            matchWholeWord: false
        )

        XCTAssertNil(payload.fileUri)
        XCTAssertTrue(payload.isRegex)
        XCTAssertFalse(payload.matchCase)
    }

    func testFindReferencesRequestPayload() {
        let payload = FindReferencesRequestPayload(
            fileUri: "anigma://main.swift",
            line: 25,
            column: 10
        )

        XCTAssertEqual(payload.line, 25)
        XCTAssertEqual(payload.column, 10)
    }

    func testOpenFilePayload() {
        let payload = OpenFilePayload(
            fileUri: "anigma://new.swift",
            content: "// New file",
            languageId: "swift",
            focus: true
        )

        XCTAssertTrue(payload.focus)
    }

    func testCloseFilePayload() {
        let payload = CloseFilePayload(fileUri: "anigma://close.swift")
        XCTAssertEqual(payload.fileUri, "anigma://close.swift")
    }

    func testUpdateContentPayload() {
        let selection = SelectionRange(startLine: 1, startColumn: 0, endLine: 1, endColumn: 10)
        let payload = UpdateContentPayload(
            fileUri: "anigma://update.swift",
            content: "Updated content",
            selection: selection
        )

        XCTAssertNotNil(payload.selection)
        XCTAssertEqual(payload.selection?.startLine, 1)
    }

    func testShowMessagePayload() {
        let payload = ShowMessagePayload(
            severity: .error,
            message: "Build failed",
            timeoutMs: 5000
        )

        XCTAssertEqual(payload.severity, .error)
        XCTAssertEqual(payload.message, "Build failed")
        XCTAssertEqual(payload.timeoutMs, 5000)
    }

    func testSetCursorPayload() {
        let payload = SetCursorPayload(
            fileUri: "anigma://cursor.swift",
            line: 100,
            column: 5
        )

        XCTAssertEqual(payload.line, 100)
    }

    func testSetSelectionPayload() {
        let selection = SelectionRange(startLine: 5, startColumn: 10, endLine: 8, endColumn: 20)
        let payload = SetSelectionPayload(
            fileUri: "anigma://select.swift",
            selection: selection
        )

        XCTAssertEqual(payload.selection.endLine, 8)
    }

    func testSetViewportPayload() {
        let viewport = ViewportRange(topLine: 50, bottomLine: 100)
        let payload = SetViewportPayload(
            fileUri: "anigma://viewport.swift",
            viewport: viewport
        )

        XCTAssertEqual(payload.viewport.topLine, 50)
    }

    func testSearchResultsPayload() {
        let results = [
            SearchResult(fileUri: "anigma://a.swift", line: 1, column: 5, match: "test", lineText: "let test = 1"),
            SearchResult(fileUri: "anigma://b.swift", line: 10, column: 20, match: "test", lineText: "func test() {}")
        ]
        let payload = SearchResultsPayload(
            requestId: "search-123",
            results: results,
            isComplete: true
        )

        XCTAssertEqual(payload.requestId, "search-123")
        XCTAssertEqual(payload.results.count, 2)
        XCTAssertTrue(payload.isComplete)
    }

    func testReferencesResultsPayload() {
        let results = [
            ReferenceResult(fileUri: "anigma://main.swift", line: 5, column: 10, name: "myFunc", kind: "function"),
            ReferenceResult(fileUri: "anigma://other.swift", line: 20, column: 15, name: "myFunc", kind: "declaration")
        ]
        let payload = ReferencesResultsPayload(
            requestId: "refs-456",
            results: results
        )

        XCTAssertEqual(payload.results.first?.kind, "function")
    }

    func testReceiptNotificationPayload() {
        let payload = ReceiptNotificationPayload(
            receiptId: "receipt-789",
            operationType: "saveFile",
            status: .success,
            message: "File saved successfully"
        )

        XCTAssertEqual(payload.status, .success)
        XCTAssertEqual(payload.message, "File saved successfully")
    }

    // MARK: - Supporting Type Tests

    func testSelectionRange() {
        let range = SelectionRange(startLine: 1, startColumn: 5, endLine: 3, endColumn: 10)
        XCTAssertEqual(range.startLine, 1)
        XCTAssertEqual(range.endColumn, 10)
    }

    func testViewportRange() {
        let viewport = ViewportRange(topLine: 10, bottomLine: 50)
        XCTAssertEqual(viewport.topLine, 10)
        XCTAssertEqual(viewport.bottomLine, 50)
    }

    func testSearchResult() {
        let result = SearchResult(
            fileUri: "anigma://test.swift",
            line: 42,
            column: 15,
            match: "TODO",
            lineText: "// TODO: fix this"
        )

        XCTAssertEqual(result.match, "TODO")
    }

    func testReferenceResult() {
        let result = ReferenceResult(
            fileUri: "anigma://decl.swift",
            line: 100,
            column: 5,
            name: "calculateTotal",
            kind: "method"
        )

        XCTAssertEqual(result.name, "calculateTotal")
        XCTAssertEqual(result.kind, "method")
    }

    func testMessageSeverity() {
        XCTAssertEqual(MessageSeverity.info.rawValue, "info")
        XCTAssertEqual(MessageSeverity.warning.rawValue, "warning")
        XCTAssertEqual(MessageSeverity.error.rawValue, "error")
    }

    func testReceiptStatus() {
        XCTAssertEqual(ReceiptStatus.success.rawValue, "success")
        XCTAssertEqual(ReceiptStatus.failure.rawValue, "failure")
        XCTAssertEqual(ReceiptStatus.pending.rawValue, "pending")
    }

    // MARK: - Bridge Version Tests

    func testBridgeVersionV1() {
        XCTAssertEqual(DevelopumBridgeVersion.v1.rawValue, "1.0")
    }

    // MARK: - JCS Canonicalization Tests

    func testMessageCanonicalJSON() throws {
        let payload = EditorReadyPayload(editorId: "e1", editorVersion: "1.0", capabilities: [])
        let message = DevelopumBridgeMessage(
            type: .editorReady,
            sessionId: "s1",
            payload: .editorReady(payload)
        )

        let canonical = try message.toCanonicalJSON()

        XCTAssertFalse(canonical.isEmpty)
        let jsonObject = try JSONSerialization.jsonObject(with: canonical) as? [String: Any]
        XCTAssertNotNil(jsonObject)
        XCTAssertEqual(jsonObject?["version"] as? String, "1.0")
        XCTAssertEqual(jsonObject?["type"] as? String, "editorReady")
    }

    func testMessageCanonicalHash() throws {
        let payload = FileOpenedPayload(
            fileUri: "anigma://test.swift",
            filePath: "test.swift",
            languageId: "swift",
            contentHash: "hash"
        )
        let message = DevelopumBridgeMessage(
            type: .fileOpened,
            sessionId: "s1",
            payload: .fileOpened(payload)
        )

        let hash = try message.canonicalHash()

        XCTAssertFalse(hash.isEmpty)
    }

    // MARK: - Payload Codable Roundtrip Tests

    func testPayloadEditorReadyCodable() throws {
        let original = EditorReadyPayload(editorId: "id", editorVersion: "1.0", capabilities: ["a", "b"])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EditorReadyPayload.self, from: data)
        XCTAssertEqual(original.editorId, decoded.editorId)
        XCTAssertEqual(original.capabilities, decoded.capabilities)
    }

    func testPayloadCursorMovedCodable() throws {
        let original = CursorMovedPayload(fileUri: "uri", line: 10, column: 5)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CursorMovedPayload.self, from: data)
        XCTAssertEqual(original.line, decoded.line)
        XCTAssertEqual(original.column, decoded.column)
    }

    func testPayloadSearchResultsCodable() throws {
        let original = SearchResultsPayload(
            requestId: "req1",
            results: [
                SearchResult(fileUri: "uri1", line: 1, column: 1, match: "m", lineText: "t")
            ],
            isComplete: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SearchResultsPayload.self, from: data)
        XCTAssertEqual(original.requestId, decoded.requestId)
        XCTAssertEqual(original.results.count, decoded.results.count)
    }

    // MARK: - Edge Cases

    func testMessageWithEmptyCapabilities() {
        let payload = EditorReadyPayload(editorId: "e", editorVersion: "1.0", capabilities: [])
        let message = DevelopumBridgeMessage(type: .editorReady, sessionId: "s", payload: .editorReady(payload))
        XCTAssertEqual(try message.payload.get() as? EditorReadyPayload, payload)
    }

    func testSearchRequestWithFileScope() {
        let payload = SearchRequestPayload(
            fileUri: "anigma://scope.swift",
            query: "TODO",
            isRegex: false,
            matchCase: true,
            matchWholeWord: true
        )

        XCTAssertNotNil(payload.fileUri)
        XCTAssertTrue(payload.matchWholeWord)
    }

    func testPayloadWithNilTimeout() {
        let payload = ShowMessagePayload(severity: .warning, message: "Warning", timeoutMs: nil)
        XCTAssertNil(payload.timeoutMs)
    }

    func testEmptySearchResults() {
        let payload = SearchResultsPayload(requestId: "empty", results: [], isComplete: true)
        XCTAssertTrue(payload.results.isEmpty)
    }
}
