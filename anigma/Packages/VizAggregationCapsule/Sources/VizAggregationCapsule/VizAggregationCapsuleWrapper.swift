import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import CapsuleCore

/// Swift wrapper for the viz aggregation capsule.
/// Provides deterministic aggregation operations for visualization pipelines.
///
/// ## Overview
///
/// The `VizAggregationCapsuleWrapper` enables performing deterministic aggregation
/// operations on columnar datasets for visualization purposes. It supports:
/// - Grouping by one or more columns
/// - Filtering with predicate expressions
/// - Aggregation functions (COUNT, SUM, MEAN, MIN, MAX, MEDIAN, QUANTILE, STDDEV, VARIANCE)
/// - Sorting with null handling policies
/// - Row limiting with deterministic tie-breaking
///
/// All operations are designed to be deterministic across runs when using the
/// `.deterministic` mode with a stable seed.
///
/// ## Key Types
///
/// - `ColumnView`: Represents a column of raw data for input
/// - `ColumnReference`: Names a column with its scalar type
/// - `AggregationPlan`: Specifies an aggregation operation
/// - `DatasetHandle`: Opaque handle to a dataset (input or output)
///
/// ## Builder APIs
///
/// For constructing complex aggregation plans, use the builder types:
///
/// ```swift
/// var predicateBuilder = PredicateBuilder()
/// predicateBuilder.greaterThan(columnIndex: 1, columnType: .float64, value: 50.0)
///
/// var aggregationBuilder = AggregationSpecBuilder()
/// aggregationBuilder.addCount(outputName: "count")
/// aggregationBuilder.addMean(columnIndex: 1, outputName: "average")
///
/// var sortKeyBuilder = SortKeyBuilder()
/// sortKeyBuilder.add(columnIndex: 0, ascending: true)
///
/// let plan = AggregationPlan(
///     groupBy: [ColumnReference(name: "category", type: .int64)],
///     predicateBuilder: predicateBuilder,
///     aggregationBuilder: aggregationBuilder,
///     sortKeyBuilder: sortKeyBuilder
/// )
/// ```
///
/// ## Example: Simple Count Aggregation
///
/// ```swift
/// let wrapper = try VizAggregationCapsuleWrapper()
///
/// // Create columnar data
/// var ids = Data()
/// var values = Data()
/// for i in 0..<100 {
///     let id = Int64(i)
///     ids.append(contentsOf: withUnsafeBytes(of: id) { Data($0) })
///     let value = Double(i) * 1.5
///     values.append(contentsOf: withUnsafeBytes(of: value) { Data($0) })
/// }
///
/// let columns = [
///     ColumnView(name: "id", type: .int64, data: ids, elementCount: 100),
///     ColumnView(name: "value", type: .float64, data: values, elementCount: 100)
/// ]
///
/// let dataset = try wrapper.createDataset(from: columns)
///
/// var builder = AggregationSpecBuilder()
/// builder.addCount(outputName: "total_rows")
///
/// let plan = AggregationPlan(aggregationBuilder: builder)
/// let (outputDataset, _) = try wrapper.execute(dataset: dataset, plan: plan)
/// ```
///
/// ## Determinism Guarantees
///
/// When using `.deterministic` mode with a non-zero `stableSeed`, all operations
/// produce identical results across runs, including:
/// - Stable sorting with deterministic tie-breaking
/// - Consistent floating-point rounding (within specified ULPs)
/// - Canonical handling of nulls and edge cases
///
/// ## Memory Management
///
/// - `DatasetHandle` objects must be explicitly destroyed using `destroyDataset(_:)`
/// - The wrapper automatically manages the capsule handle's lifetime
/// - Column data is copied internally; use `ColumnView.withCStruct` for zero-copy
///   operations when possible
public final class VizAggregationCapsuleWrapper {
    /// Capsule identity information.
    public static var identity: anigma_capsule_identity_t {
        anigma_viz_aggregation_capsule_get_identity()
    }
    
    private var handle: CapsuleHandle<AnyObject>?
    
    /// Create a viz aggregation capsule.
    public init() throws {
        var rawHandle: anigma_viz_aggregation_capsule_t?
        var error = anigma_capsule_error_t()
        
        let status = anigma_viz_aggregation_capsule_create(&rawHandle, &error)
        guard status == ANIGMA_OK, let rawHandle = rawHandle else {
            throw CapsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: rawHandle,
            destroyFunction: anigma_viz_aggregation_capsule_destroy
        )
    }
    
    deinit {
        handle?.invalidate()
    }
    
    /// Destroy a dataset handle.
    /// - Parameter dataset: Dataset handle to destroy
    public func destroyDataset(_ dataset: DatasetHandle) throws {
        var error = anigma_capsule_error_t()
        let status = anigma_viz_dataset_destroy(dataset.raw, &error)
        guard status == ANIGMA_OK else {
            throw CapsuleError(status: status, error: error)
        }
    }
    
