// DataEngine+Events.swift
// Event-driven extensions for DataEngine

import AnigmaEvents
import Foundation
import DataCore

public extension DataEngine {
    // MARK: - Event-Driven Data Processing

    /// Event-driven ingestion that publishes processing events
    /// - Parameters:
    ///   - source: URL to ingest
    ///   - options: Ingestion options
    /// - Returns: Created artifact
    /// - Throws: Errors during ingestion
    func ingestWithEvents(source: URL, options: IngestionOptions = IngestionOptions()) async throws -> Artifact {
        let processingId = UUID().uuidString
        let startTime = Date()
        
        // Publish started event
        await sharedEventBus.publish(
            DataProcessingStartedEvent(
                processingId: processingId,
                dataSourceId: source.lastPathComponent,
                dataType: "url",
                initiatedBy: "DataEngine.ingest",
                metadata: [
                    "source": source.absoluteString,
                    "options": "default",
                    "processingType": "ingestion"
                ]
            ),
            source: "DataEngine"
        )
        
        // Publish progress event (starting)
        await sharedEventBus.publish(
            DataProcessingProgressEvent(
                processingId: processingId,
                progress: 0.0,
                processedItems: 0,
                totalItems: 1,
                message: "Starting ingestion from \(source.lastPathComponent)",
                stage: "ingestion_init"
            ),
            source: "DataEngine"
        )
        
        do {
            // Perform actual ingestion
            let artifact = try await ingest(source: source, options: options)
            
            // Publish progress event (completed)
            await sharedEventBus.publish(
                DataProcessingProgressEvent(
                    processingId: processingId,
                    progress: 1.0,
                    processedItems: 1,
                    totalItems: 1,
                    message: "Ingestion completed successfully",
                    stage: "ingestion_complete"
                ),
                source: "DataEngine"
            )
            
            let duration = Date().timeIntervalSince(startTime)
            
            // Publish completion event
            await sharedEventBus.publish(
                DataProcessingCompletedEvent(
                    processingId: processingId,
                    result: artifact.id,
                    duration: duration,
                    success: true,
                    processedItems: 1
                ),
                source: "DataEngine"
            )
            
            return artifact
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            
            // Publish failure event
            await sharedEventBus.publish(
                DataProcessingFailedEvent(
                    processingId: processingId,
                    error: error,
                    processedItems: 0,
                    stackTrace: "Ingestion failed: \(error.localizedDescription)"
                ),
                source: "DataEngine"
            )
            
            throw error
        }
    }
    
    /// Event-driven profiling that publishes processing events
    /// - Parameter artifact: Artifact to profile
    /// - Returns: Profile artifact
    /// - Throws: Errors during profiling
    func profileWithEvents(artifact: Artifact) async throws -> ProfileArtifact {
        let processingId = UUID().uuidString
        let startTime = Date()
        
        // Publish started event
        await sharedEventBus.publish(
            DataProcessingStartedEvent(
                processingId: processingId,
                dataSourceId: artifact.id,
                dataType: "artifact",
                initiatedBy: "DataEngine.profile",
                metadata: [
                    "artifactId": artifact.id,
                    "artifactType": artifact.type.rawValue,
                    "processingType": "profiling"
                ]
            ),
            source: "DataEngine"
        )
        
        // Publish progress event (starting)
        await sharedEventBus.publish(
            DataProcessingProgressEvent(
                processingId: processingId,
                progress: 0.0,
                processedItems: 0,
                totalItems: 1,
                message: "Starting profiling of artifact \(artifact.id)",
                stage: "profiling_init"
            ),
            source: "DataEngine"
        )
        
        do {
            // Perform actual profiling
            let profile = try await profile(artifact: artifact)
            
            // Publish progress event (completed)
            await sharedEventBus.publish(
                DataProcessingProgressEvent(
                    processingId: processingId,
                    progress: 1.0,
                    processedItems: 1,
                    totalItems: 1,
                    message: "Profiling completed successfully",
                    stage: "profiling_complete"
                ),
                source: "DataEngine"
            )
            
            let duration = Date().timeIntervalSince(startTime)
            
            // Publish completion event
            await sharedEventBus.publish(
                DataProcessingCompletedEvent(
                    processingId: processingId,
                    result: profile.datasetId,
                    duration: duration,
                    success: true,
                    processedItems: 1
                ),
                source: "DataEngine"
            )
            
            return profile
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            
            // Publish failure event
            await sharedEventBus.publish(
                DataProcessingFailedEvent(
                    processingId: processingId,
                    error: error,
                    processedItems: 0,
                    stackTrace: "Profiling failed: \(error.localizedDescription)"
                ),
                source: "DataEngine"
            )
            
            throw error
        }
    }
    
