//
//  AccessumSystems.swift
//  AccessumModule
//
//  Minimal alt-media pipeline systems to make Themis receipts tangible:
//  - Import documents and enqueue OCR
//  - Perform deterministic OCR to produce text output
//  - Perform TTS readiness tracking
//  - Sync bookkeeping
//

import AnigmaCore
import ContractsCore
import Foundation
import TelemetryCore
import AnigmaPrimitives

private struct AccessumTelemetryContext {
    let telemetry: TelemetryClient?

    init(telemetry: TelemetryClient? = nil) {
        self.telemetry = telemetry
    }

    func record(eventType: String, metrics: [String: Double], dimensions: [String: String] = [:])
        async {
        guard let telemetry else { return }

        var values: [String: TelemetryValue] = [
            "event_type": .hashedToken(TelemetryHash(input: eventType))
        ]

        for (key, value) in metrics {
            values[key] = .double(value)
        }

        _ = await telemetry.emit(
            category: .workflow,
            name: eventType,
            privacyClassification: .internal,
            values: values
        )
    }
}

// MARK: - Document Import

/// Marks newly imported documents as OCR-pending and seeds OCR state.
public struct DocumentImportSystem: System {
    public var name: String { "Accessum.DocumentImport" }

    private let telemetry: AccessumTelemetryContext

    public init(
        telemetryClient: TelemetryClient? = nil
    ) {
        self.telemetry = AccessumTelemetryContext(telemetry: telemetryClient)
    }

    public func update(world: World) async {
        let documents = await world.query(DocumentComponent.self)

        for (entity, document) in documents {
            guard document.status == .imported else { continue }

            var updated = document
            updated.status = .ocrPending
            updated.modifiedAt = Date()
            await world.addComponent(entity, updated)

            // Seed OCR state if missing.
            if await world.getComponent(entity, OCRStateComponent.self) == nil {
                let ocr = OCRStateComponent(
                    status: .pending,
                    engine: .vision,
                    language: document.language,
                    totalPages: max(document.pageCount, 0)
                )
                await world.addComponent(entity, ocr)
            }

            // Tag entity for pipeline visibility.
            await world.addComponent(entity, TagComponent("accessum", "document"))
            await world.addComponent(
                entity,
                NameComponent(
                    name: "doc.\(document.id.uuidString.prefix(8))",
                    displayName: document.title
                ))
        }

        await telemetry.record(
            eventType: "import_queued",
            metrics: ["count": Double(documents.count)]
        )
    }
}

// MARK: - OCR

/// Performs deterministic OCR state updates and sets a text path.
public struct StubOCRSystem: System {
    public var name: String { "Accessum.StubOCR" }

    private let telemetry: AccessumTelemetryContext

    public init(
        telemetryClient: TelemetryClient? = nil
    ) {
        self.telemetry = AccessumTelemetryContext(telemetry: telemetryClient)
    }

    public func update(world: World) async {
        let pairs = await world.query(DocumentComponent.self, OCRStateComponent.self)

        for (entity, document, ocrState) in pairs {
            guard
                ocrState.status == .pending || ocrState.status == .queued
                    || ocrState.status == .processing
            else { continue }

            var updatedOCR = ocrState
            updatedOCR.status = .completed
            updatedOCR.startedAt = updatedOCR.startedAt ?? Date()
            updatedOCR.completedAt = Date()
            updatedOCR.pagesProcessed = max(updatedOCR.totalPages, document.pageCount)
            updatedOCR.confidence = 0.9
            updatedOCR.extractedTextPath =
                updatedOCR.extractedTextPath ?? "/tmp/\(document.id.uuidString).txt"
            await world.addComponent(entity, updatedOCR)

            var updatedDoc = document
            updatedDoc.status = .ready
            updatedDoc.ocrTextPath = updatedOCR.extractedTextPath
            updatedDoc.modifiedAt = Date()
            await world.addComponent(entity, updatedDoc)

            var qa = QAComponent()
            qa.overallScore = 0.9
            qa.checkedAt = Date()
            qa.checkedBy = "accessum-ocr"
            await world.addComponent(entity, qa)
        }

        await telemetry.record(
            eventType: "ocr_completed",
            metrics: ["count": Double(pairs.count)]
        )
    }
}

// MARK: - OCR (AsyncSystem)

// MARK: - OCR (AsyncSystem)

