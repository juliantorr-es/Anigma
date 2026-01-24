#include "anigma_viz_aggregation_capsule.h"
#include "anigma_capsule_core.h"

#include <cstdint>
#include <cstring>
#include <cstdlib>
#include <vector>
#include <memory>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <functional>
#include <limits>

// ============================================================================
// Internal Implementation Details
// ============================================================================

namespace {

// Viz aggregation capsule internal state
struct VizAggregationCapsuleState {
    // For now, minimal state
    uint64_t instance_id;
    
    explicit VizAggregationCapsuleState() : instance_id(0) {
        // Generate a simple instance ID (in real implementation, use proper ID generation)
        static uint64_t next_id = 1;
        instance_id = next_id++;
    }
};

// Internal column data storage
struct ColumnData {
    std::string name;
    anigma_viz_scalar_type_t type;
    std::vector<uint8_t> data;           // Raw data buffer
    std::vector<uint8_t> null_bitmap;    // Null bitmap (1 bit per element)
    size_t element_count;
    size_t element_size;                 // Size of each element in bytes (0 for variable-length)
    
    ColumnData(const anigma_viz_column_view_t* view) {
        if (!view) {
            throw std::invalid_argument("Column view is null");
        }
        
        name = view->name ? view->name : "";
        type = view->type;
        element_count = view->element_count;
        
        // Determine element size based on type
        switch (type) {
            case ANIGMA_VIZ_SCALAR_I64:
            case ANIGMA_VIZ_SCALAR_U64:
            case ANIGMA_VIZ_SCALAR_TIMESTAMP_MS_UTC:
                element_size = sizeof(int64_t);
                break;
            case ANIGMA_VIZ_SCALAR_F64:
                element_size = sizeof(double);
                break;
            case ANIGMA_VIZ_SCALAR_F32:
                element_size = sizeof(float);
                break;
            case ANIGMA_VIZ_SCALAR_BOOL:
                element_size = sizeof(uint8_t); // Stored as uint8_t
                break;
            case ANIGMA_VIZ_SCALAR_STRING_UTF8:
                element_size = 0; // Variable-length
                break;
            default:
                throw std::invalid_argument("Unknown scalar type");
        }
        
        // Copy data if provided
        if (view->data && element_count > 0) {
            if (element_size > 0) {
                // Fixed-size data
                size_t data_size = element_count * element_size;
                data.resize(data_size);
                std::memcpy(data.data(), view->data, data_size);
            } else {
                // Variable-length strings: for now, treat as opaque blob
                // In real implementation, we'd need to handle string storage
                size_t data_size = view->element_size * element_count;
                if (data_size > 0) {
                    data.resize(data_size);
                    std::memcpy(data.data(), view->data, data_size);
                }
            }
        }
        
        // Copy null bitmap if provided
        if (view->null_bitmap && view->null_bitmap_size > 0) {
            null_bitmap.resize(view->null_bitmap_size);
            std::memcpy(null_bitmap.data(), view->null_bitmap, view->null_bitmap_size);
        } else if (element_count > 0) {
            // Allocate null bitmap initialized to all non-null
            size_t bitmap_size = (element_count + 7) / 8;
            null_bitmap.resize(bitmap_size, 0xFF); // All bits set to 1 (non-null)
        }
    }
    
    // Check if element is null
    bool isNull(size_t index) const {
        if (index >= element_count) return true;
        if (null_bitmap.empty()) return false;
        size_t byte_idx = index / 8;
        size_t bit_idx = index % 8;
        return ((null_bitmap[byte_idx] >> bit_idx) & 1) == 0;
    }
    
    // Get element pointer
    const void* getElement(size_t index) const {
        if (index >= element_count) return nullptr;
        if (element_size > 0) {
            return data.data() + (index * element_size);
        } else {
            // For strings, need more complex handling
            return nullptr;
        }
    }
};

// Internal dataset state
struct DatasetState {
    std::vector<ColumnData> columns;
    size_t row_count;
    
    explicit DatasetState(const anigma_viz_column_view_t* column_views, size_t column_count) {
        if (!column_views || column_count == 0) {
            throw std::invalid_argument("Invalid column views");
        }
        
        columns.reserve(column_count);
        row_count = 0;
        
        for (size_t i = 0; i < column_count; ++i) {
            columns.emplace_back(&column_views[i]);
            if (i == 0) {
                row_count = columns[0].element_count;
            } else if (columns[i].element_count != row_count) {
                throw std::invalid_argument("Column element count mismatch");
            }
        }
    }
};

// Internal aggregation accumulator structures
struct GroupKey {
    std::vector<uint64_t> hash_parts;
    
    bool operator==(const GroupKey& other) const {
        return hash_parts == other.hash_parts;
    }
};

struct GroupKeyHash {
    size_t operator()(const GroupKey& key) const {
        size_t seed = 0;
        for (uint64_t part : key.hash_parts) {
            seed ^= std::hash<uint64_t>{}(part) + 0x9e3779b9 + (seed << 6) + (seed >> 2);
        }
        return seed;
    }
};

// Accumulator for count
struct CountAccumulator {
    uint64_t count = 0;
};

// Accumulator for sum
struct SumAccumulator {
    double sum = 0.0;
    bool is_integer = true;
    int64_t sum_int = 0;
};

// Accumulator for min/max
struct MinMaxAccumulator {
    double min = std::numeric_limits<double>::max();
    double max = std::numeric_limits<double>::lowest();
    bool has_value = false;
};

// Combined accumulator for a group
struct GroupAccumulator {
    CountAccumulator count;
    SumAccumulator sum;
    MinMaxAccumulator minmax;
    // Could add more
};

// Simple aggregation specification (internal format)
struct AggregationSpec {
    anigma_viz_agg_fn_t fn;
    size_t column_index;           // column to aggregate
    std::string output_name;       // output column name
    double param;                  // for quantiles, etc.
    
    AggregationSpec(anigma_viz_agg_fn_t f, size_t col_idx, std::string name, double p = 0.0)
        : fn(f), column_index(col_idx), output_name(std::move(name)), param(p) {}
};

// Simple predicate representation (internal format)
struct Predicate {
    anigma_viz_predicate_op_t op;
    size_t column_index;           // column to evaluate
    anigma_viz_scalar_type_t column_type; // column type for value interpretation
    union {
        int64_t int_val;
        uint64_t uint_val;
        double double_val;
        float float_val;
        uint8_t bool_val;
    } value;
    union {
        int64_t int_val2;          // for BETWEEN second value
        uint64_t uint_val2;
        double double_val2;
        float float_val2;
    } value2;
    std::vector<double> set_values; // for IN_SET
    
    Predicate(anigma_viz_predicate_op_t o, size_t col_idx, anigma_viz_scalar_type_t type)
        : op(o), column_index(col_idx), column_type(type), value{}, value2{} {
        set_values.clear();
    }
};

// Simple sort key representation (internal format)
struct SortKey {
    size_t column_index;           // column to sort by (index in output columns)
    bool ascending;                // true for ascending, false for descending
    bool nulls_first;              // true for nulls first, false for nulls last
    
    SortKey(size_t col_idx, bool asc = true, bool nulls_first_flag = true)
        : column_index(col_idx), ascending(asc), nulls_first(nulls_first_flag) {}
};

// Accumulator for a single aggregation specification within a group
struct SpecAccumulator {
    double sum = 0.0;
    double sum_squares = 0.0;
    double min = std::numeric_limits<double>::max();
    double max = std::numeric_limits<double>::lowest();
    bool has_value = false;
    std::unordered_set<uint64_t> distinct_hashes;
    
    void update(double value) {
        sum += value;
        sum_squares += value * value;
        if (!has_value || value < min) min = value;
        if (!has_value || value > max) max = value;
        has_value = true;
    }
    
