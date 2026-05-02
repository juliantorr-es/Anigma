//
//  AppStore.swift
//  AnigmaAppMac
//
//  Main application state store with Bauhaus role/surface routing.
//

@preconcurrency import AnigmaClientKit
import AnigmaHostKit
import AnigmaHostMac  // For DaemonHostCapability
import AnigmaSidecar
import AnigmaSystemSpine
import AnigmaAgents
import AnigmaAIConsole
import ExportCore
import AnigmaWork
import DataEngine
import ContractsCore
import CryptoKit
import Foundation
import SwiftUI
import Observation
import DevelopumModule
import OSLog

private let appStoreLogger = Logger(subsystem: "com.anigma.app", category: "store")

@MainActor
@Observable
final class AppStore {
  // MARK: - Bauhaus Architecture State

  /// Current role determines which surfaces are available
  var role: AnigmaRole = .user

  /// App mode: Life (compass, inbox, projects) vs Build (studio, tools)
  var mode: AppMode = .life {
    didSet { normalizeSelectionForMode() }
  }

  /// Knowledge and work state
  var sources: [AnigmaSource] = []
  var scopes: [IngestionScope] = []
  var repoWorkspaces: [RepoWorkspace] = []
  var changeSets: [ChangeSet] = []
  var consoleLogs: [ConsoleEntry] = []
  var agentProviders: [AgentProvider] = []
  var agentProfiles: [AgentProfile] = []
  var workItems: [WorkItem] = []
  var currentProject: WorkbenchProject?

  /// Network activity log for privacy transparency
  var networkActivityLog: [NetworkActivityEntry] = []

  var activeWorkspaceID: UUID?
  var activeWorkspace: RepoWorkspace? {
      repoWorkspaces.first { $0.id == activeWorkspaceID }
  }

  var developNavMode: DevelopNavMode {
      switch userSurface {
      case .develop, .developFiles: return .files
      case .developSearch: return .search
      case .developChanges: return .changes
      case .developRuns: return .runs
      case .developReview: return .review
      case .developTasks: return .tasks
      case .developAgents: return .agents
      default: return .files
      }
  }

  var developWorkbenchTab: DevelopWorkbenchTab = .editor

  /// Global status and feedback
  var activeToasts: [AnigmaToast] = []
  var isJobCenterPresented: Bool = false
  var isAIConsolePresented: Bool = false

  /// UI Triggers (Transient)
  var focusOmniBar: Bool = false
  var triggerQuickLook: Bool = false

  var hasRunningJobs: Bool {
      jobs.contains { $0.status.uppercased() == "RUNNING" || $0.status.uppercased() == "QUEUED" }
  }

  /// Current governance mode
  var governanceMode: GovernanceMode = .local

  /// Active user surface (when role == .user)
  var userSurface: UserSurface = .compass

  // MARK: - Sidebar Telemetry

  var inboxCount: Int { artifacts.count }
  var runningJobsCount: Int { jobs.filter { $0.status.uppercased() == "RUNNING" }.count }
  var projectsCount: Int { workspaces.count }
  var insightCount: Int { scopes.count } // Simplified for now

  private func normalizeSelectionForMode() {
      switch mode {
      case .life:
          // Keep current if valid for Life
          if ![.compass, .inbox, .atlas, .ask, .projects, .activity].contains(userSurface) {
              userSurface = .compass
          }
      case .work:
          if ![.projects, .inbox, .ask, .activity, .data].contains(userSurface) {
              userSurface = .projects
          }
      case .insight:
          if ![.atlas, .activity, .ask, .data].contains(userSurface) {
              userSurface = .atlas
          }
      case .build:
          if ![.studio, .activity, .inbox, .atlas].contains(userSurface) {
              userSurface = .studio
          }
      case .develop:
          // Stay in develop surfaces
          let developSurfaces: Set<UserSurface> = [.develop, .developFiles, .developSearch, .developChanges, .developRuns, .developReview, .developTasks, .developAgents, .activity, .ask, .projects]
          if !developSurfaces.contains(userSurface) {
              userSurface = .develop
          }
      }
  }

  /// Chrome state (global UI elements)
  var chrome = ChromeState()

  /// Source connection flow visibility
  var isSourceConnectionPresented = false

  /// Export flow visibility
  var isExportPresented = false

  /// Session state (auth, preferences)
  var session = SessionState()

  // MARK: - Existing Published State

  private(set) var workspaces: [AnigmaClientKit.WorkspaceSummary] = []
  private(set) var artifacts: [AnigmaClientKit.ArtifactSummary] = []
  private(set) var jobs: [AnigmaClientKit.JobSummary] = []
  var inspectorSelection: AnigmaClientKit.InspectorSelection?
  private(set) var isInitializing: Bool = true
  private(set) var initializationError: String?
  var isOnline: Bool = true
  var daemonStatus: String = "Starting..."

  enum SidebarItem: Hashable {
    case workspace(id: WorkspaceID)
    case actionCatalog
    case settings
  }

  var sidebarSelection: SidebarItem?
  var isRepoPickerPresented: Bool = false

  var selectedWorkspaceID: WorkspaceID? {
    if case .workspace(let id) = sidebarSelection {
      return id
    }
    return nil
  }

