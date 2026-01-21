//
//  AnigmaRoles.swift
//  AnigmaAppMac
//
//  Role and surface definitions for the Bauhaus architecture.
//

import Foundation

/// User role determines which shell/surfaces are available
enum AnigmaRole: String, CaseIterable, Identifiable {
    case user       // Standard user surfaces
    case worker     // Job queue management
    case admin      // System administration
    case developer  // Debug/trace tools

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .user: return "User"
        case .worker: return "Worker"
        case .admin: return "Admin"
        case .developer: return "Developer"
        }
    }
}

/// App mode: Life (compass, inbox, projects) vs Build (studio, tools)
enum AppMode: String, CaseIterable, Identifiable, Codable, Hashable {
    case life = "Life"
    case work = "Work"
    case insight = "Insight"
    case build = "Build"
    case develop = "Develop"

    var id: Self { self }
}

/// Knowledge map lenses
enum AtlasLens: String, CaseIterable, Identifiable, Hashable {
    case contexts = "Contexts"
    case people = "People"
    case money = "Money"
    case health = "Health"
    case learning = "Learning"
    case projects = "Project Map"
    case timeline = "Timeline"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .contexts: return "circle.hexagongrid.fill"
        case .people: return "person.2.fill"
        case .money: return "dollarsign.circle.fill"
        case .health: return "heart.fill"
        case .learning: return "book.fill"
        case .projects: return "folder.fill"
        case .timeline: return "calendar"
        }
    }
}

/// Governance constraints
enum GovernanceMode: String, CaseIterable, Identifiable, Hashable, Codable {
    case local = "Local First"
    case verify = "Verify Only"
    case trusted = "Trusted Host"
    case off = "Ungoverned"

    var id: String { rawValue }
}

/// System privacy settings
struct PrivacySettings: Codable, Sendable {
    var allowCloudAI: Bool = false
    var allowCrashReports: Bool = true
    var allowAnalytics: Bool = false
}

/// System governance settings (Admin Console)
struct GovernanceSettings: Codable, Sendable {
    var agentStance: GovernanceStance = .sandbox
    var requireAuditReceipts: Bool = true
    var maxParallelJobs: Int = 4
    var autoVerifyReceipts: Bool = true
}

/// Agent execution stance
enum GovernanceStance: String, CaseIterable, Identifiable, Hashable, Codable {
    case sandbox = "Sandbox (Proposal Only)"
    case directWrite = "Direct Write (Bypass Review)"

    var id: String { rawValue }
}

/// User surfaces (for .user role)
enum UserSurface: String, CaseIterable, Identifiable {
    case compass    // Now dashboard
    case inbox      // Triage queue
    case atlas      // Lenses (People, Money, Health, etc.)
    case ask        // Research panel
    case projects   // Project workspaces
    case data       // Data workspace
    case studio     // Tool builder
    case export     // Export tool
    case aiConsole  // AI Management Panel
    case develop        // Repo-aware workbench (default)
    case developFiles
    case developSearch
    case developChanges
    case developRuns
    case developReview
    case developTasks
    case developAgents
    case developBrowse
    case developGithub
    case activity   // Progress lane
    case actionCatalog // Unified Tool Runner

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .actionCatalog: return "Action Catalog"
        case .export: return "Export"
        case .aiConsole: return "AI Console"
        case .compass: return "Compass"
        case .inbox: return "Inbox"
        case .atlas: return "Atlas"
        case .ask: return "Ask"
        case .projects: return "Projects"
        case .data: return "Data"
        case .studio: return "Studio"
        case .develop, .developFiles: return "Files"
        case .developSearch: return "Search"
        case .developChanges: return "Changes"
        case .developRuns: return "Runs"
        case .developReview: return "Review"
        case .developTasks: return "Tasks"
        case .developAgents: return "Agents"
        case .developBrowse: return "Browse"
        case .developGithub: return "GitHub"
        case .activity: return "Activity"
        }
    }

    var icon: String {
        switch self {
        case .compass: return "compass"
        case .inbox: return "tray.fill"
        case .atlas: return "globe"
        case .ask: return "questionmark.circle.fill"
        case .projects: return "folder.fill"
        case .data: return "tablecells.fill"
        case .studio: return "hammer.fill"
        case .export: return "square.and.arrow.up.fill"
        case .aiConsole: return "cpu.fill"
        case .develop, .developFiles: return "doc.on.doc.fill"
        case .developSearch: return "magnifyingglass"
        case .developChanges: return "diff"
        case .developRuns: return "play.circle.fill"
        case .developReview: return "checkmark.seal.fill"
        case .developTasks: return "checklist"
        case .developAgents: return "shingle.2.fill"
        case .developBrowse: return "safari"
        case .developGithub: return "network"
        case .activity: return "chart.line.uptrend.xyaxis"
        case .actionCatalog: return "tray.2.fill"
        }
    }
}