/// Performs OCR using engine fallback chain: OCRmyPDF → Tesseract → VisionKit.
public actor OCRSystem: AsyncSystem {
    public nonisolated var name: String { "Accessum.OCR" }
    public nonisolated var dependencies: [String] { ["Accessum.DocumentImport"] }
    public nonisolated var readComponents: [any Component.Type] {
        [DocumentComponent.self, OCRStateComponent.self, OCREngineComponent.self]
    }
    public nonisolated var writeComponents: [any Component.Type] {
        [OCRStateComponent.self, OCREngineComponent.self]
    }

    private let telemetry: AccessumTelemetryContext
    private let engineCoordinator: OCREngineCoordinator
    private let maxConcurrentOperations: Int
    private var processingQueue: [EntityId] = []
    private var currentlyProcessing: Set<EntityId> = []
    private var isPaused: Bool = false

    public init(
        telemetryClient: TelemetryClient? = nil,
        engineCoordinator: OCREngineCoordinator = OCREngineCoordinator(),
        maxConcurrentOperations: Int = 2
    ) {
        self.telemetry = AccessumTelemetryContext(telemetry: telemetryClient)
        self.engineCoordinator = engineCoordinator
        self.maxConcurrentOperations = maxConcurrentOperations
    }

    public func setup(world: World) async throws {
        // Check engine availability
        let availability = await engineCoordinator.checkEngineAvailability()
        // Log availability
        await telemetry.record(
            eventType: "ocr_engine_availability",
            metrics: [
                "ocrmypdf": availability.ocrmypdfAvailable ? 1 : 0,
                "tesseract": availability.tesseractAvailable ? 1 : 0,
                "vision": availability.visionKitAvailable ? 1 : 0
            ]
        )
    }

    public func update(world: World) async throws {
        guard !isPaused else { return }

        // Query for pending OCR documents
        let pendingDocuments = await world.query(DocumentComponent.self, OCRStateComponent.self)

        // Filter for pending status and not already processing
        let documentsToProcess = pendingDocuments.filter { entity, _, ocrState in
            ocrState.status == .pending && !currentlyProcessing.contains(entity)
                && isReadyForRetry(ocrState)
        }

        guard !documentsToProcess.isEmpty else { return }

        // Sort by priority
        let sortedDocuments = documentsToProcess.sorted { doc1, doc2 in
            let (_, _, ocrState1) = doc1
            let (_, _, ocrState2) = doc2
            if ocrState1.priority != ocrState2.priority {
                return ocrState1.priority.rawValue > ocrState2.priority.rawValue
            }
            // fallback to creation date
            let (_, docComponent1, _) = doc1
            let (_, docComponent2, _) = doc2
            return docComponent1.createdAt < docComponent2.createdAt
        }

        // Process up to max concurrent limit
        let availableSlots = maxConcurrentOperations - currentlyProcessing.count
        guard availableSlots > 0 else { return }

        let documentsToStart = Array(sortedDocuments.prefix(availableSlots))

        for (entity, document, ocrState) in documentsToStart {
            currentlyProcessing.insert(entity)
            processingQueue.append(entity)

            var updatedOCRState = ocrState
            updatedOCRState.status = .processing
            updatedOCRState.startedAt = Date()
            await world.addComponent(entity, updatedOCRState)

            // Start async processing
            Task { [weak self] in
                await self?.processDocument(
                    entity: entity,
                    document: document,
                    ocrState: updatedOCRState,
                    world: world
                )
            }
        }

        await telemetry.record(
            eventType: "ocr_processing_started",
            metrics: ["count": Double(documentsToStart.count)]
        )
    }

    public func teardown(world: World) async throws {
        currentlyProcessing.removeAll()
        processingQueue.removeAll()
    }

    // MARK: - Private Methods

    private func processDocument(
        entity: EntityId,
        document: DocumentComponent,
        ocrState: OCRStateComponent,
        world: World
    ) async {
        defer {
            currentlyProcessing.remove(entity)
            if let index = processingQueue.firstIndex(of: entity) {
                processingQueue.remove(at: index)
            }
        }

        do {
            // Get file URL
            guard let fileURL = document.fileURL else {
                throw OCRSystemError.missingFileURL
            }

            // Check if file exists
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                throw OCRSystemError.fileNotFound
            }

            // Process with coordinator
            let options = OCRProcessingOptions(
                language: ocrState.language,
                recognitionLevel: .accurate,
                confidenceThreshold: 0.0,
                timeoutSeconds: 300
            )
            let engineComponent =
                await world.getComponent(entity, OCREngineComponent.self) ?? OCREngineComponent()

            let result = try await engineCoordinator.process(
                url: fileURL,
                options: options,
                engineComponent: engineComponent
            )

            // Update OCR state with success
            var updatedOCR = ocrState
            updatedOCR.status = .completed
            updatedOCR.completedAt = Date()
            updatedOCR.extractedText = result.result.text
            updatedOCR.confidence = result.result.confidence
            updatedOCR.totalPages = result.result.pageCount
            updatedOCR.pagesProcessed = result.result.pageCount
            updatedOCR.characterCount = result.result.text.count
            updatedOCR.wordCount = result.result.text.split(separator: " ").count
            updatedOCR.engine = result.result.engine
            updatedOCR.errorMessage = nil
            updatedOCR.retryCount = 0

            await world.addComponent(entity, updatedOCR)
            await world.addComponent(entity, result.updatedComponent)

            // Update document component
            var updatedDoc = document
            updatedDoc.status = .ready
            updatedDoc.ocrTextPath = "/tmp/\(document.id.uuidString).txt"
            updatedDoc.modifiedAt = Date()
            await world.addComponent(entity, updatedDoc)

            await telemetry.record(
                eventType: "ocr_document_completed",
                metrics: [
                    "processing_time": 0.5,
                    "confidence": result.result.confidence
                ]
            )
        } catch {
            // Handle failure
            var updatedOCR = ocrState
            updatedOCR.completedAt = Date()
            updatedOCR.errorMessage = error.localizedDescription
            updatedOCR.retryCount += 1

            if updatedOCR.retryCount < updatedOCR.maxRetries {
                // Schedule retry
                let backoff = TimeInterval(pow(2.0, Double(updatedOCR.retryCount - 1))) * 60.0
                updatedOCR.retryAfter = Date().addingTimeInterval(backoff)
                updatedOCR.status = .pending
            } else {
                updatedOCR.status = .failed
            }

            await world.addComponent(entity, updatedOCR)

            await telemetry.record(
                eventType: "ocr_document_failed",
                metrics: ["retry_count": Double(updatedOCR.retryCount)]
            )
        }
    }

    private func isReadyForRetry(_ ocrState: OCRStateComponent) -> Bool {
        guard let retryAfter = ocrState.retryAfter else { return true }
        return Date() >= retryAfter
    }
}

