import Foundation
import DataCore

public protocol TransformEngineProtocol: Sendable {
    func apply(transform: TransformIR, to ir: TabularIR) async throws -> (TabularIR, ChangeArtifact)
}

public actor TransformEngine: TransformEngineProtocol {
    public init() {}

    public func apply(transform: TransformIR, to ir: TabularIR) async throws -> (TabularIR, ChangeArtifact) {
        // Basic Transform Implementation

        let fileURL = URL(fileURLWithPath: ir.storagePointer)
        let data = try Data(contentsOf: fileURL)
        guard let content = String(data: data, encoding: .utf8) else {
             throw NSError(domain: "TransformEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not read file"])
        }

        var lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var headerLine = ""

        if !lines.isEmpty {
            headerLine = lines.removeFirst()
        }

        var transformedLines: [String] = []
        var recordsAffected = 0

        // Apply operations
        for operation in transform.operations {
            switch operation {
            case .filter(let predicate):
                // Very naive filter: keep rows that contain the predicate string
                // In a real engine, this would parse the predicate expression
                let originalCount = lines.count
                lines = lines.filter { $0.contains(predicate) }
                recordsAffected += (originalCount - lines.count)

            case .renameColumn(let old, let new):
                // Rename in header
                headerLine = headerLine.replacingOccurrences(of: old, with: new)
                // No records affected in terms of row count, but schema changes

            case .dropColumn:
                // Not implemented in this basic version
                break

            case .coerceType:
                // Not implemented in this basic version
                break
            }
        }

        transformedLines = [headerLine] + lines

        // Write to new file
        let newContent = transformedLines.joined(separator: "\n")
        let newFilename = UUID().uuidString + ".csv"
        let newFileURL = fileURL.deletingLastPathComponent().appendingPathComponent(newFilename)
        try newContent.write(to: newFileURL, atomically: true, encoding: .utf8)

        // Update Schema
        // For rename, we should update the schema. For filter, schema stays same.
        var newColumns = ir.schema.columns
        for operation in transform.operations {
            if case .renameColumn(let old, let new) = operation {
                if let index = newColumns.firstIndex(where: { $0.name == old }) {
                    let oldCol = newColumns[index]
                    newColumns[index] = ColumnSchema(name: new, type: oldCol.type, isNullable: oldCol.isNullable)
                }
            }
        }

        let newIR = TabularIR(
            schema: TableSchema(columns: newColumns),
            rowCount: lines.count,
            storagePointer: newFileURL.path,
            parsingDiagnostics: []
        )

        let change = ChangeArtifact(
            transformId: transform.id,
            recordsAffected: recordsAffected,
            columnsChanged: [], // Populate if needed
            diffSummary: "Applied \(transform.operations.count) operations. Filter removed \(recordsAffected) rows."
        )

        return (newIR, change)
    }
}
