//
//  SecurityAwareMigrationEngineFactory.swift
//  HarmoniaModuleExperimental
//
//  HarmoniaModule/Security
//
//  Factory that creates security-wrapped migration engines.
//  No engine runs naked - all engines go through the complete security spine.
//

import Foundation
import AnigmaCore // Import AnigmaCore for all moved types
import SQLite3
import HarmoniaModule
import AnigmaPrimitives

// MARK: - Security-Aware Factory

/// Factory that creates migration engines wrapped in security layers.
/// Order of wrapping: Base → Doctrine → Capability → Isolation → Provenance
public struct SecurityAwareMigrationEngineFactory {
    private var capabilityValidator: CapabilityValidating
    private let doctrineScout: ConcreteLawComplianceScout
    private let secretVault: SecretVault?
    private let auditLogger: AnigmaCore.AuditLogger
    private let traceSink: MigrationTraceSink

    public init(
        capabilityValidator: CapabilityValidating = DumbCapabilityValidator(securityEvents: AnigmaCore.SecurityEventsManager()),
        doctrineScout: ConcreteLawComplianceScout = ConcreteLawComplianceScout(),
        secretVault: SecretVault? = nil,
        auditLogger: AnigmaCore.AuditLogger = AnigmaCore.AuditLogger(),
        traceSink: MigrationTraceSink = NoopMigrationTraceSink()
    ) {
        self.capabilityValidator = capabilityValidator
        self.doctrineScout = doctrineScout
        self.auditLogger = auditLogger
        self.traceSink = traceSink

        // Try to create secret vault, but use nil if it fails (for testing)
        do {
            self.secretVault = try secretVault ?? SecretVault()
        } catch {
            print("[WARNING] Failed to create SecretVault: \(error). Secret operations will be disabled.")
            self.secretVault = nil
        }
    }

    /// Create a security-wrapped migration engine for the given task.
    /// - Parameter task: Migration task to process
    /// - Returns: Security-wrapped engine, or blocked engine if capabilities insufficient
    public func engine(for task: AnigmaCore.MigrationTaskRow) -> (any AnigmaCore.MigrationEngine)? {
        logInfo("Creating security-wrapped engine for task \(task.id)", category: "SecurityFactory")

        // 1. Get base engine
        guard let baseEngine = MigrationEngineFactory.engine(for: task, traceSink: traceSink) else {
            logError("No base engine found for task category: \(task.featureCategory)", category: "SecurityFactory")
            return nil
        }

        // 2. Analyze task to determine requirements
        let (engineType, requiredCapabilities) = TaskCapabilityAnalyzer.analyze(task)
        let zone = TaskCapabilityAnalyzer.determineZone(for: task)
        let trustTier = task.trustTier ?? AnigmaCore.TrustTier.bronze

        logInfo("Task analysis: type=\(engineType.rawValue), zone=\(zone.rawValue), trust=\(trustTier.rawValue)", category: "SecurityFactory")
        logInfo("Required capabilities: \(requiredCapabilities.map { $0.rawValue }.joined(separator: ", "))", category: "SecurityFactory")

        // 3. Validate capabilities BEFORE any wrapping
        let validationResult: AnigmaCore.ValidationResult
        do {
            // Create capability context for audit logging
            let context = CapabilityContext(
                engineId: "migration-\(task.id)",
                projectId: task.projectId?.uuidString,
                taskId: task.id,
                filePath: task.filePath ?? task.path ?? task.pathDetail
            )

            validationResult = try capabilityValidator.validate(
                engineType: engineType,
                requestedCapabilities: requiredCapabilities,
                currentZone: zone,
                claimedTier: trustTier,
                context: context
            )
        } catch {
            logError("Capability validation failed: \(error)", category: "SecurityFactory")
            return BlockedMigrationEngine(
                reason: "Capability validation error: \(error.localizedDescription)",
                taskId: task.id,
                engineType: engineType
            )
        }

        // 4. Handle invalid capability validation
        guard validationResult.isValid else {
            logError("Capability validation invalid: \(validationResult.reason ?? "unknown")", category: "SecurityFactory")

            // Create capability debt task for blocking violation
            if let reason = validationResult.reason {
                createCapabilityDebtTask(
                    task: task,
                    reason: reason,
                    engineType: engineType,
                    requiredCapabilities: requiredCapabilities
                )
            }

            return BlockedMigrationEngine(
                reason: validationResult.reason ?? "Capability check failed",
                taskId: task.id,
                engineType: engineType
            )
        }

        // 5. Extract capability grant if validation passed
        let capabilityGrant: AnigmaCore.CapabilityGrant?
        if case .valid(let grant) = validationResult {
            capabilityGrant = grant
            logInfo("Capability grant issued: \(grant?.id.uuidString ?? "none")", category: "SecurityFactory")
        } else {
            capabilityGrant = nil
        }

        // 6. Build security-wrapped engine (order matters!)
        var engine: any AnigmaCore.MigrationEngine = baseEngine

        // Layer 1: Doctrine checks (safety before capability enforcement)
        engine = DoctrineAwareMigrationEngineWrapper(
            baseEngine: engine,
            lawComplianceScout: doctrineScout
        )

        // Layer 2: Process isolation (capability enforcement)
        let sandboxConfig = createSandboxConfig(
            for: task,
            capabilities: requiredCapabilities,
            zone: zone,
            capabilityGrant: capabilityGrant
        )

        engine = IsolatedMigrationEngine(
            baseEngine: engine,
            config: sandboxConfig,
            engineId: "\(engineType.rawValue)-\(task.id)"
        )

        // Layer 3: Provenance signing (audit what actually ran)
        engine = ProvenanceAwareMigrationEngine(
            baseEngine: engine,
            engineId: "signed-\(task.id)"
        )

        // Layer 4: Audit logging wrapper (capture all operations)
        engine = AuditedMigrationEngine(
            baseEngine: engine,
            auditLogger: auditLogger,
            taskId: task.id,
            engineType: engineType,
            capabilityGrant: capabilityGrant
        )

        logInfo("Security-wrapped engine created successfully for task \(task.id)", category: "SecurityFactory")
        return engine
    }

