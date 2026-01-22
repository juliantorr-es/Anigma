#include "../../include/anigma_layout_engine_capsule.h"
#include "../../include/anigma_capsule_core.h"

#include <cstdint>
#include <cstring>
#include <vector>
#include <memory>
#include <cmath>
#include <algorithm>
#include <unordered_map>
#include <unordered_set>
#include <mutex>
#include <cstdlib>
#include <chrono>

// PDFium includes
#define ANIGMA_ENABLE_PDFIUM 1
#if ANIGMA_ENABLE_PDFIUM
#include "fpdfview.h"
#include "fpdf_text.h"
#include "fpdf_edit.h"
#include "fpdf_sysfontinfo.h"
#endif // ANIGMA_ENABLE_PDFIUM

// OCR includes (conditional compilation)
#define ANIGMA_ENABLE_OCR 1
#if ANIGMA_ENABLE_OCR
#include <tesseract/baseapi.h>
#include <leptonica/allheaders.h>
#endif // ANIGMA_ENABLE_OCR

// ============================================================================
// Internal Implementation Details
// ============================================================================

namespace {

// PDFium library initialization
static void initPDFium() {
#if ANIGMA_ENABLE_PDFIUM
    static std::once_flag initFlag;
    std::call_once(initFlag, []() {
        FPDF_InitLibrary();
    });
#endif
}

// UTF-16 to UTF-8 conversion helpers
static void appendUTF8FromCodePoint(std::string& out, uint32_t cp) {
    if (cp <= 0x7F) {
        out.push_back(static_cast<char>(cp));
    } else if (cp <= 0x7FF) {
        out.push_back(static_cast<char>(0xC0 | (cp >> 6)));
        out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    } else if (cp <= 0xFFFF) {
        out.push_back(static_cast<char>(0xE0 | (cp >> 12)));
        out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
        out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    } else if (cp <= 0x10FFFF) {
        out.push_back(static_cast<char>(0xF0 | (cp >> 18)));
        out.push_back(static_cast<char>(0x80 | ((cp >> 12) & 0x3F)));
        out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
        out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    } else {
        // Invalid code point, replace with replacement character U+FFFD
        out.push_back('\xEF');
        out.push_back('\xBF');
        out.push_back('\xBD');
    }
}

static bool isHighSurrogate(uint16_t code) {
    return code >= 0xD800 && code <= 0xDBFF;
}

static bool isLowSurrogate(uint16_t code) {
    return code >= 0xDC00 && code <= 0xDFFF;
}

static uint32_t combineSurrogates(uint16_t high, uint16_t low) {
    return 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00);
}

// Uniform grid spatial index for fast bounding box queries
class UniformGrid {
private:
    // Grid dimensions and cell size
    double minX_, minY_, maxX_, maxY_;
    double cellSize_;
    size_t cols_, rows_;
    
    // Cell storage: each cell contains vector of indices
    std::vector<std::vector<uint32_t>> cells_;
    
    // Original boxes and indices for fallback and exact intersection test
    std::vector<anigma_bounding_box_t> boxes_;
    std::vector<uint32_t> indices_;
    
    // Convert coordinate to cell index
    inline size_t cellX(double x) const {
        size_t cx = static_cast<size_t>((x - minX_) / cellSize_);
        return std::min(cx, cols_ - 1);
    }
    
    inline size_t cellY(double y) const {
        size_t cy = static_cast<size_t>((y - minY_) / cellSize_);
        return std::min(cy, rows_ - 1);
    }
    
    // Get cell index for cell coordinates
    inline size_t cellIndex(size_t cx, size_t cy) const {
        return cy * cols_ + cx;
    }
    
public:
    // Constructor with page bounds and optional cell size (default 50 points)
    UniformGrid(double pageWidth, double pageHeight, double cellSize = 50.0)
        : minX_(0.0), minY_(0.0), maxX_(pageWidth), maxY_(pageHeight), cellSize_(cellSize) {
        // Ensure positive dimensions
        if (maxX_ <= minX_ || maxY_ <= minY_ || cellSize_ <= 0.0) {
            cols_ = rows_ = 1;
        } else {
            cols_ = static_cast<size_t>(std::ceil((maxX_ - minX_) / cellSize_));
            rows_ = static_cast<size_t>(std::ceil((maxY_ - minY_) / cellSize_));
        }
        cells_.resize(cols_ * rows_);
    }
    
    // Default constructor (for compatibility)
    UniformGrid() : minX_(0.0), minY_(0.0), maxX_(0.0), maxY_(0.0), cellSize_(50.0), cols_(1), rows_(1) {
        cells_.resize(1);
    }
    
    // Initialize grid with page bounds (can be called after default construction)
    void init(double pageWidth, double pageHeight, double cellSize = 50.0) {
        minX_ = 0.0;
        minY_ = 0.0;
        maxX_ = pageWidth;
        maxY_ = pageHeight;
        cellSize_ = cellSize;
        
        if (maxX_ <= minX_ || maxY_ <= minY_ || cellSize_ <= 0.0) {
            cols_ = rows_ = 1;
        } else {
            cols_ = static_cast<size_t>(std::ceil((maxX_ - minX_) / cellSize_));
            rows_ = static_cast<size_t>(std::ceil((maxY_ - minY_) / cellSize_));
        }
        cells_.clear();
        cells_.resize(cols_ * rows_);
        boxes_.clear();
        indices_.clear();
    }
    
    void addBox(const anigma_bounding_box_t& box, uint32_t index) {
        boxes_.push_back(box);
        indices_.push_back(index);
        
        // Determine which cells this box intersects
        size_t startX = cellX(box.left);
        size_t endX = cellX(box.right);
        size_t startY = cellY(box.top);
        size_t endY = cellY(box.bottom);
        
        // Add index to all intersecting cells
        for (size_t y = startY; y <= endY; ++y) {
            for (size_t x = startX; x <= endX; ++x) {
                cells_[cellIndex(x, y)].push_back(index);
            }
        }
    }
    
    void query(const anigma_bounding_box_t& queryBox,
               std::vector<uint32_t>& outIndices,
               size_t maxResults) const {
        if (boxes_.empty()) return;
        
        // Determine cells intersected by query box
        size_t startX = cellX(queryBox.left);
        size_t endX = cellX(queryBox.right);
        size_t startY = cellY(queryBox.top);
        size_t endY = cellY(queryBox.bottom);
        
        // Use visited flags to avoid duplicates (same index in multiple cells)
        std::vector<char> visited(boxes_.size(), 0);
        outIndices.reserve(std::min(maxResults, static_cast<size_t>(64)));
        
        // Collect candidate indices from cells
        for (size_t y = startY; y <= endY; ++y) {
            for (size_t x = startX; x <= endX; ++x) {
                const auto& cell = cells_[cellIndex(x, y)];
                for (uint32_t idx : cell) {
                    if (!visited[idx]) {
                        visited[idx] = 1;
                        // Perform exact intersection test
                        const auto& box = boxes_[idx];
                        if (box.left <= queryBox.right &&
                            box.right >= queryBox.left &&
                            box.top <= queryBox.bottom &&
                            box.bottom >= queryBox.top) {
                            outIndices.push_back(idx);
                            if (outIndices.size() >= maxResults) return;
                        }
                    }
                }
            }
        }
    }
    
    size_t size() const { return boxes_.size(); }
    void clear() {
        boxes_.clear();
        indices_.clear();
        for (auto& cell : cells_) cell.clear();
    }
};

// Alias for backward compatibility (rename SpatialIndex to UniformGrid)
using SpatialIndex = UniformGrid;

// Table detection helper functions (legacy, text-only)
static std::vector<anigma_bounding_box_t> detectTablesFromSegments(
    const std::vector<anigma_text_segment_t>& segments,
    double confidence_threshold) {
    
    std::vector<anigma_bounding_box_t> tables;
    
    if (segments.size() < 4) {
        // Too few segments to form a table
        return tables;
    }
    
    // Group segments by rows (similar y-coordinate within tolerance)
    const double row_tolerance = 5.0; // points
    std::vector<std::vector<const anigma_text_segment_t*>> rows;
    
    // Sort segments by top coordinate (descending - top to bottom)
    std::vector<const anigma_text_segment_t*> sorted_segments;
    sorted_segments.reserve(segments.size());
    for (const auto& seg : segments) {
        sorted_segments.push_back(&seg);
    }
    std::sort(sorted_segments.begin(), sorted_segments.end(),
        [](const anigma_text_segment_t* a, const anigma_text_segment_t* b) {
            return a->bbox.top > b->bbox.top; // higher y = top of page
        });
    
    // Group into rows
    for (const auto* seg : sorted_segments) {
        bool placed = false;
        for (auto& row : rows) {
            if (!row.empty()) {
                const auto* first_in_row = row.front();
                double y_diff = std::fabs(seg->bbox.top - first_in_row->bbox.top);
                if (y_diff <= row_tolerance) {
                    row.push_back(seg);
                    placed = true;
                    break;
                }
            }
        }
        if (!placed) {
            rows.push_back({seg});
        }
    }
    
    // Sort each row by left coordinate
    for (auto& row : rows) {
        std::sort(row.begin(), row.end(),
            [](const anigma_text_segment_t* a, const anigma_text_segment_t* b) {
                return a->bbox.left < b->bbox.left;
            });
    }
    
    // Filter rows with too few segments (likely not part of a table)
    rows.erase(std::remove_if(rows.begin(), rows.end(),
        [](const std::vector<const anigma_text_segment_t*>& row) {
            return row.size() < 2; // need at least 2 columns
        }), rows.end());
    
    if (rows.size() < 2) {
        // Need at least 2 rows for a table
        return tables;
    }
    
    // Simple table detection: look for consistent column alignment
    // For now, just create a bounding box around all segments in candidate rows
    // This is a simplistic approach - a real implementation would detect
    // actual table structure with columns
    
    // Collect all segments from candidate rows
    std::vector<const anigma_text_segment_t*> table_segments;
    for (const auto& row : rows) {
        for (const auto* seg : row) {
            table_segments.push_back(seg);
        }
    }
    
    // Compute bounding box union
    if (!table_segments.empty()) {
        double left = table_segments[0]->bbox.left;
        double top = table_segments[0]->bbox.top;
        double right = table_segments[0]->bbox.right;
        double bottom = table_segments[0]->bbox.bottom;
        
        for (size_t i = 1; i < table_segments.size(); ++i) {
            const auto* seg = table_segments[i];
            left = std::min(left, seg->bbox.left);
            top = std::min(top, seg->bbox.top);
            right = std::max(right, seg->bbox.right);
            bottom = std::max(bottom, seg->bbox.bottom);
        }
        
        // Add some padding
        const double padding = 2.0;
        anigma_bounding_box_t table_bbox;
        table_bbox.left = left - padding;
        table_bbox.top = top - padding;
        table_bbox.right = right + padding;
        table_bbox.bottom = bottom + padding;
        
        // Simple confidence calculation based on grid-like structure
        // For now, just check if we have enough rows and columns
        double confidence = std::min(1.0, 
            (rows.size() * 0.2) + (rows[0].size() * 0.1));
        
        if (confidence >= confidence_threshold) {
            tables.push_back(table_bbox);
        }
    }
    
    return tables;
}

