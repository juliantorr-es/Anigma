/**
 * TableExtractionCapsule C++ Implementation
 */

#include "TableExtractionCapsule/table_extraction_capsule.h"
#include "anigma_capsule_core.h"
#include "anigma_status.h"
#include <vector>
#include <memory>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <map>
#include <set>

// Forward declarations
namespace {

// Helper to duplicate strings safely
char* safe_strdup(const char* s) {
    if (!s) return nullptr;
    size_t len = strlen(s);
    char* d = (char*)malloc(len + 1);
    if (d) memcpy(d, s, len + 1);
    return d;
}

// Helper to duplicate strings with length
char* safe_strndup(const char* s, size_t len) {
    if (!s) return nullptr;
    char* d = (char*)malloc(len + 1);
    if (d) {
        memcpy(d, s, len);
        d[len] = '\0';
    }
    return d;
}

// Helper to duplicate std::string to char*
char* safe_string_dup(const std::string& s) {
    return safe_strndup(s.c_str(), s.length());
}

class TableExtractionContext {
public:
    explicit TableExtractionContext(const struct anigma_table_extraction_config_t& config)
        : config_(config) {
        // Initialize context
        if (config.enable_ml_detection) {
            // TODO: Initialize ONNX Runtime if needed
        }
    }

    ~TableExtractionContext() {
        // Cleanup
        if (config_.enable_ml_detection) {
            // TODO: Cleanup ONNX Runtime
        }
    }

