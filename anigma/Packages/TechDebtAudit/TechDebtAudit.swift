//
//  TechDebtAudit.swift
//  TechDebtAudit
//
//  [Brief description of file purpose]
//

import Foundation

public struct TechDebtAudit {
    private let rootURL: URL

    public init(rootURL: URL) {
        self.rootURL = rootURL
    }

    public func runAudit() throws -> TechDebtAuditReport {
        let markerRecords = try collectMarkers()
        let markers = markerRecords.map { $0.marker }
        let entries = try collectEntries()

        let entryIDs = Set(entries.map { $0.id })
        var missingDocIDs: [TechDebtIssue] = []
        for record in markerRecords {
            if !entryIDs.contains(record.marker.id) {
                missingDocIDs.append(TechDebtIssue(
                    id: record.marker.id,
                    file: record.marker.file,
                    line: record.line,
                    snippet: record.snippet
                ))
            }
        }

        let markerIDs = Set(markers.map { $0.id })
        var orphanedDocIDs: [TechDebtEntryPayload] = []
        for entry in entries {
            if !markerIDs.contains(entry.id) {
                orphanedDocIDs.append(TechDebtEntryPayload(
                    id: entry.id,
                    title: entry.title,
                    line: entry.line,
                    metadata: entry.metadata
                ))
            }
        }

        let success = missingDocIDs.isEmpty && orphanedDocIDs.isEmpty
        return TechDebtAuditReport(
            markers: markers,
            entries: entries,
            missingDocIDs: missingDocIDs,
            orphanedDocIDs: orphanedDocIDs,
            success: success
        )
    }

    private func collectMarkers() throws -> [MarkerRecord] {
        var records: [MarkerRecord] = []
        var seenIDs = Set<String>()
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: rootURL, includingPropertiesForKeys: nil) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "swift" else { continue }
            let content = try String(contentsOf: fileURL)
            let lines = content.components(separatedBy: .newlines)

            for (index, line) in lines.enumerated() {
                guard let range = line.range(of: "STUB_TRACK:") else { continue }
                let tail = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
                guard let dashRange = tail.range(of: " – ") else {
                    throw TechDebtAuditError.malformedMarker(reason: "Malformed marker in \(fileURL.path): \(line)")
                }
                let id = String(tail[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                let title = String(tail[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                guard !id.isEmpty, !title.isEmpty else {
                    throw TechDebtAuditError.malformedMarker(reason: "Incomplete marker in \(fileURL.path): \(line)")
                }
                if seenIDs.contains(id) {
                    throw TechDebtAuditError.duplicateMarker(id: id)
                }
                seenIDs.insert(id)

                let marker = StubMarker(id: id, file: relativePath(for: fileURL), line: index + 1)
                let record = MarkerRecord(
                    marker: marker,
                    snippet: line.trimmingCharacters(in: .whitespaces),
                    fileURL: fileURL,
                    line: index + 1
                )
                records.append(record)
            }
        }

        return records
    }

    private func collectEntries() throws -> [TechDebtEntry] {
        let docURL = rootURL.appendingPathComponent("Docs/TechDebt.md")
        guard FileManager.default.fileExists(atPath: docURL.path) else {
            return []
        }

        let content = try String(contentsOf: docURL)
        let lines = content.components(separatedBy: .newlines)
        var entries: [TechDebtEntry] = []
        var seenIDs = Set<String>()
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("### ") else {
                index += 1
                continue
            }

            let headerLineNumber = index + 1
            let headerBody = trimmed.dropFirst(4).trimmingCharacters(in: .whitespaces)

            guard let headerDash = headerBody.range(of: " – ") else {
                throw TechDebtAuditError.malformedEntry(reason: "Malformed header at line \(headerLineNumber): \(trimmed)")
            }

            let id = String(headerBody[..<headerDash.lowerBound]).trimmingCharacters(in: .whitespaces)
            let title = String(headerBody[headerDash.upperBound...]).trimmingCharacters(in: .whitespaces)

            index += 1
            while index < lines.count && lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                index += 1
            }

            guard index < lines.count else {
                throw TechDebtAuditError.malformedEntry(reason: "Missing ID line for entry \(id)")
            }

            let idLine = lines[index].trimmingCharacters(in: .whitespaces)
            guard idLine.hasPrefix("ID:") else {
                throw TechDebtAuditError.malformedEntry(reason: "Expected ID block after header \(id)")
            }

            let idBody = idLine.dropFirst(3).trimmingCharacters(in: .whitespaces)
            guard let idLineDash = idBody.range(of: " – ") else {
                throw TechDebtAuditError.malformedEntry(reason: "Malformed ID line for entry \(id)")
            }

            let docId = String(idBody[..<idLineDash.lowerBound]).trimmingCharacters(in: .whitespaces)
            let docRest = String(idBody[idLineDash.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard docId == id else {
                throw TechDebtAuditError.malformedEntry(reason: "ID mismatch for entry \(id)")
            }

            let (docTitle, metadata) = parseTitleAndMetadata(from: docRest)
            guard docTitle == title else {
                throw TechDebtAuditError.malformedEntry(reason: "Title mismatch for entry \(id)")
            }

            if seenIDs.contains(id) {
                throw TechDebtAuditError.duplicateEntry(id: id)
            }
            seenIDs.insert(id)

            entries.append(TechDebtEntry(
                id: id,
                title: title,
                line: headerLineNumber,
                metadata: metadata
            ))
            index += 1
        }

        return entries
    }

    private func parseTitleAndMetadata(from text: String) -> (String, String) {
        if let metadataRange = text.range(of: " - ") {
            let title = String(text[..<metadataRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let metadata = String(text[metadataRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (title, metadata)
        }
        return (text, "")
    }

    private func relativePath(for url: URL) -> String {
        let rootPath = rootURL.path
        let filePath = url.path
        if filePath.hasPrefix(rootPath) {
            let trimmed = filePath.dropFirst(rootPath.count)
            return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return filePath
    }

    private struct MarkerRecord {
        let marker: StubMarker
        let snippet: String
        let fileURL: URL
        let line: Int
    }
}
