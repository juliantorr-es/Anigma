//
//  UpdateIntegration.swift
//  AnigmaCore
//
//  AnigmaCore - Update Integration Layer
//
//  Wires the update system into Governance, WriteGate, and SecuredWorld.
//  Makes updates a first-class governance concern, not a side-show.
//

import Foundation
import ContractsCore
import GovernanceCore

/// WriteCheck that enforces update phases and version policies.
/// Integrates seamlessly with the existing WriteGate infrastructure.
public struct UpdatePhaseCheck: WriteCheck {
    public let id = "update-phase"
    public let name = "Update Phase Check"
    public let isBlocking = true

    private let orchestrator: UpdateOrchestrator
    private let clientIdProvider: @Sendable () async -> UUID?
    private let profileProvider: @Sendable (WriteProposal) -> CheckpointProfile

    public init(
        orchestrator: UpdateOrchestrator,
        clientIdProvider: @escaping @Sendable () async -> UUID?,
        profileProvider: @escaping @Sendable (WriteProposal) -> CheckpointProfile = { _ in .soft }
    ) {
        self.orchestrator = orchestrator
        self.clientIdProvider = clientIdProvider
        self.profileProvider = profileProvider
    }

    public func appliesTo(_ proposal: WriteProposal) -> Bool {
        // Always applies to write operations
        true
    }

    public func evaluate(_ proposal: WriteProposal) async -> WriteCheckResult {
        guard let clientId = await clientIdProvider() else {
            // No client context - allow (server-side operations)
            return .pass(checkId: id, message: "Server-side operation, no client check needed")
        }

        let profile = profileProvider(proposal)
        let decision = await orchestrator.canProceed(clientId: clientId, operationProfile: profile)

        if decision.allowed {
            var message = "Operation allowed in \(decision.phase.rawValue) phase"
            if let timeLeft = decision.timeUntilBlocked {
                message += " (\(Int(timeLeft / 3600))h until blocked)"
            }
            return .pass(checkId: id, message: message)
        } else {
            return WriteCheckResult(
                checkId: id,
                passed: false,
                message: decision.reason,
                details: [
                    "phase": decision.phase.rawValue,
                    "client_status": decision.clientStatus.rawValue,
                    "required_action": decision.requiredAction?.rawValue ?? "none"
                ]
            )
        }
    }
}

// MARK: - Operation Profile Registry

/// Registry mapping operation types to their checkpoint profiles.
/// Allows domains to declare how their operations behave during updates.
public actor OperationProfileRegistry {
    /// Registered operation profiles by module and operation.
    private var profiles: [String: [String: CheckpointProfile]] = [:]

    /// Default profiles by module.
    private var moduleDefaults: [String: CheckpointProfile] = [:]

    /// Global default profile.
    private var globalDefault: CheckpointProfile = .soft

    public init() {}

    // MARK: - Registration

    /// Register a profile for a specific operation.
    public func register(
        module: String,
        operation: String,
        profile: CheckpointProfile
    ) {
        if profiles[module] == nil {
            profiles[module] = [:]
        }
        profiles[module]?[operation] = profile
    }

    /// Register default profile for a module.
    public func registerModuleDefault(
        module: String,
        profile: CheckpointProfile
    ) {
        moduleDefaults[module] = profile
    }

    /// Set global default profile.
    public func setGlobalDefault(_ profile: CheckpointProfile) {
        globalDefault = profile
    }

    /// Register multiple profiles at once.
    public func registerBatch(_ registrations: [(module: String, operation: String, profile: CheckpointProfile)]) {
        for reg in registrations {
            register(module: reg.module, operation: reg.operation, profile: reg.profile)
        }
    }

    // MARK: - Lookup

    /// Get profile for an operation.
    public func getProfile(module: String, operation: String) -> CheckpointProfile {
        // Check specific operation
        if let moduleProfiles = profiles[module],
           let profile = moduleProfiles[operation] {
            return profile
        }

        // Check module default
        if let moduleDefault = moduleDefaults[module] {
            return moduleDefault
        }

        // Fall back to global default
        return globalDefault
    }

    /// Get profile from a WriteProposal.
    public func getProfile(for proposal: WriteProposal) -> CheckpointProfile {
        return getProfile(module: proposal.module, operation: proposal.operation)
    }

    /// List all registered profiles.
    public func listProfiles() -> [(module: String, operation: String, profile: CheckpointProfile)] {
        var result: [(String, String, CheckpointProfile)] = []
        for (module, ops) in profiles {
            for (operation, profile) in ops {
                result.append((module, operation, profile))
            }
        }
        return result.sorted { $0.0 < $1.0 || ($0.0 == $1.0 && $0.1 < $1.1) }
    }
}

