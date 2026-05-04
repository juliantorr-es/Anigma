import AnigmaPrimitives

import AnigmaPrimitives

//
//  Identity.swift
//  AnigmaCore
//
//  First-class identity domain for the Anigma platform.
//  Implements stable principal identities, time-bounded role assignments,
//  group/team membership, and capability derivation.
//
//  Design principles:
//  - One internal ID per human, stable across username/email changes
//  - Roles and affiliations are time-bounded and auditable
//  - Capabilities are derived from roles/groups, not hard-coded
//  - All identity changes are governed and logged
//  - Designed for SSO integration with external IdPs
//

import AnigmaPrimitives
import ContractsCore
import Foundation

// MARK: - Principal Identity

/// A stable identity representing a human or system in Anigma.
/// One principal per human, with multiple linked external identifiers.
public struct PrincipalIdentity: Component, Sendable, Codable {
    /// Internal stable UUID that never changes.
    public let principalId: UUID

    /// Human-readable display name.
    public var displayName: String

    /// Primary email address (may change).
    public var primaryEmail: String?

    /// Principal type.
    public var principalType: PrincipalType

    /// Account status.
    public var status: PrincipalStatus

    /// When the identity was created.
    public let createdAt: Date

    /// When the identity was last modified.
    public var modifiedAt: Date

    /// When the identity was last authenticated.
    public var lastAuthenticatedAt: Date?

    /// MFA status.
    public var mfaEnabled: Bool

    /// Preferred language/locale.
    public var locale: String?

    /// Timezone preference.
    public var timezone: String?

    public init(
        principalId: UUID = UUID(),
        displayName: String,
        primaryEmail: String? = nil,
        principalType: PrincipalType = .human,
        status: PrincipalStatus = .active,
        createdAt: Date = Date(),
        mfaEnabled: Bool = false,
        locale: String? = nil,
        timezone: String? = nil
    ) {
        self.principalId = principalId
        self.displayName = displayName
        self.primaryEmail = primaryEmail
        self.principalType = principalType
        self.status = status
        self.createdAt = createdAt
        self.modifiedAt = createdAt
        self.lastAuthenticatedAt = nil
        self.mfaEnabled = mfaEnabled
        self.locale = locale
        self.timezone = timezone
    }
}

/// Types of principals in the system.
public enum PrincipalType: String, Sendable, Codable {
    /// A human user.
    case human = "human"

    /// A system service account.
    case service = "service"

    /// An automated agent.
    case agent = "agent"

    /// An external system integration.
    case integration = "integration"
}

/// Status of a principal account.
public enum PrincipalStatus: String, Sendable, Codable {
    /// Account is active and can authenticate.
    case active = "active"

    /// Account is temporarily suspended.
    case suspended = "suspended"

    /// Account is pending activation (e.g., awaiting email verification).
    case pending = "pending"

    /// Account has been deprovisioned.
    case deprovisioned = "deprovisioned"

    /// Account is locked due to security concerns.
    case locked = "locked"
}

// MARK: - External Identifiers

/// Links a principal to external identity systems.
public struct ExternalIdentifierComponent: Component, Sendable, Codable {
    /// The principal this identifier belongs to.
    public let principalId: UUID

    /// The external system (e.g., "ccsf-sis", "canvas", "okta", "google").
    public let system: String

    /// The identifier value in that system.
    public let externalId: String

    /// Type of identifier (e.g., "employee_id", "student_id", "email", "oidc_sub").
    public let identifierType: String

    /// Whether this is the primary identifier for this system.
    public var isPrimary: Bool

    /// When the link was established.
    public let linkedAt: Date

    /// When the link was last verified.
    public var lastVerifiedAt: Date?

    /// Whether the link is currently active.
    public var isActive: Bool

