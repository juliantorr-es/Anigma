//
//  ControlCatalog.swift
//  AnigmaCore
//
//  NIST SP 800-53 and other compliance control catalogs as native data structures.
//  Controls are first-class entities, not spreadsheet rows.
//
//  This module provides:
//  - Control definitions from NIST 800-53 Rev.5
//  - FedRAMP baseline overlays (Low/Moderate/High)
//  - WCAG 2.1 / Section 508 accessibility controls
//  - Extensible framework for additional standards (ISO 27001, CJIS, etc.)
//

import AnigmaPrimitives
import ContractsCore
import Foundation

// MARK: - Control Framework

/// Identifies a compliance framework.
public struct ComplianceFramework: Sendable, Codable, Hashable {
    /// Unique framework identifier.
    public let frameworkId: String

    /// Human-readable name.
    public let name: String

    /// Version of the framework.
    public let version: String

    /// Issuing organization.
    public let organization: String

    /// URL to official documentation.
    public let documentationUrl: String?

    /// When this framework was last updated.
    public let lastUpdated: Date

    public init(
        frameworkId: String,
        name: String,
        version: String,
        organization: String,
        documentationUrl: String? = nil,
        lastUpdated: Date = Date()
    ) {
        self.frameworkId = frameworkId
        self.name = name
        self.version = version
        self.organization = organization
        self.documentationUrl = documentationUrl
        self.lastUpdated = lastUpdated
    }
}

/// Standard compliance frameworks.
public enum StandardFrameworks {
    public static let nist80053Rev5 = ComplianceFramework(
        frameworkId: "NIST-800-53-R5",
        name: "NIST SP 800-53 Revision 5",
        version: "5.0",
        organization: "National Institute of Standards and Technology",
        documentationUrl: "https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final"
    )

    public static let fedRAMPLow = ComplianceFramework(
        frameworkId: "FedRAMP-Low",
        name: "FedRAMP Low Baseline",
        version: "2023",
        organization: "Federal Risk and Authorization Management Program",
        documentationUrl: "https://www.fedramp.gov/baselines/"
    )

    public static let fedRAMPModerate = ComplianceFramework(
        frameworkId: "FedRAMP-Moderate",
        name: "FedRAMP Moderate Baseline",
        version: "2023",
        organization: "Federal Risk and Authorization Management Program",
        documentationUrl: "https://www.fedramp.gov/baselines/"
    )

    public static let fedRAMPHigh = ComplianceFramework(
        frameworkId: "FedRAMP-High",
        name: "FedRAMP High Baseline",
        version: "2023",
        organization: "Federal Risk and Authorization Management Program",
        documentationUrl: "https://www.fedramp.gov/baselines/"
    )

    public static let wcag21 = ComplianceFramework(
        frameworkId: "WCAG-2.1",
        name: "Web Content Accessibility Guidelines 2.1",
        version: "2.1",
        organization: "World Wide Web Consortium (W3C)",
        documentationUrl: "https://www.w3.org/TR/WCAG21/"
    )

    public static let section508 = ComplianceFramework(
        frameworkId: "Section-508",
        name: "Section 508 Accessibility Standards",
        version: "2017",
        organization: "U.S. Access Board",
        documentationUrl: "https://www.section508.gov/"
    )

    public static let all: [ComplianceFramework] = [
        nist80053Rev5, fedRAMPLow, fedRAMPModerate, fedRAMPHigh,
        wcag21, section508
    ]
}

// MARK: - Control Family

/// A family of related controls (e.g., AC for Access Control).
public struct ControlFamily: Sendable, Codable, Hashable {
    /// Two-letter family identifier (e.g., "AC", "AU", "CM").
    public let familyId: String

    /// Human-readable name.
    public let name: String

    /// Description of this family's purpose.
    public let description: String

    /// Which framework this family belongs to.
    public let frameworkId: String

    public init(
        familyId: String,
        name: String,
        description: String,
        frameworkId: String
    ) {
        self.familyId = familyId
        self.name = name
        self.description = description
        self.frameworkId = frameworkId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(familyId)
        hasher.combine(frameworkId)
    }
}

/// NIST 800-53 control families.
public enum NIST80053Families {
    public static let AC = ControlFamily(
        familyId: "AC",
        name: "Access Control",
        description: "Policies and procedures for managing access to information systems and resources.",
        frameworkId: "NIST-800-53-R5"
    )

    public static let AT = ControlFamily(
        familyId: "AT",
        name: "Awareness and Training",
        description: "Security awareness and training programs for personnel.",
        frameworkId: "NIST-800-53-R5"
    )

    public static let AU = ControlFamily(
        familyId: "AU",
        name: "Audit and Accountability",
        description: "Audit record creation, protection, and retention.",
        frameworkId: "NIST-800-53-R5"
    )

    public static let CA = ControlFamily(
        familyId: "CA",
        name: "Assessment, Authorization, and Monitoring",
        description: "Security assessment, authorization, and continuous monitoring.",
        frameworkId: "NIST-800-53-R5"
    )

    public static let CM = ControlFamily(
        familyId: "CM",
        name: "Configuration Management",
        description: "Configuration baselines, change control, and inventory.",
        frameworkId: "NIST-800-53-R5"
    )

