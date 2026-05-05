//
//  main.swift
//  AnigmaDaemon
//
//  Entry point for the Anigma sidecar daemon.
//

import AnigmaDaemonCore
import AnigmaCLIDatabase
import AnigmaSidecar
import AnigmaCore
import DatabaseCore
import Foundation
import AnigmaNativeShims
import StorageCore
import Dispatch

func shouldShowHelp(_ arguments: [String]) -> Bool {
    arguments.contains("--help") || arguments.contains("-h")
}

func printUsage() {
    print("""
    Anigma Sidecar Daemon

    Usage:
      anigmad [--config <path>] [--socket <path>] [--tcp-enabled] [--tls-enabled]
      anigmad --worker
      anigmad verify-chain <receipt-hash> <socket-path>

    Options:
      -h, --help         Show this help text and exit.
      --config <path>    Load daemon configuration from a JSON file.
      --socket <path>    Override the Unix socket path.
      --tcp-enabled      Enable the TCP listener.
      --tls-enabled      Enable TLS for TCP transport.
      --tls-cert <path>  TLS certificate path.
      --tls-key <path>   TLS private key path.
      --cors-origins <list>
                         Comma-separated CORS origins for TCP transport.
    """)
}

func parityFailureMessage(_ report: WorkerRegistryParityReport) -> String {
    "Worker registry parity drift detected. Missing: \(report.missingKinds). Extra: \(report.extraKinds)"
}

enum WorkerRegistryBuildError: Error, CustomStringConvertible {
    case parityFailure(String)

    var description: String {
        switch self {
        case .parityFailure(let message):
            return message
        }
    }
}

func buildCanonicalWorkerRegistryForCLI(configuration: DaemonConfiguration) async -> Result<JobRegistry, WorkerRegistryBuildError> {
    let registry = JobRegistry()
    // PostgreSQL is now the first-class database - SQLite is deprecated
    let dbPath = CLIDatabaseConfig.defaultDatabasePath()
    let database = DatabaseActor(path: dbPath)
    let report = await DaemonWorkerRegistry.registerCanonicalWorkers(
        on: registry,
        database: database,
        configuration: configuration
    )
    guard report.isInParity else {
        return .failure(.parityFailure(parityFailureMessage(report)))
    }
    return .success(registry)
}


// Capture ambient process state once at the top-level boundary
let processArguments = CommandLine.arguments
let processEnvironment = ProcessInfo.processInfo.environment

// Initialize configuration from ambient process state
var configuration: DaemonConfiguration
do {
    configuration = try DaemonConfiguration.from(
        arguments: processArguments,
        environment: processEnvironment
    )
} catch {
    fputs("Fatal: Failed to initialize configuration: \(error)\n", stderr)
    RuntimeAuthority.shared.shutdown(exitCode: 1)
}

if shouldShowHelp(processArguments) {
    printUsage()
    RuntimeAuthority.shared.shutdown(exitCode:0)
}

// Check for worker mode
if processArguments.contains("--worker") {
    fputs("Anigma worker starting...\n", stderr)

    // Apply resource limits
    WorkerProcess.applyResourceLimits()

    // Initialize canonical runtime registry and validate parity
    let registry: JobRegistry
    switch await buildCanonicalWorkerRegistryForCLI(configuration: configuration) {
    case .success(let builtRegistry):
        registry = builtRegistry
    case .failure(let message):
        fputs("\(message)\n", stderr)
        RuntimeAuthority.shared.shutdown(exitCode:1)
    }


    // Read JobSpec from stdin
    let inputData = FileHandle.standardInput.readDataToEndOfFile()
    do {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(WorkerJobPayload.self, from: inputData)
        fputs("Worker: executing job \(payload.jobId) (kind: \(payload.spec.kind))\n", stderr)

        // Resolve worker
        guard let worker = await registry.worker(for: payload.spec.kind) else {
            fputs("Worker: unknown job kind \(payload.spec.kind)\n", stderr)
            RuntimeAuthority.shared.shutdown(exitCode:1)
        }

        // Execute
        let outputs = try await worker.execute(
            inputs: payload.spec.inputs,
            config: payload.spec.configCanonical,
            vaultData: payload.vaultPayloads
        )

        // Return results via stdout
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let resultData = try encoder.encode(outputs)
        FileHandle.standardOutput.write(resultData)
        fputs("\nWorker: job \(payload.jobId) completed successfully\n", stderr)
        RuntimeAuthority.shared.shutdown(exitCode:0)

    } catch {
        fputs("Worker: fatal error: \(error)\n", stderr)
        RuntimeAuthority.shared.shutdown(exitCode:1)
    }
}

