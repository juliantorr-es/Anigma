import Foundation
import DataCore

public protocol QueryEngineProtocol: Sendable {
    func execute(viewSpec: ViewSpec) async throws -> TabularIR
}

public actor QueryEngine: QueryEngineProtocol {
    public init() {}

    public func execute(viewSpec: ViewSpec) async throws -> TabularIR {
        let sourceURL = URL(fileURLWithPath: viewSpec.sourceSnapshotId)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw QueryEngineError.missingSource(viewSpec.sourceSnapshotId)
        }

        let data = try Data(contentsOf: sourceURL)
        guard let content = String(data: data, encoding: .utf8) else {
            throw QueryEngineError.unreadableSource(sourceURL.path)
        }

        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard let headerLine = lines.first else {
            return TabularIR(schema: TableSchema(columns: []), rowCount: 0, storagePointer: sourceURL.path)
        }

        let headers = splitCSVRow(headerLine)
        guard !headers.isEmpty else {
            return TabularIR(schema: TableSchema(columns: []), rowCount: 0, storagePointer: sourceURL.path)
        }

        var rows = lines.dropFirst().map(splitCSVRow)

        if !viewSpec.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let needle = viewSpec.query.lowercased()
            rows = rows.filter { row in
                row.joined(separator: " ").lowercased().contains(needle)
            }
        }

        rows = applyFilters(rows, headers: headers, filters: viewSpec.filters)
        rows = applySort(rows, headers: headers, sort: viewSpec.sort)

        let columns = inferColumns(headers: headers, rows: rows)
        return TabularIR(
            schema: TableSchema(columns: columns),
            rowCount: rows.count,
            storagePointer: sourceURL.path
        )
    }

    private func splitCSVRow(_ row: String) -> [String] {
        row.split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private func applyFilters(_ rows: [[String]], headers: [String], filters: [ViewFilter]) -> [[String]] {
        guard !filters.isEmpty else { return rows }
        let headerIndex = Dictionary(uniqueKeysWithValues: headers.enumerated().map { ($0.element, $0.offset) })
        return rows.filter { row in
            filters.allSatisfy { filter in
                guard let index = headerIndex[filter.column], index < row.count else { return false }
                let value = row[index]
                switch filter.operation {
                case .equals:
                    return value == filter.value
                case .contains:
                    return value.localizedCaseInsensitiveContains(filter.value)
                case .greaterThan:
                    return compare(value, filter.value) == .orderedDescending
                case .lessThan:
                    return compare(value, filter.value) == .orderedAscending
                }
            }
        }
    }

    private func applySort(_ rows: [[String]], headers: [String], sort: [ViewSort]) -> [[String]] {
        guard !sort.isEmpty else { return rows }
        let headerIndex = Dictionary(uniqueKeysWithValues: headers.enumerated().map { ($0.element, $0.offset) })
        return rows.sorted { lhs, rhs in
            for descriptor in sort {
                guard let index = headerIndex[descriptor.column] else { continue }
                let lhsValue = index < lhs.count ? lhs[index] : ""
                let rhsValue = index < rhs.count ? rhs[index] : ""
                let comparison = compare(lhsValue, rhsValue)
                if comparison != .orderedSame {
                    return descriptor.ascending ? comparison == .orderedAscending : comparison == .orderedDescending
                }
            }
            return false
        }
    }

    private func inferColumns(headers: [String], rows: [[String]]) -> [ColumnSchema] {
        headers.enumerated().map { index, name in
            let sample = rows.compactMap { row -> String? in
                guard index < row.count else { return nil }
                let value = row[index]
                return value.isEmpty ? nil : value
            }.first
            return ColumnSchema(name: name, type: inferType(from: sample), isNullable: true)
        }
    }

    private func inferType(from value: String?) -> ColumnType {
        guard let value, !value.isEmpty else { return .string }
        if Int(value) != nil { return .integer }
        if Double(value) != nil { return .double }
        if ["true", "false", "yes", "no"].contains(value.lowercased()) { return .boolean }
        return .string
    }

    private func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        if let lhsNumber = Double(lhs), let rhsNumber = Double(rhs) {
            if lhsNumber < rhsNumber { return .orderedAscending }
            if lhsNumber > rhsNumber { return .orderedDescending }
            return .orderedSame
        }
        return lhs.localizedStandardCompare(rhs)
    }
}

public enum QueryEngineError: LocalizedError, Sendable {
    case missingSource(String)
    case unreadableSource(String)

    public var errorDescription: String? {
        switch self {
        case .missingSource(let source):
            return "QueryEngine could not find source file at \(source)"
        case .unreadableSource(let source):
            return "QueryEngine could not read UTF-8 content from \(source)"
        }
    }
}
