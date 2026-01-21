import XCTest
import AnigmaCore
import AnigmaSystemSpine
import DataCore
import DataEngine
@testable import AnigmaAgents

final class AgentTests: XCTestCase {

    struct MockAgent: Agent {
        let id = "mock-agent"
        let name = "Mock Agent"
        let description = "Agent for testing"
        let capabilities: [AgentCapability] = [.dataAnalysis]

        func execute(instruction: String, context: AgentContext) async throws -> AgentResult {
            return AgentResult(
                output: "Done",
                artifacts: [],
                receipt: Receipt(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    actor: "mock-agent",
                    action: "none",
                    status: .success,
                    details: [:]
                )
            )
        }
    }

    func testMockAgentExecution() async throws {
        let agent = MockAgent()
        let jobEngine = JobEngine()
        let dataEngine = DataEngine()
        let context = AgentContext(
            workspaceId: UUID(),
            sessionId: "test-session",
            jobEngine: jobEngine,
            dataEngine: dataEngine
        )

        let result = try await agent.execute(instruction: "Test", context: context)
        XCTAssertEqual(result.output, "Done")
        XCTAssertEqual(result.receipt.actor, "mock-agent")
    }
}