// Check for verification mode
if processArguments.contains("--verify") {
    do {
        try await Verifier.run(configuration: configuration)
        RuntimeAuthority.shared.shutdown(exitCode:0)
    } catch {
        fputs("Verification failed: \(error)\n", stderr)
        RuntimeAuthority.shared.shutdown(exitCode:1)
    }
}

// Check for list-jobs mode
if processArguments.contains("--list-jobs") {
    let registry: JobRegistry
    switch await buildCanonicalWorkerRegistryForCLI(configuration: configuration) {
    case .success(let builtRegistry):
        registry = builtRegistry
    case .failure(let message):
        fputs("\(message)\n", stderr)
        RuntimeAuthority.shared.shutdown(exitCode:1)
    }

    let kinds = await registry.registeredKinds()
    print("Registered Job Kinds:")
    for kind in kinds {
        print("  - \(kind)")
    }
    RuntimeAuthority.shared.shutdown(exitCode:0)
}

// Check for vault-summary mode
if processArguments.contains("--vault-summary") {
    do {
        // PostgreSQL is now the first-class database - SQLite is deprecated
        let dbActor = DatabaseActor(path: DatabaseConfiguration.defaultDatabasePath())
        try await dbActor.open()
        let vaultURL = URL(
            fileURLWithPath: (NSHomeDirectory() as NSString).appendingPathComponent(".anigma/vault")
        )

        let vault = try await VaultAuthority(
            rootURL: vaultURL,
            database: dbActor,
            keyProvider: DefaultVaultKeyProvider.make()
        )

        let artifacts = try await vault.listArtifacts()
        print("Vault Summary:")
        print("  - Total Artifacts: \(artifacts.count)")

        var typeCounts: [String: Int] = [:]
        var totalBytes: Int = 0
        for art in artifacts {
            typeCounts[art.kind.rawValue, default: 0] += 1
            totalBytes += art.byteLen
        }

        print(
            "  - Total Storage: \(ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file))"
        )
        print("  - Artifacts by Kind:")
        for (kind, count) in typeCounts.sorted(by: { $0.key < $1.key }) {
            print("    - \(kind): \(count)")
        }
        RuntimeAuthority.shared.shutdown(exitCode:0)
    } catch {
        fputs("Failed to get vault summary: \(error)\n", stderr)
        RuntimeAuthority.shared.shutdown(exitCode:1)
    }
}

// Check for status mode
if processArguments.contains("--status") {
    do {
        let socketPath = (configuration.daemon.unixSocket as NSString).expandingTildeInPath
        if !FileManager.default.fileExists(atPath: socketPath) {
            print("Error: Daemon is not running (socket not found at \(socketPath))")
            RuntimeAuthority.shared.shutdown(exitCode:1)
        }

        // Connect via HTTP SidecarBridge
        let bridge = try await SidecarBridge.create(
            socketPath: socketPath,
            clientName: "anigmad-cli",
            scopes: ["system.read"]
        )

        let status = try await bridge.getStatus()

        print("Anigma Daemon Status:")
        print("  - API Version: \(status.apiVersion)")
        print("  - Daemon Version: \(status.daemonVersion)")
        print("  - Build Hash: \(status.buildHash)")
        print("  - Socket: \(status.socketPath)")
        print("  - TCP: \(status.tcpEnabled ? "Enabled" : "Disabled")")
        print("  - Workers: \(status.workerProcesses)")
        print(
            "  - Vault Size: \(ByteCountFormatter.string(fromByteCount: Int64(status.vaultSizeBytes), countStyle: .file))"
        )
        print(
            "  - Vault Quota: \(ByteCountFormatter.string(fromByteCount: Int64(status.vaultQuotaBytes), countStyle: .file))"
        )

        if let extraJson = status.extraJson, !extraJson.isEmpty {
            if let data = extraJson.data(using: String.Encoding.utf8),
                let metrics = try? JSONDecoder().decode(DatabaseMetrics.self, from: data) {
                print("\nDatabase Metrics:")
                print("  - Query Count: \(metrics.queryCount)")
                print(
                    "  - Avg Query Time: \(String(format: "%.3f", metrics.averageQueryTime * 1000))ms"
                )
                print("  - Transaction Retries: \(metrics.transactionRetries)")
                print("  - Busy Timeouts: \(metrics.busyTimeoutExhausted)")
                if let activeConnections = metrics.activeConnectionCount {
                    print("  - Active Connections: \(activeConnections)")
                }
                if let openCount = metrics.connectionOpenCount {
                    print("  - Connection Opens: \(openCount)")
                }
                if let closeCount = metrics.connectionCloseCount {
                    print("  - Connection Closes: \(closeCount)")
                }
                if let openFailures = metrics.connectionOpenFailures {
                    print("  - Connection Open Failures: \(openFailures)")
                }
                if let uptime = metrics.connectionUptimeSeconds {
                    print("  - Connection Uptime: \(String(format: "%.1f", uptime))s")
                }
                if let walSize = metrics.walSize {
                    print(
                        "  - WAL Size: \(ByteCountFormatter.string(fromByteCount: walSize, countStyle: .file))"
                    )
                }
                if let ckpt = metrics.walCheckpointCount {
                    print("  - WAL Checkpoints: \(ckpt)")
                }
            }
        }
        RuntimeAuthority.shared.shutdown(exitCode:0)
    } catch {
        print("Error getting status: \(error)")
        RuntimeAuthority.shared.shutdown(exitCode:1)
    }
}