    /// Get the number of columns in a dataset.
    /// - Parameter dataset: Dataset handle
    /// - Returns: Number of columns
    public func columnCount(of dataset: DatasetHandle) throws -> Int {
        var error = anigma_capsule_error_t()
        var count: size_t = 0
        let status = anigma_viz_dataset_get_column_count(dataset.raw, &count, &error)
        guard status == ANIGMA_OK else {
            throw CapsuleError(status: status, error: error)
        }
        return Int(count)
    }
    
    /// Get information about a column in a dataset.
    /// - Parameters:
    ///   - dataset: Dataset handle
    ///   - columnIndex: Column index (0-based)
    /// - Returns: Column reference (name and type)
    public func columnInfo(of dataset: DatasetHandle, at columnIndex: Int) throws -> ColumnReference {
        var error = anigma_capsule_error_t()
        var cInfo = anigma_viz_column_ref_t()
        let status = anigma_viz_dataset_get_column_info(dataset.raw, columnIndex, &cInfo, &error)
        guard status == ANIGMA_OK else {
            throw CapsuleError(status: status, error: error)
        }
        // Convert C string to Swift string
        let name = cInfo.name.map { String(cString: $0) } ?? ""
        let type = ScalarType.from(cInfo.type)
        return ColumnReference(name: name, type: type)
    }
    
    /// Get pointer to column data.
    /// - Parameters:
    ///   - dataset: Dataset handle
    ///   - columnIndex: Column index (0-based)
    /// - Returns: Tuple of data pointer and element count
    /// - Note: The returned pointer is valid until the dataset is destroyed.
    public func columnData(of dataset: DatasetHandle, at columnIndex: Int) throws -> (data: UnsafeRawPointer, elementCount: Int) {
        var error = anigma_capsule_error_t()
        var dataPtr: UnsafeRawPointer?
        var count: size_t = 0
        let status = anigma_viz_dataset_get_column_data(dataset.raw, columnIndex, &dataPtr, &count, &error)
        guard status == ANIGMA_OK, let dataPtr = dataPtr else {
            throw CapsuleError(status: status, error: error)
        }
        return (dataPtr, Int(count))
    }
    
    /// Create a dataset from column views.
    /// - Parameters:
    ///   - columns: Array of column views
    /// - Returns: Dataset handle
    public func createDataset(from columns: [ColumnView]) throws -> DatasetHandle {
        var error = anigma_capsule_error_t()
        var dataset: anigma_viz_dataset_t?
        
        guard !columns.isEmpty else {
            throw CapsuleError(status: ANIGMA_ERR_INVALID_ARG, error: anigma_capsule_error_t())
        }
        
        // Convert column names to C strings (need to stay alive for the duration)
        let nameCStrings = columns.map { strdup($0.name) }
        defer {
            for cStr in nameCStrings {
                free(cStr)
            }
        }
        
        // Check for strdup failures
        for cStr in nameCStrings {
            guard cStr != nil else {
                throw CapsuleError(status: ANIGMA_ERR_INTERNAL, error: anigma_capsule_error_t())
            }
        }
        
        // Force unwrap since we checked for nil
        let nameCStringsUnwrapped = nameCStrings.map { $0! }
        
        // Helper to recursively process columns with nested withUnsafeBytes
        func processColumns(
            _ columns: [ColumnView],
            _ names: [UnsafeMutablePointer<CChar>],
            index: Int,
            cStructs: inout [anigma_viz_column_view_t]
        ) -> anigma_status_t {
            guard index < columns.count else {
                // All columns processed, call C function with the accumulated C structs
                return cStructs.withUnsafeBufferPointer { buffer in
                    anigma_viz_dataset_create_from_columns(
                        buffer.baseAddress,
                        columns.count,
                        &dataset,
                        &error
                    )
                }
            }
            
            let column = columns[index]
            let nameCStr = names[index]
            
            // Determine element size
            let elementSize: Int
            switch column.type {
            case .int64, .uint64, .timestampMsUtc:
                elementSize = 8
            case .float64:
                elementSize = 8
            case .float32:
                elementSize = 4
            case .bool:
                elementSize = 1
            case .stringUtf8:
                elementSize = 0 // Variable-length
            }
            
            // Process column data with nested withUnsafeBytes
            return column.data.withUnsafeBytes { dataBytes in
                if let nullBitmap = column.nullBitmap {
                    return nullBitmap.withUnsafeBytes { nullBytes in
                        let cStruct = anigma_viz_column_view_t(
                            name: nameCStr,
                            type: column.type.toCType(),
                            data: dataBytes.baseAddress,
                            element_count: column.elementCount,
                            element_size: elementSize,
                            null_bitmap: nullBytes.baseAddress,
                            null_bitmap_size: nullBitmap.count
                        )
                        cStructs.append(cStruct)
                        return processColumns(columns, names, index: index + 1, cStructs: &cStructs)
                    }
                } else {
                    let cStruct = anigma_viz_column_view_t(
                        name: nameCStr,
                        type: column.type.toCType(),
                        data: dataBytes.baseAddress,
                        element_count: column.elementCount,
                        element_size: elementSize,
                        null_bitmap: nil,
                        null_bitmap_size: 0
                    )
                    cStructs.append(cStruct)
                    return processColumns(columns, names, index: index + 1, cStructs: &cStructs)
                }
            }
        }
        
        var cStructs: [anigma_viz_column_view_t] = []
        cStructs.reserveCapacity(columns.count)
        
        let status = processColumns(columns, nameCStringsUnwrapped, index: 0, cStructs: &cStructs)
        
        guard status == ANIGMA_OK, let dataset = dataset else {
            throw CapsuleError(status: status, error: error)
        }
        
        return DatasetHandle(raw: dataset)
    }
    
