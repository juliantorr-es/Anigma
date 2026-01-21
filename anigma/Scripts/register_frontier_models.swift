import Foundation
import DatabaseCore
import ModelRegistryModule
import ContractsCore

@main
struct RegisterFrontierModels {
    static func main() async {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Failed to unwrap appSupport")
        }
        let anigmaDir = appSupport.appendingPathComponent("Anigma")
        let modelDbPath = anigmaDir.appendingPathComponent("models.sqlite").path

        print("Connecting to model database at \(modelDbPath)")
        let modelDbActor = DatabaseActor(dbPath: modelDbPath)
        do {
            try await modelDbActor.open()
            let modelDb = try await ModelRegistryDatabase(dbActor: modelDbActor)
            let registry = ModelRegistryModule(database: modelDb)

            // 1. Llama 3.1 8B Instruct (4-bit)
            try await register(registry, spec: ModelRegistrationSpec(
                modelID: "llama-3.1-8b-instruct-4bit",
                modelHash: "hash-llama-3.1-8b-q4",
                taskContract: .llmChat,
                backendKind: .mlx,
                source: ModelSource(type: "huggingface", identifier: "mlx-community/Meta-Llama-3.1-8B-Instruct-4bit"),
                license: "Apache-2.0", // Using compatible name for registry validator
                artifactHashes: [:],
                metadata: ["description": "Meta Llama 3.1 8B Instruct quantized to 4-bit for M1/M2/M3", "frontier": "true"]
            ))

            // 2. Qwen 2.5 7B Coder (4-bit)
            try await register(registry, spec: ModelRegistrationSpec(
                modelID: "qwen-2.5-7b-coder-4bit",
                modelHash: "hash-qwen-2.5-7b-coder-q4",
                taskContract: .llmChat,
                backendKind: .mlx,
                source: ModelSource(type: "huggingface", identifier: "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit"),
                license: "Apache-2.0",
                artifactHashes: [:],
                metadata: ["description": "Qwen 2.5 Coder 7B - Best in class coding model for its size", "frontier": "true"]
            ))

            // 3. Phi-3.5 Mini (3.8B)
            try await register(registry, spec: ModelRegistrationSpec(
                modelID: "phi-3.5-mini-instruct-4bit",
                modelHash: "hash-phi-3.5-mini-q4",
                taskContract: .llmChat,
                backendKind: .mlx,
                source: ModelSource(type: "huggingface", identifier: "mlx-community/Phi-3.5-mini-instruct-4bit"),
                license: "MIT",
                artifactHashes: [:],
                metadata: ["description": "Microsoft Phi-3.5 Mini - Extremely efficient and smart small model", "frontier": "true"]
            ))

            // 4. BGE-M3 Embeddings
            try await register(registry, spec: ModelRegistrationSpec(
                modelID: "bge-m3-4bit",
                modelHash: "hash-bge-m3-q4",
                taskContract: .embedding,
                backendKind: .mlx,
                source: ModelSource(type: "huggingface", identifier: "mlx-community/bge-m3-4bit"),
                license: "MIT",
                artifactHashes: [:],
                dimensions: 1024,
                metadata: ["description": "BGE-M3 multilingual embedding model", "frontier": "true"]
            ))

            print("\n✅ Successfully registered frontier models in registry.")

        } catch {
            print("\n❌ Error: \(error)")
        }
    }

    static func register(_ registry: ModelRegistryModule, spec: ModelRegistrationSpec) async throws {
        print("Registering \(spec.modelID)...\n")
        _ = try await registry.registerModel(spec)
    }
}