// Figure detection helper functions  
static std::vector<anigma_bounding_box_t> detectFigures(
    FPDF_PAGE page,
    double page_width,
    double page_height) {
    
    std::vector<anigma_bounding_box_t> figures;
    
#if ANIGMA_ENABLE_PDFIUM
    if (!page) {
        return figures;
    }
    
    int obj_count = FPDFPage_CountObjects(page);
    for (int i = 0; i < obj_count; ++i) {
        FPDF_PAGEOBJECT page_obj = FPDFPage_GetObject(page, i);
        if (!page_obj) {
            continue;
        }
        
        int obj_type = FPDFPageObj_GetType(page_obj);
        if (obj_type != FPDF_PAGEOBJ_IMAGE) {
            continue;
        }
        
        // Get bounding box in PDF coordinates (points, bottom-left origin)
        float left, bottom, right, top;
        if (!FPDFPageObj_GetBounds(page_obj, &left, &bottom, &right, &top)) {
            continue;
        }
        
        // Convert to top-left origin coordinate system
        double y_top = page_height - static_cast<double>(top);
        double y_bottom = page_height - static_cast<double>(bottom);
        
        // Create bounding box
        anigma_bounding_box_t bbox;
        bbox.left = static_cast<double>(left);
        bbox.top = y_top;
        bbox.right = static_cast<double>(right);
        bbox.bottom = y_bottom;
        
        figures.push_back(bbox);
    }
#endif
    
    return figures;
}

static std::vector<anigma_image_data_t> extractImages(
    FPDF_PAGE page,
    double page_width,
    double page_height) {
    
    std::vector<anigma_image_data_t> images;
    
#if ANIGMA_ENABLE_PDFIUM
    if (!page) {
        return images;
    }
    
    int obj_count = FPDFPage_CountObjects(page);
    for (int i = 0; i < obj_count; ++i) {
        FPDF_PAGEOBJECT page_obj = FPDFPage_GetObject(page, i);
        if (!page_obj) {
            continue;
        }
        
        int obj_type = FPDFPageObj_GetType(page_obj);
        if (obj_type != FPDF_PAGEOBJ_IMAGE) {
            continue;
        }
        
        // Get bounding box in PDF coordinates (points, bottom-left origin)
        float left, bottom, right, top;
        if (!FPDFPageObj_GetBounds(page_obj, &left, &bottom, &right, &top)) {
            continue;
        }
        
        // Convert to top-left origin coordinate system
        double y_top = page_height - static_cast<double>(top);
        double y_bottom = page_height - static_cast<double>(bottom);
        
        // Create image data structure
        anigma_image_data_t image_data{};
        image_data.bbox.left = static_cast<double>(left);
        image_data.bbox.top = y_top;
        image_data.bbox.right = static_cast<double>(right);
        image_data.bbox.bottom = y_bottom;
        
        // Get image metadata
        FPDF_IMAGEOBJ_METADATA metadata{};
        if (FPDFImageObj_GetImageMetadata(page_obj, page, &metadata)) {
            image_data.width = metadata.width;
            image_data.height = metadata.height;
            image_data.horizontal_dpi = metadata.horizontal_dpi;
            image_data.vertical_dpi = metadata.vertical_dpi;
            image_data.bits_per_pixel = metadata.bits_per_pixel;
            image_data.colorspace = metadata.colorspace;
        } else {
            // Fallback: get pixel size
            unsigned int width = 0, height = 0;
            if (FPDFImageObj_GetImagePixelSize(page_obj, &width, &height)) {
                image_data.width = width;
                image_data.height = height;
            }
            image_data.horizontal_dpi = 0.0f;
            image_data.vertical_dpi = 0.0f;
            image_data.bits_per_pixel = 0;
            image_data.colorspace = 0;
        }
        
        // Get raw image data length
        unsigned long raw_len = FPDFImageObj_GetImageDataRaw(page_obj, nullptr, 0);
        if (raw_len > 0) {
            image_data.raw_data = static_cast<uint8_t*>( (void*)malloc(raw_len));
            if (image_data.raw_data) {
                unsigned long copied = FPDFImageObj_GetImageDataRaw(page_obj, image_data.raw_data, raw_len);
                if (copied == raw_len) {
                    image_data.raw_data_len = raw_len;
                } else {
                    free(image_data.raw_data);
                    image_data.raw_data = nullptr;
                    image_data.raw_data_len = 0;
                }
            }
        } else {
            image_data.raw_data = nullptr;
            image_data.raw_data_len = 0;
        }
        
        // Get first filter string
        int filter_count = FPDFImageObj_GetImageFilterCount(page_obj);
        if (filter_count > 0) {
            unsigned long filter_len = FPDFImageObj_GetImageFilter(page_obj, 0, nullptr, 0);
            if (filter_len > 0) {
                char* filter_buf = static_cast<char*>( (void*)malloc(filter_len));
                if (filter_buf) {
                    unsigned long copied = FPDFImageObj_GetImageFilter(page_obj, 0, filter_buf, filter_len);
                    if (copied == filter_len) {
                        image_data.filter = filter_buf;
                    } else {
                        free(filter_buf);
                        image_data.filter = nullptr;
                    }
                }
            }
        } else {
            image_data.filter = nullptr;
        }
        
        images.push_back(image_data);
    }
#endif
    
    return images;
}

// ============================================================================
// Table Detection Helper Functions
// ============================================================================

// Line segment with coordinates
struct LineSegment {
    double x1, y1, x2, y2;
    double width; // stroke width
    bool isHorizontal() const { return std::fabs(y1 - y2) < 0.1; }
    bool isVertical() const { return std::fabs(x1 - x2) < 0.1; }
    double length() const { 
        double dx = x2 - x1, dy = y2 - y1;
        return std::sqrt(dx*dx + dy*dy);
    }
};

/**
 * Extract line segments from PDF page objects (paths).
 * 
 * This function iterates over all page objects and identifies FPDF_PAGEOBJ_PATH objects
 * that represent lines or rectangles. It uses bounding box analysis to detect horizontal
 * and vertical lines, which are common as table borders.
 * 
 * Limitations: currently uses simple bounding box analysis; does not parse path segments.
 * This may miss diagonal lines or complex paths, but is sufficient for most table borders.
 * 
 * @param page PDFium page handle
 * @param page_height Page height used for coordinate conversion (bottom-left to top-left origin)
 * @param horizontalLines Output vector for detected horizontal lines
 * @param verticalLines Output vector for detected vertical lines
 */
static void extractLinesFromPage(FPDF_PAGE page, double page_height,
                                 std::vector<LineSegment>& horizontalLines,
                                 std::vector<LineSegment>& verticalLines) {
#if ANIGMA_ENABLE_PDFIUM
    if (!page) return;
    
    int obj_count = FPDFPage_CountObjects(page);
    for (int i = 0; i < obj_count; ++i) {
        FPDF_PAGEOBJECT page_obj = FPDFPage_GetObject(page, i);
        if (!page_obj) continue;
        
        int obj_type = FPDFPageObj_GetType(page_obj);
        if (obj_type != FPDF_PAGEOBJ_PATH) continue;
        
        // Get bounding box to quickly check if it's a line/rectangle
        float left, bottom, right, top;
        if (!FPDFPageObj_GetBounds(page_obj, &left, &bottom, &right, &top)) {
            continue;
        }
        
        // Convert to top-left origin coordinate system
        double y_top = page_height - static_cast<double>(top);
        double y_bottom = page_height - static_cast<double>(bottom);
        
        // Check if this is a rectangle (4 points) or a line (2 points)
        // We'll approximate by analyzing path segments (simplified)
        // For now, treat any path with small thickness as potential border
        
        // Try to get stroke width
        float stroke_width = 1.0f;
        // FPDFPageObj_GetStrokeWidth may exist; if not, default
        
        // Check if bounding box is thin (line) or has area (rectangle)
        double width = right - left;
        double height = top - bottom; // note: top > bottom in PDF coordinates
        
        const double epsilon = 0.5; // points
        
        if (width < epsilon && height > epsilon) {
            // Vertical line
            LineSegment line;
            line.x1 = left; line.x2 = left;
            line.y1 = y_top; line.y2 = y_bottom;
            line.width = stroke_width;
            verticalLines.push_back(line);
        } else if (height < epsilon && width > epsilon) {
            // Horizontal line
            LineSegment line;
            line.x1 = left; line.x2 = right;
            line.y1 = y_top; line.y2 = y_top; // same y
            line.width = stroke_width;
            horizontalLines.push_back(line);
        } else if (width > epsilon && height > epsilon) {
            // Rectangle - add all four edges as lines
            // Top edge
            LineSegment topLine;
            topLine.x1 = left; topLine.x2 = right;
            topLine.y1 = y_top; topLine.y2 = y_top;
            topLine.width = stroke_width;
            horizontalLines.push_back(topLine);
            // Bottom edge
            LineSegment bottomLine;
            bottomLine.x1 = left; bottomLine.x2 = right;
            bottomLine.y1 = y_bottom; bottomLine.y2 = y_bottom;
            bottomLine.width = stroke_width;
            horizontalLines.push_back(bottomLine);
            // Left edge
            LineSegment leftLine;
            leftLine.x1 = left; leftLine.x2 = left;
            leftLine.y1 = y_top; leftLine.y2 = y_bottom;
            leftLine.width = stroke_width;
            verticalLines.push_back(leftLine);
            // Right edge
            LineSegment rightLine;
            rightLine.x1 = right; rightLine.x2 = right;
            rightLine.y1 = y_top; rightLine.y2 = y_bottom;
            rightLine.width = stroke_width;
            verticalLines.push_back(rightLine);
        }
    }
#endif
}

// Helper functions for line clustering and grid detection

/**
 * Cluster similar coordinate values within a tolerance.
 * 
 * Used to align line positions that are slightly offset due to floating-point
 * inaccuracies or minor misalignments in PDF rendering. Implements single-pass
 * clustering with mean updating.
 * 
 * @param values Input values (unsorted)
 * @param tolerance Maximum distance between values to be considered same cluster
 * @return Vector of cluster centers (sorted ascending)
 */
static std::vector<double> clusterValues(const std::vector<double>& values, double tolerance) {
    std::vector<double> sorted = values;
    std::sort(sorted.begin(), sorted.end());
    std::vector<double> clusters;
    for (double val : sorted) {
        bool found = false;
        for (double& cluster : clusters) {
            if (std::fabs(val - cluster) <= tolerance) {
                cluster = (cluster + val) / 2.0; // update cluster mean
                found = true;
                break;
            }
        }
        if (!found) {
            clusters.push_back(val);
        }
    }
    return clusters;
}

/**
 * Build grid from detected horizontal and vertical lines.
 * 
 * This function clusters line positions to identify distinct row and column boundaries.
 * It extracts unique y positions from horizontal lines and unique x positions from vertical lines,
 * then clusters them within a tolerance to account for floating-point inaccuracies and minor
 * misalignments. The resulting rowBounds and columnBounds represent the grid lines.
 * 
 * @param horizontalLines Detected horizontal line segments
 * @param verticalLines Detected vertical line segments
 * @param rowBounds Output vector of y positions for row boundaries (sorted ascending)
 * @param columnBounds Output vector of x positions for column boundaries (sorted ascending)
 * @param tolerance Clustering tolerance in points (default 2.0)
 * @return true if at least 2 rows and 2 columns identified, false otherwise
 */
static bool detectGridFromLines(const std::vector<LineSegment>& horizontalLines,
                                const std::vector<LineSegment>& verticalLines,
                                std::vector<double>& rowBounds,
                                std::vector<double>& columnBounds,
                                double tolerance = 2.0) {
    // Extract unique y positions from horizontal lines (both y1 and y2 are same)
    std::vector<double> yPositions;
    for (const auto& line : horizontalLines) {
        yPositions.push_back(line.y1);
    }
    // Extract unique x positions from vertical lines
    std::vector<double> xPositions;
    for (const auto& line : verticalLines) {
        xPositions.push_back(line.x1);
    }
    
    if (yPositions.size() < 2 || xPositions.size() < 2) {
        return false; // insufficient lines for a grid
    }
    
    // Cluster positions
    rowBounds = clusterValues(yPositions, tolerance);
    columnBounds = clusterValues(xPositions, tolerance);
    
    // Sort ascending
    std::sort(rowBounds.begin(), rowBounds.end());
    std::sort(columnBounds.begin(), columnBounds.end());
    
    // Ensure at least 2 rows and 2 columns
    return rowBounds.size() >= 2 && columnBounds.size() >= 2;
}

