import Foundation
import AnigmaCore

/// Minimal daemon configuration used to wire up AnigmaDaemonCore without full configuration plumbing.
/// This is a stub and will log when convenience factory methods are used.
public struct DaemonConfiguration: Codable, Sendable {
    public struct VaultConfig: Codable, Sendable {
        public var rootPath: String
        public var maxSizeGB: Int
    }

    public enum ExecutionMode: String, Sendable, Codable {
        case subprocess
        case inProcess
    }

    public struct DaemonConfig: Codable, Sendable {
        public var bindHost: String
        public var bindPort: Int
        public var unixSocket: String
        public var tcpEnabled: Bool
        public var tlsEnabled: Bool
        public var tlsCertificatePath: String?
        public var tlsPrivateKeyPath: String?
        public var corsAllowedOrigins: [String]
        public var executionMode: ExecutionMode
        public var maxClients: Int
        public var shutdownTimeoutSeconds: Int
        public var apiKeysEnabled: Bool
        public var aneSchedulingEnabled: Bool
        public var requireContractValidation: Bool
        public var cacheEnabled: Bool?
        public var mlWorkerPath: String?
        public var evidenceDirectory: String?
        public var useMockML: Bool

        public init(
            bindHost: String,
            bindPort: Int,
            unixSocket: String,
            tcpEnabled: Bool,
            tlsEnabled: Bool,
            tlsCertificatePath: String?,
            tlsPrivateKeyPath: String?,
            corsAllowedOrigins: [String],
            executionMode: ExecutionMode,
            maxClients: Int,
            shutdownTimeoutSeconds: Int,
            apiKeysEnabled: Bool,
            aneSchedulingEnabled: Bool,
            requireContractValidation: Bool,
            cacheEnabled: Bool? = true,
            mlWorkerPath: String? = nil,
            evidenceDirectory: String? = nil,
            useMockML: Bool = false
        ) {
            self.bindHost = bindHost
            self.bindPort = bindPort
            self.unixSocket = unixSocket
            self.tcpEnabled = tcpEnabled
            self.tlsEnabled = tlsEnabled
            self.tlsCertificatePath = tlsCertificatePath
            self.tlsPrivateKeyPath = tlsPrivateKeyPath
            self.corsAllowedOrigins = corsAllowedOrigins
            self.executionMode = executionMode
            self.maxClients = maxClients
            self.shutdownTimeoutSeconds = shutdownTimeoutSeconds
            self.apiKeysEnabled = apiKeysEnabled
            self.aneSchedulingEnabled = aneSchedulingEnabled
            self.requireContractValidation = requireContractValidation
            self.cacheEnabled = cacheEnabled
            self.mlWorkerPath = mlWorkerPath
            self.evidenceDirectory = evidenceDirectory
            self.useMockML = useMockML
        }
    }

    public struct ResourcesConfig: Codable, Sendable {
        public var maxConcurrentJobs: Int
        public var maxMemoryMB: Int
        public var workerProcesses: Int
        public var maxANEUtilization: Double
        public var thermalThreshold: Double
        public var powerBudget: Double
        public var maxFileSizeMB: Int
        public var cacheSizeLimitMB: Int
        public var timeoutSeconds: Int?
    }

    public struct AntigravityConfig: Codable, Sendable {
        public var redirectPort: Int
    }

    public enum ReceiptStoreMode: String, Sendable, Codable {
        case vault
        case inMemory
    }

    public struct GovernanceConfig: Codable, Sendable {
        public var receiptStoreMode: ReceiptStoreMode
        public var generateExecutionReceipts: Bool
        public var auditAllOperations: Bool
    }

    public var vault: VaultConfig
    public var daemon: DaemonConfig
    public var resources: ResourcesConfig
    public var antigravity: AntigravityConfig
    public var governance: GovernanceConfig
    
    /// Ambient environment variables captured at startup.
    public var environment: [String: String]

    public init(
        vault: VaultConfig,
        daemon: DaemonConfig,
        resources: ResourcesConfig,
        antigravity: AntigravityConfig,
        governance: GovernanceConfig,
        environment: [String: String] = [:]
    ) {
        self.vault = vault
        self.daemon = daemon
        self.resources = resources
        self.antigravity = antigravity
        self.governance = governance
        self.environment = environment
    }

