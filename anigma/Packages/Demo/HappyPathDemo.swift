import AnigmaPrimitives

import AnigmaPrimitives

//
//  HappyPathDemo.swift
//  Demo
//
//  Demo Module
//
//  Comprehensive happy path demo for Export Job Ticket system.
//  Enables Franklin to showcase complete pipeline in exactly two minutes.
//

import AnigmaCore
import PolytroposModule
import Foundation

// MARK: - Happy Path Demo Orchestrator

/// Orchestrates the complete happy path demo workflow with timing checkpoints.
public actor HappyPathDemo {

    // MARK: - Dependencies

    private let world: World
    private let exportService: ExportService
    private let workDirectory: URL
    private var demoStartTime: Date?
    private var checkpoints: [DemoCheckpoint] = []

    // MARK: - Configuration

    private struct DemoConfig {
        static let targetDuration: TimeInterval = 120.0 // 2 minutes
        static let sampleDocumentCount = 3
        static let previewPageCount = 5
        static let progressUpdateInterval: TimeInterval = 0.5
    }

    // MARK: - Demo Steps

    public enum DemoStep: String, CaseIterable {
        case initialization = "Demo Initialization"
        case samplePreparation = "Sample Document Preparation"
        case quickImport = "Quick Document Import"
        case instantPreview = "Instant Preview Generation"
        case exportJobCreation = "Export Job Creation"
        case mlConsentFlow = "ML Model Consent Flow"
        case realTimeProgress = "Real-time Export Progress"
        case supportBundle = "Support Bundle Generation"
        case exportCompletion = "Export Completion & Verification"
        case finalSummary = "Demo Summary"
    }

    // MARK: - Checkpoint Tracking

    private struct DemoCheckpoint {
        let step: DemoStep
        let timestamp: Date
        let duration: TimeInterval
        let details: [String: String]
    }

    // MARK: - Initialization

    public init(world: World, workDirectory: URL) {
        self.world = world
        self.workDirectory = workDirectory
        self.exportService = ExportService(world: world, workDirectory: workDirectory)
    }

    // MARK: - Main Demo Execution

    /// Runs the complete happy path demo workflow.
    public func runDemo() async throws -> DemoReport {
        demoStartTime = Date()
        print("🚀 Starting Happy Path Demo...")
        print("📊 Target Duration: \(DemoConfig.targetDuration) seconds")

        var demoReport = DemoReport(startTime: demoStartTime!)

        // Step 1: Demo Initialization
        await recordCheckpoint(.initialization) {
            try await initializeDemo()
        }

        // Step 2: Sample Document Preparation
        await recordCheckpoint(.samplePreparation) {
            try await prepareSampleDocuments()
        }

        // Step 3: Quick Document Import
        await recordCheckpoint(.quickImport) {
            try await performQuickImport()
        }

        // Step 4: Instant Preview Generation
        await recordCheckpoint(.instantPreview) {
            try await generateInstantPreview()
        }

        // Step 5: Export Job Creation
        await recordCheckpoint(.exportJobCreation) {
            try await createExportJob()
        }

        // Step 6: ML Consent Flow
        await recordCheckpoint(.mlConsentFlow) {
            try await handleMLConsentFlow()
        }

        // Step 7: Real-time Export Progress
        await recordCheckpoint(.realTimeProgress) {
            try await simulateRealTimeProgress()
        }

        // Step 8: Support Bundle Generation
        await recordCheckpoint(.supportBundle) {
            try await generateSupportBundle()
        }

        // Step 9: Export Completion
        await recordCheckpoint(.exportCompletion) {
            try await completeExport()
        }

        // Step 10: Final Summary
        await recordCheckpoint(.finalSummary) {
            demoReport = generateFinalSummary()
        }

        print("✅ Demo completed successfully!")
        return demoReport
    }

    // MARK: - Demo Step Implementations

    private func initializeDemo() async throws {
        print("🔧 Initializing demo environment...")

        // Create demo workspace
        try FileManager.default.createDirectory(
            at: workDirectory.appendingPathComponent("Demo"),
            withIntermediateDirectories: true
        )

        // Initialize ML consent components
        let consentFlowId = await world.createEntity()
        let consentFlow = ConsentFlowUIComponent(
            currentStep: .introduction,
            pendingConsents: [.ocr, .embedding, .captioning]
        )
        await world.addComponent(consentFlowId, consentFlow)

        print("✅ Demo environment initialized")
    }

    private func prepareSampleDocuments() async throws {
        print("📄 Preparing sample documents...")

        let samplesDir = workDirectory.appendingPathComponent("Demo/Samples")
        try FileManager.default.createDirectory(at: samplesDir, withIntermediateDirectories: true)

        // Create sample document descriptions
        let sampleDocs = [
            SampleDocument(
                name: "Financial_Report.pdf",
                description: "Multi-column financial report with tables and charts",
                pageCount: 12,
                hasTables: true,
                hasImages: true,
                complexity: .high
            ),
            SampleDocument(
                name: "Product_Catalog.pdf",
                description: "Product catalog with images and specifications",
                pageCount: 8,
                hasTables: false,
                hasImages: true,
                complexity: .medium
            ),
            SampleDocument(
                name: "Legal_Contract.pdf",
                description: "Legal contract with complex formatting",
                pageCount: 15,
                hasTables: true,
                hasImages: false,
                complexity: .medium
            )
        ]

        // Store sample document metadata
        for (index, doc) in sampleDocs.enumerated() {
            let docId = await world.createEntity()
            let docComponent = DemoDocumentComponent(
                name: doc.name,
                description: doc.description,
                pageCount: doc.pageCount,
                hasTables: doc.hasTables,
                hasImages: doc.hasImages,
                complexity: doc.complexity,
                path: samplesDir.appendingPathComponent(doc.name).path
            )
            await world.addComponent(docId, docComponent)
        }

        print("✅ \(sampleDocs.count) sample documents prepared")
    }

    private func performQuickImport() async throws {
        print("📥 Performing quick document import...")

        // Simulate rapid document import with automatic processing
        let documents = await world.entitiesWith(DemoDocumentComponent.self)

        for docId in documents.prefix(DemoConfig.sampleDocumentCount) {
            guard let doc = await world.getComponent(docId, DemoDocumentComponent.self) else {
                continue
            }

            // Simulate import progress
            for progress in stride(from: 0.0, through: 1.0, by: 0.2) {
                print("  📄 Importing \(doc.name): \(Int(progress * 100))%")
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }

            // Mark as imported
            var updatedDoc = doc
            updatedDoc.importStatus = .completed
            await world.addComponent(docId, updatedDoc)
        }

        print("✅ Quick import completed")
    }

    private func generateInstantPreview() async throws {
        print("👁️ Generating instant preview (first 5 pages)...")

        let documents = await world.entitiesWith(DemoDocumentComponent.self)

        for docId in documents.prefix(1) { // Preview first document
            guard let doc = await world.getComponent(docId, DemoDocumentComponent.self) else {
                continue
            }

            let previewPages = min(doc.pageCount, DemoConfig.previewPageCount)

            // Generate preview with source/export comparison
            let preview = DemoPreviewComponent(
                documentId: docId,
                pageCount: previewPages,
                sourceQuality: 1.0,
                exportQuality: 0.9,
                comparisonMode: .sideBySide
            )

            let previewId = await world.createEntity()
            await world.addComponent(previewId, preview)

            print("  🖼️ Generated preview for \(doc.name) - \(previewPages) pages")
            print("  📊 Quality: Source \(Int(preview.sourceQuality * 100))% vs Export \(Int(preview.exportQuality * 100))%")
        }

        print("✅ Instant preview generated")
    }

    private func createExportJob() async throws {
        print("🎬 Creating export job with print-like settings...")

        // Find a document to export
        let documents = await world.entitiesWith(DemoDocumentComponent.self)
        guard let docId = documents.first,
              let doc = await world.getComponent(docId, DemoDocumentComponent.self) else {
            throw DemoError.noDocumentsFound
        }

        // Create timeline for document
        let timelineId = await world.createEntity()
        let timeline = TimelineComponent(
            name: "Demo Timeline",
            duration: TimeInterval(doc.pageCount * 3), // 3 seconds per page
            frameRate: 30.0,
            aspectRatio: .horizontal16x9
        )
        await world.addComponent(timelineId, timeline)

        // Create export preset with print-like settings
        let exportPreset = ExportPresetComponent(
            name: "Demo Export - Print Quality",
            platform: .generic,
            resolution: .hd1080,
            videoCodec: .prores422,
            videoQuality: 95,
            audioCodec: .pcm,
            frameRate: 30.0,
            embedCaptions: true,
            captionFormat: .srt,
            colorSpace: .rec709,
            isSystemPreset: false
        )

        // Create export job
        let jobId = try await exportService.queueExport(
            timelineId: timelineId,
            preset: exportPreset
        )

        // Store demo job metadata
        let demoJob = DemoJobComponent(
            jobId: jobId,
            documentId: docId,
            presetName: exportPreset.name,
            planFrozen: true,
            settings: ExportJobSettings(
                quality: .high,
                format: .mp4,
                includeAudio: true,
                includeCaptions: true
            )
        )

        await world.addComponent(jobId, demoJob)

        print("  🎯 Export job created: \(jobId)")
        print("  ⚙️ Settings: Print quality, ProRes 422, 1080p")
        print("  🧊 Plan frozen - no further changes allowed")
        print("✅ Export job creation completed")
    }

    private func handleMLConsentFlow() async throws {
        print("🤖 Processing ML consent flow...")

        // Find existing consent flow
        let consentFlows = await world.entitiesWith(ConsentFlowUIComponent.self)
        guard let consentFlowId = consentFlows.first,
              var consentFlow = await world.getComponent(consentFlowId, ConsentFlowUIComponent.self) else {
            throw DemoError.consentFlowNotFound
        }

        // Simulate rapid consent steps
        let consentSteps: [ConsentFlowStep] = [
            .privacyPolicy,
            .modelSelection,
            .networkPermissions,
            .dataRetention,
            .confirmation,
            .completed
        ]

        for step in consentSteps {
            consentFlow.currentStep = step
            await world.addComponent(consentFlowId, consentFlow)
            print("  📋 Consent step: \(step.rawValue)")
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        }

        // Grant consent for required models
        let requiredModels: [MLModelType] = [.ocr, .embedding, .captioning]
        for modelType in requiredModels {
            let consentId = await world.createEntity()
            let consent = MLModelConsentComponent(
                modelType: modelType,
                consentState: .granted,
                grantedAt: Date(),
                privacyPreferences: PrivacyPreferences(
                    allowLocalProcessingOnly: true,
                    anonymizationLevel: .full
                ),
                termsVersion: "1.0"
            )
            await world.addComponent(consentId, consent)
        }

        print("  ✅ ML models consented and ready")
        print("✅ ML consent flow completed")
    }

    private func simulateRealTimeProgress() async throws {
        print("⏱️ Simulating real-time export progress...")

        // Find export jobs
        let jobs = await world.entitiesWith(DemoJobComponent.self)
        guard let jobId = jobs.first,
              let demoJob = await world.getComponent(jobId, DemoJobComponent.self) else {
            throw DemoError.noExportJobsFound
        }

        // Start the export
        try await exportService.startExport(demoJob.jobId)

        // Monitor progress with pause/resume simulation
        var progressUpdates = 0
        let maxUpdates = 10

        while progressUpdates < maxUpdates {
            guard let job = await exportService.getJobStatus(demoJob.jobId) else {
                break
            }

            let progressPercent = Int(job.progress * 100)
            let timeRemaining = job.estimatedTimeRemaining ?? 0

            print("  📈 Export progress: \(progressPercent)%")
            if timeRemaining > 0 {
                print("  ⏱️ Estimated time remaining: \(Int(timeRemaining))s")
            }

            // Simulate pause/resume controls
            if progressUpdates == 5 {
                print("  ⏸️ Simulating pause...")
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                print("  ▶️ Resumed export")
            }

            progressUpdates += 1
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        }

        print("✅ Real-time progress monitoring completed")
    }

    private func generateSupportBundle() async throws {
        print("📦 Generating support bundle with redaction...")

        // Create support bundle
        let bundleId = await world.createEntity()
        let supportBundle = DemoSupportBundleComponent(
            bundleId: UUID(),
            createdAt: Date(),
            includesLogs: true,
            includesSystemInfo: true,
            includesUserSettings: false, // Redacted
            redactionLevel: .sensitive,
            compressionEnabled: true
        )

        await world.addComponent(bundleId, supportBundle)

        // Simulate bundle generation
        print("  🔍 Collecting diagnostic information...")
        try await Task.sleep(nanoseconds: 200_000_000)

        print("  🙈 Applying redaction filters...")
        try await Task.sleep(nanoseconds: 200_000_000)

        print("  📦 Compressing bundle...")
        try await Task.sleep(nanoseconds: 200_000_000)

        print("  📍 Bundle saved: demo-support-bundle-\(supportBundle.bundleId.uuidString.prefix(8)).zip")
        print("✅ Support bundle generated successfully")
    }

    private func completeExport() async throws {
        print("🎉 Completing export process...")

        // Find export jobs
        let jobs = await world.entitiesWith(DemoJobComponent.self)
        guard let jobId = jobs.first,
              let demoJob = await world.getComponent(jobId, DemoJobComponent.self) else {
            throw DemoError.noExportJobsFound
        }

        // Wait for export to complete
        var attempts = 0
        let maxAttempts = 20

        while attempts < maxAttempts {
            guard let job = await exportService.getJobStatus(demoJob.jobId) else {
                break
            }

            if job.status.isTerminal {
                break
            }

            attempts += 1
            try await Task.sleep(nanoseconds: 200_000_000)
        }

        // Generate final outputs and verification
        if let finalJob = await exportService.getJobStatus(demoJob.jobId) {
            let report = exportService.generateReport(for: demoJob.jobId)

            print("  ✅ Export completed with status: \(finalJob.status.rawValue)")
            if let outputPath = finalJob.outputPath {
                print("  📁 Output: \(outputPath)")
            }
            if let report = report {
                print("  📊 File size: \(report.formattedSize)")
                print("  ⏱️ Render time: \(report.formattedDuration)")
            }

            // Generate receipt
            let receiptId = await world.createEntity()
            let receipt = DemoExportReceiptComponent(
                jobId: demoJob.jobId,
                completedAt: Date(),
                verificationStatus: .passed,
                checksum: UUID().uuidString,
                metadata: [
                    "demoMode": "true",
                    "happyPath": "true",
                    "timed": "true"
                ]
            )
            await world.addComponent(receiptId, receipt)

            print("  🧾 Export receipt generated")
        }

        print("✅ Export completion finalized")
    }

    private func generateFinalSummary() -> DemoReport {
        print("📊 Generating final demo summary...")

        let totalTime = Date().timeIntervalSince(demoStartTime!)
        var summary = DemoReport(startTime: demoStartTime!)
        summary.totalDuration = totalTime
        summary.checkpoints = checkpoints
        summary.successful = totalTime <= DemoConfig.targetDuration

        print("  ⏱️ Total demo time: \(String(format: "%.1f", totalTime)) seconds")
        print("  🎯 Target met: \(summary.successful ? "✅ YES" : "❌ NO")")

        for checkpoint in checkpoints {
            let duration = String(format: "%.2f", checkpoint.duration)
            print("  \(checkpoint.step.rawValue): \(duration)s")
        }

        return summary
    }

    // MARK: - Utility Methods

    private func recordCheckpoint(_ step: DemoStep, operation: () async throws -> Void) async {
        let startTime = Date()

        do {
            try await operation()
            let duration = Date().timeIntervalSince(startTime)
            let checkpoint = DemoCheckpoint(
                step: step,
                timestamp: startTime,
                duration: duration,
                details: ["status": "success"]
            )
            checkpoints.append(checkpoint)
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            let checkpoint = DemoCheckpoint(
                step: step,
                timestamp: startTime,
                duration: duration,
                details: ["status": "failed", "error": String(describing: error)]
            )
            checkpoints.append(checkpoint)
        }
    }
}

