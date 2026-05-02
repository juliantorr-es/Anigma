import Testing
import Foundation
@testable import IntelligenceCore
import ContractsCore
import AnigmaCore

@Suite("Core ML Executor Tests")
struct CoreMLExecutorTests {

    @Test("Verify CoreMLExecutor respects Tier 1 TensorReference contracts and artifact storage")
    func testCoreMLInferenceWithArtifactStore() async throws {
        // 1. Set up in-memory artifact store
        let store = InMemoryPipelineArtifactStore()
        
        // Provide deterministic fixture input data
        let inputData = Data([0x01, 0x02, 0x03, 0x04])
        let inputHash = try await store.storeRaw(inputData, typeName: "tensor", preferredID: nil)
        
        // 2. Setup Executor
        let executor = CoreMLExecutor(artifactStore: store)
        
        // 3. Build Portable Tier 1 Contract Shapes
        let tensorRef = TensorReference(
            id: UUID().uuidString,
            shape: [1, 4],
            dataType: "float32",
            dataHash: inputHash
        )
        
        let inputDesc = ModelInputDescriptor(name: "image", tensor: tensorRef)
        
        let modelRef = ModelReference(
            id: "mnist-v1",
            modelHash: "abcdf12345",
            backendHint: "coreml"
        )
        
        let request = PortableInferenceRequest(
            requestId: "req-1234",
            model: modelRef,
            inputs: [inputDesc]
        )
        
        // 4. Execution
        let (bundle, receipt) = try await executor.execute(request: request)
        
        // 5. Verification
        
        // Output validity
        #expect(bundle.requestId == "req-1234")
        #expect(bundle.outputs.count == 1)
        
        let outputDesc = bundle.outputs[0]
        #expect(outputDesc.name == "var_6")
        #expect(outputDesc.tensor.shape == [1, 4])
        
        // Verify output was written to ArtifactStore
        let outputHash = outputDesc.tensor.dataHash
        let hasOutput = await store.contains(outputHash)
        #expect(hasOutput == true)
        
        // Verify Receipt (Telemetry / Provenance)
        #expect(receipt.backend == "CoreML")
        #expect(receipt.modelHash == "abcdf12345")
        #expect(receipt.executionTimeMs >= 0)
        
        // NeuralEngine is the backend result
        #expect(receipt.computeUnit == "NeuralEngine")
    }
}
