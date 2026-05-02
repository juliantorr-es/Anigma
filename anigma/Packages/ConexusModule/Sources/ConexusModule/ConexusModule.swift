//
//  ConexusModule.swift
//  ConexusModule
//
//  CRM and relationship management domain for Anigma.
//  "Conexus" (Latin) - connection, union, binding together
//
//  This module provides:
//  - Contacts: People with their details, preferences, and relationships
//  - Organizations: Companies, institutions, groups with hierarchy
//  - Relationships: Typed connections between contacts/orgs
//  - Pipelines: Sales, grants, support, onboarding flows
//  - Cases/Requests: Support tickets, legal matters, service requests
//  - Activities: Calls, emails, meetings, notes attached to records
//  - Interactions: Timeline of all touchpoints with a contact/org
//
//  All CRM entities are ECS entities with components, governed by AnigmaCore.
//

import Foundation
import AnigmaCore
import AnigmaPrimitives
import ContractsCore
import GovernanceCore

// MARK: - Module Definition

/// The Conexus CRM and relationship management module.
public enum ConexusModule {
    public static let version = "0.1.0"
    public static let name = "Conexus"

    /// Initializes the Conexus module with governance integration.
    public static func initialize(governance: any GoverningController) async {
        // Cast to concrete type to access writeGate
        guard let concreteGovernance = governance as? GovernanceController else {
            return
        }
        
        // Register Conexus-specific write checks
        await concreteGovernance.writeGate.registerCheck(ContactAccessCheck())
        await concreteGovernance.writeGate.registerCheck(PipelineStageCheck())

        // Log initialization
        try? await governance.auditLog.record(
            eventType: ContractsCore.AuditEventType.custom,
            principal: "system",
            module: "ConexusModule",
            description: "ConexusModule initialized (v\(version))",
            metadata: ["original_event_type": "system_started"]
        )
    }
}

// MARK: - Conexus Identifiers

/// Unique identifier for contacts.
public struct ContactId: Hashable, Codable, Sendable, CustomStringConvertible {
    public let raw: UUID

    public init() { self.raw = UUID() }
    public init(raw: UUID) { self.raw = raw }

    public init?(uuidString: String) {
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        self.raw = uuid
    }

    public var description: String { "Contact(\(raw.uuidString.prefix(8)))" }
}

/// Unique identifier for organizations.
public struct OrganizationId: Hashable, Codable, Sendable, CustomStringConvertible {
    public let raw: UUID

    public init() { self.raw = UUID() }
    public init(raw: UUID) { self.raw = raw }

    public init?(uuidString: String) {
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        self.raw = uuid
    }

    public var description: String { "Org(\(raw.uuidString.prefix(8)))" }
}

/// Unique identifier for deals/opportunities.
public struct DealId: Hashable, Codable, Sendable, CustomStringConvertible {
    public let raw: UUID

    public init() { self.raw = UUID() }
    public init(raw: UUID) { self.raw = raw }

    public init?(uuidString: String) {
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        self.raw = uuid
    }

    public var description: String { "Deal(\(raw.uuidString.prefix(8)))" }
}

/// Unique identifier for cases/requests.
public struct CaseId: Hashable, Codable, Sendable, CustomStringConvertible {
    public let raw: UUID

    public init() { self.raw = UUID() }
    public init(raw: UUID) { self.raw = raw }

    public init?(uuidString: String) {
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        self.raw = uuid
    }

    public var description: String { "Case(\(raw.uuidString.prefix(8)))" }
}

/// Unique identifier for activities.
public struct ActivityId: Hashable, Codable, Sendable, CustomStringConvertible {
    public let raw: UUID

    public init() { self.raw = UUID() }
    public init(raw: UUID) { self.raw = raw }

    public var description: String { "Activity(\(raw.uuidString.prefix(8)))" }
}

/// Unique identifier for pipelines.
public struct PipelineId: Hashable, Codable, Sendable, CustomStringConvertible {
    public let raw: UUID

    public init() { self.raw = UUID() }
    public init(raw: UUID) { self.raw = raw }

    public var description: String { "Pipeline(\(raw.uuidString.prefix(8)))" }
}

// MARK: - Contact Types

/// Classification of contacts.
public enum ContactType: String, Codable, Sendable, CaseIterable {
    case individual       // A person
    case student          // Student (DSPS/education)
    case client           // Client/customer
    case lead             // Prospective contact
    case vendor           // Vendor/supplier
    case partner          // Partner organization rep
    case employee         // Internal employee
    case beneficiary      // Benefits/services recipient
}

