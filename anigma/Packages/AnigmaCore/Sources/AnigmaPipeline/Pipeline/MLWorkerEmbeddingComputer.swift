//
//  MLWorkerEmbeddingComputer.swift
//  AnigmaCore
//
//  [Brief description of file purpose]
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import InferenceCore
import ContractsCore
import Foundation

/// Concrete implementation of `EmbeddingComputing` that uses the `MLWorkerExecutable`.
public struct MLWorkerEmbeddingComputer: EmbeddingComputing {
    private let mlWorkerPath: String // Path to the MLWorkerExecutable binary

    public init(mlWorkerPath: String) {
        self.mlWorkerPath = mlWorkerPath
    }

    public func computeEmbeddings(
        modelID: String,
        modelVersion: String?,
        inputs: [String],
        normalize: Bool
    ) async throws -> ContractsCore.EmbeddingResult {
        guard !inputs.isEmpty else {
            return ContractsCore.EmbeddingResult(modelID: modelID, modelVersion: modelVersion, dimension: 0, vectors: [], inputHashes: [])
        }

        var allEmbeddings: [[Double]] = []
        var allInputHashes: [String] = []
        allEmbeddings.reserveCapacity(inputs.count)
        allInputHashes.reserveCapacity(inputs.count)

        for (index, inputString) in inputs.enumerated() {
            let inputHash = ContractKeyDerivation.blake3Hex(Data(inputString.utf8))
            allInputHashes.append(inputHash)

            let tempInputFile = try writeTempInput(input: inputString)
            defer { try? FileManager.default.removeItem(at: tempInputFile) }

            let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("anigma-ml-worker-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: outputDir) }

            let request = MLWorkerRequest(
                requestId: "embedding-\(UUID().uuidString)",
                runId: "embedding-\(UUID().uuidString)",
                stepId: "embed-\(index)",
                engine: .mlx,
                task: .embed,
                inputs: [MLArtifactRef(path: tempInputFile.path, hash: inputHash)],
                options: MLTaskOptions(seed: 42, outputDirectory: outputDir.path)
            )

            let response = try execute(request: request, executablePath: mlWorkerPath)
            guard response.status == .completed else {
                throw MLWorkerEmbeddingComputerError.executionFailed(response.errorMessage ?? "ml-worker failed")
            }

            guard let output = response.outputs.first else {
                throw MLWorkerEmbeddingComputerError.invalidOutput("ml-worker returned no outputs")
            }

            let embedding = try loadEmbedding(fromHeaderPath: output.path)
            let vector = normalize ? normalizeVector(embedding) : embedding
            allEmbeddings.append(vector)
        }

        let dimension = allEmbeddings.first?.count ?? 0
        return ContractsCore.EmbeddingResult(
            modelID: modelID,
            modelVersion: modelVersion,
            dimension: dimension,
            vectors: allEmbeddings,
            inputHashes: allInputHashes
        )
    }
}

public enum MLWorkerEmbeddingComputerError: Error, LocalizedError {
    case executionFailed(String)
    case invalidOutput(String)

    public var errorDescription: String? {
        switch self {
        case .executionFailed(let stderr):
            return "MLWorkerExecutable execution failed: \(stderr)"
        case .invalidOutput(let message):
            return "MLWorkerExecutable produced invalid output: \(message)"
        }
    }
}

private struct WorkerEmbeddingHeader: Codable {
    let dataPath: String
    let embeddingDimension: Int?
    let shape: [Int]?
}

private func writeTempInput(input: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("anigma-embedding-\(UUID().uuidString).txt")
    try input.write(to: url, atomically: true, encoding: .utf8)
    return url
}

private func execute(request: MLWorkerRequest, executablePath: String) throws -> MLWorkerResponse {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executablePath)
    process.arguments = ["--engine", request.engine.rawValue]

    let stdinPipe = Pipe()
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardInput = stdinPipe
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    try process.run()

    let encoder = JSONEncoder()
    let payload = try encoder.encode(request)
    stdinPipe.fileHandleForWriting.write(payload + Data("\n".utf8))
    stdinPipe.fileHandleForWriting.closeFile()

    process.waitUntilExit()

    let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: stdout, encoding: .utf8) else {
        throw MLWorkerEmbeddingComputerError.invalidOutput("Unable to decode stdout")
    }

    guard let line = output.split(separator: "\n").first else {
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        throw MLWorkerEmbeddingComputerError.invalidOutput("No response line. stderr: \(stderr)")
    }

    let decoder = JSONDecoder()
    return try decoder.decode(MLWorkerResponse.self, from: Data(line.utf8))
}

private func loadEmbedding(fromHeaderPath path: String) throws -> [Double] {
    let headerURL = URL(fileURLWithPath: path)
    let headerData = try Data(contentsOf: headerURL)
    let header = try JSONDecoder().decode(WorkerEmbeddingHeader.self, from: headerData)

    let dataURL: URL
    if header.dataPath.hasPrefix("/") {
        dataURL = URL(fileURLWithPath: header.dataPath)
    } else {
        dataURL = headerURL.deletingLastPathComponent().appendingPathComponent(header.dataPath)
    }

    let rawData = try Data(contentsOf: dataURL)
    let floatCount = rawData.count / MemoryLayout<Float>.size
    let floats: [Float] = rawData.withUnsafeBytes { raw in
        let buffer = raw.bindMemory(to: Float.self)
        return Array(buffer.prefix(floatCount))
    }
    return floats.map(Double.init)
}

private func normalizeVector(_ vector: [Double]) -> [Double] {
    let norm = sqrt(vector.reduce(0.0) { $0 + $1 * $1 })
    guard norm > 0 else { return vector }
    return vector.map { $0 / norm }
}