// MARK: - Domain Profile Presets

/// Pre-defined checkpoint profiles for common domain operations.
public struct DomainProfiles {

    // MARK: - Pragma (Work Management)

    public static let pragmaProfiles: [(module: String, operation: String, profile: CheckpointProfile)] = [
        // Hard operations - block immediately during drain
        ("Pragma", "bulk_import_tasks", .hard),
        ("Pragma", "archive_project", .hard),
        ("Pragma", "delete_project", .hard),
        ("Pragma", "migrate_workflow", .hard),

        // Soft operations - allow during drain, block during maintenance
        ("Pragma", "create_task", .soft),
        ("Pragma", "update_task", .soft),
        ("Pragma", "assign_task", .soft),
        ("Pragma", "change_status", .soft),
        ("Pragma", "add_comment", .soft),

        // Checkpoint operations - allow finish, save drafts
        ("Pragma", "create_project", .checkpoint),
        ("Pragma", "edit_workflow", .checkpoint),

        // Read-only - always allowed
        ("Pragma", "view_task", .readonly),
        ("Pragma", "list_tasks", .readonly),
        ("Pragma", "search", .readonly)
    ]

    // MARK: - Conexus (CRM)

    public static let conexusProfiles: [(module: String, operation: String, profile: CheckpointProfile)] = [
        // Hard operations
        ("Conexus", "bulk_import_contacts", .hard),
        ("Conexus", "merge_organizations", .hard),
        ("Conexus", "delete_contact", .hard),
        ("Conexus", "archive_pipeline", .hard),

        // Soft operations
        ("Conexus", "create_contact", .soft),
        ("Conexus", "update_contact", .soft),
        ("Conexus", "create_activity", .soft),
        ("Conexus", "move_deal_stage", .soft),
        ("Conexus", "add_relationship", .soft),

        // Checkpoint operations
        ("Conexus", "create_case", .checkpoint),
        ("Conexus", "create_deal", .checkpoint),

        // Read-only
        ("Conexus", "view_contact", .readonly),
        ("Conexus", "search_contacts", .readonly),
        ("Conexus", "view_pipeline", .readonly)
    ]

    // MARK: - Codex (Knowledge)

    public static let codexProfiles: [(module: String, operation: String, profile: CheckpointProfile)] = [
        // Hard operations
        ("Codex", "delete_space", .hard),
        ("Codex", "bulk_import_pages", .hard),
        ("Codex", "migrate_templates", .hard),

        // Soft operations
        ("Codex", "create_page", .soft),
        ("Codex", "update_page", .soft),
        ("Codex", "add_comment", .soft),
        ("Codex", "create_space", .soft),

        // Checkpoint operations
        ("Codex", "edit_page", .checkpoint),  // Multi-step editing
        ("Codex", "apply_template", .checkpoint),

        // Read-only
        ("Codex", "view_page", .readonly),
        ("Codex", "search", .readonly),
        ("Codex", "view_history", .readonly)
    ]

    // MARK: - Diaplasion (Alt-Media)

