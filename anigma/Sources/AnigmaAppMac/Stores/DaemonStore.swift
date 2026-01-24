//
//  DaemonStore.swift
//  AnigmaAppMac
//
//  Manages daemon connection, bridge, circuit breakers, and job monitoring.
//  Extracted from AppStore for focused responsibility and testability.
//

import Foundation
import Observation
import AnigmaClientKit
import AnigmaSidecar
import AnigmaHostMac
import AnigmaPrimitives

@MainActor
@Observable
final class DaemonStore {
    
    // MARK: - Daemon Connection Properties
    
    /// Daemon bridge for communication with anigmad
    var daemonBridge: SidecarBridge?
    
    /// Daemon host capability for lifecycle management
    let daemonCapability: DaemonHostCapability
    
    /// Connection monitor for daemon health
    private var connectionMonitor: ConnectionMonitor?
    
    /// Circuit breaker for daemon communication
    private let daemonCircuitBreaker: CircuitBreaker
    
    /// Circuit breaker for ML worker communication
    private let mlWorkerCircuitBreaker: CircuitBreaker
    
    /// Daemon status message for UI display
    var daemonStatus: String = "Starting..."
    
    /// Detailed daemon status response
    var daemonDetailedStatus: AnigmaStatusResponse?
    
    /// Selected receipt JSON for debugging/audit
    var selectedReceiptJson: String?
    
    /// Daemon connection status (computed)
    var isDaemonConnected: Bool { daemonBridge != nil }
    
    // MARK: - Authority & Client Properties
    
    /// Anigma authority for surface registration
    var authority: AnigmaAuthority?
    
    /// Anigma client for workspace operations
    var client: MacAnigmaClient?
    
    /// Surface ID for this app instance
    private(set) var surfaceId: SurfaceId?
    
    /// Actor ID for this app instance
    private(set) var actorId: ActorId?
    
    /// Capability token for authorization
    var capabilityToken: ContractsCore.CapabilityToken?
    
    // MARK: - Global Ledger Data
    
    /// Global artifacts from daemon (not workspace-specific)
    var globalArtifacts: [AnigmaArtifactRef] = []
    
    /// Cursor for paginating global artifacts
    var globalArtifactsCursor: String?
    
    // MARK: - Dependencies (Injected)
    
    /// Callback for showing toast notifications
    var showToast: ((String, String?, String?) -> Void)?
    
    /// Callback for showing error notifications
    var showError: ((String) -> Void)?
    
    /// Callback for logging network activity
    var logNetworkActivity: ((String, String, String, String) -> Void)?
    
    /// Callback for syncing job states with UI
    var syncJobStates: (() -> Void)?
    
    // MARK: - Initialization
    
    init(daemonCapability: DaemonHostCapability) {
        self.daemonCapability = daemonCapability
        
        // Initialize circuit breakers for backend services
        self.daemonCircuitBreaker = CircuitBreaker(
            serviceName: "AnigmaDaemon",
            failureThreshold: 5,
            successThreshold: 2,
            timeout: 30.0
        )
        self.mlWorkerCircuitBreaker = CircuitBreaker(
            serviceName: "MLWorker",
            failureThreshold: 3,
            successThreshold: 2,
            timeout: 20.0
        )
    }
    
    // MARK: - Daemon Lifecycle
    
