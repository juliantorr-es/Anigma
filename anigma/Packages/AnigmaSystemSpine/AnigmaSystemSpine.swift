//
//  AnigmaSystemSpine.swift
//  AnigmaSystemSpine
//
//  The shared spine for Apple System Integration.
//  Provides the canonical object model, CloudKit sync, and App Group storage.
//

import Foundation
import CoreData
import CloudKit

public final class SystemSpine: Sendable {
    public static let shared = SystemSpine()

    // App Group Identifier - must match entitlements
    public let appGroupIdentifier = "group.com.anigma.system"

    // Core Data Container
    public let container: NSPersistentCloudKitContainer

    // Job Engine
    public let jobEngine: JobEngine

    public init(inMemory: Bool = false) {
        // Define the model programmatically to avoid .xcdatamodeld complexity in CLI
        let model = SystemSpine.createModel()

        container = NSPersistentCloudKitContainer(name: "AnigmaSystem", managedObjectModel: model)

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve persistent store description")
        }

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
            // Initialize JobEngine for in-memory
            do {
                self.jobEngine = try JobEngine(directoryURL: URL(fileURLWithPath: "/tmp/jobqueue-\(UUID().uuidString)"))
            } catch {
                fatalError("Failed to initialize in-memory JobEngine: \(error)")
            }
        } else {
            // Use App Group container
            if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
                description.url = groupURL.appendingPathComponent("AnigmaSystem.db")
            } else {
                // Fallback to Application Support
                if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                    let anigmaDir = appSupport.appendingPathComponent("Anigma")
                    try? FileManager.default.createDirectory(at: anigmaDir, withIntermediateDirectories: true)
                    description.url = anigmaDir.appendingPathComponent("AnigmaSystem.db")
                }
            }

            // Enable CloudKit only if we think we have entitlements (heuristic)
            // For now, we disable CloudKit in this build to prevent crashes if entitlements are missing
            // description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            //     containerIdentifier: "iCloud.com.anigma.system"
            // )

            // Enable History Tracking for deduplication/sync
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            // Enable automatic migration
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true

            // Initialize JobEngine
            do {
                if let _ = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
                    self.jobEngine = try JobEngine(appGroupIdentifier: appGroupIdentifier)
                } else {
                    // Fallback to standard documents directory if App Group is missing
                    guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                        fatalError("Failed to unwrap docs")
                    }
                    let jobDir = docs.appendingPathComponent("AnigmaJobs")
                    try FileManager.default.createDirectory(at: jobDir, withIntermediateDirectories: true)
                    self.jobEngine = try JobEngine(directoryURL: jobDir)
                }
            } catch {
                fatalError("Failed to initialize JobEngine: \(error)")
            }
        }

        container.loadPersistentStores { _, error in
            if let error = error {
                print("Failed to load persistent stores: \(error). Falling back to in-memory.")
                // Fallback to in-memory if persistent store fails (e.g. due to missing entitlements)
                self.container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
                self.container.loadPersistentStores { _, fallbackError in
                    if let fallbackError = fallbackError {
                        fatalError("Failed to load in-memory fallback store: \(fallbackError)")
                    }
                }
            }
        }

        // Merge policy: Prefer store (cloud) version on conflict, but we should be smarter later
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    // MARK: - Programmatic Model Definition

    private static func createModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // Entities
        let caseEntity = NSEntityDescription()
        caseEntity.name = "AnigmaCase"
        caseEntity.managedObjectClassName = "AnigmaCase"

        let documentEntity = NSEntityDescription()
        documentEntity.name = "AnigmaDocument"
        documentEntity.managedObjectClassName = "AnigmaDocument"

        let taskEntity = NSEntityDescription()
        taskEntity.name = "AnigmaTask"
        taskEntity.managedObjectClassName = "AnigmaTask"

        let receiptEntity = NSEntityDescription()
        receiptEntity.name = "AnigmaReceipt"
        receiptEntity.managedObjectClassName = "AnigmaReceipt"

        // Attributes - AnigmaCase
        let caseId = NSAttributeDescription()
        caseId.name = "id"
        caseId.attributeType = .UUIDAttributeType
        caseId.isOptional = false

        let caseTitle = NSAttributeDescription()
        caseTitle.name = "title"
        caseTitle.attributeType = .stringAttributeType
        caseTitle.isOptional = false

        let caseCreated = NSAttributeDescription()
        caseCreated.name = "createdAt"
        caseCreated.attributeType = .dateAttributeType
        caseCreated.isOptional = false

        caseEntity.properties = [caseId, caseTitle, caseCreated]

        // Attributes - AnigmaDocument
        let docId = NSAttributeDescription()
        docId.name = "id"
        docId.attributeType = .UUIDAttributeType
        docId.isOptional = false

        let docFilename = NSAttributeDescription()
        docFilename.name = "filename"
        docFilename.attributeType = .stringAttributeType
        docFilename.isOptional = false

        documentEntity.properties = [docId, docFilename]

        // Attributes - AnigmaTask
        let taskId = NSAttributeDescription()
        taskId.name = "id"
        taskId.attributeType = .UUIDAttributeType
        taskId.isOptional = false

        let taskTitle = NSAttributeDescription()
        taskTitle.name = "title"
        taskTitle.attributeType = .stringAttributeType
        taskTitle.isOptional = false

        let taskIsDone = NSAttributeDescription()
        taskIsDone.name = "isDone"
        taskIsDone.attributeType = .booleanAttributeType
        taskIsDone.defaultValue = false

        taskEntity.properties = [taskId, taskTitle, taskIsDone]

        // Attributes - AnigmaReceipt
        let receiptId = NSAttributeDescription()
        receiptId.name = "id"
        receiptId.attributeType = .UUIDAttributeType
        receiptId.isOptional = false

        let receiptTimestamp = NSAttributeDescription()
        receiptTimestamp.name = "timestamp"
        receiptTimestamp.attributeType = .dateAttributeType
        receiptTimestamp.isOptional = false

        let receiptAction = NSAttributeDescription()
        receiptAction.name = "action"
        receiptAction.attributeType = .stringAttributeType
        receiptAction.isOptional = false

        let receiptActor = NSAttributeDescription()
        receiptActor.name = "actor"
        receiptActor.attributeType = .stringAttributeType
        receiptActor.isOptional = false

        let receiptSurface = NSAttributeDescription()
        receiptSurface.name = "surface"
        receiptSurface.attributeType = .stringAttributeType
        receiptSurface.isOptional = false

        let receiptDetails = NSAttributeDescription()
        receiptDetails.name = "details"
        receiptDetails.attributeType = .stringAttributeType
        receiptDetails.isOptional = true

        receiptEntity.properties = [receiptId, receiptTimestamp, receiptAction, receiptActor, receiptSurface, receiptDetails]

        // Entities - IntegrationAccount
        let accountEntity = NSEntityDescription()
        accountEntity.name = "IntegrationAccount"
        accountEntity.managedObjectClassName = "IntegrationAccount"

        let accId = NSAttributeDescription()
        accId.name = "id"
        accId.attributeType = .UUIDAttributeType
        accId.isOptional = false

        let accProvider = NSAttributeDescription()
        accProvider.name = "providerType"
        accProvider.attributeType = .stringAttributeType
        accProvider.isOptional = false

        let accTenant = NSAttributeDescription()
        accTenant.name = "tenantId"
        accTenant.attributeType = .stringAttributeType
        accTenant.isOptional = true

        let accAccountId = NSAttributeDescription()
        accAccountId.name = "accountId"
        accAccountId.attributeType = .stringAttributeType
        accAccountId.isOptional = false

        let accScopes = NSAttributeDescription()
        accScopes.name = "scopes"
        accScopes.attributeType = .stringAttributeType
        accScopes.isOptional = false

        let accLastSync = NSAttributeDescription()
        accLastSync.name = "lastSync"
        accLastSync.attributeType = .dateAttributeType
        accLastSync.isOptional = true

        let accHealth = NSAttributeDescription()
        accHealth.name = "healthStatus"
        accHealth.attributeType = .stringAttributeType
        accHealth.isOptional = false

        let accSpace = NSAttributeDescription()
        accSpace.name = "spaceId"
        accSpace.attributeType = .stringAttributeType
        accSpace.isOptional = false

        accountEntity.properties = [accId, accProvider, accTenant, accAccountId, accScopes, accLastSync, accHealth, accSpace]

        // Entities - SyncTrack
        let trackEntity = NSEntityDescription()
        trackEntity.name = "SyncTrack"
        trackEntity.managedObjectClassName = "SyncTrack"

        let trackId = NSAttributeDescription()
        trackId.name = "id"
        trackId.attributeType = .UUIDAttributeType
        trackId.isOptional = false

        let trackAccountId = NSAttributeDescription()
        trackAccountId.name = "accountId"
        trackAccountId.attributeType = .UUIDAttributeType
        trackAccountId.isOptional = false

        let trackType = NSAttributeDescription()
        trackType.name = "trackType"
        trackType.attributeType = .stringAttributeType
        trackType.isOptional = false

        let trackWatermark = NSAttributeDescription()
        trackWatermark.name = "lastWatermark"
        trackWatermark.attributeType = .stringAttributeType
        trackWatermark.isOptional = true

        let trackSuccess = NSAttributeDescription()
        trackSuccess.name = "lastSuccess"
        trackSuccess.attributeType = .dateAttributeType
        trackSuccess.isOptional = true

        let trackFailure = NSAttributeDescription()
        trackFailure.name = "lastFailure"
        trackFailure.attributeType = .dateAttributeType
        trackFailure.isOptional = true

        let trackReason = NSAttributeDescription()
        trackReason.name = "failureReason"
        trackReason.attributeType = .stringAttributeType
        trackReason.isOptional = true

        trackEntity.properties = [trackId, trackAccountId, trackType, trackWatermark, trackSuccess, trackFailure, trackReason]

        // Entities - ConflictRecord
        let conflictEntity = NSEntityDescription()
        conflictEntity.name = "ConflictRecord"
        conflictEntity.managedObjectClassName = "ConflictRecord"

        let conflictId = NSAttributeDescription()
        conflictId.name = "id"
        conflictId.attributeType = .UUIDAttributeType
        conflictId.isOptional = false

        let conflictObjectId = NSAttributeDescription()
        conflictObjectId.name = "objectId"
        conflictObjectId.attributeType = .stringAttributeType
        conflictObjectId.isOptional = false

        let conflictObjectType = NSAttributeDescription()
        conflictObjectType.name = "objectType"
        conflictObjectType.attributeType = .stringAttributeType
        conflictObjectType.isOptional = false

        let conflictType = NSAttributeDescription()
        conflictType.name = "conflictType"
        conflictType.attributeType = .stringAttributeType
        conflictType.isOptional = false

        let conflictDetected = NSAttributeDescription()
        conflictDetected.name = "detectedAt"
        conflictDetected.attributeType = .dateAttributeType
        conflictDetected.isOptional = false

        let conflictStatus = NSAttributeDescription()
        conflictStatus.name = "status"
        conflictStatus.attributeType = .stringAttributeType
        conflictStatus.isOptional = false

        let conflictResolution = NSAttributeDescription()
        conflictResolution.name = "resolution"
        conflictResolution.attributeType = .stringAttributeType
        conflictResolution.isOptional = true

        conflictEntity.properties = [conflictId, conflictObjectId, conflictObjectType, conflictType, conflictDetected, conflictStatus, conflictResolution]

        // Entities - RepairAction
        let repairEntity = NSEntityDescription()
        repairEntity.name = "RepairAction"
        repairEntity.managedObjectClassName = "RepairAction"

        let repairId = NSAttributeDescription()
        repairId.name = "id"
        repairId.attributeType = .UUIDAttributeType
        repairId.isOptional = false

        let repairType = NSAttributeDescription()
        repairType.name = "actionType"
        repairType.attributeType = .stringAttributeType
        repairType.isOptional = false

        let repairTarget = NSAttributeDescription()
        repairTarget.name = "targetId"
        repairTarget.attributeType = .stringAttributeType
        repairTarget.isOptional = false

        let repairStatus = NSAttributeDescription()
        repairStatus.name = "status"
        repairStatus.attributeType = .stringAttributeType
        repairStatus.isOptional = false

        let repairCreated = NSAttributeDescription()
        repairCreated.name = "createdAt"
        repairCreated.attributeType = .dateAttributeType
        repairCreated.isOptional = false

        let repairReceipts = NSAttributeDescription()
        repairReceipts.name = "receipts"
        repairReceipts.attributeType = .stringAttributeType
        repairReceipts.isOptional = true

        repairEntity.properties = [repairId, repairType, repairTarget, repairStatus, repairCreated, repairReceipts]

        // Finalize
        model.entities = [caseEntity, documentEntity, taskEntity, receiptEntity, accountEntity, trackEntity, conflictEntity, repairEntity]
        return model
    }

    // MARK: - CoreReceipt Recording

    public func recordReceipt(action: String, actor: String, surface: String, details: String? = nil) {
        let context = container.newBackgroundContext()
        context.perform {
            let receipt = AnigmaReceipt(context: context)
            receipt.id = UUID()
            receipt.timestamp = Date()
            receipt.action = action
            receipt.actor = actor
            receipt.surface = surface
            receipt.details = details

            do {
                try context.save()
            } catch {
                print("Failed to save receipt: \(error)")
            }
        }
    }
}