    /// Creates a configuration from command line arguments and environment variables.
    /// This is the preferred way to initialize configuration from ambient process state.
    public static func from(arguments: [String], environment: [String: String] = [:]) throws -> DaemonConfiguration {
        logInfo("[DaemonConfiguration] Initializing from \(arguments.count) arguments and \(environment.count) env vars", category: "DaemonConfiguration")
        
        var config = DaemonConfiguration.developmentDefault(environment: environment)
        config.environment = environment
        
        // 1. Environment variables (Internal precedence: Env > Default)
        if let mlPath = environment["ML_WORKER_PATH"] {
            config.daemon.mlWorkerPath = mlPath
        }
        if let evidenceDir = environment["ANIGMA_EVIDENCE_DIR"] {
            config.daemon.evidenceDirectory = evidenceDir
        }
        if environment["ML_WORKER_MOCK_MODE"] == "true" || environment["ANIGMA_INDEX_USE_REAL_ML"] == "0" {
            config.daemon.useMockML = true
        }

        // 2. Command line arguments (Internal precedence: Argv > Env > Default)
        // Simple manual override for socket path if provided as 2nd arg (legacy behavior)
        if arguments.count >= 3 && !arguments[2].hasPrefix("-") {
            config.daemon.unixSocket = arguments[2]
        }

        // Search for --config (though loading logic remains in the entry point currently)
        if let configIndex = arguments.firstIndex(of: "--config"),
           configIndex + 1 < arguments.count {
            // Path found, but actual loading happens in the executable currently.
            // We just record it if needed.
        }
        
        return config
    }

    /// Development-friendly default configuration.
    public static func developmentDefault(rootPath: String = "~/AnigmaDaemon", environment: [String: String] = [:]) -> DaemonConfiguration {
        logWarning("[DaemonConfiguration stub] developmentDefault() called; this configuration is a stub and not fully implemented.", category: "DaemonConfiguration")
        return DaemonConfiguration(
            vault: VaultConfig(rootPath: rootPath, maxSizeGB: 10),
            daemon: DaemonConfig(
                bindHost: "127.0.0.1",
                bindPort: 8097,
                unixSocket: {
                    #if os(macOS)
                        return NSString(string: "~/Library/Caches/anigma/anigmad.sock").expandingTildeInPath
                    #elseif os(Linux)
                        if let xdgRuntime = environment["XDG_RUNTIME_DIR"] {
                            return "\(xdgRuntime)/anigmad.sock"
                        }
                        return NSString(string: "~/.cache/anigma/anigmad.sock").expandingTildeInPath
                    #else
                        return NSString(string: "~/.anigma/anigmad.sock").expandingTildeInPath
                    #endif
                }(),
                tcpEnabled: false,
                tlsEnabled: false,
                tlsCertificatePath: nil,
                tlsPrivateKeyPath: nil,
                corsAllowedOrigins: [],
                executionMode: .subprocess,
                maxClients: 128,
                shutdownTimeoutSeconds: 30,
                apiKeysEnabled: false,
                aneSchedulingEnabled: false,
                requireContractValidation: false,
                mlWorkerPath: nil,
                evidenceDirectory: nil,
                useMockML: false
            ),
            resources: ResourcesConfig(
                maxConcurrentJobs: 4,
                maxMemoryMB: 8192,
                workerProcesses: 4,
                maxANEUtilization: 80.0,
                thermalThreshold: 75.0,
                powerBudget: 10.0,
                maxFileSizeMB: 10,
                cacheSizeLimitMB: 100,
                timeoutSeconds: 60
            ),
            antigravity: AntigravityConfig(redirectPort: 8080),
            governance: GovernanceConfig(
                receiptStoreMode: .vault,
                generateExecutionReceipts: true,
                auditAllOperations: false
            ),
            environment: [:]
        )
    }

    public static var `default`: DaemonConfiguration {
        // Alignment: In a global static context, we may have to read ambient state once if not injected.
        // But prefer calling .from(arguments:environment:) instead.
        developmentDefault(environment: ProcessInfo.processInfo.environment)
    }
}

public typealias VaultConfig = DaemonConfiguration.VaultConfig
public typealias DaemonConfig = DaemonConfiguration.DaemonConfig
public typealias ResourcesConfig = DaemonConfiguration.ResourcesConfig
public typealias AntigravityConfig = DaemonConfiguration.AntigravityConfig
