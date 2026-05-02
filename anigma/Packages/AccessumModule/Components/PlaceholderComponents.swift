import AnigmaPrimitives

import AnigmaPrimitives

//
//  PlaceholderComponents.swift
//  AccessumModule
//
//  Accessum Components
//
//  Canonical ECS vocabulary for the alt-media (Apertum) engine inside Anigma/Themis.
//  Trimmed to behavior we care about: import → OCR → accessible output, governed by prefs/compliance.
//

import AnigmaCore
import Foundation

// MARK: - Shared enums

public enum DocumentSource: String, Codable, Sendable {
    case upload, scan, `import`, request, download, generated
}

public enum DocumentStatus: String, Codable, Sendable {
    case imported
    case ocrPending
    case ocrRunning
    case ready
    case failed
}

public enum OCRStatus: String, Codable, Sendable {
    case pending = "pending"
    case queued = "queued"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    case skipped = "skipped"
    case cancelled = "cancelled"

    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .queued: return "Queued"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .skipped: return "Skipped"
        case .cancelled: return "Cancelled"
        }
    }
}

public enum OCREngine: String, Codable, Sendable {
    case vision
    case tesseract
    case ocrmypdf
}

public enum OCRPriority: Int, Codable, Sendable, Comparable, Hashable {
    case low = 0
    case normal = 1
    case high = 2
    case urgent = 3

    public static func < (lhs: OCRPriority, rhs: OCRPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var displayName: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
}

public typealias JobPriority = OCRPriority

public enum ReadingMode: String, Codable, Sendable {
    case text
    case audio
    case braille
}

public enum SyncState: String, Codable, Sendable {
    case idle, syncing, error, pending
}

public enum FulfillmentStatus: String, Codable, Sendable {
    case pending, inProgress, completed, failed
}

// MARK: - Core document pipeline

/// Document metadata for alt-media processing.
public struct DocumentComponent: Component, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var source: DocumentSource
    public var path: String
    public var mimeType: String
    public var pageCount: Int
    public var sizeBytes: Int64
    public var hash: String?
    public var language: String
    public var status: DocumentStatus
    public var importedAt: Date
    public var modifiedAt: Date
    public var ocrTextPath: String?
    public var tags: [String]
    public var priority: JobPriority
    // Additional fields from Apertum Accesum
    public var category: String
    public var isSensitive: Bool
    public var ferpaTag: String
    public var createdAt: Date
    public var contentHash: String
    public var fileSize: Int64 { sizeBytes } // computed for compatibility

    public init(
        id: UUID = UUID(),
        title: String,
        source: DocumentSource,
        path: String,
        mimeType: String = "application/pdf",
        pageCount: Int = 0,
        sizeBytes: Int64 = 0,
        hash: String? = nil,
        language: String = "en",
        status: DocumentStatus = .imported,
        importedAt: Date = Date(),
        modifiedAt: Date = Date(),
        ocrTextPath: String? = nil,
        tags: [String] = [],
        priority: JobPriority = .normal,
        category: String = "Uncategorized",
        isSensitive: Bool = false,
        ferpaTag: String = "",
        createdAt: Date? = nil,
        contentHash: String = ""
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.path = path
        self.mimeType = mimeType
        self.pageCount = pageCount
        self.sizeBytes = sizeBytes
        self.hash = hash
        self.language = language
        self.status = status
        self.importedAt = importedAt
        self.modifiedAt = modifiedAt
        self.ocrTextPath = ocrTextPath
        self.tags = tags
        self.priority = priority
        self.category = category
        self.isSensitive = isSensitive
        self.ferpaTag = ferpaTag
        self.createdAt = createdAt ?? importedAt
        self.contentHash = contentHash
    }

    /// Computed property for compatibility with original fileURL
    public var fileURL: URL? {
        guard !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// Whether the document needs OCR processing
    public var needsOCR: Bool {
        ocrTextPath == nil && mimeType == "application/pdf"
    }
}

/// OCR processing state.
public struct OCRStateComponent: Component, Codable, Sendable {
    public var status: OCRStatus
    public var engine: OCREngine
    public var language: String
    public var pagesProcessed: Int
    public var totalPages: Int
    public var startedAt: Date?
    public var completedAt: Date?
    public var confidence: Double
    public var errorMessage: String?
    public var retryCount: Int
    public var maxRetries: Int
    public var extractedTextPath: String?
    // Additional fields from Apertum Accesum
    public var priority: OCRPriority
    public var useAdvancedEngine: Bool
    public var retryAfter: Date?
    public var extractedText: String
    public var processingDuration: TimeInterval
    public var characterCount: Int
    public var wordCount: Int