    /// Create sandbox configuration based on capabilities.
    private func createSandboxConfig(
        for task: AnigmaCore.MigrationTaskRow,
        capabilities: [AnigmaCore.GranularCapability],
        zone: AnigmaCore.SecurityZone,
        capabilityGrant: AnigmaCore.CapabilityGrant?
    ) -> AnigmaCore.SandboxConfig {
        let projectPath: String
        if let filePath = task.filePath, let url = URL(fileURLWithPath: filePath) {
            projectPath = url.deletingLastPathComponent().path
        } else {
            projectPath = FileManager.default.currentDirectoryPath
        }

        // Determine sandbox type based on capabilities
        let hasNetwork = capabilities.contains { $0.category == .network }
        let hasWrite = capabilities.contains { $0 == .fsWriteSource || $0 == .fsWriteGenerated }
        let hasGit = capabilities.contains { $0.category == .git }

        if hasNetwork {
            // Network engine sandbox
            var allowedEndpoints: [String] = []

            if capabilities.contains(.netGitHubApiRead) || capabilities.contains(.netGitHubApiWrite) {
                allowedEndpoints.append("https://api.github.com")
            }
            if capabilities.contains(.netRawGithub) {
                allowedEndpoints.append("https://raw.githubusercontent.com")
            }
            if capabilities.contains(.netOpenAiApi) {
                allowedEndpoints.append("https://api.openai.com")
            }
            if capabilities.contains(.netHuggingfaceApi) {
                allowedEndpoints.append("https://huggingface.co")
            }
            if capabilities.contains(.netHttpGet) || capabilities.contains(.netHttpPost) {
                // Generic HTTP - be conservative
                allowedEndpoints.append(contentsOf: [])
            }

            return AnigmaCore.SandboxConfig.networkEngineSandbox(
                projectPath: projectPath,
                allowedEndpoints: allowedEndpoints
            )

        } else if hasWrite || hasGit {
            // Mutation engine sandbox
            return AnigmaCore.SandboxConfig.mutationEngineSandbox(projectPath: projectPath)

        } else {
            // Read-only sandbox (most restrictive)
            return AnigmaCore.SandboxConfig.readOnlySandbox(projectPath: projectPath)
        }
    }

    /// Create a capability debt task for blocking violations.
    private func createCapabilityDebtTask(
        task: AnigmaCore.MigrationTaskRow,
        reason: String,
        engineType: AnigmaCore.EngineType,
        requiredCapabilities: [AnigmaCore.GranularCapability]
    ) {
        logWarning("Creating capability debt task for blocked engine", category: "SecurityFactory")

        // In practice, this would create a database entry
        // For Phase 1, just log it
        let debtTask: [String: Any] = [
            "task_id": task.id,
            "engine_type": engineType.rawValue,
            "reason": reason,
            "required_capabilities": requiredCapabilities.map { $0.rawValue },
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]

        if let debtData = try? JSONSerialization.data(withJSONObject: debtTask, options: .prettyPrinted),
           let debtString = String(data: debtData, encoding: .utf8) {
            logInfo("Capability debt task:\n\(debtString)", category: "SecurityFactory")
        }
    }
}

