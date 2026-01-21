import Foundation
import DataCore

public protocol IngestionEngineProtocol: Sendable {
    func ingest(source: URL, options: IngestionOptions) async throws -> TabularIR
}

public struct IngestionOptions: Codable, Sendable {
    public let delimiter: String?
    public let hasHeader: Bool

    public init(delimiter: Character? = nil, hasHeader: Bool = true) {
        self.delimiter = delimiter.map { String($0) }
        self.hasHeader = hasHeader
    }

    public var delimiterChar: Character? {
        return delimiter?.first
    }
}

public actor IngestionEngine: IngestionEngineProtocol {
    public init() {}

    public func ingest(source: URL, options: IngestionOptions) async throws -> TabularIR {
        // Basic CSV Ingestion Implementation

        // 1. Read file content
        let data = try Data(contentsOf: source)
        guard let content = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "IngestionEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not decode file as UTF-8"])
        }

        // 2. Parse lines
        var lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            return TabularIR(
                schema: TableSchema(columns: []),
                rowCount: 0,
                storagePointer: source.path,
                parsingDiagnostics: []
            )
        }

        // 3. Infer Schema
        let delimiter = options.delimiterChar ?? ","
        let headerLine = lines[0]
        let headers: [String]

        if options.hasHeader {
            headers = headerLine.split(separator: delimiter).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            lines.removeFirst()
        } else {
            let firstRow = headerLine.split(separator: delimiter)
            headers = (0..<firstRow.count).map { "Column\($0 + 1)" }
        }

        // Simple type inference based on first non-empty row
        var columnTypes: [ColumnType] = Array(repeating: .string, count: headers.count)
        if let firstDataRow = lines.first {
            let values = firstDataRow.split(separator: delimiter).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

            for (index, value) in values.enumerated() {
                if index < columnTypes.count {
                    if Int(value) != nil {
                        columnTypes[index] = .integer
                    } else if Double(value) != nil {
                        columnTypes[index] = .double
                    } else if ["true", "false", "yes", "no"].contains(value.lowercased()) {
                        columnTypes[index] = .boolean
                    } else {
                        columnTypes[index] = .string
                    }
                }
            }
        }

        let columns = zip(headers, columnTypes).map { name, type in
            ColumnSchema(name: name, type: type, isNullable: true)
        }

        // 4. Create TabularIR
        // In a real system, we would copy the file to a managed storage.
        // Here we use the source path as the storage pointer.

        return TabularIR(
            schema: TableSchema(columns: columns),
            rowCount: lines.count,
            storagePointer: source.path,
            parsingDiagnostics: []
        )
    }
}
