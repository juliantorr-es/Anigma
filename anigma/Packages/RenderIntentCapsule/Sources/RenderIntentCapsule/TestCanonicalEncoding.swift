import Foundation

/// Simple test to verify canonical encoding works
@main
struct TestCanonicalEncoding {
    static func main() {
        print("Testing RenderIntentCapsule canonical encoding...")
        
        // Test 1: Bytes operations
        print("\n1. Testing Bytes operations:")
        let testValue: UInt64 = 0x0123456789ABCDEF
        var buffer = [UInt8](repeating: 0, count: MemoryLayout<UInt64>.size)
        
        buffer.withUnsafeMutableBytes { pointer in
            Bytes.copy(testValue, to: pointer.baseAddress!)
            let loaded = Bytes.load(from: pointer.baseAddress!, as: UInt64.self)
            print("   Copy/Load test: \(loaded == testValue ? "PASS" : "FAIL")")
        }
        
        // Test 2: IntentID
        print("\n2. Testing IntentID:")
        let id1 = IntentID(high: 0x0123456789ABCDEF, low: 0xFEDCBA9876543210)
        let id2 = IntentID(high: 0x0123456789ABCDEF, low: 0xFEDCBA9876543210)
        print("   Equality test: \(id1 == id2 ? "PASS" : "FAIL")")
        print("   Hex string: \(id1.hexString)")
        print("   Short hex: \(id1.shortHex)")
        
        // Test 3: StableHasher
        print("\n3. Testing StableHasher:")
        let hash1 = StableHasher.hash("Hello, World!")
        let hash2 = StableHasher.hash("Hello, World!")
        let hash3 = StableHasher.hash("Hello, World?")
        print("   Deterministic test: \(hash1 == hash2 ? "PASS" : "FAIL")")
        print("   Different input test: \(hash1 != hash3 ? "PASS" : "FAIL")")
        
        // Test 4: RenderIntent
        print("\n4. Testing RenderIntent:")
        let intent1 = RenderIntent.clear(color: SIMD4(1, 0, 0, 1))
        let intent2 = RenderIntent.clear(color: SIMD4(1, 0, 0, 1))
        print("   ID stability: \(intent1.id == intent2.id ? "PASS" : "FAIL")")
        print("   Type: \(intent1.type)")
        print("   ID: \(intent1.id)")
        
        // Test 5: CanvasTextIntentBuilder
        print("\n5. Testing CanvasTextIntentBuilder:")
        var builder = CanvasTextIntentBuilder(text: "Test")
            .position(SIMD2(10, 20))
            .fontSize(16)
            .color(SIMD4(0, 0, 0, 1))
        
        let textIntent = builder.build()
        print("   Builder test: \(textIntent.type == .drawText ? "PASS" : "FAIL")")
        
        print("\nAll tests completed!")
    }
}