/// Privileged surfaces (for worker/admin/developer roles)
enum PrivilegedSurface: String, CaseIterable, Identifiable {
    case workerQueue
    case adminConsole
    case devConsole

    var id: String { rawValue }
}

/// Pinned activity for Compass dock
struct PinnedAction: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let systemImage: String
    let actionName: String
}

/// A human-defined collection of knowledge (e.g., "Housing Transition", "CCSF Spring 2026")
struct IngestionScope: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var description: String
    var depth: IndexingDepth
    var computePolicy: ComputePolicy
    var storagePolicy: StoragePolicy
    var sourceIds: Set<String>
    var isActive: Bool = true
}

/// A repository-specific workspace
struct RepoWorkspace: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var rootURL: URL
    var gitState: GitState
    var indexStatus: IndexingDepth
    var indexingProgress: Double // 0.0 to 1.0
    var includeRules: [String]
    var excludeRules: [String]
    var trustBoundary: GovernanceMode

    // Sandbox & Governance
    var sandboxURL: URL? // The worktree/sandbox root
    var networkPolicy = NetworkPolicy(stance: .offline)
    var resourceBudget = ResourceBudget()
}

struct NetworkPolicy: Codable, Hashable, Sendable {
    enum Stance: String, Codable {
        case offline = "Offline"
        case localOnly = "Localhost Only"
        case open = "Open Network"
    }
    var stance: Stance = .offline
    var allowedDomains: [String] = []
}

struct ResourceBudget: Codable, Hashable, Sendable {
    var cpuLimit: Double = 0.5 // 50%
    var memoryLimitMB: Int = 1024
    var wallClockLimitSeconds: Int = 300
}

/// Snapshot of the repository's git status
struct GitState: Codable, Hashable, Sendable {
    var headHash: String
    var branch: String
    var isDirty: Bool
    var stagedSummary: String?
    var remoteURL: URL?
}

/// A governed collection of code changes
struct ChangeSet: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let workspaceId: UUID
    var title: String
    var summary: String
    var patches: [Patch]
    var riskScore: Double // 0.0 to 1.0
    var status: ChangeStatus
    var generatedBy: String? // Capability ID
    var receiptHash: String?
    var createdAt: Date
}

/// A single file-level diff
struct Patch: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var filePath: String
    var diff: String
    var isNewFile: Bool = false
    var isDeleted: Bool = false
    var isSensitive: Bool = false
}

enum ChangeStatus: String, Codable {
    case proposed = "Proposed"
    case applying = "Applying"
    case applied = "Applied"
    case rejected = "Rejected"
}

/// An external CLI agent (e.g. Gemini CLI, Claude Code)
struct AgentProvider: Identifiable, Codable, Hashable, Sendable {
    let id: String // e.g. "gemini-cli"
    var displayName: String
    var binaryPath: String
    var version: String?
    var capabilities: [AgentCapability]
    var trustRecord: ToolTrustRecord?
    var isEnabled: Bool = false
}

enum AgentCapability: String, Codable, CaseIterable {
    case analyze = "Analyze Repo"
    case patch = "Propose Patch"
    case check = "Run Checks"
    case docs = "Generate Docs"
}

/// Cryptographic fingerprint and approval state of a tool
struct ToolTrustRecord: Codable, Hashable, Sendable {
    let binaryHash: String // SHA256 of the executable
    let signingIdentity: String?
    var approvedAt: Date
    var approvedBy: String // User ID or session ID
}

/// A specific configuration for a run
struct AgentProfile: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var providerId: String
    var model: String?
    var networkStance: NetworkPolicy.Stance = .offline
    var defaultCheckProfile: String?
    var binaryPath: String?
}

enum DevelopNavMode: String, CaseIterable, Codable, Identifiable {
    case files = "Files"
    case search = "Search"
    case changes = "Changes"
    case runs = "Runs"
    case review = "Review"
    case tasks = "Tasks"
    case agents = "Agents"
    case browse = "Browse"
    case github = "GitHub"

    var id: Self { self }
}

enum DevelopWorkbenchTab: String, CaseIterable, Codable, Identifiable {
    case editor = "Editor"
    case review = "Review"
    case logs = "Logs"

    var id: Self { self }
}

/// A logged network request for privacy transparency
struct NetworkActivityEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let domain: String
    let timestamp: Date
    let isAllowed: Bool
    let reason: String?

    init(id: UUID = UUID(), domain: String, timestamp: Date = Date(), isAllowed: Bool, reason: String? = nil) {
        self.id = id
        self.domain = domain
        self.timestamp = timestamp
        self.isAllowed = isAllowed
        self.reason = reason
    }
}