    struct anigma_table_extraction_config_t config_;
    // TODO: Add ML model and ONNX Runtime state
};

// Internal structures
struct InternalTableCell {
    int32_t row;
    int32_t column;
    std::string text;
    anigma_table_bbox_t bbox;
    int32_t page_index;
};

struct InternalTable {
    anigma_table_bbox_t bbox;
    std::vector<InternalTableCell> cells;
    int32_t page_index;
};

// Helper functions
inline double calculate_bbox_area(const struct anigma_layout_segment_t& segment) {
    double width = segment.bbox.right - segment.bbox.left;
    double height = segment.bbox.bottom - segment.bbox.top;
    return width * height;
}

inline bool is_horizontal_line(const struct anigma_layout_segment_t& seg1, 
                               const struct anigma_layout_segment_t& seg2, 
                               double tolerance) {
    double y_diff = std::abs(seg1.bbox.top - seg2.bbox.top);
    return y_diff < tolerance;
}

inline bool is_vertical_line(const struct anigma_layout_segment_t& seg1, 
                             const struct anigma_layout_segment_t& seg2, 
                             double tolerance) {
    double x_diff = std::abs(seg1.bbox.left - seg2.bbox.left);
    return x_diff < tolerance;
}

// Forward declarations
std::vector<InternalTableCell> create_cells_from_clustering(
    const std::vector<struct anigma_layout_segment_t>& segments,
    int32_t page_index);

// Table detection algorithms
std::vector<size_t> detect_table_lines(const std::vector<struct anigma_layout_segment_t>& segments, 
                                      double page_width, 
                                      double page_height, 
                                      double min_table_area) {
    std::vector<size_t> table_lines;
    
    if (segments.empty()) {
        return table_lines;
    }
    
    // Sort segments by position for analysis
    std::vector<struct anigma_layout_segment_t> sorted_segments = segments;
    std::sort(sorted_segments.begin(), sorted_segments.end(), 
        [](const auto& a, const auto& b) {
            return a.bbox.top < b.bbox.top || 
                   (a.bbox.top == b.bbox.top && a.bbox.left < b.bbox.left);
        });
    
    // Analyze segments to detect potential table lines
    // We look for horizontal and vertical alignments that suggest table structure
    
    // Group segments by y-coordinate (potential horizontal lines)
    std::map<double, std::vector<size_t>> y_groups;
    for (size_t i = 0; i < sorted_segments.size(); ++i) {
        const auto& seg = sorted_segments[i];
        double y_center = (seg.bbox.top + seg.bbox.bottom) / 2.0;
        y_groups[y_center].push_back(i);
    }
    
    // Group segments by x-coordinate (potential vertical lines)
    std::map<double, std::vector<size_t>> x_groups;
    for (size_t i = 0; i < sorted_segments.size(); ++i) {
        const auto& seg = sorted_segments[i];
        double x_center = (seg.bbox.left + seg.bbox.right) / 2.0;
        x_groups[x_center].push_back(i);
    }
    
    // Identify significant horizontal alignments (potential table rows)
    for (const auto& [y_pos, indices] : y_groups) {
        if (indices.size() >= 2) { // At least 2 segments at this y position
            double total_width = 0.0;
            for (size_t idx : indices) {
                total_width += (sorted_segments[idx].bbox.right - sorted_segments[idx].bbox.left);
            }
            double avg_width = total_width / indices.size();
            
            // Consider it a table line if we have multiple segments with reasonable width
            if (avg_width > 50.0) { // Minimum reasonable cell width
                for (size_t idx : indices) {
                    table_lines.push_back(idx);
                }
            }
        }
    }
    
    // Identify significant vertical alignments (potential table columns)
    for (const auto& [x_pos, indices] : x_groups) {
        if (indices.size() >= 2) { // At least 2 segments at this x position
            double total_height = 0.0;
            for (size_t idx : indices) {
                total_height += (sorted_segments[idx].bbox.bottom - sorted_segments[idx].bbox.top);
            }
            double avg_height = total_height / indices.size();
            
            // Consider it a table line if we have multiple segments with reasonable height
            if (avg_height > 20.0) { // Minimum reasonable cell height
                for (size_t idx : indices) {
                    table_lines.push_back(idx);
                }
            }
        }
    }
    
    return table_lines;
}

// Cell extraction algorithm
std::vector<InternalTableCell> extract_table_cells(
    const std::vector<struct anigma_layout_segment_t>& segments,
    const std::vector<size_t>& horizontal_lines,
    const std::vector<size_t>& vertical_lines,
    int32_t page_index) {
    std::vector<InternalTableCell> cells;
    
    if (segments.empty()) {
        return cells;
    }
    
    // If no lines detected, use a simple grid-based approach
    if (horizontal_lines.empty() && vertical_lines.empty()) {
        // Fallback: create cells based on text segment clustering
        return create_cells_from_clustering(segments, page_index);
    }
    
    // Create a set of line indices for quick lookup
    std::set<size_t> line_indices(horizontal_lines.begin(), horizontal_lines.end());
    line_indices.insert(vertical_lines.begin(), vertical_lines.end());
    
    // Group non-line segments into cells
    std::vector<struct anigma_layout_segment_t> non_line_segments;
    for (size_t i = 0; i < segments.size(); ++i) {
        if (line_indices.find(i) == line_indices.end()) {
            non_line_segments.push_back(segments[i]);
        }
    }
    
    if (non_line_segments.empty()) {
        return cells;
    }
    
    // Sort non-line segments by position
    std::sort(non_line_segments.begin(), non_line_segments.end(),
        [](const auto& a, const auto& b) {
            return a.bbox.top < b.bbox.top || 
                   (a.bbox.top == b.bbox.top && a.bbox.left < b.bbox.left);
        });
    
    // Create cells by grouping segments that are close to each other
    // This is a simplified approach - a real implementation would use
    // more sophisticated algorithms to determine cell boundaries
    
    InternalTableCell current_cell;
    current_cell.row = 0;
    current_cell.column = 0;
    current_cell.text.assign(non_line_segments[0].text, non_line_segments[0].text_len);
    current_cell.bbox = non_line_segments[0].bbox;
    current_cell.page_index = page_index;
    
    for (size_t i = 1; i < non_line_segments.size(); ++i) {
        const auto& seg = non_line_segments[i];
        const auto& last_seg = non_line_segments[i-1];
        
        // Check if this segment belongs to the current cell
        bool same_row = std::abs(seg.bbox.top - last_seg.bbox.top) < 10.0;
        bool same_column = std::abs(seg.bbox.left - last_seg.bbox.left) < 10.0;
        
        if (same_row && same_column) {
            // Extend current cell
            current_cell.text += " ";
            current_cell.text.append(seg.text, seg.text_len);
            
            // Expand bounding box
            current_cell.bbox.left = std::min(current_cell.bbox.left, seg.bbox.left);
            current_cell.bbox.top = std::min(current_cell.bbox.top, seg.bbox.top);
            current_cell.bbox.right = std::max(current_cell.bbox.right, seg.bbox.right);
            current_cell.bbox.bottom = std::max(current_cell.bbox.bottom, seg.bbox.bottom);
        } else {
            // Finalize current cell
            cells.push_back(current_cell);
            
            // Start new cell
            current_cell.row = same_row ? current_cell.row : current_cell.row + 1;
            current_cell.column = same_column ? current_cell.column : current_cell.column + 1;
            current_cell.text.assign(seg.text, seg.text_len);
            current_cell.bbox = seg.bbox;
            current_cell.page_index = page_index;
        }
    }
    
    // Add the last cell
    if (!current_cell.text.empty()) {
        cells.push_back(current_cell);
    }
    
    return cells;
}

// Fallback cell creation using clustering algorithm
std::vector<InternalTableCell> create_cells_from_clustering(
    const std::vector<struct anigma_layout_segment_t>& segments,
    int32_t page_index) {
    std::vector<InternalTableCell> cells;
    
    if (segments.empty()) {
        return cells;
    }
    
    // Simple clustering: group segments that are close to each other
    // This creates a grid-like structure
    
    // First, sort segments by position
    std::vector<struct anigma_layout_segment_t> sorted_segments = segments;
    std::sort(sorted_segments.begin(), sorted_segments.end(),
        [](const auto& a, const auto& b) {
            return a.bbox.top < b.bbox.top || 
                   (a.bbox.top == b.bbox.top && a.bbox.left < b.bbox.left);
        });
    
    // Group into rows based on vertical position
    std::vector<std::vector<struct anigma_layout_segment_t>> rows;
    std::vector<struct anigma_layout_segment_t> current_row;
    current_row.push_back(sorted_segments[0]);
    
    for (size_t i = 1; i < sorted_segments.size(); ++i) {
        const auto& seg = sorted_segments[i];
        const auto& last_seg = current_row.back();
        
        // Check if segment belongs to the same row
        if (std::abs(seg.bbox.top - last_seg.bbox.top) < 20.0) {
            current_row.push_back(seg);
        } else {
            rows.push_back(current_row);
            current_row.clear();
            current_row.push_back(seg);
        }
    }
    
    if (!current_row.empty()) {
        rows.push_back(current_row);
    }
    
    // Now create cells within each row
    for (size_t row_idx = 0; row_idx < rows.size(); ++row_idx) {
        auto& row = rows[row_idx];
        
        // Sort row segments by horizontal position
        std::sort(row.begin(), row.end(),
            [](const auto& a, const auto& b) {
                return a.bbox.left < b.bbox.left;
            });
        
        // Group into columns
        std::vector<std::vector<struct anigma_layout_segment_t>> columns;
        std::vector<struct anigma_layout_segment_t> current_column;
        current_column.push_back(row[0]);
        
        for (size_t i = 1; i < row.size(); ++i) {
            const auto& seg = row[i];
            const auto& last_seg = current_column.back();
            
            // Check if segment belongs to the same column
            if (std::abs(seg.bbox.left - last_seg.bbox.left) < 20.0) {
                current_column.push_back(seg);
            } else {
                columns.push_back(current_column);
                current_column.clear();
                current_column.push_back(seg);
            }
        }
        
        if (!current_column.empty()) {
            columns.push_back(current_column);
        }
        
        // Create cells for this row
        for (size_t col_idx = 0; col_idx < columns.size(); ++col_idx) {
            auto& column = columns[col_idx];
            
            InternalTableCell cell;
            cell.row = static_cast<int32_t>(row_idx);
            cell.column = static_cast<int32_t>(col_idx);
            
            // Combine text from all segments in this cell
            for (const auto& seg : column) {
                if (!cell.text.empty()) {
                    cell.text += " ";
                }
                cell.text.append(seg.text, seg.text_len);
            }
            
            // Calculate bounding box
            if (!column.empty()) {
                cell.bbox.left = column[0].bbox.left;
                cell.bbox.top = column[0].bbox.top;
                cell.bbox.right = column[0].bbox.right;
                cell.bbox.bottom = column[0].bbox.bottom;
                
                for (const auto& seg : column) {
                    cell.bbox.left = std::min(cell.bbox.left, seg.bbox.left);
                    cell.bbox.top = std::min(cell.bbox.top, seg.bbox.top);
                    cell.bbox.right = std::max(cell.bbox.right, seg.bbox.right);
                    cell.bbox.bottom = std::max(cell.bbox.bottom, seg.bbox.bottom);
                }
            }
            
            cell.page_index = page_index;
            cells.push_back(cell);
        }
    }
    
    return cells;
}

} // namespace

