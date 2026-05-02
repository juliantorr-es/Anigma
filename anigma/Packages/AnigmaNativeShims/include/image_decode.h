// image_decode.h
// Native image decoding interface for ImageDecodeCapsule
// Supports JPEG, PNG, WebP formats

#ifndef IMAGE_DECODE_H
#define IMAGE_DECODE_H

#include <stdint.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

// Version
const char* image_decode_version(void);

// Error codes
typedef int32_t image_decode_error_t;
#define IMAGE_DECODE_SUCCESS 0
#define IMAGE_DECODE_ERROR_NULL_POINTER 1
#define IMAGE_DECODE_ERROR_INVALID_DATA 2
#define IMAGE_DECODE_ERROR_UNSUPPORTED_FORMAT 3
#define IMAGE_DECODE_ERROR_DECODE_FAILED 4
#define IMAGE_DECODE_ERROR_MEMORY_ALLOCATION 5
#define IMAGE_DECODE_ERROR_INVALID_DIMENSIONS 6

// Pixel formats
typedef uint32_t image_format_t;
#define IMAGE_FORMAT_GRAY 0      // 8-bit grayscale
#define IMAGE_FORMAT_RGB 1       // 24-bit RGB
#define IMAGE_FORMAT_RGBA 2      // 32-bit RGBA
#define IMAGE_FORMAT_BGRA 3      // 32-bit BGRA

// Image metadata
typedef struct {
    uint32_t width;
    uint32_t height;
    image_format_t format;
    uint32_t bytes_per_pixel;
    uint64_t data_size;
} image_metadata_t;

// Decode image from encoded data
// Returns error code; fills output_data and metadata on success
// Caller responsible for freeing output_data
image_decode_error_t image_decode(
    const uint8_t* encoded_data,
    uint64_t encoded_size,
    uint8_t** output_data,        // Output: decoded pixels (caller must free)
    image_metadata_t* metadata    // Output: image metadata
);

// Decode JPEG specifically
image_decode_error_t image_decode_jpeg(
    const uint8_t* jpeg_data,
    uint64_t jpeg_size,
    uint8_t** output_data,
    image_metadata_t* metadata
);

// Decode PNG specifically
image_decode_error_t image_decode_png(
    const uint8_t* png_data,
    uint64_t png_size,
    uint8_t** output_data,
    image_metadata_t* metadata
);

// Decode WebP specifically
image_decode_error_t image_decode_webp(
    const uint8_t* webp_data,
    uint64_t webp_size,
    uint8_t** output_data,
    image_metadata_t* metadata
);

// Free decoded image data
void image_decode_free(uint8_t* data);

// Detect image format from header
image_format_t image_detect_format(const uint8_t* data, uint64_t size);

#ifdef __cplusplus
}
#endif

#endif // IMAGE_DECODE_H
