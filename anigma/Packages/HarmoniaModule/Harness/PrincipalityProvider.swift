//
//  PrincipalityProvider.swift
//  HarmoniaModule
//
//  Simple factory + cache for per-project principalities.
//  Lives at the same level as your root module singleton.
//  Phase B: Default choir construction with governance protocols.
//

@preconcurrency import Foundation

/// Simple factory + cache for per-project principalities.
/// Lives at the same level as your root module singleton.
public actor PrincipalityProvider {
    public static let shared = PrincipalityProvider()

    private var controllers: [UUID: PrincipalityProjectController] = [:]

    private init() {}

    /// Gets or creates a principality controller for a project.
    /// - Parameters:
    ///   - projectId: The project identifier
    ///   - store: Project harness store (defaults to shared)
    ///   - policyRegistry: Policy registry (Seraphim)
    ///   - banditGovernor: Bandit governor (Thrones)
    ///   - gatekeeper: Gatekeeper (Cherubim)
    ///   - securityEnforcer: Security enforcer (Dominions)
    ///   - harnessRunner: Harness runner (Archangels)
    ///   - eventSink: Event sink for governance events
    ///   - rudeCLI: Rude CLI commands (defaults to new instance)
    /// - Returns: Principality controller for the project
    public func controller(
        for projectId: UUID,
        store: ProjectHarnessStore = .shared,
        policyRegistry: PolicyRegistry = BlessedPolicyRegistry(),
        banditGovernor: BanditGovernor = BanditGovernorImpl(),
        gatekeeper: Gatekeeper = GatekeeperImpl(),
        securityEnforcer: SecurityEnforcer = SecurityEnforcerImpl(),
        harnessRunner: HarnessRunner = HarnessRunnerImpl(),
        eventSink: GovernanceEventSink = ConsoleEventSink(),
        rudeCLI: RudeCLICommands = RudeCLICommands()
    ) -> PrincipalityProjectController {
        if let existing = controllers[projectId] {
            return existing
        }

        let controller = PrincipalityProjectController(
            projectId: projectId,
            store: store,
            policyRegistry: policyRegistry,
            banditGovernor: banditGovernor,
            gatekeeper: gatekeeper,
            securityEnforcer: securityEnforcer,
            harnessRunner: harnessRunner,
            eventSink: eventSink,
            rudeCLI: rudeCLI
        )
        controllers[projectId] = controller
        return controller
    }

    /// Gets an existing principality controller for a project, if it exists.
    /// - Parameter projectId: The project identifier
    /// - Returns: Existing principality controller, or nil if not cached
    public func existingController(for projectId: UUID) -> PrincipalityProjectController? {
        return controllers[projectId]
    }

    /// Removes a principality controller from the cache.
    /// Useful for testing or when a project is deleted.
    /// - Parameter projectId: The project identifier
    public func removeController(for projectId: UUID) {
        controllers.removeValue(forKey: projectId)
    }

    /// Clears all cached principality controllers.
    /// Useful for testing or memory management.
    public func clearCache() {
        controllers.removeAll()
    }

    /// Gets all cached project IDs.
    /// - Returns: Array of project IDs with cached controllers
    public func cachedProjectIds() -> [UUID] {
        return Array(controllers.keys)
    }

    /// Gets the number of cached controllers.
    /// - Returns: Count of cached controllers
    public func cacheCount() -> Int {
        return controllers.count
    }

    /// Pre-warms the cache with controllers for all existing projects.
    /// - Parameters:
    ///   - store: Project harness store
    ///   - policyRegistry: Policy registry (Seraphim)
    ///   - banditGovernor: Bandit governor (Thrones)
    ///   - gatekeeper: Gatekeeper (Cherubim)
    ///   - securityEnforcer: Security enforcer (Dominions)
    ///   - harnessRunner: Harness runner (Archangels)
    ///   - eventSink: Event sink for governance events
    ///   - rudeCLI: Rude CLI commands
    public func prewarmCache(
        store: ProjectHarnessStore = .shared,
        policyRegistry: PolicyRegistry = BlessedPolicyRegistry(),
        banditGovernor: BanditGovernor = BanditGovernorImpl(),
        gatekeeper: Gatekeeper = GatekeeperImpl(),
        securityEnforcer: SecurityEnforcer = SecurityEnforcerImpl(),
        harnessRunner: HarnessRunner = HarnessRunnerImpl(),
        eventSink: GovernanceEventSink = ConsoleEventSink(),
        rudeCLI: RudeCLICommands = RudeCLICommands()
    ) async throws {
        let projects = try await store.loadAllProjects()

        for project in projects {
            _ = controller(
                for: project.id,
                store: store,
                policyRegistry: policyRegistry,
                banditGovernor: banditGovernor,
                gatekeeper: gatekeeper,
                securityEnforcer: securityEnforcer,
                harnessRunner: harnessRunner,
                eventSink: eventSink,
                rudeCLI: rudeCLI
            )
        }
    }
}

