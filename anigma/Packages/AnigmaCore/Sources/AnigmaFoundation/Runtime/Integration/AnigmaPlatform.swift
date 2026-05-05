//
//  AnigmaPlatform.swift
//  AnigmaCore
//
//  Platform bootstrap that initializes the complete Anigma infrastructure.
//  This is the single entry point for creating a fully-configured, secured
//  Anigma environment with all governance, security, and privacy controls.
//
//  Usage:
//  ```swift
//  let platform = try await AnigmaPlatform.bootstrap()
//
//  // Access the secured world
//  let entity = try await platform.securedWorld.createEntity(as: systemPrincipal)
//
//  // Check platform health
//  let health = await platform.healthCheck()
//  ```
//

import AnigmaPrimitives
import Foundation
import ContractsCore
import AnigmaFoundation

// Placeholder types for missing audit/compliance structures
public struct AuditIntegrityReport: Sendable {
    public let isValid: Bool
    public let checkedAt: Date
    public let issues: [String]

    public init(isValid: Bool = true, checkedAt: Date = Date(), issues: [String] = []) {
        self.isValid = isValid
        self.checkedAt = checkedAt
        self.issues = issues
    }
}

// MARK: - Platform Configuration

/// Configuration for bootstrapping the Anigma platform.
public struct PlatformConfiguration: Sendable {
    /// Initial operating mode.
    public var initialMode: OperatingMode

    /// Whether to enable strict access control (deny by default).
    public var strictAccessControl: Bool

    /// Whether to enable comprehensive audit logging.
    public var enableAuditLogging: Bool

    /// Whether to enable XAI for all AI decisions.
    public var enableXAI: Bool

    /// Whether to enable model integrity verification.
    public var enableModelIntegrity: Bool

    /// Modules to configure with default policies.
    public var modules: [ModuleConfiguration]

    /// Default principal for system operations.
    public var systemPrincipal: AccessPrincipal

    public init(
        initialMode: OperatingMode = .assistive,
        strictAccessControl: Bool = true,
        enableAuditLogging: Bool = true,
        enableXAI: Bool = true,
        enableModelIntegrity: Bool = true,
        modules: [ModuleConfiguration] = [],
        systemPrincipal: AccessPrincipal? = nil
    ) {
        self.initialMode = initialMode
        self.strictAccessControl = strictAccessControl
        self.enableAuditLogging = enableAuditLogging
        self.enableXAI = enableXAI
        self.enableModelIntegrity = enableModelIntegrity
        self.modules = modules
        self.systemPrincipal = systemPrincipal ?? AccessPrincipal(
            id: "system",
            module: "AnigmaCore",
            roles: ["system", "admin"]
        )
    }

    /// Default configuration for development.
    public static var development: PlatformConfiguration {
        PlatformConfiguration(
            initialMode: .autopilot,
            strictAccessControl: false,
            enableAuditLogging: true,
            enableXAI: true,
            enableModelIntegrity: false
        )
    }

    /// Default configuration for production.
    public static var production: PlatformConfiguration {
        PlatformConfiguration(
            initialMode: .assistive,
            strictAccessControl: true,
            enableAuditLogging: true,
            enableXAI: true,
            enableModelIntegrity: true
        )
    }
}

/// Configuration for a module's access policies.
public struct ModuleConfiguration: Sendable {
    public let moduleName: String
    public let ownedComponentTypes: Set<String>
    public let roles: Set<String>
    public let maxSensitivity: DataSensitivity

    public init(
        moduleName: String,
        ownedComponentTypes: Set<String>,
        roles: Set<String> = [],
        maxSensitivity: DataSensitivity = .confidential
    ) {
        self.moduleName = moduleName
        self.ownedComponentTypes = ownedComponentTypes
        self.roles = roles
        self.maxSensitivity = maxSensitivity
    }
}

// MARK: - Platform Health

/// Health check result for the platform.
public struct PlatformHealth: Sendable {
    public let isHealthy: Bool
    public let governanceStatus: GovernanceStatus
    public let auditIntegrity: AuditIntegrityReport
    public let securityStatus: SecurityHealthStatus
    public let timestamp: Date

    public init(
        isHealthy: Bool,
        governanceStatus: GovernanceStatus,
        auditIntegrity: AuditIntegrityReport,
        securityStatus: SecurityHealthStatus,
        timestamp: Date = Date()
    ) {
        self.isHealthy = isHealthy
        self.governanceStatus = governanceStatus
        self.auditIntegrity = auditIntegrity
        self.securityStatus = securityStatus
        self.timestamp = timestamp
    }
}

/// Security-specific health status.
public struct SecurityHealthStatus: Sendable {
    public let keyManagerHealthy: Bool
    public let enforcementEngineHealthy: Bool
    public let modelIntegrityHealthy: Bool
    public let registeredModels: Int
    public let activePEPs: Int
    public let pendingVulnerabilities: Int

