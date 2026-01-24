//
//  AppStore.swift
//  AnigmaAppMac
//
//   Bauhaus Architecture - God object refactored into focused managers.
//

import AnigmaClientKit
import AnigmaSystemSpine
import ExportCore
import AnigmaWork
import DataEngine
import ContractsCore
import AnigmaPrimitives
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
    let intakeManager: IntakeManager
    let contextManager: ContextManager
    let jobManager: JobManager
    let developManager: DevelopManager
    let cacheManager: CacheManager
    
    // MARK: - Sub-stores
    let serviceIntegrationStore: ServiceIntegrationStore
    let sourceConnectionStore: SourceConnectionStore
    let workspaceStore: WorkspaceStore
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
    var inspectorSelection: AnigmaClientKit.InspectorSelection?
    private(set) var isInitializing: Bool = true
    private(set) var initializationError: String?
    var isOnline: Bool = true
    var activeToasts: [AnigmaToast] = []
    var isJobCenterPresented: Bool = false
    var isAIConsolePresented: Bool = false
    var focusOmniBar: Bool = false
    var triggerQuickLook: Bool = false
    
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
    var artifactSearchQuery: String = ""
    var sidecarError: String?
    var jobSearchQuery: String = ""
    var jobStatusFilter: JobStatusFilter = .all
    var jobTrustFilter: JobTrustFilter = .all
    var actionCatalog: [ActionDefinition] = []
    var hosts: [DaemonHost] = []
    var pinnedActions: [PinnedAction] = []
    
    // MARK: - Harmonia Background Services
    public private(set) var harmoniaBackgroundSync: HarmoniaBackgroundSync?
    public private(set) var harmoniaCommandHistory: HarmoniaCommandHistory?

    // MARK: - Initialization
    
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
        self.harmoniaCommandHistory = HarmoniaCommandHistory()
        
        self.daemonStore = DaemonStore(daemonCapability: daemonCapability)
        self.serviceIntegrationStore = ServiceIntegrationStore(
            daemonCapability: daemonCapability,
            daemonStore: daemonStore
        )
        self.sourceConnectionStore = SourceConnectionStore()
        self.workspaceStore = WorkspaceStore()
        
        // Initialize Managers
        self.intakeManager = IntakeManager(store: self)
        self.contextManager = ContextManager(store: self)
        self.jobManager = JobManager(store: self)
        self.developManager = DevelopManager(store: self)
        self.cacheManager = CacheManager(store: self)
        
        self.connectionMonitor = ConnectionMonitor(capability: daemonCapability)
        
        setupCallbacks()
        loadCache()
        loadHosts()
    }
    
    private func setupCallbacks() {
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
        daemonStore.selectedReceiptJson
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
        self.monitorDaemonJob(daemonId: result.jobID, title: spec.kind)
        return result
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
    
    func downloadArtifact(id: ArtifactID) async -> Data? {
        guard let client = client else { return nil }
        return try? await client.query.downloadArtifact(id: id)
    }
    
    func deleteArtifact(id: ArtifactID) async {
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
        do {
            isInitializing = true
            connectionMonitor?.start()
            try await daemonStore.initializeDaemon()
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
        } catch {
            isInitializing = false
            initializationError = error.localizedDescription
            daemonStatus = "Error: \(error.localizedDescription)"
        }
    }
    
    func refreshDaemonStatus() async { await daemonStore.refreshDaemonStatus() }
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
            if ![.projects, .inbox, .ask, .activity, .data].contains(userSurface) { userSurface = .projects }
        case .insight:
            if ![.atlas, .activity, .ask, .data].contains(userSurface) { userSurface = .atlas }
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
    func savePinnedActions() { cacheManager.savePinnedActions() }
    func saveToUserDefaults(_ data: Data, forKey key: String) throws { try cacheManager.saveToUserDefaults(data, forKey: key) }

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
            result = result.filter { jobTrustFilter == .verified ? $0.isTrusted : !$0.isTrusted }
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
    func refreshVaultStatus() async { await serviceIntegrationStore.harmoniaStore.refreshVaultStatus() }
    func verifyVault() async throws -> HarmoniaClient.VaultVerificationResponse { try await serviceIntegrationStore.harmoniaStore.verifyVault() }
    func runVaultGC(dryRun: Bool = false) async throws -> HarmoniaClient.VaultGCResponse { try await serviceIntegrationStore.harmoniaStore.runVaultGC(dryRun: dryRun) }
    func refreshPipelineStatus() async {
        guard let workspace = activeWorkspace else { return }
        await serviceIntegrationStore.harmoniaStore.refreshPipelineStatus(workspace: workspace.id.uuidString)
    }
    func runTechDebtAudit(path: String) async { await serviceIntegrationStore.harmoniaStore.runTechDebtAudit(path: path) }
    func searchLedger(query: String, limit: Int = 10) async { await serviceIntegrationStore.harmoniaStore.searchLedger(query: query, limit: limit) }
    func startDaemon() async throws { try await serviceIntegrationStore.harmoniaStore.startDaemon() }
    func stopDaemon() async throws { try await serviceIntegrationStore.harmoniaStore.stopDaemon() }
    
    func scanDoctrine(path: String, domains: [String]? = nil) async { await serviceIntegrationStore.doctrineStore.scan(path: path, domains: domains) }
    func loadDoctrineStats() async { await serviceIntegrationStore.doctrineStore.loadStats() }
    func loadDoctrineRules(domain: String? = nil) async { await serviceIntegrationStore.doctrineStore.loadRules(domain: domain) }
    func loadDoctrinePacks() async { await serviceIntegrationStore.doctrineStore.loadPacks() }
    func resolveDoctrineViolation(id: String, note: String? = nil) async throws { try await serviceIntegrationStore.doctrineStore.resolveViolation(id: id, note: note) }
    func enableDoctrinePack(id: String) async throws { try await serviceIntegrationStore.doctrineStore.enablePack(id: id) }
    func disableDoctrinePack(id: String) async throws { try await serviceIntegrationStore.doctrineStore.disablePack(id: id) }
    
    func loadRegisteredModels() async { await serviceIntegrationStore.mlStore.loadRegisteredModels() }
    func importHuggingFaceModel(repo: String, revision: String = "main", progressHandler: @escaping (Double) -> Void = { _ in }) async {
        await serviceIntegrationStore.mlStore.importHuggingFaceModel(repo: repo, revision: revision, progressHandler: progressHandler)
    }
    func deleteModel(_ modelId: String) async { await serviceIntegrationStore.mlStore.deleteModel(modelId) }
}
