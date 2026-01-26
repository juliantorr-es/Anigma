import Foundation
import AnigmaNativeShims
import CapsuleCore

public final class VizAggregationCapsuleWrapper {
    private let handle: CapsuleHandle<AnyObject>?
    
    public init() throws {
        var rawHandle: anigma_viz_aggregation_capsule_t?
        var error = anigma_capsule_error_t()
        
        let status = anigma_viz_aggregation_capsule_create(&rawHandle, &error)
        guard status == ANIGMA_OK, let finalHandle = rawHandle else {
            throw capsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: finalHandle,
            destroyFunction: capsuleDestroyer(anigma_viz_aggregation_capsule_destroy)
        )
    }
    public func createDataset(from columns: [ColumnView]) throws -> DatasetHandle {
        var rawDataset: anigma_viz_dataset_t?
        var error = anigma_capsule_error_t()
        
        let cColumns: [anigma_viz_column_view_t] = columns.map { col in
            anigma_viz_column_view_t(
                name: (col.name as NSString).utf8String,
                type: col.type.toCType(),
                data: col.data.withUnsafeBytes { $0.baseAddress },
                element_count: col.elementCount,
                element_size: 0,
                null_bitmap: col.nullBitmap?.withUnsafeBytes { $0.baseAddress },
                null_bitmap_size: col.nullBitmap?.count ?? 0
            )
        }
        
        let status = anigma_viz_dataset_create_from_columns(cColumns, cColumns.count, &rawDataset, &error)
        guard status == ANIGMA_OK, let finalDataset = rawDataset else {
            throw capsuleError(status: status, error: error)
        }
        
        return DatasetHandle(raw: finalDataset)
    }
    
    public func destroyDataset(_ dataset: DatasetHandle) throws {
        var error = anigma_capsule_error_t()
        let status = anigma_viz_dataset_destroy(dataset.raw, &error)
        if status != ANIGMA_OK {
            throw capsuleError(status: status, error: error)
        }
    }
    
    public func execute(dataset: DatasetHandle, plan: AggregationPlan) throws -> (DatasetHandle, ExecutionMetrics) {
        // Stub - but needs correct return type for compilation
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
    let raw: anigma_viz_dataset_t
    
    init(raw: anigma_viz_dataset_t) {
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

public struct ColumnReference: Sendable {
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
        groupBy: [ColumnReference],
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
    
    func toCType() -> anigma_viz_scalar_type_t {
        switch self {
        case .int64: return ANIGMA_VIZ_SCALAR_I64
        case .uint64: return ANIGMA_VIZ_SCALAR_U64
        case .float64: return ANIGMA_VIZ_SCALAR_F64
        case .float32: return ANIGMA_VIZ_SCALAR_F32
        case .bool: return ANIGMA_VIZ_SCALAR_BOOL
        case .timestampMsUtc: return ANIGMA_VIZ_SCALAR_TIMESTAMP_MS_UTC
        case .stringUtf8: return ANIGMA_VIZ_SCALAR_STRING_UTF8
        }
    }
}

private func capsuleError(status: anigma_status_t, error: anigma_capsule_error_t) -> CapsuleError {
    let message = error.message.map { String(cString: $0) } ?? "Capsule error"
    return CapsuleError(status: status, code: error.code, message: message)
}

private func capsuleDestroyer(
    _ destroy: @escaping (UnsafeMutableRawPointer, UnsafeMutablePointer<anigma_capsule_error_t>) -> anigma_status_t
) -> (UnsafeMutableRawPointer) -> Void {
    { ptr in
        var err = anigma_capsule_error_t()
        _ = destroy(ptr, &err)
    }
}