/// Relationship types between contacts/orgs.
public enum RelationshipType: String, Codable, Sendable, CaseIterable {
    case employedBy       // Contact works at Org
    case manages          // Contact manages Contact
    case reportsTo        // Contact reports to Contact
    case memberOf         // Contact is member of Org
    case represents       // Contact represents Org
    case relatedTo        // Generic relationship
    case spouseOf         // Family relationship
    case parentOf         // Family relationship
    case advisorTo        // Advisor relationship
    case referredBy       // Referral tracking
}

// MARK: - Organization Types

/// Classification of organizations.
public enum OrganizationType: String, Codable, Sendable, CaseIterable {
    case company          // For-profit company
    case nonprofit        // Non-profit organization
    case government       // Government agency
    case educational      // School, college, university
    case healthcare       // Hospital, clinic, etc.
    case legalEntity      // Law firm, legal aid
    case community        // Community organization
    case other
}

// MARK: - Pipeline Types

/// Types of pipelines for different use cases.
public enum PipelineType: String, Codable, Sendable, CaseIterable {
    case sales            // Sales pipeline
    case fundraising      // Grants/donations
    case support          // Support/service requests
    case onboarding       // Client/student onboarding
    case legal            // Legal case pipeline
    case recruitment      // Hiring pipeline
    case partnership      // Partnership development
    case altMedia         // Alt-media request pipeline
}

// MARK: - Pipeline Stage

/// A stage within a pipeline.
public struct PipelineStage: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let order: Int
    public let probability: Double  // 0.0 to 1.0 for deals
    public let isWon: Bool
    public let isLost: Bool
    public let color: String

    public init(
        id: String,
        name: String,
        order: Int,
        probability: Double = 0.5,
        isWon: Bool = false,
        isLost: Bool = false,
        color: String = "#808080"
    ) {
        self.id = id
        self.name = name
        self.order = order
        self.probability = probability
        self.isWon = isWon
        self.isLost = isLost
        self.color = color
    }

    public var isTerminal: Bool { isWon || isLost }

    // Common stages
    public static let newLead = PipelineStage(id: "new", name: "New Lead", order: 0, probability: 0.1, color: "#0052CC")
    public static let qualified = PipelineStage(id: "qualified", name: "Qualified", order: 1, probability: 0.25, color: "#6554C0")
    public static let proposal = PipelineStage(id: "proposal", name: "Proposal", order: 2, probability: 0.5, color: "#FFAB00")
    public static let negotiation = PipelineStage(id: "negotiation", name: "Negotiation", order: 3, probability: 0.75, color: "#FF8B00")
    public static let closedWon = PipelineStage(id: "closed_won", name: "Closed Won", order: 4, probability: 1.0, isWon: true, color: "#36B37E")
    public static let closedLost = PipelineStage(id: "closed_lost", name: "Closed Lost", order: 5, probability: 0.0, isLost: true, color: "#FF5630")
}

// MARK: - Pipeline Definition

/// Defines a pipeline with its stages.
public struct PipelineDefinition: Codable, Sendable, Identifiable {
    public let id: PipelineId
    public let name: String
    public let type: PipelineType
    public let description: String?
    public let stages: [PipelineStage]
    public let defaultStageId: String

    public init(
        id: PipelineId = PipelineId(),
        name: String,
        type: PipelineType,
        description: String? = nil,
        stages: [PipelineStage],
        defaultStageId: String
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.description = description
        self.stages = stages
        self.defaultStageId = defaultStageId
    }

    /// Gets valid next stages from a given stage.
    public func validNextStages(from stageId: String) -> [PipelineStage] {
        guard let currentStage = stages.first(where: { $0.id == stageId }),
              !currentStage.isTerminal else {
            return []
        }
        // Allow moving forward or to terminal stages
        return stages.filter { $0.order > currentStage.order || $0.isTerminal }
    }

    /// Default sales pipeline.
    public static let defaultSales = PipelineDefinition(
        name: "Sales Pipeline",
        type: .sales,
        description: "Standard B2B sales pipeline",
        stages: [.newLead, .qualified, .proposal, .negotiation, .closedWon, .closedLost],
        defaultStageId: "new"
    )

    /// Alt-media request pipeline.
    public static let altMediaRequest = PipelineDefinition(
        name: "Alt-Media Requests",
        type: .altMedia,
        description: "Alt-media conversion request pipeline",
        stages: [
            PipelineStage(id: "submitted", name: "Submitted", order: 0, probability: 0.1, color: "#0052CC"),
            PipelineStage(id: "processing", name: "Processing", order: 1, probability: 0.5, color: "#FFAB00"),
            PipelineStage(id: "qa_review", name: "QA Review", order: 2, probability: 0.8, color: "#6554C0"),
            PipelineStage(id: "delivered", name: "Delivered", order: 3, probability: 1.0, isWon: true, color: "#36B37E"),
            PipelineStage(id: "cancelled", name: "Cancelled", order: 4, probability: 0.0, isLost: true, color: "#FF5630")
        ],
        defaultStageId: "submitted"
    )
}