    /// Execute an aggregation plan on a dataset.
    /// - Parameters:
    ///   - dataset: Input dataset handle
    ///   - plan: Aggregation plan
    /// - Returns: Tuple of output dataset and metadata
    public func execute(
        dataset: DatasetHandle,
        plan: AggregationPlan
    ) throws -> (outputDataset: DatasetHandle, metadata: AggregationMetadata?) {
        var error = anigma_capsule_error_t()
        var outputDataset: anigma_viz_dataset_t?
        var outputMeta = anigma_viz_aggregation_meta_t()
        
        // Use the plan's withCStruct to ensure pointer validity
        let status = try plan.withCStruct { cPlan in
            var mutableCPlan = cPlan
            return try handle?.withHandle { rawHandle in
                anigma_viz_aggregation_capsule_execute(
                    rawHandle,
                    dataset.raw,
                    &mutableCPlan,
                    &outputDataset,
                    &outputMeta,
                    &error
                )
            }
        }
        
        guard let status = status, status == ANIGMA_OK, let outputDataset = outputDataset else {
            throw CapsuleError(status: status ?? ANIGMA_ERR_INTERNAL, error: error)
        }
        
        let outputHandle = DatasetHandle(raw: outputDataset)
        let metadata = AggregationMetadata(from: outputMeta)
        
        // Free the C metadata after copying its contents
        anigma_viz_aggregation_capsule_free_meta(&outputMeta)
        
        return (outputHandle, metadata)
    }
}

// MARK: - Handle Types

/// Opaque handle to a dataset.
public struct DatasetHandle {
    let raw: anigma_viz_dataset_t
    
    init(raw: anigma_viz_dataset_t) {
        self.raw = raw
    }
}

// MARK: - Data Types

/// Column view for raw columnar data input.
public struct ColumnView {
    public var name: String
    public var type: ScalarType
    public var data: Data
    public var elementCount: Int
    public var nullBitmap: Data?
    
    public init(name: String, type: ScalarType, data: Data, elementCount: Int, nullBitmap: Data? = nil) {
        self.name = name
        self.type = type
        self.data = data
        self.elementCount = elementCount
        self.nullBitmap = nullBitmap
    }
    
    /// Call a closure with a C column view structure.
    /// The pointers in the structure are only valid for the duration of the closure.
    func withCStruct<Result>(_ body: (anigma_viz_column_view_t) throws -> Result) rethrows -> Result {
        // Convert name to C string (must stay alive for the duration of the closure)
        let nameCStr = strdup(name)
        defer { free(nameCStr) }
        
        // Determine element size
        let elementSize: Int
        switch type {
        case .int64, .uint64, .timestampMsUtc:
            elementSize = 8
        case .float64:
            elementSize = 8
        case .float32:
            elementSize = 4
        case .bool:
            elementSize = 1
        case .stringUtf8:
            elementSize = 0 // Variable-length
        }
        
        // We need to call body with a C struct that has valid data pointers.
        // We'll use withUnsafeBytes for data and nullBitmap to get pointers
        // that are valid within this closure.
        return try data.withUnsafeBytes { dataBytes in
            if let nullBitmap = nullBitmap {
                return try nullBitmap.withUnsafeBytes { nullBytes in
                    let cStruct = anigma_viz_column_view_t(
                        name: nameCStr,
                        type: type.toCType(),
                        data: dataBytes.baseAddress,
                        element_count: elementCount,
                        element_size: elementSize,
                        null_bitmap: nullBytes.baseAddress,
                        null_bitmap_size: nullBitmap.count
                    )
                    return try body(cStruct)
                }
            } else {
                let cStruct = anigma_viz_column_view_t(
                    name: nameCStr,
                    type: type.toCType(),
                    data: dataBytes.baseAddress,
                    element_count: elementCount,
                    element_size: elementSize,
                    null_bitmap: nil,
                    null_bitmap_size: 0
                )
                return try body(cStruct)
            }
        }
    }
}

/// Scalar data types supported by the viz aggregation capsule.
public enum ScalarType {
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
    
    static func from(_ cType: anigma_viz_scalar_type_t) -> ScalarType {
        switch cType {
        case ANIGMA_VIZ_SCALAR_I64: return .int64
        case ANIGMA_VIZ_SCALAR_U64: return .uint64
        case ANIGMA_VIZ_SCALAR_F64: return .float64
        case ANIGMA_VIZ_SCALAR_F32: return .float32
        case ANIGMA_VIZ_SCALAR_BOOL: return .bool
        case ANIGMA_VIZ_SCALAR_TIMESTAMP_MS_UTC: return .timestampMsUtc
        case ANIGMA_VIZ_SCALAR_STRING_UTF8: return .stringUtf8
        default: fatalError("Unknown scalar type: \(cType)")
        }
    }
}

