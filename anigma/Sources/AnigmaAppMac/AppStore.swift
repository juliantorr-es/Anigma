//
//  AppStore.swift
//  AnigmaAppMac
//
//   Bauhaus Architecture - God object refactored into focused managers.
//

import AnigmaClientKit
import AnigmaSystemSpine
import AnigmaHostMac
import AnigmaHostKit
import AnigmaAgents
import AnigmaAIConsole
import ExportCore
import AnigmaWork
import DataEngine
import ContractsCore
import AnigmaPrimitives
import CryptoKit
import Foundation
import ModelManagement
import AnigmaCore
import Combine
import SwiftUI
import Observation
import UniformTypeIdentifiers
import DatabaseCore
import MLWorkerCommon
import ModelManagement

@MainActor
@Observable
final class AppStore {
    struct LedgerSearchProjectionState {
        var query: String = ""
        var results: [HarmoniaClient.SearchResult] = []
        var totalMatches: Int = 0
        var isSearching: Bool = false
        var errorMessage: String?

        var response: HarmoniaClient.SearchResponse? {
            guard !query.isEmpty else { return nil }
            return HarmoniaClient.SearchResponse(query: query, results: results, totalMatches: totalMatches)
        }
    }
    
    struct VaultStatusInfo {
        var totalArtifacts: Int = 0
        var storageUsed: Int = 0
        var status: String = "ready"
    }
    
    struct PipelineStatusInfo {
        var pendingJobs: Int = 0
        var runningJobs: Int = 0
        var completedJobs: Int = 0
        var failedJobs: Int = 0
    }

    // MARK: - Bauhaus Architecture State
    
    /// Artifact service for chunking and virtualization
    let developArtifactService: DevelopumArtifactService
    
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
    var consoleLogs: [ConsoleEntry] = []
    var agentProviders: [AgentProvider] = []
    var agentProfiles: [AgentProfile] = []
    var workItems: [WorkItem] = []
    var tools: [AnigmaTool] = []
    var localJobs: [AnigmaJob] = [] {
        didSet { syncJobStates() }
    }
    var networkActivityLog: [NetworkActivityEntry] = []
    
    // MARK: - Managers (Phase 2 Extraction)
    var intakeManager: IntakeManager!
    var contextManager: ContextManager!
    var jobManager: JobManager!
    var developManager: DevelopManager!
    var cacheManager: CacheManager!
    
    // MARK: - Sub-stores
    let serviceIntegrationStore: ServiceIntegrationStore
    let sourceConnectionStore: SourceConnectionStore
    let workspaceStore: WorkspaceStore
    let modelRegistry: ModelRegistryAppStore
    let daemonStore: DaemonStore
    
    // MARK: - Infrastructure
    internal let daemonCapability: DaemonHostCapability
    let systemSpine: SystemSpine
    let dataEngine: DataEngine
    let agentOrchestrator: AgentOrchestrator
    let exportEngine: ExportEngine
    let aiConsoleClient: AIConsoleClient
    
    internal private(set) var connectionMonitor: ConnectionMonitor?
    private var irSubscriptionTask: Task<Void, Never>?
    internal private(set) var authority: AnigmaAuthority?
    internal private(set) var client: MacAnigmaClient?
    private(set) public var surfaceId: SurfaceId?
    private(set) public var actorId: ActorId?
    private var capabilityToken: ContractsCore.CapabilityToken?
    
    // MARK: - UI & Session State
    var chrome = ChromeState()
    var isSourceConnectionPresented = false
    var isExportPresented = false
    var session = SessionState()
    var inspectorSelection: InspectorSelection?
    private(set) var isInitializing: Bool = true
    private(set) var initializationError: String?
    var isOnline: Bool = true
    var activeToasts: [AnigmaToast] = []
    var isJobCenterPresented: Bool = false
    var isAIConsolePresented: Bool = false
    var isHarmoniaCliPresented: Bool = false
    var focusOmniBar: Bool = false
    var triggerQuickLook: Bool = false
    var ledgerSearchProjection = LedgerSearchProjectionState()
    
    // MARK: - Vault & Telemetry
    var vaultStatus: VaultStatusInfo = VaultStatusInfo()
    var vaultNeedsRefresh: Bool = false
    var telemetryEntries: [String] = []
    
    enum SidebarItem: Hashable {
        case workspace(id: WorkspaceID)
        case actionCatalog
        case settings
    }
    
    var sidebarSelection: SidebarItem? {
        didSet {
            if case .workspace(let id) = sidebarSelection {
                Task {
                    await workspaceStore.selectWorkspace(id)
                }
            }
        }
    }
    
