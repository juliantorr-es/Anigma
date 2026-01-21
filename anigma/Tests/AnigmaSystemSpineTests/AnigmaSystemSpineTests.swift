//
//  AnigmaSystemSpineTests.swift
//  AnigmaSystemSpineTests
//
//  Tests for the shared system spine.
//

import XCTest
@testable import AnigmaSystemSpine
import CoreData

final class AnigmaSystemSpineTests: XCTestCase, @unchecked Sendable {

    var spine: SystemSpine!

    override func setUp() {
        super.setUp()
        // Use in-memory store for testing
        spine = SystemSpine(inMemory: true)
    }

    override func tearDown() {
        spine = nil
        super.tearDown()
    }

    func testSpineInitialization() {
        XCTAssertNotNil(spine.container)
        XCTAssertEqual(spine.appGroupIdentifier, "group.com.anigma.system")
    }

    func testRecordReceipt() async throws {
        spine.recordReceipt(action: "test_action", actor: "tester", surface: "test_suite", details: "details")

        // Wait for background save
        try await Task.sleep(nanoseconds: 1_000_000_000)

        let context = spine.container.viewContext
        try await context.perform {
            let request = NSFetchRequest<AnigmaReceipt>(entityName: "AnigmaReceipt")
            do {
                let results = try context.fetch(request)
                XCTAssertEqual(results.count, 1)
                XCTAssertEqual(results.first?.action, "test_action")
            } catch {
                XCTFail("Fetch failed: \(error)")
            }
        }
    }

    func testWidgetDataProvider() async {
        // Seed data
        let context = spine.container.newBackgroundContext()
        await context.perform {
            let task = AnigmaTask(context: context)
            task.id = UUID()
            task.title = "Widget Task"
            task.isDone = false
            try? context.save()
        }

        // Wait for propagation
        try? await Task.sleep(nanoseconds: 500_000_000)

        let provider = WidgetDataProvider(spine: spine)
        let tasks = await provider.getTodayTasks()

        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.title, "Widget Task")
    }
}