/// Null handling semantics.
public enum NullPolicy {
    case disallow
    case dropRows
    case propagate
    
    func toCType() -> anigma_viz_null_policy_t {
        switch self {
        case .disallow: return ANIGMA_VIZ_NULL_DISALLOW
        case .dropRows: return ANIGMA_VIZ_NULL_DROP_ROWS
        case .propagate: return ANIGMA_VIZ_NULL_PROPAGATE
        }
    }
}

/// Aggregation mode (deterministic vs fast).
public enum AggregationMode {
    case deterministic
    case fast
    
    func toCType() -> anigma_viz_aggregation_mode_t {
        switch self {
        case .deterministic: return ANIGMA_VIZ_AGG_MODE_DETERMINISTIC
        case .fast: return ANIGMA_VIZ_AGG_MODE_FAST
        }
    }
}

/// Aggregation functions.
public enum AggregationFunction {
    case count
    case countDistinct
    case sum
    case mean
    case min
    case max
    case median
    case quantile(Double)
    case stddev
    case variance
    
    func toCType() -> anigma_viz_agg_fn_t {
        switch self {
        case .count: return ANIGMA_VIZ_AGG_COUNT
        case .countDistinct: return ANIGMA_VIZ_AGG_COUNT_DISTINCT
        case .sum: return ANIGMA_VIZ_AGG_SUM
        case .mean: return ANIGMA_VIZ_AGG_MEAN
        case .min: return ANIGMA_VIZ_AGG_MIN
        case .max: return ANIGMA_VIZ_AGG_MAX
        case .median: return ANIGMA_VIZ_AGG_MEDIAN
        case .quantile: return ANIGMA_VIZ_AGG_QUANTILE
        case .stddev: return ANIGMA_VIZ_AGG_STDDEV
        case .variance: return ANIGMA_VIZ_AGG_VARIANCE
        }
    }
    
    var parameter: Double {
        switch self {
        case .quantile(let p): return p
        default: return 0.0
        }
    }
}

/// Aggregation plan specification.
public struct AggregationPlan {
    public var mode: AggregationMode
    public var nullPolicy: NullPolicy
    public var selectColumns: [ColumnReference]?
    public var groupBy: [ColumnReference]?
    public var limitRows: UInt32
    public var stableSeed: UInt64
    public var floatRoundingUlps: UInt32
    
    // Raw data properties (backward compatibility)
    public var predicates: Data? {
        get {
            if let predicateBuilder = _predicateBuilder {
                return predicateBuilder.serialize()
            }
            return _predicates
        }
        set {
            _predicates = newValue
            _predicateBuilder = nil
        }
    }
    
    public var aggregations: Data? {
        get {
            if let aggregationBuilder = _aggregationBuilder {
                return aggregationBuilder.serialize()
            }
            return _aggregations
        }
        set {
            _aggregations = newValue
            _aggregationBuilder = nil
        }
    }
    
    public var sortKeys: Data? {
        get {
            if let sortKeyBuilder = _sortKeyBuilder {
                return sortKeyBuilder.serialize()
            }
            return _sortKeys
        }
        set {
            _sortKeys = newValue
            _sortKeyBuilder = nil
        }
    }
    
    // Builder properties
    public var predicateBuilder: PredicateBuilder? {
        get { _predicateBuilder }
        set {
            _predicateBuilder = newValue
            _predicates = nil
        }
    }
    
    public var aggregationBuilder: AggregationSpecBuilder? {
        get { _aggregationBuilder }
        set {
            _aggregationBuilder = newValue
            _aggregations = nil
        }
    }
    
    public var sortKeyBuilder: SortKeyBuilder? {
        get { _sortKeyBuilder }
        set {
            _sortKeyBuilder = newValue
            _sortKeys = nil
        }
    }
    
    // Private storage
    private var _predicates: Data?
    private var _aggregations: Data?
    private var _sortKeys: Data?
    private var _predicateBuilder: PredicateBuilder?
    private var _aggregationBuilder: AggregationSpecBuilder?
    private var _sortKeyBuilder: SortKeyBuilder?
    
    public init(
        mode: AggregationMode = .deterministic,
        nullPolicy: NullPolicy = .disallow,
        selectColumns: [ColumnReference]? = nil,
        predicates: Data? = nil,
        groupBy: [ColumnReference]? = nil,
        aggregations: Data? = nil,
        sortKeys: Data? = nil,
        limitRows: UInt32 = 0,
        stableSeed: UInt64 = 0,
        floatRoundingUlps: UInt32 = 1
    ) {
        self.mode = mode
        self.nullPolicy = nullPolicy
        self.selectColumns = selectColumns
        self.groupBy = groupBy
        self.limitRows = limitRows
        self.stableSeed = stableSeed
        self.floatRoundingUlps = floatRoundingUlps
        self._predicates = predicates
        self._aggregations = aggregations
        self._sortKeys = sortKeys
        self._predicateBuilder = nil
        self._aggregationBuilder = nil
        self._sortKeyBuilder = nil
    }
    