    public init(
        status: OCRStatus = .pending,
        engine: OCREngine = .vision,
        language: String = "en-US",
        pagesProcessed: Int = 0,
        totalPages: Int = 0,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        confidence: Double = -1,
        errorMessage: String? = nil,
        retryCount: Int = 0,
        maxRetries: Int = 3,
        extractedTextPath: String? = nil,
        priority: OCRPriority = .normal,
        useAdvancedEngine: Bool = true,
        retryAfter: Date? = nil,
        extractedText: String = "",
        processingDuration: TimeInterval = 0,
        characterCount: Int = 0,
        wordCount: Int = 0
    ) {
        self.status = status
        self.engine = engine
        self.language = language
        self.pagesProcessed = pagesProcessed
        self.totalPages = totalPages
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.confidence = confidence
        self.errorMessage = errorMessage
        self.retryCount = retryCount
        self.maxRetries = maxRetries
        self.extractedTextPath = extractedTextPath
        self.priority = priority
        self.useAdvancedEngine = useAdvancedEngine
        self.retryAfter = retryAfter
        self.extractedText = extractedText
        self.processingDuration = processingDuration
        self.characterCount = characterCount
        self.wordCount = wordCount
    }

    public var progress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(pagesProcessed) / Double(totalPages)
    }

    /// Whether OCR processing is complete (success or failure)
    public var isComplete: Bool {
        switch status {
        case .completed, .failed, .skipped, .cancelled:
            return true
        case .pending, .queued, .processing:
            return false
        }
    }

    /// Whether OCR can be retried
    public var canRetry: Bool {
        status == .failed && retryCount < maxRetries
    }
}

/// Reading state/preferences for a document.
public struct ReadingStateComponent: Component, Codable, Sendable {
    public var mode: ReadingMode
    public var lastPage: Int
    public var lastOffset: Double
    public var highlightDuringTTS: Bool
    public var playbackRate: Double

    public init(
        mode: ReadingMode = .text,
        lastPage: Int = 0,
        lastOffset: Double = 0,
        highlightDuringTTS: Bool = true,
        playbackRate: Double = 1.0
    ) {
        self.mode = mode
        self.lastPage = lastPage
        self.lastOffset = lastOffset
        self.highlightDuringTTS = highlightDuringTTS
        self.playbackRate = playbackRate
    }
}

/// Selected OCR engine/config.
public struct OCREngineComponent: Component, Codable, Sendable {
    public var engine: OCREngine
    public var modelVersion: String?
    public var qualityHint: String?

    public init(engine: OCREngine = .vision, modelVersion: String? = nil, qualityHint: String? = nil) {
        self.engine = engine
        self.modelVersion = modelVersion
        self.qualityHint = qualityHint
    }
}

// MARK: - Audio/TTS

public enum AudioStatus: String, Codable, Sendable {
    case pending, generating, ready, failed
}

public struct AudioStateComponent: Component, Codable, Sendable {
    public var status: AudioStatus
    public var voiceId: String?
    public var format: String?
    public var durationSeconds: Double?
    public var outputPath: String?
    public var errorMessage: String?

    public init(
        status: AudioStatus = .pending,
        voiceId: String? = nil,
        format: String? = nil,
        durationSeconds: Double? = nil,
        outputPath: String? = nil,
        errorMessage: String? = nil
    ) {
        self.status = status
        self.voiceId = voiceId
        self.format = format
        self.durationSeconds = durationSeconds
        self.outputPath = outputPath
        self.errorMessage = errorMessage
    }
}

public struct VoicePreferencesComponent: Component, Codable, Sendable {
    public var voiceId: String?
    public var rate: Double
    public var pitch: Double
    public var volume: Double

