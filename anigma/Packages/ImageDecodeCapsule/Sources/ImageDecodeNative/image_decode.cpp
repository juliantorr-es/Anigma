// image_decode.cpp
// Native image decoding implementation
// Uses ImageIO framework for hardware-accelerated decoding

#include "image_decode.h"
#include <stdlib.h>
#include <string.h>

const char* image_decode_version(void) {
    return "1.0.0";
}

// Magic number detection for image formats
static bool is_jpeg(const uint8_t* data, uint64_t size) {
    return size >= 2 && data[0] == 0xFF && data[1] == 0xD8;
}

static bool is_png(const uint8_t* data, uint64_t size) {
    return size >= 8 && 
           data[0] == 0x89 && 
           data[1] == 0x50 && 
           data[2] == 0x4E && 
           data[3] == 0x47;
}

static bool is_webp(const uint8_t* data, uint64_t size) {
    return size >= 12 &&
           data[0] == 0x52 &&
           data[1] == 0x49 &&
           data[2] == 0x46 &&
           data[3] == 0x46 &&
           data[8] == 0x57 &&
           data[9] == 0x45 &&
           data[10] == 0x42 &&
           data[11] == 0x50;
}

#ifdef __APPLE__
#include <ImageIO/ImageIO.h>
#include <CoreGraphics/CoreGraphics.h>

static image_decode_error_t decode_with_imageio(
    const uint8_t* encoded_data,
    uint64_t encoded_size,
    uint8_t** output_data,
    image_metadata_t* metadata
) {
    if (!encoded_data || !output_data || !metadata) {
        return IMAGE_DECODE_ERROR_NULL_POINTER;
    }
    
    if (encoded_size == 0) {
        return IMAGE_DECODE_ERROR_INVALID_DATA;
    }
    
    // Create data provider from buffer
    CGDataProviderRef provider = CGDataProviderCreateWithData(
        nullptr,
        encoded_data,
        encoded_size,
        nullptr  // No release callback
    );
    
    if (!provider) {
        return IMAGE_DECODE_ERROR_MEMORY_ALLOCATION;
    }
    
    // Try to create image source
    CGImageSourceRef source = CGImageSourceCreateWithDataProvider(provider, nullptr);
    CGDataProviderRelease(provider);
    
    if (!source) {
        return IMAGE_DECODE_ERROR_DECODE_FAILED;
    }
    
    // Get image
    CGImageRef cgimage = CGImageSourceCreateImageAtIndex(source, 0, nullptr);
    CFRelease(source);
    
    if (!cgimage) {
        return IMAGE_DECODE_ERROR_DECODE_FAILED;
    }
    
    // Extract dimensions and format
    size_t width = CGImageGetWidth(cgimage);
    size_t height = CGImageGetHeight(cgimage);
    
    if (width == 0 || height == 0 || width > 65536 || height > 65536) {
        CGImageRelease(cgimage);
        return IMAGE_DECODE_ERROR_INVALID_DIMENSIONS;
    }
    
    // Determine format and create context
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    size_t bytesPerPixel = 4;
    
    metadata->format = IMAGE_FORMAT_RGBA;
    metadata->bytes_per_pixel = bytesPerPixel;
    metadata->width = (uint32_t)width;
    metadata->height = (uint32_t)height;
    metadata->data_size = width * height * bytesPerPixel;
    
    // Allocate output buffer
    uint8_t* buffer = (uint8_t*)malloc(metadata->data_size);
    if (!buffer) {
        CGColorSpaceRelease(colorSpace);
        CGImageRelease(cgimage);
        return IMAGE_DECODE_ERROR_MEMORY_ALLOCATION;
    }
    
    // Create context and draw image
    CGContextRef ctx = CGBitmapContextCreate(
        buffer,
        width, height,
        8,  // bits per component
        width * bytesPerPixel,  // bytes per row
        colorSpace,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault
    );
    
    CGColorSpaceRelease(colorSpace);
    
    if (!ctx) {
        free(buffer);
        CGImageRelease(cgimage);
        return IMAGE_DECODE_ERROR_MEMORY_ALLOCATION;
    }
    
    CGContextDrawImage(ctx, CGRectMake(0, 0, width, height), cgimage);
    CGContextRelease(ctx);
    CGImageRelease(cgimage);
    
    *output_data = buffer;
    return IMAGE_DECODE_SUCCESS;
}

#else
// Fallback for non-Apple platforms (simplified stub)
static image_decode_error_t decode_with_imageio(
    const uint8_t* encoded_data,
    uint64_t encoded_size,
    uint8_t** output_data,
    image_metadata_t* metadata
) {
    return IMAGE_DECODE_ERROR_UNSUPPORTED_FORMAT;
}
#endif

image_decode_error_t image_decode(
    const uint8_t* encoded_data,
    uint64_t encoded_size,
    uint8_t** output_data,
    image_metadata_t* metadata
) {
    if (!encoded_data || !output_data || !metadata) {
        return IMAGE_DECODE_ERROR_NULL_POINTER;
    }
    
    if (encoded_size == 0) {
        return IMAGE_DECODE_ERROR_INVALID_DATA;
    }
    
    // Use ImageIO for all formats (JPEG, PNG, WebP)
    return decode_with_imageio(encoded_data, encoded_size, output_data, metadata);
}

image_decode_error_t image_decode_jpeg(
    const uint8_t* jpeg_data,
    uint64_t jpeg_size,
    uint8_t** output_data,
    image_metadata_t* metadata
) {
    if (!is_jpeg(jpeg_data, jpeg_size)) {
        return IMAGE_DECODE_ERROR_INVALID_DATA;
    }
    return image_decode(jpeg_data, jpeg_size, output_data, metadata);
}

image_decode_error_t image_decode_png(
    const uint8_t* png_data,
    uint64_t png_size,
    uint8_t** output_data,
    image_metadata_t* metadata
) {
    if (!is_png(png_data, png_size)) {
        return IMAGE_DECODE_ERROR_INVALID_DATA;
    }
    return image_decode(png_data, png_size, output_data, metadata);
}

image_decode_error_t image_decode_webp(
    const uint8_t* webp_data,
    uint64_t webp_size,
    uint8_t** output_data,
    image_metadata_t* metadata
) {
    if (!is_webp(webp_data, webp_size)) {
        return IMAGE_DECODE_ERROR_INVALID_DATA;
    }
    return image_decode(webp_data, webp_size, output_data, metadata);
}

void image_decode_free(uint8_t* data) {
    if (data) {
        free(data);
    }
}

image_format_t image_detect_format(const uint8_t* data, uint64_t size) {
    if (!data || size == 0) {
        return 0xFF;  // Unknown
    }
    
    if (is_jpeg(data, size)) {
        return 0x01;  // JPEG
    }
    if (is_png(data, size)) {
        return 0x02;  // PNG
    }
    if (is_webp(data, size)) {
        return 0x03;  // WebP
    }
    
    return 0xFF;  // Unknown
}
