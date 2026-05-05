//
//  MLInferWorker.swift
//  AnigmaDaemonCore
//

import Foundation
import ContractsCore
import ExecutionCore
import MLWorkerCommon

/// ml.infer worker
/// Executes local inference via the governed ml-worker library (in-process)
/// or fallback to ml-worker binary (subprocess).
public struct MLInferWorker: JobWorker {
    public static let kind = "ml.infer"
    private let configuration: DaemonConfiguration?

    public init(configuration: DaemonConfiguration? = nil) {
        self.configuration = configuration
    }

    public func execute(
        inputs: [ArtifactRef],
        config: Data,
        vaultData: [String: Data]
    ) async throws -> [JobOutputPayload] {
        fputs("Worker: starting ML inference...\n", stderr)
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

        return try await WorkerTooling.withTemporaryDirectoryAsync(prefix: "ml-infer-job") { dir in
            // 1. Write Input Files to Temp Dir
            let modelPath = dir.appendingPathComponent("model.bin").path
            try modelByteData.write(to: URL(fileURLWithPath: modelPath))

            var workerInputs: [MLWorkerCommon.MLArtifactRef] = [
                MLWorkerCommon.MLArtifactRef(path: modelPath, hash: modelInput.hash)
            ]

            if inputs.count > 1, let inputInput = inputs.safe(1), let inputData = vaultData[inputInput.hash] {
                 let inputPath = dir.appendingPathComponent("input.dat").path
                 try inputData.write(to: URL(fileURLWithPath: inputPath))
                  workerInputs.append(MLWorkerCommon.MLArtifactRef(path: inputPath, hash: inputInput.hash))
            }

            // 2. Prepare Output Directory
            let outputDir = dir.appendingPathComponent("output")
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

            // 3. Construct MLWorkerRequest
            let engine: MLWorkerCommon.MLWorkerEngine = mlConfig.engine.contains("llama") ? .llama : .mlx
            let task: ContractsCore.MLWorkerTask = mlConfig.engine.contains("whisper") ? .transcribe : .chat
            let useMockMode = configuration?.daemon.useMockML ?? false
            let inProcessWorker = MLWorker(engine: engine, mockMode: useMockMode)

            let request = MLWorkerCommon.MLWorkerRequest(
                requestId: UUID().uuidString,
                runId: "daemon-job-\(UUID().uuidString.prefix(8))",
                stepId: "ml.infer",
                engine: engine,
                task: task,
                inputs: workerInputs,
                options: MLWorkerCommon.MLTaskOptions(
                    seed: 42,
                    maxTokens: mlConfig.maxTokens,
                    temperature: nil,
                    topP: nil,
                    outputDirectory: outputDir.path
                )
            )

            // 4. Execute (In-Process by default in this worker)
            let response: MLWorkerCommon.MLWorkerResponse
            do {
                response = try await inProcessWorker.performTaskAsync(request)
            } catch {
                // Fallback to subprocess if enabled/desired? 
                // For now, let's try subprocess fallback if in-process fails or if we want to preserve old behavior
                fputs("Warning: In-process ML inference failed: \(error.localizedDescription). Falling back to subprocess.\n", stderr)
                response = try await executeSubprocess(request: request, modelPath: modelPath, engine: engine, dir: dir)
            }

            if response.status == .failed {
                throw WorkerError.executionFailed("ML worker reported failure: \(response.errorMessage ?? "unknown")")
            }

            // 5. Collect Outputs with Security Checks
            var jobOutputs: [JobOutputPayload] = []
            let canonicalOutputDir = outputDir.resolvingSymlinksInPath().path

            for artifact in response.outputs {
                let fileURL = URL(fileURLWithPath: artifact.path)
                
                // Security check
                if !fileURL.path.hasPrefix(canonicalOutputDir) && !FileManager.default.fileExists(atPath: fileURL.path) {
                    // Handle relative paths from worker output
                    let absoluteURL = outputDir.appendingPathComponent(artifact.path)
                    if absoluteURL.path.hasPrefix(canonicalOutputDir) {
                        let data = try Data(contentsOf: absoluteURL)
                        jobOutputs.append(JobOutputPayload(data: data, mediaType: "text/plain", kind: "derived"))
                        continue
                    }
                }

                let data = try Data(contentsOf: fileURL)
                jobOutputs.append(JobOutputPayload(data: data, mediaType: "text/plain", kind: "derived"))
            }

            // 6. Collect Metrics Payload
            if let metrics = response.metrics {
                let metricsData = try JSONEncoder().encode(metrics)
                jobOutputs.append(JobOutputPayload(data: metricsData, mediaType: "application/json", kind: "metrics"))
            }

            return jobOutputs
        }
    }
    
    private func executeSubprocess(request: MLWorkerCommon.MLWorkerRequest, modelPath: String, engine: MLWorkerCommon.MLWorkerEngine, dir: URL) async throws -> MLWorkerCommon.MLWorkerResponse {
        let mlWorkerPath = configuration?.daemon.mlWorkerPath ?? WorkerTooling.findTool(named: "ml-worker")

        guard let mlWorkerPath = mlWorkerPath else {
            throw WorkerError.executionFailed("Tool 'ml-worker' not found for fallback.")
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let requestData = try encoder.encode(request)

        let args = ["--engine", engine == .llama ? "llama" : "mlx"]
        var env = configuration?.environment ?? ProcessInfo.processInfo.environment
        env["MLX_MODEL_PATH"] = modelPath
        env["LLAMA_MODEL_PATH"] = modelPath

            let result = try await WorkerTooling.runProcessAsync(config: WorkerTooling.RunProcessConfiguration(
                executable: mlWorkerPath,
                arguments: args,
                workingDirectory: dir,
                inputData: requestData + Data("\n".utf8),
                environment: env,
                timeout: 300.0
            ))

        if result.exitCode != 0 {
            throw WorkerError.executionFailed("ml-worker subprocess failed (\(result.exitCode)): \(result.stderr)")
        }

        return try JSONDecoder().decode(MLWorkerCommon.MLWorkerResponse.self, from: result.stdout)
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
