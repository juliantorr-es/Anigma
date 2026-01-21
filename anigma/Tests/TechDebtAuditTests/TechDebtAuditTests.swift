//
//  TechDebtAuditTests.swift
//  TechDebtAuditTests
//
//  Unit tests for TechDebtAuditTests.
//

import XCTest
import TechDebtAudit

final class TechDebtAuditTests: XCTestCase {
    func testSingleMarkerPasses() throws {
        let root = try makeTempRepo()
        try createFile(at: root.appendingPathComponent("Sources/App/Foo.swift"), contents: "// STUB_TRACK: TD-0001 – Example stub\n")
        try createTechDebt(at: root, entries: [("TD-0001", "Example stub", "Meta/Tracking only not set")])

        let audit = TechDebtAudit(rootURL: root)
        let report = try audit.runAudit()
        XCTAssertTrue(report.success)
        XCTAssertEqual(report.missingDocIDs.count, 0)
        XCTAssertEqual(report.orphanedDocIDs.count, 0)
    }

    func testMultipleMarkers() throws {
        let root = try makeTempRepo()
        try createFile(at: root.appendingPathComponent("Sources/App/Foo.swift"), contents: "// STUB_TRACK: TD-0001 – Example stub\n")
        try createFile(at: root.appendingPathComponent("Sources/App/Bar.swift"), contents: "// STUB_TRACK: TD-0002 – Another stub\n")
        try createTechDebt(at: root, entries: [("TD-0001", "Example stub", ""), ("TD-0002", "Another stub", "")])

        let audit = TechDebtAudit(rootURL: root)
        let report = try audit.runAudit()
        XCTAssertTrue(report.success)
        XCTAssertEqual(report.markers.count, 2)
    }

    func testDuplicateMarkerIDs() throws {
        let root = try makeTempRepo()
        try createFile(at: root.appendingPathComponent("Sources/App/Foo.swift"), contents: "// STUB_TRACK: TD-0001 – Example stub\n")
        try createFile(at: root.appendingPathComponent("Sources/App/Bar.swift"), contents: "// STUB_TRACK: TD-0001 – Duplicate stub\n")
        try createTechDebt(at: root, entries: [("TD-0001", "Example stub", "")])

        let audit = TechDebtAudit(rootURL: root)
        XCTAssertThrowsError(try audit.runAudit()) { error in
            XCTAssertTrue(error is TechDebtAuditError)
        }
    }

    func testMalformedMarkerBlock() throws {
        let root = try makeTempRepo()
        let content = """
        // STUB_TRACK
        // ID:
        // END_STUB_TRACK
        """
        try createFile(at: root.appendingPathComponent("Sources/App/Bad.swift"), contents: content)
        try createTechDebt(at: root, entries: [("TD-0001", "Example stub", "")])

        let audit = TechDebtAudit(rootURL: root)
        XCTAssertThrowsError(try audit.runAudit()) { error in
            XCTAssertTrue(error is TechDebtAuditError)
        }
    }

    func testMalformedTechDebtEntry() throws {
        let root = try makeTempRepo()
        try createFile(at: root.appendingPathComponent("Sources/App/Foo.swift"), contents: "// STUB_TRACK: TD-0001 – Example stub\n")
        let techDebtContent = """
        ## Bogus Entry
        ID:
        """
        try createTechDebtContent(at: root, content: techDebtContent)

        let audit = TechDebtAudit(rootURL: root)
        XCTAssertThrowsError(try audit.runAudit()) { error in
            XCTAssertTrue(error is TechDebtAuditError)
        }
    }

    func testOrphanedDocID() throws {
        let root = try makeTempRepo()
        try createTechDebt(at: root, entries: [("TD-0009", "Orphaned stub", "")])
        let audit = TechDebtAudit(rootURL: root)
        let report = try audit.runAudit()
        XCTAssertFalse(report.success)
        XCTAssertEqual(report.orphanedDocIDs.count, 1)
    }

    func testMissingDocID() throws {
        let root = try makeTempRepo()
        try createFile(at: root.appendingPathComponent("Sources/App/Foo.swift"), contents: "// STUB_TRACK: TD-0001 – Example stub\n")
        try createTechDebt(at: root, entries: [])
        let audit = TechDebtAudit(rootURL: root)
        let report = try audit.runAudit()
        XCTAssertFalse(report.success)
        XCTAssertEqual(report.missingDocIDs.count, 1)
    }

    // MARK: - Helpers

    private func makeTempRepo() throws -> URL {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: temp.appendingPathComponent("Sources"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: temp.appendingPathComponent("Docs"), withIntermediateDirectories: true)
        return temp
    }

    private func createFile(at url: URL, contents: String) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    private func createTechDebt(at root: URL, entries: [(String, String, String)]) throws {
        var sections = [String]()
        for (id, title, meta) in entries {
            let metadata = meta.isEmpty ? "" : " - \(meta)"
            sections.append("""
            ### \(id) – \(title)
            ID: \(id) – \(title)\(metadata)
            """)
        }
        let content = """
        # TechDebt

        \(sections.joined(separator: "\n\n"))
        """
        try createTechDebtContent(at: root, content: content)
    }

    private func createTechDebtContent(at root: URL, content: String) throws {
        try createFile(at: root.appendingPathComponent("Docs/TechDebt.md"), contents: content)
    }
}