    /// Event-driven transformation that publishes processing events
    /// - Parameters:
    ///   - artifact: Artifact to transform
    ///   - transform: Transformation to apply
    /// - Returns: Tuple of (newArtifact, changeArtifact)
    /// - Throws: Errors during transformation
    func transformWithEvents(artifact: Artifact, transform: TransformIR) async throws -> (Artifact, ChangeArtifact) {
        let processingId = UUID().uuidString
        let startTime = Date()
        
        // Publish started event
        await sharedEventBus.publish(
            DataProcessingStartedEvent(
                processingId: processingId,
                dataSourceId: artifact.id,
                dataType: "transformation",
                initiatedBy: "DataEngine.transform",
                metadata: [
                    "artifactId": artifact.id,
                    "transformType": transform.id,
                    "processingType": "transformation"
                ]
            ),
            source: "DataEngine"
        )
        
        // Publish progress event (starting)
        await sharedEventBus.publish(
            DataProcessingProgressEvent(
                processingId: processingId,
                progress: 0.0,
                processedItems: 0,
                totalItems: 1,
                message: "Starting transformation of artifact \(artifact.id)",
                stage: "transformation_init"
            ),
            source: "DataEngine"
        )
        
        do {
            // Perform actual transformation
            let (newArtifact, change) = try await self.transform(artifact: artifact, transform: transform)
            
            // Publish progress event (completed)
            await sharedEventBus.publish(
                DataProcessingProgressEvent(
                    processingId: processingId,
                    progress: 1.0,
                    processedItems: 1,
                    totalItems: 1,
                    message: "Transformation completed successfully",
                    stage: "transformation_complete"
                ),
                source: "DataEngine"
            )
            
            let duration = Date().timeIntervalSince(startTime)
            
            // Publish completion event
            await sharedEventBus.publish(
                DataProcessingCompletedEvent(
                    processingId: processingId,
                    result: newArtifact.id,
                    duration: duration,
                    success: true,
                    processedItems: 1
                ),
                source: "DataEngine"
            )
            
            return (newArtifact, change)
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            
            // Publish failure event
            await sharedEventBus.publish(
                DataProcessingFailedEvent(
                    processingId: processingId,
                    error: error,
                    processedItems: 0,
                    stackTrace: "Transformation failed: \(error.localizedDescription)"
                ),
                source: "DataEngine"
            )
            
            throw error
        }
    }
    
    /// Event-driven query that publishes processing events
    /// - Parameter viewSpec: View specification
    /// - Returns: Result artifact
    /// - Throws: Errors during query
    func queryWithEvents(viewSpec: ViewSpec) async throws -> Artifact {
        let processingId = UUID().uuidString
        let startTime = Date()
        
        // Publish started event
        await sharedEventBus.publish(
            DataProcessingStartedEvent(
                processingId: processingId,
                dataSourceId: viewSpec.sourceSnapshotId,
                dataType: "query",
                initiatedBy: "DataEngine.query",
                metadata: [
                    "sourceSnapshotId": viewSpec.sourceSnapshotId,
                    "processingType": "query"
                ]
            ),
            source: "DataEngine"
        )
        
        // Publish progress event (starting)
        await sharedEventBus.publish(
            DataProcessingProgressEvent(
                processingId: processingId,
                progress: 0.0,
                processedItems: 0,
                totalItems: 1,
                message: "Starting query execution",
                stage: "query_init"
            ),
            source: "DataEngine"
        )
        
        do {
            // Perform actual query
            let result = try await query(viewSpec: viewSpec)
            
            // Publish progress event (completed)
            await sharedEventBus.publish(
                DataProcessingProgressEvent(
                    processingId: processingId,
                    progress: 1.0,
                    processedItems: 1,
                    totalItems: 1,
                    message: "Query execution completed successfully",
                    stage: "query_complete"
                ),
                source: "DataEngine"
            )
            
            let duration = Date().timeIntervalSince(startTime)
            
            // Publish completion event
            await sharedEventBus.publish(
                DataProcessingCompletedEvent(
                    processingId: processingId,
                    result: result.id,
                    duration: duration,
                    success: true,
                    processedItems: 1
                ),
                source: "DataEngine"
            )
            
            return result
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            
            // Publish failure event
            await sharedEventBus.publish(
                DataProcessingFailedEvent(
                    processingId: processingId,
                    error: error,
                    processedItems: 0,
                    stackTrace: "Query failed: \(error.localizedDescription)"
                ),
                source: "DataEngine"
            )
            
            throw error
        }
    }
    
