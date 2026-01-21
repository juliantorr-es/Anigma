import Foundation

// MARK: - Profile Artifact

public struct ProfileArtifact: Codable, Sendable {
    public let datasetId: String
    public let columnProfiles: [String: ColumnProfile]
    public let totalRows: Int
    public let parsingFailures: Int

    public init(datasetId: String, columnProfiles: [String: ColumnProfile], totalRows: Int, parsingFailures: Int) {
        self.datasetId = datasetId
        self.columnProfiles = columnProfiles
        self.totalRows = totalRows
        self.parsingFailures = parsingFailures
    }
}

public struct ColumnProfile: Codable, Sendable {
    public let inferredType: ColumnType
    public let nullCount: Int
    public let distinctCount: Int
    public let topValues: [String: Int] // Value -> Count
    public let min: String?
    public let max: String?
    public let mean: Double?

    public init(inferredType: ColumnType, nullCount: Int, distinctCount: Int, topValues: [String: Int], min: String? = nil, max: String? = nil, mean: Double? = nil) {
        self.inferredType = inferredType
        self.nullCount = nullCount
        self.distinctCount = distinctCount
        self.topValues = topValues
        self.min = min
        self.max = max
        self.mean = mean
    }
}

// MARK: - View Spec

public struct ViewSpec: Codable, Sendable {
    public let query: String // Or structured query object
    public let parameters: [String: String]
    public let filters: [ViewFilter]
    public let sort: [ViewSort]
    public let sourceSnapshotId: String

    public init(query: String, parameters: [String: String], filters: [ViewFilter], sort: [ViewSort], sourceSnapshotId: String) {
        self.query = query
        self.parameters = parameters
        self.filters = filters
        self.sort = sort
        self.sourceSnapshotId = sourceSnapshotId
    }
}

public struct ViewFilter: Codable, Sendable {
    public let column: String
    public let operation: FilterOperation
    public let value: String

    public init(column: String, operation: FilterOperation, value: String) {
        self.column = column
        self.operation = operation
        self.value = value
    }
}

public enum FilterOperation: String, Codable, Sendable {
    case equals
    case contains
    case greaterThan
    case lessThan
    // ...
}

public struct ViewSort: Codable, Sendable {
    public let column: String
    public let ascending: Bool

    public init(column: String, ascending: Bool) {
        self.column = column
        self.ascending = ascending
    }
}

// MARK: - Change Artifact

public struct ChangeArtifact: Codable, Sendable {
    public let transformId: String
    public let recordsAffected: Int
    public let columnsChanged: [String]
    public let diffSummary: String

    public init(transformId: String, recordsAffected: Int, columnsChanged: [String], diffSummary: String) {
        self.transformId = transformId
        self.recordsAffected = recordsAffected
        self.columnsChanged = columnsChanged
        self.diffSummary = diffSummary
    }
}