    public static let CP = ControlFamily(
        familyId: "CP",
        name: "Contingency Planning",
        description: "Backup, recovery, and continuity of operations.",
        frameworkId: "NIST-800-53-R5"
    )

    public static let IA = ControlFamily(
        familyId: "IA",
        name: "Identification and Authentication",
        description: "User identification and authentication mechanisms.",
        frameworkId: "NIST-800-53-R5"
    )

    public static let IR = ControlFamily(
        familyId: "IR",
        name: "Incident Response",
        description: "Incident handling, reporting, and recovery.",
        frameworkId: "NIST-800-53-R5"
    )

    public static let MA = ControlFamily(
        familyId: "MA",
        name: "Maintenance",
        description: "System maintenance policies and procedures.",
        frameworkId: "NIST-800-53-R5"
    )

    public static let MP = ControlFamily(
        familyId: "MP",
        name: "Media Protection",
        description: "Protection of system media and information.",
        frameworkId: "NIST-800-53-R5"
    )

    public static let PE = ControlFamily(
        familyId: "PE",
        name: "Physical and Environmental Protection",
        description: "Physical access controls and environmental safeguards.",
        frameworkId: "NIST-800-53-R5"
    )

    public static let PL = ControlFamily(
        familyId: "PL",
        name: "Planning",
        description: "Security planning and system security plans.",
        frameworkId: "NIST-800-53-R5"
    )

    public static let PM = ControlFamily(
        familyId: "PM",
        name: "Program Management",
        description: "Information security program management.",
        frameworkId: "NIST-800-53-R5"
    )

    public static let PS = ControlFamily(
        familyId: "PS",
        name: "Personnel Security",
        description: "Personnel screening, termination, and transfer.",
        frameworkId: "NIST-800-53-R5"
    )

    public static let PT = ControlFamily(
        familyId: "PT",
        name: "PII Processing and Transparency",
        description: "Privacy controls for personally identifiable information.",
        frameworkId: "NIST-800-53-R5"
    )

    public static let RA = ControlFamily(
        familyId: "RA",
        name: "Risk Assessment",
        description: "Risk assessment policies and vulnerability scanning.",
        frameworkId: "NIST-800-53-R5"
    )

    public static let SA = ControlFamily(
        familyId: "SA",
        name: "System and Services Acquisition",
        description: "System development lifecycle and supply chain protection.",
        frameworkId: "NIST-800-53-R5"
    )

    public static let SC = ControlFamily(
        familyId: "SC",
        name: "System and Communications Protection",
        description: "Boundary protection, cryptography, and secure communications.",
        frameworkId: "NIST-800-53-R5"
    )

    public static let SI = ControlFamily(
        familyId: "SI",
        name: "System and Information Integrity",
        description: "Flaw remediation, malware protection, and monitoring.",
        frameworkId: "NIST-800-53-R5"
    )

    public static let SR = ControlFamily(
        familyId: "SR",
        name: "Supply Chain Risk Management",
        description: "Supply chain risk management policies and procedures.",
        frameworkId: "NIST-800-53-R5"
    )

    public static let all: [ControlFamily] = [
        AC, AT, AU, CA, CM, CP, IA, IR, MA, MP,
        PE, PL, PM, PS, PT, RA, SA, SC, SI, SR
    ]
}

// MARK: - Control Definition

/// A single control definition from a compliance framework.
public struct ControlDefinition: Sendable, Codable, Hashable, Identifiable {
    /// Unique control identifier (e.g., "AC-2", "AU-6(1)").
    public let controlId: String

    /// The framework this control belongs to.
    public let frameworkId: String

    /// The family this control belongs to.
    public let familyId: String

    /// Human-readable title.
    public let title: String

    /// Full control statement/requirement.
    public let statement: String

    /// Discussion/supplemental guidance.
    public let discussion: String?

    /// FedRAMP baseline levels that include this control.
    public let baselines: Set<ControlBaseline>

    /// Control priority (P1 = highest).
    public let priority: ControlPriority?

    /// Parent control ID (for enhancements like AC-2(1)).
    public let parentControlId: String?

    /// Related controls.
    public let relatedControls: [String]

    /// Control parameters that need organization-defined values.
    public let parameters: [ControlParameter]

    public var id: String { controlId }

    public init(
        controlId: String,
        frameworkId: String,
        familyId: String,
        title: String,
        statement: String,
        discussion: String? = nil,
        baselines: Set<ControlBaseline> = [],
        priority: ControlPriority? = nil,
        parentControlId: String? = nil,
        relatedControls: [String] = [],
        parameters: [ControlParameter] = []
    ) {
        self.controlId = controlId
        self.frameworkId = frameworkId
        self.familyId = familyId
        self.title = title
        self.statement = statement
        self.discussion = discussion
        self.baselines = baselines
        self.priority = priority
        self.parentControlId = parentControlId
        self.relatedControls = relatedControls
        self.parameters = parameters
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(controlId)
        hasher.combine(frameworkId)
    }

    public static func == (lhs: ControlDefinition, rhs: ControlDefinition) -> Bool {
        lhs.controlId == rhs.controlId && lhs.frameworkId == rhs.frameworkId
    }

    /// Whether this is a control enhancement (e.g., AC-2(1)).
    public var isEnhancement: Bool {
        parentControlId != nil || controlId.contains("(")
    }
}

