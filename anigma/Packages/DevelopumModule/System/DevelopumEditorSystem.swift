//
//  DevelopumEditorSystem.swift
//  DevelopumModule
//
//  ECS system for managing Develop mode editor state.
//  Processes bridge messages and updates workspace state.
//

import AnigmaCore
import AnigmaPrimitives
import Foundation
import TelemetryCore

/// System that manages editor state and processes bridge messages.
public struct DevelopumEditorSystem: System {
    public var name: String { "DevelopumEditorSystem" }
    
    private let databaseService: DevelopumDatabaseService
    private let telemetryClient: TelemetryClient?
    
    /// Current bridge session ID for message correlation.
    private var currentSessionId: String = UUID().uuidString
    
    public init(
        databaseService: DevelopumDatabaseService,
        telemetryClient: TelemetryClient? = nil
    ) {
        self.databaseService = databaseService
        self.telemetryClient = telemetryClient
    }
    
    public func update(world: World) async {
        await processPendingBridgeMessages(world: world)
        await updateWorkspaceStates(world: world)
        await cleanupClosedFiles(world: world)
    }
    
    // MARK: - Bridge Message Processing
    
    /// Process pending bridge messages from entities.
    private func processPendingBridgeMessages(world: World) async {
        let messages = await world.query(BridgeMessageComponent.self, RepoSessionComponent.self)
        
        for (entity, bridgeMessage, repoSession) in messages {
            guard bridgeMessage.status == .pending else { continue }
            
            logInfo("Processing bridge message: \(bridgeMessage.messageType)", category: "DevelopumEditorSystem")
            
            switch bridgeMessage.messageType {
            case .fileOpened:
                await handleFileOpened(world: world, entity: entity, bridgeMessage: bridgeMessage, repoSession: repoSession)
            case .fileClosed:
                await handleFileClosed(world: world, entity: entity, bridgeMessage: bridgeMessage, repoSession: repoSession)
            case .cursorMoved:
                await handleCursorMoved(world: world, entity: entity, bridgeMessage: bridgeMessage, repoSession: repoSession)
            case .selectionChanged:
                await handleSelectionChanged(world: world, entity: entity, bridgeMessage: bridgeMessage, repoSession: repoSession)
            case .viewportChanged:
                await handleViewportChanged(world: world, entity: entity, bridgeMessage: bridgeMessage, repoSession: repoSession)
            case .contentChanged:
                await handleContentChanged(world: world, entity: entity, bridgeMessage: bridgeMessage, repoSession: repoSession)
            case .saveRequest:
                await handleSaveRequest(world: world, entity: entity, bridgeMessage: bridgeMessage, repoSession: repoSession)
            case .searchRequest:
                await handleSearchRequest(world: world, entity: entity, bridgeMessage: bridgeMessage, repoSession: repoSession)
            default:
                logWarning("Unhandled bridge message type: \(bridgeMessage.messageType)", category: "DevelopumEditorSystem")
            }
            
            var updated = bridgeMessage
            updated.status = .completed
            await world.addComponent(entity, updated)
        }
    }
    
    /// Handle file opened message.
    private func handleFileOpened(
        world: World,
        entity: EntityId,
        bridgeMessage: BridgeMessageComponent,
        repoSession: RepoSessionComponent
    ) async {
        guard let payload = try? JSONDecoder().decode(FileOpenedPayload.self, from: bridgeMessage.payloadJson.data(using: .utf8)!) else {
            logError("Failed to decode FileOpenedPayload", category: "DevelopumEditorSystem")
            return
        }
        
        // Create open file component
        let openFile = OpenFileComponent(
            fileUri: payload.fileUri,
            filePath: payload.filePath,
            languageId: payload.languageId,
            contentHash: payload.contentHash,
            lastActivityAt: Date()
        )
        await world.addComponent(entity, openFile)
        
        // Update database workspace state
        let workspaceState = WorkspaceState(
            repoId: repoSession.id,
            filePath: payload.filePath,
            isOpen: true,
            updatedAt: Date()
        )
        try? await databaseService.saveWorkspaceState(workspaceState)
        
        logInfo("File opened: \(payload.filePath)", category: "DevelopumEditorSystem")
    }
    
    /// Handle file closed message.
    private func handleFileClosed(
        world: World,
        entity: EntityId,
        bridgeMessage: BridgeMessageComponent,
        repoSession: RepoSessionComponent
    ) async {
        guard let payload = try? JSONDecoder().decode(FileClosedPayload.self, from: bridgeMessage.payloadJson.data(using: .utf8)!) else {
            logError("Failed to decode FileClosedPayload", category: "DevelopumEditorSystem")
            return
        }
        
        // Extract file path from URI
        let filePath = extractFilePath(from: payload.fileUri)
        
        // Remove open file component
        await world.removeComponent(entity, OpenFileComponent.self)
        
        // Update database workspace state
        try? await databaseService.closeWorkspaceState(repoId: repoSession.id, filePath: filePath)
        
        logInfo("File closed: \(filePath)", category: "DevelopumEditorSystem")
    }
    
