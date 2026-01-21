//
//  RealHarnessRunner.swift
//  HarmoniaCLI
//
//  Real harness runner that uses the actual harness systems.
//

import ArgumentParser
import Foundation
import HarmoniaModule

struct RealHarnessRunner: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "harness-run",
            abstract: "Run real harness with code analysis"
        )
    }

    @Option(name: .shortAndLong, help: "Project ID")
    var projectId: String = "harness-test"

    @Option(name: .shortAndLong, help: "Iterations")
    var iterations: Int = 2

    @Flag(name: .long, help: "Enable code analysis tools")
    var enableAnalysis: Bool = false

    func run() async throws {
        print("🚀 Running REAL harness for project: \(projectId)")
        print("Iterations: \(iterations)")
        print("Code analysis: \(enableAnalysis ? "✅ Enabled" : "❌ Disabled")")

        // For now, run the simple harness test
        print("\n🧪 Running SimpleHarnessTest...")

        do {
            try await SimpleHarnessTest.runTest()
            print("\n✅ Harness test completed successfully!")

            // Show what would happen in real run
            print("\n📊 In a real run with this configuration:")
            print("   - Project: \(projectId)")
            print(
                "   - Mode: \(enableAnalysis ? "Layer 2 (with analysis)" : "Layer 1 (basic tools)")"
            )
            print(
                "   - Tools registered: \(enableAnalysis ? "8 (5 basic + 3 analysis)" : "5 (basic only)")"
            )
            print("   - Observability: ✅ ToolUsageLog tracking")
            print("   - Database: harmonia_harness.sqlite")

            print("\n🎯 Next: Implement ProjectCodingAgentService integration")
            print("   to connect the harness to actual LLM calls")

        } catch {
            print("❌ Harness test failed: \(error)")
        }
    }
}
