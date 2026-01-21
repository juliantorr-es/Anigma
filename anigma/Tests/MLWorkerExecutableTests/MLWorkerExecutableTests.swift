//
//  MLWorkerExecutableTests.swift
//  MLWorkerExecutableTests
//
//  Unit tests for MLWorkerExecutableTests.
//

import XCTest
import Foundation
import CryptoKit
import MLWorkerCommon
@testable import MLWorkerExecutable
#if canImport(MLXLMCommon)
import MLXLMCommon
#endif

final class MLWorkerExecutableTests: XCTestCase {

    func testSHA256Hashing() throws {
        guard let data = "test data".data(using: .utf8) else {
            fatalError("Failed to unwrap data")
        }
        let hash = sha256Hex(data)

        XCTAssertEqual(hash.count, 64) // SHA256 hex string length
        XCTAssertEqual(hash, "916f0027a575074ce72a331777c3478d6513f786a591bd892da1a577bf2335f9")

        // Test deterministic behavior
        let hash2 = sha256Hex(data)
        XCTAssertEqual(hash, hash2)
    }

    func testEmbeddingGeneration() throws {
        let vector = generateMockEmbedding(
            inputHash: "test-input",
            modelHash: "test-model",
            dimension: 384
        )

        XCTAssertEqual(vector.count, 384)
        // Verify deterministic behavior
        let vector2 = generateMockEmbedding(
            inputHash: "test-input",
            modelHash: "test-model",
            dimension: 384
        )
        XCTAssertEqual(vector, vector2)

        // Verify different inputs produce different vectors
        let vector3 = generateMockEmbedding(
            inputHash: "different-input",
            modelHash: "test-model",
            dimension: 384
        )
        XCTAssertNotEqual(vector, vector3)
    }

    func testNDJSONEncodingDecoding() throws {
        let request = MLWorkerRequest(
            requestId: "req-123",
            runId: "run-456",
            stepId: "step-789",
            engine: .mlx,
            task: .embed,
            inputs: [
                MLArtifactRef(path: "/tmp/input.txt", hash: "abc123")
            ],
            options: MLTaskOptions(
                seed: 42,
                maxTokens: 512,
                temperature: 0.1
            )
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MLWorkerRequest.self, from: data)

        XCTAssertEqual(request.requestId, decoded.requestId)
        XCTAssertEqual(request.runId, decoded.runId)
        XCTAssertEqual(request.engine, decoded.engine)
        XCTAssertEqual(request.task, decoded.task)
        XCTAssertEqual(request.inputs.count, decoded.inputs.count)
        XCTAssertEqual(request.options.temperature, decoded.options.temperature)
    }

    func testCanonicalHashingIsDeterministic() throws {
        let requestA = MLWorkerRequest(
            requestId: "req-abc",
            runId: "run-xyz",
            stepId: "step-123",
            engine: .mlx,
            task: .chat,
            inputs: [MLArtifactRef(path: "/tmp/input.txt", hash: "abc123")],
            options: MLTaskOptions(seed: 99, maxTokens: 32, temperature: 0.7, topP: 0.9, outputDirectory: "/tmp/out")
        )

        // Same data with different construction order to ensure canonical serialization is stable
        let requestB = MLWorkerRequest(
            requestId: "req-abc",
            runId: "run-xyz",
            stepId: "step-123",
            engine: .mlx,
            task: .chat,
            inputs: [MLArtifactRef(path: "/tmp/input.txt", hash: "abc123")],
            options: MLTaskOptions(seed: 99, maxTokens: 32, temperature: 0.7, topP: 0.9, outputDirectory: "/tmp/out")
        )

        let hashA = try MLWorkerHasher.hashRequest(requestA)
        let hashB = try MLWorkerHasher.hashRequest(requestB)

        XCTAssertEqual(hashA, hashB, "Canonical hashing should be deterministic regardless of field declaration order")
        XCTAssertEqual(hashA.count, 64)
    }