    var isRepoPickerPresented: Bool = false
    
    // Analysis Results and Latency Measurement
    var techDebtReport: HarmoniaClient.TechDebtAuditResponse? = nil
    var lastAnalysisLatency: TimeInterval? = nil
    
    var artifactSearchQuery: String = ""
    var sidecarError: String?
    var jobSearchQuery: String = ""
    var jobStatusFilter: JobStatusFilter = .all
    var jobTrustFilter: JobTrustFilter = .all
    var actionCatalog: [ActionDefinition] = []
    var hosts: [DaemonHost] = []
    var pinnedActions: [PinnedAction] = []
    
    // MARK: - Model Browser State
    // Note: Model browser state is defined in AppStoreModelExtensions
    var activeDownloads: [Any] = []
    var queuedDownloads: [Any] = []
    var storageStatus: Any?
    var storageWarnings: [Any] = []
    var modelSearchResults: [AnigmaClientKit.HFSearchResult] = []
    var isSearchingModels: Bool = false
    
    // MARK: - Download Management
    var downloadQueue: DownloadQueueManager? { nil }
    var hfClient: HuggingFaceHubClient? { nil }
    var hfKeychain: AnigmaClientKit.HuggingFaceKeychain? { nil }
    var systemBenchmark: SystemBenchmark? { nil }
    var isRunningBenchmark: Bool = false
    var benchmarkResult: SystemBenchmark.Result?
    var modelSearchError: String?
    var storageWarning: String? { nil }

    func loadMoreArtifacts() async {
        // Pagination stub
    }
    
    // MARK: - Harmonia Background Services
    public private(set) var harmoniaBackgroundSync: HarmoniaBackgroundSync?
    public private(set) var harmoniaCommandHistory: HarmoniaCommandHistory?
    
    // MARK: - Additional Properties
    var hasRunningJobs: Bool { !localJobs.isEmpty }
    var governanceMode: GovernanceMode { .verify }
    var pipelineStatus: HarmoniaClient.PipelineStatusResponse? = nil
    var runtime: String { "native" }
    var adminSurfacesEnabled: Bool = true
    var developerToolsEnabled: Bool = true
    var daemonBridge: Any? { nil }
    var harmoniaClient: DoctrineClient? { nil }
    var doctrineClient: DoctrineClient? { nil }
    var doctrinePacks: DoctrineClient.PacksResponse? { nil }
    var doctrineScanResults: DoctrineClient.ScanResponse? { nil }
    var doctrineStats: DoctrineClient.ViolationStatsResponse? { nil }
    var doctrineViolations: DoctrineClient.ViolationsResponse? { nil }
    var doctrineRules: DoctrineClient.RulesResponse? { nil }
    var privacySettings: [String: Bool] { [:] }
    var googleOAuthLastRefreshAt: Date? { nil }

    // MARK: - Initialization
    
    init() {
        self.daemonCapability = DaemonHostCapability()
        self.systemSpine = SystemSpine.shared
        self.dataEngine = DataEngine()
        
        // Define appSupport early for service initialization
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Failed to unwrap appSupport")
        }
        
