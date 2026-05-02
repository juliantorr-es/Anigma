//
//  DaemonFirstCLIOrchestrator.swift
//  AnigmaCLIExecutable
//
//  Primary orchestrator for daemon-first CLI execution with local fallback.
//

import AnigmaCLIOrchestrator
import AnigmaCLIEventing
import AnigmaCLICore
import AnigmaCLIGovernance
import AnigmaCLIMCP
import AnigmaSidecar
import Foundation
import ArgumentParser

/// Configuration for daemon-first execution
public struct DaemonFirstConfig {
    public var useDaemon: Bool
    public var daemonURL: String?
    public var socketPath: String?
    public var localFallback: Bool
    public var healthCheckTimeout: TimeInterval
    public var maxRetries: Int
    
    public init(
        useDaemon: Bool = true,
        daemonURL: String? = nil,
        socketPath: String? = nil,
        localFallback: Bool = true,
        healthCheckTimeout: TimeInterval = 5.0,
        maxRetries: Int = 3
    ) {
        self.useDaemon = useDaemon
        self.daemonURL = daemonURL
        self.socketPath = socketPath
        self.localFallback = localFallback
        self.healthCheckTimeout = healthCheckTimeout
        self.maxRetries = maxRetries
    }
    
    /// Load configuration from environment variables
    public static func fromEnvironment() -> DaemonFirstConfig {
        let env = ProcessInfo.processInfo.environment
        
        return DaemonFirstConfig(
            useDaemon: env["ANIGMA_USE_DAEMON"]?.lowercased() != "false",
            daemonURL: env["ANIGMA_DAEMON_URL"],
            socketPath: env["ANIGMA_SOCKET"],
            localFallback: env["ANIGMA_LOCAL_FALLBACK"]?.lowercased() != "false",
            healthCheckTimeout: TimeInterval(env["ANIGMA_HEALTH_TIMEOUT"] ?? "5.0") ?? 5.0,
            maxRetries: Int(env["ANIGMA_MAX_RETRIES"] ?? "3") ?? 3
        )
    }
    
    /// Load configuration from command-line arguments
    public static func fromArguments(
        useDaemon: Bool? = nil,
        daemonURL: String? = nil,
        socketPath: String? = nil,
        localFallback: Bool? = nil
    ) -> DaemonFirstConfig {
        var config = fromEnvironment()
        
        if let useDaemon = useDaemon {
            config.useDaemon = useDaemon
        }
        
        if let daemonURL = daemonURL {
            config.daemonURL = daemonURL
        }
        
        if let socketPath = socketPath {
            config.socketPath = socketPath
        }
        
        if let localFallback = localFallback {
            config.localFallback = localFallback
        }
        
        return config
    }
}

/// Health status of daemon connection
public enum DaemonHealthStatus {
    case healthy
    case unhealthy(reason: String)
    case unavailable
}

/// Result of daemon operation
public enum DaemonOperationResult<T> {
    case daemonSuccess(T)
    case daemonFailure(error: Error)
    case localFallback(T)
    case localFailure(error: Error)
    
    /// Check if result is a daemon success
    public var isDaemonSuccess: Bool {
        if case .daemonSuccess = self {
            return true
        }
        return false
    }
    
    /// Get the value if successful (either daemon or local)
    public var value: T? {
        switch self {
        case .daemonSuccess(let value), .localFallback(let value):
            return value
        case .daemonFailure, .localFailure:
            return nil
        }
    }
    
    /// Get the error if failed
    public var error: Error? {
        switch self {
        case .daemonFailure(let error), .localFailure(let error):
            return error
        case .daemonSuccess, .localFallback:
            return nil
        }
    }
}