    /// Convenience initializer with builders.
    public init(
        mode: AggregationMode = .deterministic,
        nullPolicy: NullPolicy = .disallow,
        selectColumns: [ColumnReference]? = nil,
        groupBy: [ColumnReference]? = nil,
        limitRows: UInt32 = 0,
        stableSeed: UInt64 = 0,
        floatRoundingUlps: UInt32 = 1,
        predicateBuilder: PredicateBuilder?,
        aggregationBuilder: AggregationSpecBuilder?,
        sortKeyBuilder: SortKeyBuilder?
    ) {
        self.mode = mode
        self.nullPolicy = nullPolicy
        self.selectColumns = selectColumns
        self.groupBy = groupBy
        self.limitRows = limitRows
        self.stableSeed = stableSeed
        self.floatRoundingUlps = floatRoundingUlps
        self._predicates = nil
        self._aggregations = nil
        self._sortKeys = nil
        self._predicateBuilder = predicateBuilder
        self._aggregationBuilder = aggregationBuilder
        self._sortKeyBuilder = sortKeyBuilder
    }
    
    /// Call a closure with a C aggregation plan structure.
    /// The pointers in the structure are only valid for the duration of the closure.
    func withCStruct<Result>(_ body: (anigma_viz_aggregation_plan_t) throws -> Result) rethrows -> Result {
        // Convert select_columns if present
        let selectColumnsCount = selectColumns?.count ?? 0
        var selectColumnsC: [anigma_viz_column_ref_t] = []
        var selectColumnNames: [UnsafeMutablePointer<CChar>] = []
        
        if let selectColumns = selectColumns {
            selectColumnsC.reserveCapacity(selectColumnsCount)
            selectColumnNames.reserveCapacity(selectColumnsCount)
            
            for column in selectColumns {
                let nameCStr = strdup(column.name)
                selectColumnNames.append(nameCStr!)
                selectColumnsC.append(anigma_viz_column_ref_t(
                    name: nameCStr,
                    type: column.type.toCType()
                ))
            }
        }
        
        // Convert group_by if present
        let groupByCount = groupBy?.count ?? 0
        var groupByC: [anigma_viz_column_ref_t] = []
        var groupByNames: [UnsafeMutablePointer<CChar>] = []
        
        if let groupBy = groupBy {
            groupByC.reserveCapacity(groupByCount)
            groupByNames.reserveCapacity(groupByCount)
            
            for column in groupBy {
                let nameCStr = strdup(column.name)
                groupByNames.append(nameCStr!)
                groupByC.append(anigma_viz_column_ref_t(
                    name: nameCStr,
                    type: column.type.toCType()
                ))
            }
        }
        
        defer {
            // Clean up duplicated strings
            for nameCStr in selectColumnNames {
                free(nameCStr)
            }
            for nameCStr in groupByNames {
                free(nameCStr)
            }
        }
        
        // Create the C plan structure
        var cPlan = anigma_viz_aggregation_plan_t()
        cPlan.mode = mode.toCType()
        cPlan.null_policy = nullPolicy.toCType()
        cPlan.limit_rows = limitRows
        cPlan.stable_seed = stableSeed
        cPlan.float_rounding_ulps = floatRoundingUlps
        
        // Set select columns
        if !selectColumnsC.isEmpty {
            cPlan.select_columns = selectColumnsC.withUnsafeBufferPointer { $0.baseAddress }
            cPlan.select_columns_count = selectColumnsC.count
        } else {
            cPlan.select_columns = nil
            cPlan.select_columns_count = 0
        }
        
        // Set predicates (opaque data)
        let predicatesData = self.predicates
        if let predicates = predicatesData {
            cPlan.predicates = predicates.withUnsafeBytes { $0.baseAddress }
            cPlan.predicates_bytes = predicates.count
        } else {
            cPlan.predicates = nil
            cPlan.predicates_bytes = 0
        }
        
        // Set group by
        if !groupByC.isEmpty {
            cPlan.group_by = groupByC.withUnsafeBufferPointer { $0.baseAddress }
            cPlan.group_by_count = groupByC.count
        } else {
            cPlan.group_by = nil
            cPlan.group_by_count = 0
        }
        
        // Set aggregations (opaque data)
        let aggregationsData = self.aggregations
        if let aggregations = aggregationsData {
            cPlan.aggregations = aggregations.withUnsafeBytes { $0.baseAddress }
            cPlan.aggregations_bytes = aggregations.count
        } else {
            cPlan.aggregations = nil
            cPlan.aggregations_bytes = 0
        }
        
        // Set sort keys (opaque data)
        let sortKeysData = self.sortKeys
        if let sortKeys = sortKeysData {
            cPlan.sort_keys = sortKeys.withUnsafeBytes { $0.baseAddress }
            cPlan.sort_keys_bytes = sortKeys.count
        } else {
            cPlan.sort_keys = nil
            cPlan.sort_keys_bytes = 0
        }
        
        // Call the closure with the C plan
        return try body(cPlan)
    }
}

