import Foundation
import CryptoKit

public actor IngestNormalizeSystem {
    private let database: ContextumDatabase
    private let textPreprocessor: TextPreprocessingSystem
    private let maxChunkSize: Int
    private let overlapSize: Int

    public init(database: ContextumDatabase, maxChunkSize: Int = 512, overlapSize: Int = 50) {
        self.database = database
        self.textPreprocessor = TextPreprocessingSystem(useCapsuleFallback: true)
        self.maxChunkSize = maxChunkSize
        self.overlapSize = overlapSize
    }

    public func process(source: ContextSourceComponent) async throws {
        let startTime = Date()
        var outcome: TelemetryEventComponent.Outcome = .success
        var errorCode: String?
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

            let preprocessed = await textPreprocessor.preprocessForStorage(content)

            diagnosticPayload["originalLength"] = String(preprocessed.originalLength)
            diagnosticPayload["processedLength"] = String(preprocessed.processedLength)
            diagnosticPayload["sanitized"] = String(preprocessed.sanitized)
            diagnosticPayload["wordCount"] = String(preprocessed.statistics.wordCount)
            diagnosticPayload["graphemeCount"] = String(preprocessed.statistics.graphemeCount)
            diagnosticPayload["isCapsuleAvailable"] = String(await textPreprocessor.isCapsuleAvailable)

            let normalizedContent = preprocessed.normalizedText
            let data = Data(normalizedContent.utf8)
            let hash = SHA256.hash(data: data)
            let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()

            var chunkComponents: [ChunkComponent] = []
            let chunks = chunkText(normalizedContent)

            for (index, chunkContent) in chunks.enumerated() {
                let chunkData = Data(chunkContent.utf8)
                let chunkHash = SHA256.hash(data: chunkData)
                let chunkHashString = chunkHash.compactMap { String(format: "%02x", $0) }.joined()

                let chunkComponent = ChunkComponent(
                    chunkId: UUID().uuidString,
                    sourceId: source.receiptId,
                    contentHash: chunkHashString,
                    chunkIndex: index,
                    totalChunks: chunks.count,
                    byteRange: 0..<chunkData.count,
                    tokenCount: nil
                )

                try await database.insertChunk(chunkComponent, content: chunkContent)
                chunkComponents.append(chunkComponent)
            }

            diagnosticPayload["chunkCount"] = String(chunks.count)

            let event = TelemetryEventComponent(
                eventId: UUID().uuidString,
                eventType: .ingest,
                receiptId: source.receiptId,
                outcome: .success,
                durationMs: Int(Date().timeIntervalSince(startTime) * 1000),
                diagnosticPayload: diagnosticPayload
            )

            try await database.insertEvent(event)

        } catch {
            outcome = .failure
            errorCode = error.localizedDescription
            diagnosticPayload["error"] = error.localizedDescription
            throw error
        }
    }

    private func chunkText(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }

        let chunkingConfig = TextChunkingConfig(
            targetChunkSize: maxChunkSize,
            minChunkSize: max(64, maxChunkSize / 4),
            maxChunkSize: min(maxChunkSize * 2, 8192),
            windowSize: 48,
            determinismTier: UInt32(ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE)
        )

        do {
            let wrapper = try TextChunkingCapsuleWrapper(config: chunkingConfig)
            let data = Data(text.utf8)
            try wrapper.processBytes(data)
            try wrapper.finalize()

            let chunkData = try wrapper.extractChunks(from: data)

            var stringChunks: [String] = []
            for chunk in chunkData {
                if let chunkString = String(data: chunk, encoding: .utf8) {
                    stringChunks.append(chunkString)
                } else {
                    return fallbackChunkText(text)
                }
            }

            if overlapSize > 0 && stringChunks.count > 1 {
                return applyOverlap(to: stringChunks)
            }

            return stringChunks.isEmpty ? [text] : stringChunks

        } catch {
            return fallbackChunkText(text)
        }
    }

    private func fallbackChunkText(_ text: String) -> [String] {
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
        return await textPreprocessor.preprocessForStorage(text)
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
}