    public init(
        principalId: UUID,
        system: String,
        externalId: String,
        identifierType: String,
        isPrimary: Bool = true,
        linkedAt: Date = Date(),
        isActive: Bool = true
    ) {
        self.principalId = principalId
        self.system = system
        self.externalId = externalId
        self.identifierType = identifierType
        self.isPrimary = isPrimary
        self.linkedAt = linkedAt
        self.lastVerifiedAt = linkedAt
        self.isActive = isActive
    }
}

// MARK: - Role Definitions

/// Definition of a role in the system.
public struct RoleDefinition: Sendable, Codable, Hashable {
    /// Unique role identifier.
    public let roleId: String

    /// Human-readable name.
    public let name: String

    /// Description of what this role allows.
    public let description: String

    /// Module this role belongs to (nil = global).
    public let module: String?

    /// Base capabilities granted by this role.
    public let capabilities: Set<String>

    /// Roles this role inherits from.
    public let inheritsFrom: Set<String>

    /// Maximum data sensitivity this role can access.
    public let maxSensitivity: DataSensitivity

    /// Whether this role can be self-assigned.
    public let selfAssignable: Bool

    /// Whether this role requires additional approval.
    public let requiresApproval: Bool

    public init(
        roleId: String,
        name: String,
        description: String,
        module: String? = nil,
        capabilities: Set<String> = [],
        inheritsFrom: Set<String> = [],
        maxSensitivity: DataSensitivity = .internal,
        selfAssignable: Bool = false,
        requiresApproval: Bool = false
    ) {
        self.roleId = roleId
        self.name = name
        self.description = description
        self.module = module
        self.capabilities = capabilities
        self.inheritsFrom = inheritsFrom
        self.maxSensitivity = maxSensitivity
        self.selfAssignable = selfAssignable
        self.requiresApproval = requiresApproval
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(roleId)
    }

    public static func == (lhs: RoleDefinition, rhs: RoleDefinition) -> Bool {
        lhs.roleId == rhs.roleId
    }
}

// MARK: - Role Assignments

/// A time-bounded role assignment to a principal.
public struct RoleAssignmentComponent: Component, Sendable, Codable {
    /// Unique assignment ID.
    public let assignmentId: UUID

    /// The principal receiving the role.
    public let principalId: UUID

    /// The role being assigned.
    public let roleId: String

    /// The organizational unit for scoped roles (e.g., department, campus).
    public let organizationScope: String?

    /// When this assignment becomes effective.
    public let effectiveFrom: Date

    /// When this assignment expires (nil = indefinite).
    public var effectiveUntil: Date?

    /// Who assigned this role.
    public let assignedBy: UUID

    /// When the assignment was created.
    public let assignedAt: Date

    /// Justification for the assignment.
    public let justification: String?

    /// Current status of the assignment.
    public var status: RoleAssignmentStatus

    /// Whether this was auto-assigned from IdP claims.
    public let fromIdP: Bool

    public init(
        assignmentId: UUID = UUID(),
        principalId: UUID,
        roleId: String,
        organizationScope: String? = nil,
        effectiveFrom: Date = Date(),
        effectiveUntil: Date? = nil,
        assignedBy: UUID,
        justification: String? = nil,
        status: RoleAssignmentStatus = .active,
        fromIdP: Bool = false
    ) {
        self.assignmentId = assignmentId
        self.principalId = principalId
        self.roleId = roleId
        self.organizationScope = organizationScope
        self.effectiveFrom = effectiveFrom
        self.effectiveUntil = effectiveUntil
        self.assignedBy = assignedBy
        self.assignedAt = Date()
        self.justification = justification
        self.status = status
        self.fromIdP = fromIdP
    }

    /// Whether the assignment is currently effective.
    public func isEffective(at date: Date = Date()) -> Bool {
        guard status == .active else { return false }
        guard date >= effectiveFrom else { return false }
        if let until = effectiveUntil, date > until { return false }
        return true
    }
}

/// Status of a role assignment.
public enum RoleAssignmentStatus: String, Sendable, Codable {
    /// Assignment is active.
    case active = "active"

    /// Assignment is pending approval.
    case pendingApproval = "pending_approval"

    /// Assignment was revoked.
    case revoked = "revoked"

