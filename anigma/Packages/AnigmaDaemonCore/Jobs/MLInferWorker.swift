//
//  MLInferWorker.swift
//  AnigmaDaemonCore
//

import Foundation
import ContractsCore
import ExecutionCore

/// ml.infer worker
/// Executes local inference via the governed ml-worker binary.
public struct MLInferWorker: JobWorker {
    public static let kind = "ml.infer"

    public init() {}

    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        fputs("Worker: starting ML inference (via ml-worker)...\n", stderr)
        fflush(stderr)

        // inputs[0]: model file, inputs[1]: input data
        guard let modelInput = inputs.first else {
            throw WorkerError.invalidInputCount(expected: 1, got: 0)
        }
        guard let modelByteData = vaultData[modelInput.hash] else {
            throw WorkerError.missingInputData(hash: modelInput.hash)
        }

        // Decode config
        let mlConfig = MLInferConfig.decode(from: config)

        let envBinary = ProcessInfo.processInfo.environment["ML_WORKER_BINARY"]
        let mlWorkerPath = envBinary ?? WorkerTooling.findTool(named: "ml-worker")

        guard let mlWorkerPath = mlWorkerPath else {
            throw WorkerError.executionFailed("Tool 'ml-worker' not found in PATH or bundles.")
        }

        return try await WorkerTooling.withTemporaryDirectoryAsync(prefix: "ml-infer-job") { dir in
            // 1. Write Input Files to Temp Dir
            let modelPath = dir.appendingPathComponent("model.bin").path
            try modelByteData.write(to: URL(fileURLWithPath: modelPath))

            var workerInputs: [MLArtifactRef] = [
                MLArtifactRef(path: modelPath, hash: modelInput.hash)
            ]

            if inputs.count > 1, let inputInput = inputs.safe(1), let inputData = vaultData[inputInput.hash] {
                 let inputPath = dir.appendingPathComponent("input.dat").path
                 try inputData.write(to: URL(fileURLWithPath: inputPath))
                 workerInputs.append(MLArtifactRef(path: inputPath, hash: inputInput.hash))
            }

            // 2. Prepare Output Directory
            let outputDir = dir.appendingPathComponent("output")
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

            // 3. Construct MLWorkerRequest
            let engine: MLWorkerEngine = mlConfig.engine.contains("llama") ? .llama : .mlx
            let task: MLWorkerTask = mlConfig.engine.contains("whisper") ? .transcribe : .chat

            let request = MLWorkerRequest(
                requestId: UUID().uuidString,
                runId: "daemon-job-\(UUID().uuidString.prefix(8))",
                stepId: "ml.infer",
                engine: engine,
                task: task,
                inputs: workerInputs,
                options: MLTaskOptions(
                    seed: 42,
                    maxTokens: mlConfig.maxTokens,
                    outputDirectory: outputDir.path
                )
            )

            // 4. Serialize Request
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            let requestData = try encoder.encode(request)

            // 5. Run ml-worker (ASYNC with Cancellation)
            let args = [
                "--engine", engine == .llama ? "llama" : "mlx"
            ]

            let env = [
                "MLX_MODEL_PATH": modelPath,
                "LLAMA_MODEL_PATH": modelPath
            ]

            let result = try await WorkerTooling.runProcessAsync(
                executable: mlWorkerPath,
                arguments: args,
                workingDirectory: dir,
                inputData: requestData + Data("\n".utf8),
                environment: env,
                timeout: 300.0
            )

            if result.exitCode != 0 {
                throw WorkerError.executionFailed("ml-worker failed (\(result.exitCode)): \(result.stderr)")
            }

            // 6. Parse Response (Stdout)
            guard !result.stdout.isEmpty else {
                 throw WorkerError.executionFailed("ml-worker produced no stdout. stderr: \(result.stderr)")
            }

            let decoder = JSONDecoder()
            let response = try decoder.decode(MLWorkerResponse.self, from: result.stdout)

            if response.status == .failed {
                throw WorkerError.executionFailed("ml-worker reported failure: \(response.errorMessage ?? "unknown")")
            }

            // 7. Collect Outputs with Security Checks
            var jobOutputs: [JobOutputPayload] = []
            let canonicalOutputDir = outputDir.resolvingSymlinksInPath().path

            for artifact in response.outputs {
                let fileURL = URL(fileURLWithPath: artifact.path)

                // Security Check: Symlink and Path Traversal
                let resourceValues = try fileURL.resourceValues(forKeys: [.isSymbolicLinkKey, .canonicalPathKey])

                if resourceValues.isSymbolicLink == true {
                     throw WorkerError.executionFailed("Security violation: Worker produced a symlink at \(artifact.path)")
                }

                let canonicalFile = fileURL.resolvingSymlinksInPath().path
                if !canonicalFile.hasPrefix(canonicalOutputDir) {
                     throw WorkerError.executionFailed("Security violation: Output path traversal detected: \(canonicalFile)")
                }

                let data = try Data(contentsOf: fileURL)

                jobOutputs.append(JobOutputPayload(
                     data: data,
                     mediaType: "text/plain",
                     kind: "derived"
                ))
            }

            // 8. Collect Metrics Payload
            if let metrics = response.metrics {
                // Encode metrics to JSON and attach
                let metricsData = try JSONEncoder().encode(metrics)
                jobOutputs.append(JobOutputPayload(
                    data: metricsData,
                    mediaType: "application/json",
                    kind: "metrics"
                ))
            }

            return jobOutputs
        }
    }
}

private struct MLInferConfig: Codable {
    let engine: String
    let maxTokens: Int?
    let extraArgs: [String]

    static let `default` = MLInferConfig(
        engine: "mlx",
        maxTokens: 128,
        extraArgs: []
    )

    static func decode(from data: Data) -> MLInferConfig {
        guard !data.isEmpty else { return .default }
        let decoder = JSONDecoder()
        return (try? decoder.decode(MLInferConfig.self, from: data)) ?? .default
    }
}

extension Array {
    func safe(_ index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