    void updateDistinct(uint64_t hash) {
        distinct_hashes.insert(hash);
    }
};

// Helper to hash a column value for distinct counting
uint64_t hashColumnValue(const ColumnData& col, size_t row, anigma_viz_scalar_type_t type) {
    if (col.isNull(row)) {
        return 0; // null hash (distinct from any non-null)
    }
    
    const void* elem = col.getElement(row);
    if (!elem) {
        return 0;
    }
    
    // Use deterministic hash combining bytes
    uint64_t seed = 0;
    if (col.element_size > 0) {
        const uint8_t* bytes = static_cast<const uint8_t*>(elem);
        for (size_t b = 0; b < col.element_size; ++b) {
            seed = (seed * 31) + bytes[b];
        }
    } else {
        // Variable-length strings: hash first N bytes
        // For now, treat as zero
        seed = 0;
    }
    return seed;
}

// Parse simple aggregation specifications from opaque bytes
std::vector<AggregationSpec> parseAggregationSpecs(const void* data, size_t bytes, const DatasetState* dataset) {
    std::vector<AggregationSpec> specs;
    
    if (!data || bytes == 0) {
        // Default: count aggregation
        specs.emplace_back(ANIGMA_VIZ_AGG_COUNT, 0, "count");
        return specs;
    }
    
    // For now, implement a simple format:
    // Each spec is: uint8_t fn, uint32_t col_idx, uint16_t name_len, char[name_len], double param
    // This is a placeholder - real implementation would use proper serialization
    const uint8_t* ptr = static_cast<const uint8_t*>(data);
    size_t offset = 0;
    
    while (offset + sizeof(uint8_t) + sizeof(uint32_t) + sizeof(uint16_t) <= bytes) {
        uint8_t fn_byte = ptr[offset++];
        if (fn_byte < ANIGMA_VIZ_AGG_COUNT || fn_byte > ANIGMA_VIZ_AGG_VARIANCE) {
            break; // invalid function
        }
        
        anigma_viz_agg_fn_t fn = static_cast<anigma_viz_agg_fn_t>(fn_byte);
        
        uint32_t col_idx;
        std::memcpy(&col_idx, ptr + offset, sizeof(uint32_t));
        offset += sizeof(uint32_t);
        
        if (col_idx >= dataset->columns.size()) {
            break; // invalid column index
        }
        
        uint16_t name_len;
        std::memcpy(&name_len, ptr + offset, sizeof(uint16_t));
        offset += sizeof(uint16_t);
        
        if (offset + name_len + sizeof(double) > bytes) {
            break; // not enough data
        }
        
        std::string name(reinterpret_cast<const char*>(ptr + offset), name_len);
        offset += name_len;
        
        double param = 0.0;
        if (fn == ANIGMA_VIZ_AGG_QUANTILE) {
            std::memcpy(&param, ptr + offset, sizeof(double));
            offset += sizeof(double);
        }
        
        specs.emplace_back(fn, col_idx, name, param);
    }
    
    // If parsing failed, return default count spec
    if (specs.empty()) {
        specs.emplace_back(ANIGMA_VIZ_AGG_COUNT, 0, "count");
    }
    
    return specs;
}

// Parse predicate specifications from opaque bytes
std::vector<Predicate> parsePredicates(const void* data, size_t bytes, const DatasetState* dataset) {
    std::vector<Predicate> predicates;
    
    if (!data || bytes == 0) {
        return predicates; // empty list means no filtering
    }
    
    // Simple format: list of predicates with AND semantics
    // Each predicate: uint8_t op, uint32_t col_idx, uint8_t col_type, value(s) based on op
    const uint8_t* ptr = static_cast<const uint8_t*>(data);
    size_t offset = 0;
    
    while (offset < bytes) {
        if (offset + sizeof(uint8_t) + sizeof(uint32_t) + sizeof(uint8_t) > bytes) {
            break; // not enough data for header
        }
        
        uint8_t op_byte = ptr[offset++];
        if (op_byte < ANIGMA_VIZ_PRED_EQ || op_byte > ANIGMA_VIZ_PRED_IS_NOT_NULL) {
            break; // invalid operation
        }
        
        anigma_viz_predicate_op_t op = static_cast<anigma_viz_predicate_op_t>(op_byte);
        
        uint32_t col_idx;
        std::memcpy(&col_idx, ptr + offset, sizeof(uint32_t));
        offset += sizeof(uint32_t);
        
        if (col_idx >= dataset->columns.size()) {
            break; // invalid column index
        }
        
        uint8_t col_type_byte = ptr[offset++];
        if (col_type_byte < ANIGMA_VIZ_SCALAR_I64 || col_type_byte > ANIGMA_VIZ_SCALAR_STRING_UTF8) {
            break; // invalid column type
        }
        
        anigma_viz_scalar_type_t col_type = static_cast<anigma_viz_scalar_type_t>(col_type_byte);
        Predicate pred(op, col_idx, col_type);
        
        // Read value(s) based on operation
        switch (op) {
            case ANIGMA_VIZ_PRED_EQ:
            case ANIGMA_VIZ_PRED_NEQ:
            case ANIGMA_VIZ_PRED_LT:
            case ANIGMA_VIZ_PRED_LTE:
            case ANIGMA_VIZ_PRED_GT:
            case ANIGMA_VIZ_PRED_GTE: {
                // Single value matching column type
                size_t value_size = 0;
                switch (col_type) {
                    case ANIGMA_VIZ_SCALAR_I64:
                    case ANIGMA_VIZ_SCALAR_U64:
                    case ANIGMA_VIZ_SCALAR_TIMESTAMP_MS_UTC:
                        value_size = sizeof(int64_t);
                        break;
                    case ANIGMA_VIZ_SCALAR_F64:
                        value_size = sizeof(double);
                        break;
                    case ANIGMA_VIZ_SCALAR_F32:
                        value_size = sizeof(float);
                        break;
                    case ANIGMA_VIZ_SCALAR_BOOL:
                        value_size = sizeof(uint8_t);
                        break;
                    default:
                        // String not supported yet
                        break;
                }
                
                if (value_size > 0 && offset + value_size <= bytes) {
                    switch (col_type) {
                        case ANIGMA_VIZ_SCALAR_I64:
                        case ANIGMA_VIZ_SCALAR_TIMESTAMP_MS_UTC:
                            std::memcpy(&pred.value.int_val, ptr + offset, value_size);
                            break;
                        case ANIGMA_VIZ_SCALAR_U64:
                            std::memcpy(&pred.value.uint_val, ptr + offset, value_size);
                            break;
                        case ANIGMA_VIZ_SCALAR_F64:
                            std::memcpy(&pred.value.double_val, ptr + offset, value_size);
                            break;
                        case ANIGMA_VIZ_SCALAR_F32:
                            std::memcpy(&pred.value.float_val, ptr + offset, value_size);
                            break;
                        case ANIGMA_VIZ_SCALAR_BOOL:
                            std::memcpy(&pred.value.bool_val, ptr + offset, value_size);
                            break;
                        default:
                            break;
                    }
                    offset += value_size;
                }
                break;
            }
            
            case ANIGMA_VIZ_PRED_BETWEEN: {
                // Two values
                size_t value_size = 0;
                switch (col_type) {
                    case ANIGMA_VIZ_SCALAR_I64:
                    case ANIGMA_VIZ_SCALAR_U64:
                    case ANIGMA_VIZ_SCALAR_TIMESTAMP_MS_UTC:
                        value_size = sizeof(int64_t);
                        break;
                    case ANIGMA_VIZ_SCALAR_F64:
                        value_size = sizeof(double);
                        break;
                    case ANIGMA_VIZ_SCALAR_F32:
                        value_size = sizeof(float);
                        break;
                    default:
                        break;
                }
                
                if (value_size > 0 && offset + 2 * value_size <= bytes) {
                    // First value
                    switch (col_type) {
                        case ANIGMA_VIZ_SCALAR_I64:
                        case ANIGMA_VIZ_SCALAR_TIMESTAMP_MS_UTC:
                            std::memcpy(&pred.value.int_val, ptr + offset, value_size);
                            std::memcpy(&pred.value2.int_val2, ptr + offset + value_size, value_size);
                            break;
                        case ANIGMA_VIZ_SCALAR_U64:
                            std::memcpy(&pred.value.uint_val, ptr + offset, value_size);
                            std::memcpy(&pred.value2.uint_val2, ptr + offset + value_size, value_size);
                            break;
                        case ANIGMA_VIZ_SCALAR_F64:
                            std::memcpy(&pred.value.double_val, ptr + offset, value_size);
                            std::memcpy(&pred.value2.double_val2, ptr + offset + value_size, value_size);
                            break;
                        case ANIGMA_VIZ_SCALAR_F32:
                            std::memcpy(&pred.value.float_val, ptr + offset, value_size);
                            std::memcpy(&pred.value2.float_val2, ptr + offset + value_size, value_size);
                            break;
                        default:
                            break;
                    }
                    offset += 2 * value_size;
                }
                break;
            }
            
            case ANIGMA_VIZ_PRED_IN_SET: {
                // Count followed by values
                if (offset + sizeof(uint32_t) > bytes) {
                    break;
                }
                uint32_t count;
                std::memcpy(&count, ptr + offset, sizeof(uint32_t));
                offset += sizeof(uint32_t);
                
                size_t value_size = 0;
                switch (col_type) {
                    case ANIGMA_VIZ_SCALAR_I64:
                    case ANIGMA_VIZ_SCALAR_U64:
                    case ANIGMA_VIZ_SCALAR_TIMESTAMP_MS_UTC:
                        value_size = sizeof(int64_t);
                        break;
                    case ANIGMA_VIZ_SCALAR_F64:
                        value_size = sizeof(double);
                        break;
                    case ANIGMA_VIZ_SCALAR_F32:
                        value_size = sizeof(float);
                        break;
                    default:
                        break;
                }
                
                if (value_size > 0 && offset + count * value_size <= bytes) {
                    pred.set_values.reserve(count);
                    for (uint32_t i = 0; i < count; ++i) {
                        double val = 0.0;
                        switch (col_type) {
                            case ANIGMA_VIZ_SCALAR_I64: {
                                int64_t int_val;
                                std::memcpy(&int_val, ptr + offset, value_size);
                                val = static_cast<double>(int_val);
                                break;
                            }
                            case ANIGMA_VIZ_SCALAR_U64: {
                                uint64_t uint_val;
                                std::memcpy(&uint_val, ptr + offset, value_size);
                                val = static_cast<double>(uint_val);
                                break;
                            }
                            case ANIGMA_VIZ_SCALAR_F64:
                                std::memcpy(&val, ptr + offset, value_size);
                                break;
                            case ANIGMA_VIZ_SCALAR_F32: {
                                float float_val;
                                std::memcpy(&float_val, ptr + offset, value_size);
                                val = static_cast<double>(float_val);
                                break;
                            }
                            default:
                                break;
                        }
                        pred.set_values.push_back(val);
                        offset += value_size;
                    }
                }
                break;
            }
            
            case ANIGMA_VIZ_PRED_IS_NULL:
            case ANIGMA_VIZ_PRED_IS_NOT_NULL:
                // No additional values needed
                break;
        }
        
        predicates.push_back(pred);
    }
    
    return predicates;
}

// Parse sort key specifications from opaque bytes
std::vector<SortKey> parseSortKeys(const void* data, size_t bytes, const DatasetState* dataset, 
                                   size_t group_column_count, size_t agg_specs_count) {
    std::vector<SortKey> sort_keys;
    
    if (!data || bytes == 0) {
        return sort_keys; // empty list means no sorting
    }
    
    // Simple format: list of sort keys
    // Each key: uint32_t col_idx, uint8_t direction (1=asc, 2=desc), uint8_t nulls_order (1=first, 2=last)
    const uint8_t* ptr = static_cast<const uint8_t*>(data);
    size_t offset = 0;
    size_t total_output_columns = group_column_count + agg_specs_count;
    
    while (offset + sizeof(uint32_t) + 2 * sizeof(uint8_t) <= bytes) {
        uint32_t col_idx;
        std::memcpy(&col_idx, ptr + offset, sizeof(uint32_t));
        offset += sizeof(uint32_t);
        
        uint8_t direction = ptr[offset++];
        uint8_t nulls_order = ptr[offset++];
        
        // Validate column index (must be within output columns)
        if (col_idx >= total_output_columns) {
            break; // invalid column index
        }
        
        bool ascending = (direction == 1); // 1 = ascending, 2 = descending
        bool nulls_first = (nulls_order == 1); // 1 = nulls first, 2 = nulls last
        
        sort_keys.emplace_back(col_idx, ascending, nulls_first);
    }
    
    return sort_keys;
}

// Helper to extract numeric value from column
double getNumericValue(const ColumnData& col, size_t row, anigma_viz_scalar_type_t type) {
    if (col.isNull(row)) {
        return std::numeric_limits<double>::quiet_NaN();
    }
    
    const void* elem = col.getElement(row);
    if (!elem) {
        return std::numeric_limits<double>::quiet_NaN();
    }
    
    switch (type) {
        case ANIGMA_VIZ_SCALAR_I64: {
            int64_t val = *static_cast<const int64_t*>(elem);
            return static_cast<double>(val);
        }
        case ANIGMA_VIZ_SCALAR_U64: {
            uint64_t val = *static_cast<const uint64_t*>(elem);
            return static_cast<double>(val);
        }
        case ANIGMA_VIZ_SCALAR_F64: {
            return *static_cast<const double*>(elem);
        }
        case ANIGMA_VIZ_SCALAR_F32: {
            float val = *static_cast<const float*>(elem);
            return static_cast<double>(val);
        }
        case ANIGMA_VIZ_SCALAR_BOOL: {
            uint8_t val = *static_cast<const uint8_t*>(elem);
            return static_cast<double>(val);
        }
        case ANIGMA_VIZ_SCALAR_TIMESTAMP_MS_UTC: {
            int64_t val = *static_cast<const int64_t*>(elem);
            return static_cast<double>(val);
        }
        default:
            return std::numeric_limits<double>::quiet_NaN();
    }
}

// Helper to compute min/max for a column view
std::pair<double, double> computeColumnDomain(const anigma_viz_column_view_t* col_view) {
    if (!col_view || !col_view->data || col_view->element_count == 0) {
        return {std::numeric_limits<double>::quiet_NaN(), std::numeric_limits<double>::quiet_NaN()};
    }
    
    double min_val = std::numeric_limits<double>::max();
    double max_val = std::numeric_limits<double>::lowest();
    bool has_value = false;
    
    const uint8_t* null_bitmap = static_cast<const uint8_t*>(col_view->null_bitmap);
    size_t element_size = col_view->element_size;
    
    for (size_t i = 0; i < col_view->element_count; ++i) {
        // Check null bitmap if present
        if (null_bitmap) {
            size_t byte_idx = i / 8;
            size_t bit_idx = i % 8;
            if (!(null_bitmap[byte_idx] & (1 << bit_idx))) {
                continue; // null value
            }
        }
        
        const void* elem = static_cast<const uint8_t*>(col_view->data) + i * element_size;
        double val = std::numeric_limits<double>::quiet_NaN();
        
        switch (col_view->type) {
            case ANIGMA_VIZ_SCALAR_I64: {
                int64_t int_val = *static_cast<const int64_t*>(elem);
                val = static_cast<double>(int_val);
                break;
            }
            case ANIGMA_VIZ_SCALAR_U64: {
                uint64_t uint_val = *static_cast<const uint64_t*>(elem);
                val = static_cast<double>(uint_val);
                break;
            }
            case ANIGMA_VIZ_SCALAR_F64: {
                val = *static_cast<const double*>(elem);
                break;
            }
            case ANIGMA_VIZ_SCALAR_F32: {
                float float_val = *static_cast<const float*>(elem);
                val = static_cast<double>(float_val);
                break;
            }
            case ANIGMA_VIZ_SCALAR_BOOL: {
                uint8_t bool_val = *static_cast<const uint8_t*>(elem);
                val = static_cast<double>(bool_val);
                break;
            }
            case ANIGMA_VIZ_SCALAR_TIMESTAMP_MS_UTC: {
                int64_t ts_val = *static_cast<const int64_t*>(elem);
                val = static_cast<double>(ts_val);
                break;
            }
            case ANIGMA_VIZ_SCALAR_STRING_UTF8:
            default:
                // Non-numeric column, skip
                continue;
        }
        
        if (std::isnan(val)) {
            continue;
        }
        
        if (!has_value) {
            min_val = val;
            max_val = val;
            has_value = true;
        } else {
            if (val < min_val) min_val = val;
            if (val > max_val) max_val = val;
        }
    }
    
    if (!has_value) {
        return {std::numeric_limits<double>::quiet_NaN(), std::numeric_limits<double>::quiet_NaN()};
    }
    
    return {min_val, max_val};
}

// Evaluate a single predicate against a row
bool evaluateSinglePredicate(const Predicate& pred, const DatasetState* dataset, size_t row) {
    const ColumnData& col = dataset->columns[pred.column_index];
    bool is_null = col.isNull(row);
    
    // Handle IS_NULL and IS_NOT_NULL
    if (pred.op == ANIGMA_VIZ_PRED_IS_NULL) {
        return is_null;
    }
    if (pred.op == ANIGMA_VIZ_PRED_IS_NOT_NULL) {
        return !is_null;
    }
    
    // If column is null, comparison predicates evaluate to false (unless null handling policy)
    if (is_null) {
        return false;
    }
    
    // Get column value as double for numeric comparison
    double col_val = getNumericValue(col, row, pred.column_type);
    if (std::isnan(col_val)) {
        return false; // can't compare NaN
    }
    
    switch (pred.op) {
        case ANIGMA_VIZ_PRED_EQ:
            switch (pred.column_type) {
                case ANIGMA_VIZ_SCALAR_I64:
                case ANIGMA_VIZ_SCALAR_TIMESTAMP_MS_UTC:
                    return col_val == static_cast<double>(pred.value.int_val);
                case ANIGMA_VIZ_SCALAR_U64:
                    return col_val == static_cast<double>(pred.value.uint_val);
                case ANIGMA_VIZ_SCALAR_F64:
                    return col_val == pred.value.double_val;
                case ANIGMA_VIZ_SCALAR_F32:
                    return col_val == static_cast<double>(pred.value.float_val);
                case ANIGMA_VIZ_SCALAR_BOOL:
                    return col_val == static_cast<double>(pred.value.bool_val);
                default:
                    return false;
            }
            
        case ANIGMA_VIZ_PRED_NEQ:
            switch (pred.column_type) {
                case ANIGMA_VIZ_SCALAR_I64:
                case ANIGMA_VIZ_SCALAR_TIMESTAMP_MS_UTC:
                    return col_val != static_cast<double>(pred.value.int_val);
                case ANIGMA_VIZ_SCALAR_U64:
                    return col_val != static_cast<double>(pred.value.uint_val);
                case ANIGMA_VIZ_SCALAR_F64:
                    return col_val != pred.value.double_val;
                case ANIGMA_VIZ_SCALAR_F32:
                    return col_val != static_cast<double>(pred.value.float_val);
                case ANIGMA_VIZ_SCALAR_BOOL:
                    return col_val != static_cast<double>(pred.value.bool_val);
                default:
                    return false;
            }
            
        case ANIGMA_VIZ_PRED_LT:
            switch (pred.column_type) {
                case ANIGMA_VIZ_SCALAR_I64:
                case ANIGMA_VIZ_SCALAR_TIMESTAMP_MS_UTC:
                    return col_val < static_cast<double>(pred.value.int_val);
                case ANIGMA_VIZ_SCALAR_U64:
                    return col_val < static_cast<double>(pred.value.uint_val);
                case ANIGMA_VIZ_SCALAR_F64:
                    return col_val < pred.value.double_val;
                case ANIGMA_VIZ_SCALAR_F32:
                    return col_val < static_cast<double>(pred.value.float_val);
                case ANIGMA_VIZ_SCALAR_BOOL:
                    return col_val < static_cast<double>(pred.value.bool_val);
                default:
                    return false;
            }
            
        case ANIGMA_VIZ_PRED_LTE:
            switch (pred.column_type) {
                case ANIGMA_VIZ_SCALAR_I64:
                case ANIGMA_VIZ_SCALAR_TIMESTAMP_MS_UTC:
                    return col_val <= static_cast<double>(pred.value.int_val);
                case ANIGMA_VIZ_SCALAR_U64:
                    return col_val <= static_cast<double>(pred.value.uint_val);
                case ANIGMA_VIZ_SCALAR_F64:
                    return col_val <= pred.value.double_val;
                case ANIGMA_VIZ_SCALAR_F32:
                    return col_val <= static_cast<double>(pred.value.float_val);
                case ANIGMA_VIZ_SCALAR_BOOL:
                    return col_val <= static_cast<double>(pred.value.bool_val);
                default:
                    return false;
            }
            
        case ANIGMA_VIZ_PRED_GT:
            switch (pred.column_type) {
                case ANIGMA_VIZ_SCALAR_I64:
                case ANIGMA_VIZ_SCALAR_TIMESTAMP_MS_UTC:
                    return col_val > static_cast<double>(pred.value.int_val);
                case ANIGMA_VIZ_SCALAR_U64:
                    return col_val > static_cast<double>(pred.value.uint_val);
                case ANIGMA_VIZ_SCALAR_F64:
                    return col_val > pred.value.double_val;
                case ANIGMA_VIZ_SCALAR_F32:
                    return col_val > static_cast<double>(pred.value.float_val);
                case ANIGMA_VIZ_SCALAR_BOOL:
                    return col_val > static_cast<double>(pred.value.bool_val);
                default:
                    return false;
            }
            
        case ANIGMA_VIZ_PRED_GTE:
            switch (pred.column_type) {
                case ANIGMA_VIZ_SCALAR_I64:
                case ANIGMA_VIZ_SCALAR_TIMESTAMP_MS_UTC:
                    return col_val >= static_cast<double>(pred.value.int_val);
                case ANIGMA_VIZ_SCALAR_U64:
                    return col_val >= static_cast<double>(pred.value.uint_val);
                case ANIGMA_VIZ_SCALAR_F64:
                    return col_val >= pred.value.double_val;
                case ANIGMA_VIZ_SCALAR_F32:
                    return col_val >= static_cast<double>(pred.value.float_val);
                case ANIGMA_VIZ_SCALAR_BOOL:
                    return col_val >= static_cast<double>(pred.value.bool_val);
                default:
                    return false;
            }
            
        case ANIGMA_VIZ_PRED_BETWEEN: {
            double lower = 0.0, upper = 0.0;
            switch (pred.column_type) {
                case ANIGMA_VIZ_SCALAR_I64:
                case ANIGMA_VIZ_SCALAR_TIMESTAMP_MS_UTC:
                    lower = static_cast<double>(pred.value.int_val);
                    upper = static_cast<double>(pred.value2.int_val2);
                    break;
                case ANIGMA_VIZ_SCALAR_U64:
                    lower = static_cast<double>(pred.value.uint_val);
                    upper = static_cast<double>(pred.value2.uint_val2);
                    break;
                case ANIGMA_VIZ_SCALAR_F64:
                    lower = pred.value.double_val;
                    upper = pred.value2.double_val2;
                    break;
                case ANIGMA_VIZ_SCALAR_F32:
                    lower = static_cast<double>(pred.value.float_val);
                    upper = static_cast<double>(pred.value2.float_val2);
                    break;
                default:
                    return false;
            }
            return col_val >= lower && col_val <= upper;
        }
            
        case ANIGMA_VIZ_PRED_IN_SET:
            for (double set_val : pred.set_values) {
                if (col_val == set_val) {
                    return true;
                }
            }
            return false;
            
        default:
            return false;
    }
}

// Evaluate all predicates against a row (AND semantics)
bool evaluatePredicate(const std::vector<Predicate>& predicates, const DatasetState* dataset, size_t row) {
    for (const auto& pred : predicates) {
        if (!evaluateSinglePredicate(pred, dataset, row)) {
            return false;
        }
    }
    return true;
}

// Simple predicate evaluator (legacy interface - parses and evaluates)
bool evaluatePredicate(const void* predicate_data, size_t predicate_bytes, 
                      const DatasetState* dataset, size_t row, anigma_capsule_error_t* err) {
    // Parse predicates
    std::vector<Predicate> predicates = parsePredicates(predicate_data, predicate_bytes, dataset);
    
    // Evaluate all predicates (AND semantics)
    return evaluatePredicate(predicates, dataset, row);
}

// Helper to copy element from source to destination
void copyElement(const ColumnData& src_col, size_t src_row, void* dst, size_t dst_offset) {
    if (src_col.isNull(src_row)) {
        // For simplicity, skip null handling in output
        return;
    }
    
    const void* src_elem = src_col.getElement(src_row);
    if (!src_elem || src_col.element_size == 0) {
        return;
    }
    
    uint8_t* dst_ptr = static_cast<uint8_t*>(dst) + dst_offset * src_col.element_size;
    std::memcpy(dst_ptr, src_elem, src_col.element_size);
}

// Validate plan parameters
bool validatePlan(const anigma_viz_aggregation_plan_t* plan, anigma_capsule_error_t* err) {
    if (!plan) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Plan pointer is null";
        }
        return false;
    }
    
    if (plan->mode != ANIGMA_VIZ_AGG_MODE_DETERMINISTIC && 
        plan->mode != ANIGMA_VIZ_AGG_MODE_FAST) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid aggregation mode";
        }
        return false;
    }
    
    if (plan->null_policy < ANIGMA_VIZ_NULL_DISALLOW || 
        plan->null_policy > ANIGMA_VIZ_NULL_PROPAGATE) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid null policy";
        }
        return false;
    }
    
    // Validate select columns if present
    if (plan->select_columns && plan->select_columns_count > 0) {
        for (size_t i = 0; i < plan->select_columns_count; ++i) {
            const auto& col = plan->select_columns[i];
            if (!col.name) {
                if (err) {
                    err->code = ANIGMA_ERR_INVALID_ARG;
                    err->message = "Column name is null";
                }
                return false;
            }
            if (col.type < ANIGMA_VIZ_SCALAR_I64 || col.type > ANIGMA_VIZ_SCALAR_STRING_UTF8) {
                if (err) {
                    err->code = ANIGMA_ERR_INVALID_ARG;
                    err->message = "Invalid column type";
                }
                return false;
            }
        }
    }
    
    // Validate group-by columns if present
    if (plan->group_by && plan->group_by_count > 0) {
        for (size_t i = 0; i < plan->group_by_count; ++i) {
            const auto& col = plan->group_by[i];
            if (!col.name) {
                if (err) {
                    err->code = ANIGMA_ERR_INVALID_ARG;
                    err->message = "Group-by column name is null";
                }
                return false;
            }
        }
    }
    
    return true;
}