// MARK: - Managed Object Subclasses (Stubs)

@objc(AnigmaCase)
public class AnigmaCase: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var createdAt: Date
}

@objc(AnigmaDocument)
public class AnigmaDocument: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var filename: String
}

@objc(AnigmaTask)
public class AnigmaTask: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var isDone: Bool
}

@objc(AnigmaReceipt)
public class AnigmaReceipt: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var timestamp: Date
    @NSManaged public var action: String
    @NSManaged public var actor: String
    @NSManaged public var surface: String
    @NSManaged public var details: String?
}

@objc(IntegrationAccount)
public class IntegrationAccount: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var providerType: String
    @NSManaged public var tenantId: String?
    @NSManaged public var accountId: String
    @NSManaged public var scopes: String
    @NSManaged public var lastSync: Date?
    @NSManaged public var healthStatus: String
    @NSManaged public var spaceId: String
}

@objc(SyncTrack)
public class SyncTrack: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var accountId: UUID
    @NSManaged public var trackType: String
    @NSManaged public var lastWatermark: String?
    @NSManaged public var lastSuccess: Date?
    @NSManaged public var lastFailure: Date?
    @NSManaged public var failureReason: String?
}

@objc(ConflictRecord)
public class ConflictRecord: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var objectId: String
    @NSManaged public var objectType: String
    @NSManaged public var conflictType: String
    @NSManaged public var detectedAt: Date
    @NSManaged public var status: String
    @NSManaged public var resolution: String?
}

@objc(RepairAction)
public class RepairAction: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var actionType: String
    @NSManaged public var targetId: String
    @NSManaged public var status: String
    @NSManaged public var createdAt: Date
    @NSManaged public var receipts: String?
}
