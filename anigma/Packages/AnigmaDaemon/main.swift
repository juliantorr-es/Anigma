//
//  main.swift
//  AnigmaDaemon
//
//  Entry point for the Anigma sidecar daemon.
//

import AnigmaDaemonCore
import AnigmaCLIDatabase
import AnigmaSidecar
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

func buildCanonicalWorkerRegistryForCLI() async -> Result<JobRegistry, WorkerRegistryBuildError> {
    let registry = JobRegistry()
    // PostgreSQL is now the first-class database - SQLite is deprecated
    let dbPath = CLIDatabaseConfig.defaultDatabasePath()
    let database = DatabaseActor(path: dbPath)
    let report = await DaemonWorkerRegistry.registerCanonicalWorkers(
        on: registry,
        database: database
    )
    guard report.isInParity else {
        return .failure(.parityFailure(parityFailureMessage(report)))
    }
    return .success(registry)
}

/// Update configuration with command-line arguments
func updateConfigurationWithCommandLineArguments(
    _ configuration: DaemonConfiguration,
    arguments: [String]
) -> DaemonConfiguration {
    var config = configuration
    var daemonConfig = config.daemon

    if let socketIndex = arguments.firstIndex(of: "--socket"),
       socketIndex + 1 < arguments.count {
        let socketPath = arguments[socketIndex + 1]
        daemonConfig = DaemonConfig(
            bindHost: daemonConfig.bindHost,
            bindPort: daemonConfig.bindPort,
            unixSocket: socketPath,
            tcpEnabled: daemonConfig.tcpEnabled,
            tlsEnabled: daemonConfig.tlsEnabled,
            tlsCertificatePath: daemonConfig.tlsCertificatePath,
            tlsPrivateKeyPath: daemonConfig.tlsPrivateKeyPath,
            corsAllowedOrigins: daemonConfig.corsAllowedOrigins,
            executionMode: daemonConfig.executionMode,
            maxClients: daemonConfig.maxClients,
            shutdownTimeoutSeconds: daemonConfig.shutdownTimeoutSeconds,
            apiKeysEnabled: daemonConfig.apiKeysEnabled,
            aneSchedulingEnabled: daemonConfig.aneSchedulingEnabled,
            requireContractValidation: daemonConfig.requireContractValidation
        )
    }
    
    // Parse TCP enabled
    if arguments.contains("--tcp-enabled") {
            daemonConfig = DaemonConfig(
                bindHost: daemonConfig.bindHost,
                bindPort: daemonConfig.bindPort,
                unixSocket: daemonConfig.unixSocket,
                tcpEnabled: true,
                tlsEnabled: daemonConfig.tlsEnabled,
                tlsCertificatePath: daemonConfig.tlsCertificatePath,
                tlsPrivateKeyPath: daemonConfig.tlsPrivateKeyPath,
                corsAllowedOrigins: daemonConfig.corsAllowedOrigins,
                executionMode: daemonConfig.executionMode,
                maxClients: daemonConfig.maxClients,
                shutdownTimeoutSeconds: daemonConfig.shutdownTimeoutSeconds,
                apiKeysEnabled: daemonConfig.apiKeysEnabled,
                aneSchedulingEnabled: daemonConfig.aneSchedulingEnabled,
                requireContractValidation: daemonConfig.requireContractValidation
            )
        }
    
    // Parse TLS enabled
    if arguments.contains("--tls-enabled") {
        // Ensure TCP is also enabled
        if !daemonConfig.tcpEnabled {
            daemonConfig = DaemonConfig(
                bindHost: daemonConfig.bindHost,
                bindPort: daemonConfig.bindPort,
                unixSocket: daemonConfig.unixSocket,
                tcpEnabled: true,
                tlsEnabled: true,
                tlsCertificatePath: daemonConfig.tlsCertificatePath,
                tlsPrivateKeyPath: daemonConfig.tlsPrivateKeyPath,
                corsAllowedOrigins: daemonConfig.corsAllowedOrigins,
                executionMode: daemonConfig.executionMode,
                maxClients: daemonConfig.maxClients,
                shutdownTimeoutSeconds: daemonConfig.shutdownTimeoutSeconds,
                apiKeysEnabled: daemonConfig.apiKeysEnabled,
                aneSchedulingEnabled: daemonConfig.aneSchedulingEnabled,
                requireContractValidation: daemonConfig.requireContractValidation
            )
        } else {
            daemonConfig = DaemonConfig(
                bindHost: daemonConfig.bindHost,
                bindPort: daemonConfig.bindPort,
                unixSocket: daemonConfig.unixSocket,
                tcpEnabled: daemonConfig.tcpEnabled,
                tlsEnabled: true,
                tlsCertificatePath: daemonConfig.tlsCertificatePath,
                tlsPrivateKeyPath: daemonConfig.tlsPrivateKeyPath,
                corsAllowedOrigins: daemonConfig.corsAllowedOrigins,
                executionMode: daemonConfig.executionMode,
                maxClients: daemonConfig.maxClients,
                shutdownTimeoutSeconds: daemonConfig.shutdownTimeoutSeconds,
                apiKeysEnabled: daemonConfig.apiKeysEnabled,
                aneSchedulingEnabled: daemonConfig.aneSchedulingEnabled,
                requireContractValidation: daemonConfig.requireContractValidation
            )
        }
    }
    
    // Parse TLS certificate path
    if let certIndex = arguments.firstIndex(of: "--tls-cert"),
       certIndex + 1 < arguments.count {
        let certPath = arguments[certIndex + 1]
            daemonConfig = DaemonConfig(
                bindHost: daemonConfig.bindHost,
                bindPort: daemonConfig.bindPort,
                unixSocket: daemonConfig.unixSocket,
                tcpEnabled: daemonConfig.tcpEnabled,
                tlsEnabled: daemonConfig.tlsEnabled,
                tlsCertificatePath: certPath,
                tlsPrivateKeyPath: daemonConfig.tlsPrivateKeyPath,
                corsAllowedOrigins: daemonConfig.corsAllowedOrigins,
                executionMode: daemonConfig.executionMode,
                maxClients: daemonConfig.maxClients,
                shutdownTimeoutSeconds: daemonConfig.shutdownTimeoutSeconds,
                apiKeysEnabled: daemonConfig.apiKeysEnabled,
                aneSchedulingEnabled: daemonConfig.aneSchedulingEnabled,
                requireContractValidation: daemonConfig.requireContractValidation
            )
        }
    
    // Parse TLS private key path
    if let keyIndex = arguments.firstIndex(of: "--tls-key"),
       keyIndex + 1 < arguments.count {
        let keyPath = arguments[keyIndex + 1]
            daemonConfig = DaemonConfig(
                bindHost: daemonConfig.bindHost,
                bindPort: daemonConfig.bindPort,
                unixSocket: daemonConfig.unixSocket,
                tcpEnabled: daemonConfig.tcpEnabled,
                tlsEnabled: daemonConfig.tlsEnabled,
                tlsCertificatePath: daemonConfig.tlsCertificatePath,
                tlsPrivateKeyPath: keyPath,
                corsAllowedOrigins: daemonConfig.corsAllowedOrigins,
                executionMode: daemonConfig.executionMode,
                maxClients: daemonConfig.maxClients,
                shutdownTimeoutSeconds: daemonConfig.shutdownTimeoutSeconds,
                apiKeysEnabled: daemonConfig.apiKeysEnabled,
                aneSchedulingEnabled: daemonConfig.aneSchedulingEnabled,
                requireContractValidation: daemonConfig.requireContractValidation
            )
        }
    
    // Parse CORS origins (comma-separated)
    if let corsIndex = arguments.firstIndex(of: "--cors-origins"),
       corsIndex + 1 < arguments.count {
        let originsString = arguments[corsIndex + 1]
        let origins = originsString.split(separator: ",").map(String.init)
            daemonConfig = DaemonConfig(
                bindHost: daemonConfig.bindHost,
                bindPort: daemonConfig.bindPort,
                unixSocket: daemonConfig.unixSocket,
                tcpEnabled: daemonConfig.tcpEnabled,
                tlsEnabled: daemonConfig.tlsEnabled,
                tlsCertificatePath: daemonConfig.tlsCertificatePath,
                tlsPrivateKeyPath: daemonConfig.tlsPrivateKeyPath,
                corsAllowedOrigins: origins,
                executionMode: daemonConfig.executionMode,
                maxClients: daemonConfig.maxClients,
                shutdownTimeoutSeconds: daemonConfig.shutdownTimeoutSeconds,
                apiKeysEnabled: daemonConfig.apiKeysEnabled,
                aneSchedulingEnabled: daemonConfig.aneSchedulingEnabled,
                requireContractValidation: daemonConfig.requireContractValidation
            )
        }
    
    config.daemon = daemonConfig
    return config
}