/// Column reference.
public struct ColumnReference {
    public var name: String
    public var type: ScalarType
    
    public init(name: String, type: ScalarType) {
        self.name = name
        self.type = type
    }
    
    func toCStruct() -> anigma_viz_column_ref_t {
        anigma_viz_column_ref_t(
            name: (name as NSString).utf8String,
            type: type.toCType()
        )
    }
}

// MARK: - Builder Types

/// Builder for aggregation specifications.
public struct AggregationSpecBuilder {
    /// Single aggregation specification.
    public struct Spec {
        let function: AggregationFunction
        let columnIndex: UInt32
        let outputName: String
        let parameter: Double
        
        public init(function: AggregationFunction, columnIndex: UInt32, outputName: String, parameter: Double = 0.0) {
            self.function = function
            self.columnIndex = columnIndex
            self.outputName = outputName
            self.parameter = parameter
        }
    }
    
    private var specs: [Spec] = []
    
    public init() {}
    
    /// Add a COUNT aggregation.
    /// - Parameters:
    ///   - columnIndex: Input column index (0 for row count)
    ///   - outputName: Output column name
    public mutating func addCount(columnIndex: UInt32 = 0, outputName: String = "count") {
        specs.append(Spec(function: .count, columnIndex: columnIndex, outputName: outputName))
    }
    
    /// Add a COUNT_DISTINCT aggregation.
    /// - Parameters:
    ///   - columnIndex: Input column index
    ///   - outputName: Output column name
    public mutating func addCountDistinct(columnIndex: UInt32, outputName: String = "count_distinct") {
        specs.append(Spec(function: .countDistinct, columnIndex: columnIndex, outputName: outputName))
    }
    
    /// Add a SUM aggregation.
    /// - Parameters:
    ///   - columnIndex: Input column index
    ///   - outputName: Output column name
    public mutating func addSum(columnIndex: UInt32, outputName: String = "sum") {
        specs.append(Spec(function: .sum, columnIndex: columnIndex, outputName: outputName))
    }
    
    /// Add a MEAN aggregation.
    /// - Parameters:
    ///   - columnIndex: Input column index
    ///   - outputName: Output column name
    public mutating func addMean(columnIndex: UInt32, outputName: String = "mean") {
        specs.append(Spec(function: .mean, columnIndex: columnIndex, outputName: outputName))
    }
    
    /// Add a MIN aggregation.
    /// - Parameters:
    ///   - columnIndex: Input column index
    ///   - outputName: Output column name
    public mutating func addMin(columnIndex: UInt32, outputName: String = "min") {
        specs.append(Spec(function: .min, columnIndex: columnIndex, outputName: outputName))
    }
    
    /// Add a MAX aggregation.
    /// - Parameters:
    ///   - columnIndex: Input column index
    ///   - outputName: Output column name
    public mutating func addMax(columnIndex: UInt32, outputName: String = "max") {
        specs.append(Spec(function: .max, columnIndex: columnIndex, outputName: outputName))
    }
    
    /// Add a MEDIAN aggregation.
    /// - Parameters:
    ///   - columnIndex: Input column index
    ///   - outputName: Output column name
    public mutating func addMedian(columnIndex: UInt32, outputName: String = "median") {
        specs.append(Spec(function: .median, columnIndex: columnIndex, outputName: outputName))
    }
    
    /// Add a QUANTILE aggregation.
    /// - Parameters:
    ///   - columnIndex: Input column index
    ///   - quantile: Quantile value (0.0 to 1.0)
    ///   - outputName: Output column name
    public mutating func addQuantile(columnIndex: UInt32, quantile: Double, outputName: String = "quantile") {
        specs.append(Spec(function: .quantile(quantile), columnIndex: columnIndex, outputName: outputName, parameter: quantile))
    }
    
    /// Add a STDDEV aggregation.
    /// - Parameters:
    ///   - columnIndex: Input column index
    ///   - outputName: Output column name
    public mutating func addStddev(columnIndex: UInt32, outputName: String = "stddev") {
        specs.append(Spec(function: .stddev, columnIndex: columnIndex, outputName: outputName))
    }
    
    /// Add a VARIANCE aggregation.
    /// - Parameters:
    ///   - columnIndex: Input column index
    ///   - outputName: Output column name
    public mutating func addVariance(columnIndex: UInt32, outputName: String = "variance") {
        specs.append(Spec(function: .variance, columnIndex: columnIndex, outputName: outputName))
    }
    
    /// Serialize specifications to binary format expected by C++ implementation.
    public func serialize() -> Data {
        var data = Data()
        
        for spec in specs {
            // uint8_t fn
            data.append(UInt8(spec.function.toCType().rawValue))
            
            // uint32_t col_idx
            withUnsafeBytes(of: spec.columnIndex.littleEndian) { data.append(contentsOf: $0) }
            
            // uint16_t name_len
            let nameBytes = spec.outputName.utf8
            let nameLen = UInt16(nameBytes.count)
            withUnsafeBytes(of: nameLen.littleEndian) { data.append(contentsOf: $0) }
            
            // char[name_len]
            data.append(contentsOf: nameBytes)
            
            // double param (only for QUANTILE)
            if case .quantile = spec.function {
                withUnsafeBytes(of: spec.parameter.bitPattern.littleEndian) { data.append(contentsOf: $0) }
            }
        }
        
        return data
    }
    