    /// Assignment expired naturally.
    case expired = "expired"

    /// Assignment was superseded by a newer one.
    case superseded = "superseded"
}

// MARK: - Groups and Teams

/// A group or team that principals can belong to.
public struct GroupComponent: Component, Sendable, Codable {
    /// Unique group ID.
    public let groupId: UUID

    /// Group identifier (human-readable slug).
    public let slug: String

    /// Display name.
    public var name: String

    /// Description.
    public var description: String?

    /// Type of group.
    public var groupType: GroupType

    /// Parent group (for nested groups).
    public var parentGroupId: UUID?

    /// Organization this group belongs to.
    public var organizationId: String?

    /// Whether the group is active.
    public var isActive: Bool

    /// When the group was created.
    public let createdAt: Date

    /// Roles automatically granted to group members.
    public var inheritedRoles: Set<String>

    public init(
        groupId: UUID = UUID(),
        slug: String,
        name: String,
        description: String? = nil,
        groupType: GroupType = .team,
        parentGroupId: UUID? = nil,
        organizationId: String? = nil,
        inheritedRoles: Set<String> = []
    ) {
        self.groupId = groupId
        self.slug = slug
        self.name = name
        self.description = description
        self.groupType = groupType
        self.parentGroupId = parentGroupId
        self.organizationId = organizationId
        self.isActive = true
        self.createdAt = Date()
        self.inheritedRoles = inheritedRoles
    }
}

/// Types of groups.
public enum GroupType: String, Sendable, Codable {
    /// A functional team.
    case team = "team"

    /// A department or organizational unit.
    case department = "department"

    /// A committee or council.
    case committee = "committee"

    /// A project group.
    case project = "project"

    /// An access group (for permissions only).
    case access = "access"

    /// A security group from IdP.
    case security = "security"
}

/// Membership of a principal in a group.
public struct GroupMembershipComponent: Component, Sendable, Codable {
    /// Unique membership ID.
    public let membershipId: UUID

    /// The principal who is a member.
    public let principalId: UUID

    /// The group they belong to.
    public let groupId: UUID

    /// Role within the group (e.g., "member", "lead", "admin").
    public var groupRole: String

    /// When membership became effective.
    public let effectiveFrom: Date

    /// When membership expires.
    public var effectiveUntil: Date?

    /// Whether membership is active.
    public var isActive: Bool

    /// Who added this member.
    public let addedBy: UUID

    /// When the membership was created.
    public let addedAt: Date

    public init(
        membershipId: UUID = UUID(),
        principalId: UUID,
        groupId: UUID,
        groupRole: String = "member",
        effectiveFrom: Date = Date(),
        effectiveUntil: Date? = nil,
        addedBy: UUID
    ) {
        self.membershipId = membershipId
        self.principalId = principalId
        self.groupId = groupId
        self.groupRole = groupRole
        self.effectiveFrom = effectiveFrom
        self.effectiveUntil = effectiveUntil
        self.isActive = true
        self.addedBy = addedBy
        self.addedAt = Date()
    }

    /// Whether the membership is currently effective.
    public func isEffective(at date: Date = Date()) -> Bool {
        guard isActive else { return false }
        guard date >= effectiveFrom else { return false }
        if let until = effectiveUntil, date > until { return false }
        return true
    }
}

// MARK: - Capability Derivation

/// Derived capabilities for a principal at a point in time.
public struct DerivedCapabilities: Sendable {
    /// The principal.
    public let principalId: UUID

    /// When this was computed.
    public let computedAt: Date

    /// All effective role IDs (including inherited).
    public let effectiveRoles: Set<String>

    /// All effective group IDs (including nested).
    public let effectiveGroups: Set<UUID>

    /// All derived capabilities.
    public let capabilities: Set<String>

    /// Maximum data sensitivity accessible.
    public let maxSensitivity: DataSensitivity

    /// Organization scopes accessible.
    public let organizationScopes: Set<String>