/**
 * Map text segments to grid cells.
 * 
 * For each text segment, compute its center point and determine which grid cell
 * (defined by rowBounds and columnBounds) contains it. Marks the corresponding
 * cell as occupied. This helps identify which cells contain content and is used
 * for coverage analysis and merged cell detection.
 * 
 * @param segments Vector of text segments extracted from the page
 * @param rowBounds Row boundary y positions (sorted ascending)
 * @param columnBounds Column boundary x positions (sorted ascending)
 * @param occupied Output 2D boolean matrix where true indicates cell contains text
 */
static void mapSegmentsToGrid(const std::vector<anigma_text_segment_t>& segments,
                              const std::vector<double>& rowBounds,
                              const std::vector<double>& columnBounds,
                              std::vector<std::vector<bool>>& occupied) {
    if (rowBounds.size() < 2 || columnBounds.size() < 2) return;
    
    occupied.assign(rowBounds.size() - 1, std::vector<bool>(columnBounds.size() - 1, false));
    
    for (const auto& seg : segments) {
        // Find which cell contains the segment center
        double centerX = (seg.bbox.left + seg.bbox.right) / 2.0;
        double centerY = (seg.bbox.top + seg.bbox.bottom) / 2.0;
        
        int row = -1, col = -1;
        for (size_t i = 0; i < rowBounds.size() - 1; ++i) {
            if (centerY >= rowBounds[i] && centerY <= rowBounds[i + 1]) {
                row = static_cast<int>(i);
                break;
            }
        }
        for (size_t j = 0; j < columnBounds.size() - 1; ++j) {
            if (centerX >= columnBounds[j] && centerX <= columnBounds[j + 1]) {
                col = static_cast<int>(j);
                break;
            }
        }
        
        if (row >= 0 && col >= 0) {
            occupied[row][col] = true;
        }
    }
}

/**
 * Detect merged cells by analyzing missing internal borders.
 * 
 * For each grid cell, check if there are horizontal lines at its top and bottom edges,
 * and vertical lines at its left and right edges. If any of these edges lack a line,
 * the cell may be merged with adjacent cells. This simple heuristic identifies cells
 * that span multiple rows or columns in tables with visible borders.
 * 
 * @param occupied Occupancy matrix from mapSegmentsToGrid
 * @param rowBounds Row boundary y positions
 * @param columnBounds Column boundary x positions
 * @param horizontalLines Detected horizontal line segments
 * @param verticalLines Detected vertical line segments
 * @param merged Output 2D boolean matrix where true indicates cell is merged
 */
static void detectMergedCells(const std::vector<std::vector<bool>>& occupied,
                              const std::vector<double>& rowBounds,
                              const std::vector<double>& columnBounds,
                              const std::vector<LineSegment>& horizontalLines,
                              const std::vector<LineSegment>& verticalLines,
                              std::vector<std::vector<bool>>& merged) {
    size_t rows = rowBounds.size() - 1;
    size_t cols = columnBounds.size() - 1;
    merged.assign(rows, std::vector<bool>(cols, false));
    
    // For each cell, check if internal borders exist
    const double lineTolerance = 2.0; // points
    
    for (size_t r = 0; r < rows; ++r) {
        double top = rowBounds[r];
        double bottom = rowBounds[r + 1];
        for (size_t c = 0; c < cols; ++c) {
            double left = columnBounds[c];
            double right = columnBounds[c + 1];
            
            // Check for top horizontal line
            bool hasTop = false;
            for (const auto& line : horizontalLines) {
                if (std::fabs(line.y1 - top) < lineTolerance &&
                    line.x1 <= left + lineTolerance && line.x2 >= right - lineTolerance) {
                    hasTop = true;
                    break;
                }
            }
            // Check for bottom horizontal line
            bool hasBottom = false;
            for (const auto& line : horizontalLines) {
                if (std::fabs(line.y1 - bottom) < lineTolerance &&
                    line.x1 <= left + lineTolerance && line.x2 >= right - lineTolerance) {
                    hasBottom = true;
                    break;
                }
            }
            // Check for left vertical line
            bool hasLeft = false;
            for (const auto& line : verticalLines) {
                if (std::fabs(line.x1 - left) < lineTolerance &&
                    line.y1 <= top + lineTolerance && line.y2 >= bottom - lineTolerance) {
                    hasLeft = true;
                    break;
                }
            }
            // Check for right vertical line
            bool hasRight = false;
            for (const auto& line : verticalLines) {
                if (std::fabs(line.x1 - right) < lineTolerance &&
                    line.y1 <= top + lineTolerance && line.y2 >= bottom - lineTolerance) {
                    hasRight = true;
                    break;
                }
            }
            
            // If any internal border is missing, the cell might be merged with neighbor
            // For simplicity, mark as merged if at least one border missing
            merged[r][c] = !(hasTop && hasBottom && hasLeft && hasRight);
        }
    }
    
    // Post-process: if a cell is merged and its neighbor is also merged and both occupied,
    // they might be part of a larger merged cell. This is a simplified detection.
}

/**
 * Compute confidence score for a detected table.
 * 
 * Combines multiple heuristics to produce a confidence score between 0.0 and 1.0:
 * - Presence of borders (adds 0.3)
 * - Grid regularity (size of table relative to max expected size)
 * - Cell occupancy (coverage of text segments within grid cells)
 * 
 * Additional heuristics like header detection can be integrated.
 * 
 * @param hasBorders Whether the table was detected via border lines
 * @param rowCount Number of rows in the grid
 * @param colCount Number of columns in the grid
 * @param occupied Occupancy matrix indicating which cells contain text
 * @param coverageThreshold Minimum coverage for full confidence (default 0.5)
 * @return Confidence score between 0.0 and 1.0
 */
static double computeTableConfidence(bool hasBorders,
                                     size_t rowCount,
                                     size_t colCount,
                                     const std::vector<std::vector<bool>>& occupied,
                                     double coverageThreshold = 0.5) {
    double confidence = 0.0;
    
    if (hasBorders) {
        confidence += 0.3; // presence of borders increases confidence
    }
    
    // Regularity of grid (more rows/columns increase confidence up to a point)
    double sizeScore = std::min(1.0, (rowCount * colCount) / 20.0);
    confidence += sizeScore * 0.2;
    
    // Cell occupancy (coverage)
    size_t totalCells = rowCount * colCount;
    size_t occupiedCells = 0;
    for (const auto& row : occupied) {
        for (bool occ : row) {
            if (occ) occupiedCells++;
        }
    }
    double coverage = totalCells > 0 ? static_cast<double>(occupiedCells) / totalCells : 0.0;
    if (coverage >= coverageThreshold) {
        confidence += 0.3;
    } else {
        confidence += coverage * 0.3;
    }
    
    // Additional heuristics can be added (e.g., header detection)
    
    return std::min(confidence, 1.0);
}

/**
 * Detect header rows and columns based on font weight, position, and repetition.
 * 
 * Header detection heuristics:
 * - Top row is often a header (position-based)
 * - First column may be a header (row headers)
 * - Bold font text indicates header cells (if font flags contain bold bit)
 * 
 * @param segments Text segments with font information
 * @param rowBounds Row boundary y positions
 * @param columnBounds Column boundary x positions
 * @param headerRows Output boolean vector indicating which rows are headers
 * @param headerColumns Output boolean vector indicating which columns are headers
 */
static void detectHeaders(const std::vector<anigma_text_segment_t>& segments,
                          const std::vector<double>& rowBounds,
                          const std::vector<double>& columnBounds,
                          std::vector<bool>& headerRows,
                          std::vector<bool>& headerColumns) {
    headerRows.assign(rowBounds.size() - 1, false);
    headerColumns.assign(columnBounds.size() - 1, false);
    
    if (segments.empty()) return;
    
    // Simple heuristic: top row is often a header
    if (rowBounds.size() > 1) {
        headerRows[0] = true;
    }
    
    // First column could be header (e.g., row headers)
    if (columnBounds.size() > 1) {
        headerColumns[0] = true;
    }
    
    // Further analysis: check font flags for bold text
    for (const auto& seg : segments) {
        // Determine which cell contains segment center
        double centerX = (seg.bbox.left + seg.bbox.right) / 2.0;
        double centerY = (seg.bbox.top + seg.bbox.bottom) / 2.0;
        
        int row = -1, col = -1;
        for (size_t i = 0; i < rowBounds.size() - 1; ++i) {
            if (centerY >= rowBounds[i] && centerY <= rowBounds[i + 1]) {
                row = static_cast<int>(i);
                break;
            }
        }
        for (size_t j = 0; j < columnBounds.size() - 1; ++j) {
            if (centerX >= columnBounds[j] && centerX <= columnBounds[j + 1]) {
                col = static_cast<int>(j);
                break;
            }
        }
        
        if (row >= 0 && col >= 0) {
            // Check if font is bold (font_flags may contain bold bit)
            // Assuming font_flags bit 0 is bold (check PDFium documentation)
            const uint32_t BOLD_FLAG = 1; // placeholder
            if (seg.font_flags & BOLD_FLAG) {
                headerRows[row] = true;
                headerColumns[col] = true;
            }
        }
    }
}

// Grid structure for table detection
struct GridCell {
    double left, top, right, bottom;
    bool occupied; // by text segment
    bool merged; // spans multiple rows/cols
    int row, col;
};

struct DetectedTable {
    std::vector<GridCell> cells;
    std::vector<double> columnBounds; // x positions
    std::vector<double> rowBounds; // y positions
    anigma_bounding_box_t bbox;
    double confidence;
    bool hasBorders;
};

/**
 * Enhanced table detection with border/line detection, merged cell detection, and header recognition.
 * 
 * This function implements advanced table detection by combining multiple techniques:
 * 1. Border/Line Detection: Extract horizontal and vertical lines from PDF paths
 * 2. Grid Construction: Cluster lines to form row and column boundaries
 * 3. Text Mapping: Map text segments to grid cells for occupancy analysis
 * 4. Merged Cell Detection: Identify cells missing internal borders
 * 5. Header Recognition: Detect header rows/columns based on position and font weight
 * 6. Confidence Scoring: Compute confidence based on borders, grid regularity, coverage
 * 7. Fallback: If border detection fails, use text-based table detection
 * 8. Post-processing: Merge overlapping tables
 * 
 * The algorithm maintains backward compatibility by returning bounding boxes only,
 * but internally computes detailed table structure for improved accuracy.
 * 
 * @param segments Text segments extracted from the page
 * @param page PDFium page handle for accessing page objects
 * @param page_width Page width in points
 * @param page_height Page height in points
 * @param confidence_threshold Minimum confidence score (0.0-1.0)
 * @return Vector of table bounding boxes that meet confidence threshold
 */
