import Foundation
import AnigmaPrimitives

/// High-level interface for the VizAggregationCapsule.
/// Provides a fluent, type-safe API for performing deterministic data aggregations.
public final class VizAggregationCapsule {
    private let wrapper: VizAggregationCapsuleWrapper
    
    public init() throws {
        self.wrapper = try VizAggregationCapsuleWrapper()
    }
    
    // MARK: - Data Ingestion
    
    /// Creates a dataset from a dictionary of columns.
    /// - Parameter columns: Dictionary mapping column names to their data values.
    /// - Returns: A handle to the created dataset.
    public func createDataset(columns: [String: ColumnData]) throws -> Dataset {
        var columnViews: [ColumnView] = []
        var rowCount: Int?
        
        for (name, data) in columns {
            let count = data.count
            if let existingCount = rowCount, existingCount != count {
                throw VizError.columnCountMismatch
            }
            rowCount = count
            
            columnViews.append(
                ColumnView(
                    name: name,
                    type: data.type,
                    data: data.buffer,
                    elementCount: count,
                    nullBitmap: data.nullBitmap
                )
            )
        }
        
        guard let finalCount = rowCount, finalCount > 0 else {
            throw VizError.emptyDataset
        }
        
        let handle = try wrapper.createDataset(from: columnViews)
        return Dataset(handle: handle, wrapper: wrapper, rowCount: finalCount, columns: columns.keys.sorted())
    }
    
    // MARK: - Query Execution
    
    /// Executes an aggregation query on a dataset.
    /// - Parameters:
    ///   - dataset: The input dataset.
    ///   - query: The query configuration.
    /// - Returns: A new dataset containing the aggregation results.
    public func aggregate(dataset: Dataset, query: AggregationQuery) throws -> Dataset {
        let plan = query.buildPlan()
        let (outputHandle, _) = try wrapper.execute(dataset: dataset.handle, plan: plan)
        
        // Retrieve column info from output dataset to populate the Dataset object
        let colCount = try wrapper.columnCount(of: outputHandle)
        var colNames: [String] = []
        
        for i in 0..<colCount {
            let info = try wrapper.columnInfo(of: outputHandle, at: i)
            colNames.append(info.name)
        }
        
        // Note: We don't know the row count immediately without querying a column
        // But we can get it from the first column data if needed, or add a wrapper method.
        // For now, let's assume valid output and lazily fetch or fetch first col to check size.
        let (_, count) = try wrapper.columnData(of: outputHandle, at: 0)
        
        return Dataset(handle: outputHandle, wrapper: wrapper, rowCount: count, columns: colNames)
    }
}

// MARK: - Supporting Types

public enum VizError: Error {
    case columnCountMismatch
    case emptyDataset
    case invalidColumn
}

/// Represents a column of data ready for ingestion.
public struct ColumnData {
    public let type: ScalarType
    public let buffer: Data
    public let nullBitmap: Data?
    public let count: Int
    
    public init(values: [Int64]) {
        self.type = .int64
        self.count = values.count
        self.buffer = values.withUnsafeBufferPointer { Data(buffer: $0) }
        self.nullBitmap = nil
    }
    
    public init(values: [Double]) {
        self.type = .float64
        self.count = values.count
        self.buffer = values.withUnsafeBufferPointer { Data(buffer: $0) }
        self.nullBitmap = nil
    }
    
    // TODO: Add initializers for other types and null handling
}

/// A managed dataset resource.
public class Dataset {
    internal let handle: DatasetHandle
    internal let wrapper: VizAggregationCapsuleWrapper
    public let rowCount: Int
    public let columns: [String]
    
    internal init(handle: DatasetHandle, wrapper: VizAggregationCapsuleWrapper, rowCount: Int, columns: [String]) {
        self.handle = handle
        self.wrapper = wrapper
        self.rowCount = rowCount
        self.columns = columns
    }
    
    deinit {
        try? wrapper.destroyDataset(handle)
    }
    
    /// Reads a column as Double values (if type matches).
    public func readDoubleColumn(at index: Int) throws -> [Double] {
        let (ptr, count) = try wrapper.columnData(of: handle, at: index)
        let buffer = UnsafeBufferPointer(start: ptr.assumingMemoryBound(to: Double.self), count: count)
        return Array(buffer)
    }
    
    /// Reads a column as Int64 values (if type matches).
    public func readIntColumn(at index: Int) throws -> [Int64] {
        let (ptr, count) = try wrapper.columnData(of: handle, at: index)
        let buffer = UnsafeBufferPointer(start: ptr.assumingMemoryBound(to: Int64.self), count: count)
        return Array(buffer)
    }
}

/// Fluent builder for aggregation queries.
public struct AggregationQuery {
    public var groupBy: [String] = []
    public var aggregations: [(function: AggregationFunction, column: String, output: String)] = []
    public var filters: [(column: String, op: PredicateBuilder.PredicateOperation, value: Any)] = [] // Simplified
    
    public init() {}
    
    public func buildPlan() -> AggregationPlan {
        // This requires mapping string column names to indices, which implies we need schema awareness here.
        // For the full implementation, we need a Schema object or lookups.
        // Assuming for now the user handles indices or we map them later.
        // To make this truly high-level, `Dataset` should expose schema (name -> index/type).
        
        // Placeholder for compilation logic
        return AggregationPlan()
    }
}
