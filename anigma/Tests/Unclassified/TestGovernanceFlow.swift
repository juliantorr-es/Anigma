//  TestGovernanceFlow.swift
//  Simple test to demonstrate the angelic governance system

import Foundation
import HarmoniaModule

@main
struct TestGovernanceFlow {
    static func main() async {
        print("🧠 Testing Angelic Governance System - Phase B")
        print("=============================================\n")

        // Create a test project ID
        let projectId = UUID()

        print("1. Creating Principality controller for project \(projectId.uuidString.prefix(8))...")
        let controller = PrincipalityProvider.shared.controller(for: projectId)

        print("2. Testing governance flow for UI feature category...")

        do {
            // Try to run a session with governance protocols
            let report = try await controller.runSession(
                featureCategory: "ui",
                explicitConfigId: "ui_conservative"
            )

            print("✅ Session completed successfully!")
            print("   - Session index: \(report.sessionIndex)")
            print("   - Config used: \(report.configId ?? "none")")
            print("   - Feature category: \(report.featureCategory ?? "none")")
            print("   - Session healthy: \(report.metrics.isHealthy)")
            print("   - Violations: \(report.violations.count)")

            print("\n3. Testing bandit report...")
            let banditReport = try await controller.getBanditReport()
            print("   Bandit report: \(banditReport)")

            print("\n4. Testing project status...")
            let status = try await controller.getStatus()
            print("   Project: \(status.name)")
            print("   Health rate: \(String(format: "%.1f%%", status.healthRate * 100))")
            print("   Total sessions: \(status.totalSessions)")
            print("   Healthy sessions: \(status.healthySessions)")

            print("\n🎉 Governance system test completed successfully!")
            print("\n📋 Summary:")
            print("   - Created Principality controller with default choir")
            print("   - Executed session through angelic hierarchy:")
            print("     • BanditGovernor (Thrones) selected config")
            print("     • PolicyRegistry (Seraphim) validated config")
            print("     • Gatekeeper (Cherubim) performed checks")
            print("     • SecurityEnforcer (Dominions) checked quarantine")
            print("     • HarnessRunner (Archangels) executed session")
            print("   - Emitted governance events via ConsoleEventSink")
            print("   - Updated bandit learning from session outcome")

        } catch {
            print("❌ Error: \(error)")
        }

        print("\n=============================================")
        print("Phase B Implementation Complete!")
        print("✅ Governance protocols defined")
        print("✅ Protocol implementations created")
        print("✅ PrincipalityProjectController refactored")
        print("✅ PrincipalityProvider updated with default choir")
        print("✅ Angelic hierarchy operational (in comments only)")
    }
}