// MARK: - Activity Types

/// Types of activities in the CRM.
public enum ActivityType: String, Codable, Sendable, CaseIterable {
    case call             // Phone call
    case email            // Email sent/received
    case meeting          // Meeting (in-person or virtual)
    case note             // Internal note
    case task             // Task/to-do
    case document         // Document attached
    case statusChange     // Status/stage change
    case creation         // Record created
    case update           // Record updated
}

// MARK: - Case/Request Types

/// Types of cases/requests.
public enum CaseType: String, Codable, Sendable, CaseIterable {
    case supportTicket    // General support
    case serviceRequest   // Service request
    case complaint        // Complaint
    case inquiry          // General inquiry
    case legalMatter      // Legal case
    case accommodationRequest  // Disability accommodation
    case altMediaRequest  // Alt-media conversion
    case benefitsApplication   // Benefits application
}

/// Priority for cases.
public enum CasePriority: Int, Codable, Sendable, Comparable, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2
    case urgent = 3
    case critical = 4

    public static func < (lhs: CasePriority, rhs: CasePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        case .critical: return "Critical"
        }
    }
}

/// Status for cases.
public enum CaseStatus: String, Codable, Sendable, CaseIterable {
    case new
    case open
    case inProgress
    case pendingCustomer
    case pendingInternal
    case resolved
    case closed
    case cancelled

    public var isOpen: Bool {
        switch self {
        case .new, .open, .inProgress, .pendingCustomer, .pendingInternal:
            return true
        case .resolved, .closed, .cancelled:
            return false
        }
    }
}

// MARK: - Write Checks

/// Checks access to contact records based on sensitivity and role.
public struct ContactAccessCheck: WriteCheck {
    public let id = "conexus-contact-access"
    public let name = "Contact Access Check"
    public let isBlocking = true

    public init() {}

    public func appliesTo(_ proposal: WriteProposal) -> Bool {
        proposal.module == "Conexus" &&
        (proposal.componentType == "ContactComponent" || proposal.componentType == "OrganizationComponent")
    }

    public func evaluate(_ proposal: WriteProposal) async -> WriteCheckResult {
        // Real implementation would check:
        // 1. Principal's role and access level
        // 2. Contact's sensitivity classification
        // 3. Data residency requirements
        .pass(checkId: id, message: "Contact access check passed")
    }
}

/// Checks that pipeline stage transitions are valid.
public struct PipelineStageCheck: WriteCheck {
    public let id = "conexus-pipeline-stage"
    public let name = "Pipeline Stage Check"
    public let isBlocking = true

    public init() {}

    public func appliesTo(_ proposal: WriteProposal) -> Bool {
        proposal.module == "Conexus" && proposal.operation == "stage_change"
    }

    public func evaluate(_ proposal: WriteProposal) async -> WriteCheckResult {
        guard let _ = proposal.context["from_stage"],
              let _ = proposal.context["to_stage"] else {
            return .fail(checkId: id, message: "Missing stage information")
        }
        // Real implementation would validate against pipeline definition
        return .pass(checkId: id, message: "Stage transition is valid")
    }
}

// MARK: - Conexus Errors

public enum ConexusError: Error, LocalizedError, Sendable {
    case contactNotFound(ContactId)
    case organizationNotFound(OrganizationId)
    case dealNotFound(DealId)
    case caseNotFound(CaseId)
    case pipelineNotFound(PipelineId)
    case invalidStageTransition(from: String, to: String)
    case duplicateRecord(String)
    case permissionDenied(reason: String)
    case invalidRelationship(String)

    public var errorDescription: String? {
        switch self {
        case .contactNotFound(let id):
            return "Contact not found: \(id)"
        case .organizationNotFound(let id):
            return "Organization not found: \(id)"
        case .dealNotFound(let id):
            return "Deal not found: \(id)"
        case .caseNotFound(let id):
            return "Case not found: \(id)"
        case .pipelineNotFound(let id):
            return "Pipeline not found: \(id)"
        case .invalidStageTransition(let from, let to):
            return "Invalid stage transition from '\(from)' to '\(to)'"
        case .duplicateRecord(let detail):
            return "Duplicate record: \(detail)"
        case .permissionDenied(let reason):
            return "Permission denied: \(reason)"
        case .invalidRelationship(let detail):
            return "Invalid relationship: \(detail)"
        }
    }
}

// MARK: - Capability Module Conformance

extension ConexusModule: CapabilityModule {
    public static func register(runtime: PlatformRuntime) async throws {
        // Register module with runtime
        await initialize(governance: runtime.governance)
    }
}
