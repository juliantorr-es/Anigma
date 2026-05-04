//
//  ControlImplementation.swift
//  AnigmaCore
//
//  Maps controls to their implementations within Anigma.
//  Tracks implementation status, evidence sources, and responsible modules.
//
//  Design principles:
//  - Every control is mapped to explicit implementations
//  - Evidence is structured, not screenshots
//  - Implementation status is computed, not declared
//  - Changes to implementations are governed and audited
//

import AnigmaPrimitives
import ContractsCore
import Foundation

// MARK: - Control Implementation

/// Maps a control to its implementation within Anigma.
public struct ControlImplementation: Sendable, Codable, Identifiable {
    /// Unique implementation ID.
    public let implementationId: UUID

    /// The control being implemented.
    public let controlId: String

    /// The framework the control belongs to.
    public let frameworkId: String

    /// How this control is implemented.
    public let implementationType: ImplementationType

    /// Modules that participate in implementing this control.
    public let implementingModules: [String]

    /// Specific services/actors that implement this control.
    public let implementingServices: [String]

    /// Human-readable implementation statement.
    public let statement: String

    /// Organization-defined parameter values.
    public let parameterValues: [String: String]

    /// Evidence sources for this implementation.
    public let evidenceSources: [EvidenceSource]

    /// Probes that monitor this control.
    public let probeIds: [String]

    /// Current implementation status.
    public var status: ImplementationStatus

    /// Notes about implementation gaps or risks.
    public var notes: String?

    /// When this implementation was last reviewed.
    public var lastReviewedAt: Date?

    /// Who last reviewed this implementation.
    public var lastReviewedBy: UUID?

    /// Version of this implementation record.
    public let version: Int

    /// When this record was created.
    public let createdAt: Date

    /// When this record was last modified.
    public var modifiedAt: Date

    public var id: UUID { implementationId }

    public init(
        implementationId: UUID = UUID(),
        controlId: String,
        frameworkId: String,
        implementationType: ImplementationType,
        implementingModules: [String],
        implementingServices: [String] = [],
        statement: String,
        parameterValues: [String: String] = [:],
        evidenceSources: [EvidenceSource] = [],
        probeIds: [String] = [],
        status: ImplementationStatus = .planned,
        notes: String? = nil,
        version: Int = 1
    ) {
        self.implementationId = implementationId
        self.controlId = controlId
        self.frameworkId = frameworkId
        self.implementationType = implementationType
        self.implementingModules = implementingModules
        self.implementingServices = implementingServices
        self.statement = statement
        self.parameterValues = parameterValues
        self.evidenceSources = evidenceSources
        self.probeIds = probeIds
        self.status = status
        self.notes = notes
        self.lastReviewedAt = nil
        self.lastReviewedBy = nil
        self.version = version
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}

/// How a control is implemented.
public enum ImplementationType: String, Sendable, Codable {
    /// Fully implemented in software/configuration.
    case technical = "technical"

    /// Implemented through documented procedures.
    case procedural = "procedural"

    /// Combination of technical and procedural.
    case hybrid = "hybrid"

    /// Inherited from underlying infrastructure.
    case inherited = "inherited"

    /// Not applicable to this system.
    case notApplicable = "not_applicable"
}

/// Current status of a control implementation.
public enum ImplementationStatus: String, Sendable, Codable {
    /// Control is fully implemented and verified.
    case implemented = "implemented"

    /// Control is partially implemented.
    case partiallyImplemented = "partially_implemented"

    /// Control implementation is planned.
    case planned = "planned"

    /// Control is not applicable.
    case notApplicable = "not_applicable"

    /// Control is inherited from another system.
    case inherited = "inherited"

    /// Control implementation has known issues.
    case degraded = "degraded"

    /// Control is not implemented.
    case notImplemented = "not_implemented"

    /// Whether this status counts as "compliant".
    public var isCompliant: Bool {
        switch self {
        case .implemented, .notApplicable, .inherited:
            return true
        case .partiallyImplemented, .planned, .degraded, .notImplemented:
            return false
        }
    }
}

// MARK: - Evidence Sources

/// A source of evidence for control implementation.
public struct EvidenceSource: Sendable, Codable, Hashable {
    /// Type of evidence.
    public let evidenceType: ComplianceEvidenceType

    /// Identifier for the evidence source.
    public let sourceId: String

    /// Human-readable description.
    public let description: String

    /// How to collect this evidence.
    public let collectionMethod: EvidenceCollectionMethod