/// FedRAMP baseline levels.
public enum ControlBaseline: String, Sendable, Codable, Hashable {
    case low = "low"
    case moderate = "moderate"
    case high = "high"
}

/// Control priority levels.
public enum ControlPriority: String, Sendable, Codable, Hashable {
    case p1 = "P1"
    case p2 = "P2"
    case p3 = "P3"
}

/// A parameter within a control that needs organization-defined values.
public struct ControlParameter: Sendable, Codable, Hashable {
    /// Parameter identifier (e.g., "AC-2_ODP[01]").
    public let parameterId: String

    /// Human-readable label.
    public let label: String

    /// Description of what value is needed.
    public let description: String

    /// FedRAMP-defined value (if any).
    public let fedRAMPValue: String?

    public init(
        parameterId: String,
        label: String,
        description: String,
        fedRAMPValue: String? = nil
    ) {
        self.parameterId = parameterId
        self.label = label
        self.description = description
        self.fedRAMPValue = fedRAMPValue
    }
}

// MARK: - NIST 800-53 Control Catalog

/// Catalog of NIST 800-53 Rev.5 controls.
/// This is a subset of the most critical controls for Anigma.
public enum NIST80053Controls {

    // MARK: Access Control (AC)

    public static let AC1 = ControlDefinition(
        controlId: "AC-1",
        frameworkId: "NIST-800-53-R5",
        familyId: "AC",
        title: "Policy and Procedures",
        statement: "a. Develop, document, and disseminate access control policy and procedures; b. Review and update the current policy and procedures.",
        baselines: [.low, .moderate, .high],
        priority: .p1
    )

    public static let AC2 = ControlDefinition(
        controlId: "AC-2",
        frameworkId: "NIST-800-53-R5",
        familyId: "AC",
        title: "Account Management",
        statement: "a. Define and document the types of accounts allowed and specifically prohibited; b. Assign account managers; c. Require approvals for requests to create accounts; d. Create, enable, modify, disable, and remove accounts in accordance with policy; e. Specifically authorize and monitor the use of shared and group accounts; f. Notify account managers within an organization-defined time period when accounts are no longer required, when users are terminated or transferred, and when system usage or need-to-know changes; g. Require access authorization prior to authorizing access to the system; h. Review accounts for compliance.",
        baselines: [.low, .moderate, .high],
        priority: .p1,
        parameters: [
            ControlParameter(parameterId: "AC-2_ODP[01]", label: "account types", description: "Types of accounts to be managed", fedRAMPValue: "privileged, non-privileged"),
            ControlParameter(parameterId: "AC-2_ODP[02]", label: "time period", description: "Time period for notification", fedRAMPValue: "within 24 hours")
        ]
    )

    public static let AC2_1 = ControlDefinition(
        controlId: "AC-2(1)",
        frameworkId: "NIST-800-53-R5",
        familyId: "AC",
        title: "Account Management | Automated System Account Management",
        statement: "Support the management of system accounts using automated mechanisms.",
        baselines: [.moderate, .high],
        parentControlId: "AC-2"
    )

    public static let AC3 = ControlDefinition(
        controlId: "AC-3",
        frameworkId: "NIST-800-53-R5",
        familyId: "AC",
        title: "Access Enforcement",
        statement: "Enforce approved authorizations for logical access to information and system resources in accordance with applicable access control policies.",
        baselines: [.low, .moderate, .high],
        priority: .p1
    )

    public static let AC6 = ControlDefinition(
        controlId: "AC-6",
        frameworkId: "NIST-800-53-R5",
        familyId: "AC",
        title: "Least Privilege",
        statement: "Employ the principle of least privilege, allowing only authorized accesses for users which are necessary to accomplish assigned organizational tasks.",
        baselines: [.low, .moderate, .high],
        priority: .p1
    )

    public static let AC7 = ControlDefinition(
        controlId: "AC-7",
        frameworkId: "NIST-800-53-R5",
        familyId: "AC",
        title: "Unsuccessful Logon Attempts",
        statement: "a. Enforce a limit on consecutive invalid logon attempts; b. Automatically lock the account or delay next logon attempt when the maximum is exceeded.",
        baselines: [.low, .moderate, .high],
        priority: .p2,
        parameters: [
            ControlParameter(parameterId: "AC-7_ODP[01]", label: "number", description: "Number of consecutive invalid attempts", fedRAMPValue: "not more than 3")
        ]
    )

    public static let AC17 = ControlDefinition(
        controlId: "AC-17",
        frameworkId: "NIST-800-53-R5",
        familyId: "AC",
        title: "Remote Access",
        statement: "a. Establish and document usage restrictions, configuration/connection requirements, and implementation guidance for each type of remote access allowed; b. Authorize each type of remote access prior to allowing such connections.",
        baselines: [.low, .moderate, .high],
        priority: .p1
    )

    // MARK: Audit and Accountability (AU)

    public static let AU1 = ControlDefinition(
        controlId: "AU-1",
        frameworkId: "NIST-800-53-R5",
        familyId: "AU",
        title: "Policy and Procedures",
        statement: "a. Develop, document, and disseminate audit and accountability policy and procedures; b. Review and update the current policy and procedures.",
        baselines: [.low, .moderate, .high],
        priority: .p1
    )

