//
//  WorkerProcess.swift
//  AnigmaDaemonCore
//
//  Manages a worker subprocess for job execution.
//

import Foundation
import ExecutionCore

#if os(macOS) || os(Linux)
    import Darwin
#endif

/// Manages a worker subprocess
public actor WorkerProcess {
    public var currentJobId: String?
    private let executablePath: String
    private let resourceLimits: (ramMB: Int, cpuSec: Int)

    public init(executablePath: String? = nil, resourceLimits: (ramMB: Int, cpuSec: Int) = (4096, 60)) {
        self.currentJobId = nil
        // Use the current executable for workers, or override for testing
        self.executablePath = executablePath ?? Bundle.main.executablePath ?? "./anigmad"
        self.resourceLimits = resourceLimits
    }

    /// Assign a job ID to this worker (for tracking)
    public func assignJob(_ id: String?) {
        self.currentJobId = id
    }

    private var currentProcess: Process?

    /// Execute a job in a subprocess
    public func execute(job: borrowing Job, vaultData: [String: Data]) async throws -> [JobOutputPayload] {
        let process = Process()
        self.currentProcess = process

        defer {
            self.currentProcess = nil
        }

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["--worker"]

        // Inject resource limits into environment (Pass 6)
        var env = ProcessInfo.processInfo.environment
        env["ANIGMA_WORKER_RAM_MB"] = String(resourceLimits.ramMB)
        env["ANIGMA_WORKER_CPU_SEC"] = String(resourceLimits.cpuSec)
        process.environment = env

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Encode job to JSON with ISO8601 dates
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payload = WorkerJobPayload(jobId: job.jobId, spec: job.spec, vaultPayloads: vaultData)
        let jobData = try encoder.encode(payload)

        // Start process
        try process.run()

        // Write job data to stdin
        try stdinPipe.fileHandleForWriting.write(contentsOf: jobData)
        try stdinPipe.fileHandleForWriting.close()

        // Read output from stdout
        let outputData = try stdoutPipe.fileHandleForReading.readToEnd()
        let capturedStderrData = try stderrPipe.fileHandleForReading.readToEnd()

        if let data = capturedStderrData, !data.isEmpty,
            let msg = String(data: data, encoding: .utf8) {
            fputs("Subprocess stderr: \(msg)\n", stderr)
        }

        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorMsg =
                capturedStderrData.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
            throw WorkerError.executionFailed(
                "Worker exited with status \(process.terminationStatus): \(errorMsg)")
        }

        guard let data = outputData else {
            throw WorkerError.executionFailed("Worker produced no output")
        }

        // Decode results with ISO8601 dates
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let outputs = try decoder.decode([JobOutputPayload].self, from: data)
        return outputs
    }

    /// Apply resource limits to the current process (to be called by the worker)
    public static func applyResourceLimits() {
        #if os(macOS) || os(Linux)
            let env = ProcessInfo.processInfo.environment

            // Read RAM limit (default 4096MB)
            let ramMB = Int(env["ANIGMA_WORKER_RAM_MB"] ?? "") ?? 4096
            let memoryLimit: rlim_t = rlim_t(ramMB) * 1024 * 1024

            var rl = rlimit(rlim_cur: memoryLimit, rlim_max: memoryLimit)
            if setrlimit(RLIMIT_AS, &rl) != 0 {
                fputs(
                    "Worker: Warning: setrlimit(RLIMIT_AS) failed: \(String(cString: strerror(errno)))\n",
                    stderr)
            }

            // Read CPU limit (default 60 seconds)
            let cpuSec = Int(env["ANIGMA_WORKER_CPU_SEC"] ?? "") ?? 60
            let cpuLimit = rlim_t(cpuSec)

            var rlCpu = rlimit(rlim_cur: cpuLimit, rlim_max: cpuLimit)
            if setrlimit(RLIMIT_CPU, &rlCpu) != 0 {
                fputs(
                    "Worker: Warning: setrlimit(RLIMIT_CPU) failed: \(String(cString: strerror(errno)))\n",
                    stderr)
            }
        #endif
    }

    /// Terminate the running process if it exists
    public func terminate() {
        currentProcess?.terminate()
        currentProcess = nil
    }
}