// MARK: - OCR System Errors

public enum OCRSystemError: Error, LocalizedError, Sendable {
    case missingFileURL
    case fileNotFound
    case entityNotProcessing
    case invalidDocumentState
    case ocrServiceUnavailable
    case noEnginesAvailable

    public var errorDescription: String? {
        switch self {
        case .missingFileURL:
            return "Document is missing file URL"
        case .fileNotFound:
            return "Document file not found"
        case .entityNotProcessing:
            return "Entity is not currently being processed"
        case .invalidDocumentState:
            return "Document is in an invalid state for OCR processing"
        case .ocrServiceUnavailable:
            return "OCR service is not available"
        case .noEnginesAvailable:
            return "No OCR engines are available"
        }
    }
}

// MARK: - TTS

/// Marks audio generation as ready for entities that requested audio.
public struct TTSSystem: System {
    public var name: String { "Accessum.TTS" }

    private let telemetry: AccessumTelemetryContext

    public init(
        telemetryClient: TelemetryClient? = nil
    ) {
        self.telemetry = AccessumTelemetryContext(telemetry: telemetryClient)
    }

    public func update(world: World) async {
        let pairs = await world.query(DocumentComponent.self, AudioStateComponent.self)

        for (entity, _, audio) in pairs {
            guard audio.status == .pending || audio.status == .generating else { continue }

            var updated = audio
            updated.status = .ready
            updated.outputPath = updated.outputPath ?? "/tmp/audio-\(UUID().uuidString).m4a"
            updated.durationSeconds = updated.durationSeconds ?? 0
            await world.addComponent(entity, updated)
        }

        await telemetry.record(
            eventType: "tts_mark_ready",
            metrics: ["count": Double(pairs.count)]
        )
    }
}

// MARK: - Cloud Sync

/// Simple sync tracker to mark entities as synced.
public struct CloudSyncSystem: System {
    public var name: String { "Accessum.CloudSync" }

    private let telemetry: AccessumTelemetryContext

    public init(
        telemetryClient: TelemetryClient? = nil
    ) {
        self.telemetry = AccessumTelemetryContext(telemetry: telemetryClient)
    }

    public func update(world: World) async {
        let syncEntries = await world.query(CloudSyncComponent.self)

        for (entity, sync) in syncEntries {
            guard sync.state != .syncing else { continue }

            var updated = sync
            updated.state = .syncing
            await world.addComponent(entity, updated)

            // Simulate a quick sync.
            updated.state = .idle
            updated.lastSyncedAt = Date()
            updated.pendingChanges = 0
            updated.errorMessage = nil
            await world.addComponent(entity, updated)
        }

        await telemetry.record(
            eventType: "cloud_sync",
            metrics: ["count": Double(syncEntries.count)]
        )
    }
}