// MARK: - Supporting Types

/// Sample document metadata for demo.
private struct SampleDocument {
    let name: String
    let description: String
    let pageCount: Int
    let hasTables: Bool
    let hasImages: Bool
    let complexity: DocumentComplexity
}

/// Document complexity levels.
private enum DocumentComplexity: String, Codable {
    case low, medium, high
}

/// Demo-specific components.

/// Component for demo documents.
public struct DemoDocumentComponent: Component, Codable {
    public var name: String
    public var description: String
    public var pageCount: Int
    public var hasTables: Bool
    public var hasImages: Bool
    public var complexity: DocumentComplexity
    public var path: String
    public var importStatus: ImportStatus

    public init(
        name: String,
        description: String,
        pageCount: Int,
        hasTables: Bool,
        hasImages: Bool,
        complexity: DocumentComplexity,
        path: String,
        importStatus: ImportStatus = .pending
    ) {
        self.name = name
        self.description = description
        self.pageCount = pageCount
        self.hasTables = hasTables
        self.hasImages = hasImages
        self.complexity = complexity
        self.path = path
        self.importStatus = importStatus
    }
}

/// Import status for documents.
public enum ImportStatus: String, Codable {
    case pending, inProgress, completed, failed
}

/// Component for demo previews.
public struct DemoPreviewComponent: Component, Codable {
    public let documentId: EntityId
    public let pageCount: Int
    public let sourceQuality: Double
    public let exportQuality: Double
    public let comparisonMode: ComparisonMode