        // Initialize Developum Services
        let developumRoot = appSupport.appendingPathComponent("Anigma/Developum", isDirectory: true)
        let vaultRoot = appSupport.appendingPathComponent("Anigma/Vault", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: developumRoot, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: vaultRoot, withIntermediateDirectories: true)
        } catch {
            initializationError = "Developum storage unavailable: \(error.localizedDescription)"
        }

        let databasePath = developumRoot.appendingPathComponent("developum.postgres").path
        let databaseExecutor: any DatabaseExecutor = DatabaseActor(path: databasePath)
        let databaseAuthority = AppDatabaseAuthority(database: databaseExecutor)
        let artifactAuthority = AppArtifactAuthority(
            databaseAuthority: databaseAuthority,
            vaultRoot: vaultRoot
        )
        self.developArtifactService = DevelopumArtifactService()
        
        // Initialize AI Registry
        let registryURL = appSupport.appendingPathComponent("Anigma/AIRegistry")
        let registry = AIRegistry(storageURL: registryURL)
        
        self.agentOrchestrator = AgentOrchestrator(jobEngine: systemSpine.jobEngine, dataEngine: dataEngine, registry: registry)
        self.exportEngine = ExportEngine(jobEngine: systemSpine.jobEngine)
        self.aiConsoleClient = AIConsoleClient(jobEngine: systemSpine.jobEngine, registry: registry)
        self.harmoniaCommandHistory = HarmoniaCommandHistory()
        
        self.daemonStore = DaemonStore(daemonCapability: daemonCapability)
        self.serviceIntegrationStore = ServiceIntegrationStore(
            daemonCapability: daemonCapability,
            daemonStore: daemonStore
        )
        self.sourceConnectionStore = SourceConnectionStore(daemonStore: daemonStore)
        self.workspaceStore = WorkspaceStore()
        self.modelRegistry = ModelRegistryAppStore()

        let modelRegistryRoot = appSupport.appendingPathComponent("Anigma/ModelRegistry", isDirectory: true)
        let modelRegistryArtifactsRoot = modelRegistryRoot.appendingPathComponent("Artifacts", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: modelRegistryRoot, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: modelRegistryArtifactsRoot, withIntermediateDirectories: true)
        } catch {
            if initializationError == nil {
                initializationError = "Model registry storage unavailable: \(error.localizedDescription)"
            }
        }
        
        // Initialize Managers
        self.intakeManager = IntakeManager(store: self)
        self.contextManager = ContextManager(store: self)
        self.jobManager = JobManager(store: self)
        self.developManager = DevelopManager(store: self)
        self.cacheManager = CacheManager(store: self)
        
        self.connectionMonitor = ConnectionMonitor(capability: daemonCapability)

        Task { @MainActor [weak self] in
            do {
                try await databaseAuthority.prepare()
                try await artifactAuthority.prepare()
            } catch {
                if self?.initializationError == nil {
                    self?.initializationError = error.localizedDescription
                }
            }
        }
        
        setupCallbacks()
        loadCache()
        loadHosts()

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.modelRegistry.bootstrap(
                storagePath: modelRegistryRoot.appendingPathComponent("models.postgres").path,
                artifactStore: modelRegistryArtifactsRoot
            )
        }
    }
    
    private func setupCallbacks() {
        setupServiceIntegrationCallbacks()
        setupSourceConnectionCallbacks()
        setupWorkspaceCallbacks()
        setupDaemonCallbacks()
        setupBackgroundSync()
    }
    
    private func setupServiceIntegrationCallbacks() {
        serviceIntegrationStore.showToast = { [weak self] title, subtitle, icon in
            self?.showToast(title: title, subtitle: subtitle, icon: icon)
        }
        serviceIntegrationStore.showError = { [weak self] message in
            self?.showError(message)
        }
        serviceIntegrationStore.logNetworkActivity = { [weak self] event, domain, purpose, classification in
            self?.logNetworkActivity(domain: domain, isAllowed: true, reason: "\(event): \(purpose) (\(classification))")
        }
        serviceIntegrationStore.harmoniaStore.projectLedgerSearch = { [weak self] projection in
            self?.ledgerSearchProjection.query = projection.query
            self?.ledgerSearchProjection.results = projection.results
            self?.ledgerSearchProjection.totalMatches = projection.totalMatches
            self?.ledgerSearchProjection.isSearching = projection.isSearching
            self?.ledgerSearchProjection.errorMessage = projection.errorMessage
        }
        serviceIntegrationStore.configureCallbacks()
    }
    
    private func setupSourceConnectionCallbacks() {
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
    }
    
    private func setupWorkspaceCallbacks() {
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
    }
    
    private func setupDaemonCallbacks() {
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
    }
    
    private func setupBackgroundSync() {
        SystemUXSupport.shared.registerNotificationCategories()
        self.harmoniaBackgroundSync = HarmoniaBackgroundSync(appStore: self)
        self.harmoniaBackgroundSync?.start()
    }
    
    // MARK: - State Delegation
    
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
    var currentProject: WorkbenchProject? {
        get { workspaceStore.currentProject }
        set { workspaceStore.currentProject = newValue }
    }
    var workspaces: [AnigmaClientKit.WorkspaceSummary] {
        workspaceStore.workspaces
    }
    var artifacts: [AnigmaClientKit.ArtifactSummary] {
        get { workspaceStore.artifacts }
        set { workspaceStore.artifacts = newValue }
    }
    var jobs: [AnigmaClientKit.JobSummary] {
        get { workspaceStore.jobs }
        set { workspaceStore.jobs = newValue }
    }
    var daemonStatus: String {
        get { daemonStore.daemonStatus }
        set { daemonStore.daemonStatus = newValue }
    }
    var daemonDetailedStatus: AnigmaStatusResponse? {
        daemonStore.daemonDetailedStatus
    }
    var selectedReceiptJson: String? {
        get { daemonStore.selectedReceiptJson }
        set { daemonStore.selectedReceiptJson = newValue }
    }
    var globalArtifacts: [AnigmaArtifactRef] {
        daemonStore.globalArtifacts
    }
    var globalArtifactsCursor: String? {
        daemonStore.globalArtifactsCursor
    }
    var hasMoreWorkspaces: Bool {
        workspaceStore.hasMoreWorkspaces
    }
    var hasMoreArtifacts: Bool {
        workspaceStore.hasMoreArtifacts
    }
    var activeWorkspace: RepoWorkspace? {
        workspaceStore.activeWorkspace
    }
    var selectedFileURL: URL? {
        get { workspaceStore.selectedFileURL }
        set { workspaceStore.selectedFileURL = newValue }
    }
    var developNavMode: DevelopNavMode {
        get { AppState.shared.developNavMode }
        set { AppState.shared.developNavMode = newValue }
    }
    var developWorkbenchTab: DevelopWorkbenchTab {
        get { workspaceStore.developWorkbenchTab }
        set { workspaceStore.developWorkbenchTab = newValue }
    }
    var userSurface: UserSurface {
        get { AppState.shared.selectedSurface }
        set { AppState.shared.selectedSurface = newValue }
    }
    var activeWorkspaceID: UUID? {
        workspaceStore.activeWorkspaceID
    }
    var hasMoreJobs: Bool {
        workspaceStore.hasMoreJobs
    }
    var selectedWorkspaceID: WorkspaceID? {
        if case .workspace(let id) = sidebarSelection {
            return id
        }
        return nil
    }
    var isDaemonConnected: Bool {
        daemonStore.isDaemonConnected
    }
    
    // MARK: - Intake Logic
    
    @MainActor func handleIntake(_ providers: [NSItemProvider]) { intakeManager.handleIntake(providers) }
    @MainActor func handleIntake(url: URL) { intakeManager.handleIntake(url: url) }
    
    // MARK: - Context Operations
    
    @MainActor func activateContext(_ context: AnigmaContext) { contextManager.activateContext(context) }
    
    // MARK: - Job Operations
    
    func submitJob(action: String, parameters: [String: BindingValue]) async { await jobManager.submitJob(action: action, parameters: parameters) }
    func runSimulatedJob(id: UUID, stages: [(Double, String)]) async { await jobManager.runSimulatedJob(id: id, stages: stages) }
    func cancelJob(id: JobID) async { await jobManager.cancelJob(id: id) }
    func deleteJob(id: JobID) async { await jobManager.deleteJob(id: id) }
    func verifyJob(id: JobID) async { await jobManager.verifyJob(id: id) }
    
    @MainActor
    func dispatchJob(_ spec: AnigmaJobSpec) async throws -> AnigmaSubmitJobResponse {
        let result = try await daemonStore.dispatchJob(spec)
        if let jobId = result.jobId {
            self.monitorDaemonJob(daemonId: jobId, title: spec.kind)
        }
        return result
    }
    
    func loadHosts() {
        self.hosts = [
            DaemonHost(id: "local", name: "Local Node", url: URL(string: "http://localhost:8080")!, status: .online)
        ]
    }
    
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
    
    // MARK: - Develop Mode Operations
    
    func applyChangeSet(_ changeSetId: UUID) async { await developManager.applyChangeSet(changeSetId) }
    func rejectChangeSet(_ changeSetId: UUID) async { await developManager.rejectChangeSet(changeSetId) }
    func runCheckProfile(name: String) async { await developManager.runCheckProfile(name: name) }
    func discoverAgentProviders() async { await developManager.discoverAgentProviders() }
    func enableAgentProvider(_ providerId: String) async { await developManager.enableAgentProvider(providerId) }
    func runAgent(id: String, instruction: String) async { await developManager.runAgent(id: id, instruction: instruction) }

    // MARK: - Workspace & Repository
    
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
    
    func selectWorkspace(_ id: WorkspaceID) async {
        sidebarSelection = .workspace(id: id)
        guard id != selectedWorkspaceID else { return }
        await workspaceStore.selectWorkspace(id)
    }
    
    func loadMoreWorkspaces() async { await workspaceStore.loadMoreWorkspaces() }
    func createWorkspace(name: String = "New Workspace") async { 
        await workspaceStore.createWorkspace(name: name) 
        if let id = workspaceStore.workspaces.first(where: { $0.name == name })?.id {
            sidebarSelection = .workspace(id: id)
        }
    }
    func updateWorkspace(id: WorkspaceID, name: String) async { await workspaceStore.updateWorkspace(id: id, name: name) }
    func deleteWorkspace(id: WorkspaceID) async { 
        await workspaceStore.deleteWorkspace(id: id)
        if selectedWorkspaceID == id {
            if let firstId = workspaces.first?.id {
                sidebarSelection = .workspace(id: firstId)
                await selectWorkspace(firstId)
            } else {
                sidebarSelection = nil
            }
        }
    }

    // MARK: - Artifact Management
    
    func uploadArtifact(name: String, data: Data) async {

        guard let client = client, let workspaceId = selectedWorkspaceID else { return }
        do {
            _ = try await client.command.uploadArtifact(workspaceId: workspaceId, name: name, data: data)
            await selectWorkspace(workspaceId)
        } catch {
            print("Error uploading artifact: \(error)")
        }
    }
    
    func downloadArtifact(id: AnigmaClientKit.ArtifactID) async -> Data? {
        guard let client = client else { return nil }
        return try? await client.query.downloadArtifact(id: id)
    }
    
    func deleteArtifact(id: AnigmaClientKit.ArtifactID) async {
        guard let client = client, let workspaceId = selectedWorkspaceID else { return }
        do {
            try await client.command.deleteArtifact(id: id)
            await selectWorkspace(workspaceId)
            if case .artifact(let selectedId) = inspectorSelection, selectedId == id {
                inspectorSelection = nil
            }
        } catch {
            print("Error deleting artifact: \(error)")
        }
    }
    
    // MARK: - Daemon Communication
    
    func initialLoad() async {
        isInitializing = true
        connectionMonitor?.start()
        await daemonStore.initializeDaemon()
        self.authority = daemonStore.authority
        self.surfaceId = daemonStore.surfaceId
        self.actorId = daemonStore.actorId
        self.capabilityToken = daemonStore.capabilityToken
        self.client = daemonStore.client
        workspaceStore.client = self.client
        await authority?.ensureDefaultWorkspace()
        subscribeToIR()
        await workspaceStore.loadWorkspaces()
        isInitializing = false
        daemonStatus = "Ready"
    }
    
    func refreshDaemonStatus() async { await daemonStore.refreshDaemonStatus() }
    func getReceipt(hash: String) async throws -> AnigmaClientKit.CoreReceipt? {
        guard let client = client else { return nil }
        return try? await client.query.getReceipt(hash: hash)
    }

    func evaluateAction(intent: ActionIntent) async -> IntentEvaluation? {
        await authority?.evaluateIntent(intent)
    }
    
    func evaluateAction(action: String, parameters: [String: BindingValue]) async -> IntentEvaluation? {
        // Stub: convert action string to intent and evaluate
        // For now, return .allowed to allow actions to proceed
        return .allowed
    }

    func fetchReceipt(hash: String) async { await daemonStore.fetchReceipt(hash: hash) }
    func loadGlobalArtifacts(reset: Bool = false) async { await daemonStore.loadGlobalArtifacts(reset: reset) }
    func refreshDaemonInfo() async { await daemonStore.refreshDaemonInfo() }
    func streamJobEvents(jobId: String) async throws -> AsyncThrowingStream<AnigmaJobEvent, Error> { try await daemonStore.streamJobEvents(jobId: jobId) }
    func verifyReceiptChain(headHash: String) async -> Bool { await daemonStore.verifyReceiptChain(headHash: headHash) }
    
    // MARK: - UI Support
    
    func showToast(title: String, subtitle: String? = nil, icon: String? = nil, actionLabel: String? = nil) {
        let toast = AnigmaToast(id: UUID(), title: title, subtitle: subtitle, icon: icon, actionLabel: actionLabel)
        withAnimation { activeToasts.append(toast) }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4.0))
            withAnimation { self.activeToasts.removeAll { $0.id == toast.id } }
        }
    }
    
    func showError(_ message: String) {
        let toast = AnigmaToast(id: UUID(), title: "⚠️ Error", subtitle: message, icon: "exclamationmark.octagon.fill")
        withAnimation { activeToasts.append(toast) }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(8.0))
            withAnimation { self.activeToasts.removeAll { $0.id == toast.id } }
        }
    }
    
    func logNetworkActivity(domain: String, isAllowed: Bool, reason: String? = nil) {
        let entry = NetworkActivityEntry(domain: domain, timestamp: Date(), isAllowed: isAllowed, reason: reason)
        networkActivityLog.append(entry)
        if networkActivityLog.count > 100 { networkActivityLog.removeFirst() }
    }
    
    // MARK: - Internal Helpers
    
    private func normalizeSelectionForMode() {
        switch mode {
        case .life:
            if ![.compass, .inbox, .atlas, .ask, .projects, .activity].contains(userSurface) { userSurface = .compass }
        case .work:
            if ![.projects, .inbox, .ask, .activity, .data, .documentLibrary].contains(userSurface) { userSurface = .projects }
        case .insight:
            if ![.atlas, .activity, .ask, .data, .observatorium].contains(userSurface) { userSurface = .atlas }
        case .build:
            if ![.studio, .activity, .inbox, .atlas].contains(userSurface) { userSurface = .studio }
        case .develop:
            let developSurfaces: Set<UserSurface> = [.develop, .developFiles, .developSearch, .developChanges, .developRuns, .developReview, .developTasks, .developAgents, .activity, .ask, .projects]
            if !developSurfaces.contains(userSurface) { userSurface = .develop }
        }
    }
    
    private func setSourceConnected(_ sourceType: SourceType, connected: Bool) {
        if let index = sources.firstIndex(where: { $0.type == sourceType }) {
            sources[index].status = connected ? .connected : .paused
            sources[index].isConnected = connected
            return
        }
        guard connected else { return }
        sources.append(AnigmaSource(name: sourceType.rawValue, type: sourceType, path: sourceType.description, depth: .discovery, computePolicy: ComputePolicy(), storagePolicy: StoragePolicy(), isConnected: true, lastIndexed: nil, status: .connected, stats: nil))
    }
    
    private func syncJobStates() {
        let state = AppState.shared
        state.jobStream = jobs.map { job in
            AppState.JobEntry(id: UUID(uuidString: job.id) ?? UUID(), title: job.name, status: mapJobStatus(job.status), progress: nil, source: "System", receiptLink: nil, timestamp: job.createdAt)
        }
        let localRunningCount = localJobs.filter { $0.status == .running || $0.status == .pending }.count
        state.runningJobsCount = jobs.filter { $0.status.uppercased() == "RUNNING" || $0.status.uppercased() == "QUEUED" }.count + localRunningCount
        state.blockedJobsCount = jobs.filter { $0.status.uppercased() == "BLOCKED" }.count
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
    
    private func subscribeToIR() {
        guard let client = client else { return }
        irSubscriptionTask = Task { @MainActor in
            do {
                for try await _ in client.events.events() {
                    if let workspaceId = self.selectedWorkspaceID {
                        await self.refreshJobs(workspaceId: workspaceId)
                    }
                }
            } catch {
                print("Event stream error: \(error)")
            }
        }
    }
    
    private func refreshJobs(workspaceId: WorkspaceID) async {
        guard let client = client else { return }
        if let page = try? await client.query.listJobs(workspaceID: workspaceId, cursor: nil, limit: 50) {
            jobs = page.items
        }
    }

    // MARK: - Caching delegation
    func saveCache() { cacheManager.saveCache() }
    func loadCache() { cacheManager.loadCache() }
    /// Run a pinned action
    func runPinnedAction(_ action: PinnedAction) async {
        await submitJob(action: action.actionName, parameters: [:])
    }

    func savePinnedActions() { cacheManager.savePinnedActions() }
    func saveToUserDefaults(_ data: Data, forKey key: String) throws { try cacheManager.saveToUserDefaults(data, forKey: key) }

    func describeHuggingFaceModel(repo: String, revision: String = "main") async -> HFModelDescriptor? {
        // Placeholder implementation
        return nil
    }

    // MARK: - Internal for Managers
    func updateJob(id: UUID, progress: Double, message: String) {
        if let index = self.localJobs.firstIndex(where: { $0.id == id }) {
            self.localJobs[index].progress = progress
            self.localJobs[index].message = message
        }
    }
}