  // Search & Filtering
  var artifactSearchQuery: String = ""
  var sidecarError: String?
  var hasMoreWorkspaces = false
  private var workspacesCursor: String?
  var jobSearchQuery: String = ""
  var jobStatusFilter: JobStatusFilter = .all
  var jobTrustFilter: JobTrustFilter = .all

  var actionCatalog: [ActionDefinition] = []
  var hosts: [DaemonHost] = []

  // Pagination
  private var artifactsCursor: String?
  private var jobsCursor: String?
  private(set) var hasMoreArtifacts: Bool = false
  private(set) var hasMoreJobs: Bool = false

  // MARK: - Compass Computed Properties

  /// Jobs that are currently running or queued
  var runningJobs: [AnigmaClientKit.JobSummary] {
    jobs.filter { $0.status.uppercased() == "RUNNING" || $0.status.uppercased() == "QUEUED" }
  }

  /// User's pinned quick actions
  var pinnedActions: [PinnedAction] {
    // TODO: Persist to UserDefaults or sync with daemon
    [
      PinnedAction(id: "ocr", title: "OCR", systemImage: "doc.text.viewfinder", actionName: "ocr"),
      PinnedAction(id: "translate", title: "Translate", systemImage: "globe", actionName: "translate"),
      PinnedAction(id: "summarize", title: "Summarize", systemImage: "text.quote", actionName: "summarize")
    ]
  }

  /// Run a pinned action
  func runPinnedAction(_ action: PinnedAction) async {
    await submitJob(action: action.actionName, parameters: [:])
  }

  // MARK: - Private State

  private var authority: AnigmaAuthority?
  private var client: MacAnigmaClient?
  private(set) public var surfaceId: SurfaceId?
  private(set) public var actorId: ActorId?
  private var capabilityToken: ContractsCore.CapabilityToken?

  // MARK: - Governance & Role State (Phase 1)

  var privacySettings = PrivacySettings()

  // Phase 8: Daemon lifecycle is a host capability
  private let daemonCapability: DaemonHostCapability
  private var connectionMonitor: ConnectionMonitor?

  // Phase 9: System Integration Spine
  let systemSpine: SystemSpine

  // Phase 10: Data & Agents
  let dataEngine: DataEngine
  let agentOrchestrator: AgentOrchestrator

  // Phase 11: Export
  let exportEngine: ExportEngine

  // Phase 12: AI Console
  let aiConsoleClient: AIConsoleClient

  private var irSubscriptionTask: Task<Void, Never>?

  // MARK: - Initialization

  /// Initialize with a nil capability for default behavior, or pass one explicitly
  init() {
    self.daemonCapability = DaemonHostCapability()
    self.systemSpine = SystemSpine.shared
    self.dataEngine = DataEngine()

    // Initialize AI Registry
    guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
        fatalError("Failed to unwrap appSupport")
    }
    let registryURL = appSupport.appendingPathComponent("Anigma/AIRegistry")
    let registry = AIRegistry(storageURL: registryURL)

    self.agentOrchestrator = AgentOrchestrator(jobEngine: systemSpine.jobEngine, dataEngine: dataEngine, registry: registry)
    self.exportEngine = ExportEngine(jobEngine: systemSpine.jobEngine)
    self.aiConsoleClient = AIConsoleClient(jobEngine: systemSpine.jobEngine, registry: registry)

    loadCache()
    loadHosts()
    loadSampleKnowledge()

    self.connectionMonitor = ConnectionMonitor(capability: daemonCapability)