    /// Initializes the Authority and starts the daemon if needed.
    func initializeDaemon() async {
        do {
            // Step 1: Ensure daemon is running (via host capability)
            daemonStatus = "Checking daemon..."
            let status = try await withRetry {
                try await self.daemonCapability.ensureDaemonRunning()
            }
            daemonStatus = "Daemon: \(status.description)"
            
            // Step 2: Establish Sidecar Bridge
            if status == .running || status == .alreadyRunning || status == .started {
                daemonStatus = "Connecting Bridge..."
                self.daemonBridge = try await SidecarBridge.create(
                    clientName: "AnigmaAppMac",
                    scopes: ["Anigma.All"]
                )
                
                // Verify connection
                if let bridge = self.daemonBridge {
                    let healthy = try await bridge.healthCheck()
                    if healthy {
                        print("✅ Sidecar Bridge Connected & Healthy")
                    } else {
                        print("⚠️ Sidecar Bridge Connected but Unhealthy")
                    }
                }
            }
            
            // Step 3: Create Authority
            daemonStatus = "Connecting to Authority..."
            authority = try await withRetry {
                try await AnigmaAuthority.create()
            }
            
            // Step 4: Register surface
            guard let authority = authority else {
                throw DaemonStoreError.authorityNotInitialized
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
            
            daemonStatus = "Ready"
            
        } catch {
            daemonStatus = "Error: \(error.localizedDescription)"
            showError?("Failed to initialize daemon: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Job Submission & Monitoring
    
    /// Submits a job to the daemon and monitors its progress.
    func dispatchJob(_ spec: AnigmaJobSpec) async throws -> AnigmaSubmitJobResponse {
        // Wrap daemon communication in circuit breaker
        return try await daemonCircuitBreaker.execute { @MainActor in
            guard let bridge = self.daemonBridge else {
                // Attempt daemon reconnection with proper error handling
                do {
                    try await self.daemonCapability.ensureDaemonRunning()
                } catch {
                    throw DaemonStoreError.daemonStartFailed(
                        underlying: error,
                        suggestion: "Please check daemon logs or restart manually in Settings → Daemon"
                    )
                }
                
                // Try to establish bridge connection
                do {
                    self.daemonBridge = try await SidecarBridge.create(
                        clientName: "AnigmaAppMac",
                        scopes: ["Anigma.All"]
                    )
                } catch {
                    throw DaemonStoreError.connectionFailed(
                        underlying: error,
                        suggestion: "Daemon is running but bridge connection failed. Check network/firewall settings."
                    )
                }
                
                if let bridge = self.daemonBridge {
                    let result = try await bridge.submitJob(spec)
                    return result
                }
                throw DaemonStoreError.notConnected
            }
            let result = try await bridge.submitJob(spec)
            return result
        }
    }
    

    
    // MARK: - Daemon Status & Info
    
    /// Refreshes detailed daemon status.
    func refreshDaemonStatus() async {
        guard let bridge = daemonBridge else { return }
        do {
            self.daemonDetailedStatus = try await bridge.getStatus()
        } catch {
            print("Failed to fetch detailed daemon status: \(error)")
        }
    }
    
    /// Loads global artifacts from daemon.
    func loadGlobalArtifacts(reset: Bool = false) async {
        guard let bridge = daemonBridge else { return }
        if reset {
            globalArtifacts = []
            globalArtifactsCursor = nil
        }
        
        do {
            let response = try await bridge.listArtifacts(pageToken: globalArtifactsCursor ?? "", pageSize: 50)
            globalArtifacts.append(contentsOf: response.artifacts)
            globalArtifactsCursor = response.nextPageToken.isEmpty ? nil : response.nextPageToken
        } catch {
            showError?("Failed to load global artifacts: \(error.localizedDescription)")
        }
    }
    
    /// Refreshes all daemon information.
    func refreshDaemonInfo() async {
        await refreshDaemonStatus()
    }
    
    // MARK: - Job Operations
    
    /// Streams events for a submitted job.
    func streamJobEvents(jobId: String) async throws -> AsyncThrowingStream<AnigmaJobEvent, Error> {
        guard let bridge = daemonBridge else {
            throw DaemonStoreError.notConnected
        }
        return await bridge.streamJobEvents(jobId: jobId)
    }
    
    /// Cancels a running job.
    func cancelJob(jobId: String) async throws -> AnigmaCancelJobResponse {
        guard let bridge = daemonBridge else {
            throw DaemonStoreError.notConnected
        }
        return try await bridge.cancelJob(jobId: jobId)
    }
    
    /// Verifies the integrity of a receipt chain.
    func verifyReceiptChain(headHash: String) async -> Bool {
        guard let bridge = daemonBridge else { return false }
        do {
            let response = try await bridge.verifyChain(headReceiptHash: headHash)
            if response.ok {
                showToast?("Audit Verified", "Chain integrity confirmed.", "checkmark.shield.fill")
                return true
            } else {
                showToast?("Verification Failed", response.message, "exclamationmark.shield.fill")
                return false
            }
        } catch {
            showError?("Audit Error: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Fetches raw receipt JSON for debugging/audit.
    func fetchReceipt(hash: String) async {
        guard let bridge = daemonBridge else { return }
        do {
            let response = try await bridge.getReceipt(receiptHash: hash)
            self.selectedReceiptJson = response.receiptCanonicalJson
        } catch {
            showError?("Failed to fetch receipt: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Error Types
    
    enum DaemonStoreError: LocalizedError {
        case notConnected
        case authorityNotInitialized
        case daemonStartFailed(underlying: Error, suggestion: String)
        case connectionFailed(underlying: Error, suggestion: String)
        
        var errorDescription: String? {
            switch self {
            case .notConnected:
                return "Not connected to daemon. Please ensure the daemon is running."
            case .authorityNotInitialized:
                return "Authority not initialized. Daemon connection may have failed."
            case .daemonStartFailed(let error, let suggestion):
                return "Failed to start daemon: \(error.localizedDescription)\n\(suggestion)"
            case .connectionFailed(let error, let suggestion):
                return "Failed to connect to daemon: \(error.localizedDescription)\n\(suggestion)"
            }
        }
    }
}