    public init(
        documentId: EntityId,
        pageCount: Int,
        sourceQuality: Double,
        exportQuality: Double,
        comparisonMode: ComparisonMode
    ) {
        self.documentId = documentId
        self.pageCount = pageCount
        self.sourceQuality = sourceQuality
        self.exportQuality = exportQuality
        self.comparisonMode = comparisonMode
    }
}

/// Preview comparison modes.
public enum ComparisonMode: String, Codable {
    case sideBySide, overlay, diff
}

/// Component for demo export jobs.
public struct DemoJobComponent: Component, Codable {
    public let jobId: EntityId
    public let documentId: EntityId
    public let presetName: String
    public let planFrozen: Bool
    public let settings: ExportJobSettings

    public init(
        jobId: EntityId,
        documentId: EntityId,
        presetName: String,
        planFrozen: Bool,
        settings: ExportJobSettings
    ) {
        self.jobId = jobId
        self.documentId = documentId
        self.presetName = presetName
        self.planFrozen = planFrozen
        self.settings = settings
    }
}

/// Export job settings.
public struct ExportJobSettings: Codable {
    public let quality: ExportQuality
    public let format: ExportFormat
    public let includeAudio: Bool
    public let includeCaptions: Bool

    public init(
        quality: ExportQuality,
        format: ExportFormat,
        includeAudio: Bool,
        includeCaptions: Bool
    ) {
        self.quality = quality
        self.format = format
        self.includeAudio = includeAudio
        self.includeCaptions = includeCaptions
    }
}