    /// How often this evidence should be collected.
    public let frequency: EvidenceFrequency

    public init(
        evidenceType: ComplianceEvidenceType,
        sourceId: String,
        description: String,
        collectionMethod: EvidenceCollectionMethod = .automated,
        frequency: EvidenceFrequency = .continuous
    ) {
        self.evidenceType = evidenceType
        self.sourceId = sourceId
        self.description = description
        self.collectionMethod = collectionMethod
        self.frequency = frequency
    }
}

/// Types of compliance evidence.
/// NOTE: Renamed from EvidenceType to avoid collision with EvidenceAuthorityImpl.EvidenceType
public enum ComplianceEvidenceType: String, Sendable, Codable, Hashable {
    /// Audit log entries.
    case auditLog = "audit_log"

    /// System configuration.
    case configuration = "configuration"

    /// Metrics and telemetry.
    case metrics = "metrics"

    /// Policy documents.
    case policy = "policy"

    /// Test results.
    case testResults = "test_results"

    /// Manual assessment.
    case assessment = "assessment"

    /// Scan results (vulnerability, accessibility).
    case scanResults = "scan_results"

    /// Training records.
    case trainingRecords = "training_records"

    /// Incident reports.
    case incidentReport = "incident_report"

    /// Change records.
    case changeRecord = "change_record"
}

/// How evidence is collected.
public enum EvidenceCollectionMethod: String, Sendable, Codable, Hashable {
    /// Collected automatically by the system.
    case automated = "automated"

    /// Collected through manual processes.
    case manual = "manual"

    /// Combination of automated and manual.
    case hybrid = "hybrid"
}

/// Frequency of evidence collection.
public enum EvidenceFrequency: String, Sendable, Codable, Hashable {
    /// Real-time or near-real-time.
    case continuous = "continuous"

    /// Daily collection.
    case daily = "daily"

    /// Weekly collection.
    case weekly = "weekly"

    /// Monthly collection.
    case monthly = "monthly"

    /// Quarterly collection.
    case quarterly = "quarterly"

    /// Annual collection.
    case annual = "annual"

    /// On-demand or as needed.
    case onDemand = "on_demand"
}

// MARK: - Evidence Artifacts

/// A collected evidence artifact.
public struct EvidenceArtifact: Sendable, Codable, Identifiable {
    /// Unique artifact ID.
    public let artifactId: UUID

    /// Which control this is evidence for.
    public let controlId: String

    /// Framework ID.
    public let frameworkId: String

    /// The implementation this supports.
    public let implementationId: UUID

    /// Type of evidence.
    public let evidenceType: ComplianceEvidenceType

    /// When this evidence was collected.
    public let collectedAt: Date

    /// Time period this evidence covers.
    public let periodStart: Date

    /// End of coverage period.
    public let periodEnd: Date

    /// Summary of what the evidence shows.
    public let summary: String

    /// Structured data (JSON-encodable).
    public let data: [String: ComplianceValue]

    /// Hash of the evidence for integrity.
    public let contentHash: String

    /// Whether this evidence supports compliance.
    public let supportsCompliance: Bool

    /// Any findings or issues.
    public let findings: [EvidenceFinding]

    public var id: UUID { artifactId }

    public init(
        artifactId: UUID = UUID(),
        controlId: String,
        frameworkId: String,
        implementationId: UUID,
        evidenceType: ComplianceEvidenceType,
        periodStart: Date,
        periodEnd: Date,
        summary: String,
        data: [String: ComplianceValue] = [:],
        contentHash: String = "",
        supportsCompliance: Bool = true,
        findings: [EvidenceFinding] = []
    ) {
        self.artifactId = artifactId
        self.controlId = controlId
        self.frameworkId = frameworkId
        self.implementationId = implementationId
        self.evidenceType = evidenceType
        self.collectedAt = Date()
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.summary = summary
        self.data = data
        self.contentHash = contentHash
        self.supportsCompliance = supportsCompliance
        self.findings = findings
    }
}

/// A finding from evidence collection.
public struct EvidenceFinding: Sendable, Codable {
    /// Finding severity.
    public let severity: FindingSeverity

    /// Finding description.
    public let description: String

    /// Remediation recommendation.
    public let remediation: String?

    /// Whether this has been addressed.
    public var addressed: Bool