    // MARK: - Event Subscriptions

    /// Setup event subscriptions for external triggers
    func setupEventSubscriptions() async {
        // Subscribe to data processing requests from external sources
        let subscription1 = await sharedEventBus.subscribe(to: DataProcessingStartedEvent.self) { [weak self] event in
            guard let self = self else { return }
            
            // Only process events not initiated by DataEngine itself
            guard event.event.initiatedBy != "DataEngine" else { return }
            
            Task {
                do {
                    // Process based on data type
                    switch event.event.dataType {
                    case "url":
                        if let sourceUrlString = event.event.metadata?["source"],
                           let url = URL(string: sourceUrlString) {
                            _ = try await self.ingestWithEvents(source: url)
                        }
                    
                    case "artifact":
                        // Artifact-based processing would require artifact lookup
                        // This would be implemented in a real system
                        break
                    
                    case "query":
                        // Query-based processing would require view spec construction
                        break
                    
                    default:
                        break
                    }
                } catch {
                    // Publish failure event if processing fails
                    await sharedEventBus.publish(
                        DataProcessingFailedEvent(
                            processingId: event.event.processingId,
                            error: error,
                            processedItems: 0
                        ),
                        source: "DataEngine"
                    )
                }
            }
        }
        
        // Subscribe to work item events from workflows
        let subscription2 = await sharedEventBus.subscribe(to: WorkItemCreatedEvent.self) { [weak self] event in
            guard let self = self else { return }
            
            // Only process data processing work items
            guard event.event.workItemType == "data_processing" else { return }
            
            Task {
                do {
                    // Process work item based on metadata
                    if let sourceUrlString = event.event.metadata?["source"],
                       let url = URL(string: sourceUrlString) {
                        _ = try await self.ingestWithEvents(source: url)
                    }
                    
                    // Publish work item completion event
                    await sharedEventBus.publish(
                        WorkItemCompletedEvent(
                            workItemId: event.event.workItemId,
                            result: "Data processing completed",
                            duration: 0, // Would measure actual duration
                            success: true
                        ),
                        source: "DataEngine"
                    )
                } catch {
                    // Publish work item failure event
                    await sharedEventBus.publish(
                        WorkItemFailedEvent(
                            workItemId: event.event.workItemId,
                            error: error,
                            duration: 0
                        ),
                        source: "DataEngine"
                    )
                }
            }
        }
        
        // Store subscription IDs for cleanup
        eventSubscriptionIds.append(subscription1)
        eventSubscriptionIds.append(subscription2)
    }
    
    /// Cleanup event subscriptions
    func cleanupEventSubscriptions() async {
        for id in eventSubscriptionIds {
            await sharedEventBus.unsubscribe(id: id)
        }
        eventSubscriptionIds.removeAll()
    }
}

// MARK: - DataEngine Event Extensions

public extension DataEngine {
    /// Convenience method to create a work item for data processing
    /// - Parameters:
    ///   - source: Data source URL
    ///   - priority: Work item priority
    ///   - metadata: Additional metadata
    /// - Returns: Created work item ID
    static func createDataProcessingWorkItem(
        source: URL,
        priority: Int = 1,
        metadata: [String: String]? = nil
    ) async -> String {
        let workItemId = UUID().uuidString
        var workItemMetadata = metadata ?? [:]
        workItemMetadata["source"] = source.absoluteString
        workItemMetadata["processingType"] = "ingestion"
        
        // Publish work item created event
        await sharedEventBus.publish(
            WorkItemCreatedEvent(
                workItemId: workItemId,
                workItemType: "data_processing",
                priority: priority,
                createdBy: "DataEngine",
                metadata: workItemMetadata
            ),
            source: "DataEngine"
        )
        
        return workItemId
    }
    
    /// Convenience method to create a data processing request
    /// - Parameters:
    ///   - source: Data source URL
    ///   - initiatedBy: Initiator identifier
    ///   - metadata: Additional metadata
    /// - Returns: Processing ID
    static func requestDataProcessing(
        source: URL,
        initiatedBy: String,
        metadata: [String: String]? = nil
    ) async -> String {
        let processingId = UUID().uuidString
        var requestMetadata = metadata ?? [:]
        requestMetadata["source"] = source.absoluteString
        requestMetadata["processingType"] = "ingestion"
        
        // Publish data processing started event
        await sharedEventBus.publish(
            DataProcessingStartedEvent(
                processingId: processingId,
                dataSourceId: source.lastPathComponent,
                dataType: "url",
                initiatedBy: initiatedBy,
                metadata: requestMetadata
            ),
            source: "DataEngine"
        )
        
        return processingId
    }
}
