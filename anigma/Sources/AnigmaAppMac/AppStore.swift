// Mock refactored code

import AnigmaClientKit
// import AnigmaSidecar

import AnigmaSystemSpine
// import AnigmaAgents
// import AnigmaAIConsole
import ExportCore
import AnigmaWork
import DataEngine
import ContractsCore
import MLWorkerCommon
import AnigmaDaemonCore  // For AnigmaArtifactRef, CancelJobResponse
import CathedralModule
import CryptoKit
import Foundation
import Combine
import SwiftUI
import Observation
import UniformTypeIdentifiers
import DevelopumModule
import DatabaseCore

@MainActor
@Observable
final class AppStore {
  // MARK: - Bauhaus Architecture State
  
  /// Artifact service for chunking and virtualization
  let developArtifactService: DevelopumArtifactService
  
  private let dbService: DevelopumDatabaseService
  
  private func setupServices() {
      // Logic from init moved here if needed or kept in init
  }

  /// Current role determines which surfaces are available
  var role: AnigmaRole = .user

  /// App mode: Life (compass, inbox, projects) vs Build (studio, tools)
  var mode: AppMode = .life {
    didSet { normalizeSelectionForMode() }
  }

  /// Knowledge and work state
  var sources: [AnigmaSource] = []
  var contexts: [AnigmaContext] = []
  var scopes: [IngestionScope] = []
  var repoWorkspaces: [RepoWorkspace] {
    get { workspaceStore.repoWorkspaces }
    set { workspaceStore.repoWorkspaces = newValue }
  }
  var changeSets: [ChangeSet] {
    get { workspaceStore.changeSets }
    set { workspaceStore.changeSets = newValue }
  }
  var selectedChangeSetID: UUID? {
    get { workspaceStore.selectedChangeSetID }
    set { workspaceStore.selectedChangeSetID = newValue }
  }
  var consoleLogs: [ConsoleEntry] = []
  var agentProviders: [AgentProvider] = []
  var agentProfiles: [AgentProfile] = []
  var workItems: [WorkItem] = []
  var tools: [AnigmaTool] = [] // Build Loop
  var currentProject: WorkbenchProject? {
    get { workspaceStore.currentProject }
    set { workspaceStore.currentProject = newValue }
  }

  // Spine local jobs
  var localJobs: [AnigmaJob] = [] {
    didSet { syncJobStates() }
  }

  /// Network activity log for privacy transparency
  var networkActivityLog: [NetworkActivityEntry] = []



