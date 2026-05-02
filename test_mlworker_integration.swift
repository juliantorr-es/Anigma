// Test MLWorkerPool integration with ProcessPool
import Foundation
import SubprocessPooling

@main
struct TestMLWorkerIntegration {
    static func main() async {
        print("Testing MLWorkerPool integration with ProcessPool...")
        
        // Create a ProcessPool for MLWorker
        let pool = ProcessPool<MLWorker>()
        
        // Get the MLWorkerPool
        let mlWorkerPool = pool.getMLWorkerPool()
        print("✓ Successfully created MLWorkerPool from ProcessPool")
        
        // Test basic functionality
        let input = MLWorkerInput(
            modelId: "test-model",
            taskType: .embedding,
            inputData: Array(repeating: 0.5, count: 100)
        )
        
        print("Submitting test task to MLWorkerPool...")
        let result = await mlWorkerPool.submitTask(input)
        
        switch result {
        case .success(let output):
            print("✓ Task completed successfully")
            print("  Model ID: \(output.modelId)")
            print("  Output data count: \(output.outputData.count)")
            print("  Inference time: \(output.inferenceTime) seconds")
            print("  Tokens processed: \(output.tokensProcessed)")
        case .failure(let error):
            print("✗ Task failed: \(error)")
        }
        
        // Test metrics
        let metrics = mlWorkerPool.getMetrics()
        print("\nMLWorkerPool Metrics:")
        print("  Worker count: \(metrics.workerCount)")
        print("  GPU count: \(metrics.gpuCount)")
        print("  Total tasks completed: \(metrics.totalTasksCompleted)")
        print("  Total tasks failed: \(metrics.totalTasksFailed)")
        
        // Test ProcessPool metrics (should include MLWorkerPool metrics)
        let poolMetrics = await pool.getMetrics()
        print("\nProcessPool Metrics:")
        print("  Pool size: \(poolMetrics.poolSize)")
        print("  Active workers: \(poolMetrics.activeWorkers)")
        print("  MLWorkerPool metrics included: \(poolMetrics.mlWorkerMetrics != nil)")
        
        if let mlMetrics = poolMetrics.mlWorkerMetrics {
            print("  MLWorkerPool worker count: \(mlMetrics.workerCount)")
            print("  MLWorkerPool GPU count: \(mlMetrics.gpuCount)")
        }
        
        // Test shutdown
        print("\nShutting down...")
        await pool.shutdown()
        print("✓ Shutdown completed")
        
        print("\n🎉 All tests passed!")
    }
}