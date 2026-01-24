//
//  ServiceIntegrationStore.swift
//  AnigmaAppMac
//
//  Consolidates all service-specific stores (ML, Pipeline, Doctrine, Harmonia, Accessum, Surface, AST, Outline).
//  Extracted from AppStore for focused responsibility and testability.
//

import Foundation
import Observation
import AnigmaHostMac
import AnigmaSidecar

@MainActor
@Observable
final class ServiceIntegrationStore {
    
    // MARK: - Service Stores
    
    /// ML Store: model registry, inference operations, HuggingFace integration
    let mlStore: MLStore
    
    /// Pipeline Store: data processing pipelines
    let pipelineStore: PipelineStore
    
    /// Doctrine Store: rule checking and violation management
    let doctrineStore: DoctrineStore
    
    /// Harmonia Store: vault, tech debt, ledger operations
    let harmoniaStore: HarmoniaStore
    
    /// Accessum Flow Store: access control and permissions
    let accessumFlowStore: AccessumFlowStore
    
    /// Surface Store: UI surfaces and rendering
    let surfaceStore: SurfaceStore
    
    /// AST Services Store: code analysis and refactoring
    let astServicesStore: ASTServicesStore
    
    /// Outline Store: document generation and zine creation
    let outlineStore: OutlineStore
    
    // MARK: - Dependencies (Injected)
    
    /// Callback for showing toast notifications
    var showToast: ((String, String?, String?) -> Void)?
    
    /// Callback for showing error notifications
    var showError: ((String) -> Void)?
    
    /// Callback for logging network activity
    var logNetworkActivity: ((String, String, String, String) -> Void)?
    
    // MARK: - Initialization
    
    init(
        daemonCapability: DaemonHostCapability,
        daemonStore: DaemonStore
    ) {
        // Initialize MLStore with daemonStore
        self.mlStore = MLStore(daemonStore: daemonStore)
        
        // Initialize PipelineStore with dependencies
        let pipelineClient = PipelineClient()
        self.pipelineStore = PipelineStore(pipelineClient: pipelineClient)
        
        // Initialize DoctrineStore with dependencies
        let doctrineClient = DoctrineClient()
        self.doctrineStore = DoctrineStore(doctrineClient: doctrineClient)
        
        // Initialize HarmoniaStore with dependencies
        self.harmoniaStore = HarmoniaStore(harmoniaClient: daemonCapability.harmonia)
        
        // Initialize AccessumFlowStore with dependencies
        let accessumFlowClient = AccessumFlowClient()
        self.accessumFlowStore = AccessumFlowStore(accessumFlowClient: accessumFlowClient)
        
        // Initialize SurfaceStore with dependencies
        let surfaceClient = SurfaceClient()
        self.surfaceStore = SurfaceStore(surfaceClient: surfaceClient)
        
        // Initialize ASTServicesStore with dependencies
        let astServicesClient = ASTServicesClient()
        self.astServicesStore = ASTServicesStore(astServicesClient: astServicesClient)
        
        // Initialize OutlineStore with dependencies
        let outlineClient = OutlineClient()
        self.outlineStore = OutlineStore(outlineClient: outlineClient)
    }
    
    // MARK: - Configuration
    
    /// Configures all callbacks for UI operations across all service stores.
    func configureCallbacks() {
        // Configure MLStore callbacks
        mlStore.showToast = { [weak self] title, subtitle, icon in
            self?.showToast?(title, subtitle, icon)
        }
        mlStore.showError = { [weak self] message in
            self?.showError?(message)
        }
        mlStore.logNetworkActivity = { [weak self] event, domain, purpose, classification in
            self?.logNetworkActivity?(event, domain, purpose, classification)
        }
        
        // Configure PipelineStore callbacks
        pipelineStore.showToast = { [weak self] title, subtitle, icon in
            self?.showToast?(title, subtitle, icon)
        }
        pipelineStore.showError = { [weak self] message in
            self?.showError?(message)
        }
        
        // Configure DoctrineStore callbacks
        doctrineStore.showToast = { [weak self] title, subtitle, icon in
            self?.showToast?(title, subtitle, icon)
        }
        doctrineStore.showError = { [weak self] message in
            self?.showError?(message)
        }
        
        // Configure HarmoniaStore callbacks
        harmoniaStore.showToast = { [weak self] title, subtitle, icon in
            self?.showToast?(title, subtitle, icon)
        }
        harmoniaStore.showError = { [weak self] message in
            self?.showError?(message)
        }
        
        // Configure AccessumFlowStore callbacks
        accessumFlowStore.showToast = { [weak self] title, subtitle, icon in
            self?.showToast?(title, subtitle, icon)
        }
        accessumFlowStore.showError = { [weak self] message in
            self?.showError?(message)
        }
        
        // Configure SurfaceStore callbacks
        surfaceStore.showToast = { [weak self] title, subtitle, icon in
            self?.showToast?(title, subtitle, icon)
        }
        surfaceStore.showError = { [weak self] message in
            self?.showError?(message)
        }
        
        // Configure ASTServicesStore callbacks
        astServicesStore.showToast = { [weak self] title, subtitle, icon in
            self?.showToast?(title, subtitle, icon)
        }
        astServicesStore.showError = { [weak self] message in
            self?.showError?(message)
        }
        
        // Configure OutlineStore callbacks
        outlineStore.showToast = { [weak self] title, subtitle, icon in
            self?.showToast?(title, subtitle, icon)
        }
        outlineStore.showError = { [weak self] message in
            self?.showError?(message)
        }
    }
}