// Check for verify-chain mode (Pass 7)
if let verifyIndex = processArguments.firstIndex(of: "--verify-chain"),
    verifyIndex + 1 < processArguments.count {

    let hash = processArguments[verifyIndex + 1]

    // Connect to daemon
    let socketPath = (configuration.daemon.unixSocket as NSString).expandingTildeInPath
    if !FileManager.default.fileExists(atPath: socketPath) {
        print("Error: Daemon is not running (socket not found at \(socketPath))")
        RuntimeAuthority.shared.shutdown(exitCode:1)
    }
    // Connect via HTTP SidecarBridge
    let bridge = try await SidecarBridge.create(
        socketPath: socketPath,
        clientName: "anigmad-auditor",
        scopes: ["audit.read"]
    )

    let response = try await bridge.verifyChain(headReceiptHash: hash)
    if response.ok {
        print("VERIFICATION SUCCESS: Chain ending at \(hash) is valid.")
        print("Message: \(response.message)")
        RuntimeAuthority.shared.shutdown(exitCode:0)
    } else {
        print("VERIFICATION FAILURE: Chain ending at \(hash) is INVALID.")
        print("Message: \(response.message)")
        if let error = response.error {
            print("Error: \(error.code) - \(error.message)")
        }
        RuntimeAuthority.shared.shutdown(exitCode:1)
    }
}

// Main daemon mode
print("Anigma Sidecar Daemon starting...")
fflush(stdout)

do {
    print("Config socket: \(configuration.daemon.unixSocket)")
    if configuration.daemon.tcpEnabled {
        print("Config TCP: enabled on \(configuration.daemon.bindHost):\(configuration.daemon.bindPort)")
        if configuration.daemon.tlsEnabled {
            print("Config TLS: enabled")
        }
        if !configuration.daemon.corsAllowedOrigins.isEmpty {
            print("Config CORS origins: \(configuration.daemon.corsAllowedOrigins)")
        }
    }
    fflush(stdout)

    // Create daemon
    let daemon = try await AnigmaDaemon(configuration: configuration)
    print("Daemon created.")
    fflush(stdout)

    // Start daemon
    try await daemon.start()
    print("Daemon started.")
    fflush(stdout)

    // Setup Async Signal Handling
    let signalSource = AsyncStream<Int32> { continuation in
        let sources: [Int32: DispatchSourceSignal] = [
            SIGINT: DispatchSource.makeSignalSource(signal: SIGINT, queue: .main),
            SIGTERM: DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        ]

        for (sig, source) in sources {
            source.setEventHandler {
                continuation.yield(sig)
            }
            source.resume()
        }

        continuation.onTermination = { _ in
            sources.values.forEach { $0.cancel() }
        }
    }

    // Wait for signal (blocks here until signal received)
    for await sig in signalSource {
        print("\nReceived signal \(sig). Shutting down...")
        break // Exit loop to proceed to shutdown
    }

    // Graceful Stop
    print("Stopping daemon services...")
    await daemon.stop()
    print("Daemon stopped gracefully.")
    RuntimeAuthority.shared.shutdown(exitCode: 0)

} catch {
    print("Fatal error: \(error)")
    fflush(stdout)
    RuntimeAuthority.shared.shutdown(exitCode: 1)
}