    /// Source breakdown for audit.
    public let sources: [CapabilitySource]

    public init(
        principalId: UUID,
        effectiveRoles: Set<String>,
        effectiveGroups: Set<UUID>,
        capabilities: Set<String>,
        maxSensitivity: DataSensitivity,
        organizationScopes: Set<String>,
        sources: [CapabilitySource]
    ) {
        self.principalId = principalId
        self.computedAt = Date()
        self.effectiveRoles = effectiveRoles
        self.effectiveGroups = effectiveGroups
        self.capabilities = capabilities
        self.maxSensitivity = maxSensitivity
        self.organizationScopes = organizationScopes
        self.sources = sources
    }

    /// Checks if the principal has a specific capability.
    public func hasCapability(_ capability: String) -> Bool {
        capabilities.contains(capability)
    }

    /// Checks if the principal can access data at a given sensitivity.
    public func canAccessSensitivity(_ sensitivity: DataSensitivity) -> Bool {
        sensitivity <= maxSensitivity
    }
}

/// Source of a capability (for audit trail).
public struct CapabilitySource: Sendable {
    public let capability: String
    public let sourceType: CapabilitySourceType
    public let sourceId: String
    public let sourceName: String

    public init(capability: String, sourceType: CapabilitySourceType, sourceId: String, sourceName: String) {
        self.capability = capability
        self.sourceType = sourceType
        self.sourceId = sourceId
        self.sourceName = sourceName
    }
}

/// Types of capability sources.
public enum CapabilitySourceType: String, Sendable {
    case directRole = "direct_role"
    case inheritedRole = "inherited_role"
    case groupMembership = "group_membership"
    case idpClaim = "idp_claim"
}

// MARK: - Session and Authentication

/// An active session for a principal.
public struct SessionComponent: Component, Sendable, Codable {
    /// Unique session ID.
    public let sessionId: UUID

    /// The principal this session belongs to.
    public let principalId: UUID

    /// When the session was created.
    public let createdAt: Date

    /// When the session expires.
    public var expiresAt: Date

    /// When the session was last active.
    public var lastActivityAt: Date

    /// Client information.
    public var clientInfo: SessionClientInfo

    /// Whether this session is still valid.
    public var isValid: Bool

    /// Reason for invalidation (if any).
    public var invalidationReason: String?

    /// Authentication method used.
    public let authMethod: AuthenticationMethod

    /// MFA verification status for this session.
    public var mfaVerified: Bool

    public init(
        sessionId: UUID = UUID(),
        principalId: UUID,
        expiresAt: Date,
        clientInfo: SessionClientInfo,
        authMethod: AuthenticationMethod,
        mfaVerified: Bool = false
    ) {
        self.sessionId = sessionId
        self.principalId = principalId
        self.createdAt = Date()
        self.expiresAt = expiresAt
        self.lastActivityAt = Date()
        self.clientInfo = clientInfo
        self.isValid = true
        self.invalidationReason = nil
        self.authMethod = authMethod
        self.mfaVerified = mfaVerified
    }

    /// Whether the session is currently active (valid and not expired).
    public func isActive(at date: Date = Date()) -> Bool {
        isValid && date < expiresAt
    }
}

/// Client information for a session.
public struct SessionClientInfo: Sendable, Codable {
    public let ipAddress: String?
    public let userAgent: String?
    public let deviceId: String?
    public let platform: String?
    public let appVersion: String?

    public init(
        ipAddress: String? = nil,
        userAgent: String? = nil,
        deviceId: String? = nil,
        platform: String? = nil,
        appVersion: String? = nil
    ) {
        self.ipAddress = ipAddress
        self.userAgent = userAgent
        self.deviceId = deviceId
        self.platform = platform
        self.appVersion = appVersion
    }
}

/// Authentication methods.
public enum AuthenticationMethod: String, Sendable, Codable {
    case password = "password"
    case sso = "sso"
    case apiKey = "api_key"
    case certificate = "certificate"
    case token = "token"
}

// MARK: - Deprovisioning