// MARK: - Audited Migration Engine

/// Migration engine wrapper that logs all operations for audit trail.
private struct AuditedMigrationEngine: AnigmaCore.MigrationEngine {
    private let baseEngine: AnigmaCore.MigrationEngine
    private let auditLogger: AnigmaCore.AuditLogger
    private let taskId: String
    private let engineType: AnigmaCore.EngineType
    private let capabilityGrant: AnigmaCore.CapabilityGrant?

    init(
        baseEngine: AnigmaCore.MigrationEngine,
        auditLogger: AnigmaCore.AuditLogger,
        taskId: String,
        engineType: AnigmaCore.EngineType,
        capabilityGrant: AnigmaCore.CapabilityGrant?
    ) {
        self.baseEngine = baseEngine
        self.auditLogger = auditLogger
        self.taskId = taskId
        self.engineType = engineType
        self.capabilityGrant = capabilityGrant
    }

    func process(task: AnigmaCore.MigrationTaskRow, db: OpaquePointer?) async throws -> AnigmaCore.MigrationResult {
        let startTime = Date()

        // Log operation start
        await auditLogger.logOperation(
            engineId: "audited-\(taskId)",
            operation: "migration_process",
            command: "\(engineType.rawValue)_engine",
            arguments: ["task_id=\(taskId)"],
            config: AnigmaCore.SandboxConfig.readOnlySandbox(projectPath: "") // Default sandbox config
        )

        // Log capability grant if present
        if let grant = capabilityGrant {
            logInfo("Using capability grant: \(grant.id), expires in \(Int(grant.timeRemaining))s", category: "AuditedEngine")
        }

        do {
            // Process with base engine
            let result = try await baseEngine.process(task: task, db: db)
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)

            // Log result
            await auditLogger.logResult(
                engineId: "audited-\(taskId)",
                operation: "migration_process",
                result: AnigmaCore.ProcessResult(
                    exitCode: result.isSuccess ? 0 : 1,
                    output: "Migration \(result.isSuccess ? "succeeded" : "failed")",
                    error: result.errorDescription ?? "",
                    duration: duration,
                    timedOut: false
                ),
                startTime: startTime,
                endTime: endTime
            )

            logInfo("Audited engine completed in \(String(format: "%.2f", duration))s", category: "AuditedEngine")
            return result

        } catch {
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)

            await auditLogger.logError(
                engineId: "audited-\(taskId)",
                operation: "migration_process",
                error: "Engine error: \(error.localizedDescription)"
            )

            logError("Audited engine failed after \(String(format: "%.2f", duration))s: \(error)", category: "AuditedEngine")
            throw error
        }
    }
}

// MARK: - Helper Extensions

extension AnigmaCore.SandboxConfig { // Update extension to be on AnigmaCore.SandboxConfig
    /// Network engine sandbox with custom allowed endpoints.
    static func networkEngineSandbox(projectPath: String, allowedEndpoints: [String] = []) -> AnigmaCore.SandboxConfig {
        var endpoints = [
            "https://api.github.com",
            "https://raw.githubusercontent.com"
        ]
        endpoints.append(contentsOf: allowedEndpoints)

        return AnigmaCore.SandboxConfig(
            workingDirectory: projectPath,
            allowedReadPaths: [projectPath],
            allowedWritePaths: [],  // Network engines shouldn't write files
            allowNetwork: true,
            allowedEndpoints: endpoints,
            environment: [
                "PATH": "/usr/bin:/bin",
                "HOME": NSHomeDirectory()
            ],
            maxMemoryMB: 1024,
            maxCPUTimeSeconds: 300
        )
    }
}

extension AnigmaCore.MigrationResult { // Update extension to be on AnigmaCore.MigrationResult
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .skipped, .failed:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .success:
            return nil
        case .skipped(let reason):
            return "Skipped: \(reason)"
        case .failed(let error):
            return error
        }
    }
}

// MARK: - Logging Helper

private func logInfo(_ message: String, category: String) {
    print("[INFO][\(category)] \(message)")
}

private func logWarning(_ message: String, category: String) {
    print("[WARNING][\(category)] \(message)")
}

private func logError(_ message: String, category: String) {
    print("[ERROR][\(category)] \(message)")
}
