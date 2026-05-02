// ModelRegistry+Events.swift
// Event-driven extensions for ModelRegistry
// Provides event publishing for model loading, activation, and management

import Foundation
import AnigmaEvents

// MARK: - Model Registry Event Extensions

public extension ModelRegistry {
    /// Load model with event publishing
    func loadModelWithEvents(
        identifier: String,
        configuration: ModelConfiguration,
        eventBus: EventBus = .shared
    ) async throws -> ModelHandle {
        // Publish model loading started event
        eventBus.publish(
            ModelRegistryEvent.loadingStarted(
                modelId: identifier,
                modelType: configuration.modelType.rawValue
            )
        )
        
        do {
            let handle = try await self.loadModel(identifier: identifier, configuration: configuration)
            
            // Publish model loading completed event
            eventBus.publish(
                ModelRegistryEvent.loadingCompleted(
                    modelId: identifier,
                    modelType: configuration.modelType.rawValue,
                    handle: handle
                )
            )
            
            return handle
        } catch {
            // Publish model loading failed event
            eventBus.publish(
                ModelRegistryEvent.loadingFailed(
                    modelId: identifier,
                    modelType: configuration.modelType.rawValue,
                    error: error.localizedDescription
                )
            )
            throw error
        }
    }
    
    /// Activate model with event publishing
    func activateModelWithEvents(
        handle: ModelHandle,
        eventBus: EventBus = .shared
    ) async throws {
        // Publish model activation started event
        eventBus.publish(
            ModelRegistryEvent.activationStarted(
                modelHandle: handle.identifier
            )
        )
        
        do {
            try await self.activateModel(handle: handle)
            
            // Publish model activation completed event
            eventBus.publish(
                ModelRegistryEvent.activationCompleted(
                    modelHandle: handle.identifier
                )
            )
        } catch {
            // Publish model activation failed event
            eventBus.publish(
                ModelRegistryEvent.activationFailed(
                    modelHandle: handle.identifier,
                    error: error.localizedDescription
                )
            )
            throw error
        }
    }
    
    /// Deactivate model with event publishing
    func deactivateModelWithEvents(
        handle: ModelHandle,
        eventBus: EventBus = .shared
    ) async throws {
        // Publish model deactivation started event
        eventBus.publish(
            ModelRegistryEvent.deactivationStarted(
                modelHandle: handle.identifier
            )
        )
        
        do {
            try await self.deactivateModel(handle: handle)
            
            // Publish model deactivation completed event
            eventBus.publish(
                ModelRegistryEvent.deactivationCompleted(
                    modelHandle: handle.identifier
                )
            )
        } catch {
            // Publish model deactivation failed event
            eventBus.publish(
                ModelRegistryEvent.deactivationFailed(
                    modelHandle: handle.identifier,
                    error: error.localizedDescription
                )
            )
            throw error
        }
    }
    
    /// Unload model with event publishing
    func unloadModelWithEvents(
        handle: ModelHandle,
        eventBus: EventBus = .shared
    ) async throws {
        // Publish model unloading started event
        eventBus.publish(
            ModelRegistryEvent.unloadingStarted(
                modelHandle: handle.identifier
            )
        )
        
        do {
            try await self.unloadModel(handle: handle)
            
            // Publish model unloading completed event
            eventBus.publish(
                ModelRegistryEvent.unloadingCompleted(
                    modelHandle: handle.identifier
                )
            )
        } catch {
            // Publish model unloading failed event
            eventBus.publish(
                ModelRegistryEvent.unloadingFailed(
                    modelHandle: handle.identifier,
                    error: error.localizedDescription
                )
            )
            throw error
        }
    }
}

// MARK: - Model Registry Manager with Event Subscriptions

/// Model registry manager that subscribes to model-related events
public class ModelRegistryManager {
    private let eventBus: EventBus
    private var eventSubscriptionIds: [String] = []
    private let registry: ModelRegistry
    private var activeModels: [String: ModelHandle] = [:]
    
    public init(registry: ModelRegistry, eventBus: EventBus = .shared) {
        self.registry = registry
        self.eventBus = eventBus
        setupEventSubscriptions()
    }
    
    deinit {
        cleanupEventSubscriptions()
    }
    
    private func setupEventSubscriptions() {
        // Subscribe to model loading request events
        let loadingRequestSubscription = eventBus.subscribe(
            to: ModelLoadingRequestEvent.self
        ) { [weak self] event in
            await self?.handleModelLoadingRequest(event: event)
        }
        eventSubscriptionIds.append(loadingRequestSubscription.id)
        
        // Subscribe to work item events for model operations
        let workItemSubscription = eventBus.subscribe(
            to: WorkItemEvent.self
        ) { [weak self] event in
            await self?.handleWorkItemEvent(event: event)
        }
        eventSubscriptionIds.append(workItemSubscription.id)
    }
    
    private func cleanupEventSubscriptions() {
        for subscriptionId in eventSubscriptionIds {
            eventBus.unsubscribe(id: subscriptionId)
        }
        eventSubscriptionIds.removeAll()
    }
    
