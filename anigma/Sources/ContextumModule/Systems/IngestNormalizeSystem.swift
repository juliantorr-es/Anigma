import Foundation
import CryptoKit
import TextChunkingCapsule
import ContractsCore
import TelemetryCore
import OSLog

public actor IngestNormalizeSystem {
    private static let logger = Logger(
        subsystem: "com.anigma.ContextumModule",
        category: "IngestNormalizeSystem"
    )
    private let database: ContextumDatabase
    private let textPreprocessor: TextPreprocessingSystem
    private let preprocessingConfiguration: TextPreprocessingConfiguration
    private let maxChunkSize: Int
    private let overlapSize: Int
    private let chunkingConfig: TextChunkingConfig
    private var chunkingCapsule: TextChunkingCapsuleWrapper?

    public init(
        database: ContextumDatabase,
        maxChunkSize: Int = 512,
        overlapSize: Int = 50,
        preprocessingConfiguration: TextPreprocessingConfiguration = .ingestDefault
    ) {
        self.database = database
        self.textPreprocessor = TextPreprocessingSystem(useCapsuleFallback: true)
        self.preprocessingConfiguration = preprocessingConfiguration
        self.maxChunkSize = maxChunkSize
        self.overlapSize = overlapSize
        self.chunkingConfig = TextChunkingConfig(
            targetChunkSize: maxChunkSize,
            minChunkSize: maxChunkSize / 2,
            maxChunkSize: min(maxChunkSize * 2, 8192),
            windowSize: 48,
            determinismTier: 1
        )
        self.chunkingCapsule = try? TextChunkingCapsuleWrapper(config: chunkingConfig)
        if chunkingCapsule == nil {
            Self.logger.warning(
                "Text chunking capsule unavailable during ingest normalization initialization; using legacy line-based chunking"
            )
        }
    }

    public func process(source: ContextSourceComponent) async throws {
        let startTime = Date()
        var diagnosticPayload: [String: String] = [:]

        do {
            guard let content = source.content else {
                let event = TelemetryEventComponent(
                    eventId: UUID().uuidString,
                    eventType: .ingest,
                    receiptId: source.receiptId,
                    outcome: .failure,
                    errorCode: "INGEST_NO_CONTENT",
                    diagnosticPayload: ["reason": "Source content is nil"]
                )
                try await database.insertEvent(event)
                return
            }
            let persistedSource = try await database.upsertResolvedSource(source)

            let preprocessed = await textPreprocessor.preprocessForStorage(content, configuration: preprocessingConfiguration)

            diagnosticPayload["originalLength"] = String(preprocessed.originalLength)
            diagnosticPayload["processedLength"] = String(preprocessed.processedLength)
            diagnosticPayload["sanitized"] = String(preprocessed.sanitized)
            diagnosticPayload["wordCount"] = String(preprocessed.statistics.wordCount)
            diagnosticPayload["graphemeCount"] = String(preprocessed.statistics.graphemeCount)
            if let tokenCount = preprocessed.tokenCount {
                diagnosticPayload["tokenCount"] = String(tokenCount)
            }
            diagnosticPayload["isCapsuleAvailable"] = String(await textPreprocessor.isCapsuleAvailable)

            let normalizedContent = preprocessed.normalizedText
            let rawArtifactHash = persistedSource.artifactHash
            let tokenizerPolicyHash = preprocessingConfiguration
                .tokenizerPolicyFingerprint(sourceType: persistedSource.sourceType)
            let sanitizerPolicyHash = preprocessingConfiguration
                .sanitizerPolicyFingerprint(sourceType: persistedSource.sourceType)
            let preprocessingPolicyHash = preprocessingConfiguration
                .preprocessingPolicyFingerprint(sourceType: persistedSource.sourceType)
            let normalizationHash = stableHash([
                persistedSource.sourceType.rawValue,
                normalizedContent,
                tokenizerPolicyHash,
                sanitizerPolicyHash
            ])
            let chunkerConfigHash = stableHash([
                persistedSource.sourceType.rawValue,
                String(chunkingConfig.targetChunkSize),
                String(chunkingConfig.minChunkSize),
                String(chunkingConfig.maxChunkSize),
                String(chunkingConfig.windowSize),
                String(chunkingConfig.determinismTier),
                String(overlapSize),
                preprocessingPolicyHash
            ])
            
            var chunkComponents: [ChunkComponent] = []
            let chunks = await chunkText(normalizedContent)

            for (index, chunkContent) in chunks.enumerated() {
                let chunkData = Data(chunkContent.utf8)
                let chunkHash = SHA256.hash(data: chunkData)
                let chunkHashString = chunkHash.compactMap { String(format: "%02x", $0) }.joined()

                let chunkComponent = ChunkComponent(
                    chunkId: UUID().uuidString,
                    sourceId: persistedSource.sourceId,
                    contentHash: chunkHashString,
                    chunkIndex: index,
                    totalChunks: chunks.count,
                    byteRange: 0..<chunkData.count,
                    tokenCount: await textPreprocessor.tokenCount(for: chunkContent, policy: preprocessingConfiguration.tokenizationPolicy)
                )

                let boundaryMetadata = ChunkBoundaryMetadata(
                    normalizationForm: preprocessingConfiguration.normalizationForm,
                    sanitized: preprocessed.sanitized,
                    originalLength: preprocessed.originalLength,
                    normalizedLength: normalizedContent.utf8.count,
                    chunkIndex: index,
                    totalChunks: chunks.count,
                    chunkByteRangeStart: 0,
                    chunkByteRangeEnd: chunkData.count,
                    overlapSize: overlapSize,
                    boundaries: preprocessed.boundaries
                )
                let provenance = ChunkIngestProvenance(
                    rawArtifactHash: rawArtifactHash,
                    normalizationHash: normalizationHash,
                    chunkerConfigHash: chunkerConfigHash,
                    tokenizerPolicyHash: tokenizerPolicyHash,
                    sanitizerPolicyHash: sanitizerPolicyHash,
                    boundaryMetadata: boundaryMetadata
                )

                try await database.insertChunk(chunkComponent, content: chunkContent, provenance: provenance)
                chunkComponents.append(chunkComponent)
            }

            diagnosticPayload["chunkCount"] = String(chunks.count)

            let event = TelemetryEventComponent(
                eventId: UUID().uuidString,
                eventType: .ingest,
                receiptId: persistedSource.receiptId,
                durationMs: Int(Date().timeIntervalSince(startTime) * 1000),
                outcome: .success,
                diagnosticPayload: diagnosticPayload
            )

            try await database.insertEvent(event)

        } catch {
            diagnosticPayload["error"] = error.localizedDescription
            throw error
        }
    }

    private func chunkText(_ text: String) async -> [String] {
        guard !text.isEmpty else { return [] }

        let data = Data(text.utf8)

        if let wrapper = chunkingCapsule {
            do {
                try wrapper.reset()
                try wrapper.processBytes(data)
                try wrapper.finalize()

                let chunkData = try await wrapper.extractChunks(from: data)

                var stringChunks: [String] = []
                for chunk in chunkData {
                    if let s = String(data: chunk, encoding: .utf8) {
                        stringChunks.append(s)
                    }
                }

                if overlapSize > 0 && stringChunks.count > 1 {
                    return applyOverlap(to: stringChunks)
                }

                return stringChunks.isEmpty ? [text] : stringChunks
            } catch {
                return fallbackChunkText(
                    text,
                    reason: "capsule_chunking_failed",
                    errorDescription: error.localizedDescription
                )
            }
        }
        return fallbackChunkText(
            text,
            reason: "capsule_unavailable"
        )
    }

    private func fallbackChunkText(
        _ text: String,
        reason: String,
        errorDescription: String? = nil
    ) -> [String] {
        if let errorDescription {
            Self.logger.warning(
                "Using legacy line-based chunking fallback (reason: \(reason, privacy: .public), text_length: \(text.utf8.count, privacy: .public), max_chunk_size: \(self.maxChunkSize, privacy: .public), overlap_size: \(self.overlapSize, privacy: .public), error: \(errorDescription, privacy: .public))"
            )
        } else {
            Self.logger.warning(
                "Using legacy line-based chunking fallback (reason: \(reason, privacy: .public), text_length: \(text.utf8.count, privacy: .public), max_chunk_size: \(self.maxChunkSize, privacy: .public), overlap_size: \(self.overlapSize, privacy: .public))"
            )
        }

        var chunks: [String] = []
        let lines = text.components(separatedBy: .newlines)
        var currentChunk = ""

        for line in lines {
            if (currentChunk + line).count > maxChunkSize, !currentChunk.isEmpty {
                chunks.append(currentChunk)
                currentChunk = String(currentChunk.suffix(overlapSize))
            }
            currentChunk += line + "\n"
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }

        return chunks.isEmpty ? [text] : chunks
    }

    private func applyOverlap(to chunks: [String]) -> [String] {
        guard chunks.count > 1 else { return chunks }

        var overlappedChunks: [String] = []

        for i in 0..<chunks.count {
            var chunk = chunks[i]

            if i > 0 {
                let previousChunk = chunks[i - 1]
                let overlapStart = max(0, previousChunk.count - overlapSize)
                let overlapText = String(previousChunk.suffix(from: previousChunk.index(previousChunk.startIndex, offsetBy: overlapStart)))
                chunk = overlapText + chunk
            }

            if i < chunks.count - 1 {
                let nextChunk = chunks[i + 1]
                let overlapEnd = min(overlapSize, nextChunk.count)
                let overlapText = String(nextChunk.prefix(overlapEnd))
                chunk += overlapText
            }

            overlappedChunks.append(chunk)
        }

        return overlappedChunks
    }

    public func preprocessText(_ text: String) async -> PreprocessedText {
        return await textPreprocessor.preprocessForStorage(text, configuration: preprocessingConfiguration)
    }

    public func normalizeText(_ text: String, form: UnicodeForm = .nfc) async -> String {
        return await textPreprocessor.normalizeText(text, form: form)
    }

    public func detectBoundaries(_ text: String, type: BoundaryType = .word) async -> [TextBoundary] {
        return await textPreprocessor.detectBoundaries(text, type: type)
    }

    public func foldCase(_ text: String, locale: String? = nil) async -> String {
        return await textPreprocessor.foldCase(text, locale: locale)
    }

    public func stripDiacritics(_ text: String) async -> String {
        return await textPreprocessor.stripDiacritics(text)
    }

    public func getTextStatistics(_ text: String) async -> TextStatistics {
        return await textPreprocessor.generateStatistics(text)
    }

    public func validateTextEncoding(_ text: String) async -> Bool {
        return await textPreprocessor.validateUTF8(text)
    }

    private func stableHash(_ parts: [String]) -> String {
        let data = Data(parts.joined(separator: "|").utf8)
        return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
}
