//
//  PostgresTestcontainers.swift
//  DatabaseCore
//
//  Testcontainers setup for PostgreSQL integration tests.
//  Uses testcontainers-swift if available, otherwise provides mock implementations.
//
//  See td-8643ef: Set up Testcontainers for PostgreSQL
//  See td-89a996: PostgreSQL First-Class Implementation Epic
//

import Foundation

// MARK: - Container Configuration

/// PostgreSQL container configuration
public struct PostgresContainerConfig: Sendable, Codable {
    public let image: String
    public let tag: String
    public let username: String
    public let password: String
    public let database: String
    public let port: Int
    public let env: [String: String]
    
    public static let `default` = PostgresContainerConfig(
        image: "postgres",
        tag: "16-alpine",
        username: "testuser",
        password: "testpass",
        database: "testdb",
        port: 5432,
        env: [
            "POSTGRES_USER": "testuser",
            "POSTGRES_PASSWORD": "testpass",
            "POSTGRES_DB": "testdb"
        ]
    )
    
    public init(
        image: String = "postgres",
        tag: String = "16-alpine",
        username: String = "testuser",
        password: String = "testpass",
        database: String = "testdb",
        port: Int = 5432,
        env: [String: String] = [:]
    ) {
        self.image = image
        self.tag = tag
        self.username = username
        self.password = password
        self.database = database
        self.port = port
        self.env = env
    }
    
    public var fullImage: String {
        "\(image):\(tag)"
    }
    
    public var connectionString: String {
        "postgresql://\(username):\(password)@localhost:\(port)/\(database)"
    }
}

// MARK: - Container State

/// State of a PostgreSQL container
public enum PostgresContainerState: String, Sendable, Codable {
    case notStarted
    case starting
    case running
    case stopped
    case failed
    case removed
}

/// PostgreSQL container information
public struct PostgresContainerInfo: Sendable, Codable {
    public let id: String
    public let name: String
    public var state: PostgresContainerState
    public let config: PostgresContainerConfig
    public let mappedPort: Int?
    public let createdAt: Date
    public var startedAt: Date?
    
    public init(
        id: String,
        name: String,
        state: PostgresContainerState,
        config: PostgresContainerConfig,
        mappedPort: Int? = nil,
        createdAt: Date = Date(),
        startedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.state = state
        self.config = config
        self.mappedPort = mappedPort
        self.createdAt = createdAt
        self.startedAt = startedAt
    }
}

// MARK: - Container Manager

/// Manages PostgreSQL test containers
/// This is a protocol to allow for different implementations:
/// - Real Testcontainers (testcontainers-swift)
/// - Docker CLI
/// - Mock/In-memory for CI environments without Docker
public protocol PostgresContainerManager: Sendable {
    /// Start a PostgreSQL container
    func start(config: PostgresContainerConfig) async throws -> PostgresContainerInfo
    
    /// Stop a running container
    func stop(_ containerID: String) async throws
    
    /// Stop all containers managed by this instance
    func stopAll() async throws
    
    /// Get container info
    func getInfo(_ containerID: String) async throws -> PostgresContainerInfo?
    
    /// Check if container is running
    func isRunning(_ containerID: String) async throws -> Bool
    
    /// Check if container is healthy
    func isHealthy(_ containerID: String) async throws -> Bool
    
    /// Execute a command in the container
    func exec(_ containerID: String, command: [String]) async throws -> String
    
    /// Get logs from container
    func logs(_ containerID: String, since: Date?) async throws -> String
}

// MARK: - Default Implementation (Docker CLI)

