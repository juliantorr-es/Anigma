import Foundation
import DataCore

public protocol ProfilingEngineProtocol: Sendable {
    func profile(ir: TabularIR) async throws -> ProfileArtifact
}

public actor ProfilingEngine: ProfilingEngineProtocol {
    public init() {}

    public func profile(ir: TabularIR) async throws -> ProfileArtifact {
        // Basic Profiling Implementation

        let fileURL = URL(fileURLWithPath: ir.storagePointer)
        guard let data = try? Data(contentsOf: fileURL),
              let content = String(data: data, encoding: .utf8) else {
            return ProfileArtifact(
                datasetId: ir.storagePointer,
                columnProfiles: [:],
                totalRows: ir.rowCount,
                parsingFailures: 1 // Treat read failure as parsing failure
            )
        }

        var lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        // Assume header is present if schema has columns, otherwise assume no header or it's already handled
        // For simplicity, we'll just skip the first line if it matches the column names
        if !lines.isEmpty {
            let firstLine = lines[0]
            // Very naive check: if first line contains column names
            if ir.schema.columns.contains(where: { firstLine.contains($0.name) }) {
                lines.removeFirst()
            }
        }

        var columnStats: [String: (nullCount: Int, min: String?, max: String?)] = [:]
        var columnProfiles: [String: ColumnProfile] = [:]

        // Initialize stats
        for column in ir.schema.columns {
            columnStats[column.name] = (nullCount: 0, min: nil, max: nil)
        }

        // Iterate rows
        for row in lines {
            let values = row.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

            for (index, value) in values.enumerated() {
                if index < ir.schema.columns.count {
                    let columnName = ir.schema.columns[index].name
                    guard var stats = columnStats[columnName] else {
                        fatalError("Failed to unwrap stats")
                    }

                    if value.isEmpty {
                        stats.nullCount += 1
                    } else {
                        // Update min/max (string comparison for now)
                        if let currentMin = stats.min {
                            if value < currentMin { stats.min = value }
                        } else {
                            stats.min = value
                        }

                        if let currentMax = stats.max {
                            if value > currentMax { stats.max = value }
                        } else {
                            stats.max = value
                        }
                    }

                    columnStats[columnName] = stats
                }
            }
        }

        // Create ColumnProfiles
        for (name, stats) in columnStats {
            // Find column type
            let type = ir.schema.columns.first { $0.name == name }?.type ?? .string

            columnProfiles[name] = ColumnProfile(
                inferredType: type,
                nullCount: stats.nullCount,
                distinctCount: 0, // Not implemented in basic version
                topValues: [:], // Not implemented in basic version
                min: stats.min,
                max: stats.max,
                mean: nil
            )
        }

        return ProfileArtifact(
            datasetId: ir.storagePointer,
            columnProfiles: columnProfiles,
            totalRows: lines.count,
            parsingFailures: 0
        )
    }
}