/// Record of a deprovisioning action.
public struct DeprovisioningRecord: Component, Sendable, Codable {
    /// Unique record ID.
    public let recordId: UUID

    /// The principal being deprovisioned.
    public let principalId: UUID

    /// Type of deprovisioning.
    public let deprovisionType: DeprovisionType

    /// Reason for deprovisioning.
    public let reason: String

    /// Who initiated the deprovisioning.
    public let initiatedBy: UUID

    /// When the deprovisioning was initiated.
    public let initiatedAt: Date

    /// When the deprovisioning was completed.
    public var completedAt: Date?

    /// Current status.
    public var status: DeprovisionStatus

    /// Actions taken during deprovisioning.
    public var actions: [DeprovisionAction]

    /// Whether data was retained or deleted.
    public var dataRetentionPolicy: String?

    public init(
        recordId: UUID = UUID(),
        principalId: UUID,
        deprovisionType: DeprovisionType,
        reason: String,
        initiatedBy: UUID
    ) {
        self.recordId = recordId
        self.principalId = principalId
        self.deprovisionType = deprovisionType
        self.reason = reason
        self.initiatedBy = initiatedBy
        self.initiatedAt = Date()
        self.completedAt = nil
        self.status = .pending
        self.actions = []
        self.dataRetentionPolicy = nil
    }
}

/// Types of deprovisioning.
public enum DeprovisionType: String, Sendable, Codable {
    /// Employee left the organization.
    case termination = "termination"

    /// Role change within organization.
    case roleChange = "role_change"

    /// Temporary suspension.
    case suspension = "suspension"

    /// Security-related lockout.
    case securityLockout = "security_lockout"

    /// Account cleanup.
    case cleanup = "cleanup"
}

/// Status of deprovisioning.
public enum DeprovisionStatus: String, Sendable, Codable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"
    case rolledBack = "rolled_back"
}

/// An action taken during deprovisioning.
public struct DeprovisionAction: Sendable, Codable {
    public let actionType: String
    public let target: String
    public let performedAt: Date
    public let success: Bool
    public let details: String?

    public init(actionType: String, target: String, success: Bool, details: String? = nil) {
        self.actionType = actionType
        self.target = target
        self.performedAt = Date()
        self.success = success
        self.details = details
    }
}

// MARK: - Standard Roles

/// Standard role definitions for common use cases.
public enum StandardRoles {
    // System-level roles
    public static let systemAdmin = RoleDefinition(
        roleId: "system_admin",
        name: "System Administrator",
        description: "Full system access for platform administration",
        capabilities: ["*"],
        maxSensitivity: .restricted,
        requiresApproval: true
    )

    public static let securityAdmin = RoleDefinition(
        roleId: "security_admin",
        name: "Security Administrator",
        description: "Security configuration and audit access",
        capabilities: [
            "security.manage", "audit.read", "audit.export",
            "identity.manage", "sessions.manage", "keys.rotate"
        ],
        maxSensitivity: .restricted,
        requiresApproval: true
    )

    // Institutional roles
    public static let institutionAdmin = RoleDefinition(
        roleId: "institution_admin",
        name: "Institution Administrator",
        description: "Administrative access for institution management",
        module: "institution",
        capabilities: [
            "institution.manage", "users.manage", "groups.manage",
            "policies.manage", "reports.view"
        ],
        maxSensitivity: .sensitive
    )

    // DSPS roles
    public static let dspsDirector = RoleDefinition(
        roleId: "dsps_director",
        name: "DSPS Director",
        description: "Full access to DSPS operations and reporting",
        module: "dsps",
        capabilities: [
            "dsps.manage", "dsps.cases.all", "dsps.reports.all",
            "dsps.staff.manage", "dsps.policies.manage"
        ],
        maxSensitivity: .restricted
    )

