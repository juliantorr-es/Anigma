//
//  WorkBoardServiceTests.swift
//  PragmaModuleTests
//
//  Tests/PragmaModuleTests
//
//  Tests for the WorkBoardService intent handling.
//

import ContractsCore
import XCTest

@testable import AnigmaCore
@testable import PragmaModule

final class WorkBoardServiceTests: XCTestCase {
    private var world: World!
    private var governance: GovernanceController!
    private var workService: WorkService!
    private var workBoardService: WorkBoardService!

    override func setUp() async throws {
        world = World()
        governance = GovernanceController()
        await governance.initialize()
        await governance.setMode(.autopilot, by: "test")
        workService = WorkService(world: world, governance: governance)
        workBoardService = WorkBoardService(
            world: world, workService: workService, governance: governance)
    }

    func testSnapshotPinningRejectsStaleIntent() async throws {
        let project = try await workService.createProject(
            keyPrefix: "TEST",
            name: "Work Board",
            leadId: "tester",
            principal: "tester"
        )

        let scope = WorkBoardScope(projectId: project.project.id)
        let snapshot1 = try await workBoardService.boardSnapshot(scope: scope, trustTier: .bronze)
        _ = try await workBoardService.boardSnapshot(scope: scope, trustTier: .bronze)

        let header = ActionIntent.Header(
            surfaceId: SurfaceId.generate(),
            actorId: ActorId(rawValue: "tester"),
            capabilityToken: "token",
            irSnapshotId: snapshot1.snapshotId
        )
        let intent = WorkBoardIntent(
            header: header,
            action: .createTask,
            parameters: [
                "projectId": .string(project.project.id.raw.uuidString),
                "title": .string("New Task"),
                "tags": .array([.string("workboard")])
            ]
        )

        await XCTAssertThrowsErrorAsync(try await self.workBoardService.submitIntent(intent)) {
            error in
            guard case WorkBoardError.staleSnapshot = error else {
                XCTFail("Expected staleSnapshot error")
                return
            }
        }
    }

    func testStartAttemptPopulatesRunningColumn() async throws {
        let project = try await workService.createProject(
            keyPrefix: "WB",
            name: "Work Board",
            leadId: "tester",
            principal: "tester"
        )
        let task = try await workService.createTask(
            projectId: project.entityId,
            title: "Attempt Task",
            reporterId: "tester",
            principal: "tester"
        )

        let scope = WorkBoardScope(projectId: project.project.id)
        let snapshot = try await workBoardService.boardSnapshot(scope: scope, trustTier: .bronze)

        let header = ActionIntent.Header(
            surfaceId: SurfaceId.generate(),
            actorId: ActorId(rawValue: "tester"),
            capabilityToken: "token",
            irSnapshotId: snapshot.snapshotId
        )
        let intent = WorkBoardIntent(
            header: header,
            action: .startAttempt,
            parameters: [
                "taskId": .string(task.task.id.raw.uuidString),
                "executorProfileId": .string("codex.default"),
                "baseRef": .string("main"),
                "baseCommit": .string("deadbeef"),
                "allowUnattendedExecution": .bool(false)
            ]
        )

        _ = try await workBoardService.submitIntent(intent)
        let updated = try await workBoardService.boardSnapshot(scope: scope, trustTier: .bronze)

        XCTAssertEqual(updated.attempts.count, 1)
        XCTAssertEqual(updated.attempts.first?.status, .running)
        let runningColumn = updated.columns.first { $0.status == .running }
        XCTAssertEqual(runningColumn?.attemptIds.count, 1)
        XCTAssertEqual(updated.attempts.first?.receipts.count, 1)
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure @escaping () async throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (Error) -> Void
) async {
    do {
        _ = try await expression()
        XCTFail(message(), file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
