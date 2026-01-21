//
//  ModelConversionPipeline.swift
//  ModelRegistry
//
//  Governed format conversion with full receipts.
//  Only supports formats that fit deterministic execution constraints.
//

import Foundation
import ContractsCore

/// Conversion pipeline for supported format transformations
public actor ModelConversionPipeline {
    private let workDir: URL
    private let registry: ModelRegistryProtocol

    public init(workDir: URL, registry: ModelRegistryProtocol) {
        self.workDir = workDir
        self.registry = registry
    }

    // MARK: - Supported Conversions

    /// Convert HuggingFace safetensors → MLX format (first-class path)
    public func convertToMLX(modelId: String, quantization: String? = nil) async throws -> ConversionReceipt {
        guard let entry = try await registry.find(id: modelId) else {
            throw ConversionError.modelNotFound(modelId)
        }

        // Verify source format is safetensors
        guard entry.spec.artifactHashes.keys.contains(where: { $0.hasSuffix(".safetensors") }) else {
            throw ConversionError.unsupportedSourceFormat("Not a safetensors model")
        }

        let startTime = Date()
        let outputDir = workDir.appendingPathComponent(modelId + "_mlx")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        // Build input hashes manifest
        var inputHashes: [String: String] = [:]
        for (file, hash) in entry.spec.artifactHashes where file.hasSuffix(".safetensors") {
            inputHashes[file] = hash
        }

        // Execute conversion via mlx-lm CLI (assumes installed separately)
        // This is a governed capability - execution tracked
        var conversionArgs = [
            "mlx_lm.convert",
            "--hf-path", entry.installPath,
            "--mlx-path", outputDir.path
        ]

        if let quant = quantization {
            conversionArgs.append(contentsOf: ["--quantize", quant])
        }

        let toolVersion = try await getMLXToolVersion()

        // Run conversion (synchronous for determinism)
        let result = try await executeConversion(args: conversionArgs)
        guard result.exitCode == 0 else {
            throw ConversionError.conversionFailed(result.stderr)
        }

        // Hash output artifacts
        var outputHashes: [String: String] = [:]
        let outputFiles = try FileManager.default.contentsOfDirectory(at: outputDir, includingPropertiesForKeys: nil)
        for file in outputFiles {
            let hash = try await computeFileSHA256(url: file)
            outputHashes[file.lastPathComponent] = hash
        }

        let receipt = ConversionReceipt(
            inputHashes: inputHashes,
            toolId: "mlx-lm",
            toolVersion: toolVersion,
            outputHashes: outputHashes,
            quantization: quantization,
            timestamp: startTime,
            metadata: [
                "duration_sec": String(Int(Date().timeIntervalSince(startTime))),
                "output_dir": outputDir.path
            ]
        )

        return receipt
    }

    /// Convert HuggingFace → GGUF (compatibility lane)
    public func convertToGGUF(modelId: String, quantization: String = "Q4_K_M") async throws -> ConversionReceipt {
        guard let entry = try await registry.find(id: modelId) else {
            throw ConversionError.modelNotFound(modelId)
        }

        let startTime = Date()
        let outputDir = workDir.appendingPathComponent(modelId + "_gguf")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        // Input hashes
        var inputHashes: [String: String] = [:]
        for (file, hash) in entry.spec.artifactHashes {
            inputHashes[file] = hash
        }

        // Use llama.cpp convert.py + quantize (assumes tools installed)
        let convertArgs = [
            "python3",
            "/usr/local/lib/llama.cpp/convert.py",
            entry.installPath,
            "--outfile", outputDir.appendingPathComponent("model.gguf").path,
            "--outtype", "f16"
        ]

        let convertResult = try await executeConversion(args: convertArgs)
        guard convertResult.exitCode == 0 else {
            throw ConversionError.conversionFailed(convertResult.stderr)
        }

        // Quantize
        let quantizeArgs = [
            "/usr/local/bin/quantize",
            outputDir.appendingPathComponent("model.gguf").path,
            outputDir.appendingPathComponent("model-\(quantization).gguf").path,
            quantization
        ]

        let quantResult = try await executeConversion(args: quantizeArgs)
        guard quantResult.exitCode == 0 else {
            throw ConversionError.conversionFailed(quantResult.stderr)
        }

        // Hash outputs
        let finalGGUF = outputDir.appendingPathComponent("model-\(quantization).gguf")
        let hash = try await computeFileSHA256(url: finalGGUF)
        let outputHashes = ["model-\(quantization).gguf": hash]

        let toolVersion = try await getLlamaCppVersion()

        return ConversionReceipt(
            inputHashes: inputHashes,
            toolId: "llama.cpp",
            toolVersion: toolVersion,
            outputHashes: outputHashes,
            quantization: quantization,
            timestamp: startTime,
            metadata: [
                "duration_sec": String(Int(Date().timeIntervalSince(startTime))),
                "output_file": finalGGUF.path
            ]
        )
    }

    // MARK: - Tool Version Detection

    private func getMLXToolVersion() async throws -> String {
        let result = try await executeCommand(args: ["python3", "-c", "import mlx_lm; print(mlx_lm.__version__)"])
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func getLlamaCppVersion() async throws -> String {
        let result = try await executeCommand(args: ["/usr/local/bin/quantize", "--version"])
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Execution Helpers

    private func executeConversion(args: [String]) async throws -> ProcessResult {
        return try await executeCommand(args: args)
    }

    private func executeCommand(args: [String]) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return ProcessResult(
            exitCode: Int(process.terminationStatus),
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )
    }

    private func computeFileSHA256(url: URL) async throws -> String {
        let data = try Data(contentsOf: url)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Supporting Types

private struct ProcessResult {
    let exitCode: Int
    let stdout: String
    let stderr: String
}

public enum ConversionError: Error {
    case modelNotFound(String)
    case unsupportedSourceFormat(String)
    case conversionFailed(String)
    case toolNotFound(String)
}

import CommonCrypto