/// Primary orchestrator for daemon-first CLI execution
public actor DaemonFirstCLIOrchestrator {
    private let config: DaemonFirstConfig
    private let eventStream: CLIEventStream
    private var bridge: SidecarBridge?
    private var guardian: DaemonGuardian?
    private var isInitialized = false
    
    public init(config: DaemonFirstConfig, eventStream: CLIEventStream) {
        self.config = config
        self.eventStream = eventStream
    }
    
    /// Initialize daemon connection if configured
    private func initializeDaemon() async throws {
        guard config.useDaemon && !isInitialized else { return }
        
        let socketPath = config.socketPath ?? SidecarConfig.defaultUnixSocketPath()
        guardian = DaemonGuardian(socketPath: socketPath)
        
        do {
            try await guardian?.ensureDaemonRunning()
            
            let clientName = "anigma-cli-daemon-first"
            bridge = try await SidecarBridge.create(
                socketPath: socketPath,
                clientName: clientName
            )
            
            isInitialized = true
            await eventStream.emit(CLIEvent(kind: .info, message: "Daemon connection established"))
        } catch {
            await eventStream.emit(CLIEvent(kind: .warning, message: "Failed to initialize daemon: \(error)"))
            if !config.localFallback {
                throw error
            }
        }
    }
    
    /// Check daemon health
    public func checkDaemonHealth() async -> DaemonHealthStatus {
        guard let bridge = bridge else {
            return .unavailable
        }
        
        do {
            _ = try await bridge.getStatus()
            return .healthy
        } catch {
            return .unhealthy(reason: "Health check failed: \(error)")
        }
    }
    
    /// Execute a task with daemon-first logic
    public func executeTask(
        _ task: String,
        context: TaskContext,
        mode: ExecutionMode = .run,
        dryRun: Bool = false
    ) async -> DaemonOperationResult<RunOutcome> {
        do {
            try await initializeDaemon()
            
            if let bridge {
                // Execute via daemon
                let runner = RemoteOneShotRunner(bridge: bridge)
                let options = RemoteOneShotRunner.RunOptions(
                    verbose: false,
                    json: false
                )
                
                try await runner.execute(
                    task: task,
                    context: context,
                    options: options
                )

                let planResult = try await planLocal(task: task, context: context)
                switch planResult {
                case .localFallback(let plan):
                    let outcome = RunOutcome(
                        plan: plan,
                        governance: GovernanceDecision(allowed: true, issues: []),
                        dryRun: dryRun,
                        status: .running,
                        message: "Task executed via daemon"
                    )
                    return .daemonSuccess(outcome)
                case .localFailure(let error):
                    return .daemonFailure(error: error)
                case .daemonSuccess(let plan):
                    let outcome = RunOutcome(
                        plan: plan,
                        governance: GovernanceDecision(allowed: true, issues: []),
                        dryRun: dryRun,
                        status: .running,
                        message: "Task executed via daemon"
                    )
                    return .daemonSuccess(outcome)
                case .daemonFailure(let error):
                    return .daemonFailure(error: error)
                }
            } else if config.localFallback {
                // Fall back to local execution
                await eventStream.emit(CLIEvent(kind: .info, message: "Falling back to local execution"))
                return try await executeLocal(task: task, context: context, mode: mode, dryRun: dryRun)
            } else {
                throw NSError(domain: "DaemonFirstCLIOrchestrator", code: 1, 
                            userInfo: [NSLocalizedDescriptionKey: "Daemon unavailable and local fallback disabled"])
            }
        } catch {
            if config.localFallback {
                await eventStream.emit(CLIEvent(kind: .warning, message: "Daemon execution failed, attempting local fallback: \(error)"))
                do {
                    return try await executeLocal(task: task, context: context, mode: mode, dryRun: dryRun)
                } catch {
                    return .localFailure(error: error)
                }
            } else {
                return .daemonFailure(error: error)
            }
        }
    }
    
    /// Plan a task with daemon-first logic
    public func planTask(
        _ task: String,
        context: TaskContext
    ) async -> DaemonOperationResult<PlanOutcome> {
        do {
            try await initializeDaemon()
            
            if bridge != nil {
                // Plan via daemon
                // Note: This requires daemon-side planning support
                // For now, fall back to local
                await eventStream.emit(CLIEvent(kind: .info, message: "Planning via daemon not yet implemented, using local fallback"))
                return try await planLocal(task: task, context: context)
            } else if config.localFallback {
                return try await planLocal(task: task, context: context)
            } else {
                throw NSError(domain: "DaemonFirstCLIOrchestrator", code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Daemon unavailable and local fallback disabled"])
            }
        } catch {
            if config.localFallback {
                await eventStream.emit(CLIEvent(kind: .warning, message: "Daemon planning failed, attempting local fallback: \(error)"))
                do {
                    return try await planLocal(task: task, context: context)
                } catch {
                    return .localFailure(error: error)
                }
            } else {
                return .daemonFailure(error: error)
            }
        }
    }

    /// Plan a task with review artifacts using daemon-first logic.
    public func planTask(
        _ task: String,
        context: TaskContext,
        reviewers: Int,
        reviewMode: PlanReviewMode
    ) async -> DaemonOperationResult<PlanReviewOutcome> {
        do {
            try await initializeDaemon()

            if bridge != nil {
                await eventStream.emit(
                    CLIEvent(
                        kind: .info,
                        message: "Planning reviews via daemon not yet implemented, using local fallback"
                    )
                )
                return try await planLocalReviewed(
                    task: task,
                    context: context,
                    reviewers: reviewers,
                    reviewMode: reviewMode
                )
            } else if config.localFallback {
                return try await planLocalReviewed(
                    task: task,
                    context: context,
                    reviewers: reviewers,
                    reviewMode: reviewMode
                )
            } else {
                throw NSError(
                    domain: "DaemonFirstCLIOrchestrator",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Daemon unavailable and local fallback disabled"]
                )
            }
        } catch {
            if config.localFallback {
                await eventStream.emit(
                    CLIEvent(
                        kind: .warning,
                        message: "Daemon planning with reviews failed, attempting local fallback: \(error)"
                    )
                )
                do {
                    return try await planLocalReviewed(
                        task: task,
                        context: context,
                        reviewers: reviewers,
                        reviewMode: reviewMode
                    )
                } catch {
                    return .localFailure(error: error)
                }
            } else {
                return .daemonFailure(error: error)
            }
        }
    }
    
    /// Execute locally (fallback)
    private func executeLocal(
        task: String,
        context: TaskContext,
        mode: ExecutionMode,
        dryRun: Bool
    ) async throws -> DaemonOperationResult<RunOutcome> {
        let taskIntent = TaskIntent(summary: task, details: nil)
        let localOrchestrator = makeLocalOrchestrator(enableMcp: true)
        
        let outcome = try await localOrchestrator.run(
            task: taskIntent,
            context: context,
            dryRun: dryRun
        )
        
        return .localFallback(outcome)
    }
    
    /// Plan locally (fallback)
    private func planLocal(
        task: String,
        context: TaskContext
    ) async throws -> DaemonOperationResult<PlanOutcome> {
        let taskIntent = TaskIntent(summary: task, details: nil)
        let localOrchestrator = makeLocalOrchestrator(enableMcp: true)
        
        let outcome = try await localOrchestrator.plan(
            task: taskIntent,
            context: context
        )

        return .localFallback(outcome)
    }

    private func planLocalReviewed(
        task: String,
        context: TaskContext,
        reviewers: Int,
        reviewMode: PlanReviewMode
    ) async throws -> DaemonOperationResult<PlanReviewOutcome> {
        let taskIntent = TaskIntent(summary: task, details: nil)
        let localOrchestrator = makeLocalOrchestrator(enableMcp: true)

        let outcome = try await localOrchestrator.planWithReview(
            task: taskIntent,
            context: context,
            reviewers: reviewers,
            reviewMode: reviewMode
        )

        return .localFallback(outcome)
    }
    
    /// Create local orchestrator for fallback
    private func makeLocalOrchestrator(enableMcp: Bool) -> AnigmaCLIOrchestrator {
        let fallback = LocalContractBuilder()
        
        guard enableMcp else {
            return AnigmaCLIOrchestrator(
                contractBuilder: fallback,
                eventStream: eventStream
            )
        }
        
        let baseConfig = MCPContractBuilderConfiguration.fromEnvironment()
        let config = MCPContractBuilderConfiguration(
            enabled: baseConfig.enabled && enableMcp,
            includeDigest: baseConfig.includeDigest,
            maxTokens: baseConfig.maxTokens,
            temperature: baseConfig.temperature
        )
        let mcpBuilder = MCPContractBuilder(
            configuration: config,
            eventStream: eventStream,
            fallback: fallback
        )
        
        return AnigmaCLIOrchestrator(
            contractBuilder: mcpBuilder,
            eventStream: eventStream
        )
    }
    
    /// Get daemon status information
    public func getDaemonStatus() async -> [String: Any] {
        let health = await checkDaemonHealth()
        var status: [String: Any] = [
            "useDaemon": config.useDaemon,
            "localFallback": config.localFallback,
            "initialized": isInitialized
        ]
        
        switch health {
        case .healthy:
            status["health"] = "healthy"
        case .unhealthy(let reason):
            status["health"] = "unhealthy"
            status["reason"] = reason
        case .unavailable:
            status["health"] = "unavailable"
        }
        
        if let socketPath = config.socketPath {
            status["socketPath"] = socketPath
        }
        
        if let daemonURL = config.daemonURL {
            status["daemonURL"] = daemonURL
        }
        
        return status
    }
}

/// Command-line arguments for daemon control
public struct DaemonOptions: ParsableArguments {
    @Flag(name: .long, help: "Use daemon for execution (default: true).")
    public var daemon: Bool = true
    
    @Flag(name: .long, help: "Force local execution (overrides --daemon).")
    public var local: Bool = false
    
    @Option(name: .long, help: "Daemon URL (overrides ANIGMA_DAEMON_URL).")
    public var daemonURL: String?
    
    @Option(name: .long, help: "Unix socket path (overrides ANIGMA_SOCKET).")
    public var socketPath: String?
    
    @Flag(name: .long, help: "Disable local fallback when daemon is unavailable.")
    public var noLocalFallback: Bool = false
    
    @Flag(name: .long, help: "Show daemon health status.")
    public var health: Bool = false
    
    public init() {}
    
    /// Convert to DaemonFirstConfig
    public func toConfig() -> DaemonFirstConfig {
        return DaemonFirstConfig.fromArguments(
            useDaemon: local ? false : daemon,
            daemonURL: daemonURL,
            socketPath: socketPath,
            localFallback: !noLocalFallback
        )
    }
}

/// Helper to create DaemonFirstCLIOrchestrator with proper configuration
public func makeDaemonFirstOrchestrator(
    daemonOptions: DaemonOptions? = nil,
    eventStream: CLIEventStream
) -> DaemonFirstCLIOrchestrator {
    let config: DaemonFirstConfig
    if let options = daemonOptions {
        config = options.toConfig()
    } else {
        config = DaemonFirstConfig.fromEnvironment()
    }
    
    return DaemonFirstCLIOrchestrator(config: config, eventStream: eventStream)
}