if shouldShowHelp(CommandLine.arguments) {
    printUsage()
    exit(0)
}

// Check for worker mode
if CommandLine.arguments.contains("--worker") {
    fputs("Anigma worker starting...\n", stderr)

    // Apply resource limits
    WorkerProcess.applyResourceLimits()

    // Initialize canonical runtime registry and validate parity
    let registry: JobRegistry
    switch await buildCanonicalWorkerRegistryForCLI() {
    case .success(let builtRegistry):
        registry = builtRegistry
    case .failure(let message):
        fputs("\(message)\n", stderr)
        exit(1)
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
            exit(1)
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
        exit(0)

    } catch {
        fputs("Worker: fatal error: \(error)\n", stderr)
        exit(1)
    }
}

// Check for verification mode
if CommandLine.arguments.contains("--verify") {
    do {
        try await Verifier.run()
        exit(0)
    } catch {
        fputs("Verification failed: \(error)\n", stderr)
        exit(1)
    }
}

// Check for list-jobs mode
if CommandLine.arguments.contains("--list-jobs") {
    let registry: JobRegistry
    switch await buildCanonicalWorkerRegistryForCLI() {
    case .success(let builtRegistry):
        registry = builtRegistry
    case .failure(let message):
        fputs("\(message)\n", stderr)
        exit(1)
    }

    let kinds = await registry.registeredKinds()
    print("Registered Job Kinds:")
    for kind in kinds {
        print("  - \(kind)")
    }
    exit(0)
}

