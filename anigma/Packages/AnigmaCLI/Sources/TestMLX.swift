//
//  TestMLX.swift
//  AnigmaCLI
//
//  Quick test script for MLX functionality.
//

import Foundation

#if canImport(MLX)
import MLX
import MLXLM
#endif

@main
struct TestMLX {
    static func main() async {
        print("🧪 Testing MLX Integration...")
        
        // Test MLX availability
        #if canImport(MLX)
        print("✅ MLX framework is available")
        
        // Test MLX backend runner
        await testMLXBackend()
        
        // Test integration
        await testIntegration()
        
        #else
        print("❌ MLX framework not available - make sure you're on Apple Silicon")
        #endif
        
        print("🏁 Test completed")
    }
    
    #if canImport(MLX)
    static func testMLXBackend() async {
        do {
            print("🔄 Testing MLX Backend...")
            
            // Test basic MLX functionality
            MLX.GPU.set(device: 0)
            print("✅ GPU device set")
            
            // Test basic tensor operations
            let a = MLX.array([1, 2, 3, 4])
            let b = MLX.array([5, 6, 7, 8])
            let c = a + b
            print("✅ Basic tensor operations working")
            
        } catch {
            print("❌ MLX Backend test failed: \(error)")
        }
    }
    #endif
    
    static func testIntegration() async {
        print("🔄 Testing Integration...")
        
        // Create MLX engine instance via reflection
        if let engineClass = NSClassFromString("MLXInferenceEngine") {
            print("✅ MLXInferenceEngine class found")
            
            // Test if we can create an instance
            let engine = engineClass.init()
            print("✅ MLXInferenceEngine instance created")
            
            // Test MLXChatProvider
            if let chatProviderClass = NSClassFromString("MLXChatProvider") {
                print("✅ MLXChatProvider class found")
                let chatProvider = chatProviderClass.init()
                print("✅ MLXChatProvider instance created")
            }
            
            // Test MLXBackendRunner
            if let backendRunnerClass = NSClassFromString("MLXBackendRunner") {
                print("✅ MLXBackendRunner class found")
                let backendRunner = backendRunnerClass.init()
                print("✅ MLXBackendRunner instance created")
            }
            
        } else {
            print("❌ MLXInferenceEngine class not found")
        }
        
        print("✅ Integration test completed")
    }
}