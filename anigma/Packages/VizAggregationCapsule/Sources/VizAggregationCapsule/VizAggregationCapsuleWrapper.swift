import Foundation
import CapsuleCore

// Stub: VizAggregation C APIs not available in this environment
// STUB_TRACK: viz-aggregation-wrapper – VizAggregation C APIs not integrated
public final class VizAggregationCapsuleWrapper {
    private let handle: String
    
    public init() throws {
        // STUB_TRACK: viz-aggregation-init – Wrapper initialization is stubbed
        print("⚠️  STUB INVOKED: VizAggregationCapsuleWrapper.init()")
        print("   VizAggregation C APIs not available - using stub wrapper")
        self.handle = "stub"
    }
    
    public func createDataset(from columns: [ColumnView]) throws -> DatasetHandle {
        // STUB_TRACK: viz-aggregation-create-dataset – Dataset creation is stubbed
        print("⚠️  STUB INVOKED: VizAggregationCapsuleWrapper.createDataset()")
        print("   Dataset creation - using stub handle")
        return DatasetHandle(raw: "stub")
    }
    
    public func destroyDataset(_ dataset: DatasetHandle) throws {
        // No-op stub
        // STUB_TRACK: viz-aggregation-destroy-dataset – Dataset destroy call is stubbed
        print("⚠️  STUB INVOKED: VizAggregationCapsuleWrapper.destroyDataset()")
    }
    
    public func execute(dataset: DatasetHandle, plan: AggregationPlan) throws -> (DatasetHandle, ExecutionMetrics) {
        // STUB_TRACK: viz-aggregation-execute – Aggregation execution is stubbed
        print("⚠️  STUB INVOKED: VizAggregationCapsuleWrapper.execute()")
        print("   Aggregation execution - returning stub metrics")
        return (dataset, ExecutionMetrics())
    }
    
    public func columnCount(of dataset: DatasetHandle) throws -> Int {
        return 0 
    }
    
    public func columnData(of dataset: DatasetHandle, at index: Int) throws -> ColumnData {
        return ColumnData(data: Data(), elementCount: 0)
    }
}

public struct DatasetHandle: @unchecked Sendable {
    let raw: String
    
    init(raw: String) {
        self.raw = raw
    }
}

public struct ExecutionMetrics: Sendable {}

public struct ColumnData: Sendable {
    public let data: Data
    public let elementCount: Int
}

public struct PredicateBuilder: Sendable {
    public init() {}
    public mutating func equal(columnIndex: UInt32, columnType: ScalarType, value: String) {}
    public mutating func notEqual(columnIndex: UInt32, columnType: ScalarType, value: String) {}
}

public struct AggregationSpecBuilder: Sendable {
    public init() {}
    public mutating func addCount(columnIndex: UInt32, outputName: String) {}
    public mutating func addMean(columnIndex: UInt32, outputName: String) {}
    public mutating func addQuantile(columnIndex: UInt32, quantile: Double, outputName: String) {}
    public mutating func addMin(columnIndex: UInt32, outputName: String) {}
    public mutating func addMax(columnIndex: UInt32, outputName: String) {}
    public mutating func addStddev(columnIndex: UInt32, outputName: String) {}
}

public struct SortKeyBuilder: Sendable {
    public init() {}
    public mutating func add(columnIndex: UInt32, ascending: Bool) {}
}

public struct VizColumnReference: Sendable {
    public let name: String
    public let type: ScalarType
    public init(name: String, type: ScalarType) {
        self.name = name
        self.type = type
    }
}

public struct AggregationPlan: Sendable {
    public enum Mode { case deterministic }
    public enum NullPolicy { case dropRows }
    
    public init(
        mode: Mode,
        nullPolicy: NullPolicy,
        groupBy: [VizColumnReference],
        limitRows: UInt32? = nil,
        predicateBuilder: PredicateBuilder?,
        aggregationBuilder: AggregationSpecBuilder,
        sortKeyBuilder: SortKeyBuilder? = nil
    ) {}
}

public struct ColumnView {
    public let name: String
    public let type: ScalarType
    public let data: Data
    public let elementCount: Int
    public let nullBitmap: Data?
    
    public init(name: String, type: ScalarType, data: Data, elementCount: Int, nullBitmap: Data? = nil) {
        self.name = name
        self.type = type
        self.data = data
        self.elementCount = elementCount
        self.nullBitmap = nullBitmap
    }
}

public enum ScalarType: Sendable {
    case int64
    case uint64
    case float64
    case float32
    case bool
    case timestampMsUtc
    case stringUtf8
}