// MARK: - Computed Properties (Filtered)

extension AppStore {
    var filteredArtifacts: [AnigmaClientKit.ArtifactSummary] {
        if artifactSearchQuery.isEmpty { return artifacts }
        return artifacts.filter { $0.name.localizedCaseInsensitiveContains(artifactSearchQuery) }
    }

    var filteredJobs: [AnigmaClientKit.JobSummary] {
        var result = jobs
        if !jobSearchQuery.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(jobSearchQuery) }
        }
        if jobStatusFilter != .all {
            result = result.filter { $0.status.uppercased() == jobStatusFilter.rawValue }
        }
        if jobTrustFilter != .all {
            result = result.filter { jobTrustFilter == .trusted ? $0.isTrusted : !$0.isTrusted }
        }
        return result
    }

    var inboxCount: Int { artifacts.count }
    var runningJobsCount: Int { jobs.filter { $0.status.uppercased() == "RUNNING" }.count }
    var projectsCount: Int { workspaces.count }
    var insightCount: Int { scopes.count }
}

// MARK: - Service Delegation (Phase 1 Integration)

extension AppStore {
    var surfaceStore: SurfaceStore { serviceIntegrationStore.surfaceStore }
    var outlineStore: OutlineStore { serviceIntegrationStore.outlineStore }
    var searchResults: HarmoniaClient.SearchResponse? { ledgerSearchProjection.response }
    var registeredModels: [ModelRegistryEntry] { serviceIntegrationStore.mlStore.registeredModels }
    var mlWorkerStatus: MLWorkerClient.WorkerStatusResponse? { serviceIntegrationStore.mlStore.mlWorkerStatus }
    var mlWorkerTasks: [MLWorkerClient.TaskStatusResponse] { serviceIntegrationStore.mlStore.mlWorkerTasks }

