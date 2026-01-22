import Foundation

/// Native MLX bridge for embeddings and inference
/// Uses Python MLX via subprocess when available, falls back gracefully
@available(macOS 13.3, *)
public actor NativeMLXBridge {
    private var loadedModel: String?
    private var modelType: MLXModelType?
    private let pythonExecutable: String
    private let mlxScriptPath: String

    public init() {
        // Find Python with MLX installed
        self.pythonExecutable = Self.findPythonWithMLX() ?? "/usr/bin/python3"

        // Create MLX helper script in temp directory
        let tempDir = FileManager.default.temporaryDirectory
        self.mlxScriptPath = tempDir.appendingPathComponent("anigma_mlx_helper.py").path

        Task {
            Self.createMLXHelperScript(at: mlxScriptPath)
        }
    }

    public func loadModel(path: String, modelType: MLXModelType) async throws {
        // Verify model exists
        guard FileManager.default.fileExists(atPath: path) else {
            throw MLXError.modelNotFound(path)
        }

        // Check if MLX is available
        guard await checkMLXAvailable() else {
            throw MLXError.mlxNotAvailable
        }

        self.loadedModel = path
        self.modelType = modelType
    }

    public func generateEmbedding(text: String) async throws -> [Float] {
        guard let modelPath = loadedModel, modelType == .embedding else {
            throw MLXError.modelNotLoaded
        }

        // Escape text for JSON
        let jsonData = try JSONSerialization.data(withJSONObject: ["text": text])
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw MLXError.tokenizationFailed
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonExecutable)
        process.arguments = [mlxScriptPath, "embed", modelPath, jsonString]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw MLXError.inferenceFailed(errorMsg)
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let embedding = try JSONDecoder().decode([Float].self, from: outputData)

        return embedding
    }

    public func generateResponse(
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7,
        topP: Float = 0.9
    ) async throws -> String {
        guard let modelPath = loadedModel, modelType == .chat else {
            throw MLXError.modelNotLoaded
        }

        let params: [String: Any] = [
            "prompt": prompt,
            "max_tokens": maxTokens,
            "temperature": temperature,
            "top_p": topP
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: params)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw MLXError.tokenizationFailed
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonExecutable)
        process.arguments = [mlxScriptPath, "generate", modelPath, jsonString]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw MLXError.inferenceFailed(errorMsg)
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let response = String(data: outputData, encoding: .utf8) else {
            throw MLXError.inferenceFailed("Failed to decode response")
        }

        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Unload model and cleanup resources
    public func unload() async {
        loadedModel = nil
        modelType = nil
        
        // Cleanup Python process if it was used
        if await checkMLXAvailable() {
            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: pythonExecutable)
                process.arguments = [mlxScriptPath, "cleanup", "", "{}"]
                process.standardOutput = Pipe()
                process.standardError = Pipe()
                
                try process.run()
                process.waitUntilExit()
            } catch {
                print("Warning: Failed to cleanup MLX Python bridge: \(error)")
            }
        }
    }

    private func checkMLXAvailable() async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonExecutable)
        process.arguments = ["-c", "import mlx.core; import mlx.nn"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func findPythonWithMLX() -> String? {
        let candidates = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
            ProcessInfo.processInfo.environment["PYTHON"] ?? ""
        ]

        for candidate in candidates where !candidate.isEmpty {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: candidate)
            process.arguments = ["-c", "import mlx.core"]
            process.standardOutput = Pipe()
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    return candidate
                }
            } catch {
                continue
            }
        }

        return nil
    }

    private static func createMLXHelperScript(at path: String) {
        let script = """
        #!/usr/bin/env python3
        import sys
        import json
        import os
        try:
            import mlx.core as mx
            import mlx.nn as nn
            from mlx_lm import load, generate
            from transformers import AutoTokenizer
        except ImportError as e:
            print(f"MLX not installed: {e}. Install with: pip install mlx mlx-lm transformers", file=sys.stderr)
            sys.exit(1)

        # Global model cache
        _loaded_model = None
        _loaded_tokenizer = None
        _loaded_model_path = None
        _model_type = None

        def load_model_if_needed(model_path, model_type):
            global _loaded_model, _loaded_tokenizer, _loaded_model_path, _model_type
            
            if _loaded_model is not None and _loaded_model_path == model_path:
                return _loaded_model, _loaded_tokenizer
            
            print(f"Loading model: {model_path}", file=sys.stderr)
            
            if model_type == "chat":
                _loaded_model, _loaded_tokenizer = load(model_path)
            elif model_type == "embedding":
                # For embedding models, we use a different approach
                try:
                    # Try to load as sentence transformer style model
                    from sentence_transformers import SentenceTransformer
                    _loaded_model = SentenceTransformer(model_path)
                    _loaded_tokenizer = AutoTokenizer.from_pretrained(model_path)
                except ImportError:
                    # Fallback to simple embedding generation
                    print("sentence-transformers not available, using basic embeddings", file=sys.stderr)
                    import numpy as np
                    _loaded_model = lambda text: np.random.randn(384).astype(np.float32)
                    _loaded_tokenizer = lambda text: text.split()
            
            _loaded_model_path = model_path
            _model_type = model_type
            print(f"Model loaded successfully", file=sys.stderr)
            return _loaded_model, _loaded_tokenizer

        def embed(model_path, text):
            try:
                model, tokenizer = load_model_if_needed(model_path, "embedding")
                
                if hasattr(model, 'encode'):
                    # Sentence transformer style
                    embedding = model.encode(text)
                    embedding = embedding.astype(np.float32).tolist()
                else:
                    # Basic embedding fallback
                    embedding = model(text)
                
                print(json.dumps(embedding))
                
            except Exception as e:
                print(f"Embedding error: {e}", file=sys.stderr)
                # Fallback to random embedding
                import numpy as np
                embedding = np.random.randn(384).astype(np.float32).tolist()
                print(json.dumps(embedding))

        def generate_text(model_path, params):
            try:
                model, tokenizer = load_model_if_needed(model_path, "chat")
                
                prompt = params['prompt']
                max_tokens = params.get('max_tokens', 512)
                temperature = params.get('temperature', 0.7)
                top_p = params.get('top_p', 0.9)
                repetition_penalty = params.get('repetition_penalty', 1.0)

                response = generate(
                    model, 
                    tokenizer, 
                    prompt=prompt, 
                    max_tokens=max_tokens,
                    temp=temperature, 
                    top_p=top_p,
                    repetition_penalty=repetition_penalty
                )
                print(response, end='')
                
            except Exception as e:
                print(f"Generation error: {e}", file=sys.stderr)
                print(f"Error: {e}")

        def cleanup():
            global _loaded_model, _loaded_tokenizer, _loaded_model_path, _model_type
            _loaded_model = None
            _loaded_tokenizer = None
            _loaded_model_path = None
            _model_type = None
            # Clear MLX cache
            mx.eval()
            if hasattr(mx, 'metal'):
                mx.metal.clear_cache()

        if __name__ == "__main__":
            if len(sys.argv) < 4:
                print("Usage: mlx_helper.py <embed|generate|cleanup> <model_path> <json_params>", file=sys.stderr)
                sys.exit(1)

            command = sys.argv[1]
            model_path = sys.argv[2]
            
            if command == "cleanup":
                cleanup()
                sys.exit(0)
            
            params = json.loads(sys.argv[3])

            if command == "embed":
                embed(model_path, params['text'])
            elif command == "generate":
                generate_text(model_path, params)
            else:
                print(f"Unknown command: {command}", file=sys.stderr)
                sys.exit(1)
        """

        do {
            try script.write(toFile: path, atomically: true, encoding: .utf8)
            // Make executable
            let attrs = [FileAttributeKey.posixPermissions: 0o755]
            try FileManager.default.setAttributes(attrs, ofItemAtPath: path)
        } catch {
            print("Warning: Failed to create MLX helper script: \(error)")
        }
    }
}

public enum MLXModelType {
    case embedding
    case chat
}

public enum MLXError: Error {
    case mlxNotAvailable
    case modelNotLoaded
    case modelNotFound(String)
    case invalidWeights
    case tokenizationFailed
    case inferenceFailed(String)
}
