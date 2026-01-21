//
//  DaemonConfiguration.swift
//  AnigmaDaemonCore
//
//  Configuration for the Anigma sidecar daemon.
//

import Foundation

/// Configuration for the Anigma sidecar daemon.
public struct DaemonConfiguration: Codable, Sendable {
    public let daemon: DaemonConfig
    public let vault: VaultConfig
    public let governance: GovernanceConfig
    public let resources: ResourceConfig
    public let telemetry: TelemetryConfig

    public init(
        daemon: DaemonConfig = .default,
        vault: VaultConfig = .default,
        governance: GovernanceConfig = .default,
        resources: ResourceConfig = .default,
        telemetry: TelemetryConfig = .default
    ) {
        self.daemon = daemon
        self.vault = vault
        self.governance = governance
        self.resources = resources
        self.telemetry = telemetry
    }

    public static let `default` = DaemonConfiguration()
}

/// Daemon server configuration
public struct DaemonConfig: Codable, Sendable {
    /// Bind host (default: 127.0.0.1)
    public let bindHost: String

    /// Bind port (default: 50051)
    public let bindPort: Int

    /// Unix socket path (platform-aware default)
    public let unixSocket: String

    /// Enable TCP transport (default: false)
    public let tcpEnabled: Bool

    /// Enable TLS encryption for TCP transport (default: false, requires tcpEnabled: true)
    public let tlsEnabled: Bool

    /// Path to TLS certificate file (PEM format)
    public let tlsCertificatePath: String?

    /// Path to TLS private key file (PEM format)
    public let tlsPrivateKeyPath: String?

    /// CORS allowed origins (empty array means no CORS)
    public let corsAllowedOrigins: [String]

    /// Enable API key authentication for web/mobile access (default: false)
    public let apiKeysEnabled: Bool

    /// Default scopes granted to new API keys
    public let apiKeyDefaultScopes: [String]

    /// API key expiry in days (0 for no expiry)
    public let apiKeyExpiryDays: Int

    /// Job execution mode for workers (default: subprocess)
    public let executionMode: ExecutionMode

    /// Maximum concurrent clients
    public let maxClients: Int

    /// Shutdown timeout in seconds
    public let shutdownTimeoutSeconds: Int

    public init(
        bindHost: String = "127.0.0.1",
        bindPort: Int = 50051,
        unixSocket: String? = nil,
        tcpEnabled: Bool = false,
        tlsEnabled: Bool = false,
        tlsCertificatePath: String? = nil,
        tlsPrivateKeyPath: String? = nil,
        corsAllowedOrigins: [String] = [],
        apiKeysEnabled: Bool = false,
        apiKeyDefaultScopes: [String] = ["system.read", "vault.read", "job.read", "audit.read"],
        apiKeyExpiryDays: Int = 90,
        executionMode: ExecutionMode = .subprocess,
        maxClients: Int = 100,
        shutdownTimeoutSeconds: Int = 30
    ) {
        precondition(!tlsEnabled || tcpEnabled, "tlsEnabled requires tcpEnabled to be true")
        self.bindHost = bindHost
        self.bindPort = bindPort
        self.unixSocket = unixSocket ?? Self.defaultUnixSocketPath()
        self.tcpEnabled = tcpEnabled
        self.tlsEnabled = tlsEnabled
        self.tlsCertificatePath = tlsCertificatePath
        self.tlsPrivateKeyPath = tlsPrivateKeyPath
        self.corsAllowedOrigins = corsAllowedOrigins
        self.apiKeysEnabled = apiKeysEnabled
        self.apiKeyDefaultScopes = apiKeyDefaultScopes
        self.apiKeyExpiryDays = apiKeyExpiryDays
        self.executionMode = executionMode
        self.maxClients = maxClients
        self.shutdownTimeoutSeconds = shutdownTimeoutSeconds
    }

    /// Platform-aware default Unix socket path
    public static func defaultUnixSocketPath() -> String {
        #if os(macOS)
            return NSString(string: "~/Library/Caches/anigma/anigmad.sock").expandingTildeInPath
        #elseif os(Linux)
            if let xdgRuntime = ProcessInfo.processInfo.environment["XDG_RUNTIME_DIR"] {
                return "\(xdgRuntime)/anigmad.sock"
            }
            return NSString(string: "~/.cache/anigma/anigmad.sock").expandingTildeInPath
        #else
            return NSString(string: "~/.anigma/anigmad.sock").expandingTildeInPath
        #endif
    }

    public static let `default` = DaemonConfig()

