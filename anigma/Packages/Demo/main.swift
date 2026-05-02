//
//  main.swift
//  Demo
//
//  Demo Module
//
//  Entry point for running happy path demo.
//

import AnigmaCore
import Foundation

@main
struct DemoMain {
    static func main() async throws {
        print("🎬 Anigma Export Job Ticket - Happy Path Demo")
        print("=" + String(repeating: "=", count: 49))

        // Initialize world and work directory
        let world = World()
        let workDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("AnigmaDemo")

        // Create and run happy path demo
        let demo = HappyPathDemo(world: world, workDirectory: workDirectory)

        do {
            let report = try await demo.runDemo()

            print("\n" + "=" + String(repeating: "=", count: 49))
            print("🎊 Demo Summary:")
            print("✅ Success: \(report.successful)")
            print("⏱️ Duration: \(String(format: "%.1f", report.totalDuration))s")
            print("📊 Checkpoints: \(report.checkpoints.count)")

            if report.successful {
                print("🎯 Target achieved! Franklin can now showcase complete pipeline.")
            } else {
                print("⚠️ Demo exceeded target time.")
            }

        } catch {
            print("❌ Demo failed: \(error)")
            exit(1)
        }
    }
}