    public static let diaplasionProfiles: [(module: String, operation: String, profile: CheckpointProfile)] = [
        // Hard operations - long-running, must complete or not start
        ("Diaplasion", "batch_ocr", .hard),
        ("Diaplasion", "bulk_epub_generation", .hard),
        ("Diaplasion", "batch_braille_export", .hard),
        ("Diaplasion", "batch_audio_generation", .hard),

        // Soft operations
        ("Diaplasion", "ingest_document", .soft),
        ("Diaplasion", "create_request", .soft),
        ("Diaplasion", "update_request_priority", .soft),

        // Checkpoint operations
        ("Diaplasion", "configure_pipeline", .checkpoint)

        // Note: Individual OCR/export jobs are tagged at runtime
        // based on whether they started before drain mode
    ]

    // MARK: - Transcriptum (Academic Records)

    public static let transcriptumProfiles: [(module: String, operation: String, profile: CheckpointProfile)] = [
        // Hard operations - FERPA-critical, must be complete or not done
        ("Transcriptum", "submit_grades", .hard),
        ("Transcriptum", "finalize_term", .hard),
        ("Transcriptum", "award_degree", .hard),
        ("Transcriptum", "bulk_enrollment", .hard),
        ("Transcriptum", "grade_change", .hard),

        // Soft operations
        ("Transcriptum", "add_enrollment", .soft),
        ("Transcriptum", "drop_enrollment", .soft),
        ("Transcriptum", "update_standing", .soft),

        // Checkpoint operations
        ("Transcriptum", "enter_grades", .checkpoint),  // Multi-step grade entry
        ("Transcriptum", "create_section", .checkpoint),

        // Read-only
        ("Transcriptum", "view_transcript", .readonly),
        ("Transcriptum", "view_enrollment", .readonly),
        ("Transcriptum", "generate_report", .readonly)
    ]

    // MARK: - DSPS Operations

    public static let dspsProfiles: [(module: String, operation: String, profile: CheckpointProfile)] = [
        // Hard operations
        ("DSPS", "batch_letter_generation", .hard),
        ("DSPS", "bulk_case_update", .hard),

        // Soft operations
        ("DSPS", "create_accommodation_case", .soft),
        ("DSPS", "update_case_status", .soft),
        ("DSPS", "send_letter", .soft),
        ("DSPS", "create_alt_media_request", .soft),

        // Checkpoint operations
        ("DSPS", "intake_workflow", .checkpoint),
        ("DSPS", "configure_accommodations", .checkpoint),

        // Read-only
        ("DSPS", "view_student_profile", .readonly),
        ("DSPS", "view_case", .readonly)
    ]

    /// All domain profiles combined.
    public static var allProfiles: [(module: String, operation: String, profile: CheckpointProfile)] {
        pragmaProfiles + conexusProfiles + codexProfiles +
        diaplasionProfiles + transcriptumProfiles + dspsProfiles
    }
}

// MARK: - Update Cohorts

/// Cohort for staged rollouts.
/// Allows different user groups to receive updates at different times.
public struct UpdateCohort: Sendable, Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let description: String
    public let priority: Int  // Lower = earlier updates
    public let criteria: CohortCriteria
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        priority: Int,
        criteria: CohortCriteria,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.priority = priority
        self.criteria = criteria
        self.createdAt = createdAt
    }
}

/// Criteria for cohort membership.
public enum CohortCriteria: Sendable, Codable {
    case roles(Set<String>)
    case departments(Set<String>)
    case modules(Set<String>)
    case principals(Set<String>)
    case environment(DeploymentEnvironment)
    case custom(String)  // Custom identifier
    case all  // Matches everyone

    /// Check if a principal matches this criteria.
    public func matches(
        principalId: String,
        roles: Set<String> = [],
        department: String? = nil,
        activeModules: Set<String> = [],
        environment: DeploymentEnvironment = .production
    ) -> Bool {
        switch self {
        case .roles(let required):
            return !required.isDisjoint(with: roles)
        case .departments(let depts):
            guard let dept = department else { return false }
            return depts.contains(dept)
        case .modules(let mods):
            return !mods.isDisjoint(with: activeModules)
        case .principals(let ids):
            return ids.contains(principalId)
        case .environment(let env):
            return env == environment
        case .custom:
            return false  // Custom logic handled externally
        case .all:
            return true
        }
    }
}