    /// Get the number of specifications.
    public var count: Int { specs.count }
    
    /// Check if builder is empty.
    public var isEmpty: Bool { specs.isEmpty }
}

/// Builder for filter predicates.
public struct PredicateBuilder {
    /// Single predicate.
    public struct Predicate {
        let operation: PredicateOperation
        let columnIndex: UInt32
        let columnType: ScalarType
        let values: [Any]
        
        public init(operation: PredicateOperation, columnIndex: UInt32, columnType: ScalarType, values: [Any] = []) {
            self.operation = operation
            self.columnIndex = columnIndex
            self.columnType = columnType
            self.values = values
        }
    }
    
    /// Predicate operation.
    public enum PredicateOperation: UInt8 {
        case equal = 1
        case notEqual = 2
        case lessThan = 3
        case lessThanOrEqual = 4
        case greaterThan = 5
        case greaterThanOrEqual = 6
        case inSet = 7
        case between = 8
        case isNull = 9
        case isNotNull = 10
        
        func toCType() -> UInt8 { rawValue }
    }
    
    private var predicates: [Predicate] = []
    
    public init() {}
    
    // Helper to append a predicate with value
    private mutating func append(_ operation: PredicateOperation, columnIndex: UInt32, columnType: ScalarType, value: Any?) {
        if let value = value {
            predicates.append(Predicate(operation: operation, columnIndex: columnIndex, columnType: columnType, values: [value]))
        } else {
            predicates.append(Predicate(operation: operation, columnIndex: columnIndex, columnType: columnType))
        }
    }
    
    /// Add equality predicate.
    public mutating func equal<T>(columnIndex: UInt32, columnType: ScalarType, value: T) {
        append(.equal, columnIndex: columnIndex, columnType: columnType, value: value)
    }
    
    /// Add inequality predicate.
    public mutating func notEqual<T>(columnIndex: UInt32, columnType: ScalarType, value: T) {
        append(.notEqual, columnIndex: columnIndex, columnType: columnType, value: value)
    }
    
    /// Add less-than predicate.
    public mutating func lessThan<T>(columnIndex: UInt32, columnType: ScalarType, value: T) {
        append(.lessThan, columnIndex: columnIndex, columnType: columnType, value: value)
    }
    
    /// Add less-than-or-equal predicate.
    public mutating func lessThanOrEqual<T>(columnIndex: UInt32, columnType: ScalarType, value: T) {
        append(.lessThanOrEqual, columnIndex: columnIndex, columnType: columnType, value: value)
    }
    
    /// Add greater-than predicate.
    public mutating func greaterThan<T>(columnIndex: UInt32, columnType: ScalarType, value: T) {
        append(.greaterThan, columnIndex: columnIndex, columnType: columnType, value: value)
    }
    
    /// Add greater-than-or-equal predicate.
    public mutating func greaterThanOrEqual<T>(columnIndex: UInt32, columnType: ScalarType, value: T) {
        append(.greaterThanOrEqual, columnIndex: columnIndex, columnType: columnType, value: value)
    }
    
    /// Add IN_SET predicate.
    public mutating func inSet<T>(columnIndex: UInt32, columnType: ScalarType, values: [T]) {
        predicates.append(Predicate(operation: .inSet, columnIndex: columnIndex, columnType: columnType, values: values))
    }
    
    /// Add BETWEEN predicate.
    public mutating func between<T>(columnIndex: UInt32, columnType: ScalarType, lower: T, upper: T) {
        predicates.append(Predicate(operation: .between, columnIndex: columnIndex, columnType: columnType, values: [lower, upper]))
    }
    
    /// Add IS_NULL predicate.
    public mutating func isNull(columnIndex: UInt32, columnType: ScalarType) {
        predicates.append(Predicate(operation: .isNull, columnIndex: columnIndex, columnType: columnType))
    }
    
    /// Add IS_NOT_NULL predicate.
    public mutating func isNotNull(columnIndex: UInt32, columnType: ScalarType) {
        predicates.append(Predicate(operation: .isNotNull, columnIndex: columnIndex, columnType: columnType))
    }
    