    /// Handle cursor moved message.
    private func handleCursorMoved(
        world: World,
        entity: EntityId,
        bridgeMessage: BridgeMessageComponent,
        repoSession: RepoSessionComponent
    ) async {
        guard let payload = try? JSONDecoder().decode(CursorMovedPayload.self, from: bridgeMessage.payloadJson.data(using: .utf8)!) else {
            logError("Failed to decode CursorMovedPayload", category: "DevelopumEditorSystem")
            return
        }
        
        guard var openFile = await world.getComponent(entity, OpenFileComponent.self) else {
            return
        }
        
        openFile.cursorLine = payload.line
        openFile.cursorColumn = payload.column
        openFile.lastActivityAt = Date()
        await world.addComponent(entity, openFile)
        
        // Update database asynchronously
        let filePath = extractFilePath(from: payload.fileUri)
        Task {
            var workspaceState = (try? await databaseService.getWorkspaceState(repoId: repoSession.id, filePath: filePath)) ?? WorkspaceState(
                repoId: repoSession.id,
                filePath: filePath,
                updatedAt: Date()
            )
            workspaceState.cursorLine = payload.line
            workspaceState.cursorColumn = payload.column
            workspaceState.updatedAt = Date()
            try? await databaseService.saveWorkspaceState(workspaceState)
        }
    }
    
    /// Handle selection changed message.
    private func handleSelectionChanged(
        world: World,
        entity: EntityId,
        bridgeMessage: BridgeMessageComponent,
        repoSession: RepoSessionComponent
    ) async {
        guard let payload = try? JSONDecoder().decode(SelectionChangedPayload.self, from: bridgeMessage.payloadJson.data(using: .utf8)!) else {
            logError("Failed to decode SelectionChangedPayload", category: "DevelopumEditorSystem")
            return
        }
        
        guard var openFile = await world.getComponent(entity, OpenFileComponent.self) else {
            return
        }
        
        openFile.selectionStartLine = payload.startLine
        openFile.selectionStartColumn = payload.startColumn
        openFile.selectionEndLine = payload.endLine
        openFile.selectionEndColumn = payload.endColumn
        openFile.lastActivityAt = Date()
        await world.addComponent(entity, openFile)
        
        // Update database asynchronously
        let filePath = extractFilePath(from: payload.fileUri)
        Task {
            var workspaceState = (try? await databaseService.getWorkspaceState(repoId: repoSession.id, filePath: filePath)) ?? WorkspaceState(
                repoId: repoSession.id,
                filePath: filePath,
                updatedAt: Date()
            )
            workspaceState.selectionStartLine = payload.startLine
            workspaceState.selectionStartColumn = payload.startColumn
            workspaceState.selectionEndLine = payload.endLine
            workspaceState.selectionEndColumn = payload.endColumn
            workspaceState.updatedAt = Date()
            try? await databaseService.saveWorkspaceState(workspaceState)
        }
    }
    
    /// Handle viewport changed message.
    private func handleViewportChanged(
        world: World,
        entity: EntityId,
        bridgeMessage: BridgeMessageComponent,
        repoSession: RepoSessionComponent
    ) async {
        guard let payload = try? JSONDecoder().decode(ViewportChangedPayload.self, from: bridgeMessage.payloadJson.data(using: .utf8)!) else {
            logError("Failed to decode ViewportChangedPayload", category: "DevelopumEditorSystem")
            return
        }
        
        guard var openFile = await world.getComponent(entity, OpenFileComponent.self) else {
            return
        }
        
        openFile.viewportTopLine = payload.topLine
        openFile.viewportBottomLine = payload.bottomLine
        openFile.lastActivityAt = Date()
        await world.addComponent(entity, openFile)
        
        // Update database asynchronously
        let filePath = extractFilePath(from: payload.fileUri)
        Task {
            var workspaceState = (try? await databaseService.getWorkspaceState(repoId: repoSession.id, filePath: filePath)) ?? WorkspaceState(
                repoId: repoSession.id,
                filePath: filePath,
                updatedAt: Date()
            )
            workspaceState.viewportTopLine = payload.topLine
            workspaceState.viewportBottomLine = payload.bottomLine
            workspaceState.updatedAt = Date()
            try? await databaseService.saveWorkspaceState(workspaceState)
        }
    }
    
