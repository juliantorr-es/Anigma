//
//  WorkBoardMCPBridgeTests.swift
//  PragmaModuleTests
//
//  Tests/PragmaModuleTests
//
//  Tests for the WorkBoard MCP bridge.
//

import ContractsCore
import XCTest

@testable import AnigmaCore
@testable import PragmaModule

final class WorkBoardMCPBridgeTests: XCTestCase {
    private var world: World!
    private var governance: GovernanceController!
    private var workService: WorkService!
    private var workBoardService: WorkBoardService!
    private var bridge: WorkBoardMCPBridge!

    override func setUp() async throws {
        world = World()
        governance = GovernanceController()
        await governance.initialize()
        await governance.setMode(.autopilot, by: "tester")
        workService = WorkService(world: world, governance: governance)
        workBoardService = WorkBoardService(
            world: world, workService: workService, governance: governance)
        bridge = WorkBoardMCPBridge(workBoard: workBoardService)
    }

    func testSnapshotToolUsesSessionBinding() async throws {
        let project = try await workService.createProject(
            keyPrefix: "MCP",
            name: "MCP Project",
            leadId: "tester",
            principal: "tester"
        )
        let scope = WorkBoardScope(projectId: project.project.id)
        let scopeData = try JSONEncoder().encode(scope)
        let scopeJson = String(decoding: scopeData, as: UTF8.self)

        let session = WorkBoardMCPSession(
            sessionId: "session-1",
            surfaceId: SurfaceId.generate(),
            actorId: ActorId(rawValue: "tester"),
            trustTier: .bronze,
            securityZone: .selfHost
        )

        let response = try await bridge.handle(
            tool: "work_board.snapshot",
            arguments: ["scope": scopeJson],
            session: session
        )

        let decoded = try JSONDecoder().decode(WorkBoardSnapshot.self, from: Data(response.utf8))
        XCTAssertEqual(decoded.scope.projectId, project.project.id)
    }

    func testMutationRequiresActorMatch() async throws {
        let project = try await workService.createProject(
            keyPrefix: "MCP",
            name: "MCP Project",
            leadId: "tester",
            principal: "tester"
        )

        let session = WorkBoardMCPSession(
            sessionId: "session-1",
            surfaceId: SurfaceId.generate(),
            actorId: ActorId(rawValue: "tester"),
            trustTier: .bronze,
            securityZone: .selfHost
        )

        await XCTAssertThrowsErrorAsync(
            try await self.bridge.handle(
                tool: "work_board.create_task",
                arguments: [
                    "actorId": "other",
                    "capabilityToken": "token",
                    "irSnapshotId": "snapshot",
                    "projectId": project.project.id.raw.uuidString,
                    "title": "Task"
                ],
                session: session
            )
        ) { error in
            guard case MCPBridgeError.accessDenied = error else {
                XCTFail("Expected accessDenied error")
                return
            }
        }
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
