import ArgumentParser
import Foundation
import HarmoniaRuntime

struct HarmoniaStatusCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "status",
            abstract: "Check the HarmoniaRuntime health/status gate."
        )
    }

    mutating func run() async throws {
        let status = HarmoniaRuntime.status()

        print("🩺 HarmoniaRuntime status")
        print("   Health: \(status.health.rawValue)")
        print("   Summary: \(status.summary)")
        print("   Query/session: \(status.querySession.rawValue)")
        print("   Memory/context: \(status.memoryContext.rawValue)")
        print("   Receipts/observability: \(status.receiptsObservability.rawValue)")
        print("   Orchestration: \(status.orchestration.rawValue)")

        if !status.notes.isEmpty {
            print("   Notes:")
            for note in status.notes {
                print("     - \(note)")
            }
        }
    }
}