// MARK: - Convenience Extensions

extension PrincipalityProvider {
    /// Convenience method to get a principality controller with default dependencies.
    /// - Parameter projectId: The project identifier
    /// - Returns: Principality controller for the project
    public func controller(for projectId: UUID) -> PrincipalityProjectController {
        // Create composite event sink with user collector and console
        let userCollector = UserEventCollector()
        let consoleSink = TieredConsoleEventSink(verbosity: .normal)
        let compositeSink = CompositeEventSink(sinks: [userCollector, consoleSink])

        return controller(
            for: projectId,
            store: .shared,
            policyRegistry: BlessedPolicyRegistry(),
            banditGovernor: BanditGovernorImpl(),
            gatekeeper: GatekeeperImpl(),
            securityEnforcer: SecurityEnforcerImpl(),
            harnessRunner: HarnessRunnerImpl(),
            eventSink: compositeSink,
            rudeCLI: RudeCLICommands()
        )
    }

    /// Convenience method to get a principality controller for a project ID string.
    /// - Parameter projectIdString: The project identifier as a string
    /// - Returns: Principality controller for the project, or nil if ID is invalid
    public func controller(for projectIdString: String) -> PrincipalityProjectController? {
        guard let projectId = UUID(uuidString: projectIdString) else {
            return nil
        }
        return controller(for: projectId)
    }
}

// MARK: - CLI Integration Helper

extension PrincipalityProvider {
    /// CLI helper to resolve a project ID from various inputs.
    /// - Parameters:
    ///   - projectId: Explicit project ID (highest priority)
    ///   - projectName: Project name to look up
    ///   - interactive: Whether to prompt interactively if no ID found
    /// - Returns: Resolved project ID, or nil if not found
    public func resolveProjectId(
        projectId: UUID? = nil,
        projectName: String? = nil,
        interactive: Bool = false
    ) async throws -> UUID? {
        // 1. Use explicit ID if provided
        if let projectId = projectId {
            return projectId
        }

        // 2. Try to find by name
        if let projectName = projectName {
            let store = ProjectHarnessStore.shared
            let projects = try await store.loadAllProjects()
            if let project = projects.first(where: { $0.name == projectName }) {
                return project.id
            }
        }

        // 3. If interactive, show list and prompt
        if interactive {
            let store = ProjectHarnessStore.shared
            let projects = try await store.loadAllProjects()

            if projects.isEmpty {
                print("No projects found. Create one with `harmonia create-project`")
                return nil
            }

            print("Select a project:")
            for (index, project) in projects.enumerated() {
                print("  \(index + 1). \(project.name) (\(project.id.uuidString.prefix(8))...)")
            }

            print("\nEnter number or project ID: ", terminator: "")
            if let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) {
                // Try to parse as number
                if let index = Int(input), index > 0 && index <= projects.count {
                    return projects[index - 1].id
                }
                // Try to parse as UUID
                if let uuid = UUID(uuidString: input) {
                    return uuid
                }
                // Try to find by name
                if let project = projects.first(where: { $0.name == input }) {
                    return project.id
                }
            }
        }

