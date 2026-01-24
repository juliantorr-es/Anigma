//
//  DevelopumLSPBridge.swift
//  DevelopumModule
//
//  LSP Bridge for semantic navigation in Develop mode.
//  Provides definition, references, hover, completion, and document symbols via Language Server Protocol.
//

import AnigmaCore
import AnigmaPrimitives
import ExecutionCore
import Foundation
import TelemetryCore

// MARK: - DevelopumLSPBridge

/// Main LSP Bridge service for semantic navigation in Develop mode.
public actor DevelopumLSPBridge {
    private let databaseService: DevelopumDatabaseService
    private let receiptService: DevelopumReceiptService?
    private var connections: [UUID: LSPConnection] = [:]
    private let defaultLSPPath: String
    private let telemetryClient: TelemetryClient?

    public init(
        databaseService: DevelopumDatabaseService,
        receiptService: DevelopumReceiptService? = nil,
        defaultLSPPath: String = "sourcekit-lsp",
        telemetryClient: TelemetryClient? = nil
    ) {
        self.databaseService = databaseService
        self.receiptService = receiptService
        self.connections = [:]
        self.defaultLSPPath = defaultLSPPath
        self.telemetryClient = telemetryClient
    }

    // MARK: - Connection Management

    public func initialize(
        repoId: UUID,
        repoPath: String,
        transportType: LSPConnection.LSPTransportType = .stdio
    ) async throws -> ServerCapabilities {
        logInfo("Initializing LSP bridge for repo: \(repoId.uuidString)", category: "DevelopumLSPBridge")

        let connection = LSPConnection(
            repoId: repoId,
            repoPath: repoPath,
            transportType: transportType,
            lspServerPath: defaultLSPPath
        )

        try await connection.connect()
        self.connections[repoId] = connection

        let params = InitializeParams(
            processId: Int(ProcessInfo.processInfo.processIdentifier),
            rootUri: AnigmaVirtualURI.documentURI(repoId: repoId, filePath: repoPath),
            initializationOptions: InitializationOptions(
                anigmaOptions: AnigmaLSPOptions(
                    repoId: repoId.uuidString,
                    repoPath: repoPath
                )
            ),
            capabilities: ClientCapabilities(
                textDocument: TextDocumentClientCapabilities(
                    synchronization: TextDocumentSyncOptions(openClose: true, change: .incremental),
                    completion: CompletionCapabilities(
                        dynamicRegistration: true,
                        completionItem: CompletionItemCapabilities(snippetSupport: true)
                    ),
                    hover: HoverCapabilities(dynamicRegistration: true),
                    definition: DefinitionCapabilities(dynamicRegistration: true, linkSupport: true),
                    references: ReferencesCapabilities(dynamicRegistration: true),
                    documentSymbol: DocumentSymbolCapabilities(
                        dynamicRegistration: true,
                        hierarchicalDocumentSymbolSupport: true
                    )
                ),
                workspace: WorkspaceClientCapabilities(applyEdit: true, workspaceFolders: true)
            )
        )

        let result: InitializeResult = try await connection.sendRequest(
            .initialize,
            params: params,
            responseType: InitializeResult.self
        )

        try await connection.sendNotification(.initialized, params: InitializedParams())

        if let _ = receiptService {
            let inputs: [String: TelemetryValue] = [
                "repoId": .string(repoId.uuidString),
                "repoPath": .string(repoPath),
                "transportType": .string(transportType.rawValue),
                "serverName": .string(result.serverInfo?.name ?? "unknown")
            ]
            let inputsHash = TelemetryHash.compute(from: inputs)
            let _ = ReceiptWire.create(
                actionName: "developum.lsp.initialize",
                authority: "DevelopumModule",
                decision: .allowed,
                reasonCode: "initialized",
                timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
                inputsHash: inputsHash,
                outputsHash: nil,
                previousReceiptHash: nil,
                metadata: inputs
            )
        }

        logInfo("LSP bridge initialized for repo: \(repoId.uuidString)", category: "DevelopumLSPBridge")

        return result.capabilities
    }

    public func shutdown(repoId: UUID) async throws {
        logInfo("Shutting down LSP bridge for repo: \(repoId.uuidString)", category: "DevelopumLSPBridge")

        guard let connection = connections[repoId] else {
            return
        }

        try await connection.sendRequest(
            .shutdown,
            params: ShutdownParams(),
            responseType: LSPResult.self // Using LSPResult instead of Void to satisfy sendRequest
        )

        await connection.disconnect()
        self.connections.removeValue(forKey: repoId)

        if let _ = receiptService {
            let inputs: [String: TelemetryValue] = ["repoId": .string(repoId.uuidString)]
            let inputsHash = TelemetryHash.compute(from: inputs)
            let _ = ReceiptWire.create(
                actionName: "developum.lsp.shutdown",
                authority: "DevelopumModule",
                decision: .allowed,
                reasonCode: "shutdown",
                timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
                inputsHash: inputsHash,
                outputsHash: nil,
                previousReceiptHash: nil,
                metadata: inputs
            )
        }
    }

    private func getConnection(for repoId: UUID) throws -> LSPConnection {
        guard let connection = connections[repoId] else {
            throw LSPConnectionError.notConnected
        }
        return connection
    }

    // MARK: - Document Operations

    public func openDocument(
        repoId: UUID,
        filePath: String,
        content: String,
        languageId: String
    ) async throws {
        logInfo("Opening document: \(filePath)", category: "DevelopumLSPBridge")

        let connection = try getConnection(for: repoId)

        let uri = AnigmaVirtualURI.documentURI(repoId: repoId, filePath: filePath)
        let textDocument = TextDocumentItem(
            uri: uri,
            languageId: languageId,
            version: 1,
            text: content
        )

        try await connection.sendNotification(
            .textDocumentDidOpen,
            params: DidOpenTextDocumentParams(textDocument: textDocument)
        )

        if let _ = receiptService {
            let inputs: [String: TelemetryValue] = [
                "repoId": .string(repoId.uuidString),
                "filePath": .string(filePath),
                "languageId": .string(languageId),
                "uri": .string(uri)
            ]
            let inputsHash = TelemetryHash.compute(from: inputs)
            let _ = ReceiptWire.create(
                actionName: "developum.lsp.openDocument",
                authority: "DevelopumModule",
                decision: .allowed,
                reasonCode: "opened",
                timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
                inputsHash: inputsHash,
                outputsHash: nil,
                previousReceiptHash: nil,
                metadata: inputs
            )
        }
    }

    public func closeDocument(repoId: UUID, filePath: String) async throws {
        logInfo("Closing document: \(filePath)", category: "DevelopumLSPBridge")

        let connection = try getConnection(for: repoId)

        let uri = AnigmaVirtualURI.documentURI(repoId: repoId, filePath: filePath)

        try await connection.sendNotification(
            .textDocumentDidClose,
            params: DidCloseTextDocumentParams(
                textDocument: TextDocumentIdentifier(uri: uri)
            )
        )

        if let _ = receiptService {
            let inputs: [String: TelemetryValue] = [
                "repoId": .string(repoId.uuidString),
                "filePath": .string(filePath),
                "uri": .string(uri)
            ]
            let inputsHash = TelemetryHash.compute(from: inputs)
            let _ = ReceiptWire.create(
                actionName: "developum.lsp.closeDocument",
                authority: "DevelopumModule",
                decision: .allowed,
                reasonCode: "closed",
                timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
                inputsHash: inputsHash,
                outputsHash: nil,
                previousReceiptHash: nil,
                metadata: inputs
            )
        }
    }

    // MARK: - Semantic Navigation

    public func definition(
        repoId: UUID,
        filePath: String,
        line: Int,
        column: Int
    ) async throws -> [Location] {
        logInfo("Getting definition for \(filePath):\(line):\(column)", category: "DevelopumLSPBridge")

        let connection = try getConnection(for: repoId)

        let uri = AnigmaVirtualURI.documentURI(repoId: repoId, filePath: filePath)
        let params = DefinitionParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            position: Position(line: line, character: column)
        )

        let result: DefinitionResult = try await connection.sendRequest(
            .textDocumentDefinition,
            params: params,
            responseType: DefinitionResult.self
        )

        if let _ = receiptService {
            let inputs: [String: TelemetryValue] = [
                "repoId": .string(repoId.uuidString),
                "filePath": .string(filePath),
                "line": .int(line),
                "column": .int(column),
                "resultCount": .int(result.locations.count)
            ]
            let inputsHash = TelemetryHash.compute(from: inputs)
            let _ = ReceiptWire.create(
                actionName: "developum.lsp.definition",
                authority: "DevelopumModule",
                decision: .allowed,
                reasonCode: "found",
                timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
                inputsHash: inputsHash,
                outputsHash: nil,
                previousReceiptHash: nil,
                metadata: inputs
            )
        }

        return result.locations
    }

    public func references(
        repoId: UUID,
        filePath: String,
        line: Int,
        column: Int,
        includeDeclaration: Bool = true
    ) async throws -> [Location] {
        logInfo("Getting references for \(filePath):\(line):\(column)", category: "DevelopumLSPBridge")

        let connection = try getConnection(for: repoId)

        let uri = AnigmaVirtualURI.documentURI(repoId: repoId, filePath: filePath)
        let params = ReferenceParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            position: Position(line: line, character: column),
            context: ReferenceContext(includeDeclaration: includeDeclaration)
        )

        let locations: [Location] = try await connection.sendRequest(
            .textDocumentReferences,
            params: params,
            responseType: [Location].self
        )

        if let _ = receiptService {
            let inputs: [String: TelemetryValue] = [
                "repoId": .string(repoId.uuidString),
                "filePath": .string(filePath),
                "line": .int(line),
                "column": .int(column),
                "includeDeclaration": .bool(includeDeclaration),
                "resultCount": .int(locations.count)
            ]
            let inputsHash = TelemetryHash.compute(from: inputs)
            let _ = ReceiptWire.create(
                actionName: "developum.lsp.references",
                authority: "DevelopumModule",
                decision: .allowed,
                reasonCode: "found",
                timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
                inputsHash: inputsHash,
                outputsHash: nil,
                previousReceiptHash: nil,
                metadata: inputs
            )
        }

        return locations
    }

    public func hover(
        repoId: UUID,
        filePath: String,
        line: Int,
        column: Int
    ) async throws -> HoverResult? {
        logInfo("Getting hover for \(filePath):\(line):\(column)", category: "DevelopumLSPBridge")

        let connection = try getConnection(for: repoId)

        let uri = AnigmaVirtualURI.documentURI(repoId: repoId, filePath: filePath)
        let params = HoverParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            position: Position(line: line, character: column)
        )

        let result: HoverResult? = try await connection.sendRequest(
            .textDocumentHover,
            params: params,
            responseType: HoverResult?.self
        )

        if let _ = receiptService {
            let inputs: [String: TelemetryValue] = [
                "repoId": .string(repoId.uuidString),
                "filePath": .string(filePath),
                "line": .int(line),
                "column": .int(column),
                "hasContent": .bool(result != nil)
            ]
            let inputsHash = TelemetryHash.compute(from: inputs)
            let _ = ReceiptWire.create(
                actionName: "developum.lsp.hover",
                authority: "DevelopumModule",
                decision: .allowed,
                reasonCode: "queried",
                timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
                inputsHash: inputsHash,
                outputsHash: nil,
                previousReceiptHash: nil,
                metadata: inputs
            )
        }

        return result
    }

    public func completion(
        repoId: UUID,
        filePath: String,
        line: Int,
        column: Int,
        triggerCharacter: String? = nil,
        triggerKind: CompletionTriggerKind = .invoked
    ) async throws -> CompletionResult {
        logInfo("Getting completion for \(filePath):\(line):\(column)", category: "DevelopumLSPBridge")

        let connection = try getConnection(for: repoId)

        let uri = AnigmaVirtualURI.documentURI(repoId: repoId, filePath: filePath)
        let context = triggerCharacter != nil
            ? CompletionContext(triggerKind: triggerKind, triggerCharacter: triggerCharacter)
            : nil
        let params = CompletionParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            position: Position(line: line, character: column),
            context: context
        )

        let result: CompletionResult = try await connection.sendRequest(
            .textDocumentCompletion,
            params: params,
            responseType: CompletionResult.self
        )

        if let _ = receiptService {
            let inputs: [String: TelemetryValue] = [
                "repoId": .string(repoId.uuidString),
                "filePath": .string(filePath),
                "line": .int(line),
                "column": .int(column),
                "itemCount": .int(result.items.count)
            ]
            let inputsHash = TelemetryHash.compute(from: inputs)
            let _ = ReceiptWire.create(
                actionName: "developum.lsp.completion",
                authority: "DevelopumModule",
                decision: .allowed,
                reasonCode: "provided",
                timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
                inputsHash: inputsHash,
                outputsHash: nil,
                previousReceiptHash: nil,
                metadata: inputs
            )
        }

        return result
    }

    public func documentSymbols(repoId: UUID, filePath: String) async throws -> [DocumentSymbol] {
        logInfo("Getting document symbols for \(filePath)", category: "DevelopumLSPBridge")

        let connection = try getConnection(for: repoId)

        let uri = AnigmaVirtualURI.documentURI(repoId: repoId, filePath: filePath)
        let params = DocumentSymbolParams(
            textDocument: TextDocumentIdentifier(uri: uri)
        )

        let symbols: [DocumentSymbol] = try await connection.sendRequest(
            .textDocumentDocumentSymbol,
            params: params,
            responseType: [DocumentSymbol].self
        )

        if let _ = receiptService {
            let inputs: [String: TelemetryValue] = [
                "repoId": .string(repoId.uuidString),
                "filePath": .string(filePath),
                "symbolCount": .int(symbols.count)
            ]
            let inputsHash = TelemetryHash.compute(from: inputs)
            let _ = ReceiptWire.create(
                actionName: "developum.lsp.documentSymbols",
                authority: "DevelopumModule",
                decision: .allowed,
                reasonCode: "queried",
                timestampMs: Int64(Date().timeIntervalSince1970 * 1000),
                inputsHash: inputsHash,
                outputsHash: nil,
                previousReceiptHash: nil,
                metadata: inputs
            )
        }

        return symbols
    }

    // MARK: - Bridge Message Generation

    public func createBridgeMessage(
        sessionId: String,
        repoId: UUID,
        type: DevelopumMessageType,
        payload: LSPBridgePayload
    ) -> LSPBridgeMessage {
        return LSPBridgeMessage(
            type: type,
            sessionId: sessionId,
            repoId: repoId.uuidString,
            payload: payload
        )
    }
}