/// Default implementation using Docker CLI
/// Requires docker to be installed and accessible
public final actor DefaultPostgresContainerManager: PostgresContainerManager {
    private var containers: [String: PostgresContainerInfo] = [:]
    private let processRunner: ProcessRunner
    
    public init(processRunner: ProcessRunner = DefaultProcessRunner()) {
        self.processRunner = processRunner
    }
    
    public func start(config: PostgresContainerConfig) async throws -> PostgresContainerInfo {
        let containerName = "anigma-test-postgres-{" + UUID().uuidString.prefix(8) + "}"
        let fullImage = config.fullImage
        
        // Build docker run command
        var args: [String] = [
            "run",
            "-d",
            "--name", containerName,
            "-e", "POSTGRES_USER=\(config.username)",
            "-e", "POSTGRES_PASSWORD=\(config.password)",
            "-e", "POSTGRES_DB=\(config.database)",
            "-p", "\(config.port):5432",
            "--health-cmd", "pg_isready -U \(config.username) -d \(config.database)",
            "--health-interval", "5s",
            "--health-timeout", "5s",
            "--health-retries", "5"
        ]
        
        // Add additional env
        for (key, value) in config.env {
            args.append(contentsOf: ["-e", "\(key)=\(value)"])
        }
        
        args.append(fullImage)
        args.append("postgres")
        args.append("-c")
        args.append("max_connections=100")
        
        // Run docker command
        let output = try await processRunner.run("docker", arguments: args)
        
        // Extract container ID from output
        let containerID = output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let info = PostgresContainerInfo(
            id: containerID,
            name: containerName,
            state: .starting,
            config: config,
            mappedPort: config.port,
            createdAt: Date()
        )
        
        containers[containerID] = info
        
        // Wait for healthy
        try await waitForHealthy(containerID: containerID, timeout: 30)
        
        var updatedInfo = info
        updatedInfo.state = .running
        updatedInfo.startedAt = Date()
        containers[containerID] = updatedInfo
        
        return updatedInfo
    }
    
    public func stop(_ containerID: String) async throws {
        _ = try await processRunner.run("docker", arguments: ["stop", containerID])
        
        if var info = containers[containerID] {
            info.state = .stopped
            containers[containerID] = info
        }
    }
    
    public func stopAll() async throws {
        let containerIDs = containers.keys
        
        for id in containerIDs {
            try await stop(id)
        }
    }
    
    public func getInfo(_ containerID: String) async throws -> PostgresContainerInfo? {
        return containers[containerID]
    }
    
    public func isRunning(_ containerID: String) async throws -> Bool {
        guard let info = try await getInfo(containerID) else { return false }
        if info.state == .running {
            return true
        }
        // Check actual docker state
        do {
            let output = try await processRunner.run("docker", arguments: ["ps", "-q", "--filter", "id=\(containerID)"])
            return !output.isEmpty
        } catch {
            return false
        }
    }
    
    public func isHealthy(_ containerID: String) async throws -> Bool {
        do {
            let output = try await processRunner.run("docker", arguments: ["inspect", "--format={{.State.Health.Status}},\(containerID)"])
            return output.contains("healthy")
        } catch {
            return false
        }
    }
    
    public func exec(_ containerID: String, command: [String]) async throws -> String {
        try await processRunner.run("docker", arguments: ["exec", containerID] + command)
    }
    
    public func logs(_ containerID: String, since: Date? = nil) async throws -> String {
        var args = ["logs", containerID]
        if let since {
            let formatter = ISO8601DateFormatter()
            args.append(contentsOf: ["--since", formatter.string(from: since)])
        }
        return try await processRunner.run("docker", arguments: args)
    }
    
    // MARK: - Private
    
    private func waitForHealthy(containerID: String, timeout: TimeInterval) async throws {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            do {
                if try await isHealthy(containerID) {
                    return
                }
            } catch {
                // Ignore errors, try again
            }
            try await Task.sleep(nanoseconds: UInt64(1_000_000_000)) // 1 second
        }
        throw PostgresContainerError.healthCheckTimeout(containerID)
    }
}

// MARK: - Testcontainers with psql

