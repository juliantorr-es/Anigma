import Foundation
import AnigmaCore
import HarmoniaModule

// Simple test runner
print("🧪 Running harness test...")

do {
    try await SimpleHarnessTest.runTest()
    print("✅ Harness test completed successfully!")
} catch {
    print("❌ Harness test failed: \(error)")
    exit(1)
}