static std::vector<anigma_bounding_box_t> detectTables(
    const std::vector<anigma_text_segment_t>& segments,
    FPDF_PAGE page,
    double page_width,
    double page_height,
    double confidence_threshold) {
    
    std::vector<anigma_bounding_box_t> tables;
    
    // Step 1: Extract lines from page
    std::vector<LineSegment> horizontalLines, verticalLines;
    extractLinesFromPage(page, page_height, horizontalLines, verticalLines);
    
    // Step 2: Attempt border-based table detection if we have enough lines
    bool borderTablesDetected = false;
    if (horizontalLines.size() >= 2 && verticalLines.size() >= 2) {
        // Cluster lines into potential tables based on proximity
        const double clusterTolerance = 20.0; // points
        std::vector<std::vector<LineSegment>> horizontalClusters, verticalClusters;
        // Simple clustering: group lines whose bounding boxes overlap
        // For now, assume all lines belong to same table (simplification)
        // TODO: Implement proper line clustering for multiple tables
        
        // Build grid from all lines
        std::vector<double> rowBounds, columnBounds;
        if (detectGridFromLines(horizontalLines, verticalLines, rowBounds, columnBounds)) {
            // Map segments to grid
            std::vector<std::vector<bool>> occupied;
            mapSegmentsToGrid(segments, rowBounds, columnBounds, occupied);
            
            // Detect merged cells using line analysis
            std::vector<std::vector<bool>> merged;
            detectMergedCells(occupied, rowBounds, columnBounds, horizontalLines, verticalLines, merged);
            
            // Compute table bounding box from grid outer bounds
            if (rowBounds.size() >= 2 && columnBounds.size() >= 2) {
                anigma_bounding_box_t tableBbox;
                tableBbox.left = columnBounds.front();
                tableBbox.right = columnBounds.back();
                tableBbox.top = rowBounds.front();
                tableBbox.bottom = rowBounds.back();
                
                // Compute confidence
                bool hasBorders = true;
                double confidence = computeTableConfidence(hasBorders, rowBounds.size() - 1,
                                                          columnBounds.size() - 1, occupied);
                
                if (confidence >= confidence_threshold) {
                    tables.push_back(tableBbox);
                    borderTablesDetected = true;
                }
            }
        }
    }
    
    // Step 3: If border detection failed or produced no tables, fall back to text-based detection
    if (!borderTablesDetected) {
        tables = detectTablesFromSegments(segments, confidence_threshold);
    }
    
    // Step 4: Post-process tables (merge overlapping, etc.)
    // Simple merging: if two tables overlap significantly, keep the larger one
    const double overlapThreshold = 0.8; // 80% overlap
    std::vector<bool> keep(tables.size(), true);
    for (size_t i = 0; i < tables.size(); ++i) {
        if (!keep[i]) continue;
        for (size_t j = i + 1; j < tables.size(); ++j) {
            if (!keep[j]) continue;
            const auto& a = tables[i];
            const auto& b = tables[j];
            // Compute intersection area
            double left = std::max(a.left, b.left);
            double right = std::min(a.right, b.right);
            double top = std::max(a.top, b.top);
            double bottom = std::min(a.bottom, b.bottom);
            if (left < right && top < bottom) {
                double intersectionArea = (right - left) * (bottom - top);
                double areaA = (a.right - a.left) * (a.bottom - a.top);
                double areaB = (b.right - b.left) * (b.bottom - b.top);
                double overlapA = intersectionArea / areaA;
                double overlapB = intersectionArea / areaB;
                if (overlapA > overlapThreshold || overlapB > overlapThreshold) {
                    // Keep the larger table
                    if (areaA >= areaB) {
                        keep[j] = false;
                    } else {
                        keep[i] = false;
                        break; // current table removed, move on
                    }
                }
            }
        }
    }
    
    std::vector<anigma_bounding_box_t> finalTables;
    for (size_t i = 0; i < tables.size(); ++i) {
        if (keep[i]) finalTables.push_back(tables[i]);
    }
    
    return finalTables;
}

// ============================================================================
// OCR Integration Class
// ============================================================================

#if ANIGMA_ENABLE_OCR
class OCREngine {
private:
    tesseract::TessBaseAPI tess;
    std::string current_language;
    bool initialized;
    
public:
    OCREngine() : initialized(false) {}
    
    ~OCREngine() {
        if (initialized) {
            tess.End();
        }
    }
    
    bool initialize(const char* language = "eng") {
        if (initialized && current_language == language) {
            return true;
        }
        
        if (initialized) {
            tess.End();
            initialized = false;
        }
        
        // Initialize Tesseract with English by default
        int result = tess.Init(nullptr, language, tesseract::OEM_DEFAULT);
        if (result == 0) {
            // Set page segmentation mode for automatic detection
            tess.SetPageSegMode(tesseract::PSM_AUTO);
            current_language = language;
            initialized = true;
            return true;
        }
        return false;
    }
    
    std::vector<anigma_ocr_result_t> processImage(const uint8_t* image_data, 
                                                  int width, int height, 
                                                  int bytes_per_pixel,
                                                  const anigma_bounding_box_t& region_bbox) {
        std::vector<anigma_ocr_result_t> results;
        
        if (!initialized || !image_data) {
            return results;
        }
        
        // Set image for OCR
        tess.SetImage(image_data, width, height, bytes_per_pixel, width * bytes_per_pixel);
        
        // Get OCR result
        char* ocr_text = tess.GetUTF8Text();
        if (!ocr_text) {
            return results;
        }
        
        // Get confidence scores
        int* confidences = nullptr;
        tesseract::ResultIterator* ri = tess.GetIterator();
        if (ri) {
            // Process words with confidence
            do {
                const char* word = ri->GetUTF8Text(tesseract::RIL_WORD);
                if (word && strlen(word) > 0) {
                    float conf = ri->Confidence(tesseract::RIL_WORD);
                    int x1, y1, x2, y2;
                    ri->BoundingBox(tesseract::RIL_WORD, &x1, &y1, &x2, &y2);
                    
                    anigma_ocr_result_t result{};
                    result.text = strdup(word);
                    result.confidence = conf / 100.0; // Convert to 0-1 range
                    result.language = strdup(current_language.c_str());
                    result.word_count = 1;
                    
                    // Convert coordinates to our coordinate system
                    result.bbox.left = static_cast<double>(x1);
                    result.bbox.top = static_cast<double>(y1);
                    result.bbox.right = static_cast<double>(x2);
                    result.bbox.bottom = static_cast<double>(y2);
                    
                    results.push_back(result);
                    delete[] word;
                }
            } while (ri->Next(tesseract::RIL_WORD));
            delete ri;
        }
        
        delete[] ocr_text;
        return results;
    }
};
#endif // ANIGMA_ENABLE_OCR

// ============================================================================
// Font Analysis Class
// ============================================================================

class FontAnalyzer {
private:
    std::unordered_map<std::string, std::string> font_families;
    std::unordered_map<std::string, double> font_metrics;
    
public:
    FontAnalyzer() {
        // Initialize common font family mappings
        font_families["Times-Roman"] = "Times New Roman";
        font_families["Times-Bold"] = "Times New Roman";
        font_families["Times-Italic"] = "Times New Roman";
        font_families["Helvetica"] = "Arial";
        font_families["Helvetica-Bold"] = "Arial";
        font_families["Helvetica-Oblique"] = "Arial";
        font_families["Courier"] = "Courier New";
        font_families["Courier-Bold"] = "Courier New";
        font_families["Courier-Oblique"] = "Courier New";
    }
    
    anigma_font_analysis_t analyzeFont(const char* font_name, double font_size, 
                                      uint32_t font_flags, uint32_t color_rgb) {
        anigma_font_analysis_t analysis{};
        
        // Extract family and subfamily
        std::string name = font_name ? font_name : "Unknown";
        std::string family = name;
        std::string subfamily = "";
        
        // Check for style indicators in font name
        bool is_bold = (font_flags & 0x0001) != 0 || name.find("Bold") != std::string::npos;
        bool is_italic = (font_flags & 0x0002) != 0 || name.find("Italic") != std::string::npos || 
                         name.find("Oblique") != std::string::npos;
        
        // Map to standard families
        auto it = font_families.find(name);
        if (it != font_families.end()) {
            family = it->second;
        }
        
        // Determine serif/monospace
        bool is_serif = family.find("Times") != std::string::npos || 
                       family.find("Georgia") != std::string::npos ||
                       family.find("serif") != std::string::npos;
        bool is_monospace = family.find("Courier") != std::string::npos ||
                           family.find("Mono") != std::string::npos ||
                           family.find("Consolas") != std::string::npos;
        
        // Fill analysis structure
        analysis.family = strdup(family.c_str());
        analysis.subfamily = strdup(subfamily.c_str());
        analysis.size = font_size;
        analysis.weight = is_bold ? 700 : 400;
        analysis.italic = is_italic ? 1 : 0;
        analysis.bold = is_bold ? 1 : 0;
        analysis.monospace = is_monospace ? 1 : 0;
        analysis.serif = is_serif ? 1 : 0;
        analysis.style_flags = font_flags;
        analysis.x_height = font_size * 0.6; // Approximation
        analysis.cap_height = font_size * 0.7; // Approximation
        analysis.color_rgb = color_rgb;
        analysis.contrast_ratio = 0.0; // Would need background color for accurate calculation
        
        return analysis;
    }
};

// ============================================================================
// Layout Classification Class
// ============================================================================

class LayoutClassifier {
private:
    FontAnalyzer font_analyzer;
    
public:
    anigma_layout_element_type_t classifyElement(const anigma_text_segment_t& segment, 
                                               const std::vector<anigma_text_segment_t>& all_segments,
                                               double page_width, double page_height) {
        
        // Simple heuristic-based classification
        double text_length = strlen(segment.text ? segment.text : "");
        double bbox_width = segment.bbox.right - segment.bbox.left;
        double bbox_height = segment.bbox.bottom - segment.bbox.top;
        double position_y = segment.bbox.top; // Distance from top
        
        // Check if text spans most of page width (likely header)
        if (bbox_width > page_width * 0.8 && segment.font_size > 14.0 && position_y < page_height * 0.2) {
            return ANIGMA_LAYOUT_ELEMENT_HEADER;
        }
        
        // Check for list items (start with bullet or number)
        const char* text = segment.text ? segment.text : "";
        if (text[0] == '•' || text[0] == '-' || text[0] == '*' || 
            (isdigit(text[0]) && (text[1] == '.' || text[1] == ')'))) {
            return ANIGMA_LAYOUT_ELEMENT_LIST_ITEM;
        }
        
        // Check for footer (bottom of page, small font)
        if (position_y > page_height * 0.9 && segment.font_size < 10.0) {
            return ANIGMA_LAYOUT_ELEMENT_FOOTER;
        }
        
        // Check for code block (monospace font)
        if (segment.font_name && 
            (strstr(segment.font_name, "Courier") || strstr(segment.font_name, "Mono"))) {
            return ANIGMA_LAYOUT_ELEMENT_CODE_BLOCK;
        }
        
        // Default to paragraph
        return ANIGMA_LAYOUT_ELEMENT_PARAGRAPH;
    }
    
    double calculateClassificationConfidence(const anigma_text_segment_t& segment,
                                           anigma_layout_element_type_t type) {
        // Simple confidence calculation based on various heuristics
        double confidence = 0.5; // Base confidence
        
        switch (type) {
            case ANIGMA_LAYOUT_ELEMENT_HEADER:
                if (segment.font_size > 14.0) confidence += 0.2;
                if (segment.font_flags & 0x0001) confidence += 0.1; // Bold
                if (strlen(segment.text ? segment.text : "") < 100) confidence += 0.1;
                break;
                
            case ANIGMA_LAYOUT_ELEMENT_LIST_ITEM:
                {
                    const char* text = segment.text ? segment.text : "";
                    if (text[0] == '•' || text[0] == '-' || text[0] == '*') confidence += 0.3;
                    if (isdigit(text[0]) && (text[1] == '.' || text[1] == ')')) confidence += 0.3;
                }
                break;
                
            case ANIGMA_LAYOUT_ELEMENT_CODE_BLOCK:
                if (segment.font_name && 
                    (strstr(segment.font_name, "Courier") || strstr(segment.font_name, "Mono"))) {
                    confidence += 0.4;
                }
                break;
                
            default:
                confidence = 0.7; // Higher confidence for default paragraph
                break;
        }
        
        return std::min(confidence, 1.0);
    }
};

// ============================================================================
// Reading Order Detection Class
// ============================================================================