// Simple count aggregation implementation
anigma_status_t executeAggregationPlan(
    anigma_viz_dataset_t input,
    const anigma_viz_aggregation_plan_t* plan,
    anigma_viz_dataset_t* out_derived,
    anigma_viz_aggregation_meta_t* out_meta,
    anigma_capsule_error_t* err
) {
    // Validate inputs
    if (!input) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Input dataset handle is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (!plan) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Plan pointer is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (!out_derived) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Output derived dataset pointer is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        DatasetState* input_state = static_cast<DatasetState*>(input);
        size_t row_count = input_state->row_count;
        
        // Parse aggregation specifications
        std::vector<AggregationSpec> agg_specs = parseAggregationSpecs(
            plan->aggregations, plan->aggregations_bytes, input_state);
        
        // Parse predicates (AND semantics)
        std::vector<Predicate> predicates = parsePredicates(
            plan->predicates, plan->predicates_bytes, input_state);
        
        // Parse sort keys
        std::vector<SortKey> sort_keys = parseSortKeys(
            plan->sort_keys, plan->sort_keys_bytes, input_state,
            plan->group_by_count, agg_specs.size());
        
        // Find column indices for group-by columns
        size_t group_by_count = plan->group_by_count;
        const anigma_viz_column_ref_t* group_by = plan->group_by;
        std::vector<size_t> group_column_indices;
        group_column_indices.reserve(group_by_count);
        
        for (size_t i = 0; i < group_by_count; ++i) {
            const anigma_viz_column_ref_t& col_ref = group_by[i];
            size_t found_index = input_state->columns.size();
            for (size_t j = 0; j < input_state->columns.size(); ++j) {
                if (input_state->columns[j].name == col_ref.name) {
                    found_index = j;
                    break;
                }
            }
            if (found_index == input_state->columns.size()) {
                if (err) {
                    err->code = ANIGMA_ERR_INVALID_ARG;
                    err->message = "Group-by column not found in dataset";
                }
                return ANIGMA_ERR_INVALID_ARG;
            }
            group_column_indices.push_back(found_index);
        }
        
        // Find column indices for aggregation columns
        for (auto& spec : agg_specs) {
            if (spec.column_index >= input_state->columns.size()) {
                if (err) {
                    err->code = ANIGMA_ERR_INVALID_ARG;
                    err->message = "Aggregation column index out of bounds";
                }
                return ANIGMA_ERR_INVALID_ARG;
            }
        }
        
        // Determine null policy
        anigma_viz_null_policy_t null_policy = plan->null_policy;
        
        // Enhanced accumulator structure
        struct EnhancedGroupAccumulator {
            uint64_t count = 0;
            size_t first_row_index = 0; // store first row for copying group values
            std::vector<SpecAccumulator> spec_accums;
            
            EnhancedGroupAccumulator(size_t num_specs) : spec_accums(num_specs) {}
        };
        
        std::unordered_map<GroupKey, EnhancedGroupAccumulator, GroupKeyHash> group_accumulators;
        
        // Process all rows
        for (size_t row = 0; row < row_count; ++row) {
            // Check nulls in group columns
            bool has_null_in_group = false;
            for (size_t col_idx : group_column_indices) {
                if (input_state->columns[col_idx].isNull(row)) {
                    has_null_in_group = true;
                    break;
                }
            }
            
            if (has_null_in_group) {
                switch (null_policy) {
                    case ANIGMA_VIZ_NULL_DISALLOW:
                        if (err) {
                            err->code = static_cast<anigma_status_t>(ANIGMA_VIZ_ERR_NULL_POLICY_VIOLATION);
                            err->message = "Null found in group-by column with NULL_DISALLOW policy";
                        }
                        return static_cast<anigma_status_t>(ANIGMA_VIZ_ERR_NULL_POLICY_VIOLATION);
                    case ANIGMA_VIZ_NULL_DROP_ROWS:
                        continue; // skip this row
                    case ANIGMA_VIZ_NULL_PROPAGATE:
                        // For now, skip null rows
                        continue;
                }
            }
            
            // Evaluate predicates (skip row if any predicate fails)
            if (!predicates.empty()) {
                if (!evaluatePredicate(predicates, input_state, row)) {
                    continue; // skip this row
                }
            }
            
            // Build group key
            GroupKey key;
            for (size_t col_idx : group_column_indices) {
                const ColumnData& col = input_state->columns[col_idx];
                const void* elem = col.getElement(row);
                if (!elem) continue;
                
                uint64_t hash = 0;
                if (col.element_size > 0) {
                    const uint8_t* bytes = static_cast<const uint8_t*>(elem);
                    for (size_t b = 0; b < col.element_size; ++b) {
                        hash = (hash * 31) + bytes[b];
                    }
                }
                key.hash_parts.push_back(hash);
            }
            
            // Get or create accumulator for this group
            auto it = group_accumulators.find(key);
            if (it == group_accumulators.end()) {
                it = group_accumulators.emplace(key, EnhancedGroupAccumulator(agg_specs.size())).first;
                it->second.first_row_index = row;
            }
            EnhancedGroupAccumulator& acc = it->second;
            acc.count++;
            
            // Update aggregations for each spec
            for (size_t spec_idx = 0; spec_idx < agg_specs.size(); ++spec_idx) {
                const auto& spec = agg_specs[spec_idx];
                auto& spec_accum = acc.spec_accums[spec_idx];
                
                if (spec.fn == ANIGMA_VIZ_AGG_COUNT) {
                    // count is already handled above via acc.count
                    continue;
                }
                
                const ColumnData& agg_col = input_state->columns[spec.column_index];
                if (agg_col.isNull(row)) {
                    // Skip null values in aggregation columns
                    continue;
                }
                
                double value = getNumericValue(agg_col, row, agg_col.type);
                if (std::isnan(value)) {
                    continue;
                }
                
                // Compute hash for distinct counting (used by COUNT_DISTINCT)
                uint64_t hash = hashColumnValue(agg_col, row, agg_col.type);
                
                switch (spec.fn) {
                    case ANIGMA_VIZ_AGG_SUM:
                    case ANIGMA_VIZ_AGG_MEAN:
                    case ANIGMA_VIZ_AGG_STDDEV:
                    case ANIGMA_VIZ_AGG_VARIANCE:
                        spec_accum.update(value);
                        break;
                    case ANIGMA_VIZ_AGG_MIN:
                        if (!spec_accum.has_value || value < spec_accum.min) {
                            spec_accum.min = value;
                            spec_accum.has_value = true;
                        }
                        break;
                    case ANIGMA_VIZ_AGG_MAX:
                        if (!spec_accum.has_value || value > spec_accum.max) {
                            spec_accum.max = value;
                            spec_accum.has_value = true;
                        }
                        break;
                    case ANIGMA_VIZ_AGG_COUNT_DISTINCT:
                        spec_accum.updateDistinct(hash);
                        break;
                    default:
                        // MEDIAN, QUANTILE not yet implemented
                        break;
                }
            }
            
            // For min/max across all numeric columns (not spec-specific)
            // This is a simplification - real implementation would track per spec
            for (const auto& spec : agg_specs) {
                if (spec.fn == ANIGMA_VIZ_AGG_MIN || spec.fn == ANIGMA_VIZ_AGG_MAX) {
                    // Already handled above
                    continue;
                }
            }
        }
        
        // Create sorted vector of group entries if sorting is required
        std::vector<decltype(group_accumulators)::value_type*> sorted_groups;
        sorted_groups.reserve(group_accumulators.size());
        for (auto it = group_accumulators.begin(); it != group_accumulators.end(); ++it) {
            sorted_groups.push_back(&*it);
        }
        
        // Sort groups if sort keys are specified
        if (!sort_keys.empty()) {
            std::stable_sort(sorted_groups.begin(), sorted_groups.end(),
                [&](const auto* a, const auto* b) {
                    // Compare based on sort keys
                    for (const auto& sort_key : sort_keys) {
                        size_t col_idx = sort_key.column_index;
                        bool a_is_null = false;
                        bool b_is_null = false;
                        double a_val = 0.0;
                        double b_val = 0.0;
                        
                        // Determine if column is a group column or aggregation column
                        if (col_idx < group_by_count) {
                            // Group column: get value from first row of the group
                            size_t input_col_idx = group_column_indices[col_idx];
                            const ColumnData& col = input_state->columns[input_col_idx];
                            size_t row_a = a->second.first_row_index;
                            size_t row_b = b->second.first_row_index;
                            
                            a_is_null = col.isNull(row_a);
                            b_is_null = col.isNull(row_b);
                            
                            if (!a_is_null) a_val = getNumericValue(col, row_a, col.type);
                            if (!b_is_null) b_val = getNumericValue(col, row_b, col.type);
                        } else {
                            // Aggregation column: compute aggregated value
                            size_t agg_idx = col_idx - group_by_count;
                            if (agg_idx >= agg_specs.size()) {
                                // Invalid column index, treat as equal
                                continue;
                            }
                            const auto& spec = agg_specs[agg_idx];
                            const EnhancedGroupAccumulator& acc_a = a->second;
                            const EnhancedGroupAccumulator& acc_b = b->second;
                            
                            // Get spec accumulators for this aggregation
                            const SpecAccumulator& spec_a = acc_a.spec_accums[agg_idx];
                            const SpecAccumulator& spec_b = acc_b.spec_accums[agg_idx];
                            
                            // Compute aggregated value for this spec
                            switch (spec.fn) {
                                case ANIGMA_VIZ_AGG_COUNT:
                                    a_val = static_cast<double>(acc_a.count);
                                    b_val = static_cast<double>(acc_b.count);
                                    // COUNT always has a value (count >= 0)
                                    a_is_null = false;
                                    b_is_null = false;
                                    break;
                                case ANIGMA_VIZ_AGG_COUNT_DISTINCT:
                                    // COUNT_DISTINCT always has a value (distinct count >= 0)
                                    a_is_null = false;
                                    b_is_null = false;
                                    a_val = static_cast<double>(spec_a.distinct_hashes.size());
                                    b_val = static_cast<double>(spec_b.distinct_hashes.size());
                                    break;
                                case ANIGMA_VIZ_AGG_SUM:
                                    a_is_null = !spec_a.has_value;
                                    b_is_null = !spec_b.has_value;
                                    if (!a_is_null) a_val = spec_a.sum;
                                    if (!b_is_null) b_val = spec_b.sum;
                                    break;
                                case ANIGMA_VIZ_AGG_MEAN:
                                    a_is_null = !spec_a.has_value;
                                    b_is_null = !spec_b.has_value;
                                    if (!a_is_null) a_val = (acc_a.count > 0) ? spec_a.sum / static_cast<double>(acc_a.count) : 0.0;
                                    if (!b_is_null) b_val = (acc_b.count > 0) ? spec_b.sum / static_cast<double>(acc_b.count) : 0.0;
                                    break;
                                case ANIGMA_VIZ_AGG_MIN:
                                    a_is_null = !spec_a.has_value;
                                    b_is_null = !spec_b.has_value;
                                    if (!a_is_null) a_val = spec_a.min;
                                    if (!b_is_null) b_val = spec_b.min;
                                    break;
                                case ANIGMA_VIZ_AGG_MAX:
                                    a_is_null = !spec_a.has_value;
                                    b_is_null = !spec_b.has_value;
                                    if (!a_is_null) a_val = spec_a.max;
                                    if (!b_is_null) b_val = spec_b.max;
                                    break;
                                case ANIGMA_VIZ_AGG_VARIANCE:
                                case ANIGMA_VIZ_AGG_STDDEV:
                                    a_is_null = !spec_a.has_value;
                                    b_is_null = !spec_b.has_value;
                                    if (!a_is_null && acc_a.count > 0) {
                                        double sum = spec_a.sum;
                                        double sum_squares = spec_a.sum_squares;
                                        double variance = (sum_squares - (sum * sum) / static_cast<double>(acc_a.count)) / static_cast<double>(acc_a.count);
                                        a_val = (spec.fn == ANIGMA_VIZ_AGG_STDDEV) ? std::sqrt(variance) : variance;
                                    }
                                    if (!b_is_null && acc_b.count > 0) {
                                        double sum = spec_b.sum;
                                        double sum_squares = spec_b.sum_squares;
                                        double variance = (sum_squares - (sum * sum) / static_cast<double>(acc_b.count)) / static_cast<double>(acc_b.count);
                                        b_val = (spec.fn == ANIGMA_VIZ_AGG_STDDEV) ? std::sqrt(variance) : variance;
                                    }
                                    break;
                                default:
                                    // Not implemented, treat as equal
                                    continue;
                            }
                        }
                        
                        // Handle nulls based on nulls_first flag
                        if (a_is_null || b_is_null) {
                            if (a_is_null && b_is_null) {
                                continue; // both null, move to next sort key
                            }
                            if (sort_key.nulls_first) {
                                return a_is_null; // nulls come first
                            } else {
                                return !a_is_null; // nulls come last
                            }
                        }
                        
                        // Compare values
                        if (a_val < b_val) {
                            return sort_key.ascending;
                        }
                        if (a_val > b_val) {
                            return !sort_key.ascending;
                        }
                        // Equal values, continue to next sort key
                    }
                    // All sort keys equal, use deterministic tie-breaker: compare group key hash
                    // Compute combined hash for each group
                    auto computeHash = [](const GroupKey& key) {
                        size_t seed = 0;
                        for (uint64_t part : key.hash_parts) {
                            seed ^= std::hash<uint64_t>{}(part) + 0x9e3779b9 + (seed << 6) + (seed >> 2);
                        }
                        return seed;
                    };
                    size_t hash_a = computeHash(a->first);
                    size_t hash_b = computeHash(b->first);
                    return hash_a < hash_b;
                });
        } else {
            // No explicit sort keys, sort by group key hash for deterministic ordering
            std::stable_sort(sorted_groups.begin(), sorted_groups.end(),
                [](const auto* a, const auto* b) {
                    // Compute combined hash for each group
                    auto computeHash = [](const GroupKey& key) {
                        size_t seed = 0;
                        for (uint64_t part : key.hash_parts) {
                            seed ^= std::hash<uint64_t>{}(part) + 0x9e3779b9 + (seed << 6) + (seed >> 2);
                        }
                        return seed;
                    };
                    size_t hash_a = computeHash(a->first);
                    size_t hash_b = computeHash(b->first);
                    return hash_a < hash_b;
                });
        }
        
        // Apply limit if specified (truncate sorted groups before creating output)
        if (plan->limit_rows > 0 && plan->limit_rows < sorted_groups.size()) {
            sorted_groups.resize(plan->limit_rows);
        }
        size_t num_groups = sorted_groups.size();
        
        // Prepare output columns
        std::vector<anigma_viz_column_view_t> output_columns;
        
        // Add group columns
        for (size_t i = 0; i < group_by_count; ++i) {
            size_t col_idx = group_column_indices[i];
            const ColumnData& input_col = input_state->columns[col_idx];
            size_t element_size = input_col.element_size;
            
            if (element_size == 0) {
                // Variable-length strings not yet supported
                if (err) {
                    err->code = ANIGMA_ERR_NOT_IMPLEMENTED;
                    err->message = "Variable-length string columns not yet supported";
                }
                return ANIGMA_ERR_NOT_IMPLEMENTED;
            }
            
            size_t buffer_size = num_groups * element_size;
            std::vector<uint8_t> buffer(buffer_size);
            
            // Fill buffer with values from first row of each group (in sorted order)
            size_t group_index = 0;
            for (const auto* pair_ptr : sorted_groups) {
                const EnhancedGroupAccumulator& acc = pair_ptr->second;
                copyElement(input_col, acc.first_row_index, buffer.data(), group_index);
                group_index++;
            }
            
            anigma_viz_column_view_t col_view;
            col_view.name = input_col.name.c_str();
            col_view.type = input_col.type;
            col_view.data = buffer.data();
            col_view.element_count = num_groups;
            col_view.element_size = element_size;
            col_view.null_bitmap = nullptr;
            col_view.null_bitmap_size = 0;
            output_columns.push_back(col_view);
        }
        
        // Add aggregation result columns
        for (const auto& spec : agg_specs) {
            size_t spec_idx = &spec - &agg_specs[0];
            const ColumnData& agg_col = input_state->columns[spec.column_index];
            anigma_viz_scalar_type_t output_type = ANIGMA_VIZ_SCALAR_F64; // most aggs produce double
            
            switch (spec.fn) {
                case ANIGMA_VIZ_AGG_COUNT:
                case ANIGMA_VIZ_AGG_COUNT_DISTINCT:
                    output_type = ANIGMA_VIZ_SCALAR_U64;
                    break;
                default:
                    output_type = ANIGMA_VIZ_SCALAR_F64;
                    break;
            }
            
            size_t element_size = 0;
            switch (output_type) {
                case ANIGMA_VIZ_SCALAR_U64:
                    element_size = sizeof(uint64_t);
                    break;
                case ANIGMA_VIZ_SCALAR_F64:
                    element_size = sizeof(double);
                    break;
                default:
                    element_size = sizeof(double);
                    break;
            }
            
            size_t buffer_size = num_groups * element_size;
            std::vector<uint8_t> buffer(buffer_size);
            
            size_t group_index = 0;
            for (const auto* pair_ptr : sorted_groups) {
                const EnhancedGroupAccumulator& acc = pair_ptr->second;
                double result = 0.0;
                uint64_t result_uint = 0;
                
                switch (spec.fn) {
                    case ANIGMA_VIZ_AGG_COUNT:
                        result_uint = acc.count;
                        std::memcpy(buffer.data() + group_index * element_size, &result_uint, element_size);
                        break;
                    case ANIGMA_VIZ_AGG_COUNT_DISTINCT:
                        result_uint = acc.spec_accums[spec_idx].distinct_hashes.size();
                        std::memcpy(buffer.data() + group_index * element_size, &result_uint, element_size);
                        break;
                    case ANIGMA_VIZ_AGG_SUM:
                        result = acc.spec_accums[spec_idx].sum;
                        std::memcpy(buffer.data() + group_index * element_size, &result, element_size);
                        break;
                    case ANIGMA_VIZ_AGG_MEAN:
                        result = (acc.count > 0) ? acc.spec_accums[spec_idx].sum / static_cast<double>(acc.count) : 0.0;
                        std::memcpy(buffer.data() + group_index * element_size, &result, element_size);
                        break;
                    case ANIGMA_VIZ_AGG_MIN:
                        result = acc.spec_accums[spec_idx].has_value ? acc.spec_accums[spec_idx].min : 0.0;
                        std::memcpy(buffer.data() + group_index * element_size, &result, element_size);
                        break;
                    case ANIGMA_VIZ_AGG_MAX:
                        result = acc.spec_accums[spec_idx].has_value ? acc.spec_accums[spec_idx].max : 0.0;
                        std::memcpy(buffer.data() + group_index * element_size, &result, element_size);
                        break;
                    case ANIGMA_VIZ_AGG_VARIANCE:
                    case ANIGMA_VIZ_AGG_STDDEV:
                        if (acc.count > 0 && acc.spec_accums[spec_idx].has_value) {
                            double sum = acc.spec_accums[spec_idx].sum;
                            double sum_squares = acc.spec_accums[spec_idx].sum_squares;
                            double variance = (sum_squares - (sum * sum) / static_cast<double>(acc.count)) / static_cast<double>(acc.count);
                            if (spec.fn == ANIGMA_VIZ_AGG_STDDEV) {
                                result = std::sqrt(variance);
                            } else {
                                result = variance;
                            }
                        } else {
                            result = 0.0;
                        }
                        std::memcpy(buffer.data() + group_index * element_size, &result, element_size);
                        break;
                    default:
                        result = 0.0;
                        std::memcpy(buffer.data() + group_index * element_size, &result, element_size);
                        break;
                }
                group_index++;
            }
            
            anigma_viz_column_view_t col_view;
            col_view.name = spec.output_name.c_str();
            col_view.type = output_type;
            col_view.data = buffer.data();
            col_view.element_count = num_groups;
            col_view.element_size = element_size;
            col_view.null_bitmap = nullptr;
            col_view.null_bitmap_size = 0;
            output_columns.push_back(col_view);
        }
        

        
        // Create output dataset
        anigma_viz_dataset_t output_dataset;
        anigma_status_t status = anigma_viz_dataset_create_from_columns(
            output_columns.data(), output_columns.size(), &output_dataset, err);
        
        if (status != ANIGMA_OK) {
            return status;
        }
        
        *out_derived = output_dataset;
        
        // Generate metadata
        if (out_meta) {
            // Generate domains for numeric columns
            struct DomainRecord {
                uint32_t col_index;
                uint8_t col_type;
                double min_val;
                double max_val;
            };
            
            std::vector<DomainRecord> domain_records;
            for (size_t i = 0; i < output_columns.size(); ++i) {
                const auto& col_view = output_columns[i];
                // Only numeric columns have domains
                if (col_view.type == ANIGMA_VIZ_SCALAR_I64 ||
                    col_view.type == ANIGMA_VIZ_SCALAR_U64 ||
                    col_view.type == ANIGMA_VIZ_SCALAR_F64 ||
                    col_view.type == ANIGMA_VIZ_SCALAR_F32 ||
                    col_view.type == ANIGMA_VIZ_SCALAR_BOOL ||
                    col_view.type == ANIGMA_VIZ_SCALAR_TIMESTAMP_MS_UTC) {
                    
                    auto domain = computeColumnDomain(&col_view);
                    double min_val = domain.first;
                    double max_val = domain.second;
                    if (!std::isnan(min_val) && !std::isnan(max_val)) {
                        domain_records.push_back({
                            static_cast<uint32_t>(i),
                            static_cast<uint8_t>(col_view.type),
                            min_val,
                            max_val
                        });
                    }
                }
            }
            
            // Allocate domains buffer
            if (!domain_records.empty()) {
                size_t domains_size = domain_records.size() * sizeof(DomainRecord);
                DomainRecord* domains_buf = static_cast<DomainRecord*>(std::malloc(domains_size));
                if (domains_buf) {
                    std::memcpy(domains_buf, domain_records.data(), domains_size);
                    out_meta->domains = domains_buf;
                    out_meta->domains_bytes = domains_size;
                } else {
                    out_meta->domains = nullptr;
                    out_meta->domains_bytes = 0;
                }
            } else {
                out_meta->domains = nullptr;
                out_meta->domains_bytes = 0;
            }
            
            // Quantiles and ticks not yet implemented
            out_meta->quantiles = nullptr;
            out_meta->quantiles_bytes = 0;
            out_meta->ticks = nullptr;
            out_meta->ticks_bytes = 0;
        }
        
        return ANIGMA_OK;
    } catch (const std::exception& e) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = e.what();
        }
        return ANIGMA_ERR_INTERNAL;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Unknown error during aggregation";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

} // anonymous namespace

