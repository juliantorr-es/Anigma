import Testing
import Foundation
import ContractsCore
import MediaPipelineContracts
@testable import MediaCore

actor Phase2InMemoryMediaArtifactStore: MediaArtifactStore {
    private struct StoredArtifact {
        let typeName: String
        let data: Data
    }

    private var storage: [String: StoredArtifact] = [:]

    func storeRaw(_ data: Data, typeName: String, preferredID: String?) async throws -> String {
        let id = preferredID ?? UUID().uuidString
        storage[id] = StoredArtifact(typeName: typeName, data: data)
        return id
    }

    func loadRaw(_ id: String) async throws -> (data: Data, typeName: String) {
        guard let artifact = storage[id] else {
            throw ValidationError.invalidRequest("Artifact \(id) not found")
        }
        return (artifact.data, artifact.typeName)
    }
}

@Suite("Phase 2: Apple-Native Backend Tests")
struct Phase2BackendTests {
    let surfaceAuthority: SurfaceAuthority
    let audioAuthority: AudioBufferAuthority
    let artifactStore: Phase2InMemoryMediaArtifactStore
    
    init() {
        self.surfaceAuthority = SurfaceAuthority()
        self.audioAuthority = AudioBufferAuthority()
        self.artifactStore = Phase2InMemoryMediaArtifactStore()
    }
    
    @Test("ImageIODecodeExecutor: Contract Execution")
    func testImageDecode() async throws {
        let fixtureURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/test.png")
            
        guard let data = try? Data(contentsOf: fixtureURL) else { return }
        
        let idString = try await artifactStore.storeRaw(data, typeName: "image/png", preferredID: UUID().uuidString)
        let id = UUID(uuidString: idString)!
        
        let executor = ImageIODecodeExecutor(surfaceAuthority: surfaceAuthority, artifactStore: artifactStore)
        let contract = ImageDecodeContract(artifactId: id, format: "png")
        
        let result = try await executor.execute(contract: contract)
        guard case .imageSurface(let imgRef) = result else {
            Issue.record("Expected MediaReference.imageSurface")
            return
        }
        
        #expect(imgRef.format == "png")
    }
    
    @Test("AudioToolboxDecodeExecutor: Contract Execution")
    func testAudioDecode() async throws {
        let fixtureURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/test.aac")
            
        guard let data = try? Data(contentsOf: fixtureURL) else { return }
        
        let idString = try await artifactStore.storeRaw(data, typeName: "audio/aac", preferredID: UUID().uuidString)
        let id = UUID(uuidString: idString)!
        
        let executor = AudioToolboxDecodeExecutor(audioAuthority: audioAuthority, artifactStore: artifactStore)
        let contract = AudioDecodeContract(artifactId: id, targetFormat: "float32")
        
        let result = try await executor.execute(contract: contract)
        guard case .audioBuffer(let audioRef) = result else {
            Issue.record("Expected MediaReference.audioBuffer")
            return
        }
        
        #expect(audioRef.sampleRate > 0)
        #expect(audioRef.channels > 0)
        #expect(audioRef.frameCount > 0)
    }
}