// MARK: - Cohort Manager

/// Manages update cohorts for staged rollouts.
public actor CohortManager {
    private var cohorts: [UUID: UpdateCohort] = [:]
    private var clientCohorts: [UUID: UUID] = [:]  // clientId -> cohortId
    private var cohortVersions: [UUID: [SemanticVersion: CohortRolloutState]] = [:]

    public init() {}

    // MARK: - Cohort Management

    /// Register a cohort.
    public func registerCohort(_ cohort: UpdateCohort) {
        cohorts[cohort.id] = cohort
    }

    /// Get cohort by ID.
    public func getCohort(_ id: UUID) -> UpdateCohort? {
        return cohorts[id]
    }

    /// List all cohorts ordered by priority.
    public func listCohorts() -> [UpdateCohort] {
        return cohorts.values.sorted { $0.priority < $1.priority }
    }

    /// Assign a client to a cohort.
    public func assignClient(_ clientId: UUID, to cohortId: UUID) {
        clientCohorts[clientId] = cohortId
    }

    /// Get cohort for a client.
    public func getClientCohort(_ clientId: UUID) -> UpdateCohort? {
        guard let cohortId = clientCohorts[clientId] else { return nil }
        return cohorts[cohortId]
    }

    /// Auto-assign client to cohort based on criteria.
    public func autoAssignClient(
        _ clientId: UUID,
        principalId: String,
        roles: Set<String>,
        department: String?,
        activeModules: Set<String>,
        environment: DeploymentEnvironment
    ) -> UpdateCohort? {
        // Find first matching cohort by priority
        for cohort in listCohorts() {
            if cohort.criteria.matches(
                principalId: principalId,
                roles: roles,
                department: department,
                activeModules: activeModules,
                environment: environment
            ) {
                clientCohorts[clientId] = cohort.id
                return cohort
            }
        }
        return nil
    }

    // MARK: - Rollout State

    /// Set rollout state for a version in a cohort.
    public func setRolloutState(
        cohortId: UUID,
        version: SemanticVersion,
        state: CohortRolloutState
    ) {
        if cohortVersions[cohortId] == nil {
            cohortVersions[cohortId] = [:]
        }
        cohortVersions[cohortId]?[version] = state
    }

    /// Get rollout state for a version in a cohort.
    public func getRolloutState(
        cohortId: UUID,
        version: SemanticVersion
    ) -> CohortRolloutState {
        return cohortVersions[cohortId]?[version] ?? .notStarted
    }

    /// Check if a version is available for a client's cohort.
    public func isVersionAvailable(
        _ version: SemanticVersion,
        forClient clientId: UUID
    ) -> Bool {
        guard let cohortId = clientCohorts[clientId],
              let state = cohortVersions[cohortId]?[version] else {
            return false
        }

        switch state {
        case .available, .draining, .mandatory:
            return true
        case .notStarted, .paused, .rolledBack:
            return false
        }
    }

    /// Get statistics for a rollout.
    public func getRolloutStatistics(
        version: SemanticVersion
    ) -> RolloutStatistics {
        var stats = RolloutStatistics(version: version)

        for (cohortId, versions) in cohortVersions {
            if let state = versions[version] {
                stats.cohortStates[cohortId] = state

                let cohortClients = clientCohorts.filter { $0.value == cohortId }.count
                switch state {
                case .notStarted:
                    stats.pending += cohortClients
                case .available, .draining:
                    stats.inProgress += cohortClients
                case .mandatory:
                    stats.completed += cohortClients
                case .paused:
                    stats.paused += cohortClients
                case .rolledBack:
                    stats.rolledBack += cohortClients
                }
            }
        }

        return stats
    }
}

