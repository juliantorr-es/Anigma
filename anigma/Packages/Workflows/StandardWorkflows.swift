import Foundation
import DataCore

public enum StandardWorkflows {
    public static let messyCSV = WorkflowDefinition(
        id: "messy-csv",
        name: "Messy CSV Cleanup",
        description: "Ingest, profile, clean, and visualize a CSV file.",
        steps: [
            .ingest(source: URL(fileURLWithPath: "/tmp/placeholder.csv")), // This would be dynamic in real usage
            .profile,
            .transform(TransformIR(id: "clean-types", operations: [
                .coerceType(column: "date", type: .date),
                .coerceType(column: "amount", type: .double)
            ])),
            .render(ViewSpec(
                query: "SELECT * FROM dataset",
                parameters: [:],
                filters: [],
                sort: [],
                sourceSnapshotId: "latest"
            ))
        ]
    )

    public static let bankExport = WorkflowDefinition(
        id: "bank-export",
        name: "Bank Export Analysis",
        description: "Normalize merchants, categorize transactions, and reconcile.",
        steps: [
            .ingest(source: URL(fileURLWithPath: "/tmp/bank.csv")),
            .profile,
            .transform(TransformIR(id: "normalize-merchants", operations: [
                .renameColumn(old: "Description", new: "Merchant")
                // In reality, this would use a more complex operation or external tool
            ])),
            .render(ViewSpec(
                query: "SELECT Merchant, SUM(Amount) FROM dataset GROUP BY Merchant",
                parameters: [:],
                filters: [],
                sort: [ViewSort(column: "SUM(Amount)", ascending: false)],
                sourceSnapshotId: "latest"
            ))
        ]
    )

    public static let databaseHealth = WorkflowDefinition(
        id: "database-health",
        name: "Database Health Check",
        description: "Capture schema, analyze stats, and check integrity.",
        steps: [
            .profile, // Profiling a database connection
            .render(ViewSpec(
                query: "SCHEMA_GRAPH",
                parameters: [:],
                filters: [],
                sort: [],
                sourceSnapshotId: "latest"
            ))
        ]
    )
}