    public static let dspsCounselor = RoleDefinition(
        roleId: "dsps_counselor",
        name: "DSPS Counselor",
        description: "Case management and student interaction",
        module: "dsps",
        capabilities: [
            "dsps.cases.manage", "dsps.students.view",
            "dsps.accommodations.create", "dsps.letters.send"
        ],
        maxSensitivity: .sensitive
    )

    public static let dspsAltMediaStaff = RoleDefinition(
        roleId: "dsps_alt_media",
        name: "DSPS Alt-Media Staff",
        description: "Alt-media production and QA",
        module: "dsps",
        capabilities: [
            "dsps.altmedia.manage", "dsps.altmedia.produce",
            "dsps.requests.view", "diaplasion.jobs.manage"
        ],
        maxSensitivity: .confidential
    )

    // Academic roles
    public static let registrar = RoleDefinition(
        roleId: "registrar",
        name: "Registrar",
        description: "Academic records management",
        module: "transcriptum",
        capabilities: [
            "records.manage", "enrollments.manage", "grades.manage",
            "transcripts.issue", "degrees.award"
        ],
        maxSensitivity: .restricted,
        requiresApproval: true
    )

    public static let faculty = RoleDefinition(
        roleId: "faculty",
        name: "Faculty",
        description: "Instructor access for assigned courses",
        module: "transcriptum",
        capabilities: [
            "courses.view.assigned", "grades.submit.assigned",
            "roster.view.assigned", "accommodations.view.assigned"
        ],
        maxSensitivity: .confidential
    )

    public static let student = RoleDefinition(
        roleId: "student",
        name: "Student",
        description: "Student self-service access",
        module: "transcriptum",
        capabilities: [
            "records.view.self", "schedule.view.self",
            "transcript.view.self", "accommodations.view.self"
        ],
        maxSensitivity: .confidential
    )

    // General roles
    public static let viewer = RoleDefinition(
        roleId: "viewer",
        name: "Viewer",
        description: "Read-only access to public and internal content",
        capabilities: ["content.view.public", "content.view.internal"],
        maxSensitivity: .internal
    )

    public static let contributor = RoleDefinition(
        roleId: "contributor",
        name: "Contributor",
        description: "Can create and edit own content",
        capabilities: [
            "content.view.internal", "content.create",
            "content.edit.own", "comments.create"
        ],
        inheritsFrom: ["viewer"],
        maxSensitivity: .internal
    )

    /// All standard roles.
    public static let all: [RoleDefinition] = [
        systemAdmin, securityAdmin, institutionAdmin,
        dspsDirector, dspsCounselor, dspsAltMediaStaff,
        registrar, faculty, student,
        viewer, contributor
    ]
}

// MARK: - Standard Capabilities

/// Standard capability definitions.
public enum StandardCapabilities {
    // System capabilities
    public static let systemManage = "system.manage"
    public static let securityManage = "security.manage"
    public static let auditRead = "audit.read"
    public static let auditExport = "audit.export"

    // Identity capabilities
    public static let identityManage = "identity.manage"
    public static let rolesManage = "roles.manage"
    public static let groupsManage = "groups.manage"
    public static let sessionsManage = "sessions.manage"

    // Content capabilities
    public static let contentViewPublic = "content.view.public"
    public static let contentViewInternal = "content.view.internal"
    public static let contentCreate = "content.create"
    public static let contentEditOwn = "content.edit.own"
    public static let contentEditAll = "content.edit.all"
    public static let contentDelete = "content.delete"

    // DSPS capabilities
    public static let dspsCasesManage = "dsps.cases.manage"
    public static let dspsCasesViewAll = "dsps.cases.all"
    public static let dspsStudentsView = "dsps.students.view"
    public static let dspsAccommodationsCreate = "dsps.accommodations.create"
    public static let dspsAltMediaManage = "dsps.altmedia.manage"

    // Academic capabilities
    public static let recordsManage = "records.manage"
    public static let recordsViewSelf = "records.view.self"
    public static let enrollmentsManage = "enrollments.manage"
    public static let gradesManage = "grades.manage"
    public static let gradesSubmitAssigned = "grades.submit.assigned"
}
