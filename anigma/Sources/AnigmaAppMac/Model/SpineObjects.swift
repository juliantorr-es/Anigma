//
//  SpineObjects.swift
//  AnigmaAppMac
//
//  The anatomical spine of Anigma: durable nouns that define the system loop.
//  Intake -> Context -> Jobs -> Artifacts -> Evidence -> Export
//

import Foundation
import SwiftUI
import AnigmaPrimitives

// MARK: - 1. Intake

// Bridge to shared types moved to AnigmaPrimitives (SidecarContracts)
typealias SourceType = AnigmaSourceType
typealias IndexingDepth = AnigmaIndexingDepth
typealias ComputePolicy = AnigmaComputePolicy
typealias StoragePolicy = AnigmaStoragePolicy
typealias SourceStatus = AnigmaSourceStatus
typealias SourceStats = AnigmaSourceStats

/// UI Extensions for SourceType
extension SourceType {
    var icon: String {
        switch self {
        case .filesystem: return "folder.fill"
        case .git: return "chevron.left.forwardslash.chevron.right"
        case .googleDrive: return "externaldrive.fill.badge.icloud"
        case .slack: return "bubble.left.and.bubble.right.fill"
        case .microsoft365: return "square.grid.3x3.fill"
        case .jira: return "ticket.fill"
        case .confluence: return "doc.text.fill"
        case .salesforce: return "cloud.fill"
        case .notion: return "doc.on.doc.fill"
        case .email: return "envelope.fill"
        case .photos: return "photo.fill"
        }
    }

    var description: String {
        switch self {
        case .filesystem: return "Local folders and files."
        case .git: return "Local or remote Git repositories."
        case .googleDrive: return "Google Drive files and folders."
        case .slack: return "Slack workspaces and channels."
        case .microsoft365: return "OneDrive, SharePoint, and Outlook."
        case .jira: return "Jira projects and issues."
        case .confluence: return "Confluence spaces and pages."
        case .salesforce: return "Salesforce records."
        case .notion: return "Notion pages and databases."
        case .email: return "IMAP or local mail archives."
        case .photos: return "System Photo Library."
        }
    }
}

/// UI Extensions for IndexingDepth
extension IndexingDepth {
    var description: String {
        switch self {
        case .discovery: return "Enumerate files and metadata. Low trust, fast."
        case .indexing: return "Extract text and searchable content. Medium trust."
        case .understanding: return "Deep analysis: entities, map, and links. High trust."
        }
    }
}

/// A raw item that has entered the system for processing
struct IntakeItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var sourceId: String // Changed to String to match shared AnigmaSource.id
    var name: String
    var location: URL
    var size: Int64
    var status: IntakeStatus
    var importedAt: Date

    enum IntakeStatus: String, Codable {
        case queued
        case parsing
        case indexed
        case error
    }
}

// MARK: - 2. Context

/// A lens or working set (formerly IngestionScope)
/// A Context is not a folder; it is a filter and a state container.
struct AnigmaContext: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var description: String
    var icon: String // SF Symbol
    var color: String // Hex or standard color name

    // The spine connects objects to contexts
    var sourceIds: Set<String> // Changed to String
    var artifactIds: Set<UUID>

    // Policy
    var governanceMode: GovernanceMode

    init(id: UUID = UUID(), name: String, description: String = "", icon: String = "folder", color: String = "blue", sourceIds: Set<String> = [], artifactIds: Set<UUID> = [], governanceMode: GovernanceMode = .local) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.color = color
        self.sourceIds = sourceIds
        self.artifactIds = artifactIds
        self.governanceMode = governanceMode
    }

    static let empty = AnigmaContext(name: "No Context")
}

// MARK: - 3. Jobs

/// Work being done (OCR, Parsing, Analysis, etc.)
struct AnigmaJob: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var daemonJobId: String? // Added to track remote jobs from anigmad
    var title: String
    var message: String?
    var contextId: UUID?
    var status: JobStatus
    var progress: Double // 0.0 to 1.0
    var startedAt: Date
    var completedAt: Date?
    var receiptHash: String? // Added for daemon audit verification

    enum JobStatus: String, Codable {
        case pending
        case running
        case completed
        case failed
    }
}

// MARK: - 4. Artifacts

/// An output produced by the system (Summary, Dataset, Deck, Binder)
struct AnigmaArtifact: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var contextId: UUID
    var title: String
    var type: ArtifactType
    var location: URL? // If it's a file
    var previewText: String?
    var createdAt: Date

    enum ArtifactType: String, Codable {
        case text
        case structured // JSON/CSV table
        case document   // PDF/Doc
        case presentation
        case code
        case archive

        var icon: String {
            switch self {
            case .text: return "doc.text"
            case .structured: return "tablecells"
            case .document: return "doc.richtext"
            case .presentation: return "rectangle.on.rectangle"
            case .code: return "chevron.left.forwardslash.chevron.right"
            case .archive: return "archivebox"
            }
        }
    }
}

// MARK: - 5. Evidence (The Ledger)

// AnigmaEvidence is now defined in AnigmaPrimitives

// MARK: - 6. Project & Tools

/// A curated deliverable set
struct AnigmaProject: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var contextIds: Set<UUID>
    var items: [ProjectItem]

    struct ProjectItem: Identifiable, Codable, Hashable, Sendable {
        let id: UUID
        let artifactId: UUID
        let note: String?
    }
}

/// A governed operation (Local, Remote, or Agent-based)
struct AnigmaTool: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var description: String
    var inputs: [String]
    var outputs: [String]
    var isVerified: Bool
    var lastRun: Date?
}

// MARK: - 7. Operations

/// Human-centric outcome grouping multiple jobs
struct WorkItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var status: String // "In Progress", "Done", "Failed"
    var jobIds: [UUID]
    var outcome: String? // "14 Deadlines extracted", "Atlas updated"
}

/// System notification toast
struct AnigmaToast: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let title: String
    let subtitle: String?
    let icon: String?
    let actionLabel: String?
    
    init(id: UUID = UUID(), title: String, subtitle: String? = nil, icon: String? = nil, actionLabel: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.actionLabel = actionLabel
    }
}

// MARK: - Governance & Modes

enum OperatingMode: String, Codable, Hashable, Sendable {
    case readOnly
    case assistive
    case autopilot
}