    // Register system integrations
    Task { @MainActor in
        SystemUXSupport.shared.registerNotificationCategories()
    }
  }

  // MARK: - Repository Maintenance

  /// Open a local git repository and switch to Develop mode
  func openLocalRepository(at url: URL) async {
      do {
          let workspace = try await WorkspaceService.shared.loadWorkspace(at: url)

          await MainActor.run {
              self.repoWorkspaces.append(workspace)
              self.sidebarSelection = .workspace(id: workspace.id.uuidString)
              self.mode = .develop
              self.normalizeSelectionForMode()
          }

          showToast(title: "Repository Opened", subtitle: workspace.name, icon: "folder.open")
      } catch {
          showToast(title: "Failed to Open", subtitle: error.localizedDescription, icon: "exclamationmark.triangle.fill")
      }
  }

  func showToast(title: String, subtitle: String? = nil, icon: String? = nil, actionLabel: String? = nil) {
    let toast = AnigmaToast(id: UUID(), title: title, subtitle: subtitle, icon: icon, actionLabel: actionLabel)
    withAnimation {
        activeToasts.append(toast)
    }

    // Auto-dismiss after 4 seconds
    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
        withAnimation {
            self.activeToasts.removeAll { $0.id == toast.id }
        }
    }
  }

  /// Log a network request for privacy transparency
  func logNetworkActivity(domain: String, isAllowed: Bool, reason: String? = nil) {
    let entry = NetworkActivityEntry(
        domain: domain,
        timestamp: Date(),
        isAllowed: isAllowed,
        reason: reason
    )

    // Keep only last 100 entries
    networkActivityLog.append(entry)
    if networkActivityLog.count > 100 {
        networkActivityLog.removeFirst()
    }
  }

  private func loadSampleKnowledge() {
    self.scopes = [
        IngestionScope(
            id: UUID(),
            name: "Housing Transition",
            description: "Paperwork, receipts, and communication regarding the move.",
            depth: .indexing,
            computePolicy: ComputePolicy(),
            storagePolicy: StoragePolicy(),
            sourceIds: ["local-docs-1"]
        ),
        IngestionScope(
            id: UUID(),
            name: "CCSF Spring 2026",
            description: "Syllabus, reading list, and assignments.",
            depth: .understanding,
            computePolicy: ComputePolicy(),
            storagePolicy: StoragePolicy(),
            sourceIds: ["course-mail-1"]
        )
    ]

    self.repoWorkspaces = []

    // Try to detect current development workspace (if running from Xcode or development)
    let currentDir = FileManager.default.currentDirectoryPath
    let potentialAnigmaPath = URL(fileURLWithPath: currentDir)

    // Check if we're in an Anigma workspace
    if FileManager.default.fileExists(atPath: potentialAnigmaPath.appendingPathComponent("Package.swift").path) {
        self.repoWorkspaces.append(RepoWorkspace(
            id: UUID(),
            name: potentialAnigmaPath.lastPathComponent,
            rootURL: potentialAnigmaPath,
            gitState: GitState(headHash: "detecting...", branch: "main", isDirty: false),
            indexStatus: .discovery,
            indexingProgress: 0.0,
            includeRules: ["Sources/**", "Docs/**"],
            excludeRules: ["**/node_modules/**", "**/.build/**", "**/DerivedData/**"],
            trustBoundary: .local
        ))

        // Refresh git state asynchronously
        Task {
            if let workspace = self.repoWorkspaces.first {
                do {
                    let refreshed = try await WorkspaceService.shared.refreshState(for: workspace)
                    if let idx = self.repoWorkspaces.firstIndex(where: { $0.id == workspace.id }) {
                        self.repoWorkspaces[idx] = refreshed
                    }
                } catch {
                    appStoreLogger.error("Failed to refresh workspace state: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }
    self.activeWorkspaceID = self.repoWorkspaces.first?.id

    self.changeSets = [
        ChangeSet(
            id: UUID(),
            workspaceId: self.repoWorkspaces.first!.id,
            title: "Global Job Center",
            summary: "Implement real-time telemetry and control popover.",
            patches: [
                Patch(id: UUID(), filePath: "Sources/AnigmaAppMac/Chrome/JobCenterPanel.swift", diff: "+ struct JobCenterPanel: View { ... }", isNewFile: true)
            ],
            riskScore: 0.2,
            status: .applied,
            generatedBy: "architect-agent",
            receiptHash: "0x8822ffcc",
            createdAt: Date()
        )
    ]

    Task {
        await discoverAgentProviders()
        self.agentProfiles = [
            AgentProfile(id: UUID(), name: "Local Refactor (Gemini)", providerId: "gemini-cli", networkStance: .offline)
        ]
    }

    self.sources = [
        AnigmaSource(id: UUID(), name: "Documents Folder", type: .filesystem, path: "\(NSHomeDirectory())/Documents", depth: .discovery, computePolicy: ComputePolicy(), storagePolicy: StoragePolicy(), isConnected: false, lastIndexed: nil, status: .paused, stats: nil),
        AnigmaSource(id: UUID(), name: "Mail Inbox", type: .email, path: "INBOX", depth: .discovery, computePolicy: ComputePolicy(), storagePolicy: StoragePolicy(), isConnected: false, lastIndexed: nil, status: .paused, stats: nil)
    ]

    self.currentProject = WorkbenchProject(
        id: UUID(),
        name: "Sample Project",
        documents: [
            DocumentIR(title: "Project Plan", blocks: [
                .heading(id: UUID(), text: "Project Plan", level: 1),
                .paragraph(id: UUID(), text: "This is the plan.", style: nil)
            ])
        ],
        sheets: [
            SheetIR(title: "Budget", columns: [
                SheetColumn(id: UUID(), name: "Item", type: .text),
                SheetColumn(id: UUID(), name: "Cost", type: .currency)
            ])
        ],
        decks: [
            DeckIR(title: "Pitch", slides: [
                DeckSlide(title: "Slide 1")
            ])
        ]
    )
  }

  /// Initializes the Authority and starts the daemon if needed.
  func initialLoad() async {
    do {
      isInitializing = true
      initializationError = nil

      connectionMonitor?.start()

      // Step 1: Ensure daemon is running (via host capability)
      daemonStatus = "Checking daemon..."
      let status = try await withRetry {
        try await self.daemonCapability.ensureDaemonRunning()
      }
      daemonStatus = "Daemon: \(status.description)"

      // Step 3: Create Authority
      daemonStatus = "Connecting to Authority..."
      authority = try await withRetry {
        try await AnigmaAuthority.create()
      }

      // Step 3.5: Initialize capability modules
      daemonStatus = "Initializing modules..."
      try await ModuleInitialization.shared.initializeModules()

      // Step 4: Register surface
      guard let authority = authority else {
        throw AppStoreError.authorityNotInitialized
      }

      let actorId = ActorId(rawValue: "anigma-app-user")
      let (sid, token) = await authority.registerSurface(actorId: actorId)
      self.surfaceId = sid
      self.actorId = actorId
      self.capabilityToken = token

      // Step 5: Create client
      client = MacAnigmaClient(
        authority: authority,
        surfaceId: sid,
        actorId: actorId,
        capabilityToken: token
      )

      // Step 6: Bootstrap default workspace
      await authority.ensureDefaultWorkspace()

      // Step 7: Subscribe to IR updates
      subscribeToIR()

      // Step 8: Load initial data
      daemonStatus = "Loading workspaces..."
      await loadWorkspaces()

      isInitializing = false
      daemonStatus = "Ready"

    } catch {
      isInitializing = false
      initializationError = error.localizedDescription
      daemonStatus = "Error: \(error.localizedDescription)"
    }
  }

  // MARK: - Computed Properties (Filtered)

  var filteredArtifacts: [AnigmaClientKit.ArtifactSummary] {
    if artifactSearchQuery.isEmpty {
      return artifacts
    }
    return artifacts.filter {
      $0.name.localizedCaseInsensitiveContains(artifactSearchQuery)
    }
  }

  var filteredJobs: [AnigmaClientKit.JobSummary] {
    var result = jobs

    // Filter by name
    if !jobSearchQuery.isEmpty {
      result = result.filter {
        $0.name.localizedCaseInsensitiveContains(jobSearchQuery)
      }
    }

    // Filter by status
    if jobStatusFilter != .all {
      result = result.filter {
        $0.status.uppercased() == jobStatusFilter.rawValue
      }
    }

    // Filter by trust
    if jobTrustFilter != .all {
      result = result.filter {
        if jobTrustFilter == .verified {
          return $0.isTrusted
        } else {
          return !$0.isTrusted
        }
      }
    }

    return result
  }

  // MARK: - Workspace Management

  private func loadWorkspaces() async {
    guard let client = client else { return }
    do {
      let page = try await client.query.listWorkspaces(cursor: nil, limit: 50)
      workspaces = page.items
      workspacesCursor = page.cursor
      hasMoreWorkspaces = page.cursor != nil
      saveCache()

      if selectedWorkspaceID == nil && !workspaces.isEmpty {
        sidebarSelection = .workspace(id: workspaces[0].id)
        await loadWorkspaceData(id: workspaces[0].id)
      }
    } catch {
      appStoreLogger.error("Error loading workspaces: \(error.localizedDescription, privacy: .public)")
    }
  }

  func selectWorkspace(_ id: WorkspaceID) async {
    sidebarSelection = .workspace(id: id)
    guard id != selectedWorkspaceID else { return }  // Already selected (via enum logic check)
    // Actually the above check is a bit redundant now but keeping it safe.
    await loadWorkspaceData(id: id)
  }

  func loadMoreWorkspaces() async {
    guard let client = client, let cursor = workspacesCursor else { return }
    do {
      let page = try await client.query.listWorkspaces(cursor: cursor, limit: 50)
      workspaces.append(contentsOf: page.items)
      workspacesCursor = page.cursor
      hasMoreWorkspaces = page.cursor != nil
    } catch {
      appStoreLogger.error("Error loading more workspaces: \(error.localizedDescription, privacy: .public)")
    }
  }

  func switchRole(to role: AnigmaRole) {
    // In the future this might basic auth checks or context switching
    self.role = role

    // Reset sidebar selection to something sensible for the new role if needed
    // For now we keep it simple
  }

  private func loadWorkspaceData(id: WorkspaceID) async {
    guard let client = client else { return }

    do {
      let artifactsPage = try await client.query.listArtifacts(
        workspaceID: id,
        cursor: nil,
        limit: 50
      )
      let jobsPage = try await client.query.listJobs(
        workspaceID: id,
        cursor: nil,
        limit: 50
      )

      artifacts = artifactsPage.items
      artifactsCursor = artifactsPage.cursor
      hasMoreArtifacts = artifactsCursor != nil

      jobs = jobsPage.items
      jobsCursor = jobsPage.cursor
      hasMoreJobs = jobsCursor != nil

      saveCache()

      // Sync to AppState (Phase B)
      await MainActor.run {
          let state = AppState.shared
          state.jobStream = jobs.map { job in
              AppState.JobEntry(
                  id: UUID(uuidString: job.id) ?? UUID(),
                  title: job.name,
                  status: mapJobStatus(job.status),
                  progress: nil, // JobSummary doesn't have progress yet
                  source: "System",
                  receiptLink: nil,
                  timestamp: job.createdAt
              )
          }
          state.runningJobsCount = jobs.filter { $0.status.uppercased() == "RUNNING" }.count
          state.blockedJobsCount = jobs.filter { $0.status.uppercased() == "BLOCKED" }.count
      }
    } catch {
      appStoreLogger.error("Error loading workspace data: \(error.localizedDescription, privacy: .public)")
    }
  }

  private func mapJobStatus(_ status: String) -> Bauhaus.StatusState {
      switch status.uppercased() {
      case "RUNNING", "QUEUED": return .running
      case "SUCCEEDED", "COMPLETED": return .newOutput
      case "FAILED", "CANCELED": return .blocked
      case "BLOCKED": return .blocked
      case "ATTENTION": return .attention
      default: return .idle
      }
  }

  func loadMoreArtifacts() async {
    guard let client = client, let id = selectedWorkspaceID, let cursor = artifactsCursor else {
      return
    }

    do {
      let page = try await client.query.listArtifacts(workspaceID: id, cursor: cursor, limit: 50)
      artifacts.append(contentsOf: page.items)
      artifactsCursor = page.cursor
      hasMoreArtifacts = artifactsCursor != nil
    } catch {
      appStoreLogger.error("Error loading more artifacts: \(error.localizedDescription, privacy: .public)")
    }
  }

  func loadMoreJobs() async {
    guard let client = client, let id = selectedWorkspaceID, let cursor = jobsCursor else { return }

    do {
      let page = try await client.query.listJobs(workspaceID: id, cursor: cursor, limit: 50)
      jobs.append(contentsOf: page.items)
      jobsCursor = page.cursor
      hasMoreJobs = jobsCursor != nil
    } catch {
      appStoreLogger.error("Error loading more jobs: \(error.localizedDescription, privacy: .public)")
    }
  }

  func createWorkspace(name: String = "New Workspace") async {
    guard let client = client else { return }

    do {
      let workspaceId = try await client.command.createWorkspace(name: name)
      await loadWorkspaces()
      sidebarSelection = .workspace(id: workspaceId)
      await selectWorkspace(workspaceId)
    } catch {
      appStoreLogger.error("Error creating workspace: \(error.localizedDescription, privacy: .public)")
    }
  }

  func deleteArtifacts(ids: Set<ArtifactID>) async {
    guard let client = client else { return }
    do {
      for id in ids {
        try await client.command.deleteArtifact(id: id)
      }
      await selectWorkspace(selectedWorkspaceID!)
    } catch {
      appStoreLogger.error("Error deleting artifacts: \(error.localizedDescription, privacy: .public)")
    }
  }

  func evaluateAction(intent: ActionIntent) async -> IntentEvaluation {
    guard let client = client else { return .denied(reason: "Client not connected") }
    do {
      return try await client.query.evaluateAction(intent: intent)
    } catch {
      return .denied(reason: "Evaluation failed: \(error.localizedDescription)")
    }
  }

  func updateWorkspace(id: WorkspaceID, name: String) async {
    guard let client = client else { return }

    do {
      try await client.command.updateWorkspace(id: id, name: name)
      await loadWorkspaces()
    } catch {
      appStoreLogger.error("Error updating workspace: \(error.localizedDescription, privacy: .public)")
    }
  }

  func deleteWorkspace(id: WorkspaceID) async {
    guard let client = client else { return }

    do {
      try await client.command.deleteWorkspace(id: id)
      await loadWorkspaces()

      if selectedWorkspaceID == id {
        if let firstId = workspaces.first?.id {
          sidebarSelection = .workspace(id: firstId)
          await selectWorkspace(firstId)
        } else {
          sidebarSelection = nil
        }
      }
    } catch {
      appStoreLogger.error("Error deleting workspace: \(error.localizedDescription, privacy: .public)")
    }
  }

  // MARK: - Job Submission

  func submitJob(action: String, parameters: [String: BindingValue]) async {
    guard let client = client else {
      appStoreLogger.warning("Cannot submit job: client not initialized")
      return
    }

    // Intercept Agent Jobs (Phase 2)
    if action == "agent-refactor", let workspace = activeWorkspace {
        guard let profileIdStr = parameters["profile"]?.stringValue,
              let profileId = UUID(uuidString: profileIdStr),
              let profile = agentProfiles.first(where: { $0.id == profileId })
        else {
            showToast(title: "Agent Error", subtitle: "Invalid profile", icon: "exclamationmark.triangle")
            return
        }

        showToast(title: "Agent Running", subtitle: "Executing gemini-cli...", icon: "brain")

        let runner = CLIAgentRunner()
        let instruction = parameters["instruction"]?.stringValue ?? "Refactor code"

        do {
            // Clear previous logs
            await MainActor.run {
                self.consoleLogs.removeAll()
                self.consoleLogs.append(ConsoleEntry(timestamp: Date(), message: "Starting agent execution...", level: .info))
            }

            var fullOutput = ""
            for try await line in try await runner.execute(profile: profile, instruction: instruction, context: workspace) {
                await MainActor.run {
                    self.consoleLogs.append(ConsoleEntry(timestamp: Date(), message: line, level: .info))
                }
                fullOutput += line + "\n"
            }

            // Parse Diff
            let parser = ChangesetParser.shared
            // We assume the agent outputs a valid diff. 
            // In reality, we might need to extract the diff block from fullOutput.
            let parsed = await parser.parseAgentResponse(fullOutput)

            if let diff = parsed.diff {
                let changeSet = try await parser.parse(
                    diff: diff,
                    workspaceId: workspace.id,
                    authorId: profile.id,
                    jobDescription: instruction
                )

                await MainActor.run {
                    self.changeSets.append(changeSet)
                    self.developWorkbenchTab = .review
                    self.userSurface = .developChanges
                }

                showToast(title: "Changes Proposed", subtitle: "Review diff under 'Changes'", icon: "doc.text.magnifyingglass")
            } else {
                showToast(title: "Agent Finished", subtitle: "No changes produced", icon: "checkmark.circle")
            }

        } catch {
            showToast(title: "Agent Failed", subtitle: error.localizedDescription, icon: "xmark.circle")
        }

        return
    }

    _ = await client.submitIntent(action: action, parameters: parameters)

    // Show toast
    showToast(
        title: "\(action.uppercased()) started",
        subtitle: "The engine is processing your request.",
        icon: "gearshape.fill",
        actionLabel: "View"
    )

    // Refresh jobs list
    if let workspaceId = selectedWorkspaceID {
      await selectWorkspace(workspaceId)
    }
  }

  // MARK: - Develop Intents

  func applyChangeSet(_ changeSetId: UUID) async {
      guard var changeSet = changeSets.first(where: { $0.id == changeSetId }),
            let workspace = repoWorkspaces.first(where: { $0.id == changeSet.workspaceId })
      else { return }

      changeSet.status = .applying
      if let index = changeSets.firstIndex(where: { $0.id == changeSetId }) {
          changeSets[index] = changeSet
      }

      showToast(title: "Applying Patch", subtitle: changeSet.title, icon: "arrow.down.doc")

      do {
          let git = GitService.shared

          // Apply each patch in the changeset
          for patch in changeSet.patches {
              try await git.applyPatch(diff: patch.diff, in: workspace.rootURL)
          }

          // Success - update status
          changeSet.status = .applied
          if let index = changeSets.firstIndex(where: { $0.id == changeSetId }) {
              changeSets[index] = changeSet
          }

          // Refresh workspace git state
          let updatedWorkspace = try await WorkspaceService.shared.refreshState(for: workspace)
          if let wsIndex = repoWorkspaces.firstIndex(where: { $0.id == workspace.id }) {
              repoWorkspaces[wsIndex] = updatedWorkspace
          }

          showToast(
              title: "Changes Applied",
              subtitle: "Git state updated",
              icon: "checkmark.circle.fill"
          )

      } catch {
          // Failure - mark as rejected or keep proposed
          changeSet.status = .rejected
          if let index = changeSets.firstIndex(where: { $0.id == changeSetId }) {
              changeSets[index] = changeSet
          }

          showToast(
              title: "Apply Failed",
              subtitle: error.localizedDescription,
              icon: "exclamationmark.triangle.fill"
          )
      }
  }

  func rejectChangeSet(_ changeSetId: UUID) async {
      guard var changeSet = changeSets.first(where: { $0.id == changeSetId }) else { return }

      changeSet.status = .rejected
      if let index = changeSets.firstIndex(where: { $0.id == changeSetId }) {
          changeSets[index] = changeSet
      }

      showToast(title: "Change Rejected", subtitle: changeSet.title, icon: "xmark.circle.fill")
  }

  func runCheckProfile(name: String) async {
      showToast(title: "Check Started", subtitle: name, icon: "play.fill")

      await submitJob(action: "test", parameters: ["profile": .string(name)])
  }

  // MARK: - Agent Governance

  /// Known agent configurations for discovery
  private static let knownAgents: [(binary: String, id: String, display: String, caps: [AgentCapability])] = [
      ("gemini", "gemini-cli", "Gemini CLI", [.analyze, .patch]),
      ("claude", "claude-code", "Claude Code", [.analyze, .patch, .check]),
      ("aider", "aider", "Aider", [.analyze, .patch]),
      ("copilot", "github-copilot", "GitHub Copilot CLI", [.analyze])
  ]

  func discoverAgentProviders() async {
      var discovered: [AgentProvider] = []

      // Search paths: common install locations + PATH
      let searchPaths = buildSearchPaths()

      for agent in Self.knownAgents {
          if let binaryPath = findBinary(named: agent.binary, in: searchPaths) {
              let version = await extractVersion(from: binaryPath)

              discovered.append(AgentProvider(
                  id: agent.id,
                  displayName: agent.display,
                  binaryPath: binaryPath,
                  version: version,
                  capabilities: agent.caps,
                  trustRecord: nil,
                  isEnabled: false
              ))
          }
      }

      self.agentProviders = discovered
  }

  private func buildSearchPaths() -> [String] {
      var paths: [String] = [
          "/usr/local/bin",
          "/opt/homebrew/bin",
          "\(NSHomeDirectory())/.local/bin",
          "\(NSHomeDirectory())/.cargo/bin"
      ]

      // Add PATH directories
      if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
          paths.append(contentsOf: pathEnv.split(separator: ":").map(String.init))
      }

      return paths
  }

  private func findBinary(named name: String, in paths: [String]) -> String? {
      let fm = FileManager.default
      for dir in paths {
          let fullPath = "\(dir)/\(name)"
          if fm.isExecutableFile(atPath: fullPath) {
              return fullPath
          }
      }
      return nil
  }

  private func extractVersion(from binaryPath: String) async -> String? {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: binaryPath)
      process.arguments = ["--version"]

      let pipe = Pipe()
      process.standardOutput = pipe
      process.standardError = FileHandle.nullDevice

      do {
          try process.run()
          process.waitUntilExit()

          let data = pipe.fileHandleForReading.readDataToEndOfFile()
          if let output = String(data: data, encoding: .utf8) {
              // Extract version number (common patterns: "1.2.3", "v1.2.3", "version 1.2.3")
              let pattern = #"(?:v|version\s*)?(\d+\.\d+(?:\.\d+)?)"#
              if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                 let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
                 let range = Range(match.range(at: 1), in: output) {
                  return String(output[range])
              }
          }
      } catch {
          appStoreLogger.error("Failed to extract version from \(binaryPath, privacy: .public): \(error.localizedDescription, privacy: .public)")
      }
      return nil
  }

  func enableAgentProvider(_ providerId: String) async {
      guard let index = agentProviders.firstIndex(where: { $0.id == providerId }) else { return }
      var provider = agentProviders[index]

      // Compute actual binary fingerprint
      let binaryHash = await computeBinaryHash(at: provider.binaryPath)
      let signingIdentity = await extractSigningIdentity(at: provider.binaryPath)

      provider.trustRecord = ToolTrustRecord(
          binaryHash: binaryHash,
          signingIdentity: signingIdentity,
          approvedAt: Date(),
          approvedBy: session.currentUserId ?? "local-user"
      )
      provider.isEnabled = true
      agentProviders[index] = provider

      showToast(title: "Tool Trusted", subtitle: "\(provider.displayName) fingerprinted and enabled.", icon: "checkmark.shield.fill")
  }

  private func computeBinaryHash(at path: String) async -> String {
      guard let data = FileManager.default.contents(atPath: path) else {
          return "sha256:unknown"
      }

      // Compute SHA-256 hash using CryptoKit
      let digest = SHA256.hash(data: data)
      let hashString = digest.compactMap { String(format: "%02x", $0) }.joined()
      return "sha256:\(hashString.prefix(16))"
  }

  private func extractSigningIdentity(at path: String) async -> String? {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
      process.arguments = ["-dv", path]

      let pipe = Pipe()
      process.standardError = pipe // codesign outputs to stderr
      process.standardOutput = FileHandle.nullDevice

      do {
          try process.run()
          process.waitUntilExit()

          let data = pipe.fileHandleForReading.readDataToEndOfFile()
          if let output = String(data: data, encoding: .utf8) {
              // Look for "Authority=" line
              for line in output.split(separator: "\n") {
                  if line.hasPrefix("Authority=") {
                      return String(line.dropFirst("Authority=".count))
                  }
              }
          }
      } catch {
          appStoreLogger.error("Failed to extract signing identity: \(error.localizedDescription, privacy: .public)")
      }
      return nil
  }

  // MARK: - Event Subscription (Phase 8: No More Polling)

  private func subscribeToIR() {
    guard let client = client else { return }

    // Phase 8: Subscribe to canonical events instead of polling
    irSubscriptionTask = Task { @MainActor in
      do {
        for try await _ in client.events.events() {
          // Events drive UI updates now
          // In production, we'd handle different event types
          // For now, just refresh jobs when we get any event
          if let workspaceId = self.selectedWorkspaceID {
            await self.refreshJobs(workspaceId: workspaceId)
          }
        }
      } catch {
        appStoreLogger.error("Event stream error: \(error.localizedDescription, privacy: .public)")
      }
    }
  }

  private func refreshJobs(workspaceId: WorkspaceID) async {
    guard let client = client else { return }

    do {
      let page = try await client.query.listJobs(
        workspaceID: workspaceId,
        cursor: nil,
        limit: 50
      )
      jobs = page.items

      // Sync to AppState
      let state = AppState.shared
      state.jobStream = jobs.map { job in
          AppState.JobEntry(
              id: UUID(uuidString: job.id) ?? UUID(),
              title: job.name,
              status: mapJobStatus(job.status),
              progress: nil,
              source: "System",
              receiptLink: nil,
              timestamp: job.createdAt
          )
      }
      state.runningJobsCount = jobs.filter { $0.status.uppercased() == "RUNNING" }.count
      state.blockedJobsCount = jobs.filter { $0.status.uppercased() == "BLOCKED" }.count
    } catch {
      // Silently fail for background refresh
    }
  }

  // MARK: - Artifact Management

  func uploadArtifact(name: String, data: Data) async {
    guard let client = client, let workspaceId = selectedWorkspaceID else { return }

    do {
      _ = try await client.command.uploadArtifact(
        workspaceId: workspaceId,
        name: name,
        data: data
      )
      await selectWorkspace(workspaceId)  // Refresh artifacts
    } catch {
      appStoreLogger.error("Error uploading artifact: \(error.localizedDescription, privacy: .public)")
    }
  }

  func downloadArtifact(id: ArtifactID) async -> Data? {
    guard let client = client else { return nil }

    do {
      return try await client.query.downloadArtifact(id: id)
    } catch {
      appStoreLogger.error("Error downloading artifact: \(error.localizedDescription, privacy: .public)")
      return nil
    }
  }

  func deleteArtifact(id: ArtifactID) async {
    guard let client = client, let workspaceId = selectedWorkspaceID else { return }

    do {
      try await client.command.deleteArtifact(id: id)
      await selectWorkspace(workspaceId)  // Refresh artifacts

      if case .artifact(let selectedId) = inspectorSelection, selectedId == id {
        inspectorSelection = nil
      }
    } catch {
      appStoreLogger.error("Error deleting artifact: \(error.localizedDescription, privacy: .public)")
    }
  }

  // MARK: - Job Management

  func cancelJob(id: JobID) async {
    guard let client = client else { return }

    do {
      try await client.command.cancelJob(id: id)
    } catch {
      appStoreLogger.error("Error cancelling job: \(error.localizedDescription, privacy: .public)")
    }
  }

  func deleteJob(id: JobID) async {
    guard let client = client else { return }

    do {
      try await client.command.deleteJob(id: id)
      await loadWorkspaceData(id: selectedWorkspaceID ?? "")
    } catch {
      appStoreLogger.error("Error deleting job: \(error.localizedDescription, privacy: .public)")
    }
  }

  // MARK: - Host Management

  func addHost(_ host: DaemonHost, password: String) {
    hosts.append(host)
    try? KeychainManager.shared.save(password: password, for: host.id)
    saveHosts()
  }

  func loadHosts() {
    if let data = UserDefaults.standard.data(forKey: "daemon_hosts"),
      let decoded = try? JSONDecoder().decode([DaemonHost].self, from: data) {
      hosts = decoded
    }
  }

  private func saveHosts() {
    if let encoded = try? JSONEncoder().encode(hosts) {
      UserDefaults.standard.set(encoded, forKey: "daemon_hosts")
    }
  }

  func verifyJob(id: JobID) async {
    guard let client = client else { return }

    do {
      try await client.command.verifyJob(id: id)
    } catch {
      appStoreLogger.error("Error verifying job: \(error.localizedDescription, privacy: .public)")
    }
  }

  func getReceipt(hash: String) async throws -> ContractsCore.Receipt? {
    guard let client = client else { return nil }
    return try await client.query.getReceipt(hash: hash)
  }

  func evaluateAction(action: String, parameters: [String: BindingValue] = [:]) async
    -> IntentEvaluation {
    guard let client = client else { return .denied(reason: "Client not initialized") }
    do {
      return try await client.command.evaluateAction(action: action, parameters: parameters)
    } catch {
      appStoreLogger.error("Error evaluating action: \(error.localizedDescription, privacy: .public)")
      return .denied(reason: error.localizedDescription)
    }
  }

  // MARK: - Agent Execution

  func runAgent(id: String, instruction: String) async {
      guard let workspaceId = activeWorkspaceID else {
          showToast(title: "No Workspace", subtitle: "Select a workspace first.", icon: "exclamationmark.triangle")
          return
      }

      do {
          _ = try await agentOrchestrator.execute(agentId: id, instruction: instruction, workspaceId: workspaceId)
          showToast(title: "Agent Completed", subtitle: "Check results.", icon: "checkmark.circle")
      } catch {
          showToast(title: "Agent Failed", subtitle: error.localizedDescription, icon: "xmark.circle")
      }
  }
}

// MARK: - Error Types

enum AppStoreError: Error, LocalizedError {
  case authorityNotInitialized
  case clientNotInitialized

  var errorDescription: String? {
    switch self {
    case .authorityNotInitialized:
      return "AnigmaAuthority not initialized"
    case .clientNotInitialized:
      return "AnigmaClient not initialized"
    }
  }
}

// MARK: - BindingValue Extensions

extension BindingValue {
  var stringValue: String? {
    if case .string(let value) = self {
      return value
    }
    return nil
  }

  var boolValue: Bool? {
    if case .bool(let value) = self {
      return value
    }
    return nil
  }
}

// MARK: - Caching

extension AppStore {
  private func saveCache() {
    let encoder = JSONEncoder()
    if let encodedWorkspaces = try? encoder.encode(workspaces) {
      UserDefaults.standard.set(encodedWorkspaces, forKey: "cache_workspaces")
    }
    if let encodedArtifacts = try? encoder.encode(artifacts) {
      UserDefaults.standard.set(encodedArtifacts, forKey: "cache_artifacts")
    }
    if let encodedJobs = try? encoder.encode(jobs) {
      UserDefaults.standard.set(encodedJobs, forKey: "cache_jobs")
    }
    UserDefaults.standard.set(selectedWorkspaceID, forKey: "cache_selected_workspace_id")
  }

  private func loadCache() {
    let decoder = JSONDecoder()
    if let data = UserDefaults.standard.data(forKey: "cache_workspaces"),
      let decoded = try? decoder.decode([AnigmaClientKit.WorkspaceSummary].self, from: data) {
      workspaces = decoded
    }
    if let data = UserDefaults.standard.data(forKey: "cache_artifacts"),
      let decoded = try? decoder.decode([AnigmaClientKit.ArtifactSummary].self, from: data) {
      artifacts = decoded
    }
    if let data = UserDefaults.standard.data(forKey: "cache_jobs"),
      let decoded = try? decoder.decode([AnigmaClientKit.JobSummary].self, from: data) {
      jobs = decoded
    }
    if let id = UserDefaults.standard.string(forKey: "cache_selected_workspace_id") {
      sidebarSelection = .workspace(id: id)
    }
  }
}

// MARK: - Search & Filter Enums

enum JobStatusFilter: String, CaseIterable, Identifiable {
  case all = "All"
  case running = "RUNNING"
  case succeeded = "SUCCEEDED"
  case failed = "FAILED"
  case canceled = "CANCELED"

  var id: String { rawValue }
  var displayName: String {
    switch self {
    case .all: return "All Statuses"
    case .running: return "Running"
    case .succeeded: return "Succeeded"
    case .failed: return "Failed"
    case .canceled: return "Canceled"
    }
  }
}

enum JobTrustFilter: String, CaseIterable, Identifiable {
  case all = "All"
  case verified = "Verified Truth"
  case unverified = "Unverified"

  var id: String { rawValue }
}