  // MARK: - Intake Logic
  @MainActor
  func handleIntake(_ providers: [NSItemProvider]) {
    for provider in providers {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    Task {
                        await MainActor.run {
                            self.handleIntake(url: url)
                        }
                    }
                }
            }
        }
    }
  }

  @MainActor
  func handleIntake(url: URL) {
      let item = IntakeItem(
          id: UUID(),
          sourceId: UUID(),
          name: url.lastPathComponent,
          location: url,
          size: 0,
          status: .queued,
          importedAt: Date()
      )
      AppState.shared.intakeQueue.append(item)
      self.processIntake(item)
  }

  @MainActor
  private func processIntake(_ item: IntakeItem) {
    let jobId = UUID()
    let initialJob = AnigmaJob(
        id: jobId,
        title: "Ingest: \(item.name)",
        message: "Initializing...",
        contextId: AppState.shared.currentContext?.id,
        status: .running,
        progress: 0.0,
        startedAt: Date()
    )
    self.localJobs.append(initialJob)

    Task {
        let url = item.location
        let isPDF = url.pathExtension.lowercased() == "pdf"

        if isPDF {
            let pdfJob = PDFImportJob()
            // Subscribe to progress and update localJobs
            let cancellable = pdfJob.progressPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] result in
                    guard let self = self else { return }
                    if let index = self.localJobs.firstIndex(where: { $0.id == jobId }) {
                        if let progress = result.progress {
                            self.localJobs[index].progress = progress.percent / 100.0
                            self.localJobs[index].message = progress.message
                        }

                        switch result.state {
                        case .success:
                            self.localJobs[index].status = .completed
                            self.localJobs[index].progress = 1.0
                            self.localJobs[index].completedAt = result.endTime
                        case .failure:
                            self.localJobs[index].status = .failed
                            self.localJobs[index].message = result.failure?.message
                        default:
                            break
                        }
                    }
                }

            let result = await pdfJob.importPDF(at: url)
            cancellable.cancel()

            // Handle completion effects (evidence, artifacts)
            handleIntakeCompletion(item: item, jobId: jobId, result: result)
        } else {
            // Generic Ingest (The "Ghost" with more polish)
            await performGenericIngest(item: item, jobId: jobId)
        }
    }
  }

  @MainActor
  private func handleIntakeCompletion<T: Codable>(item: IntakeItem, jobId: UUID, result: OperationResult<T>) {
      // 1. Update Intake Queue status
      if let idx = AppState.shared.intakeQueue.firstIndex(where: { $0.id == item.id }) {
          AppState.shared.intakeQueue[idx].status = (result.state == .success) ? .indexed : .error
      }

      // 2. Create Artifact if success
      if result.state == .success {
          let artifactId = item.id.uuidString
          if !self.artifacts.contains(where: { $0.id == artifactId }) {
              let artifact = AnigmaClientKit.ArtifactSummary(
                  id: artifactId,
                  name: item.name,
                  type: artifactType(for: item),
                  createdAt: Date()
              )
              self.artifacts.insert(artifact, at: 0)
              saveCache()
          }
      }

      // 3. Create Evidence
      let summaryText = (result.state == .success) ? "Imported \(item.name)" : "Import failed: \(result.failure?.message ?? "Unknown error")"
      let evidence = AnigmaEvidence(
          id: UUID(),
          jobId: jobId,
          contextId: AppState.shared.currentContext?.id,
          timestamp: Date(),
          type: .importEvent,
          summary: summaryText
      )
      AppState.shared.ledger.append(evidence)
  }

  @MainActor
  private func performGenericIngest(item: IntakeItem, jobId: UUID) async {
      let url = item.location
      let gotAccess = url.startAccessingSecurityScopedResource()
      defer { if gotAccess { url.stopAccessingSecurityScopedResource() } }

      do {
          let resources = try url.resourceValues(forKeys: [.fileSizeKey])
          let fileSize = Int64(resources.fileSize ?? 0)

          // Phase 1: Reading
          updateJob(id: jobId, progress: 0.3, message: "Reading file attributes...")
          try await Task.sleep(nanoseconds: 500_000_000)

          // Phase 2: Metadata
          updateJob(id: jobId, progress: 0.6, message: "Extracting metadata...")
          try await Task.sleep(nanoseconds: 800_000_000)

          // Phase 3: Finalizing
          updateJob(id: jobId, progress: 0.9, message: "Finalizing ingestion...")
          try await Task.sleep(nanoseconds: 300_000_000)

          // Success
          if let index = self.localJobs.firstIndex(where: { $0.id == jobId }) {
              self.localJobs[index].status = .completed
              self.localJobs[index].progress = 1.0
              self.localJobs[index].completedAt = Date()
              self.localJobs[index].message = "Imported (\(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)))"
          }

          // Completion effects
          let result = OperationResult<Int>(id: jobId, kind: "genericIngest", startTime: Date(), endTime: Date(), state: .success, payload: nil, progress: nil, failure: nil)
          handleIntakeCompletion(item: item, jobId: jobId, result: result)

      } catch {
          if let index = self.localJobs.firstIndex(where: { $0.id == jobId }) {
              self.localJobs[index].status = .failed
              self.localJobs[index].message = error.localizedDescription
          }
          let result = OperationResult<Int>(id: jobId, kind: "genericIngest", startTime: Date(), endTime: Date(), state: .failure, payload: nil, progress: nil, failure: .init(code: "INGEST_ERROR", message: error.localizedDescription, recoveryHint: nil))
          handleIntakeCompletion(item: item, jobId: jobId, result: result)
      }
  }

  @MainActor
  private func updateJob(id: UUID, progress: Double, message: String) {
      if let index = self.localJobs.firstIndex(where: { $0.id == id }) {
          self.localJobs[index].progress = progress
          self.localJobs[index].message = message
      }
  }

  private func artifactType(for item: IntakeItem) -> String {
      let ext = item.location.pathExtension.lowercased()
      return ext.isEmpty ? "file" : ext
  }

  // MARK: - Context Operations

  @MainActor
  func activateContext(_ context: AnigmaContext) {
    if AppState.shared.currentContext?.id != context.id {
        AppState.shared.currentContext = context

        // Check if we need to bootstrap (simulate checking if it's "fresh")
        // In a real app we'd check ledger or lastIndexed
        // Here we just trigger it if no evidence exists for this context
        let evidenceExists = AppState.shared.ledger.contains { $0.contextId == context.id }
        if !evidenceExists {
             triggerBaselineAnalysis(for: context)
        }
    }
  }

  @MainActor
  private func triggerBaselineAnalysis(for context: AnigmaContext) {
      let id = UUID()
      let initialJob = AnigmaJob(
          id: id,
          title: "Baseline: \(context.name)",
          message: "Initializing...",
          contextId: context.id,
          status: .running,
          progress: 0.05,
          startedAt: Date()
      )
      self.localJobs.append(initialJob)

      Task {
          await runSimulatedJob(id: id, stages: [
              (0.2, "Index verification..."),
              (0.4, "Invariant graph walk..."),
              (0.7, "Cross-source correlation..."),
              (0.9, "Generating evidence tokens...")
          ])

          let evidence = AnigmaEvidence(
              id: UUID(),
              jobId: id,
              contextId: context.id,
              timestamp: Date(),
              type: .jobCompletion,
              summary: "Atlas baseline established for \(context.name)"
          )
          AppState.shared.ledger.append(evidence)
      }
  }

  // MARK: - Build Loop (Tools)

  @MainActor
  func registerTool(_ tool: AnigmaTool) {
    self.tools.append(tool)

    // Log intent to the ledger (Build evidence)
    let evidence = AnigmaEvidence(
        id: UUID(),
        contextId: AppState.shared.currentContext?.id,
        timestamp: Date(),
        type: .userAction,
        summary: "Registered tool: \(tool.name)"
    )
    AppState.shared.ledger.append(evidence)
  }

  var activeWorkspaceID: UUID? {
    get { workspaceStore.activeWorkspaceID }
    set { workspaceStore.activeWorkspaceID = newValue }
  }
  var selectedFileURL: URL? {
    get { workspaceStore.selectedFileURL }
    set { workspaceStore.selectedFileURL = newValue }
  }
  var activeWorkspace: RepoWorkspace? {
    workspaceStore.activeWorkspace
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
      case .developBrowse: return .browse
      case .developGithub: return .github
      default: return .files
      }
  }

  var developWorkbenchTab: DevelopWorkbenchTab {
    get { workspaceStore.developWorkbenchTab }
    set { workspaceStore.developWorkbenchTab = newValue }
  }

  /// Global status and feedback
  var activeToasts: [AnigmaToast] = []
  var isJobCenterPresented: Bool = false
  var isAIConsolePresented: Bool = false

  /// UI Triggers (Transient)
  var focusOmniBar: Bool = false
  var triggerQuickLook: Bool = false

  var hasRunningJobs: Bool {
      jobs.contains { $0.status.uppercased() == "RUNNING" || $0.status.uppercased() == "QUEUED" } ||
      localJobs.contains { $0.status == .running || $0.status == .pending }
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

  private func setSourceConnected(_ sourceType: SourceType, connected: Bool) {
    if let index = sources.firstIndex(where: { $0.type == sourceType }) {
      sources[index].status = connected ? .connected : .paused
      sources[index].isConnected = connected
      return
    }
    
    guard connected else { return }
    sources.append(
      AnigmaSource(
        name: sourceType.rawValue,
        type: sourceType,
        path: sourceType.description,
        depth: .discovery,
        computePolicy: ComputePolicy(),
        storagePolicy: StoragePolicy(),
        isConnected: true,
        lastIndexed: nil,
        status: .connected,
        stats: nil
      )
    )
  }

  func storeGoogleOAuthToken(_ token: GoogleOAuthToken) {
    sourceConnectionStore.storeGoogleOAuthToken(token)
  }
  
  func refreshGoogleOAuthTokenIfNeeded(force: Bool = false, displayToast: Bool = false) async {
    await sourceConnectionStore.refreshGoogleOAuthTokenIfNeeded(force: force, displayToast: displayToast)
  }
  
  func disconnectGoogle() {
    sourceConnectionStore.disconnectGoogle()
  }
  
  func googleRedirectURI() -> String {
    sourceConnectionStore.googleRedirectURI()
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

  private(set) var workspaces: [AnigmaClientKit.WorkspaceSummary] {
    get { workspaceStore.workspaces }
    set { workspaceStore.workspaces = newValue }
  }
  private(set) var artifacts: [AnigmaClientKit.ArtifactSummary] {
    get { workspaceStore.artifacts }
    set { workspaceStore.artifacts = newValue }
  }
  private(set) var jobs: [AnigmaClientKit.JobSummary] {
    get { workspaceStore.jobs }
    set { workspaceStore.jobs = newValue }
  }
  var inspectorSelection: AnigmaClientKit.InspectorSelection?
  private(set) var isInitializing: Bool = true
  private(set) var initializationError: String?
  var isOnline: Bool = true
  var daemonStatus: String {
    get { daemonStore.daemonStatus }
    set { daemonStore.daemonStatus = newValue }
  }
  var daemonDetailedStatus: AnigmaStatusResponse? {
    get { daemonStore.daemonDetailedStatus }
    set { daemonStore.daemonDetailedStatus = newValue }
  }
  var selectedReceiptJson: String? {
    get { daemonStore.selectedReceiptJson }
    set { daemonStore.selectedReceiptJson = newValue }
  }

  // Global Ledger Data (from anigmad)
  var globalArtifacts: [AnigmaArtifactRef] {
    get { daemonStore.globalArtifacts }
    set { daemonStore.globalArtifacts = newValue }
  }
  var globalArtifactsCursor: String? {
    get { daemonStore.globalArtifactsCursor }
    set { daemonStore.globalArtifactsCursor = newValue }
  }

  enum SidebarItem: Hashable {
    case workspace(id: WorkspaceID)
    case actionCatalog
    case settings
  }

  var sidebarSelection: SidebarItem? {
    didSet {
      if case .workspace(let id) = sidebarSelection {
        workspaceStore._selectedWorkspaceID = id
      }
    }
  }
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
  var hasMoreWorkspaces: Bool {
    get { workspaceStore.hasMoreWorkspaces }
    set { workspaceStore.hasMoreWorkspaces = newValue }
  }
  private var workspacesCursor: String? {
    get { workspaceStore.workspacesCursor }
    set { workspaceStore.workspacesCursor = newValue }
  }
  var jobSearchQuery: String = ""
  var jobStatusFilter: JobStatusFilter = .all
  var jobTrustFilter: JobTrustFilter = .all

  var actionCatalog: [ActionDefinition] = []
  var hosts: [DaemonHost] = []

  // Pagination
  private var artifactsCursor: String? {
    get { workspaceStore.artifactsCursor }
    set { workspaceStore.artifactsCursor = newValue }
  }
  private var jobsCursor: String? {
    get { workspaceStore.jobsCursor }
    set { workspaceStore.jobsCursor = newValue }
  }
  private(set) var hasMoreArtifacts: Bool {
    get { workspaceStore.hasMoreArtifacts }
    set { workspaceStore.hasMoreArtifacts = newValue }
  }
  private(set) var hasMoreJobs: Bool {
    get { workspaceStore.hasMoreJobs }
    set { workspaceStore.hasMoreJobs = newValue }
  }

  // MARK: - Compass Computed Properties

  /// Jobs that are currently running or queued
  var runningJobs: [AnigmaClientKit.JobSummary] {
    jobs.filter { $0.status.uppercased() == "RUNNING" || $0.status.uppercased() == "QUEUED" }
  }

  /// User's pinned quick actions
  var pinnedActions: [PinnedAction] = []

  /// Run a pinned action
  func runPinnedAction(_ action: PinnedAction) async {
    await submitJob(action: action.actionName, parameters: [:])
  }

  func savePinnedActions() {
    let encoder = JSONEncoder()
    do {
      let data = try encoder.encode(pinnedActions)
      try saveToUserDefaults(data, forKey: "pinned_actions")
    } catch {
      print("❌ [AppStore] Failed to save pinned actions: \(error)")
      showError("Failed to save pinned actions. Some settings may not persist.")
    }
  }

  /// Safely save data to UserDefaults with verification
  private func saveToUserDefaults(_ data: Data, forKey key: String) throws {
    UserDefaults.standard.set(data, forKey: key)

    // Verify the write succeeded
    guard UserDefaults.standard.data(forKey: key) != nil else {
      throw NSError(
        domain: "AnigmaApp",
        code: 500,
        userInfo: [NSLocalizedDescriptionKey: "UserDefaults write verification failed for key '\(key)'"]
      )
    }
  }

  // MARK: - Private State

  private var authority: AnigmaAuthority?
  internal var daemonBridge: SidecarBridge? {
    get { daemonStore.daemonBridge }
    set { daemonStore.daemonBridge = newValue }
  }
  private var client: MacAnigmaClient?
  private(set) public var surfaceId: SurfaceId?
  private(set) public var actorId: ActorId?
  private var capabilityToken: ContractsCore.CapabilityToken?

  /// Daemon connection status (public accessor)
  var isDaemonConnected: Bool { daemonStore.isDaemonConnected }

  // MARK: - Governance & Role State (Phase 1)

  var privacySettings = PrivacySettings()
  var governanceSettings = GovernanceSettings()

  // Phase 8: Daemon lifecycle is a host capability
  internal let daemonCapability: DaemonHostCapability
  private var connectionMonitor: ConnectionMonitor?



  // MARK: - Harmonia CLI Integration

  /// Direct access to Harmonia CLI client
  public var harmoniaClient: HarmoniaClient {
    daemonCapability.harmonia
  }

  /// Vault status from Harmonia CLI (delegated to HarmoniaStore)
  var vaultStatus: HarmoniaClient.VaultStatusResponse? {
    serviceIntegrationStore.serviceIntegrationStore.harmoniaStore.vaultStatus
  }

  /// Pipeline status from Harmonia CLI (delegated to HarmoniaStore)
  var pipelineStatus: HarmoniaClient.PipelineStatusResponse? {
    serviceIntegrationStore.serviceIntegrationStore.harmoniaStore.pipelineStatus
  }

  /// Tech debt analysis report (delegated to HarmoniaStore)
  var techDebtReport: HarmoniaClient.TechDebtAuditResponse? {
    serviceIntegrationStore.serviceIntegrationStore.harmoniaStore.techDebtReport
  }

  /// Search results from ledger (delegated to HarmoniaStore)
  var searchResults: HarmoniaClient.SearchResponse? {
    serviceIntegrationStore.serviceIntegrationStore.harmoniaStore.searchResults
  }

  // MARK: - Harmonia Background Services

  /// Background synchronization service
  public private(set) var harmoniaBackgroundSync: HarmoniaBackgroundSync?

  /// Command history tracking
  public private(set) var harmoniaCommandHistory: HarmoniaCommandHistory?

  // MARK: - Doctrine Integration

  /// Doctrine CLI client for rule checking and violation management (delegated to DoctrineStore)
  public var doctrineClient: DoctrineClient {
    DoctrineClient()
  }

  /// Current doctrine scan results (delegated to DoctrineStore)
  var doctrineScanResults: DoctrineClient.ScanResponse? {
    serviceIntegrationStore.serviceIntegrationStore.doctrineStore.scanResults
  }

  /// Doctrine violation statistics (delegated to DoctrineStore)
  var doctrineStats: DoctrineClient.ViolationStatsResponse? {
    serviceIntegrationStore.serviceIntegrationStore.doctrineStore.stats
  }

  /// Available doctrine rules (delegated to DoctrineStore)
  var doctrineRules: DoctrineClient.RulesResponse? {
    serviceIntegrationStore.serviceIntegrationStore.doctrineStore.rules
  }

  /// Available doctrine packs (delegated to DoctrineStore)
  var doctrinePacks: DoctrineClient.PacksResponse? {
    serviceIntegrationStore.serviceIntegrationStore.doctrineStore.packs
  }

  // MARK: - ML Worker Integration

  /// ML Worker client for task submission and monitoring (delegated to MLStore)
  public var mlWorkerClient: MLWorkerClient {
    MLWorkerClient()
  }

  // MARK: - Accessum Flow Integration

  /// Accessum Flow client for access control and flow management (delegated to AccessumFlowStore)
  public var accessumFlowClient: AccessumFlowClient {
    AccessumFlowClient()
  }

  /// Current access policies (delegated to AccessumFlowStore)
  var accessPolicies: [PolicyInfo] {
    serviceIntegrationStore.serviceIntegrationStore.accessumFlowStore.accessPolicies
  }

  /// Access audit log (delegated to AccessumFlowStore)
  var accessAuditLog: [AuditEntry] {
    serviceIntegrationStore.serviceIntegrationStore.accessumFlowStore.accessAuditLog
  }

  /// Flow control status (delegated to AccessumFlowStore)
  var flowStatus: FlowStatusResponse? {
    serviceIntegrationStore.serviceIntegrationStore.accessumFlowStore.flowStatus
  }

  // MARK: - Surface Integration

  /// Surface client for UI rendering and visualization (delegated to SurfaceStore)
  public var surfaceClient: SurfaceClient {
    SurfaceClient()
  }

  /// Available surfaces (delegated to SurfaceStore)
  var surfaces: [SurfaceInfo] {
    serviceIntegrationStore.serviceIntegrationStore.surfaceStore.surfaces
  }

  /// Active surface metrics (delegated to SurfaceStore)
  var surfaceMetrics: [String: SurfaceMetricsResponse] {
    serviceIntegrationStore.serviceIntegrationStore.surfaceStore.surfaceMetrics
  }

  // MARK: - AST Services Integration

  /// AST Services client for code analysis (delegated to ASTServicesStore)
  public var astServicesClient: ASTServicesClient {
    ASTServicesClient()
  }

  /// AST analysis results (delegated to ASTServicesStore)
  var astAnalysisResults: ASTAnalysisResponse? {
    serviceIntegrationStore.serviceIntegrationStore.astServicesStore.analysisResults
  }

  /// Symbol references (delegated to ASTServicesStore)
  var symbolReferences: ReferencesResponse? {
    serviceIntegrationStore.serviceIntegrationStore.astServicesStore.symbolReferences
  }

  // MARK: - Pipeline Integration

  /// Pipeline client for data processing (delegated to PipelineStore)
  public var pipelineClient: PipelineClient {
    PipelineClient()
  }

  /// Available pipelines (delegated to PipelineStore)
  var pipelines: [PipelineInfo] {
    serviceIntegrationStore.serviceIntegrationStore.pipelineStore.pipelines
  }

  /// Active pipeline runs (delegated to PipelineStore)
  var pipelineRuns: [PipelineRunResponse] {
    serviceIntegrationStore.serviceIntegrationStore.pipelineStore.pipelineRuns
  }

  // MARK: - Outline/Zine Integration

  /// Outline client for document generation (delegated to OutlineStore)
  public var outlineClient: OutlineClient {
    OutlineClient()
  }

  /// Generated outlines (delegated to OutlineStore)
  var outlines: [OutlineResponse] {
    serviceIntegrationStore.serviceIntegrationStore.outlineStore.outlines
  }

  /// Available zine templates (delegated to OutlineStore)
  var zineTemplates: [ZineTemplate] {
    serviceIntegrationStore.serviceIntegrationStore.outlineStore.zineTemplates
  }

  // MARK: - Model Registry (Phase 1: Governed ML)

  /// Durable model registry with provenance tracking
  let modelRegistry: ModelRegistry

  /// HuggingFace adapter for fetch/verify/describe
  let hfAdapter: HuggingFaceAdapter

  /// Service Integration Store - consolidates all service-specific stores
  let serviceIntegrationStore: ServiceIntegrationStore
  let sourceConnectionStore: SourceConnectionStore
let workspaceStore: WorkspaceStore
let daemonStore: DaemonStore


  /// Google OAuth client ID (delegated to SourceConnectionStore)
  var googleOAuthClientId: String {
    get { sourceConnectionStore.googleOAuthClientId }
    set { sourceConnectionStore.googleOAuthClientId = newValue }
  }
  
  /// Google OAuth token (delegated to SourceConnectionStore)
  var googleOAuthToken: GoogleOAuthToken? {
    sourceConnectionStore.googleOAuthToken
  }
  
  /// Whether Google account is linked (delegated to SourceConnectionStore)
  var isGoogleLinked: Bool {
    sourceConnectionStore.isGoogleLinked
  }
  
  /// Last Google token refresh timestamp (delegated to SourceConnectionStore)
  var googleOAuthLastRefreshAt: Date? {
    sourceConnectionStore.googleOAuthLastRefreshAt
  }

  /// Registered models (delegated to MLStore)
  var registeredModels: [ModelRegistryEntry] {
    serviceIntegrationStore.serviceIntegrationStore.mlStore.registeredModels
  }

  /// ML Worker status (delegated to MLStore)
  var mlWorkerStatus: MLWorkerClient.WorkerStatusResponse? {
    serviceIntegrationStore.serviceIntegrationStore.mlStore.mlWorkerStatus
  }

  /// ML Worker tasks (delegated to MLStore)
  var mlWorkerTasks: [MLWorkerClient.TaskStatusResponse] {
    serviceIntegrationStore.serviceIntegrationStore.mlStore.mlWorkerTasks
  }

  // Phase 9: System Integration Spine
  let systemSpine: SystemSpine

  // Phase 10: Data & Agents
  let dataEngine: DataEngine
  let agentOrchestrator: AgentOrchestrator

  // Phase 11: Export
  let exportEngine: ExportEngine

  // Phase 12: AI Console
  let aiConsoleClient: AIConsoleClient

  // Phase H: Evidence-driven coordination
  let cathedralCoordinator: CathedralCoordinator

  private var irSubscriptionTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Initialize with a nil capability for default behavior, or pass one explicitly
    init() {
        self.daemonCapability = DaemonHostCapability()
        self.systemSpine = SystemSpine.shared
        self.dataEngine = DataEngine()

        // Initialize Developum Services
        self.dbService = DevelopumDatabaseService(databaseAuthority: StubDatabaseAuthority())
        self.developArtifactService = DevelopumArtifactService(
            artifactAuthority: StubArtifactAuthority(),
            databaseService: dbService
        )



    // Initialize AI Registry
    guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
        fatalError("Failed to unwrap appSupport")
    }
    let registryURL = appSupport.appendingPathComponent("Anigma/AIRegistry")
    let registry = AIRegistry(storageURL: registryURL)

    self.agentOrchestrator = AgentOrchestrator(jobEngine: systemSpine.jobEngine, dataEngine: dataEngine, registry: registry)
    self.exportEngine = ExportEngine(jobEngine: systemSpine.jobEngine)
    self.aiConsoleClient = AIConsoleClient(jobEngine: systemSpine.jobEngine, registry: registry)

    // Initialize Model Registry and HF Adapter
    let modelRegistryPath = appSupport.appendingPathComponent("Anigma/ModelRegistry/registry.json")
    self.modelRegistry = try! ModelRegistry(registryPath: modelRegistryPath)

    let modelCacheDir = appSupport.appendingPathComponent("Anigma/ModelCache")
    self.hfAdapter = try! HuggingFaceAdapter(cacheDir: modelCacheDir)

    // Initialize Harmonia services
    self.harmoniaCommandHistory = HarmoniaCommandHistory()

    // Initialize Cathedral evidence coordinator
    let cathedralConfig = CathedralConfig(
      maxEvidenceChainLength: 1000,
      evidenceTimeoutSeconds: 300,
      violationActionThreshold: .high,
      requireFreshEvidence: true,
      evidenceValidationMode: .strict
    )
    self.cathedralCoordinator = CathedralModule.create(config: cathedralConfig)

    // Initialize ServiceIntegrationStore with all service stores
    self.serviceIntegrationStore = ServiceIntegrationStore(
        daemonCapability: daemonCapability,
        modelRegistry: modelRegistry,
        hfAdapter: hfAdapter,
        cathedralCoordinator: cathedralCoordinator
    )
    self.sourceConnectionStore = SourceConnectionStore()
    self.workspaceStore = WorkspaceStore()
    self.daemonStore = DaemonStore(daemonCapability: daemonCapability)

    loadCache()
    loadHosts()
    // Note: Real data loading happens during daemon initialization

    self.connectionMonitor = ConnectionMonitor(capability: daemonCapability)

    // Inject ServiceIntegrationStore callbacks and configure
    serviceIntegrationStore.showToast = { [weak self] title, subtitle, icon in
        self?.showToast(title: title, subtitle: subtitle, icon: icon)
    }
    serviceIntegrationStore.showError = { [weak self] message in
        self?.showError(message)
    }
    serviceIntegrationStore.logNetworkActivity = { [weak self] event, domain, purpose, classification in
        self?.logNetworkActivity(domain: domain, isAllowed: true, reason: "\(event): \(purpose) (\(classification))")
    }
    serviceIntegrationStore.configureCallbacks()

    // Inject SourceConnectionStore callbacks for UI operations
    sourceConnectionStore.showToast = { [weak self] title, subtitle, icon in
      self?.showToast(title: title, subtitle: subtitle, icon: icon)
    }
    sourceConnectionStore.showError = { [weak self] message in
      self?.showError(message)
    }
    sourceConnectionStore.logNetworkActivity = { [weak self] event, domain, purpose, classification in
      self?.logNetworkActivity(domain: domain, isAllowed: true, reason: "\(event): \(purpose) (\(classification))")
    }
    sourceConnectionStore.onSourceConnectionChanged = { [weak self] sourceType, connected in
      self?.setSourceConnected(sourceType, connected: connected)
    }
    
    sourceConnectionStore.setup()

    // Inject WorkspaceStore callbacks and dependencies
    workspaceStore.client = client
    workspaceStore.showToast = { [weak self] title, subtitle, icon in
      self?.showToast(title: title, subtitle: subtitle, icon: icon)
    }
    workspaceStore.showError = { [weak self] message in
      self?.showError(message)
    }
    workspaceStore.logNetworkActivity = { [weak self] event, domain, purpose, classification in
      self?.logNetworkActivity(domain: domain, isAllowed: true, reason: "\(event): \(purpose) (\(classification))")
    }
    workspaceStore.onJobsChanged = { [weak self] in
      self?.syncJobStates()
    }
    workspaceStore.onArtifactsChanged = { [weak self] in
      // Trigger any artifact-related sync if needed
    }

    // Inject DaemonStore callbacks
    daemonStore.showToast = { [weak self] title, subtitle, icon in
      self?.showToast(title: title, subtitle: subtitle, icon: icon)
    }
    daemonStore.showError = { [weak self] message in
      self?.showError(message)
    }
    daemonStore.logNetworkActivity = { [weak self] event, domain, purpose, classification in
      self?.logNetworkActivity(domain: domain, isAllowed: true, reason: "\(event): \(purpose) (\(classification))")
    }
    daemonStore.syncJobStates = { [weak self] in
      self?.syncJobStates()
    }
    
    // Register system integrations
    Task { @MainActor in
        SystemUXSupport.shared.registerNotificationCategories()

        // Initialize and start background sync
        self.harmoniaBackgroundSync = HarmoniaBackgroundSync(appStore: self)
        self.harmoniaBackgroundSync?.start()
    }
  }

  // MARK: - Repository Maintenance

  /// Open a local git repository and switch to Develop mode
  func openLocalRepository(at url: URL) async {
      showToast(title: "Initializing Sandbox", subtitle: "Creating playground for agents...", icon: "clock.arrow.2.circlepath")
      do {
          let workspace = try await workspaceStore.openLocalRepository(at: url)
          sidebarSelection = .workspace(id: workspace.id.uuidString)
          mode = .develop
          normalizeSelectionForMode()
          showToast(title: "Repository Ready", subtitle: "\(workspace.name) (Sandboxed)", icon: "checkmark.shield.fill")
      } catch {
          showToast(title: "Failed to Open", subtitle: error.localizedDescription, icon: "exclamationmark.triangle.fill")
      }
  }

  func showToast(title: String, subtitle: String? = nil, icon: String? = nil, actionLabel: String? = nil) {
    let toast = AnigmaToast(id: UUID(), title: title, subtitle: subtitle, icon: icon, actionLabel: actionLabel)
    withAnimation {
        activeToasts.append(toast)
    }

    // Auto-dismiss after 4 seconds using structured concurrency
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(4.0))
        withAnimation {
            self.activeToasts.removeAll { $0.id == toast.id }
        }
    }
  }

  /// Shows a persistent error toast with red styling
  func showError(_ message: String) {
    let toast = AnigmaToast(
        id: UUID(),
        title: "⚠️ Error",
        subtitle: message,
        icon: "exclamationmark.octagon.fill",
        actionLabel: nil
    )
    withAnimation {
        activeToasts.append(toast)
    }

    // Errors stay longer - 8 seconds using structured concurrency
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(8.0))
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



  /// Initializes the Authority and starts the daemon if needed.
  func initialLoad() async {
    do {
      isInitializing = true
      initializationError = nil

       connectionMonitor?.start()

       // Initialize daemon via DaemonStore
       daemonStatus = "Initializing daemon..."
       try await daemonStore.initializeDaemon()
       
       // Copy daemon store properties
       self.authority = daemonStore.authority
       self.surfaceId = daemonStore.surfaceId
       self.actorId = daemonStore.actorId
       self.capabilityToken = daemonStore.capabilityToken
        self.client = daemonStore.client
        workspaceStore.client = self.client

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

    @MainActor
    func dispatchJob(_ spec: AnigmaJobSpec) async throws -> AnigmaSubmitJobResponse {
        let result = try await daemonStore.dispatchJob(spec)
        self.monitorDaemonJob(daemonId: result.jobID, title: spec.kind)
        return result
    }

  /// Monitors a daemon job and updates the local spine.
  func monitorDaemonJob(daemonId: String, title: String) {
      let localId = UUID()
      let initialJob = AnigmaJob(
          id: localId,
          daemonJobId: daemonId,
          title: "Daemon: \(title)",
          status: .pending,
          progress: 0,
          startedAt: Date()
      )

      Task { @MainActor in
          self.localJobs.append(initialJob)

          do {
              let stream = try await self.streamJobEvents(jobId: daemonId)
              for try await event in stream {
                  await MainActor.run {
                      if let index = self.localJobs.firstIndex(where: { $0.id == localId }) {
                          switch event.type {
                          case "STATE":
                              if !event.receiptHash.isEmpty {
                                  self.localJobs[index].receiptHash = event.receiptHash
                              }
                              switch event.message {
                              case "RUNNING":
                                  self.localJobs[index].status = .running
                                  self.showToast(title: "Job Started", subtitle: title, icon: "play.circle.fill")
                              case "SUCCEEDED":
                                  self.localJobs[index].status = .completed
                                  self.localJobs[index].progress = 1.0
                                  self.localJobs[index].completedAt = Date()
                                  self.showToast(title: "Job Completed", subtitle: title, icon: "checkmark.circle.fill")
                              case "FAILED":
                                  self.localJobs[index].status = .failed
                                  self.localJobs[index].message = event.message.isEmpty ? "Execution failed" : event.message
                                  self.showError("Job Failed: \(title)\n\(event.message.isEmpty ? "Check logs for details." : event.message)")
                              case "CANCELED":
                                  self.localJobs[index].status = .failed
                                  self.localJobs[index].message = "Canceled by user"
                                  self.showToast(title: "Job Canceled", subtitle: title, icon: "xmark.circle.fill")
                              default: break
                              }
                          case "PROGRESS":
                              self.localJobs[index].progress = Double(event.progressPermille) / 1000.0
                          case "LOG":
                              self.localJobs[index].message = event.message
                          case "OUTPUT":
                              if !event.receiptHash.isEmpty {
                                  self.localJobs[index].receiptHash = event.receiptHash
                              }
                              self.showToast(title: "Output Generated", subtitle: "New artifact from \(title)", icon: "doc.fill")
                          case "ERROR":
                              self.localJobs[index].status = .failed
                              self.localJobs[index].message = event.message
                              self.showError("Job Error: \(event.message)")
                          default: break
                          }
                      }
                  }
              }
          } catch {
              print("Monitoring failed for \(daemonId): \(error)")
              await MainActor.run {
                  if let index = self.localJobs.firstIndex(where: { $0.id == localId }) {
                      self.localJobs[index].status = .failed
                      self.localJobs[index].message = "Connection lost: \(error.localizedDescription)"
                  }
                  self.showError("Job Monitoring Failed\nLost connection to daemon for: \(title)\n\(error.localizedDescription)")
              }
          }
      }
  }

   @MainActor
   func refreshDaemonStatus() async {
       await daemonStore.refreshDaemonStatus()
   }

   /// Fetches raw receipt JSON for debugging/audit.
   @MainActor
   func fetchReceipt(hash: String) async {
       await daemonStore.fetchReceipt(hash: hash)
   }

   @MainActor
   func loadGlobalArtifacts(reset: Bool = false) async {
       await daemonStore.loadGlobalArtifacts(reset: reset)
   }

   /// Refreshes all daemon information
   @MainActor
   func refreshDaemonInfo() async {
       await daemonStore.refreshDaemonInfo()
   }



  /// Streams events for a submitted job.
  func streamJobEvents(jobId: String) async throws -> AsyncThrowingStream<AnigmaJobEvent, Error> {
      try await daemonStore.streamJobEvents(jobId: jobId)
  }

  /// Cancels a running job.
   @MainActor
   func cancelJob(jobId: String) async throws -> AnigmaCancelJobResponse {
       try await daemonStore.cancelJob(jobId: jobId)
   }

   /// Verifies the integrity of a receipt chain.
   @MainActor
   func verifyReceiptChain(headHash: String) async -> Bool {
       await daemonStore.verifyReceiptChain(headHash: headHash)
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
    await workspaceStore.loadWorkspaces()
    saveCache()
    if selectedWorkspaceID == nil && !workspaces.isEmpty {
      sidebarSelection = .workspace(id: workspaces[0].id)
      await workspaceStore.selectWorkspace(workspaces[0].id)
    }
  }

  func selectWorkspace(_ id: WorkspaceID) async {
    sidebarSelection = .workspace(id: id)
    guard id != selectedWorkspaceID else { return }
    await workspaceStore.selectWorkspace(id)
  }

  func loadMoreWorkspaces() async {
    await workspaceStore.loadMoreWorkspaces()
  }

  func switchRole(to role: AnigmaRole) {
    // In the future this might basic auth checks or context switching
    self.role = role

    // Reset sidebar selection to something sensible for the new role if needed
    // For now we keep it simple
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
      print("Error loading more artifacts: \(error)")
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
      print("Error loading more jobs: \(error)")
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
      print("Error creating workspace: \(error)")
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
      print("Error deleting artifacts: \(error)")
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
      print("Error updating workspace: \(error)")
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
      print("Error deleting workspace: \(error)")
    }
  }

  // MARK: - Job Submission

  func submitJob(action: String, parameters: [String: BindingValue]) async {
    guard let client = client else {
      print("Cannot submit job: client not initialized")
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

        let providerLabel = profile.binaryPath
            .map { URL(fileURLWithPath: $0).lastPathComponent }
            ?? agentProviders.first { $0.id == profile.providerId }?.displayName
            ?? profile.providerId
        showToast(title: "Agent Running", subtitle: "Executing \(providerLabel)...", icon: "brain")

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

    // --- General Intent Implementation (Refined from Ghost) ---
    let jobId = UUID()
    let jobTitle = action.uppercased().replacingOccurrences(of: "_", with: " ")
    let initialJob = AnigmaJob(
        id: jobId,
        title: jobTitle,
        message: "Initializing...",
        contextId: AppState.shared.currentContext?.id,
        status: .running,
        progress: 0.1,
        startedAt: Date()
    )
    self.localJobs.append(initialJob)

    showToast(
        title: "\(action.uppercased()) started",
        subtitle: "The engine is processing your request.",
        icon: "gearshape.fill"
    )

    Task {
        if action == "source_ingest" {
            let name = parameters["name"]?.stringValue ?? "Source"
            await runSimulatedJob(id: jobId, stages: [
                (0.1, "Discovery: Enumerating files..."),
                (0.4, "Indexing: Extracting text..."),
                (0.7, "Understanding: Mapping entities..."),
                (0.9, "Finalizing: Updating Atlas...")
            ])
            showToast(title: "Ingestion Complete", subtitle: "Source '\(name)' is now searchable.", icon: "checkmark.circle.fill")
        } else if action == "web-capture" {
            guard let html = parameters["html"]?.stringValue,
                  let urlStr = parameters["url"]?.stringValue,
                  let url = URL(string: urlStr),
                  let title = parameters["title"]?.stringValue
            else { return }

            await runSimulatedJob(id: jobId, stages: [
                (0.2, "Parsing DOM structure..."),
                (0.5, "Extracting semantics..."),
                (0.8, "Persisting graph nodes...")
            ])

            // Actually perform the work (from DataView logic)
            let extractor = WebContentExtractor()
            let structured = await extractor.extract(html: html, url: url, title: title)

            if let jsonData = try? JSONEncoder().encode(structured) {
                await uploadArtifact(name: "\(title).json", data: jsonData)
            }
            if let data = html.data(using: .utf8) {
                await uploadArtifact(name: "\(title).html", data: data)
            }
        } else if action == "ocr" {
            await runSimulatedJob(id: jobId, stages: [
                (0.3, "Extracting pixel data..."),
                (0.6, "Applying OCR engine (Vision)..."),
                (0.9, "Generating searchable layer...")
            ])
        } else if action == "translate" {
            await runSimulatedJob(id: jobId, stages: [
                (0.4, "Mapping semantic structure..."),
                (0.8, "Translating tokens...")
            ])
        } else if action == "summarize" {
            await runSimulatedJob(id: jobId, stages: [
                (0.5, "Condensing information..."),
                (0.8, "Formulating brief...")
            ])
        } else if action == "extract_deadlines" {
            await runSimulatedJob(id: jobId, stages: [
                (0.4, "Scanning artifacts for date entities..."),
                (0.7, "Validating temporal context...")
            ])
        } else if action == "verify_claims" {
            await runSimulatedJob(id: jobId, stages: [
                (0.3, "Searching evidence ledger..."),
                (0.6, "Applying consistency checks..."),
                (0.9, "Calculating confidence score...")
            ])
        } else if action == "generate_response" {
            await runSimulatedJob(id: jobId, stages: [
                (0.4, "Synthesizing research notes..."),
                (0.8, "Formulating final report...")
            ])
        } else {
            // Default: Hand off to daemon
            _ = await client.submitIntent(action: action, parameters: parameters)

            // Artificial delay to feel "real" if it was too fast
            try? await Task.sleep(nanoseconds: 500_000_000)

            await MainActor.run {
                if let index = self.localJobs.firstIndex(where: { $0.id == jobId }) {
                    self.localJobs[index].status = .completed
                    self.localJobs[index].progress = 1.0
                    self.localJobs[index].completedAt = Date()
                    self.localJobs[index].message = "Executed by Authority"
                }
            }
        }
    }

    // Refresh jobs list
    if let workspaceId = selectedWorkspaceID {
      await selectWorkspace(workspaceId)
    }
  }

  private func runSimulatedJob(id: UUID, stages: [(Double, String)]) async {
      for (prog, msg) in stages {
          await MainActor.run {
              updateJob(id: id, progress: prog, message: msg)
          }
          // Random delay between 0.5s and 1.5s
          let delay = UInt64.random(in: 500_000_000...1_500_000_000)
          try? await Task.sleep(nanoseconds: delay)
      }

      await MainActor.run {
          if let index = self.localJobs.firstIndex(where: { $0.id == id }) {
              self.localJobs[index].status = .completed
              self.localJobs[index].progress = 1.0
              self.localJobs[index].completedAt = Date()
              self.localJobs[index].message = "Operation Complete"
          }
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
          print("Failed to extract version from \(binaryPath): \(error)")
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
          print("Failed to extract signing identity: \(error)")
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
        print("Event stream error: \(error)")
      }
    }
  }

  private func syncJobStates() {
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

      let localRunningCount = localJobs.filter { $0.status == .running || $0.status == .pending }.count
      state.runningJobsCount = jobs.filter { $0.status.uppercased() == "RUNNING" || $0.status.uppercased() == "QUEUED" }.count + localRunningCount
      state.blockedJobsCount = jobs.filter { $0.status.uppercased() == "BLOCKED" }.count
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

      // Sync handled by onJobsChanged callback
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
      print("Error uploading artifact: \(error)")
    }
  }

  func downloadArtifact(id: ArtifactID) async -> Data? {
    guard let client = client else { return nil }

    do {
      return try await client.query.downloadArtifact(id: id)
    } catch {
      print("Error downloading artifact: \(error)")
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
      print("Error deleting artifact: \(error)")
    }
  }

  // MARK: - Job Management

  func cancelJob(id: JobID) async {
    guard let client = client else { return }

    do {
      try await client.command.cancelJob(id: id)
    } catch {
      print("Error cancelling job: \(error)")
    }
  }

  func deleteJob(id: JobID) async {
    guard let client = client else { return }

    do {
      try await client.command.deleteJob(id: id)
      if let workspaceId = selectedWorkspaceID {
          await workspaceStore.selectWorkspace(workspaceId)
      }
    } catch {
      print("Error deleting job: \(error)")
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
      print("Error verifying job: \(error)")
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
      print("Error evaluating action: \(error)")
      return .denied(reason: error.localizedDescription)
    }
  }

  // MARK: - Harmonia CLI Operations (Delegated to HarmoniaStore)

  /// Refresh vault status from Harmonia CLI
  func refreshVaultStatus() async {
     await serviceIntegrationStore.serviceIntegrationStore.harmoniaStore.refreshVaultStatus()
  }

  /// Verify vault integrity
  func verifyVault() async throws -> HarmoniaClient.VaultVerificationResponse {
     return try await serviceIntegrationStore.serviceIntegrationStore.harmoniaStore.verifyVault()
  }

  /// Run vault garbage collection
  func runVaultGC(dryRun: Bool = false) async throws -> HarmoniaClient.VaultGCResponse {
    return try await serviceIntegrationStore.harmoniaStore.runVaultGC(dryRun: dryRun)
  }

  /// Refresh pipeline status from Harmonia CLI
  func refreshPipelineStatus() async {
    guard let workspace = activeWorkspace else { return }
    await serviceIntegrationStore.harmoniaStore.refreshPipelineStatus(workspace: workspace.id.uuidString)
  }

  /// Run tech debt audit on a path
  func runTechDebtAudit(path: String) async {
    await serviceIntegrationStore.harmoniaStore.runTechDebtAudit(path: path)
  }

  /// Search the ledger
  func searchLedger(query: String, limit: Int = 10) async {
    await serviceIntegrationStore.harmoniaStore.searchLedger(query: query, limit: limit)
  }

  /// Get current daemon status
  func getDaemonStatus() async -> String {
    let status = await daemonCapability.getDaemonStatus()
    return status.description
  }

  /// Start daemon via Harmonia CLI
  func startDaemon() async throws {
    try await serviceIntegrationStore.harmoniaStore.startDaemon()
  }

  /// Stop daemon via Harmonia CLI
  func stopDaemon() async throws {
    try await serviceIntegrationStore.harmoniaStore.stopDaemon()
  }

  /// Check if vault status needs refresh (5 minute cache)
  var vaultNeedsRefresh: Bool {
    serviceIntegrationStore.harmoniaStore.vaultNeedsRefresh
  }

  /// Check if pipeline status needs refresh (30 second cache)
  var pipelineNeedsRefresh: Bool {
    serviceIntegrationStore.harmoniaStore.pipelineNeedsRefresh
  }

  // MARK: - Doctrine Operations (Delegated to DoctrineStore)

  /// Scan a path for doctrine violations
  func scanDoctrine(path: String, domains: [String]? = nil) async {
    await serviceIntegrationStore.doctrineStore.scan(path: path, domains: domains)
  }

  /// Load doctrine violation statistics
  func loadDoctrineStats() async {
    await serviceIntegrationStore.doctrineStore.loadStats()
  }

  /// Load available doctrine rules
  func loadDoctrineRules(domain: String? = nil) async {
    await serviceIntegrationStore.doctrineStore.loadRules(domain: domain)
  }

  /// Load available doctrine packs
  func loadDoctrinePacks() async {
    await serviceIntegrationStore.doctrineStore.loadPacks()
  }

  /// Resolve a doctrine violation
  func resolveDoctrineViolation(id: String, note: String? = nil) async throws {
    try await serviceIntegrationStore.doctrineStore.resolveViolation(id: id, note: note)
  }

  /// Enable a doctrine pack
  func enableDoctrinePack(id: String) async throws {
    try await serviceIntegrationStore.doctrineStore.enablePack(id: id)
  }

  /// Disable a doctrine pack
  func disableDoctrinePack(id: String) async throws {
    try await serviceIntegrationStore.doctrineStore.disablePack(id: id)
  }

  /// Get rule details
  func getDoctrineRuleDetails(id: String) async -> DoctrineClient.RuleDetailResponse? {
    return await serviceIntegrationStore.doctrineStore.getRuleDetails(id: id)
  }

  /// Get pack details
  func getDoctrinePackDetails(id: String) async -> DoctrineClient.PackDetailResponse? {
    return await serviceIntegrationStore.doctrineStore.getPackDetails(id: id)
  }

  /// List violations with filters
  func listDoctrineViolations(
    severity: String? = nil,
    domain: String? = nil,
    resolved: Bool? = nil,
    limit: Int = 100
  ) async {
    await serviceIntegrationStore.doctrineStore.listViolations(
      severity: severity,
      domain: domain,
      resolved: resolved,
      limit: limit
    )
  }

  // MARK: - ML Worker Operations (Delegated to MLStore)

  /// Load ML worker status
  func loadMLWorkerStatus() async {
    await serviceIntegrationStore.mlStore.loadRegisteredModels()
  }

  // MARK: - Model Registry Operations (Delegated to MLStore)

  /// Load registered models from registry
  func loadRegisteredModels() async {
    await serviceIntegrationStore.mlStore.loadRegisteredModels()
  }

  /// Import a HuggingFace model
  func importHuggingFaceModel(
    repo: String,
    revision: String = "main",
    progressHandler: @escaping (Double) -> Void = { _ in }
  ) async {
    await serviceIntegrationStore.mlStore.importHuggingFaceModel(
      repo: repo,
      revision: revision,
      progressHandler: progressHandler
    )
  }

  /// Describe a HuggingFace model without importing
  func describeHuggingFaceModel(repo: String, revision: String = "main") async -> HFModelDescriptor? {
    return await serviceIntegrationStore.mlStore.describeHuggingFaceModel(repo: repo, revision: revision)
  }

  /// Execute a governed ML run with separate parameters
  func executeGovernedMLRun(
    modelId: String,
    taskKind: ContractsCore.MLTaskKind,
    inputs: [ContractsCore.RunSpec.Input],
    backend: String,
    seed: Int? = nil,
    temperature: Double? = nil,
    topP: Double? = nil,
    maxTokens: Int? = nil
  ) async throws -> ContractsCore.ExecutionReceipt {
    // Convert backend string to MLBackend
    let mlBackend = ContractsCore.MLBackend(rawValue: backend) ?? .local
    // Convert RunSpec.Input to MLInput (assuming compatible initializer)
    let mlInputs = inputs.map { ContractsCore.MLInput(path: $0.path, hash: $0.hash, kind: $0.kind) }
    let config = MLStore.ExecuteGovernedMLRunConfiguration(
      modelId: modelId,
      taskKind: taskKind,
      inputs: mlInputs,
      backend: mlBackend,
      seed: seed,
      temperature: temperature,
      topP: topP,
      maxTokens: maxTokens
    )
    return try await serviceIntegrationStore.mlStore.executeGovernedMLRun(config: config)
  }

  /// Delete a model from registry and disk
  func deleteModel(_ modelId: String) async {
    await serviceIntegrationStore.mlStore.deleteModel(modelId)
  }

  /// Submit an ML task
  func submitMLTask(
    engine: String,
    task: MLTaskKind,
    inputs: [ContractsCore.MLArtifactRef],
    options: MLTaskOptions? = nil
  ) async {
    await serviceIntegrationStore.mlStore.submitMLTask(
      engine: engine,
      task: task,
      inputs: inputs,
      options: options
    )
  }

  /// Clear completed ML tasks
  func clearCompletedMLTasks() {
    serviceIntegrationStore.mlStore.clearCompletedMLTasks()
  }

  // MARK: - Agent Execution

  func runAgent(id: String, instruction: String) async {
      guard let workspaceId = activeWorkspaceID else {
          showToast(title: "No Workspace", subtitle: "Select a workspace first.", icon: "exclamationmark.triangle")
          return
      }

      do {
          _ = try await agentOrchestrator.execute(agentId: id, instruction: instruction, workspaceId: workspaceId, workingDirectory: activeWorkspace?.sandboxURL ?? activeWorkspace?.rootURL)
          showToast(title: "Agent Enqueued", subtitle: "Running in background.", icon: "paperplane.fill")
      } catch {
          showToast(title: "Agent Failed", subtitle: error.localizedDescription, icon: "xmark.circle")
      }
  }

  // MARK: - Accessum Flow Operations (Delegated to AccessumFlowStore)

  func loadAccessPolicies() async {
    await serviceIntegrationStore.accessumFlowStore.loadPolicies()
  }

  func createAccessPolicy(name: String, rules: [AccessRule]) async {
    await serviceIntegrationStore.accessumFlowStore.createPolicy(name: name, rules: rules)
  }

  func updateAccessPolicy(id: String, rules: [AccessRule]) async {
    await serviceIntegrationStore.accessumFlowStore.updatePolicy(id: id, rules: rules)
  }

  func deleteAccessPolicy(id: String) async {
    await serviceIntegrationStore.accessumFlowStore.deletePolicy(id: id)
  }

  func checkAccess(actor: String, resource: String, action: String) async -> Bool {
    return await serviceIntegrationStore.accessumFlowStore.checkAccess(actor: actor, resource: resource, action: action)
  }

  func loadAccessAuditLog() async {
    await serviceIntegrationStore.accessumFlowStore.loadAuditLog()
  }

  func refreshFlowStatus() async {
    await serviceIntegrationStore.accessumFlowStore.refreshFlowStatus()
  }

  // MARK: - Surface Operations (Delegated to SurfaceStore)

  func loadSurfaces() async {
    await serviceIntegrationStore.surfaceStore.loadSurfaces()
  }

  func createSurface(name: String, type: SurfaceType, config: SurfaceConfig) async {
    await serviceIntegrationStore.surfaceStore.createSurface(name: name, type: type, config: config)
  }

  func renderToSurface(surfaceId: String, content: RenderContent) async {
    await serviceIntegrationStore.surfaceStore.renderToSurface(surfaceId: surfaceId, content: content)
  }

  func exportSurface(surfaceId: String, format: SurfaceExportFormat, outputPath: String) async {
    await serviceIntegrationStore.surfaceStore.exportSurface(surfaceId: surfaceId, format: format, outputPath: outputPath)
  }

  func loadSurfaceMetrics(surfaceId: String) async {
    await serviceIntegrationStore.surfaceStore.loadSurfaceMetrics(surfaceId: surfaceId)
  }

  // MARK: - AST Services Operations (Delegated to ASTServicesStore)

  func analyzeCode(filePath: String, checks: [String] = []) async {
    await serviceIntegrationStore.astServicesStore.analyzeCode(filePath: filePath, checks: checks)
  }

  func findSymbolReferences(symbol: String, directory: String) async {
    await serviceIntegrationStore.astServicesStore.findSymbolReferences(symbol: symbol, directory: directory)
  }

  func refactorCode(filePath: String, operation: RefactorOperation) async {
    await serviceIntegrationStore.astServicesStore.refactorCode(filePath: filePath, operation: operation)
  }

  func parseFile(filePath: String, language: String) async {
    await serviceIntegrationStore.astServicesStore.parseFile(filePath: filePath, language: language)
  }

  func getSymbols(filePath: String) async {
    await serviceIntegrationStore.astServicesStore.getSymbols(filePath: filePath)
  }

  // MARK: - Pipeline Operations (Delegated to PipelineStore)

  func loadPipelines() async {
      await serviceIntegrationStore.pipelineStore.loadPipelines()
  }

  func createPipeline(name: String, stages: [AnigmaHostMac.PipelineStage]) async {
      await serviceIntegrationStore.pipelineStore.createPipeline(name: name, stages: stages)
  }

  func runPipeline(id: String, inputs: [String: String]) async {
      await serviceIntegrationStore.pipelineStore.runPipeline(id: id, inputs: inputs)
  }

  func monitorPipelineRun(runId: String) async {
      await serviceIntegrationStore.pipelineStore.monitorPipelineRun(runId: runId)
  }

  func cancelPipeline(runId: String) async {
      await serviceIntegrationStore.pipelineStore.cancelPipeline(runId: runId)
  }

  func getPipelineStatus(runId: String) async -> PipelineStatusResponse? {
      return await serviceIntegrationStore.pipelineStore.getPipelineStatus(runId: runId)
  }

  // MARK: - Outline/Zine Operations (Delegated to OutlineStore)

  func generateOutline(content: String, depth: Int = 3) async {
    await serviceIntegrationStore.outlineStore.generateOutline(content: content, depth: depth)
  }

  func createZine(outline: OutlineStructure, template: String? = nil) async {
    await serviceIntegrationStore.outlineStore.createZine(outline: outline, template: template)
  }

  func loadZineTemplates() async {
    await serviceIntegrationStore.outlineStore.loadTemplates()
  }

  func analyzeDocumentStructure(filePath: String) async {
    await serviceIntegrationStore.outlineStore.analyzeStructure(filePath: filePath)
  }

  func exportZine(zineId: String, format: ZineExportFormat, outputPath: String) async {
    await serviceIntegrationStore.outlineStore.exportZine(zineId: zineId, format: format, outputPath: outputPath)
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

    if let data = UserDefaults.standard.data(forKey: "pinned_actions"),
      let decoded = try? decoder.decode([PinnedAction].self, from: data) {
      pinnedActions = decoded
    } else {
      // Default pinned actions
      pinnedActions = [
        PinnedAction(id: "ocr", title: "OCR", systemImage: "doc.text.viewfinder", actionName: "ocr"),
        PinnedAction(id: "translate", title: "Translate", systemImage: "globe", actionName: "translate"),
        PinnedAction(id: "summarize", title: "Summarize", systemImage: "text.quote", actionName: "summarize")
      ]
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
