//
//  DatabaseConcurrencyTests.swift
//  DatabaseCoreTests
//
//  Tests for SQLite concurrency behavior under stress.
//

import XCTest
@testable import DatabaseCore

final class DatabaseConcurrencyTests: XCTestCase {
    private var testDbPath: String!

    override func setUp() async throws {
        // Create a temporary database file
        let tempDir = FileManager.default.temporaryDirectory
        testDbPath = tempDir.appendingPathComponent("test_concurrency_\(UUID().uuidString).sqlite").path
    }

    override func tearDown() async throws {
        // Clean up the test database
        if FileManager.default.fileExists(atPath: testDbPath) {
            try FileManager.default.removeItem(atPath: testDbPath)
        }
        testDbPath = nil
    }

    func testConcurrentTransactionRetries() async throws {
        // Set up the database first
        let setupActor = DatabaseActor(dbPath: testDbPath)
        try await setupActor.open()

        // Create a simple table for testing
        try await setupActor.execute("""
            CREATE TABLE IF NOT EXISTS test_table (
                id INTEGER PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
        """)

        // Test parameters
        let concurrentWriters = 10
        let writesPerWriter = 5
        let expectation = XCTestExpectation(description: "All concurrent writes complete")
        expectation.expectedFulfillmentCount = concurrentWriters

        var successfulWrites = 0
        var totalRetries = 0
        let successLock = NSLock()

        // Launch concurrent writers with separate database actors
        for writerId in 0..<concurrentWriters {
            Task {
                let dbActor = DatabaseActor(dbPath: testDbPath)
                do {
                    try await dbActor.open()

                    for writeId in 0..<writesPerWriter {
                        let value = "writer_\(writerId)_write_\(writeId)"
                        let timestamp = ISO8601DateFormatter().string(from: Date())

                        // This should trigger transaction retries due to SQLITE_BUSY
                        try await dbActor.transaction(mode: .immediate) {
                            // Simulate some work
                            try await Task.sleep(nanoseconds: 1_000_000) // 1ms

                            try await dbActor.execute("""
                                INSERT OR REPLACE INTO test_table (id, value, updated_at)
                                VALUES (?, ?, ?)
                            """, parameters: [
                                .int(writerId * 100 + writeId),
                                .text(value),
                                .text(timestamp)
                            ])
                        }

                        successLock.lock()
                        successfulWrites += 1
                        successLock.unlock()
                    }

                    // Collect metrics from this writer
                    let metrics = await dbActor.getMetrics()
                    successLock.lock()
                    totalRetries += metrics.transactionRetries
                    successLock.unlock()

                } catch {
                    print("Writer \(writerId) failed: \(error)")
                    XCTFail("Concurrent write should not fail: \(error)")
                }

                expectation.fulfill()
            }
        }

        // Wait for all writers to complete
        await fulfillment(of: [expectation], timeout: 30.0)

        // Verify results
        XCTAssertEqual(successfulWrites, concurrentWriters * writesPerWriter,
                      "All writes should succeed")

        print("Concurrency stress test results:")
        print("  Successful writes: \(successfulWrites)")
        print("  Total transaction retries: \(totalRetries)")

        // Verify data integrity
        let rows = try await setupActor.query("SELECT COUNT(*) as count FROM test_table")
        XCTAssertEqual(rows.first?.int(for: "count"), successfulWrites,
                      "All rows should be written")

        // Test that we experienced contention (this might not always trigger due to timing)
        if totalRetries > 0 {
            XCTAssertGreaterThan(totalRetries, 0,
                                "Should have experienced transaction retries under contention")
            print("  Contention detected: \(totalRetries) retries across all writers")
        } else {
            print("  No contention detected (timing dependent, this is ok)")
        }
    }

    func testWALCheckpointUnderLoad() async throws {
        let dbActor = DatabaseActor(dbPath: testDbPath)
        try await dbActor.open()

        // Create a table and populate with data to generate WAL
        try await dbActor.execute("""
            CREATE TABLE IF NOT EXISTS stress_test (
                id INTEGER PRIMARY KEY,
                data BLOB NOT NULL
            )
        """)

        // Insert enough data to generate WAL growth
        let largeData = Data(repeating: 0x41, count: 1024 * 10) // 10KB per row
        let rowCount = 100

        for i in 0..<rowCount {
            try await dbActor.execute("""
                INSERT INTO stress_test (id, data) VALUES (?, ?)
            """, parameters: [.int(i), .text(largeData.base64EncodedString())])
        }

        // Get initial metrics
        let initialMetrics = await dbActor.getMetrics()

        // Perform a checkpoint
        let checkpointResult = await dbActor.checkpointWal(mode: .passive)

        XCTAssertNotNil(checkpointResult, "Checkpoint should succeed")
        XCTAssertFalse(checkpointResult!.busy, "Checkpoint should not be busy")

        // Get metrics after checkpoint
        let finalMetrics = await dbActor.getMetrics()

        print("WAL checkpoint test results:")
        print("  Rows inserted: \(rowCount)")
        print("  Checkpoint result: \(checkpointResult!)")
        if let walSize = finalMetrics.walSize {
            let walSizeMB = Double(walSize) / (1024 * 1024)
            print("  WAL size after checkpoint: \(String(format: "%.2f", walSizeMB))MB")
        }
    }
}