    /// Get active model by identifier
    public func getActiveModel(identifier: String) -> ModelHandle? {
        return activeModels[identifier]
    }
    
    /// Get all active models
    public func getAllActiveModels() -> [String: ModelHandle] {
        return activeModels
    }
    
    /// Handle model loading requests
    private func handleModelLoadingRequest(event: ModelLoadingRequestEvent) async {
        switch event {
        case .load(let request):
            // Load the requested model
            do {
                let handle = try await registry.loadModelWithEvents(
                    identifier: request.modelId,
                    configuration: request.configuration
                )
                
                // Track active model
                activeModels[request.modelId] = handle
                
                // Activate the model if requested
                if request.activateAfterLoad {
                    try await registry.activateModelWithEvents(handle: handle)
                }
                
            } catch {
                eventBus.publish(
                    ModelRegistryEvent.notification(
                        message: "Failed to load model " + request.modelId + ": " + error.localizedDescription
                    )
                )
            }
            
        case .unload(let modelId):
            // Unload the specified model
            if let handle = activeModels[modelId] {
                do {
                    try await registry.deactivateModelWithEvents(handle: handle)
                    try await registry.unloadModelWithEvents(handle: handle)
                    activeModels.removeValue(forKey: modelId)
                } catch {
                    eventBus.publish(
                        ModelRegistryEvent.notification(
                            message: "Failed to unload model " + modelId + ": " + error.localizedDescription
                        )
                    )
                }
            }
        }
    }
    
    /// Handle work item events
    private func handleWorkItemEvent(event: WorkItemEvent) async {
        switch event {
        case .created(let workItem):
            if workItem.type == .modelOperation {
                // Process model operation work item
                if let modelRequest = workItem.payload as? ModelLoadingRequest {
                    // Handle based on work item type
                    eventBus.publish(
                        ModelLoadingRequestEvent.load(modelRequest)
                    )
                }
            }
        case .started, .progress, .completed, .failed:
            // Forward work item events as model registry events
            eventBus.publish(
                ModelRegistryEvent.notification(
                    message: "Work item event: " + event.description
                )
            )
        }
    }
}

// MARK: - Model Loading Request Models

/// Model loading request
public struct ModelLoadingRequest: Sendable, Codable {
    public let modelId: String
    public let configuration: ModelConfiguration
    public let activateAfterLoad: Bool
    public let priority: ModelLoadingPriority
    
    public init(
        modelId: String,
        configuration: ModelConfiguration = ModelConfiguration(),
        activateAfterLoad: Bool = true,
        priority: ModelLoadingPriority = .normal
    ) {
        self.modelId = modelId
        self.configuration = configuration
        self.activateAfterLoad = activateAfterLoad
        self.priority = priority
    }
}

/// Model loading priority
public enum ModelLoadingPriority: String, Sendable, Codable {
    case low
    case normal
    case high
    case critical
}

// MARK: - Convenience Methods

public extension ModelRegistryManager {
    /// Create a model loading work item
    func createModelLoadingWorkItem(
        modelId: String,
        configuration: ModelConfiguration = ModelConfiguration(),
        activateAfterLoad: Bool = true,
        priority: WorkItemPriority = .normal,
        metadata: [String: String] = [:]
    ) -> WorkItem {
        let request = ModelLoadingRequest(
            modelId: modelId,
            configuration: configuration,
            activateAfterLoad: activateAfterLoad,
            priority: .normal
        )
        
        return WorkItem(
            id: UUID().uuidString,
            type: .modelOperation,
            payload: request,
            priority: priority,
            metadata: metadata
        )
    }
    
    /// Request model loading through the event bus
    func requestModelLoading(
        modelId: String,
        configuration: ModelConfiguration = ModelConfiguration(),
        activateAfterLoad: Bool = true
    ) {
        let request = ModelLoadingRequest(
            modelId: modelId,
            configuration: configuration,
            activateAfterLoad: activateAfterLoad
        )
        
        eventBus.publish(
            ModelLoadingRequestEvent.load(request)
        )
    }
    
    /// Request model unloading through the event bus
    func requestModelUnloading(modelId: String) {
        eventBus.publish(
            ModelLoadingRequestEvent.unload(modelId)
        )
    }
}

// MARK: - Event Subscription Convenience Methods

public extension ModelRegistryManager {
    /// Subscribe to model registry events
    func subscribeToModelRegistryEvents(handler: @escaping (ModelRegistryEvent) async -> Void) -> EventSubscription {
        return eventBus.subscribe(to: ModelRegistryEvent.self, handler: handler)
    }
    
    /// Subscribe to model loading request events
    func subscribeToModelLoadingRequests(handler: @escaping (ModelLoadingRequestEvent) async -> Void) -> EventSubscription {
        return eventBus.subscribe(to: ModelLoadingRequestEvent.self, handler: handler)
    }
    
    /// Subscribe to work item events
    func subscribeToWorkItemEvents(handler: @escaping (WorkItemEvent) async -> Void) -> EventSubscription {
        return eventBus.subscribe(to: WorkItemEvent.self, handler: handler)
    }
}