// Check for vault-summary mode
if CommandLine.arguments.contains("--vault-summary") {
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
        exit(0)
    } catch {
        fputs("Failed to get vault summary: \(error)\n", stderr)
        exit(1)
    }
}

// Check for status mode
if CommandLine.arguments.contains("--status") {
    do {
        // Load configuration to get socket path
        var configuration = DaemonConfiguration.default
        if let configIndex = CommandLine.arguments.firstIndex(of: "--config"),
            configIndex + 1 < CommandLine.arguments.count {
            let configPath = CommandLine.arguments[configIndex + 1]
            let url = URL(fileURLWithPath: configPath)
            let data = try Data(contentsOf: url)
            configuration = try JSONDecoder().decode(DaemonConfiguration.self, from: data)
        }

        let socketPath = (configuration.daemon.unixSocket as NSString).expandingTildeInPath
        if !FileManager.default.fileExists(atPath: socketPath) {
            print("Error: Daemon is not running (socket not found at \(socketPath))")
            exit(1)
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
        exit(0)
    } catch {
        print("Error getting status: \(error)")
        exit(1)
    }
}

// Check for verify-chain mode (Pass 7)
if let verifyIndex = CommandLine.arguments.firstIndex(of: "--verify-chain"),
   verifyIndex + 1 < CommandLine.arguments.count {

    let hash = CommandLine.arguments[verifyIndex + 1]

    // Connect to daemon
    // Use default socket or from config
    var configuration = DaemonConfiguration.default
    if let configIndex = CommandLine.arguments.firstIndex(of: "--config"),
        configIndex + 1 < CommandLine.arguments.count {
        let configPath = CommandLine.arguments[configIndex + 1]
        let url = URL(fileURLWithPath: configPath)
        let data = try Data(contentsOf: url)
        configuration = try JSONDecoder().decode(DaemonConfiguration.self, from: data)
    }

    let socketPath = (configuration.daemon.unixSocket as NSString).expandingTildeInPath
    if !FileManager.default.fileExists(atPath: socketPath) {
        print("Error: Daemon is not running (socket not found at \(socketPath))")
        exit(1)
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
        exit(0)
    } else {
        print("VERIFICATION FAILURE: Chain ending at \(hash) is INVALID.")
        print("Message: \(response.message)")
        if let error = response.error {
            print("Error: \(error.code) - \(error.message)")
        }
        exit(1)
    }
}

// Main daemon mode
print("Anigma Sidecar Daemon starting...")
fflush(stdout)

do {
    // Load configuration
    var configuration = DaemonConfiguration.default

    if let configIndex = CommandLine.arguments.firstIndex(of: "--config"),
        configIndex + 1 < CommandLine.arguments.count {
        let configPath = CommandLine.arguments[configIndex + 1]
        let url = URL(fileURLWithPath: configPath)
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        configuration = try decoder.decode(DaemonConfiguration.self, from: data)
        print("Loaded config from \(configPath)")
    }

    // Apply command-line overrides for TCP/TLS/CORS
    configuration = updateConfigurationWithCommandLineArguments(configuration, arguments: CommandLine.arguments)

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
    exit(0)

} catch {
    print("Fatal error: \(error)")
    fflush(stdout)
    exit(1)
}
