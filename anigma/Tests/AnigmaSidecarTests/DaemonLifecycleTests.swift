//
//  DaemonLifecycleTests.swift
//  AnigmaSidecarTests
//
//  Tests for daemon lifecycle management functionality.
//

import XCTest

@testable import AnigmaSidecar

final class DaemonLifecycleTests: XCTestCase {

    func testDaemonStartAndStop() async throws {
        // This test requires the anigmad binary to be built
        // Skip if binary doesn't exist
        let binaryPath = ".build/debug/anigmad"
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            throw XCTSkip("anigmad binary not found at \(binaryPath)")
        }

        // Start daemon
        let handle = try await DaemonLifecycle.start(
            socketPath: "/tmp/test-anigmad-\(UUID().uuidString).sock"
        )

        // Verify it's running
        let status = await DaemonLifecycle.status(socketPath: handle.socketPath)
        if case .running = status {
            XCTAssertTrue(true, "Daemon is running")
        } else {
            XCTFail("Daemon should be running, got: \(status.description)")
        }

        // Stop daemon
        try await DaemonLifecycle.stop(handle: handle)

        // Verify it's stopped
        let stoppedStatus = await DaemonLifecycle.status(socketPath: handle.socketPath)
        XCTAssertEqual(stoppedStatus.description, "Stopped")
    }

    func testDaemonRestart() async throws {
        let binaryPath = ".build/debug/anigmad"
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            throw XCTSkip("anigmad binary not found")
        }

        // Start daemon
        let handle1 = try await DaemonLifecycle.start(
            socketPath: "/tmp/test-anigmad-restart-\(UUID().uuidString).sock"
        )

        let pid1 = handle1.processId

        // Restart daemon
        let handle2 = try await DaemonLifecycle.restart(handle: handle1)

        let pid2 = handle2.processId

        // PIDs should be different (new process)
        XCTAssertNotEqual(pid1, pid2, "Restart should create new process")

        // Clean up
        try await DaemonLifecycle.stop(handle: handle2)
    }

    func testStatusWhenDaemonNotRunning() async {
        let status = await DaemonLifecycle.status(
            socketPath: "/tmp/nonexistent-\(UUID().uuidString).sock"
        )

        XCTAssertEqual(status.description, "Stopped")
    }

    func testCannotStartDaemonTwice() async throws {
        let binaryPath = ".build/debug/anigmad"
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            throw XCTSkip("anigmad binary not found")
        }

        let socketPath = "/tmp/test-anigmad-double-\(UUID().uuidString).sock"

        // Start daemon
        let handle = try await DaemonLifecycle.start(socketPath: socketPath)
        defer {
            Task {
                try? await DaemonLifecycle.stop(handle: handle)
            }
        }

        // Try to start again - should fail
        do {
            _ = try await DaemonLifecycle.start(socketPath: socketPath)
            XCTFail("Should not be able to start daemon twice on same socket")
        } catch let error as DaemonLifecycleError {
            if case .alreadyRunning = error {
                XCTAssertTrue(true, "Correctly detected already running daemon")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
}