    public static let AU2 = ControlDefinition(
        controlId: "AU-2",
        frameworkId: "NIST-800-53-R5",
        familyId: "AU",
        title: "Event Logging",
        statement: "a. Identify the types of events that the system is capable of logging; b. Coordinate the event logging function with other entities requiring audit-related information; c. Specify the following event types for logging: successful and unsuccessful account logon events, account management events, object access, policy change, privilege functions, process tracking, and system events; d. Provide a rationale for why the event types selected for logging are deemed to be adequate.",
        baselines: [.low, .moderate, .high],
        priority: .p1
    )

    public static let AU3 = ControlDefinition(
        controlId: "AU-3",
        frameworkId: "NIST-800-53-R5",
        familyId: "AU",
        title: "Content of Audit Records",
        statement: "Ensure that audit records contain information that establishes: what type of event occurred, when the event occurred, where the event occurred, the source of the event, the outcome of the event, and the identity of any individuals, subjects, or objects associated with the event.",
        baselines: [.low, .moderate, .high],
        priority: .p1
    )

    public static let AU6 = ControlDefinition(
        controlId: "AU-6",
        frameworkId: "NIST-800-53-R5",
        familyId: "AU",
        title: "Audit Record Review, Analysis, and Reporting",
        statement: "a. Review and analyze system audit records for indications of inappropriate or unusual activity; b. Report findings to designated organizational personnel or roles; c. Adjust the level of audit record review, analysis, and reporting when there is a change in risk.",
        baselines: [.low, .moderate, .high],
        priority: .p1,
        parameters: [
            ControlParameter(parameterId: "AU-6_ODP[01]", label: "frequency", description: "Frequency of audit record review", fedRAMPValue: "at least weekly")
        ]
    )

    public static let AU9 = ControlDefinition(
        controlId: "AU-9",
        frameworkId: "NIST-800-53-R5",
        familyId: "AU",
        title: "Protection of Audit Information",
        statement: "a. Protect audit information and audit logging tools from unauthorized access, modification, and deletion; b. Alert appropriate personnel upon detection of unauthorized access, modification, or deletion of audit information.",
        baselines: [.low, .moderate, .high],
        priority: .p1
    )

    public static let AU11 = ControlDefinition(
        controlId: "AU-11",
        frameworkId: "NIST-800-53-R5",
        familyId: "AU",
        title: "Audit Record Retention",
        statement: "Retain audit records for a time period consistent with records retention policy to provide support for after-the-fact investigations of incidents and to meet regulatory and organizational information retention requirements.",
        baselines: [.low, .moderate, .high],
        priority: .p3,
        parameters: [
            ControlParameter(parameterId: "AU-11_ODP[01]", label: "time period", description: "Retention period for audit records", fedRAMPValue: "at least 1 year for Low, 3 years for Moderate/High")
        ]
    )

    // MARK: Configuration Management (CM)

    public static let CM1 = ControlDefinition(
        controlId: "CM-1",
        frameworkId: "NIST-800-53-R5",
        familyId: "CM",
        title: "Policy and Procedures",
        statement: "a. Develop, document, and disseminate configuration management policy and procedures; b. Review and update the current policy and procedures.",
        baselines: [.low, .moderate, .high],
        priority: .p1
    )

    public static let CM2 = ControlDefinition(
        controlId: "CM-2",
        frameworkId: "NIST-800-53-R5",
        familyId: "CM",
        title: "Baseline Configuration",
        statement: "a. Develop, document, and maintain a current baseline configuration of the system; b. Review and update the baseline configuration as an integral part of system component installations and upgrades.",
        baselines: [.low, .moderate, .high],
        priority: .p1
    )

    public static let CM3 = ControlDefinition(
        controlId: "CM-3",
        frameworkId: "NIST-800-53-R5",
        familyId: "CM",
        title: "Configuration Change Control",
        statement: "a. Determine and document the types of changes to the system that are configuration-controlled; b. Review proposed configuration-controlled changes; c. Approve or disapprove such changes with explicit consideration for security, privacy, and operational impacts; d. Document configuration change decisions; e. Implement approved changes; f. Retain records of configuration-controlled changes; g. Monitor and review activities associated with changes.",
        baselines: [.moderate, .high],
        priority: .p1
    )

    public static let CM8 = ControlDefinition(
        controlId: "CM-8",
        frameworkId: "NIST-800-53-R5",
        familyId: "CM",
        title: "System Component Inventory",
        statement: "a. Develop and document an inventory of system components that accurately reflects the system; b. Review and update the inventory; c. Determine that components within the system are within the authorization boundary.",
        baselines: [.low, .moderate, .high],
        priority: .p1
    )

    // MARK: Contingency Planning (CP)

    public static let CP1 = ControlDefinition(
        controlId: "CP-1",
        frameworkId: "NIST-800-53-R5",
        familyId: "CP",
        title: "Policy and Procedures",
        statement: "a. Develop, document, and disseminate contingency planning policy and procedures; b. Review and update the current policy and procedures.",
        baselines: [.low, .moderate, .high],
        priority: .p1
    )