/// Rollout state for a cohort/version combination.
public enum CohortRolloutState: String, Sendable, Codable {
    case notStarted   // Not yet available to this cohort
    case available    // Available but not required
    case draining     // In grace period
    case mandatory    // Required for this cohort
    case paused       // Temporarily paused
    case rolledBack   // Rolled back for this cohort
}

/// Statistics for a rollout.
public struct RolloutStatistics: Sendable {
    public let version: SemanticVersion
    public var cohortStates: [UUID: CohortRolloutState] = [:]
    public var pending: Int = 0
    public var inProgress: Int = 0
    public var completed: Int = 0
    public var paused: Int = 0
    public var rolledBack: Int = 0

    public var totalClients: Int {
        pending + inProgress + completed + paused + rolledBack
    }

    public var progressPercentage: Double {
        guard totalClients > 0 else { return 0 }
        return Double(completed) / Double(totalClients) * 100
    }
}

// MARK: - Pre-defined Cohorts

/// Standard cohorts for institutional deployments.
public struct StandardCohorts {

    /// IT/Admin cohort - gets updates first.
    public static let itAdmin = UpdateCohort(
        name: "IT & Administrators",
        description: "IT staff and system administrators - first to receive updates",
        priority: 10,
        criteria: .roles(["admin", "it_staff", "system_admin"])
    )

    /// DSPS staff cohort - early adopters for accessibility focus.
    public static let dspsStaff = UpdateCohort(
        name: "DSPS Staff",
        description: "Disability services staff - early access for accessibility testing",
        priority: 20,
        criteria: .departments(["DSPS", "Accessibility Services"])
    )

    /// Faculty cohort - moderate priority.
    public static let faculty = UpdateCohort(
        name: "Faculty",
        description: "Instructors and faculty members",
        priority: 50,
        criteria: .roles(["faculty", "instructor", "adjunct"])
    )

    /// General staff cohort.
    public static let staff = UpdateCohort(
        name: "Staff",
        description: "General classified staff",
        priority: 60,
        criteria: .roles(["staff", "classified"])
    )

    /// Student cohort - last priority.
    public static let students = UpdateCohort(
        name: "Students",
        description: "Student users",
        priority: 100,
        criteria: .roles(["student"])
    )

    /// All standard cohorts.
    public static var all: [UpdateCohort] {
        [itAdmin, dspsStaff, faculty, staff, students]
    }
}

// MARK: - Update Governance Integration

/// Extension to integrate updates with GovernanceController.
public extension GovernanceController {

    /// Register update phase check with WriteGate.
    func registerUpdateCheck(
        orchestrator: UpdateOrchestrator,
        profileRegistry: OperationProfileRegistry,
        clientIdProvider: @escaping @Sendable () async -> UUID?
    ) async {
        let check = UpdatePhaseCheck(
            orchestrator: orchestrator,
            clientIdProvider: clientIdProvider
        )            { _ in
                // Use Task to call actor method
                // In practice, this would be cached or synchronous
                return .soft  // Default; real impl would check registry
            }

        await writeGate.registerCheck(check)
    }
}

// MARK: - Update Audit Events

/// Extended audit event types for updates.
public extension AuditEventType {
    static let updateAnnounced = AuditEventType(rawValue: "update_announced")
    static let updateDrainStarted = AuditEventType(rawValue: "update_drain_started")
    static let updateBlocked = AuditEventType(rawValue: "update_blocked")
    static let updateCompleted = AuditEventType(rawValue: "update_completed")
    static let updateRolledBack = AuditEventType(rawValue: "update_rolled_back")
    static let migrationExecuted = AuditEventType(rawValue: "migration_executed")
    static let migrationFailed = AuditEventType(rawValue: "migration_failed")
    static let clientVersionBlocked = AuditEventType(rawValue: "client_version_blocked")
    static let cohortRolloutChanged = AuditEventType(rawValue: "cohort_rollout_changed")
}