    /// Serialize predicates to binary format expected by C++ implementation.
    public func serialize() -> Data {
        var data = Data()
        
        for predicate in predicates {
            // uint8_t op
            data.append(predicate.operation.toCType())
            
            // uint32_t col_idx
            withUnsafeBytes(of: predicate.columnIndex.littleEndian) { data.append(contentsOf: $0) }
            
            // uint8_t col_type
            data.append(UInt8(predicate.columnType.toCType().rawValue))
            
            // value(s) based on operation
            switch predicate.operation {
            case .equal, .notEqual, .lessThan, .lessThanOrEqual, .greaterThan, .greaterThanOrEqual:
                if let value = predicate.values.first {
                    appendValue(value, type: predicate.columnType, to: &data)
                }
                
            case .inSet:
                // Count followed by values
                let count = UInt32(predicate.values.count)
                withUnsafeBytes(of: count.littleEndian) { data.append(contentsOf: $0) }
                for value in predicate.values {
                    appendValue(value, type: predicate.columnType, to: &data)
                }
                
            case .between:
                if predicate.values.count >= 2 {
                    appendValue(predicate.values[0], type: predicate.columnType, to: &data)
                    appendValue(predicate.values[1], type: predicate.columnType, to: &data)
                }
                
            case .isNull, .isNotNull:
                // No values needed
                break
            }
        }
        
        return data
    }
    
    private func appendValue(_ value: Any, type: ScalarType, to data: inout Data) {
        switch type {
        case .int64, .timestampMsUtc:
            if let val = value as? Int64 {
                withUnsafeBytes(of: val.littleEndian) { data.append(contentsOf: $0) }
            } else if let val = value as? Int {
                withUnsafeBytes(of: Int64(val).littleEndian) { data.append(contentsOf: $0) }
            }
        case .uint64:
            if let val = value as? UInt64 {
                withUnsafeBytes(of: val.littleEndian) { data.append(contentsOf: $0) }
            } else if let val = value as? UInt {
                withUnsafeBytes(of: UInt64(val).littleEndian) { data.append(contentsOf: $0) }
            }
        case .float64:
            if let val = value as? Double {
                withUnsafeBytes(of: val.bitPattern.littleEndian) { data.append(contentsOf: $0) }
            } else if let val = value as? Float {
                withUnsafeBytes(of: Double(val).bitPattern.littleEndian) { data.append(contentsOf: $0) }
            }
        case .float32:
            if let val = value as? Float {
                withUnsafeBytes(of: val.bitPattern.littleEndian) { data.append(contentsOf: $0) }
            } else if let val = value as? Double {
                withUnsafeBytes(of: Float(val).bitPattern.littleEndian) { data.append(contentsOf: $0) }
            }
        case .bool:
            if let val = value as? Bool {
                let byte: UInt8 = val ? 1 : 0
                data.append(byte)
            } else if let val = value as? UInt8 {
                data.append(val)
            }
        case .stringUtf8:
            // String not yet supported in predicates
            break
        }
    }
    
    /// Get the number of predicates.
    public var count: Int { predicates.count }
    
    /// Check if builder is empty.
    public var isEmpty: Bool { predicates.isEmpty }
}

/// Builder for sort key specifications.
public struct SortKeyBuilder {
    /// Single sort key.
    public struct SortKey {
        let columnIndex: UInt32
        let ascending: Bool
        let nullsFirst: Bool
        
        public init(columnIndex: UInt32, ascending: Bool = true, nullsFirst: Bool = true) {
            self.columnIndex = columnIndex
            self.ascending = ascending
            self.nullsFirst = nullsFirst
        }
    }
    
    private var sortKeys: [SortKey] = []
    
    public init() {}
    
    /// Add a sort key.
    public mutating func add(columnIndex: UInt32, ascending: Bool = true, nullsFirst: Bool = true) {
        sortKeys.append(SortKey(columnIndex: columnIndex, ascending: ascending, nullsFirst: nullsFirst))
    }
    
    /// Serialize sort keys to binary format expected by C++ implementation.
    public func serialize() -> Data {
        var data = Data()
        
        for key in sortKeys {
            // uint32_t col_idx
            withUnsafeBytes(of: key.columnIndex.littleEndian) { data.append(contentsOf: $0) }
            
            // uint8_t direction (1=asc, 2=desc)
            let direction: UInt8 = key.ascending ? 1 : 2
            data.append(direction)
            
            // uint8_t nulls_order (1=first, 2=last)
            let nullsOrder: UInt8 = key.nullsFirst ? 1 : 2
            data.append(nullsOrder)
        }
        
        return data
    }
    
    /// Get the number of sort keys.
    public var count: Int { sortKeys.count }
    
    /// Check if builder is empty.
    public var isEmpty: Bool { sortKeys.isEmpty }
}

/// Aggregation metadata.
public struct AggregationMetadata {
    public var domains: Data?
    public var quantiles: Data?
    public var ticks: Data?
    
    init(from cMeta: anigma_viz_aggregation_meta_t) {
        // Convert opaque data blobs to Data if present
        if cMeta.domains_bytes > 0, let domainsPtr = cMeta.domains {
            domains = Data(bytes: domainsPtr, count: cMeta.domains_bytes)
        } else {
            domains = nil
        }
        
        if cMeta.quantiles_bytes > 0, let quantilesPtr = cMeta.quantiles {
            quantiles = Data(bytes: quantilesPtr, count: cMeta.quantiles_bytes)
        } else {
            quantiles = nil
        }
        
        if cMeta.ticks_bytes > 0, let ticksPtr = cMeta.ticks {
            ticks = Data(bytes: ticksPtr, count: cMeta.ticks_bytes)
        } else {
            ticks = nil
        }
    }
}