    public init(
        severity: FindingSeverity,
        description: String,
        remediation: String? = nil,
        addressed: Bool = false
    ) {
        self.severity = severity
        self.description = description
        self.remediation = remediation
        self.addressed = addressed
    }
}

/// Severity of a compliance finding.
public enum FindingSeverity: String, Sendable, Codable {
    case critical = "critical"
    case high = "high"
    case medium = "medium"
    case low = "low"
    case informational = "informational"
}

/// Type-erased codable value for flexible compliance data.
public indirect enum ComplianceValue: Sendable, Codable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([ComplianceValue])
    case dictionary([String: ComplianceValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let array = try? container.decode([ComplianceValue].self) {
            self = .array(array)
        } else if let dict = try? container.decode([String: ComplianceValue].self) {
            self = .dictionary(dict)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unable to decode value")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .dictionary(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - Anigma Control Implementations

/// Pre-defined control implementations for Anigma core modules.
public enum AnigmaControlImplementations {

    // MARK: Access Control Implementations

    public static let AC2_Implementation = ControlImplementation(
        controlId: "AC-2",
        frameworkId: "NIST-800-53-R5",
        implementationType: .technical,
        implementingModules: ["AnigmaCore", "Identity"],
        implementingServices: ["IdentityService", "AccessController", "GovernanceController"],
        statement: """
        Anigma implements account management through the Identity module:
        a. Account types (human, service, agent, integration) are defined in PrincipalType.
        b. IdentityService manages principal creation, modification, and deprovisioning.
        c. All account changes require appropriate roles and are governed through WriteGate.
        d. RoleAssignmentComponent tracks time-bounded role assignments with audit.
        e. GroupComponent and GroupMembershipComponent manage shared accounts.
        f. DeprovisioningRecord and ImmediateDeprovisioner handle account removal.
        g. AccessController enforces authorization before access.
        h. Periodic reviews are tracked through compliance probes.
        """,
        parameterValues: [
            "AC-2_ODP[01]": "human, service, agent, integration",
            "AC-2_ODP[02]": "immediately upon detection"
        ],
        evidenceSources: [
            EvidenceSource(
                evidenceType: .auditLog,
                sourceId: "audit.identity",
                description: "Audit log entries for all identity operations"
            ),
            EvidenceSource(
                evidenceType: .configuration,
                sourceId: "identity.roles",
                description: "Role definitions and assignments"
            ),
            EvidenceSource(
                evidenceType: .metrics,
                sourceId: "observatorium.identity",
                description: "Identity metrics including deprovisioning times"
            )
        ],
        probeIds: ["probe.ac2.account_review", "probe.ac2.deprovisioning"],
        status: .implemented
    )

    public static let AC3_Implementation = ControlImplementation(
        controlId: "AC-3",
        frameworkId: "NIST-800-53-R5",
        implementationType: .technical,
        implementingModules: ["AnigmaCore", "Security"],
        implementingServices: ["AccessController", "SecuredWorld", "WriteGate"],
        statement: """
        Anigma enforces access through multiple layers:
        - SecuredWorld wraps all ECS World access with principal context.
        - AccessController evaluates role-based and attribute-based policies.
        - WriteGate enforces additional checks before any mutation.
        - TenantIsolationEnforcer prevents cross-tenant access.
        - SecurityOperationRegistry profiles all operations with risk levels.
        - All access decisions are logged to AuditLog.
        """,
        evidenceSources: [
            EvidenceSource(
                evidenceType: .auditLog,
                sourceId: "audit.access",
                description: "Access control decision audit entries"
            ),
            EvidenceSource(
                evidenceType: .testResults,
                sourceId: "tests.security",
                description: "Security test results for access enforcement"
            )
        ],
        probeIds: ["probe.ac3.access_enforcement"],
        status: .implemented
    )

    public static let AU2_Implementation = ControlImplementation(
        controlId: "AU-2",
        frameworkId: "NIST-800-53-R5",
        implementationType: .technical,
        implementingModules: ["AnigmaCore", "Privacy"],
        implementingServices: ["AuditLog", "GovernanceController"],
        statement: """
        Anigma logs the following event types through AuditLog:
        - Successful and unsuccessful logon events (via Identity/Session)
        - Account management events (create, modify, deprovision)
        - Object access events (read/write through SecuredWorld)
        - Policy changes (via GovernanceController)
        - Privilege function usage (role assignments, kill switch)
        - Process tracking (automation executions, agent invocations)
        - System events (startup, shutdown, errors)
        All events include principal, timestamp, outcome, and context.
        """,
        evidenceSources: [
            EvidenceSource(
                evidenceType: .auditLog,
                sourceId: "audit.events",
                description: "Complete audit event log"
            ),
            EvidenceSource(
                evidenceType: .configuration,
                sourceId: "audit.config",
                description: "Audit configuration and event types"
            )
        ],
        probeIds: ["probe.au2.event_coverage"],
        status: .implemented
    )

    public static let AU9_Implementation = ControlImplementation(
        controlId: "AU-9",
        frameworkId: "NIST-800-53-R5",
        implementationType: .technical,
        implementingModules: ["AnigmaCore", "Security"],
        implementingServices: ["AuditLog", "AuditIntegrityManager", "KeyManager"],
        statement: """
        Anigma protects audit information through:
        a. AuditLog is implemented as an actor with controlled access.
        b. AuditIntegrityManager maintains hash-chained entries with Ed25519 signed anchors.
        c. Audit entries are append-only; modification/deletion is prevented.
        d. Access to audit data requires specific audit.read capability.
        e. Integrity verification detects any tampering attempts.
        f. Alerts are generated on integrity failures or unauthorized access attempts.
        """,
        evidenceSources: [
            EvidenceSource(
                evidenceType: .auditLog,
                sourceId: "audit.integrity",
                description: "Audit integrity verification logs"
            ),
            EvidenceSource(
                evidenceType: .metrics,
                sourceId: "observatorium.audit_integrity",
                description: "Audit integrity check metrics"
            )
        ],
        probeIds: ["probe.au9.integrity_check"],
        status: .implemented
    )

    public static let CM3_Implementation = ControlImplementation(
        controlId: "CM-3",
        frameworkId: "NIST-800-53-R5",
        implementationType: .hybrid,
        implementingModules: ["AnigmaCore", "Updates"],
        implementingServices: ["UpdateService", "MigrationEngine", "GovernanceController"],
        statement: """
        Anigma implements configuration change control through:
        a. ReleaseManifest documents all changes with version, migrations, and impacts.
        b. UpdateOrchestrator manages change phases (announced, draining, blocked).
        c. MigrationEngine validates changes before execution with dry-run capability.
        d. All changes require governance approval through WriteGate.
        e. Change decisions are logged to AuditLog with justification.
        f. MigrationHistory maintains complete change records.
        g. Observatorium monitors change impacts and anomalies.
        """,
        evidenceSources: [
            EvidenceSource(
                evidenceType: .changeRecord,
                sourceId: "updates.releases",
                description: "Release manifests and migration history"
            ),
            EvidenceSource(
                evidenceType: .auditLog,
                sourceId: "audit.updates",
                description: "Update and migration audit entries"
            )
        ],
        probeIds: ["probe.cm3.change_control"],
        status: .implemented
    )

    public static let CP9_Implementation = ControlImplementation(
        controlId: "CP-9",
        frameworkId: "NIST-800-53-R5",
        implementationType: .technical,
        implementingModules: ["AnigmaCore", "Storage"],
        implementingServices: ["StorageService", "BackupScheduler", "KeyManager"],
        statement: """
        Anigma implements system backup through:
        a. BackupSnapshot captures user data, system configuration, and documentation.
        b. BackupSchedule enforces organization-defined backup frequency.
        c. All backups are encrypted using KeyManager with AES-256-GCM.
        d. BackupValidation verifies backup integrity and recoverability.
        e. RecoveryOperation supports tested restore procedures.
        f. DisasterRecoveryTargets track RPO/RTO compliance.
        """,
        parameterValues: [
            "CP-9_ODP[01]": "daily incremental, weekly full"
        ],
        evidenceSources: [
            EvidenceSource(
                evidenceType: .metrics,
                sourceId: "observatorium.backup",
                description: "Backup metrics including success rate and timing"
            ),
            EvidenceSource(
                evidenceType: .testResults,
                sourceId: "backup.validation",
                description: "Backup validation and recovery test results"
            )
        ],
        probeIds: ["probe.cp9.backup_compliance"],
        status: .implemented
    )

    public static let IA2_Implementation = ControlImplementation(
        controlId: "IA-2",
        frameworkId: "NIST-800-53-R5",
        implementationType: .technical,
        implementingModules: ["AnigmaCore", "Identity"],
        implementingServices: ["IdentityService", "SessionComponent"],
        statement: """
        Anigma uniquely identifies and authenticates users through:
        - PrincipalIdentity provides stable internal UUIDs for all users.
        - ExternalIdentifierComponent links to organizational identity systems.
        - SessionComponent tracks authentication method, MFA status, and client info.
        - All system processes are associated with authenticated principals.
        - Service accounts and agents have distinct PrincipalType designations.
        """,
        evidenceSources: [
            EvidenceSource(
                evidenceType: .auditLog,
                sourceId: "audit.authentication",
                description: "Authentication event logs"
            ),
            EvidenceSource(
                evidenceType: .configuration,
                sourceId: "identity.external",
                description: "External identity provider configurations"
            )
        ],
        probeIds: ["probe.ia2.authentication"],
        status: .implemented
    )

    public static let SC12_Implementation = ControlImplementation(
        controlId: "SC-12",
        frameworkId: "NIST-800-53-R5",
        implementationType: .technical,
        implementingModules: ["AnigmaCore", "Security"],
        implementingServices: ["KeyManager"],
        statement: """
        Anigma manages cryptographic keys through KeyManager:
        - Key generation uses CryptoKit with secure random.
        - Key types include master keys, data encryption keys, and signing keys.
        - KeyMetadata tracks key lifecycle, rotation schedule, and usage.
        - Key rotation is automated based on policy.
        - Key access is controlled and audited.
        - Keys are stored using platform secure storage (Keychain/Secure Enclave).
        """,
        evidenceSources: [
            EvidenceSource(
                evidenceType: .auditLog,
                sourceId: "audit.keys",
                description: "Key management audit entries"
            ),
            EvidenceSource(
                evidenceType: .configuration,
                sourceId: "keys.metadata",
                description: "Key metadata and rotation schedules"
            )
        ],
        probeIds: ["probe.sc12.key_management"],
        status: .implemented
    )

    public static let SC13_Implementation = ControlImplementation(
        controlId: "SC-13",
        frameworkId: "NIST-800-53-R5",
        implementationType: .technical,
        implementingModules: ["AnigmaCore", "Security"],
        implementingServices: ["KeyManager"],
        statement: """
        Anigma implements FIPS-validated cryptography:
        - AES-256-GCM for symmetric encryption (via CryptoKit).
        - Ed25519 for digital signatures.
        - HKDF for key derivation.
        - Secure random generation for keys and nonces.
        - All cryptographic operations use Apple CryptoKit which provides FIPS-validated implementations on supported platforms.
        """,
        parameterValues: [
            "SC-13_ODP[01]": "AES-256-GCM, Ed25519, HKDF (via CryptoKit)"
        ],
        evidenceSources: [
            EvidenceSource(
                evidenceType: .configuration,
                sourceId: "crypto.algorithms",
                description: "Cryptographic algorithm configuration"
            ),
            EvidenceSource(
                evidenceType: .testResults,
                sourceId: "tests.crypto",
                description: "Cryptographic implementation test results"
            )
        ],
        probeIds: ["probe.sc13.crypto_compliance"],
        status: .implemented
    )

    public static let SI4_Implementation = ControlImplementation(
        controlId: "SI-4",
        frameworkId: "NIST-800-53-R5",
        implementationType: .technical,
        implementingModules: ["AnigmaCore", "Security", "Observatorium"],
        implementingServices: ["Observatorium", "PolicyEnforcementEngine", "ThreatDetector", "ModelIntegrityManager"],
        statement: """
        Anigma monitors for attacks and anomalies through:
        a. ObservatoriumService collects system-wide telemetry and metrics.
        b. SessionRiskTracker monitors for suspicious session behavior.
        c. BypassProtection detects attempts to circumvent security controls.
        d. ModelIntegrityManager detects drift and poisoning in AI components.
        e. PolicyEnforcementEngine responds to detected threats.
        f. AlertService notifies designated personnel.
        g. Monitoring levels adjust based on TenantConfiguration and risk.
        """,
        evidenceSources: [
            EvidenceSource(
                evidenceType: .metrics,
                sourceId: "observatorium.security",
                description: "Security monitoring metrics"
            ),
            EvidenceSource(
                evidenceType: .auditLog,
                sourceId: "audit.threats",
                description: "Threat detection and response audit entries"
            )
        ],
        probeIds: ["probe.si4.monitoring"],
        status: .implemented
    )

    /// All Anigma control implementations.
    public static let all: [ControlImplementation] = [
        AC2_Implementation,
        AC3_Implementation,
        AU2_Implementation,
        AU9_Implementation,
        CM3_Implementation,
        CP9_Implementation,
        IA2_Implementation,
        SC12_Implementation,
        SC13_Implementation,
        SI4_Implementation
    ]
}