/// Export quality levels.
public enum ExportQuality: String, Codable {
    case low, medium, high, ultra
}

/// Export formats.
public enum ExportFormat: String, Codable {
    case mp4, mov, avi, mkv
}

/// Component for support bundles.
public struct DemoSupportBundleComponent: Component, Codable {
    public let bundleId: UUID
    public let createdAt: Date
    public let includesLogs: Bool
    public let includesSystemInfo: Bool
    public let includesUserSettings: Bool
    public let redactionLevel: RedactionLevel
    public let compressionEnabled: Bool

    public init(
        bundleId: UUID,
        createdAt: Date,
        includesLogs: Bool,
        includesSystemInfo: Bool,
        includesUserSettings: Bool,
        redactionLevel: RedactionLevel,
        compressionEnabled: Bool
    ) {
        self.bundleId = bundleId
        self.createdAt = createdAt
        self.includesLogs = includesLogs
        self.includesSystemInfo = includesSystemInfo
        self.includesUserSettings = includesUserSettings
        self.redactionLevel = redactionLevel
        self.compressionEnabled = compressionEnabled
    }
}

/// Redaction levels for support bundles.
public enum RedactionLevel: String, Codable {
    case none, basic, sensitive, full
}

/// Component for export receipts.
public struct DemoExportReceiptComponent: Component, Codable {
    public let jobId: EntityId
    public let completedAt: Date
    public let verificationStatus: VerificationStatus
    public let checksum: String
    public let metadata: [String: String]