    /// Handle content changed message.
    private func handleContentChanged(
        world: World,
        entity: EntityId,
        bridgeMessage: BridgeMessageComponent,
        repoSession: RepoSessionComponent
    ) async {
        guard let payload = try? JSONDecoder().decode(ContentChangedPayload.self, from: bridgeMessage.payloadJson.data(using: .utf8)!) else {
            logError("Failed to decode ContentChangedPayload", category: "DevelopumEditorSystem")
            return
        }
        
        guard var openFile = await world.getComponent(entity, OpenFileComponent.self) else {
            return
        }
        
        openFile.contentHash = payload.contentHash
        openFile.hasUnsavedChanges = payload.hasUnsavedChanges
        openFile.lastActivityAt = Date()
        await world.addComponent(entity, openFile)
        
        // Update database asynchronously
        let filePath = extractFilePath(from: payload.fileUri)
        Task {
            var workspaceState = (try? await databaseService.getWorkspaceState(repoId: repoSession.id, filePath: filePath)) ?? WorkspaceState(
                repoId: repoSession.id,
                filePath: filePath,
                updatedAt: Date()
            )
            workspaceState.hasUnsavedChanges = payload.hasUnsavedChanges
            workspaceState.updatedAt = Date()
            try? await databaseService.saveWorkspaceState(workspaceState)
        }
    }
    
    /// Handle save request message.
    private func handleSaveRequest(
        world: World,
        entity: EntityId,
        bridgeMessage: BridgeMessageComponent,
        repoSession: RepoSessionComponent
    ) async {
        guard let payload = try? JSONDecoder().decode(SaveRequestPayload.self, from: bridgeMessage.payloadJson.data(using: .utf8)!) else {
            logError("Failed to decode SaveRequestPayload", category: "DevelopumEditorSystem")
            return
        }
        
        let filePath = extractFilePath(from: payload.fileUri)
        
        // Create save file job
        let job = Job.saveFile(
            repoId: repoSession.id.uuidString,
            filePath: filePath,
            content: payload.content,
            createArtifact: true,
            mirrorToWorkingTree: true
        )
        
        let jobEntity = await world.createEntity()
        await world.addComponent(jobEntity, job)
        await world.addComponent(jobEntity, repoSession)
        
        logInfo("Save request queued for: \(filePath)", category: "DevelopumEditorSystem")
    }
    
    /// Handle search request message.
    private func handleSearchRequest(
        world: World,
        entity: EntityId,
        bridgeMessage: BridgeMessageComponent,
        repoSession: RepoSessionComponent
    ) async {
        guard let payload = try? JSONDecoder().decode(SearchRequestPayload.self, from: bridgeMessage.payloadJson.data(using: .utf8)!) else {
            logError("Failed to decode SearchRequestPayload", category: "DevelopumEditorSystem")
            return
        }
        
        // Create search job
        let job = Job.searchFiles(
            repoId: repoSession.id.uuidString,
            query: payload.query,
            isRegex: payload.isRegex,
            matchCase: payload.matchCase,
            matchWholeWord: payload.matchWholeWord,
            filePattern: payload.fileUri
        )
        
        let jobEntity = await world.createEntity()
        await world.addComponent(jobEntity, job)
        await world.addComponent(jobEntity, repoSession)
        
        logInfo("Search request queued: \(payload.query)", category: "DevelopumEditorSystem")
    }
    
    // MARK: - Workspace State Management
    
    /// Persist workspace states to database.
    private func updateWorkspaceStates(world: World) async {
        let openFiles = await world.query(OpenFileComponent.self, RepoSessionComponent.self)
        
        for (entity, openFile, repoSession) in openFiles {
            let filePath = extractFilePath(from: openFile.fileUri)
            var workspaceState = (try? await databaseService.getWorkspaceState(repoId: repoSession.id, filePath: filePath)) ?? WorkspaceState(
                repoId: repoSession.id,
                filePath: filePath,
                updatedAt: Date()
            )
            
            workspaceState.cursorLine = openFile.cursorLine
            workspaceState.cursorColumn = openFile.cursorColumn
            workspaceState.selectionStartLine = openFile.selectionStartLine
            workspaceState.selectionStartColumn = openFile.selectionStartColumn
            workspaceState.selectionEndLine = openFile.selectionEndLine
            workspaceState.selectionEndColumn = openFile.selectionEndColumn
            workspaceState.viewportTopLine = openFile.viewportTopLine
            workspaceState.viewportBottomLine = openFile.viewportBottomLine
            workspaceState.isOpen = true
            workspaceState.hasUnsavedChanges = openFile.hasUnsavedChanges
            workspaceState.updatedAt = Date()
            
            try? await databaseService.saveWorkspaceState(workspaceState)
        }
    }
    
    /// Cleanup closed files from ECS.
    private func cleanupClosedFiles(world: World) async {
        let files = await world.query(OpenFileComponent.self)
        
        for (entity, openFile) in files {
            // Remove files inactive for more than 5 minutes
            if Date().timeIntervalSince(openFile.lastActivityAt) > 300 {
                logInfo("Removing inactive file: \(openFile.filePath)", category: "DevelopumEditorSystem")
                await world.removeEntity(entity)
            }
        }
    }
    
    // MARK: - Utilities
    
    /// Extract file path from anigma:// URI.
    private func extractFilePath(from uri: String) -> String {
        guard uri.hasPrefix("anigma://") else { return uri }
        
        let components = URLComponents(string: uri)
        return components?.path.replacingOccurrences(of: "/", with: "", options: .anchored) ?? uri
    }
}