    public static let CP9 = ControlDefinition(
        controlId: "CP-9",
        frameworkId: "NIST-800-53-R5",
        familyId: "CP",
        title: "System Backup",
        statement: "a. Conduct backups of user-level information, system-level information, and system documentation; b. Protect the confidentiality, integrity, and availability of backup information; c. Test backup information to verify media reliability and information integrity.",
        baselines: [.low, .moderate, .high],
        priority: .p1,
        parameters: [
            ControlParameter(parameterId: "CP-9_ODP[01]", label: "frequency", description: "Backup frequency", fedRAMPValue: "daily incremental, weekly full")
        ]
    )

    public static let CP10 = ControlDefinition(
        controlId: "CP-10",
        frameworkId: "NIST-800-53-R5",
        familyId: "CP",
        title: "System Recovery and Reconstitution",
        statement: "Provide for the recovery and reconstitution of the system to a known state within defined time periods after a disruption, compromise, or failure.",
        baselines: [.low, .moderate, .high],
        priority: .p1,
        parameters: [
            ControlParameter(parameterId: "CP-10_ODP[01]", label: "time period", description: "Recovery time objective", fedRAMPValue: "within 24 hours")
        ]
    )

    // MARK: Identification and Authentication (IA)

    public static let IA1 = ControlDefinition(
        controlId: "IA-1",
        frameworkId: "NIST-800-53-R5",
        familyId: "IA",
        title: "Policy and Procedures",
        statement: "a. Develop, document, and disseminate identification and authentication policy and procedures; b. Review and update the current policy and procedures.",
        baselines: [.low, .moderate, .high],
        priority: .p1
    )

    public static let IA2 = ControlDefinition(
        controlId: "IA-2",
        frameworkId: "NIST-800-53-R5",
        familyId: "IA",
        title: "Identification and Authentication (Organizational Users)",
        statement: "Uniquely identify and authenticate organizational users and associate that unique identification with processes acting on behalf of those users.",
        baselines: [.low, .moderate, .high],
        priority: .p1
    )

    public static let IA2_1 = ControlDefinition(
        controlId: "IA-2(1)",
        frameworkId: "NIST-800-53-R5",
        familyId: "IA",
        title: "Identification and Authentication | Multi-Factor Authentication to Privileged Accounts",
        statement: "Implement multi-factor authentication for access to privileged accounts.",
        baselines: [.low, .moderate, .high],
        parentControlId: "IA-2"
    )

    public static let IA5 = ControlDefinition(
        controlId: "IA-5",
        frameworkId: "NIST-800-53-R5",
        familyId: "IA",
        title: "Authenticator Management",
        statement: "Manage system authenticators by: verifying identity of the individual prior to initial authenticator distribution; establishing initial authenticator content; ensuring authenticators have sufficient strength; changing default content; establishing minimum and maximum lifetime restrictions; protecting authenticator content.",
        baselines: [.low, .moderate, .high],
        priority: .p1
    )

    // MARK: Incident Response (IR)

    public static let IR1 = ControlDefinition(
        controlId: "IR-1",
        frameworkId: "NIST-800-53-R5",
        familyId: "IR",
        title: "Policy and Procedures",
        statement: "a. Develop, document, and disseminate incident response policy and procedures; b. Review and update the current policy and procedures.",
        baselines: [.low, .moderate, .high],
        priority: .p1
    )

    public static let IR4 = ControlDefinition(
        controlId: "IR-4",
        frameworkId: "NIST-800-53-R5",
        familyId: "IR",
        title: "Incident Handling",
        statement: "a. Implement an incident handling capability that includes preparation, detection, analysis, containment, eradication, and recovery; b. Coordinate incident handling activities with contingency planning activities; c. Incorporate lessons learned from ongoing incident handling activities.",
        baselines: [.low, .moderate, .high],
        priority: .p1
    )

    public static let IR6 = ControlDefinition(
        controlId: "IR-6",
        frameworkId: "NIST-800-53-R5",
        familyId: "IR",
        title: "Incident Reporting",
        statement: "a. Require personnel to report suspected incidents to the organizational incident response capability within defined time periods; b. Report incident information to defined authorities.",
        baselines: [.low, .moderate, .high],
        priority: .p1,
        parameters: [
            ControlParameter(parameterId: "IR-6_ODP[01]", label: "time period", description: "Incident reporting time period", fedRAMPValue: "within 1 hour of discovery")
        ]
    )

    // MARK: Risk Assessment (RA)

    public static let RA1 = ControlDefinition(
        controlId: "RA-1",
        frameworkId: "NIST-800-53-R5",
        familyId: "RA",
        title: "Policy and Procedures",
        statement: "a. Develop, document, and disseminate risk assessment policy and procedures; b. Review and update the current policy and procedures.",
        baselines: [.low, .moderate, .high],
        priority: .p1
    )

    public static let RA5 = ControlDefinition(
        controlId: "RA-5",
        frameworkId: "NIST-800-53-R5",
        familyId: "RA",
        title: "Vulnerability Monitoring and Scanning",
        statement: "a. Monitor and scan for vulnerabilities; b. Employ vulnerability monitoring tools and techniques; c. Analyze vulnerability scan reports and results; d. Remediate legitimate vulnerabilities in accordance with risk; e. Share vulnerability information with designated organizations.",
        baselines: [.low, .moderate, .high],
        priority: .p1,
        parameters: [
            ControlParameter(parameterId: "RA-5_ODP[01]", label: "frequency", description: "Vulnerability scanning frequency", fedRAMPValue: "at least monthly for OS, annually for web apps")
        ]
    )