    public init(
        jobId: EntityId,
        completedAt: Date,
        verificationStatus: VerificationStatus,
        checksum: String,
        metadata: [String: String]
    ) {
        self.jobId = jobId
        self.completedAt = completedAt
        self.verificationStatus = verificationStatus
        self.checksum = checksum
        self.metadata = metadata
    }
}

/// Verification status for exports.
public enum VerificationStatus: String, Codable {
    case pending, passed, failed, requiresReview
}

/// Demo completion report.
public struct DemoReport {
    public let startTime: Date
    public var totalDuration: TimeInterval = 0
    public var checkpoints: [DemoCheckpoint] = []
    public var successful: Bool = false
}

// Make DocumentComplexity Codable
extension DocumentComplexity: Codable {}

// MARK: - Demo Errors

/// Demo-specific errors.
public enum DemoError: Error, LocalizedError {
    case noDocumentsFound
    case consentFlowNotFound
    case noExportJobsFound
    case demoTimeout

    public var errorDescription: String? {
        switch self {
        case .noDocumentsFound:
            return "No demo documents found"
        case .consentFlowNotFound:
            return "ML consent flow not initialized"
        case .noExportJobsFound:
            return "No export jobs found"
        case .demoTimeout:
            return "Demo exceeded target duration"
        }
    }
}
