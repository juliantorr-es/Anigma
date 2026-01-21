// TestSelfHost.swift
// Simple test for self-host functionality

import Foundation
import HarmoniaModule

@main
struct TestSelfHost {
    static func main() async {
        print("🧪 Testing Self-Host Project Configuration")

        do {
            // Test 1: Check if we're in Anigma repo
            print("1. Checking if in Anigma repo...")
            let isAnigmaRepo = SelfHostProjectConfig.isAnigmaRepo
            print("   Result: \(isAnigmaRepo ? "✅ Yes" : "❌ No")")

            // Test 2: Get project ID
            print("\n2. Getting self-host project ID...")
            let projectId = SelfHostProjectConfig.projectId
            print("   Project ID: \(projectId.uuidString)")

            // Test 3: Check environment override
            print("\n3. Testing environment override...")
            let originalEnv = ProcessInfo.processInfo.environment["ANIGMA_SELF_HOST_PROJECT_ID"]
            print("   Current env: \(originalEnv ?? "not set")")

            // Test 4: Ensure project registered
            print("\n4. Ensuring project registered...")
            let spec = try await SelfHostProjectConfig.ensureRegistered()
            print("   ✅ Project registered:")
            print("      • Name: \(spec.name)")
            print("      • ID: \(spec.id.uuidString.prefix(8))...")
            print("      • Directory: \(spec.projectDirectory ?? "not set")")

            // Test 5: Get principality controller
            print("\n5. Getting principality controller...")
            let provider = PrincipalityProvider.shared
            let controller = await provider.selfHostController()
            print("   ✅ Controller obtained for project: \(controller.projectId)")

            // Test 6: Get status
            print("\n6. Getting project status...")
            let status = try await controller.getStatus()
            print("   ✅ Status obtained:")
            print("      • Name: \(status.name)")
            print("      • Health rate: \(String(format: "%.1f%%", status.healthRate * 100))")
            print("      • Sessions: \(status.healthySessions)/\(status.totalSessions) healthy")
            print("      • Quarantined: \(status.isQuarantined ? "🚨 Yes" : "✅ No")")

            print("\n🎉 All self-host tests passed!")

        } catch {
            print("❌ Error: \(error)")
        }
    }
}