    // MARK: System and Communications Protection (SC)

    public static let SC1 = ControlDefinition(
        controlId: "SC-1",
        frameworkId: "NIST-800-53-R5",
        familyId: "SC",
        title: "Policy and Procedures",
        statement: "a. Develop, document, and disseminate system and communications protection policy and procedures; b. Review and update the current policy and procedures.",
        baselines: [.low, .moderate, .high],
        priority: .p1
    )

    public static let SC7 = ControlDefinition(
        controlId: "SC-7",
        frameworkId: "NIST-800-53-R5",
        familyId: "SC",
        title: "Boundary Protection",
        statement: "a. Monitor and control communications at the external managed interfaces to the system and at key internal managed interfaces within the system; b. Implement subnetworks for publicly accessible system components that are physically or logically separated from internal organizational networks; c. Connect to external networks or systems only through managed interfaces.",
        baselines: [.low, .moderate, .high],
        priority: .p1
    )

    public static let SC8 = ControlDefinition(
        controlId: "SC-8",
        frameworkId: "NIST-800-53-R5",
        familyId: "SC",
        title: "Transmission Confidentiality and Integrity",
        statement: "Protect the confidentiality and integrity of transmitted information.",
        baselines: [.moderate, .high],
        priority: .p1
    )

    public static let SC12 = ControlDefinition(
        controlId: "SC-12",
        frameworkId: "NIST-800-53-R5",
        familyId: "SC",
        title: "Cryptographic Key Establishment and Management",
        statement: "Establish and manage cryptographic keys when cryptography is employed within the system using automated mechanisms with supporting procedures or manual procedures.",
        baselines: [.low, .moderate, .high],
        priority: .p1
    )

    public static let SC13 = ControlDefinition(
        controlId: "SC-13",
        frameworkId: "NIST-800-53-R5",
        familyId: "SC",
        title: "Cryptographic Protection",
        statement: "a. Determine the organization-defined cryptographic uses; b. Implement defined types of cryptography required for each specified cryptographic use.",
        baselines: [.low, .moderate, .high],
        priority: .p1,
        parameters: [
            ControlParameter(parameterId: "SC-13_ODP[01]", label: "cryptography", description: "Types of cryptography", fedRAMPValue: "FIPS-validated cryptography")
        ]
    )

    public static let SC28 = ControlDefinition(
        controlId: "SC-28",
        frameworkId: "NIST-800-53-R5",
        familyId: "SC",
        title: "Protection of Information at Rest",
        statement: "Protect the confidentiality and integrity of defined information at rest.",
        baselines: [.moderate, .high],
        priority: .p1
    )

    // MARK: System and Information Integrity (SI)

    public static let SI1 = ControlDefinition(
        controlId: "SI-1",
        frameworkId: "NIST-800-53-R5",
        familyId: "SI",
        title: "Policy and Procedures",
        statement: "a. Develop, document, and disseminate system and information integrity policy and procedures; b. Review and update the current policy and procedures.",
        baselines: [.low, .moderate, .high],
        priority: .p1
    )

    public static let SI2 = ControlDefinition(
        controlId: "SI-2",
        frameworkId: "NIST-800-53-R5",
        familyId: "SI",
        title: "Flaw Remediation",
        statement: "a. Identify, report, and correct system flaws; b. Test software and firmware updates prior to installation; c. Install security-relevant updates within defined time periods; d. Incorporate flaw remediation into the configuration management process.",
        baselines: [.low, .moderate, .high],
        priority: .p1,
        parameters: [
            ControlParameter(parameterId: "SI-2_ODP[01]", label: "time period", description: "Time period for installing updates", fedRAMPValue: "within 30 days for High, 60 days for Moderate, 90 days for Low")
        ]
    )

    public static let SI4 = ControlDefinition(
        controlId: "SI-4",
        frameworkId: "NIST-800-53-R5",
        familyId: "SI",
        title: "System Monitoring",
        statement: "a. Monitor the system to detect attacks, indicators of potential attacks, and unauthorized local, network, and remote connections; b. Identify unauthorized use of the system; c. Invoke internal monitoring capabilities or deploy monitoring devices; d. Analyze detected events and anomalies; e. Adjust monitoring activity when there is a change in risk; f. Obtain legal opinion regarding compliance for monitoring activities; g. Provide monitoring information to designated personnel.",
        baselines: [.low, .moderate, .high],
        priority: .p1
    )

    public static let SI12 = ControlDefinition(
        controlId: "SI-12",
        frameworkId: "NIST-800-53-R5",
        familyId: "SI",
        title: "Information Management and Retention",
        statement: "Manage and retain information within the system and information output from the system in accordance with applicable laws, executive orders, directives, regulations, policies, standards, guidelines, and operational requirements.",
        baselines: [.low, .moderate, .high],
        priority: .p2
    )

