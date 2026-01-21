import Combine
import ContractsCore
import Foundation
#if canImport(PDFKit)
import PDFKit
#endif

@MainActor
public final class PDFImportJob {
    public struct ImportResult: Codable, Sendable, Equatable {
        public let fileName: String
        public let byteCount: Int
        public let pageCount: Int
        public let textPreview: String
        public let data: Data

        public init(
            fileName: String,
            byteCount: Int,
            pageCount: Int,
            textPreview: String,
            data: Data
        ) {
            self.fileName = fileName
            self.byteCount = byteCount
            self.pageCount = pageCount
            self.textPreview = textPreview
            self.data = data
        }
    }

    private let progressSubject = PassthroughSubject<OperationResult<ImportResult>, Never>()
    public var progressPublisher: AnyPublisher<OperationResult<ImportResult>, Never> {
        progressSubject.eraseToAnyPublisher()
    }

    private let kind = "pdfImport"

    public init() {}

    public func importPDF(at url: URL, stageDelay: TimeInterval = 0.08) async -> OperationResult<ImportResult> {
        let startTime = Date()
        let operationId = UUID()

        emitProgress(
            id: operationId,
            startTime: startTime,
            percent: 0,
            message: "Preparing PDF import..."
        )

        guard FileManager.default.fileExists(atPath: url.path) else {
            let failure = failureResult(
                id: operationId,
                startTime: startTime,
                code: "PDF_READ_ERROR",
                message: "File not found: \(url.lastPathComponent)",
                hint: "Verify the PDF is still available at the selected path."
            )
            progressSubject.send(failure)
            return failure
        }

        do {
            let data = try Data(contentsOf: url)

            emitProgress(
                id: operationId,
                startTime: startTime,
                percent: 25,
                message: "Loaded file bytes (\(data.count.formatted(.byteCount)))"
            )
            
            // Parse PDF document
            var pageCount = 0
            var extractedText = ""
            
            #if canImport(PDFKit)
            guard let document = PDFDocument(data: data) else {
                throw NSError(domain: "PDFImportJob", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid PDF format"
                ])
            }
            pageCount = document.pageCount
            extractedText = document.string ?? ""
            #else
            // Fallback for platforms without PDFKit (should not happen on macOS)
            throw NSError(domain: "PDFImportJob", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "PDF processing not available on this platform"
            ])
            #endif

            emitProgress(
                id: operationId,
                startTime: startTime,
                percent: 50,
                message: "Parsed PDF (\(pageCount) pages)"
            )
            
            emitProgress(
                id: operationId,
                startTime: startTime,
                percent: 75,
                message: "Extracted text (\(extractedText.count) characters)"
            )
            
            // Simulate indexing delay (optional, can be removed)
            if stageDelay > 0 {
                try await Task.sleep(nanoseconds: UInt64(stageDelay * 1_000_000_000))
            }
            
            let payload = ImportResult(
                fileName: url.lastPathComponent,
                byteCount: data.count,
                pageCount: pageCount,
                textPreview: preview(from: data, extractedText: extractedText),
                data: data
            )

            let success = OperationResult(
                id: operationId,
                kind: kind,
                startTime: startTime,
                endTime: Date(),
                state: .success,
                payload: payload,
                progress: .init(percent: 100, message: "Completed import"),
                failure: nil
            )
            progressSubject.send(success)
            return success
        } catch {
            let failure = failureResult(
                id: operationId,
                startTime: startTime,
                code: "PDF_READ_ERROR",
                message: "Failed to read PDF: \(error.localizedDescription)",
                hint: "Check file permissions and try again."
            )
            progressSubject.send(failure)
            return failure
        }
    }

    private func emitProgress(
        id: UUID,
        startTime: Date,
        percent: Double,
        message: String
    ) {
        let progress = OperationResult<ImportResult>(
            id: id,
            kind: kind,
            startTime: startTime,
            endTime: nil,
            state: .running,
            payload: nil,
            progress: .init(percent: percent, message: message),
            failure: nil
        )
        progressSubject.send(progress)
    }

    private func failureResult(
        id: UUID,
        startTime: Date,
        code: String,
        message: String,
        hint: String?
    ) -> OperationResult<ImportResult> {
        OperationResult(
            id: id,
            kind: kind,
            startTime: startTime,
            endTime: Date(),
            state: .failure,
            payload: nil,
            progress: nil,
            failure: .init(code: code, message: message, recoveryHint: hint)
        )
    }

    private func estimatePageCount(from data: Data) -> Int {
        guard let text = String(data: data, encoding: .utf8) else { return 1 }
        let occurrences = text.components(separatedBy: "/Type /Page").count - 1
        return max(1, occurrences)
    }

    private func preview(from data: Data) -> String {
        if let text = String(data: data, encoding: .utf8) {
            let preview = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if preview.isEmpty { return "PDF text extracted (empty body)" }
            return String(preview.prefix(120))
        }
        return "Binary PDF (\(data.count) bytes)"
    }
    
    private func preview(from data: Data, extractedText: String) -> String {
        if !extractedText.isEmpty {
            let trimmed = extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "PDF text extracted (empty body)" }
            return String(trimmed.prefix(120))
        }
        // Fallback to binary detection
        return preview(from: data)
    }

    private func sleep(_ duration: TimeInterval) async throws {
        guard duration > 0 else { return }
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }
}