// ============================================================================
// Public API Implementation
// ============================================================================

anigma_capsule_identity_t anigma_viz_aggregation_capsule_get_identity(void) {
    static const char* capsule_id = "viz_aggregation_capsule";
    static const char* build_hash = "1.0.0-dev";
    static const char* algo_version = "1.0";
    
    return anigma_capsule_identity_t{
        capsule_id,
        build_hash,
        algo_version,
        ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE
    };
}

anigma_status_t anigma_viz_aggregation_capsule_create(
    anigma_viz_aggregation_capsule_t* out_capsule,
    anigma_capsule_error_t* err
) {
    if (!out_capsule) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Output capsule pointer is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        VizAggregationCapsuleState* state = new VizAggregationCapsuleState();
        *out_capsule = static_cast<anigma_viz_aggregation_capsule_t>(state);
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to allocate viz aggregation capsule state";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_viz_aggregation_capsule_destroy(
    anigma_viz_aggregation_capsule_t capsule,
    anigma_capsule_error_t* err
) {
    if (!capsule) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Capsule handle is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        VizAggregationCapsuleState* state = static_cast<VizAggregationCapsuleState*>(capsule);
        delete state;
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to destroy viz aggregation capsule state";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_viz_aggregation_capsule_execute(
    anigma_viz_aggregation_capsule_t capsule,
    anigma_viz_dataset_t input,
    const anigma_viz_aggregation_plan_t* plan,
    anigma_viz_dataset_t* out_derived,
    anigma_viz_aggregation_meta_t* out_meta,
    anigma_capsule_error_t* err
) {
    if (!capsule) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Capsule handle is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (!validatePlan(plan, err)) {
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    // Get internal state (not used in mock, but would be used in real implementation)
    VizAggregationCapsuleState* state = static_cast<VizAggregationCapsuleState*>(capsule);
    (void)state; // Unused in mock
    
    return executeAggregationPlan(input, plan, out_derived, out_meta, err);
}

void anigma_viz_aggregation_capsule_free_meta(
    anigma_viz_aggregation_meta_t* meta
) {
    if (!meta) {
        return;
    }
    
    // Free allocated buffers if they were allocated by the capsule
    if (meta->domains) {
        std::free(const_cast<void*>(meta->domains));
        meta->domains = nullptr;
        meta->domains_bytes = 0;
    }
    if (meta->quantiles) {
        std::free(const_cast<void*>(meta->quantiles));
        meta->quantiles = nullptr;
        meta->quantiles_bytes = 0;
    }
    if (meta->ticks) {
        std::free(const_cast<void*>(meta->ticks));
        meta->ticks = nullptr;
        meta->ticks_bytes = 0;
    }
}

// ============================================================================
// Dataset Management Functions
// ============================================================================

anigma_status_t anigma_viz_dataset_create_from_columns(
    const anigma_viz_column_view_t* columns,
    size_t column_count,
    anigma_viz_dataset_t* out_dataset,
    anigma_capsule_error_t* err
) {
    if (!columns || column_count == 0) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Column views array is null or empty";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (!out_dataset) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Output dataset pointer is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        DatasetState* state = new DatasetState(columns, column_count);
        *out_dataset = static_cast<anigma_viz_dataset_t>(state);
        return ANIGMA_OK;
    } catch (const std::invalid_argument& e) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = e.what();
        }
        return ANIGMA_ERR_INVALID_ARG;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to allocate dataset state";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_viz_dataset_destroy(
    anigma_viz_dataset_t dataset,
    anigma_capsule_error_t* err
) {
    if (!dataset) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Dataset handle is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        DatasetState* state = static_cast<DatasetState*>(dataset);
        delete state;
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to destroy dataset state";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_viz_dataset_get_column_count(
    anigma_viz_dataset_t dataset,
    size_t* out_column_count,
    anigma_capsule_error_t* err
) {
    if (!dataset) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Dataset handle is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (!out_column_count) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Output column count pointer is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        DatasetState* state = static_cast<DatasetState*>(dataset);
        *out_column_count = state->columns.size();
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to get column count";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_viz_dataset_get_column_info(
    anigma_viz_dataset_t dataset,
    size_t column_index,
    anigma_viz_column_ref_t* out_info,
    anigma_capsule_error_t* err
) {
    if (!dataset) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Dataset handle is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (!out_info) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Output column info pointer is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        DatasetState* state = static_cast<DatasetState*>(dataset);
        if (column_index >= state->columns.size()) {
            if (err) {
                err->code = ANIGMA_ERR_INVALID_ARG;
                err->message = "Column index out of bounds";
            }
            return ANIGMA_ERR_INVALID_ARG;
        }
        
        const ColumnData& column = state->columns[column_index];
        out_info->name = column.name.c_str();
        out_info->type = column.type;
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to get column info";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_viz_dataset_get_column_data(
    anigma_viz_dataset_t dataset,
    size_t column_index,
    const void** out_data,
    size_t* out_element_count,
    anigma_capsule_error_t* err
) {
    if (!dataset) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Dataset handle is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (!out_data || !out_element_count) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Output data or element count pointer is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        DatasetState* state = static_cast<DatasetState*>(dataset);
        if (column_index >= state->columns.size()) {
            if (err) {
                err->code = ANIGMA_ERR_INVALID_ARG;
                err->message = "Column index out of bounds";
            }
            return ANIGMA_ERR_INVALID_ARG;
        }
        
        const ColumnData& column = state->columns[column_index];
        *out_data = column.data.data();
        *out_element_count = column.element_count;
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to get column data";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}