        return nil
    }

    /// CLI helper to get or create a principality controller with user-friendly error.
    /// - Parameters:
    ///   - projectId: Project ID (optional)
    ///   - projectName: Project name (optional)
    ///   - interactive: Whether to prompt interactively
    /// - Returns: Principality controller, or throws descriptive error
    public func controllerWithUserError(
        projectId: UUID? = nil,
        projectName: String? = nil,
        interactive: Bool = false
    ) async throws -> PrincipalityProjectController {
        guard let resolvedId = try await resolveProjectId(
            projectId: projectId,
            projectName: projectName,
            interactive: interactive
        ) else {
            if let projectName = projectName {
                throw PrincipalityError.projectNotFoundByName(projectName)
            } else {
                throw PrincipalityError.projectIdRequired
            }
        }

        return controller(for: resolvedId)
    }
}

// MARK: - System Factory Methods

extension PrincipalityProvider {
    /// Creates a ProjectCodingAgentSystem for a project.
    /// - Parameters:
    ///   - projectId: The project identifier
    ///   - toolRegistry: Tool registry for tool execution
    ///   - sandboxConfig: Sandbox configuration for safe tool execution
    /// - Returns: ProjectCodingAgentSystem configured for the project
    public func codingAgentSystem(
        for projectId: UUID,
        toolRegistry: SimpleToolRegistry = SimpleToolRegistry(),
        sandboxConfig: CodingSandboxConfig = .default
    ) async throws -> ProjectCodingAgentSystem {
        let principality = controller(for: projectId)
        return ProjectCodingAgentSystem(
            project: principality,
            toolRegistry: toolRegistry,
            sandboxConfig: sandboxConfig
        )
    }

    /// Creates a ProjectInitializerSystem for a project.
    /// - Parameters:
    ///   - projectId: The project identifier
    ///   - toolRegistry: Tool registry for LLM calls
    /// - Returns: ProjectInitializerSystem configured for the project
    public func initializerSystem(
        for projectId: UUID,
        toolRegistry: SimpleToolRegistry = SimpleToolRegistry()
    ) async throws -> ProjectInitializerSystem {
        let principality = controller(for: projectId)
        return ProjectInitializerSystem(
            project: principality,
            toolRegistry: toolRegistry
        )
    }

    /// Creates a ProjectCodingAgentService for a project.
    /// - Parameters:
    ///   - projectId: The project identifier
    ///   - toolRegistry: Tool registry for tool execution
    ///   - sandboxConfig: Sandbox configuration for safe tool execution
    ///   - epilogueRunner: Session epilogue runner
    ///   - rudeNotifier: Rude CLI notifier
    /// - Returns: ProjectCodingAgentService configured for the project
    public func codingAgentService(
        for projectId: UUID,
        toolRegistry: SimpleToolRegistry = SimpleToolRegistry(),
        sandboxConfig: CodingSandboxConfig = .default,
        epilogueRunner: SessionEpilogueRunner = SessionEpilogueRunner(),
        rudeNotifier: RudeCLINotifier = RudeCLINotifier()
    ) async throws -> ProjectCodingAgentService {
        let principality = controller(for: projectId)
        return ProjectCodingAgentService(
            project: principality,
            toolRegistry: toolRegistry,
            sandboxConfig: sandboxConfig,
            epilogueRunner: epilogueRunner,
            rudeNotifier: rudeNotifier
        )
    }
}

// MARK: - Errors

public enum PrincipalityError: LocalizedError {
    case projectIdRequired
    case projectNotFoundByName(String)
    case projectNotFound(UUID)
    case projectQuarantined(UUID)
    case sessionDenied(String)
    case cacheError(String)

    public var errorDescription: String? {
        switch self {
        case .projectIdRequired:
            return "Project ID is required. Use --project <id> or --name <name>"
        case .projectNotFoundByName(let name):
            return "Project not found with name: \(name)"
        case .projectNotFound(let id):
            return "Project not found: \(id)"
        case .projectQuarantined(let id):
            return "Project \(id) is quarantined and cannot run sessions"
        case .sessionDenied(let reason):
            return "Session denied: \(reason)"
        case .cacheError(let message):
            return "Cache error: \(message)"
        }
    }
}