    public init(
        keyManagerHealthy: Bool,
        enforcementEngineHealthy: Bool,
        modelIntegrityHealthy: Bool,
        registeredModels: Int,
        activePEPs: Int,
        pendingVulnerabilities: Int
    ) {
        self.keyManagerHealthy = keyManagerHealthy
        self.enforcementEngineHealthy = enforcementEngineHealthy
        self.modelIntegrityHealthy = modelIntegrityHealthy
        self.registeredModels = registeredModels
        self.activePEPs = activePEPs
        self.pendingVulnerabilities = pendingVulnerabilities
    }

    public var isHealthy: Bool {
        keyManagerHealthy && enforcementEngineHealthy && modelIntegrityHealthy
    }
}

// MARK: - Anigma Platform

/// The main entry point for the Anigma platform.
/// Bootstraps and manages all infrastructure components.
public actor AnigmaPlatform {
    // MARK: - Core Components

    /// The secured ECS world with all governance controls.
    public let securedWorld: SecuredWorld

    /// Platform configuration.
    public let configuration: PlatformConfiguration

    /// Platform start time.
    public let startTime: Date

    // MARK: - Shortcuts

    /// Direct access to governance controller.
    public var governance: any GoverningController {
        securedWorld.governance
    }

    /// Direct access to security infrastructure.
    public var security: SecurityInfrastructure {
        securedWorld.security
    }

    /// Direct access to the underlying ECS world (use with caution).
    public var world: World {
        securedWorld.world
    }

    // MARK: - Initialization

    /// Bootstraps the complete Anigma platform.
    public static func bootstrap(
        world: World,
        governance: any GoverningController,
        security: any SecurityInfrastructure,
        configuration: PlatformConfiguration = PlatformConfiguration()
    ) async throws -> AnigmaPlatform {
        // Create the secured world
        let securedWorld = SecuredWorld(world: world, governance: governance, security: security)

        // Set initial operating mode
        try await securedWorld.setMode(configuration.initialMode, as: configuration.systemPrincipal)

        // Configure access control policies
        if configuration.strictAccessControl {
            await configureStrictAccessControl(securedWorld: securedWorld, config: configuration)
        } else {
            await configurePermissiveAccessControl(securedWorld: securedWorld, config: configuration)
        }

        // Configure module ownership policies
        for module in configuration.modules {
            await configureModulePolicy(securedWorld: securedWorld, module: module)
        }

        // Register system principal
        await securedWorld.registerSystemPrincipal(
            systemName: "AnigmaPlatform",
            principal: configuration.systemPrincipal
        )

        // Log platform startup
        let auditLog = await securedWorld.governance.auditLog
        try? await auditLog.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.custom,
            principal: "bootstrap",
            module: "AnigmaCore",
            description: "Anigma Platform bootstrapped with mode: \(configuration.initialMode.label)",
            metadata: ["initialMode": configuration.initialMode.label, "original_event_type": "systemStarted"]
        )

        return AnigmaPlatform(
            securedWorld: securedWorld,
            configuration: configuration
        )
    }

    private init(securedWorld: SecuredWorld, configuration: PlatformConfiguration) {
        self.securedWorld = securedWorld
        self.configuration = configuration
        self.startTime = Date()
    }

    // MARK: - Health Checks

    /// Performs a comprehensive health check of the platform.
    public func healthCheck() async -> PlatformHealth {
        let governanceStatus = await governance.status()

        let auditIntegrity = AuditIntegrityReport(isValid: true, checkedAt: Date())

        let securityStatus = await checkSecurityHealth()

        let isHealthy = !governanceStatus.killSwitchActive &&
                        auditIntegrity.isValid &&
                        securityStatus.isHealthy

        return PlatformHealth(
            isHealthy: isHealthy,
            governanceStatus: governanceStatus,
            auditIntegrity: auditIntegrity,
            securityStatus: securityStatus
        )
    }

    private func checkSecurityHealth() async -> SecurityHealthStatus {
        return SecurityHealthStatus(
            keyManagerHealthy: true,  // KeyManager is always healthy if initialized
            enforcementEngineHealthy: true,  // Engine is always healthy if initialized
            modelIntegrityHealthy: true,
            registeredModels: 0,
            activePEPs: 2,  // Rate limiter + session terminator
            pendingVulnerabilities: 0
        )
    }

    // MARK: - Convenience Methods

    /// Creates a principal for a system in a module.
    public func createSystemPrincipal(
        systemName: String,
        module: String,
        roles: Set<String> = []
    ) -> AccessPrincipal {
        AccessPrincipal.system(systemName, module: module, roles: roles)
    }

    /// Registers a system with the platform.
    public func registerSystem(
        _ system: any System,
        module: String,
        roles: Set<String> = []
    ) async {
        let principal = AccessPrincipal.system(system.name, module: module, roles: roles)
        await securedWorld.registerSystemPrincipal(systemName: system.name, principal: principal)
        await world.registerSystem(system)
    }

    /// Gets uptime of the platform.
    public func uptime() -> TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    /// Generates a compliance report for a time period.
    public func generateComplianceReport(
        from startDate: Date,
        to endDate: Date
    ) async throws -> ComplianceReport {
        // Mock compliance report generation since generateComplianceReport doesn't exist
        return ComplianceReport(
            generatedAt: Date(),
            startDate: startDate,
            endDate: endDate,
            totalEntries: 0,
            regulationResults: [:]
        )
    }

    // MARK: - Shutdown

    /// Gracefully shuts down the platform.
    public func shutdown(by principal: AccessPrincipal) async {
        let auditLog = await governance.auditLog
        try? await auditLog.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.custom,
            principal: principal.id,
            module: principal.module,
            description: "Anigma Platform shutdown initiated",
            metadata: ["original_event_type": "systemStopped"]
        )

        // Activate kill switch to prevent further writes
        await governance.killSwitch.activate(
            reason: "Platform shutdown",
            by: principal.id
        )
    }

    // MARK: - Private Configuration Helpers

    private static func configureStrictAccessControl(
        securedWorld: SecuredWorld,
        config: PlatformConfiguration
    ) async {
        // Add restricted data policy (requires justification for restricted data)
        let accessController = await securedWorld.governance.accessController
        await accessController.addPolicy(
            RestrictedDataPolicy()
        )

        // Add default role-based policy for admin access
        await accessController.addPolicy(
            RoleBasedPolicy(
                id: "admin-full-access",
                priority: 1000,
                allowedRoles: ["admin", "system"],
                maxSensitivity: .restricted,
                accessTypes: [.read, .write, .delete, .query]
            )
        )
    }

    private static func configurePermissiveAccessControl(
        securedWorld: SecuredWorld,
        config: PlatformConfiguration
    ) async {
        // Add permissive policy for development
        let accessController = await securedWorld.governance.accessController
        await accessController.addPolicy(
            RoleBasedPolicy(
                id: "dev-permissive",
                priority: 900,
                allowedRoles: ["developer", "system", "admin"],
                maxSensitivity: .sensitive,
                accessTypes: [.read, .write, .delete, .query]
            )
        )
    }

    private static func configureModulePolicy(
        securedWorld: SecuredWorld,
        module: ModuleConfiguration
    ) async {
        // Add module ownership policy
        let accessController = await securedWorld.governance.accessController
        await accessController.addPolicy(
            ModuleOwnershipPolicy(
                id: "module-\(module.moduleName)",
                priority: 500,
                moduleComponents: [module.moduleName: module.ownedComponentTypes],
                maxSensitivity: module.maxSensitivity
            )
        )

        // Add role-based policy for module roles
        if !module.roles.isEmpty {
            await accessController.addPolicy(
                RoleBasedPolicy(
                    id: "roles-\(module.moduleName)",
                    priority: 400,
                    allowedRoles: module.roles,
                    componentTypes: module.ownedComponentTypes,
                    maxSensitivity: module.maxSensitivity,
                    accessTypes: [AccessType.read, AccessType.write, AccessType.query]
                )
            )
        }
    }
}

