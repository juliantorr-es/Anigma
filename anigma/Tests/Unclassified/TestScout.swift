// TestScout.swift
// Simple test to verify scout infrastructure

import Foundation
import HarmoniaModule

@main
struct TestScout {
    static func main() async throws {
        print("🧪 Testing scout infrastructure...")

        // Initialize store
        let store = ProjectHarnessStore.shared
        try store.initialize()

        // Get self-host project ID
        let projectId = SelfHostProjectConfig.projectId
        print("Project ID: \(projectId)")

        // Create principality controller
        let controller = await PrincipalityProvider.shared.controller(for: projectId)

        // Test 1: Run Swift 6 scout
        print("\n🔍 Test 1: Running Swift 6 scout...")
        do {
            let summary = try await controller.runSwift6Scout()
            print("✅ Scout completed!")
            print("   Total findings: \(summary.totalFindings)")
            print("   Tasks created: \(summary.tasksCreated)")

            for (severity, count) in summary.findingsBySeverity {
                print("   \(severity.rawValue.capitalized): \(count)")
            }
        } catch {
            print("❌ Scout failed: \(error)")
        }

        // Test 2: List pending tasks
        print("\n📋 Test 2: Listing pending tasks...")
        do {
            let tasks = try await controller.listPendingMigrationTasks()
            print("✅ Found \(tasks.count) pending tasks")

            for task in tasks {
                print("   - \(task.featureCategory) (priority: \(task.priority))")
            }
        } catch {
            print("❌ Failed to list tasks: \(error)")
        }

        // Test 3: List scout findings
        print("\n🔍 Test 3: Listing scout findings...")
        do {
            let findings = try await controller.listScoutFindings()
            print("✅ Found \(findings.count) findings")

            for finding in findings.prefix(3) {
                print("   - \(finding.problemKind) in \(finding.filePath)")
            }

            if findings.count > 3 {
                print("   ... and \(findings.count - 3) more")
            }
        } catch {
            print("❌ Failed to list findings: \(error)")
        }

        print("\n🎯 Scout infrastructure test complete!")
    }
}