/// High-level API for running PostgreSQL tests with containers
public final actor PostgresTestcontainers {
    private let containerManager: PostgresContainerManager
    private var currentContainer: PostgresContainerInfo?
    
    public init(containerManager: PostgresContainerManager = DefaultPostgresContainerManager()) {
        self.containerManager = containerManager
    }
    
    /// Start a PostgreSQL container for testing
    public func start(config: PostgresContainerConfig = .default) async throws -> PostgresContainerInfo {
        if let container = currentContainer, try await containerManager.isRunning(container.id) {
            return container
        }
        
        let container = try await containerManager.start(config: config)
        currentContainer = container
        return container
    }
    
    /// Stop the current container
    public func stop() async throws {
        if let container = currentContainer {
            try await containerManager.stop(container.id)
            currentContainer = nil
        }
    }
    
    /// Get connection string for the current container
    public func getConnectionString() throws -> String {
        guard let container = currentContainer else {
            throw PostgresContainerError.noContainerRunning
        }
        return container.config.connectionString
    }
    
    /// Get a DatabaseExecutor for the current container
    public func getDatabaseExecutor() async throws -> any DatabaseExecutor {
        let connectionString = try getConnectionString()
        return DatabaseActor(path: connectionString)
    }
    
    /// Run a test with a container
    public func runTest<T: Sendable>(
        config: PostgresContainerConfig = .default,
        _ testBlock: @escaping @Sendable (any DatabaseExecutor) async throws -> T
    ) async throws -> T {
        let _ = try await start(config: config)
        defer {
            Task {
                try? await stop()
            }
        }
        
        let database = try await getDatabaseExecutor()
        return try await testBlock(database)
    }
}

// MARK: - Process Runner Protocol

/// Protocol for running external processes
public protocol ProcessRunner: Sendable {
    func run(_ executable: String, arguments: [String]) async throws -> String
}

/// Default process runner using Process
public struct DefaultProcessRunner: ProcessRunner {
    public init() {}
    
    public func run(_ executable: String, arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output
            }
            return ""
        } catch {
            throw PostgresContainerError.processFailed(executable, arguments, error)
        }
    }
}

// MARK: - Errors

public enum PostgresContainerError: Error, CustomStringConvertible, Sendable {
    case noContainerRunning
    case containerNotFound(String)
    case containerAlreadyRunning(String)
    case containerStartFailed(String, String)
    case healthCheckTimeout(String)
    case processFailed(String, [String], Error)
    
    public var description: String {
        switch self {
        case .noContainerRunning: return "No PostgreSQL container is running"
        case let .containerNotFound(id): return "Container not found: \(id)"
        case let .containerAlreadyRunning(id): return "Container already running: \(id)"
        case let .containerStartFailed(id, err): return "Container \(id) start failed: \(err)"
        case let .healthCheckTimeout(id): return "Container \(id) health check timed out"
        case let .processFailed(exec, args, err): return "Process \(exec) \(args) failed: \(err)"
        }
    }
}

// MARK: - Mock Implementation

/// Mock container manager for CI environments without Docker
public final actor MockPostgresContainerManager: PostgresContainerManager {
    public func start(config: PostgresContainerConfig) async throws -> PostgresContainerInfo {
        // In mock mode, just return a fake container
        // Real tests would connect to a pre-configured PostgreSQL instance
        return PostgresContainerInfo(
            id: "mock-\(UUID().uuidString)",
            name: "mock-postgres",
            state: .running,
            config: config,
            mappedPort: config.port,
            createdAt: Date(),
            startedAt: Date()
        )
    }
    
    public func stop(_ containerID: String) async throws {}
    
    public func stopAll() async throws {}
    
    public func getInfo(_ containerID: String) async throws -> PostgresContainerInfo? {
        nil
    }
    
    public func isRunning(_ containerID: String) async throws -> Bool {
        false
    }
    
    public func isHealthy(_ containerID: String) async throws -> Bool {
        false
    }
    
    public func exec(_ containerID: String, command: [String]) async throws -> String {
        ""
    }
    
    public func logs(_ containerID: String, since: Date?) async throws -> String {
        ""
    }
}