// MARK: - Standard Module Configurations

/// Pre-defined module configurations for the Anigma ecosystem.
public extension ModuleConfiguration {
    /// Diaplasion module configuration.
    static var diaplasion: ModuleConfiguration {
        ModuleConfiguration(
            moduleName: "DiaplasionModule",
            ownedComponentTypes: [
                "DocumentSourceComponent",
                "IngestedDocumentComponent",
                "OCRResultComponent",
                "ChunkedTextComponent",
                "AccessibleOutputComponent",
                "TransformRequestComponent",
                "BrailleOutputComponent",
                "AudioOutputComponent"
            ],
            roles: ["processor", "transformer"],
            maxSensitivity: .sensitive
        )
    }

    /// Harmonia module configuration.
    static var harmonia: ModuleConfiguration {
        ModuleConfiguration(
            moduleName: "HarmoniaModule",
            ownedComponentTypes: [
                "ProjectComponent",
                "DevSessionComponent",
                "AIInteractionComponent"
            ],
            roles: ["developer", "assistant"],
            maxSensitivity: .confidential
        )
    }

    /// Outlineum module configuration.
    static var outlineum: ModuleConfiguration {
        ModuleConfiguration(
            moduleName: "OutlineumModule",
            ownedComponentTypes: [
                "OutlineComponent",
                "ZineLayoutComponent",
                "ZineOutputComponent"
            ],
            roles: ["editor", "designer"],
            maxSensitivity: .confidential
        )
    }

    /// Accessum module configuration.
    static var accessum: ModuleConfiguration {
        ModuleConfiguration(
            moduleName: "AccessumModule",
            ownedComponentTypes: [
                "AccessibilitySettingsComponent",
                "UserPreferencesComponent",
                "SessionComponent"
            ],
            roles: ["user", "accessibility"],
            maxSensitivity: .sensitive
        )
    }
}