    public init(voiceId: String? = nil, rate: Double = 1.0, pitch: Double = 0, volume: Double = 1.0) {
        self.voiceId = voiceId
        self.rate = rate
        self.pitch = pitch
        self.volume = volume
    }
}

// MARK: - Identity & prefs

public enum AccessumRole: String, Codable, Sendable {
    case student, staff, admin
}

public struct UserComponent: Component, Codable, Sendable {
    public let userId: UUID
    public var role: AccessumRole
    public var tenantId: String
    public var displayName: String

    public init(userId: UUID, role: AccessumRole, tenantId: String, displayName: String) {
        self.userId = userId
        self.role = role
        self.tenantId = tenantId
        self.displayName = displayName
    }
}

public struct AccessibilityPrefsComponent: Component, Codable, Sendable {
    public var preferredFontSize: Double
    public var highContrast: Bool
    public var dyslexiaFontEnabled: Bool
    public var lineSpacing: Double
    public var preferredFormats: [String]
    public var highlightDuringTTS: Bool
    public var preferredVoiceId: String?
    public var reliesOnAudio: Bool

    public init(
        preferredFontSize: Double = 16,
        highContrast: Bool = false,
        dyslexiaFontEnabled: Bool = false,
        lineSpacing: Double = 1.5,
        preferredFormats: [String] = [],
        highlightDuringTTS: Bool = true,
        preferredVoiceId: String? = nil,
        reliesOnAudio: Bool = false
    ) {
        self.preferredFontSize = preferredFontSize
        self.highContrast = highContrast
        self.dyslexiaFontEnabled = dyslexiaFontEnabled
        self.lineSpacing = lineSpacing
        self.preferredFormats = preferredFormats
        self.highlightDuringTTS = highlightDuringTTS
        self.preferredVoiceId = preferredVoiceId
        self.reliesOnAudio = reliesOnAudio
    }
}

/// Eyzo UI/session state (lightweight).
public struct EyzoStateComponent: Component, Codable, Sendable {
    public var lastViewedDocumentId: UUID?
    public var openPanels: Set<String>
    public var isPreviewMode: Bool

    public init(lastViewedDocumentId: UUID? = nil, openPanels: Set<String> = [], isPreviewMode: Bool = false) {
        self.lastViewedDocumentId = lastViewedDocumentId
        self.openPanels = openPanels
        self.isPreviewMode = isPreviewMode
    }
}

// MARK: - Sync & Compliance

public struct CloudSyncComponent: Component, Codable, Sendable {
    public var state: SyncState
    public var lastSyncedAt: Date?
    public var pendingChanges: Int
    public var errorMessage: String?

    public init(state: SyncState = .idle, lastSyncedAt: Date? = nil, pendingChanges: Int = 0, errorMessage: String? = nil) {
        self.state = state
        self.lastSyncedAt = lastSyncedAt
        self.pendingChanges = pendingChanges
        self.errorMessage = errorMessage
    }
}

public struct ComplianceLogComponent: Component, Codable, Sendable {
    public var lastEvent: String?
    public var lastCheckedAt: Date?
    public var issues: [String]

    public init(lastEvent: String? = nil, lastCheckedAt: Date? = nil, issues: [String] = []) {
        self.lastEvent = lastEvent
        self.lastCheckedAt = lastCheckedAt
        self.issues = issues
    }
}

public struct AuditComponent: Component, Codable, Sendable {
    public var auditId: UUID
    public var severity: String
    public var message: String
    public var createdAt: Date

    public init(auditId: UUID = UUID(), severity: String, message: String, createdAt: Date = Date()) {
        self.auditId = auditId
        self.severity = severity
        self.message = message
        self.createdAt = createdAt
    }
}

public struct FulfillmentComponent: Component, Codable, Sendable {
    public var requestId: UUID
    public var status: FulfillmentStatus
    public var deliveredAt: Date?
    public var deliveryChannel: String?

    public init(
        requestId: UUID,
        status: FulfillmentStatus = .pending,
        deliveredAt: Date? = nil,
        deliveryChannel: String? = nil
    ) {
        self.requestId = requestId
        self.status = status
        self.deliveredAt = deliveredAt
        self.deliveryChannel = deliveryChannel
    }
}