    var surfaces: [SurfaceInfo] { serviceIntegrationStore.surfaceStore.surfaces }
    var surfaceMetrics: [String: SurfaceMetricsResponse] { serviceIntegrationStore.surfaceStore.surfaceMetrics }
    var outlines: [OutlineResponse] { serviceIntegrationStore.outlineStore.outlines }
    var zineTemplates: [ZineTemplate] { serviceIntegrationStore.outlineStore.zineTemplates }

    // MARK: - Pipeline Management
    var pipelines: [PipelineInfo] { serviceIntegrationStore.pipelineStore.pipelines }
    var pipelineRuns: [PipelineRunResponse] { serviceIntegrationStore.pipelineStore.pipelineRuns }

    func loadPipelines() async { await serviceIntegrationStore.pipelineStore.loadPipelines() }
    func createPipeline(name: String, stages: [AnigmaPrimitives.PipelineStage]) async {
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

    func refreshVaultStatus() async { await serviceIntegrationStore.harmoniaStore.refreshVaultStatus() }
    func verifyVault() async throws -> HarmoniaClient.VaultVerificationResponse { try await serviceIntegrationStore.harmoniaStore.verifyVault() }
    func runVaultGC(dryRun: Bool = false) async throws -> HarmoniaClient.VaultGCResponse { try await serviceIntegrationStore.harmoniaStore.runVaultGC(dryRun: dryRun) }
    func refreshPipelineStatus() async {
        guard let workspace = activeWorkspace else { return }
        await serviceIntegrationStore.harmoniaStore.refreshPipelineStatus(workspace: workspace.id.uuidString)
    }
    func runTechDebtAudit(path: String) async {
        let (response, latency) = await serviceIntegrationStore.harmoniaStore.techDebtAudit(path: path)
        await MainActor.run {
            self.techDebtReport = response
            self.lastAnalysisLatency = latency
        }
    }
    func searchLedger(query: String, limit: Int = 10) async { await serviceIntegrationStore.harmoniaStore.searchLedger(query: query, limit: limit) }
    func startDaemon() async throws { try await serviceIntegrationStore.harmoniaStore.startDaemon() }
    func stopDaemon() async throws { try await serviceIntegrationStore.harmoniaStore.stopDaemon() }
    
    func getDaemonStatus() async -> String {
        do {
            try await serviceIntegrationStore.harmoniaStore.startDaemon()
            return "Running"
        } catch {
            return "Stopped"
        }
    }
    
    func scanDoctrine(path: String, domains: [String]? = nil) async { await serviceIntegrationStore.doctrineStore.scan(path: path, domains: domains) }
    func loadDoctrineStats() async { await serviceIntegrationStore.doctrineStore.loadStats() }
    func loadDoctrineRules(domain: String? = nil) async { await serviceIntegrationStore.doctrineStore.loadRules(domain: domain) }
    func loadDoctrinePacks() async { await serviceIntegrationStore.doctrineStore.loadPacks() }
    func resolveDoctrineViolation(id: String, note: String? = nil) async throws { try await serviceIntegrationStore.doctrineStore.resolveViolation(id: id, note: note) }
    func enableDoctrinePack(id: String) async throws { try await serviceIntegrationStore.doctrineStore.enablePack(id: id) }
    func disableDoctrinePack(id: String) async throws { try await serviceIntegrationStore.doctrineStore.disablePack(id: id) }
    
    func loadRegisteredModels() async { await serviceIntegrationStore.mlStore.loadRegisteredModels() }
    func loadMLWorkerStatus() async { await serviceIntegrationStore.mlStore.loadMLWorkerStatus() }
    func executeGovernedMLRun(
        modelId: String,
        taskKind: MLTaskKind,
        inputs: [ContractsCore.RunSpec.Input],
        backend: String,
        temperature: Double?,
        maxTokens: Int?
    ) async throws -> ContractsCore.ExecutionReceipt {
        guard let mappedBackend = ContractsCore.MLBackend(rawValue: backend.lowercased()) else {
            throw NSError(
                domain: "AppStore",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unsupported backend: \(backend)"]
            )
        }

        return try await serviceIntegrationStore.mlStore.executeGovernedMLRun(
            config: ExecuteGovernedMLRunConfiguration(
                modelId: modelId,
                taskKind: taskKind,
                inputs: inputs,
                backend: mappedBackend,
                temperature: temperature,
                maxTokens: maxTokens
            )
        )
    }
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
    func clearCompletedMLTasks() { serviceIntegrationStore.mlStore.clearCompletedMLTasks() }
    func importHuggingFaceModel(repo: String, revision: String = "main", progressHandler: @escaping (Double) -> Void = { _ in }) async {
        await serviceIntegrationStore.mlStore.importHuggingFaceModel(repo: repo, revision: revision, progressHandler: progressHandler)
    }
    func deleteModel(_ modelId: String) async { await serviceIntegrationStore.mlStore.deleteModel(modelId) }

    func loadSurfaces() async { await serviceIntegrationStore.surfaceStore.loadSurfaces() }
    func createSurface(name: String, type: SurfaceType, config: SurfaceConfig) async {
        await serviceIntegrationStore.surfaceStore.createSurface(name: name, type: type, config: config)
    }
    func updateSurface(id: String, config: SurfaceConfig) async {
        await serviceIntegrationStore.surfaceStore.updateSurface(id: id, config: config)
    }
    func deleteSurface(id: String) async { await serviceIntegrationStore.surfaceStore.deleteSurface(id: id) }
    func renderToSurface(surfaceId: String, content: RenderContent) async {
        await serviceIntegrationStore.surfaceStore.renderToSurface(surfaceId: surfaceId, content: content)
    }
    func exportSurface(surfaceId: String, format: SurfaceExportFormat, outputPath: String) async {
        await serviceIntegrationStore.surfaceStore.exportSurface(surfaceId: surfaceId, format: format, outputPath: outputPath)
    }
    func loadSurfaceMetrics(surfaceId: String) async {
        await serviceIntegrationStore.surfaceStore.loadSurfaceMetrics(surfaceId: surfaceId)
    }

    func generateOutline(content: String, depth: Int = 3) async {
        await serviceIntegrationStore.outlineStore.generateOutline(content: content, depth: depth)
    }
    func analyzeStructure(filePath: String) async {
        await serviceIntegrationStore.outlineStore.analyzeStructure(filePath: filePath)
    }
    func createZine(outline: OutlineStructure, template: String? = nil) async {
        await serviceIntegrationStore.outlineStore.createZine(outline: outline, template: template)
    }
    func exportZine(zineId: String, format: ZineExportFormat, outputPath: String) async {
        await serviceIntegrationStore.outlineStore.exportZine(zineId: zineId, format: format, outputPath: outputPath)
    }
    func loadZineTemplates() async { await serviceIntegrationStore.outlineStore.loadTemplates() }
    
    // MARK: - Tool Registration
    
    /// Register a new tool in the tool registry
    func registerTool(_ tool: AnigmaTool) {
        // TODO: Implement tool registration persistence
        if !tools.contains(where: { $0.id == tool.id }) {
            tools.append(tool)
            showToast(title: "Tool Registered", subtitle: "\(tool.name) has been added to your toolbox.", icon: "checkmark.circle")
        }
    }
    
    // MARK: - Google OAuth (Stub Implementation)
    
    /// Check if Google account is linked
    var isGoogleLinked: Bool {
        // TODO: Implement persistent Google OAuth token storage
        UserDefaults.standard.string(forKey: "google_oauth_token") != nil
    }
    
    /// Get configured Google OAuth Client ID
    var googleOAuthClientId: String {
        // TODO: Load from secure configuration
        UserDefaults.standard.string(forKey: "google_oauth_client_id") ?? ""
    }
    
    /// Get Google OAuth redirect URI
    func googleRedirectURI() -> String {
        // TODO: Configure based on deployment environment
        "com.anigma.app://oauth-callback"
    }
    
    /// Refresh Google OAuth token if needed
    func refreshGoogleOAuthTokenIfNeeded() async {
        // TODO: Implement token refresh logic with Google OAuth API
        // For now, this is a no-op stub
    }
    
    /// Store Google OAuth token securely
    func storeGoogleOAuthToken(_ token: String) {
        // TODO: Store securely in Keychain
        UserDefaults.standard.set(token, forKey: "google_oauth_token")
    }
}