class ReadingOrderDetector {
public:
    std::vector<uint32_t> detectReadingOrder(const std::vector<anigma_layout_element_t>& elements,
                                            std::vector<double>& confidence_scores) {
        std::vector<uint32_t> order;
        confidence_scores.clear();
        
        if (elements.empty()) {
            return order;
        }
        
        // Create indices sorted by position
        std::vector<size_t> indices(elements.size());
        std::iota(indices.begin(), indices.end(), 0);
        
        // Sort primarily by Y coordinate (top to bottom), then by X coordinate (left to right)
        std::sort(indices.begin(), indices.end(), [&elements](size_t a, size_t b) {
            const auto& elem_a = elements[a];
            const auto& elem_b = elements[b];
            
            // Check if elements are in different columns
            double col_threshold = 50.0; // Points
            bool different_columns = std::abs(elem_a.bbox.left - elem_b.bbox.left) > col_threshold;
            
            if (different_columns) {
                // Same row ordering: prioritize left to right
                double row_threshold = 10.0; // Points
                bool same_row = std::abs(elem_a.bbox.top - elem_b.bbox.top) < row_threshold;
                
                if (same_row) {
                    return elem_a.bbox.left < elem_b.bbox.left;
                }
            }
            
            // Default: top to bottom
            return elem_a.bbox.top < elem_b.bbox.top;
        });
        
        // Convert to order array and calculate confidence
        for (size_t idx : indices) {
            order.push_back(static_cast<uint32_t>(elements[idx].element_id));
            
            // Calculate confidence based on position consistency
            double confidence = 0.8; // Base confidence
            
            // Higher confidence for clearly separated elements
            if (idx > 0) {
                const auto& prev = elements[indices[idx - 1]];
                const auto& curr = elements[idx];
                double vertical_gap = curr.bbox.top - prev.bbox.bottom;
                
                if (vertical_gap > 5.0 && vertical_gap < 50.0) {
                    confidence += 0.1; // Good spacing
                } else if (vertical_gap < 0) {
                    confidence -= 0.2; // Overlap (suspicious)
                }
            }
            
            confidence_scores.push_back(std::min(confidence, 1.0));
        }
        
        return order;
    }
};

// ============================================================================
// Document Structure Analyzer Class
// ============================================================================

class DocumentStructureAnalyzer {
private:
    std::vector<std::string> section_titles;
    std::vector<uint32_t> section_start_pages;
    
public:
    void analyzeDocumentStructure(const std::vector<anigma_page_layout_t>& pages,
                                anigma_document_structure_t& structure) {
        structure.total_pages = static_cast<uint32_t>(pages.size());
        structure.section_count = 0;
        structure.section_titles = nullptr;
        structure.section_start_pages = nullptr;
        structure.element_counts = nullptr;
        structure.has_toc = 0;
        structure.has_index = 0;
        structure.has_bibliography = 0;
        
        section_titles.clear();
        section_start_pages.clear();
        
        // Simple section detection based on headers
        for (size_t page_idx = 0; page_idx < pages.size(); ++page_idx) {
            const auto& page = pages[page_idx];
            
            for (size_t elem_idx = 0; elem_idx < page.element_count; ++elem_idx) {
                const auto& element = page.elements[elem_idx];
                
                if (element.type == ANIGMA_LAYOUT_ELEMENT_HEADER && 
                    element.confidence > 0.7) {
                    // Consider as section header
                    std::string title = element.text ? element.text : "";
                    if (!title.empty() && title.length() < 100) { // Reasonable title length
                        section_titles.push_back(title);
                        section_start_pages.push_back(static_cast<uint32_t>(page_idx));
                    }
                }
            }
        }
        
        // Populate structure
        if (!section_titles.empty()) {
            structure.section_count = static_cast<uint32_t>(section_titles.size());
            structure.section_titles = new const char*[structure.section_count];
            structure.section_start_pages = new uint32_t[structure.section_count];
            structure.element_counts = new uint32_t[structure.section_count];
            
            for (size_t i = 0; i < section_titles.size(); ++i) {
                structure.section_titles[i] = strdup(section_titles[i].c_str());
                structure.section_start_pages[i] = section_start_pages[i];
                structure.element_counts[i] = 0; // Would need more detailed analysis
            }
            
            // Check for TOC (many section titles in early pages)
            if (section_start_pages.size() > 3 && 
                std::all_of(section_start_pages.begin(), section_start_pages.begin() + 3,
                           [](uint32_t page) { return page < 3; })) {
                structure.has_toc = 1;
            }
        }
    }
};

// ============================================================================
// Layout engine capsule internal state
struct LayoutEngineState {
    struct anigma_layout_engine_config_t config;
    // PDFium document handle (owned by this state)
    FPDF_DOCUMENT pdf_doc;
    // Store per-page layout results
    std::vector<struct anigma_page_layout_t> page_layouts;
    std::unordered_map<uint32_t, SpatialIndex> spatial_indices;
    // Font name interning cache (shared across pages of same document)
    std::unordered_map<std::string, char*> font_name_cache;
    // Text content interning cache (shared across pages of same document)
    std::unordered_map<std::string, char*> text_pool;
    
    // Advanced analysis engines
#if ANIGMA_ENABLE_OCR
    OCREngine ocr_engine;
#endif
    FontAnalyzer font_analyzer;
    LayoutClassifier layout_classifier;
    ReadingOrderDetector reading_order_detector;
    DocumentStructureAnalyzer structure_analyzer;
    
    // Advanced analysis results
    std::unordered_map<uint32_t, std::vector<anigma_ocr_result_t>> ocr_results_map;
    std::unordered_map<uint32_t, std::vector<anigma_layout_element_t>> layout_elements_map;
    std::unordered_map<uint32_t, anigma_reading_order_t> reading_order_map;
    
    // Profiling counters (only updated when ANIGMA_LAYOUT_ENGINE_FLAG_ENABLE_PROFILING is set)
    size_t total_chars_processed;
    size_t total_segments_created;
    size_t total_pages_processed;
    double pdf_load_time_ms;
    double text_extraction_time_ms;
    double spatial_index_build_time_ms;
    double ocr_time_ms;
    double font_analysis_time_ms;
    double layout_classification_time_ms;
    double reading_order_time_ms;
    
    LayoutEngineState(const struct anigma_layout_engine_config_t* config)
        : config(*config)
        , pdf_doc(nullptr)
        , total_chars_processed(0)
        , total_segments_created(0)
        , total_pages_processed(0)
        , pdf_load_time_ms(0.0)
        , text_extraction_time_ms(0.0)
        , spatial_index_build_time_ms(0.0)
        , ocr_time_ms(0.0)
        , font_analysis_time_ms(0.0)
        , layout_classification_time_ms(0.0)
        , reading_order_time_ms(0.0)
    {}
    
    ~LayoutEngineState() {
        freeLayoutData();
#if ANIGMA_ENABLE_PDFIUM
        if (pdf_doc) {
            FPDF_CloseDocument(pdf_doc);
            pdf_doc = nullptr;
        }
#endif
    }
    