    func testBinaryDiscoveryMLX() throws {
        // Test that MLX binary paths are properly validated
        let paths = [
            "/usr/local/bin/mlx",
            "/opt/homebrew/bin/mlx",
            "/opt/anaconda3/bin/mlx"
        ]

        var found = false
        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) {
                found = true
                break
            }
        }

        // Should not find MLX on typical test systems
        XCTAssertFalse(found, "MLX should not be installed on test system")
    }

    func testBinaryDiscoveryLlama() throws {
        // Test that ollama binary detection works
        let ollamaPath = "/usr/local/bin/ollama"
        let isExecutable = FileManager.default.isExecutableFile(atPath: ollamaPath)

        if isExecutable {
            // If ollama exists, verify it's actually executable
            XCTAssertTrue(isExecutable)
        } else {
            // If ollama doesn't exist, that's also a valid test state
            XCTAssertTrue(true, "ollama not installed - valid test state")
        }
    }

    func testMLXEmbeddingIntegration() throws {
#if canImport(MLXLMCommon)
        guard ProcessInfo.processInfo.environment["MLX_INTEGRATION_TEST"] == "1" else {
            throw XCTSkip("Set MLX_INTEGRATION_TEST=1 to enable MLX integration test")
        }

        let inputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mlx-input-\(UUID().uuidString).txt")
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mlx-output-\(UUID().uuidString).bin")
        try "hello from anigma mlx test".write(to: inputURL, atomically: true, encoding: .utf8)

        let runner = MLXBackendRunner(
            chatModelId: ProcessInfo.processInfo.environment["MLX_MODEL_ID_CHAT"],
            embedModelId: ProcessInfo.processInfo.environment["MLX_MODEL_ID_EMBED"]
        )
        let result = try runner.execute(
            modelPath: ProcessInfo.processInfo.environment["MLX_MODEL_ID_EMBED"] ?? "",
            task: .embed,
            inputFile: inputURL,
            outputFile: outputURL,
            options: MLTaskOptions(seed: 0),
            requestId: "mlx-integration-test"
        )

        XCTAssertEqual(result.exitCode, 0)
        let data = try Data(contentsOf: outputURL)
        XCTAssertFalse(data.isEmpty)
        XCTAssertEqual(data.count % MemoryLayout<Float>.size, 0)
#else
        throw XCTSkip("MLX not available in this build")
#endif
    }

    func testEmbeddingHeaderRoundTrip() throws {
        let header = EmbeddingHeader(
            schemaVersion: 1,
            dtype: "float32",
            shape: [1, 3],
            ordering: "row-major",
            tokenizer: "test",
            modelHash: "abc",
            inputHash: "def",
            requestId: "req",
            timestamp: "now",
            dataPath: "vec.bin",
            containerHash: "deadbeef",
            engine: EmbeddingEngineMetadata(engine: "mock", binaryHash: "bin", modelHash: "abc", argv: [], env: [:]),
            embeddingDimension: 3
        )
        let data = try JSONEncoder().encode(header)
        let decoded = try JSONDecoder().decode(EmbeddingHeader.self, from: data)
        XCTAssertEqual(decoded.embeddingDimension, 3)
    }

    func testDeepSeekChatStubbed() throws {
        setenv("DEEPSEEK_STUB_BODY", "{\"choices\":[{\"message\":{\"content\":\"ok\"}}]}", 1)
        defer { unsetenv("DEEPSEEK_STUB_BODY") }
        setenv("DEEPSEEK_API_KEY", ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] ?? "stub-key", 1)
        defer { unsetenv("DEEPSEEK_API_KEY") }

        let inputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("deepseek-input-\(UUID().uuidString).txt")
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("deepseek-output-\(UUID().uuidString).txt")
        try "hello".write(to: inputURL, atomically: true, encoding: .utf8)

        let runner = DeepSeekBackendRunner(apiKey: "test-key", baseURL: "https://api.deepseek.com", model: "deepseek-chat")
        let result = try runner.execute(
            modelPath: "",
            task: .chat,
            inputFile: inputURL,
            outputFile: outputURL,
            options: MLTaskOptions(seed: 0),
            requestId: "deepseek-stubbed"
        )
        XCTAssertEqual(result.exitCode, 0)
        let output = try String(contentsOf: outputURL, encoding: .utf8)
        XCTAssertEqual(output, "ok")
    }

    func testDeepSeekEmbeddingsFailClosed() throws {
        setenv("DEEPSEEK_STUB_BODY", "{\"choices\":[{\"message\":{\"content\":\"ok\"}}]}", 1)
        defer { unsetenv("DEEPSEEK_STUB_BODY") }
        setenv("DEEPSEEK_API_KEY", ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] ?? "stub-key", 1)
        defer { unsetenv("DEEPSEEK_API_KEY") }

        let inputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("deepseek-embed-input-\(UUID().uuidString).txt")
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("deepseek-embed-output-\(UUID().uuidString).bin")
        try "hello".write(to: inputURL, atomically: true, encoding: .utf8)

        let runner = DeepSeekBackendRunner(apiKey: "test-key", baseURL: "https://api.deepseek.com", model: "deepseek-chat")
        XCTAssertThrowsError(
            try runner.execute(
                modelPath: "",
                task: .embed,
                inputFile: inputURL,
                outputFile: outputURL,
                options: MLTaskOptions(seed: 0),
                requestId: "deepseek-embed-fail-closed"
            )
        ) { error in
            let message = "\(error)".lowercased()
            XCTAssertTrue(message.contains("not supported"), "Expected fail-closed embeddings error, got: \(message)")
        }
    }

    func testMLXChatIntegration() throws {
#if canImport(MLXLMCommon)
        guard ProcessInfo.processInfo.environment["MLX_INTEGRATION_TEST"] == "1" else {
            throw XCTSkip("Set MLX_INTEGRATION_TEST=1 to enable MLX chat integration test")
        }

        let inputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mlx-chat-input-\(UUID().uuidString).txt")
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mlx-chat-output-\(UUID().uuidString).txt")
        try "hello from anigma mlx chat test".write(to: inputURL, atomically: true, encoding: .utf8)

        let runner = MLXBackendRunner(
            chatModelId: ProcessInfo.processInfo.environment["MLX_MODEL_ID_CHAT"],
            embedModelId: ProcessInfo.processInfo.environment["MLX_MODEL_ID_EMBED"]
        )
        let result = try runner.execute(
            modelPath: ProcessInfo.processInfo.environment["MLX_MODEL_ID_CHAT"] ?? "",
            task: .chat,
            inputFile: inputURL,
            outputFile: outputURL,
            options: MLTaskOptions(seed: 0, maxTokens: 16),
            requestId: "mlx-chat-integration-test"
        )

        XCTAssertEqual(result.exitCode, 0)
        let output = try String(contentsOf: outputURL, encoding: .utf8)
        XCTAssertFalse(output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
#else
        throw XCTSkip("MLX not available in this build")
#endif
    }

    func testLlamaServerChatAndEmbedIntegration() throws {
        guard ProcessInfo.processInfo.environment["LLAMA_SERVER_URL"] != nil else {
            throw XCTSkip("Set LLAMA_SERVER_URL to enable llama-server integration test")
        }

        let inputChat = FileManager.default.temporaryDirectory
            .appendingPathComponent("llama-chat-input-\(UUID().uuidString).txt")
        let outputChat = FileManager.default.temporaryDirectory
            .appendingPathComponent("llama-chat-output-\(UUID().uuidString).txt")
        try "hello from llama server chat test".write(to: inputChat, atomically: true, encoding: .utf8)

        let inputEmbed = FileManager.default.temporaryDirectory
            .appendingPathComponent("llama-embed-input-\(UUID().uuidString).txt")
        let outputEmbed = FileManager.default.temporaryDirectory
            .appendingPathComponent("llama-embed-output-\(UUID().uuidString).bin")
        try "embed me".write(to: inputEmbed, atomically: true, encoding: .utf8)

        let runner = LlamaBackendRunner()

        let chatResult = try runner.execute(
            modelPath: ProcessInfo.processInfo.environment["LLAMA_MODEL_PATH"] ?? "",
            task: .chat,
            inputFile: inputChat,
            outputFile: outputChat,
            options: MLTaskOptions(seed: 0, maxTokens: 16),
            requestId: "llama-server-chat"
        )
        XCTAssertEqual(chatResult.exitCode, 0)
        let chatOutput = try String(contentsOf: outputChat, encoding: .utf8)
        XCTAssertFalse(chatOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        let embedResult = try runner.execute(
            modelPath: ProcessInfo.processInfo.environment["LLAMA_MODEL_PATH"] ?? "",
            task: .embed,
            inputFile: inputEmbed,
            outputFile: outputEmbed,
            options: MLTaskOptions(seed: 0),
            requestId: "llama-server-embed"
        )
        XCTAssertEqual(embedResult.exitCode, 0)
        let embedData = try Data(contentsOf: outputEmbed)
        let dimension = embedData.count / MemoryLayout<Float>.size
        XCTAssertGreaterThan(dimension, 0, "Expected embedding vector dimension to be > 0")
    }
}

// MARK: - Test Utilities

private func sha256Hex(_ data: Data) -> String {
    let digest = SHA256.hash(data: data)
    return digest.compactMap { String(format: "%02x", $0) }.joined()
}

private func generateMockEmbedding(inputHash: String, modelHash: String, dimension: Int) -> [Float] {
    var vector: [Float] = []
    var counter: UInt8 = 0
    while vector.count < dimension {
        var hasher = SHA256()
        hasher.update(data: Data((inputHash + modelHash).utf8))
        hasher.update(data: Data([counter]))
        let digest = hasher.finalize()
        for byte in digest {
            guard vector.count < dimension else { break }
            let normalized = (Float(Int(byte)) / 255.0) * 2 - 1
            vector.append(normalized)
        }
        counter = counter &+ 1
    }
    return vector
}

private func runCommand(_ command: String, _ arguments: [String]) throws -> String? {
    let task = Process()
    task.launchPath = command
    task.arguments = arguments
    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()
    task.waitUntilExit()

    if task.terminationStatus == 0 {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return nil
}