    /// All defined NIST 800-53 controls.
    public static let all: [ControlDefinition] = [
        // Access Control
        AC1, AC2, AC2_1, AC3, AC6, AC7, AC17,
        // Audit
        AU1, AU2, AU3, AU6, AU9, AU11,
        // Configuration Management
        CM1, CM2, CM3, CM8,
        // Contingency Planning
        CP1, CP9, CP10,
        // Identification and Authentication
        IA1, IA2, IA2_1, IA5,
        // Incident Response
        IR1, IR4, IR6,
        // Risk Assessment
        RA1, RA5,
        // System and Communications Protection
        SC1, SC7, SC8, SC12, SC13, SC28,
        // System and Information Integrity
        SI1, SI2, SI4, SI12
    ]

    /// Controls required at each baseline level.
    public static func controlsForBaseline(_ baseline: ControlBaseline) -> [ControlDefinition] {
        all.filter { $0.baselines.contains(baseline) }
    }
}

// MARK: - Accessibility Control Catalog

/// WCAG 2.1 success criteria levels.
public enum WCAGLevel: String, Sendable, Codable, Hashable {
    case a = "A"
    case aa = "AA"
    case aaa = "AAA"
}

/// WCAG 2.1 principles.
public enum WCAGPrinciple: String, Sendable, Codable {
    case perceivable = "Perceivable"
    case operable = "Operable"
    case understandable = "Understandable"
    case robust = "Robust"
}

/// Accessibility control definition for WCAG/Section 508.
public struct AccessibilityControlDefinition: Sendable, Codable, Hashable, Identifiable {
    /// Success criterion identifier (e.g., "1.1.1").
    public let criterionId: String

    /// Framework ID.
    public let frameworkId: String

    /// WCAG principle.
    public let principle: WCAGPrinciple

    /// Human-readable title.
    public let title: String

    /// Full requirement text.
    public let requirement: String

    /// Conformance level.
    public let level: WCAGLevel

    /// Techniques for satisfying this criterion.
    public let techniques: [String]

    public var id: String { "\(frameworkId)-\(criterionId)" }

    public init(
        criterionId: String,
        frameworkId: String = "WCAG-2.1",
        principle: WCAGPrinciple,
        title: String,
        requirement: String,
        level: WCAGLevel,
        techniques: [String] = []
    ) {
        self.criterionId = criterionId
        self.frameworkId = frameworkId
        self.principle = principle
        self.title = title
        self.requirement = requirement
        self.level = level
        self.techniques = techniques
    }
}

/// Catalog of key WCAG 2.1 success criteria.
public enum WCAGControls {

    // MARK: Perceivable

    public static let NonTextContent = AccessibilityControlDefinition(
        criterionId: "1.1.1",
        principle: .perceivable,
        title: "Non-text Content",
        requirement: "All non-text content that is presented to the user has a text alternative that serves the equivalent purpose.",
        level: .a,
        techniques: ["G94", "G95", "H37", "ARIA6", "ARIA10"]
    )

    public static let AudioOnlyVideoOnly = AccessibilityControlDefinition(
        criterionId: "1.2.1",
        principle: .perceivable,
        title: "Audio-only and Video-only (Prerecorded)",
        requirement: "For prerecorded audio-only and prerecorded video-only media, provide an alternative.",
        level: .a,
        techniques: ["G158", "G159", "G166"]
    )

    public static let Captions = AccessibilityControlDefinition(
        criterionId: "1.2.2",
        principle: .perceivable,
        title: "Captions (Prerecorded)",
        requirement: "Captions are provided for all prerecorded audio content in synchronized media.",
        level: .a,
        techniques: ["G87", "G93", "H95"]
    )

    public static let InfoAndRelationships = AccessibilityControlDefinition(
        criterionId: "1.3.1",
        principle: .perceivable,
        title: "Info and Relationships",
        requirement: "Information, structure, and relationships conveyed through presentation can be programmatically determined or are available in text.",
        level: .a,
        techniques: ["ARIA11", "ARIA17", "G115", "G117", "G140", "H42", "H48", "H51"]
    )

    public static let UseOfColor = AccessibilityControlDefinition(
        criterionId: "1.4.1",
        principle: .perceivable,
        title: "Use of Color",
        requirement: "Color is not used as the only visual means of conveying information, indicating an action, prompting a response, or distinguishing a visual element.",
        level: .a,
        techniques: ["G14", "G111", "G182", "G183"]
    )

    public static let ContrastMinimum = AccessibilityControlDefinition(
        criterionId: "1.4.3",
        principle: .perceivable,
        title: "Contrast (Minimum)",
        requirement: "The visual presentation of text and images of text has a contrast ratio of at least 4.5:1.",
        level: .aa,
        techniques: ["G18", "G145", "G174"]
    )

    public static let ResizeText = AccessibilityControlDefinition(
        criterionId: "1.4.4",
        principle: .perceivable,
        title: "Resize Text",
        requirement: "Text can be resized without assistive technology up to 200 percent without loss of content or functionality.",
        level: .aa,
        techniques: ["G142", "G146", "G178", "G179", "C28", "C12", "C13", "C14"]
    )

    public static let Reflow = AccessibilityControlDefinition(
        criterionId: "1.4.10",
        principle: .perceivable,
        title: "Reflow",
        requirement: "Content can be presented without loss of information or functionality, and without requiring scrolling in two dimensions.",
        level: .aa,
        techniques: ["C31", "C32", "C33", "C38"]
    )

    // MARK: Operable