    // Analyze PDF data and populate page_layouts
    bool analyzePDF(const uint8_t* pdf_data, size_t pdf_data_len, anigma_capsule_error_t* err) {
        // Reset state, optionally preserving caches
        bool preserveCaches = config.flags & ANIGMA_LAYOUT_ENGINE_FLAG_PRESERVE_CACHES;
        reset(preserveCaches);
        
        bool profiling = config.flags & ANIGMA_LAYOUT_ENGINE_FLAG_ENABLE_PROFILING;
        
        // Initialize PDFium library
        initPDFium();
        
        // Load PDF from memory
        std::chrono::high_resolution_clock::time_point pdf_load_start, pdf_load_end;
        if (profiling) pdf_load_start = std::chrono::high_resolution_clock::now();
        pdf_doc = FPDF_LoadMemDocument(pdf_data, static_cast<int>(pdf_data_len), nullptr);
        if (profiling) {
            pdf_load_end = std::chrono::high_resolution_clock::now();
            pdf_load_time_ms += std::chrono::duration<double, std::milli>(pdf_load_end - pdf_load_start).count();
        }
        if (!pdf_doc) {
            if (err) {
                err->code = ANIGMA_ERR_INVALID_ARG;
                err->message = "Failed to load PDF document";
            }
            return false;
        }
        
        int page_count = FPDF_GetPageCount(pdf_doc);
        if (page_count <= 0) {
            if (err) {
                err->code = ANIGMA_ERR_INVALID_ARG;
                err->message = "PDF has no pages";
            }
            return false;
        }
        
        // For each page, extract text segments and layout
        for (int page_idx = 0; page_idx < page_count; ++page_idx) {
            total_pages_processed++;
            FPDF_PAGE page = FPDF_LoadPage(pdf_doc, page_idx);
            if (!page) continue;
            
            // Get page dimensions
            double page_width = FPDF_GetPageWidth(page);
            double page_height = FPDF_GetPageHeight(page);
            
            // Extract text
            std::chrono::high_resolution_clock::time_point text_extract_start;
            if (profiling) text_extract_start = std::chrono::high_resolution_clock::now();
            FPDF_TEXTPAGE text_page = FPDFText_LoadPage(page);
            if (!text_page) {
                FPDF_ClosePage(page);
                continue;
            }
            
            // Count characters
            int char_count = FPDFText_CountChars(text_page);
            total_chars_processed += char_count;
            std::vector<anigma_text_segment_t> segments;
            
            // Extract character information
            struct CharInfo {
                double left, top, right, bottom;
                unsigned short code;
                double fontSize;
                char* fontName;
                int fontFlags;
                uint32_t colorRGB;
            };
            std::vector<CharInfo> chars;
            chars.reserve(char_count);
            
            // Font name interning cache to reduce allocations (uses member font_name_cache)
            
            for (int i = 0; i < char_count; ++i) {
                // Get character bounding box
                double left, right, bottom, top;
                FPDFText_GetCharBox(text_page, i, &left, &right, &bottom, &top);
                // Convert PDF coordinates (bottom-left origin) to top-left origin
                double y_top = page_height - top;
                double y_bottom = page_height - bottom;
                
                // Get character code
                unsigned short char_buffer[2];
                int len = FPDFText_GetText(text_page, i, 1, char_buffer);
                unsigned short code = (len > 0) ? char_buffer[0] : ' ';
                
                // Get font size
                double fontSize = FPDFText_GetFontSize(text_page, i);
                
                // Get font name and flags
                int fontFlags = 0;
                char fontNameBuffer[256];
                unsigned long nameLen = FPDFText_GetFontInfo(text_page, i, fontNameBuffer, sizeof(fontNameBuffer), &fontFlags);
                char* fontName = nullptr;
                if (nameLen > 0 && nameLen <= sizeof(fontNameBuffer)) {
                    std::string key(fontNameBuffer, nameLen);
                    auto it = font_name_cache.find(key);
                    if (it != font_name_cache.end()) {
                        // Use existing string
                        fontName = it->second;
                    } else {
                        // Insert new string (allocate with malloc to match existing free calls)
                        char* allocated = strdup(key.c_str());
                        font_name_cache.emplace(key, allocated);
                        fontName = allocated;
                    }
                }
                
                // Get color (placeholder - PDFium doesn't provide direct color API)
                uint32_t colorRGB = 0x000000;
                
                chars.push_back({left, y_top, right, y_bottom, code, fontSize, fontName, fontFlags, colorRGB});
            }
            
            // Cluster characters into text segments
            if (!chars.empty()) {
                // Simple greedy clustering
                size_t start = 0;
                for (size_t i = 1; i <= chars.size(); ++i) {
                    bool newCluster = false;
                    if (i == chars.size()) {
                        newCluster = true; // final cluster
                    } else {
                        const auto& prev = chars[i-1];
                        const auto& curr = chars[i];
                        // Check font similarity (name, flags, size)
                        bool sameFontName = (prev.fontName && curr.fontName && strcmp(prev.fontName, curr.fontName) == 0) ||
                                            (!prev.fontName && !curr.fontName);
                        bool sameFontFlags = prev.fontFlags == curr.fontFlags;
                        bool sameFont = sameFontName && sameFontFlags;
                        bool similarSize = fabs(prev.fontSize - curr.fontSize) < 0.5;
                        // Check horizontal proximity (simple)
                        double horizDist = curr.left - prev.right;
                        double vertDist = fabs(curr.top - prev.top);
                        bool close = horizDist <= config.merge_text_threshold && vertDist <= config.merge_text_threshold;
                        
                        newCluster = !sameFont || !similarSize || !close;
                    }
                    
                    if (newCluster) {
                        // Create segment from chars[start..i-1]
                        size_t count = i - start;
                        if (count > 0) {
                            // Build UTF-8 text
                            std::string text;
                            text.reserve(count * 4); // UTF-8 max 4 bytes per code point
                            for (size_t j = start; j < i; ++j) {
                                unsigned short code = chars[j].code;
                                
                                // Check for high surrogate
                                if (isHighSurrogate(code) && j + 1 < i) {
                                    unsigned short next = chars[j + 1].code;
                                    if (isLowSurrogate(next)) {
                                        // Combine surrogate pair
                                        uint32_t cp = combineSurrogates(code, next);
                                        appendUTF8FromCodePoint(text, cp);
                                        ++j; // Skip low surrogate
                                        continue;
                                    }
                                }
                                
                                // Check for low surrogate without preceding high surrogate (invalid)
                                if (isLowSurrogate(code)) {
                                    // Invalid surrogate, replace with replacement character
                                    appendUTF8FromCodePoint(text, 0xFFFD);
                                    continue;
                                }
                                
                                // Regular BMP character (including high surrogate without following low)
                                appendUTF8FromCodePoint(text, static_cast<uint32_t>(code));
                            }
                            
                            // Compute bounding box union
                            double left = chars[start].left;
                            double top = chars[start].top;
                            double right = chars[start].right;
                            double bottom = chars[start].bottom;
                            for (size_t j = start + 1; j < i; ++j) {
                                left = std::min(left, chars[j].left);
                                top = std::min(top, chars[j].top);
                                right = std::max(right, chars[j].right);
                                bottom = std::max(bottom, chars[j].bottom);
                            }
                            
                            anigma_text_segment_t segment{};
                            segment.bbox.left = left;
                            segment.bbox.top = top;
                            segment.bbox.right = right;
                            segment.bbox.bottom = bottom;
                            segment.text = internText(text);
                            segment.font_name = chars[start].fontName ? strdup(chars[start].fontName) : nullptr;
                            segment.font_size = chars[start].fontSize;
                            segment.font_flags = chars[start].fontFlags;
                            segment.color_rgb = chars[start].colorRGB;
                            segments.push_back(segment);
                        }
                        start = i;
                    }
                }
            }
            
            // Free temporary CharInfo font names
            // Font names are now owned by font_name_cache, no need to free individually
            for (auto& ch : chars) {
                // fontName owned by cache, do not free
                // free(ch.fontName);
                ch.fontName = nullptr;
            }
            

            
            total_segments_created += segments.size();
            
            if (profiling) {
                auto text_extract_end = std::chrono::high_resolution_clock::now();
                text_extraction_time_ms += std::chrono::duration<double, std::milli>(text_extract_end - text_extract_start).count();
            }
            
            // Build spatial index for this page
            std::chrono::high_resolution_clock::time_point spatial_index_start;
            if (profiling) spatial_index_start = std::chrono::high_resolution_clock::now();
            auto& spatial_index = spatial_indices[page_idx];
            spatial_index.init(page_width, page_height);
            for (size_t seg_idx = 0; seg_idx < segments.size(); ++seg_idx) {
                spatial_index.addBox(segments[seg_idx].bbox, static_cast<uint32_t>(seg_idx));
            }
            if (profiling) {
                auto spatial_index_end = std::chrono::high_resolution_clock::now();
                spatial_index_build_time_ms += std::chrono::duration<double, std::milli>(spatial_index_end - spatial_index_start).count();
            }
            
            // Detect tables, figures, and images
            auto tables = detectTables(segments, page, page_width, page_height, config.table_detection_confidence);
            auto figures = detectFigures(page, page_width, page_height);
            auto images = extractImages(page, page_width, page_height);
            
            // Create page layout
            anigma_page_layout_t page_layout{};
            page_layout.page_index = static_cast<uint32_t>(page_idx);
            page_layout.segment_count = segments.size();
            if (!segments.empty()) {
                page_layout.segments = new anigma_text_segment_t[segments.size()];
                std::copy(segments.begin(), segments.end(), page_layout.segments);
            } else {
                page_layout.segments = nullptr;
            }
            page_layout.table_count = tables.size();
            if (!tables.empty()) {
                page_layout.table_bboxes = new anigma_bounding_box_t[tables.size()];
                std::copy(tables.begin(), tables.end(), page_layout.table_bboxes);
            } else {
                page_layout.table_bboxes = nullptr;
            }
            page_layout.figure_count = figures.size();
            if (!figures.empty()) {
                page_layout.figure_bboxes = new anigma_bounding_box_t[figures.size()];
                std::copy(figures.begin(), figures.end(), page_layout.figure_bboxes);
            } else {
                page_layout.figure_bboxes = nullptr;
            }
            page_layout.image_count = images.size();
            if (!images.empty()) {
                page_layout.images = new anigma_image_data_t[images.size()];
                for (size_t i = 0; i < images.size(); ++i) {
                    const auto& src = images[i];
                    auto& dst = page_layout.images[i];
                    // Copy bounding box
                    dst.bbox = src.bbox;
                    // Copy metadata
                    dst.width = src.width;
                    dst.height = src.height;
                    dst.horizontal_dpi = src.horizontal_dpi;
                    dst.vertical_dpi = src.vertical_dpi;
                    dst.bits_per_pixel = src.bits_per_pixel;
                    dst.colorspace = src.colorspace;
                    // Copy raw data
                    if (src.raw_data && src.raw_data_len > 0) {
                        dst.raw_data = static_cast<uint8_t*>( (void*)malloc(src.raw_data_len));
                        if (dst.raw_data) {
                            std::memcpy(dst.raw_data, src.raw_data, src.raw_data_len);
                            dst.raw_data_len = src.raw_data_len;
                        } else {
                            dst.raw_data_len = 0;
                        }
                    } else {
                        dst.raw_data = nullptr;
                        dst.raw_data_len = 0;
                    }
                    // Copy filter string
                    if (src.filter) {
                        dst.filter = strdup(src.filter);
                    } else {
                        dst.filter = nullptr;
                    }
                }
                // Clean up source image data
                for (auto& img : images) {
                    free(img.raw_data);
                    free(const_cast<char*>(img.filter));
                }
            } else {
                page_layout.images = nullptr;
            }
            
            page_layouts.push_back(page_layout);
            
            // Cleanup
            FPDFText_ClosePage(text_page);
            FPDF_ClosePage(page);
        }
        
        return true;
    }
    
    // Intern text string to reduce duplication
    char* internText(const std::string& text) {
        auto it = text_pool.find(text);
        if (it != text_pool.end()) {
            return it->second;
        }
        char* allocated = strdup(text.c_str());
        text_pool.emplace(text, allocated);
        return allocated;
    }

    // Clear font name cache and free allocated strings
    void clearFontNameCache() {
        for (auto& kv : font_name_cache) {
            free(kv.second);
        }
        font_name_cache.clear();
        for (auto& kv : text_pool) {
            free(kv.second);
        }
        text_pool.clear();
    }
    
    // Free allocated layout data
    void freeLayoutData() {
        clearFontNameCache();
        freePageLayouts();
    }

    // Free page layouts but preserve font name cache
    void freePageLayouts() {
        for (auto& layout : page_layouts) {
            if (layout.segments) {
                for (size_t i = 0; i < layout.segment_count; ++i) {
                    free(const_cast<char*>(layout.segments[i].text));
                    free(const_cast<char*>(layout.segments[i].font_name));
                }
                delete[] layout.segments;
                layout.segments = nullptr;
            }
            if (layout.table_bboxes) {
                delete[] layout.table_bboxes;
                layout.table_bboxes = nullptr;
            }
            if (layout.figure_bboxes) {
                delete[] layout.figure_bboxes;
                layout.figure_bboxes = nullptr;
            }
            if (layout.images) {
                for (size_t i = 0; i < layout.image_count; ++i) {
                    free(layout.images[i].raw_data);
                    free(const_cast<char*>(layout.images[i].filter));
                }
                delete[] layout.images;
                layout.images = nullptr;
            }
            
            // Free OCR results
            if (layout.ocr_results) {
                for (size_t i = 0; i < layout.ocr_result_count; ++i) {
                    free(const_cast<char*>(layout.ocr_results[i].text));
                    free(const_cast<char*>(layout.ocr_results[i].language));
                }
                delete[] layout.ocr_results;
                layout.ocr_results = nullptr;
            }
            
            // Free layout elements
            if (layout.elements) {
                for (size_t i = 0; i < layout.element_count; ++i) {
                    free(const_cast<char*>(layout.elements[i].text));
                    free(const_cast<char*>(layout.elements[i].font.family));
                    free(const_cast<char*>(layout.elements[i].font.subfamily));
                }
                delete[] layout.elements;
                layout.elements = nullptr;
            }
            
            // Free reading order
            if (layout.reading_order.element_ids) {
                delete[] layout.reading_order.element_ids;
                layout.reading_order.element_ids = nullptr;
            }
            if (layout.reading_order.confidence_scores) {
                delete[] layout.reading_order.confidence_scores;
                layout.reading_order.confidence_scores = nullptr;
            }
            if (layout.reading_order.column_breaks) {
                delete[] layout.reading_order.column_breaks;
                layout.reading_order.column_breaks = nullptr;
            }
        }
        page_layouts.clear();
    }
    
    // Free advanced analysis data
    void freeAdvancedAnalysisData() {
        // Free OCR results map
        for (auto& pair : ocr_results_map) {
            for (auto& ocr_result : pair.second) {
                free(const_cast<char*>(ocr_result.text));
                free(const_cast<char*>(ocr_result.language));
            }
        }
        ocr_results_map.clear();
        
        // Free layout elements map
        for (auto& pair : layout_elements_map) {
            for (auto& element : pair.second) {
                free(const_cast<char*>(element.text));
                free(const_cast<char*>(element.font.family));
                free(const_cast<char*>(element.font.subfamily));
            }
        }
        layout_elements_map.clear();
        
        // Free reading order map
        for (auto& pair : reading_order_map) {
            delete[] pair.second.element_ids;
            delete[] pair.second.confidence_scores;
            delete[] pair.second.column_breaks;
        }
        reading_order_map.clear();
    }

    // Reset state for new PDF, optionally preserving caches
    void reset(bool preserveCaches) {
        // Close PDF document if open
#if ANIGMA_ENABLE_PDFIUM
        if (pdf_doc) {
            FPDF_CloseDocument(pdf_doc);
            pdf_doc = nullptr;
        }
#endif
        freePageLayouts();
        freeAdvancedAnalysisData();
        spatial_indices.clear();
        if (!preserveCaches) {
            clearFontNameCache();
        }
    }
};

// Validate configuration
bool validateConfig(const struct anigma_layout_engine_config_t* config, anigma_capsule_error_t* err) {
    if (!config) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Configuration pointer is null";
        }
        return false;
    }
    
    if (config->determinism_tier != ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE &&
        config->determinism_tier != ANIGMA_DETERMINISM_TIER_2_CANONICAL_BOUNDARY) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid determinism tier";
        }
        return false;
    }
    
    if (config->max_elements_per_page == 0) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "max_elements_per_page must be positive";
        }
        return false;
    }
    
    return true;
}

} // anonymous namespace

// ============================================================================
// Public API Implementation
// ============================================================================

anigma_capsule_identity_t anigma_layout_engine_capsule_get_identity(void) {
    static const char* capsule_id = "layout_engine_capsule";
    static const char* build_hash = "1.0.0-dev";
    static const char* algo_version = "1.0";
    
    return anigma_capsule_identity_t{
        capsule_id,
        build_hash,
        algo_version,
        ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE
    };
}