    enum CodingKeys: String, CodingKey {
        case bindHost = "bind_host"
        case bindPort = "bind_port"
        case unixSocket = "unix_socket"
        case tcpEnabled = "tcp_enabled"
        case tlsEnabled = "tls_enabled"
        case tlsCertificatePath = "tls_certificate_path"
        case tlsPrivateKeyPath = "tls_private_key_path"
        case corsAllowedOrigins = "cors_allowed_origins"
        case apiKeysEnabled = "api_keys_enabled"
        case apiKeyDefaultScopes = "api_key_default_scopes"
        case apiKeyExpiryDays = "api_key_expiry_days"
        case executionMode = "execution_mode"
        case maxClients = "max_clients"
        case shutdownTimeoutSeconds = "shutdown_timeout_seconds"
    }
}

/// Vault storage configuration
public struct VaultConfig: Codable, Sendable {
    public let rootPath: String
    public let maxSizeGB: Int
    public let encryptionEnabled: Bool

    public init(
        rootPath: String = "~/.anigma/vault",
        maxSizeGB: Int = 100,
        encryptionEnabled: Bool = true
    ) {
        self.rootPath = rootPath
        self.maxSizeGB = maxSizeGB
        self.encryptionEnabled = encryptionEnabled
    }

    public static let `default` = VaultConfig()

    enum CodingKeys: String, CodingKey {
        case rootPath = "root_path"
        case maxSizeGB = "max_size_gb"
        case encryptionEnabled = "encryption_enabled"
    }
}

/// Governance policy configuration
public struct GovernanceConfig: Codable, Sendable {
    public let policyPath: String
    public let strictMode: Bool
    public let auditAllOperations: Bool
    public let receiptStoreMode: ReceiptStoreMode

    public init(
        policyPath: String = "~/.anigma/policies",
        strictMode: Bool = true,
        auditAllOperations: Bool = true,
        receiptStoreMode: ReceiptStoreMode = .vault
    ) {
        self.policyPath = policyPath
        self.strictMode = strictMode
        self.auditAllOperations = auditAllOperations
        self.receiptStoreMode = receiptStoreMode
    }

    public static let `default` = GovernanceConfig()

    enum CodingKeys: String, CodingKey {
        case policyPath = "policy_path"
        case strictMode = "strict_mode"
        case auditAllOperations = "audit_all_operations"
        case receiptStoreMode = "receipt_store_mode"
    }
}

/// Worker execution modes for daemon job processing.
public enum ExecutionMode: String, Codable, Sendable {
    /// Execute jobs in a subprocess worker.
    case subprocess = "subprocess"
    /// Execute jobs in-process with direct vault access.
    case inProcess = "in_process"
}

/// Receipt store backing for the daemon receipt engine.
public enum ReceiptStoreMode: String, Codable, Sendable {
    /// Store receipts in the vault as immutable artifacts.
    case vault = "vault"
    /// Store receipts in-memory for development or tests.
    case inMemory = "in_memory"
}

/// Resource management configuration
public struct ResourceConfig: Codable, Sendable {
    public let maxMemoryMB: Int
    public let maxConcurrentJobs: Int
    public let maxConcurrentGPUJobs: Int
    public let workerProcesses: Int

    public init(
        maxMemoryMB: Int = 4096,
        maxConcurrentJobs: Int = 8,
        maxConcurrentGPUJobs: Int = 2,
        workerProcesses: Int = 4
    ) {
        self.maxMemoryMB = maxMemoryMB
        self.maxConcurrentJobs = maxConcurrentJobs
        self.maxConcurrentGPUJobs = maxConcurrentGPUJobs
        self.workerProcesses = workerProcesses
    }

    public static let `default` = ResourceConfig()

    enum CodingKeys: String, CodingKey {
        case maxMemoryMB = "max_memory_mb"
        case maxConcurrentJobs = "max_concurrent_jobs"
        case maxConcurrentGPUJobs = "max_concurrent_gpu_jobs"
        case workerProcesses = "worker_processes"
    }
}

/// Telemetry configuration
public struct TelemetryConfig: Codable, Sendable {
    public let enabled: Bool
    public let exportIntervalSeconds: Int
    public let retentionDays: Int

    public init(
        enabled: Bool = true,
        exportIntervalSeconds: Int = 60,
        retentionDays: Int = 30
    ) {
        self.enabled = enabled
        self.exportIntervalSeconds = exportIntervalSeconds
        self.retentionDays = retentionDays
    }

    public static let `default` = TelemetryConfig()

    enum CodingKeys: String, CodingKey {
        case enabled
        case exportIntervalSeconds = "export_interval_seconds"
        case retentionDays = "retention_days"
    }
}