    public static let Keyboard = AccessibilityControlDefinition(
        criterionId: "2.1.1",
        principle: .operable,
        title: "Keyboard",
        requirement: "All functionality of the content is operable through a keyboard interface without requiring specific timings for individual keystrokes.",
        level: .a,
        techniques: ["G202", "H91", "SCR20", "SCR35"]
    )

    public static let NoKeyboardTrap = AccessibilityControlDefinition(
        criterionId: "2.1.2",
        principle: .operable,
        title: "No Keyboard Trap",
        requirement: "If keyboard focus can be moved to a component using a keyboard interface, then focus can be moved away using only a keyboard interface.",
        level: .a,
        techniques: ["G21", "F10"]
    )

    public static let FocusVisible = AccessibilityControlDefinition(
        criterionId: "2.4.7",
        principle: .operable,
        title: "Focus Visible",
        requirement: "Any keyboard operable user interface has a mode of operation where the keyboard focus indicator is visible.",
        level: .aa,
        techniques: ["G149", "G165", "G195", "C15", "SCR31"]
    )

    public static let TargetSize = AccessibilityControlDefinition(
        criterionId: "2.5.5",
        principle: .operable,
        title: "Target Size (Enhanced)",
        requirement: "The size of the target for pointer inputs is at least 44 by 44 CSS pixels.",
        level: .aaa,
        techniques: ["C42"]
    )

    // MARK: Understandable

    public static let LanguageOfPage = AccessibilityControlDefinition(
        criterionId: "3.1.1",
        principle: .understandable,
        title: "Language of Page",
        requirement: "The default human language of each Web page can be programmatically determined.",
        level: .a,
        techniques: ["H57", "SVR5"]
    )

    public static let OnFocus = AccessibilityControlDefinition(
        criterionId: "3.2.1",
        principle: .understandable,
        title: "On Focus",
        requirement: "When any user interface component receives focus, it does not initiate a change of context.",
        level: .a,
        techniques: ["G107"]
    )

    public static let OnInput = AccessibilityControlDefinition(
        criterionId: "3.2.2",
        principle: .understandable,
        title: "On Input",
        requirement: "Changing the setting of any user interface component does not automatically cause a change of context unless the user has been advised of the behavior before using the component.",
        level: .a,
        techniques: ["G80", "G13", "H32", "H84", "SCR19"]
    )

    public static let ErrorIdentification = AccessibilityControlDefinition(
        criterionId: "3.3.1",
        principle: .understandable,
        title: "Error Identification",
        requirement: "If an input error is automatically detected, the item that is in error is identified and the error is described to the user in text.",
        level: .a,
        techniques: ["G83", "G84", "G85", "ARIA21", "SCR18", "SCR32"]
    )

    public static let LabelsOrInstructions = AccessibilityControlDefinition(
        criterionId: "3.3.2",
        principle: .understandable,
        title: "Labels or Instructions",
        requirement: "Labels or instructions are provided when content requires user input.",
        level: .a,
        techniques: ["G131", "G162", "G167", "H44", "H65", "H71", "ARIA1", "ARIA9"]
    )

    // MARK: Robust

    public static let Parsing = AccessibilityControlDefinition(
        criterionId: "4.1.1",
        principle: .robust,
        title: "Parsing",
        requirement: "In content implemented using markup languages, elements have complete start and end tags, elements are nested according to their specifications, elements do not contain duplicate attributes, and any IDs are unique.",
        level: .a,
        techniques: ["G134", "G192", "H74", "H75", "H88", "H93", "H94"]
    )

    public static let NameRoleValue = AccessibilityControlDefinition(
        criterionId: "4.1.2",
        principle: .robust,
        title: "Name, Role, Value",
        requirement: "For all user interface components, the name and role can be programmatically determined; states, properties, and values that can be set by the user can be programmatically set; and notification of changes to these items is available to user agents, including assistive technologies.",
        level: .a,
        techniques: ["ARIA14", "ARIA16", "G10", "G108", "G135", "H64", "H65", "H88", "H91"]
    )

    public static let StatusMessages = AccessibilityControlDefinition(
        criterionId: "4.1.3",
        principle: .robust,
        title: "Status Messages",
        requirement: "In content implemented using markup languages, status messages can be programmatically determined through role or properties such that they can be presented to the user by assistive technologies without receiving focus.",
        level: .aa,
        techniques: ["ARIA22", "ARIA23", "G199"]
    )

    /// All WCAG 2.1 controls defined.
    public static let all: [AccessibilityControlDefinition] = [
        NonTextContent, AudioOnlyVideoOnly, Captions, InfoAndRelationships,
        UseOfColor, ContrastMinimum, ResizeText, Reflow,
        Keyboard, NoKeyboardTrap, FocusVisible, TargetSize,
        LanguageOfPage, OnFocus, OnInput, ErrorIdentification, LabelsOrInstructions,
        Parsing, NameRoleValue, StatusMessages
    ]

    /// Controls at a given level and below.
    public static func controlsForLevel(_ level: WCAGLevel) -> [AccessibilityControlDefinition] {
        switch level {
        case .a:
            return all.filter { $0.level == .a }
        case .aa:
            return all.filter { $0.level == .a || $0.level == .aa }
        case .aaa:
            return all
        }
    }
}