struct anigma_layout_engine_config_t anigma_layout_engine_capsule_get_default_config(void) {
    return anigma_layout_engine_config_t{
        .determinism_tier = ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE,
        .flags = 0,
        .max_elements_per_page = 10000,
        .merge_text_threshold = 5.0,
        .table_detection_confidence = 0.8
    };
}

anigma_status_t anigma_layout_engine_capsule_validate_config(
    const struct anigma_layout_engine_config_t* config,
    anigma_capsule_error_t* err
) {
    if (!validateConfig(config, err)) {
        return ANIGMA_ERR_INVALID_ARG;
    }
    return ANIGMA_OK;
}

anigma_status_t anigma_layout_engine_capsule_create(
    const struct anigma_layout_engine_config_t* config,
    anigma_layout_engine_capsule_t* out_handle,
    anigma_capsule_error_t* err
) {
    if (!out_handle) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Output handle pointer is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (!validateConfig(config, err)) {
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        LayoutEngineState* state = new LayoutEngineState(config);
        *out_handle = static_cast<anigma_layout_engine_capsule_t>(state);
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to allocate layout engine state";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_layout_engine_capsule_destroy(
    anigma_layout_engine_capsule_t handle,
    anigma_capsule_error_t* err
) {
    (void)err;
    
    if (!handle) {
        return ANIGMA_OK;  // Destroying null handle is a no-op
    }
    
    try {
        LayoutEngineState* state = static_cast<LayoutEngineState*>(handle);
        state->freeLayoutData();
        delete state;
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to destroy layout engine state";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_layout_engine_capsule_reset(
    anigma_layout_engine_capsule_t handle,
    int preserve_caches,
    anigma_capsule_error_t* err
) {
    (void)err;
    
    if (!handle) {
        return ANIGMA_OK;  // Resetting null handle is a no-op
    }
    
    try {
        LayoutEngineState* state = static_cast<LayoutEngineState*>(handle);
        state->reset(preserve_caches != 0);
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to reset layout engine state";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_layout_engine_capsule_analyze_pdf(
    anigma_layout_engine_capsule_t handle,
    const uint8_t* pdf_data,
    size_t pdf_data_len,
    struct anigma_page_layout_t* out_layout,
    size_t max_pages,
    size_t* out_actual,
    anigma_capsule_error_t* err
) {
    if (!handle || !pdf_data || !out_actual) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    LayoutEngineState* state = static_cast<LayoutEngineState*>(handle);
    
    // Phase 1: if out_layout is NULL, return required size
    if (!out_layout) {
        if (!state->analyzePDF(pdf_data, pdf_data_len, err)) {
            return ANIGMA_ERR_INTERNAL;
        }
        *out_actual = state->page_layouts.size();
        return ANIGMA_OK;
    }
    
    // Phase 2: populate layout
    if (!state->analyzePDF(pdf_data, pdf_data_len, err)) {
        return ANIGMA_ERR_INTERNAL;
    }
    
    size_t pages_to_copy = std::min(state->page_layouts.size(), max_pages);
    for (size_t i = 0; i < pages_to_copy; ++i) {
        const anigma_page_layout_t& src = state->page_layouts[i];
        anigma_page_layout_t& dst = out_layout[i];
        
        // Copy basic fields
        dst.page_index = src.page_index;
        dst.segment_count = src.segment_count;
        dst.table_count = src.table_count;
        dst.figure_count = src.figure_count;
        dst.image_count = src.image_count;
        
        // Allocate and copy segments
        if (src.segment_count > 0 && src.segments) {
            dst.segments = new anigma_text_segment_t[src.segment_count];
            for (size_t j = 0; j < src.segment_count; ++j) {
                const anigma_text_segment_t& src_seg = src.segments[j];
                anigma_text_segment_t& dst_seg = dst.segments[j];
                
                // Copy bounding box
                dst_seg.bbox = src_seg.bbox;
                
                // Copy text string
                dst_seg.text = src_seg.text ? strdup(src_seg.text) : nullptr;
                
                // Copy font name
                dst_seg.font_name = src_seg.font_name ? strdup(src_seg.font_name) : nullptr;
                
                // Copy other fields
                dst_seg.font_size = src_seg.font_size;
                dst_seg.font_flags = src_seg.font_flags;
                dst_seg.color_rgb = src_seg.color_rgb;
            }
        } else {
            dst.segments = nullptr;
        }
        
        // Allocate and copy table bounding boxes (placeholder)
        if (src.table_count > 0 && src.table_bboxes) {
            dst.table_bboxes = new anigma_bounding_box_t[src.table_count];
            std::copy(src.table_bboxes, src.table_bboxes + src.table_count, dst.table_bboxes);
        } else {
            dst.table_bboxes = nullptr;
        }
        
        // Allocate and copy figure bounding boxes (placeholder)
        if (src.figure_count > 0 && src.figure_bboxes) {
            dst.figure_bboxes = new anigma_bounding_box_t[src.figure_count];
            std::copy(src.figure_bboxes, src.figure_bboxes + src.figure_count, dst.figure_bboxes);
        } else {
            dst.figure_bboxes = nullptr;
        }
        
        // Allocate and copy image data
        if (src.image_count > 0 && src.images) {
            dst.images = new anigma_image_data_t[src.image_count];
            for (size_t j = 0; j < src.image_count; ++j) {
                const anigma_image_data_t& src_img = src.images[j];
                anigma_image_data_t& dst_img = dst.images[j];
                // Copy bounding box
                dst_img.bbox = src_img.bbox;
                // Copy metadata
                dst_img.width = src_img.width;
                dst_img.height = src_img.height;
                dst_img.horizontal_dpi = src_img.horizontal_dpi;
                dst_img.vertical_dpi = src_img.vertical_dpi;
                dst_img.bits_per_pixel = src_img.bits_per_pixel;
                dst_img.colorspace = src_img.colorspace;
                // Copy raw data
                if (src_img.raw_data && src_img.raw_data_len > 0) {
                    dst_img.raw_data = static_cast<uint8_t*>( (void*)malloc(src_img.raw_data_len));
                    if (dst_img.raw_data) {
                        std::memcpy(dst_img.raw_data, src_img.raw_data, src_img.raw_data_len);
                        dst_img.raw_data_len = src_img.raw_data_len;
                    } else {
                        dst_img.raw_data_len = 0;
                    }
                } else {
                    dst_img.raw_data = nullptr;
                    dst_img.raw_data_len = 0;
                }
                // Copy filter string
                if (src_img.filter) {
                    dst_img.filter = strdup(src_img.filter);
                } else {
                    dst_img.filter = nullptr;
                }
            }
        } else {
            dst.images = nullptr;
        }
    }
    
    // Set output actual count
    *out_actual = pages_to_copy;
    
    return ANIGMA_OK;
}

anigma_status_t anigma_layout_engine_capsule_free_layout(
    anigma_layout_engine_capsule_t handle,
    struct anigma_page_layout_t* layout,
    anigma_capsule_error_t* err
) {
    (void)handle;
    (void)err;
    
    if (!layout) {
        return ANIGMA_OK;
    }
    
    // Free segments
    if (layout->segments) {
        for (size_t i = 0; i < layout->segment_count; ++i) {
            free(const_cast<char*>(layout->segments[i].text));
            free(const_cast<char*>(layout->segments[i].font_name));
        }
        delete[] layout->segments;
        layout->segments = nullptr;
    }
    
    // Free table bounding boxes
    if (layout->table_bboxes) {
        delete[] layout->table_bboxes;
        layout->table_bboxes = nullptr;
    }
    
    // Free figure bounding boxes
    if (layout->figure_bboxes) {
        delete[] layout->figure_bboxes;
        layout->figure_bboxes = nullptr;
    }
    
    // Free image data
    if (layout->images) {
        for (size_t i = 0; i < layout->image_count; ++i) {
            free(layout->images[i].raw_data);
            free(const_cast<char*>(layout->images[i].filter));
        }
        delete[] layout->images;
        layout->images = nullptr;
    }
    
    // Reset counts
    layout->segment_count = 0;
    layout->table_count = 0;
    layout->figure_count = 0;
    layout->image_count = 0;
    
    return ANIGMA_OK;
}

anigma_status_t anigma_layout_engine_capsule_get_profiling_stats(
    anigma_layout_engine_capsule_t handle,
    struct anigma_layout_engine_profiling_stats_t* out_stats,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_stats) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    LayoutEngineState* state = static_cast<LayoutEngineState*>(handle);
    out_stats->total_chars_processed = state->total_chars_processed;
    out_stats->total_segments_created = state->total_segments_created;
    out_stats->total_pages_processed = state->total_pages_processed;
    out_stats->pdf_load_time_ms = state->pdf_load_time_ms;
    out_stats->text_extraction_time_ms = state->text_extraction_time_ms;
    out_stats->spatial_index_build_time_ms = state->spatial_index_build_time_ms;
    out_stats->total_analysis_time_ms = state->pdf_load_time_ms + state->text_extraction_time_ms + state->spatial_index_build_time_ms;
    return ANIGMA_OK;
}

anigma_status_t anigma_layout_engine_capsule_get_spatial_index(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_index,
    void** out_index_handle,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_index_handle) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    LayoutEngineState* state = static_cast<LayoutEngineState*>(handle);
    auto it = state->spatial_indices.find(page_index);
    if (it == state->spatial_indices.end()) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Page not analyzed or out of range";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    *out_index_handle = static_cast<void*>(&it->second);
    return ANIGMA_OK;
}

anigma_status_t anigma_layout_engine_capsule_query_bbox(
    anigma_layout_engine_capsule_t handle,
    void* index_handle,
    const struct anigma_bounding_box_t* bbox,
    uint32_t* out_element_indices,
    size_t max_elements,
    size_t* out_actual,
    anigma_capsule_error_t* err
) {
    if (!handle || !index_handle || !bbox || !out_element_indices || !out_actual || max_elements == 0) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    LayoutEngineState* state = static_cast<LayoutEngineState*>(handle);
    SpatialIndex* index = static_cast<SpatialIndex*>(index_handle);
    // Optional: verify index belongs to state (we can skip for now)
    
    std::vector<uint32_t> results;
    index->query(*bbox, results, max_elements);
    
    *out_actual = results.size();
    for (size_t i = 0; i < results.size(); ++i) {
        out_element_indices[i] = results[i];
    }
    return ANIGMA_OK;
}

// ============================================================================
// Advanced Features API Implementation
// ============================================================================

anigma_status_t anigma_layout_engine_capsule_perform_ocr(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_index,
    const char* language,
    anigma_capsule_error_t* err
) {
#if ANIGMA_ENABLE_OCR
    if (!handle || !language) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    LayoutEngineState* state = static_cast<LayoutEngineState*>(handle);
    
    if (!(state->config.flags & ANIGMA_LAYOUT_ENGINE_FLAG_ENABLE_OCR)) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "OCR flag not enabled in configuration";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (page_index >= state->page_layouts.size()) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Page index out of range";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        auto start_time = std::chrono::high_resolution_clock::now();
        
        // Initialize OCR engine
        if (!state->ocr_engine.initialize(language)) {
            if (err) {
                err->code = ANIGMA_ERR_INTERNAL;
                err->message = "Failed to initialize OCR engine";
            }
            return ANIGMA_ERR_INTERNAL;
        }
        
        const auto& page_layout = state->page_layouts[page_index];
        std::vector<anigma_ocr_result_t> ocr_results;
        
        // Process images on this page for OCR
        for (size_t img_idx = 0; img_idx < page_layout.image_count; ++img_idx) {
            const auto& image = page_layout.images[img_idx];
            
            if (image.raw_data && image.raw_data_len > 0) {
                // Perform OCR on this image
                auto results = state->ocr_engine.processImage(
                    image.raw_data,
                    static_cast<int>(image.width),
                    static_cast<int>(image.height),
                    static_cast<int>(image.bits_per_pixel / 8),
                    image.bbox
                );
                
                ocr_results.insert(ocr_results.end(), results.begin(), results.end());
            }
        }
        
        // Store OCR results
        state->ocr_results_map[page_index] = std::move(ocr_results);
        
        auto end_time = std::chrono::high_resolution_clock::now();
        state->ocr_time_ms += std::chrono::duration<double, std::milli>(end_time - start_time).count();
        
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "OCR processing failed";
        }
        return ANIGMA_ERR_INTERNAL;
    }