// C API Implementation

extern "C" {

anigma_status_t anigma_table_extraction_get_default_config(
    struct anigma_table_extraction_config_t* out_config) {
    if (!out_config) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    *out_config = {
        .enable_ml_detection = false,  // Default to rule-based for determinism
        .min_table_area = 1000.0,      // 1000 square points minimum
        .max_aspect_ratio = 5.0,       // Maximum width/height ratio
        .enable_cell_merging = true,   // Enable cell merging
        .enable_header_detection = true,
        .enable_footer_detection = true,
        .onnx_model_path = nullptr
    };
    
    return ANIGMA_STATUS_OK;
}

anigma_status_t anigma_table_extraction_capsule_create(
    const struct anigma_table_extraction_config_t* config,
    anigma_capsule_handle_t* out_handle) {
    if (!config || !out_handle) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    try {
        // Create context
        auto ctx = std::make_unique<TableExtractionContext>(*config);
        
        // Store context in capsule handle
        *out_handle = reinterpret_cast<anigma_capsule_handle_t>(ctx.release());
        
        return ANIGMA_STATUS_OK;
    } catch (...) {
        return ANIGMA_STATUS_ALLOCATION_FAILED;
    }
}

anigma_status_t anigma_table_extraction_capsule_destroy(
    anigma_capsule_handle_t handle) {
    if (!handle) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    try {
        auto ctx = reinterpret_cast<TableExtractionContext*>(handle);
        delete ctx;
        return ANIGMA_STATUS_OK;
    } catch (...) {
        return ANIGMA_STATUS_INTERNAL_ERROR;
    }
}

anigma_status_t anigma_table_extraction_extract_from_segments(
    anigma_capsule_handle_t handle,
    int32_t page_index,
    const struct anigma_layout_segment_t* segments,
    size_t segment_count,
    double page_width,
    double page_height,
    struct anigma_table_extraction_result_t* out_result) {
    if (!handle || !segments || !out_result) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    try {
        auto ctx = reinterpret_cast<TableExtractionContext*>(handle);
        
        // Convert segments to vector for processing
        std::vector<struct anigma_layout_segment_t> seg_vec;
        seg_vec.reserve(segment_count);
        for (size_t i = 0; i < segment_count; ++i) {
            seg_vec.push_back(segments[i]);
        }
        
        // Detect table lines
        auto horizontal_lines = detect_table_lines(seg_vec, page_width, page_height, 
                                                   ctx->config_.min_table_area);
        auto vertical_lines = detect_table_lines(seg_vec, page_width, page_height, 
                                                 ctx->config_.min_table_area);
        
        // Extract cells
        auto internal_cells = extract_table_cells(seg_vec, horizontal_lines, vertical_lines, page_index);
        
        // Group cells into a single table for now (since detection logic is simplified)
        // In reality, we'd have multiple tables
        InternalTable table;
        table.page_index = page_index;
        if (!internal_cells.empty()) {
            table.bbox = internal_cells[0].bbox;
            for (const auto& cell : internal_cells) {
                table.bbox.left = std::min(table.bbox.left, cell.bbox.left);
                table.bbox.top = std::min(table.bbox.top, cell.bbox.top);
                table.bbox.right = std::max(table.bbox.right, cell.bbox.right);
                table.bbox.bottom = std::max(table.bbox.bottom, cell.bbox.bottom);
            }
            table.cells = internal_cells;
        }
        
        std::vector<InternalTable> tables;
        if (!internal_cells.empty()) {
            tables.push_back(table);
        }
        
        // Populate result
        out_result->table_count = tables.size();
        out_result->processing_time_us = 0; // TODO: Measure actual time
        
        if (out_result->table_count > 0) {
            out_result->tables = (struct anigma_table_t*)malloc(
                sizeof(struct anigma_table_t) * out_result->table_count);
            
            if (out_result->tables) {
                for (size_t i = 0; i < out_result->table_count; ++i) {
                    auto& src_table = tables[i];
                    auto& dst_table = out_result->tables[i];
                    
                    dst_table.page_index = src_table.page_index;
                    dst_table.bounding_box = src_table.bbox;
                    dst_table.cell_count = src_table.cells.size();
                    
                    if (dst_table.cell_count > 0) {
                        dst_table.cells = (struct anigma_table_cell_t*)malloc(
                            sizeof(struct anigma_table_cell_t) * dst_table.cell_count);
                        
                        if (dst_table.cells) {
                            for (size_t j = 0; j < dst_table.cell_count; ++j) {
                                auto& src_cell = src_table.cells[j];
                                auto& dst_cell = dst_table.cells[j];
                                
                                dst_cell.row = src_cell.row;
                                dst_cell.column = src_cell.column;
                                dst_cell.bounding_box = src_cell.bbox;
                                dst_cell.page_index = src_cell.page_index;
                                
                                dst_cell.text = safe_string_dup(src_cell.text);
                                dst_cell.text_len = src_cell.text.length();
                                
                                dst_cell.row_span = 1;
                                dst_cell.col_span = 1;
                                dst_cell.is_header = (src_cell.row == 0);
                            }
                        } else {
                            // Allocation failure for cells - partial cleanup needed
                             // Free previous tables' cells
                            for (size_t k = 0; k < i; ++k) {
                                for (size_t l = 0; l < out_result->tables[k].cell_count; ++l) {
                                    free((void*)out_result->tables[k].cells[l].text);
                                }
                                free(out_result->tables[k].cells);
                            }
                            free(out_result->tables);
                            return ANIGMA_STATUS_ALLOCATION_FAILED;
                        }
                    } else {
                        dst_table.cells = nullptr;
                    }
                }
            } else {
                return ANIGMA_STATUS_ALLOCATION_FAILED;
            }
        } else {
            out_result->tables = nullptr;
        }
        
        return ANIGMA_STATUS_OK;
    } catch (...) {
        return ANIGMA_STATUS_INTERNAL_ERROR;
    }
}

anigma_status_t anigma_table_extraction_extract_from_pdf(
    anigma_capsule_handle_t handle,
    const uint8_t* pdf_data,
    size_t pdf_size,
    struct anigma_table_extraction_result_t* out_result) {
    if (!handle || !pdf_data || !out_result) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    // TODO: Implement PDF-based extraction
    // This would use PDFium to extract text and layout information
    
    out_result->tables = nullptr;
    out_result->table_count = 0;
    out_result->processing_time_us = 0;
    
    return ANIGMA_STATUS_NOT_IMPLEMENTED;
}

anigma_status_t anigma_table_extraction_free_result(
    struct anigma_table_extraction_result_t* result) {
    if (!result) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    // Free allocated memory
    if (result->tables) {
        for (size_t i = 0; i < result->table_count; ++i) {
            auto& table = result->tables[i];
            if (table.cells) {
                for (size_t j = 0; j < table.cell_count; ++j) {
                    free((void*)table.cells[j].text);
                }
                free(table.cells);
            }
        }
        free(result->tables);
        result->tables = nullptr;
    }
    
    result->table_count = 0;
    result->processing_time_us = 0;
    
    return ANIGMA_STATUS_OK;
}

anigma_status_t anigma_table_export_to_json(
    const struct anigma_table_t* table,
    const char** out_json,
    size_t* out_json_len) {
    if (!table || !out_json || !out_json_len) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    // TODO: Implement JSON export
    *out_json = nullptr;
    *out_json_len = 0;
    
    return ANIGMA_STATUS_NOT_IMPLEMENTED;
}

anigma_status_t anigma_table_export_to_csv(
    const struct anigma_table_t* table,
    const char** out_csv,
    size_t* out_csv_len) {
    if (!table || !out_csv || !out_csv_len) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    // TODO: Implement CSV export
    *out_csv = nullptr;
    *out_csv_len = 0;
    
    return ANIGMA_STATUS_NOT_IMPLEMENTED;
}

anigma_status_t anigma_table_free_export(
    const char* data) {
    if (!data) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    // TODO: Free exported data
    return ANIGMA_STATUS_OK;
}

} // extern "C"