#else
    if (err) {
        err->code = ANIGMA_ERR_NOT_IMPLEMENTED;
        err->message = "OCR not available in this build";
    }
    return ANIGMA_ERR_NOT_IMPLEMENTED;
#endif // ANIGMA_ENABLE_OCR
}

anigma_status_t anigma_layout_engine_capsule_get_ocr_results(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_index,
    struct anigma_ocr_result_t* out_results,
    size_t max_results,
    size_t* out_actual,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_results || !out_actual) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    LayoutEngineState* state = static_cast<LayoutEngineState*>(handle);
    
    auto it = state->ocr_results_map.find(page_index);
    if (it == state->ocr_results_map.end()) {
        *out_actual = 0;
        return ANIGMA_OK;
    }
    
    const auto& ocr_results = it->second;
    size_t to_copy = std::min(ocr_results.size(), max_results);
    
    for (size_t i = 0; i < to_copy; ++i) {
        const auto& src = ocr_results[i];
        auto& dst = out_results[i];
        
        dst.bbox = src.bbox;
        dst.text = src.text ? strdup(src.text) : nullptr;
        dst.confidence = src.confidence;
        dst.language = src.language ? strdup(src.language) : nullptr;
        dst.word_count = src.word_count;
    }
    
    *out_actual = to_copy;
    return ANIGMA_OK;
}

anigma_status_t anigma_layout_engine_capsule_analyze_fonts(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_index,
    anigma_capsule_error_t* err
) {
    if (!handle) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid handle";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    LayoutEngineState* state = static_cast<LayoutEngineState*>(handle);
    
    if (!(state->config.flags & ANIGMA_LAYOUT_ENGINE_FLAG_ADVANCED_FONT_ANALYSIS)) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Advanced font analysis flag not enabled";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (page_index >= state->page_layouts.size()) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Page index out of range";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        auto start_time = std::chrono::high_resolution_clock::now();
        
        const auto& page_layout = state->page_layouts[page_index];
        
        // Enhanced font analysis would be applied here
        // For now, we just acknowledge the call
        
        auto end_time = std::chrono::high_resolution_clock::now();
        state->font_analysis_time_ms += std::chrono::duration<double, std::milli>(end_time - start_time).count();
        
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Font analysis failed";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_layout_engine_capsule_classify_layout(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_index,
    anigma_capsule_error_t* err
) {
    if (!handle) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid handle";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    LayoutEngineState* state = static_cast<LayoutEngineState*>(handle);
    
    if (!(state->config.flags & ANIGMA_LAYOUT_ENGINE_FLAG_LAYOUT_CLASSIFICATION)) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Layout classification flag not enabled";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (page_index >= state->page_layouts.size()) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Page index out of range";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        auto start_time = std::chrono::high_resolution_clock::now();
        
        const auto& page_layout = state->page_layouts[page_index];
        std::vector<anigma_layout_element_t> elements;
        
        // Convert text segments to classified layout elements
        for (size_t seg_idx = 0; seg_idx < page_layout.segment_count; ++seg_idx) {
            const auto& segment = page_layout.segments[seg_idx];
            
            anigma_layout_element_t element{};
            element.bbox = segment.bbox;
            element.text = segment.text ? strdup(segment.text) : nullptr;
            element.element_id = static_cast<uint32_t>(seg_idx);
            element.parent_id = 0;
            element.level = 0;
            
            // Classify element type
            std::vector<anigma_text_segment_t> all_segments(
                page_layout.segments,
                page_layout.segments + page_layout.segment_count
            );
            
            element.type = state->layout_classifier.classifyElement(
                segment, all_segments, 
                page_layout.bbox.right, page_layout.bbox.bottom
            );
            
            // Calculate confidence
            element.confidence = state->layout_classifier.calculateClassificationConfidence(
                segment, element.type
            );
            
            // Analyze font
            element.font = state->font_analyzer.analyzeFont(
                segment.font_name,
                segment.font_size,
                segment.font_flags,
                segment.color_rgb
            );
            
            elements.push_back(element);
        }
        
        // Store layout elements
        state->layout_elements_map[page_index] = std::move(elements);
        
        auto end_time = std::chrono::high_resolution_clock::now();
        state->layout_classification_time_ms += std::chrono::duration<double, std::milli>(end_time - start_time).count();
        
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Layout classification failed";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_layout_engine_capsule_detect_reading_order(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_index,
    anigma_capsule_error_t* err
) {
    if (!handle) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid handle";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    LayoutEngineState* state = static_cast<LayoutEngineState*>(handle);
    
    if (!(state->config.flags & ANIGMA_LAYOUT_ENGINE_FLAG_READING_ORDER_DETECTION)) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Reading order detection flag not enabled";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (page_index >= state->page_layouts.size()) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Page index out of range";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        auto start_time = std::chrono::high_resolution_clock::now();
        
        auto it = state->layout_elements_map.find(page_index);
        if (it == state->layout_elements_map.end()) {
            if (err) {
                err->code = ANIGMA_ERR_INVALID_STATE;
                err->message = "Layout classification not performed for this page";
            }
            return ANIGMA_ERR_INVALID_STATE;
        }
        
        const auto& elements = it->second;
        anigma_reading_order_t reading_order{};
        
        // Detect reading order
        std::vector<double> confidence_scores;
        auto order = state->reading_order_detector.detectReadingOrder(elements, confidence_scores);
        
        reading_order.element_count = static_cast<uint32_t>(order.size());
        if (!order.empty()) {
            reading_order.element_ids = new uint32_t[order.size()];
            reading_order.confidence_scores = new double[confidence_scores.size()];
            
            std::copy(order.begin(), order.end(), reading_order.element_ids);
            std::copy(confidence_scores.begin(), confidence_scores.end(), reading_order.confidence_scores);
        } else {
            reading_order.element_ids = nullptr;
            reading_order.confidence_scores = nullptr;
        }
        
        reading_order.column_breaks = nullptr; // Would need more complex analysis
        
        // Store reading order
        state->reading_order_map[page_index] = reading_order;
        
        auto end_time = std::chrono::high_resolution_clock::now();
        state->reading_order_time_ms += std::chrono::duration<double, std::milli>(end_time - start_time).count();
        
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Reading order detection failed";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_layout_engine_capsule_analyze_document_structure(
    anigma_layout_engine_capsule_t handle,
    struct anigma_document_structure_t* out_structure,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_structure) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    LayoutEngineState* state = static_cast<LayoutEngineState*>(handle);
    
    if (!(state->config.flags & ANIGMA_LAYOUT_ENGINE_FLAG_MULTI_PAGE_ANALYSIS)) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Multi-page analysis flag not enabled";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        // Analyze document structure across all pages
        state->structure_analyzer.analyzeDocumentStructure(
            state->page_layouts, *out_structure
        );
        
        return ANIGMA_OK;
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Document structure analysis failed";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_layout_engine_capsule_get_layout_elements(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_index,
    struct anigma_layout_element_t* out_elements,
    size_t max_elements,
    size_t* out_actual,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_elements || !out_actual) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    LayoutEngineState* state = static_cast<LayoutEngineState*>(handle);
    
    auto it = state->layout_elements_map.find(page_index);
    if (it == state->layout_elements_map.end()) {
        *out_actual = 0;
        return ANIGMA_OK;
    }
    
    const auto& elements = it->second;
    size_t to_copy = std::min(elements.size(), max_elements);
    
    for (size_t i = 0; i < to_copy; ++i) {
        const auto& src = elements[i];
        auto& dst = out_elements[i];
        
        dst.bbox = src.bbox;
        dst.type = src.type;
        dst.text = src.text ? strdup(src.text) : nullptr;
        dst.confidence = src.confidence;
        dst.reading_order = src.reading_order;
        dst.font = src.font;
        dst.element_id = src.element_id;
        dst.parent_id = src.parent_id;
        dst.level = src.level;
    }
    
    *out_actual = to_copy;
    return ANIGMA_OK;
}

anigma_status_t anigma_layout_engine_capsule_get_reading_order(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_index,
    struct anigma_reading_order_t* out_order,
    anigma_capsule_error_t* err
) {
    if (!handle || !out_order) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    LayoutEngineState* state = static_cast<LayoutEngineState*>(handle);
    
    auto it = state->reading_order_map.find(page_index);
    if (it == state->reading_order_map.end()) {
        // Return empty reading order
        out_order->element_count = 0;
        out_order->element_ids = nullptr;
        out_order->confidence_scores = nullptr;
        out_order->column_breaks = nullptr;
        return ANIGMA_OK;
    }
    
    const auto& reading_order = it->second;
    
    out_order->element_count = reading_order.element_count;
    
    if (reading_order.element_count > 0) {
        out_order->element_ids = new uint32_t[reading_order.element_count];
        out_order->confidence_scores = new double[reading_order.element_count];
        
        std::copy(reading_order.element_ids, 
                  reading_order.element_ids + reading_order.element_count,
                  out_order->element_ids);
        std::copy(reading_order.confidence_scores,
                  reading_order.confidence_scores + reading_order.element_count,
                  out_order->confidence_scores);
    } else {
        out_order->element_ids = nullptr;
        out_order->confidence_scores = nullptr;
    }
    
    out_order->column_breaks = nullptr; // Not implemented yet
    
    return ANIGMA_OK;
}

anigma_status_t anigma_layout_engine_capsule_validate_ocr_accuracy(
    anigma_layout_engine_capsule_t handle,
    uint32_t page_index,
    const char* ground_truth_text,
    double* out_character_accuracy,
    double* out_word_accuracy,
    anigma_capsule_error_t* err
) {
    if (!handle || !ground_truth_text || !out_character_accuracy || !out_word_accuracy) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    LayoutEngineState* state = static_cast<LayoutEngineState*>(handle);
    
    auto it = state->ocr_results_map.find(page_index);
    if (it == state->ocr_results_map.end()) {
        *out_character_accuracy = 0.0;
        *out_word_accuracy = 0.0;
        return ANIGMA_OK;
    }
    
    const auto& ocr_results = it->second;
    
    // Combine OCR text
    std::string ocr_text;
    for (const auto& result : ocr_results) {
        if (result.text) {
            ocr_text += result.text;
            ocr_text += " ";
        }
    }
    
    // Calculate character accuracy
    size_t correct_chars = 0;
    size_t min_len = std::min(strlen(ground_truth_text), ocr_text.length());
    
    for (size_t i = 0; i < min_len; ++i) {
        if (ground_truth_text[i] == ocr_text[i]) {
            correct_chars++;
        }
    }
    
    *out_character_accuracy = static_cast<double>(correct_chars) / 
                             std::max(strlen(ground_truth_text), ocr_text.length());
    
    // Calculate word accuracy (simplified)
    std::istringstream ground_truth_stream(ground_truth_text);
    std::istringstream ocr_stream(ocr_text);
    
    std::set<std::string> ground_truth_words, ocr_words;
    std::string word;
    
    while (ground_truth_stream >> word) {
        ground_truth_words.insert(word);
    }
    
    while (ocr_stream >> word) {
        ocr_words.insert(word);
    }
    
    size_t correct_words = 0;
    for (const auto& gt_word : ground_truth_words) {
        if (ocr_words.count(gt_word)) {
            correct_words++;
        }
    }
    
    *out_word_accuracy = static_cast<double>(correct_words) / 
                         std::max(ground_truth_words.size(), ocr_words.size());
    
    return ANIGMA_OK;
}