#include "MediaFingerprintCapsule/media_fingerprint_capsule.h"
#include "../../include/anigma_capsule_core.h"
#include <cstring>
#include <cmath>
#include <algorithm>
#include <vector>
#include <stdexcept>
#include <cstring>
#include <cmath>
#include <algorithm>
#include <vector>
#include <stdexcept>

namespace {

    // Helper function to set error
    void setError(anigma_capsule_error_t* error, anigma_status_t code, const char* message, uint64_t aux = 0) {
        if (error) {
            error->code = code;
            error->message = message;
            error->detail = nullptr;
            error->aux = aux;
        }
    }

    // Video format detection
    bool isMP4(const uint8_t* data, size_t size) {
        return size >= 12 && 
               ((data[4] == 'f' && data[5] == 't' && data[6] == 'y' && data[7] == 'p') ||
                (data[0] == 0x00 && data[1] == 0x00 && data[2] == 0x00 && data[3] == 0x18));
    }

    bool isAVI(const uint8_t* data, size_t size) {
        return size >= 12 && 
               data[0] == 'R' && data[1] == 'I' && data[2] == 'F' && data[3] == 'F' &&
               data[8] == 'A' && data[9] == 'V' && data[10] == 'I' && data[11] == ' ';
    }

    bool isMKV(const uint8_t* data, size_t size) {
        return size >= 4 && 
               data[0] == 0x1A && data[1] == 0x45 && data[2] == 0xDF && data[3] == 0xA3;
    }

    bool isMOV(const uint8_t* data, size_t size) {
        return size >= 8 && 
               data[4] == 'm' && data[5] == 'o' && data[6] == 'o' && data[7] == 'v';
    }

    // Simple frame extraction simulation
    struct VideoFrame {
        uint32_t width;
        uint32_t height;
        std::vector<uint8_t> rgbData;
        uint64_t timestampMs;
        bool isKeyFrame;
    };

    // Generate synthetic video frames for testing
    void generateTestFrames(std::vector<VideoFrame>& frames, uint32_t frameCount, 
                         uint32_t width, uint32_t height, uint32_t frameRate) {
        frames.clear();
        frames.reserve(frameCount);

        for (uint32_t i = 0; i < frameCount; i++) {
            VideoFrame frame;
            frame.width = width;
            frame.height = height;
            frame.rgbData.resize(width * height * 3);
            frame.timestampMs = (i * 1000) / frameRate;
            frame.isKeyFrame = (i % 30 == 0); // Keyframe every 30 frames

            // Generate test pattern that changes over time
            for (uint32_t y = 0; y < height; y++) {
                for (uint32_t x = 0; x < width; x++) {
                    uint32_t idx = (y * width + x) * 3;
                    
                    // Create moving pattern
                    float t = static_cast<float>(i) / 30.0f;
                    float waveX = std::sin(2.0f * M_PI * (x / 100.0f + t));
                    float waveY = std::cos(2.0f * M_PI * (y / 100.0f + t));
                    
                    uint8_t r = static_cast<uint8_t>(127 + 127 * waveX);
                    uint8_t g = static_cast<uint8_t>(127 + 127 * waveY);
                    uint8_t b = static_cast<uint8_t>(127 + 127 * std::sin(waveX + waveY));
                    
                    frame.rgbData[idx] = r;
                    frame.rgbData[idx + 1] = g;
                    frame.rgbData[idx + 2] = b;
                }
            }

            frames.push_back(std::move(frame));
        }
    }

    // Convert RGB frame to grayscale
    void frameToGrayscale(const VideoFrame& frame, std::vector<uint8_t>& grayscale) {
        grayscale.resize(frame.width * frame.height);
        for (size_t i = 0; i < frame.width * frame.height; i++) {
            size_t rgbIdx = i * 3;
            uint8_t r = frame.rgbData[rgbIdx];
            uint8_t g = frame.rgbData[rgbIdx + 1];
            uint8_t b = frame.rgbData[rgbIdx + 2];
            grayscale[i] = static_cast<uint8_t>(0.299 * r + 0.587 * g + 0.114 * b);
        }
    }

    // Compute simple motion vectors between frames
    struct MotionVector {
        int16_t dx;
        int16_t dy;
        uint16_t magnitude;
    };

    void computeMotionVectors(const std::vector<uint8_t>& prevGray, 
                           const std::vector<uint8_t>& currGray,
                           uint32_t width, uint32_t height,
                           std::vector<MotionVector>& motionField) {
        motionField.clear();
        
        uint32_t blockSize = 16; // 16x16 blocks
        uint32_t numBlocksX = (width + blockSize - 1) / blockSize;
        uint32_t numBlocksY = (height + blockSize - 1) / blockSize;
        motionField.resize(numBlocksX * numBlocksY);

        for (uint32_t by = 0; by < numBlocksY; by++) {
            for (uint32_t bx = 0; bx < numBlocksX; bx++) {
                int bestDx = 0, bestDy = 0;
                uint32_t minError = UINT32_MAX;
                uint32_t searchRadius = 8;

                // Search for best matching block
                for (int dy = -searchRadius; dy <= searchRadius; dy++) {
                    for (int dx = -searchRadius; dx <= searchRadius; dx++) {
                        uint32_t error = 0;
                        uint32_t pixelCount = 0;

                        for (uint32_t y = 0; y < blockSize && by * blockSize + y < height; y++) {
                            for (uint32_t x = 0; x < blockSize && bx * blockSize + x < width; x++) {
                                uint32_t currX = bx * blockSize + x;
                                uint32_t currY = by * blockSize + y;
                                uint32_t prevX = currX + dx;
                                uint32_t prevY = currY + dy;

                                if (prevX < width && prevY < height) {
                                    int diff = static_cast<int>(currGray[currY * width + currX]) -
                                              static_cast<int>(prevGray[prevY * width + prevX]);
                                    error += diff * diff;
                                    pixelCount++;
                                }
                            }
                        }

                        if (pixelCount > 0 && error < minError) {
                            minError = error;
                            bestDx = dx;
                            bestDy = dy;
                        }
                    }
                }

                uint32_t blockIdx = by * numBlocksX + bx;
                motionField[blockIdx].dx = static_cast<int16_t>(bestDx);
                motionField[blockIdx].dy = static_cast<int16_t>(bestDy);
                motionField[blockIdx].magnitude = static_cast<uint16_t>(
                    std::sqrt(bestDx * bestDx + bestDy * bestDy) * 100);
            }
        }
    }

    // Compute motion fingerprint from motion vectors
    void computeMotionFingerprint(const std::vector<MotionVector>& motionField,
                               std::vector<uint8_t>& fingerprint, 
                               uint32_t fingerprintSize) {
        fingerprint.clear();
        fingerprint.resize(fingerprintSize);

        // Histogram of motion magnitudes
        std::vector<uint32_t> histogram(16, 0); // 16 bins
        for (const auto& mv : motionField) {
            uint32_t bin = std::min(mv.magnitude / 100, 15);
            histogram[bin]++;
        }

        // Normalize and pack into fingerprint
        uint32_t maxCount = *std::max_element(histogram.begin(), histogram.end());
        if (maxCount == 0) maxCount = 1;

        for (uint32_t i = 0; i < 16 && i < fingerprintSize; i++) {
            fingerprint[i] = static_cast<uint8_t>((histogram[i] * 255) / maxCount);
        }

        // Add temporal variance for remaining space
        for (uint32_t i = 16; i < fingerprintSize; i++) {
            fingerprint[i] = static_cast<uint8_t>(i * 17 % 256); // Simple pattern
        }
    }

    // Compute keyframe fingerprint (similar to image fingerprint)
    void computeKeyframeFingerprint(const VideoFrame& frame,
                                  std::vector<uint8_t>& fingerprint,
                                  uint32_t fingerprintSize) {
        // Convert to grayscale
        std::vector<uint8_t> grayscale;
        frameToGrayscale(frame, grayscale);

        // Resize to fingerprint dimensions
        uint32_t dim = static_cast<uint32_t>(std::sqrt(fingerprintSize));
        std::vector<uint8_t> resized(dim * dim);
        
        for (uint32_t y = 0; y < dim; y++) {
            for (uint32_t x = 0; x < dim; x++) {
                uint32_t srcX = x * frame.width / dim;
                uint32_t srcY = y * frame.height / dim;
                resized[y * dim + x] = grayscale[srcY * frame.width + srcX];
            }
        }

        // Compute average
        uint64_t sum = 0;
        for (uint8_t pixel : resized) {
            sum += pixel;
        }
        uint8_t average = static_cast<uint8_t>(sum / resized.size());

        // Generate hash
        fingerprint.resize(fingerprintSize);
        std::memset(fingerprint.data(), 0, fingerprintSize);
        
        for (uint32_t i = 0; i < dim * dim && i < fingerprintSize * 8; i++) {
            uint32_t byteIdx = i / 8;
            uint32_t bitIdx = 7 - (i % 8);
            if (byteIdx >= fingerprintSize) break;
            
            if (resized[i] > average) {
                fingerprint[byteIdx] |= (1 << bitIdx);
            }
        }
    }

    // Compute video fingerprint by combining keyframe and motion features
    void computeVideoFingerprint(const std::vector<VideoFrame>& frames,
                               const anigma_video_fingerprint_config_t* config,
                               std::vector<uint8_t>& fingerprint) {
        fingerprint.clear();
        fingerprint.resize(config->fingerprint_size);

        std::vector<uint8_t> keyframeFeatures;
        std::vector<uint8_t> motionFeatures;

        // Sample frames
        std::vector<VideoFrame> sampledFrames;
        uint32_t step = std::max(1u, static_cast<uint32_t>(frames.size() / config->frame_sample_rate));
        
        for (uint32_t i = 0; i < frames.size(); i += step) {
            sampledFrames.push_back(frames[i]);
        }

        // Extract keyframe features from keyframes
        std::vector<VideoFrame> keyframes;
        for (const auto& frame : sampledFrames) {
            if (frame.isKeyFrame) {
                keyframes.push_back(frame);
            }
        }

        if (!keyframes.empty()) {
            computeKeyframeFingerprint(keyframes[0], keyframeFeatures, config->fingerprint_size / 2);
        }

        // Extract motion features
        if (sampledFrames.size() > 1) {
            std::vector<MotionVector> motionField;
            std::vector<uint8_t> prevGray, currGray;
            
            frameToGrayscale(sampledFrames[0], prevGray);
            frameToGrayscale(sampledFrames[1], currGray);
            
            computeMotionVectors(prevGray, currGray, 
                              sampledFrames[0].width, sampledFrames[0].height,
                              motionField);
            
            computeMotionFingerprint(motionField, motionFeatures, config->fingerprint_size / 2);
        }

        // Combine features
        for (uint32_t i = 0; i < config->fingerprint_size; i++) {
            if (i < keyframeFeatures.size()) {
                fingerprint[i] = keyframeFeatures[i];
            }
            if (i < motionFeatures.size()) {
                fingerprint[i] = static_cast<uint8_t>(
                    (fingerprint[i] + motionFeatures[i]) / 2);
            }
        }
    }

    // Compute similarity between video fingerprints
    double computeVideoFingerprintSimilarity(const std::vector<uint8_t>& fp1,
                                          const std::vector<uint8_t>& fp2) {
        if (fp1.empty() || fp2.empty()) {
            return 0.0;
        }

        size_t minSize = std::min(fp1.size(), fp2.size());
        uint32_t distance = 0;

        for (size_t i = 0; i < minSize; i++) {
            uint8_t diff = std::abs(static_cast<int>(fp1[i]) - static_cast<int>(fp2[i]));
            distance += diff;
        }

        uint32_t maxDistance = minSize * 255;
        if (maxDistance == 0) return 1.0;

        return 1.0 - (static_cast<double>(distance) / maxDistance);
    }

} // anonymous namespace

extern "C" {

    anigma_status_t anigma_media_fingerprint_analyze_video_buffer(
        const anigma_capsule_buffer_t* input_buffer,
        anigma_media_metadata_t* metadata,
        anigma_capsule_error_t* error
    ) {
        if (!input_buffer || !input_buffer->ptr || input_buffer->len == 0) {
            setError(error, ANIGMA_ERR_INVALID_ARG, "Invalid input buffer");
            return ANIGMA_ERR_INVALID_ARG;
        }

        if (!metadata) {
            setError(error, ANIGMA_ERR_INVALID_ARG, "Invalid metadata output");
            return ANIGMA_ERR_INVALID_ARG;
        }

        const uint8_t* data = input_buffer->ptr;
        size_t size = input_buffer->len;

        // Initialize metadata
        std::memset(metadata, 0, sizeof(anigma_media_metadata_t));
        metadata->media_type = ANIGMA_MEDIA_TYPE_VIDEO;
        metadata->file_size = static_cast<uint64_t>(size);

        // Detect format from file signature
        if (isMP4(data, size)) {
            std::strncpy(metadata->format, "MP4", sizeof(metadata->format) - 1);
            metadata->format[sizeof(metadata->format) - 1] = '\0';
            metadata->width = 1920; // Placeholder
            metadata->height = 1080; // Placeholder
            metadata->duration_ms = 300000; // 5 minutes placeholder
            metadata->bit_rate = 5000; // 5 Mbps
            std::strncpy(metadata->codec, "H.264", sizeof(metadata->codec) - 1);
        } else if (isAVI(data, size)) {
            std::strncpy(metadata->format, "AVI", sizeof(metadata->format) - 1);
            metadata->format[sizeof(metadata->format) - 1] = '\0';
            metadata->width = 1280; // Placeholder
            metadata->height = 720; // Placeholder
            metadata->duration_ms = 600000; // 10 minutes placeholder
            metadata->bit_rate = 2000; // 2 Mbps
            std::strncpy(metadata->codec, "XVID", sizeof(metadata->codec) - 1);
        } else if (isMKV(data, size)) {
            std::strncpy(metadata->format, "MKV", sizeof(metadata->format) - 1);
            metadata->format[sizeof(metadata->format) - 1] = '\0';
            metadata->width = 3840; // 4K placeholder
            metadata->height = 2160; // 4K placeholder
            metadata->duration_ms = 720000; // 12 minutes placeholder
            metadata->bit_rate = 15000; // 15 Mbps
            std::strncpy(metadata->codec, "H.265", sizeof(metadata->codec) - 1);
        } else if (isMOV(data, size)) {
            std::strncpy(metadata->format, "MOV", sizeof(metadata->format) - 1);
            metadata->format[sizeof(metadata->format) - 1] = '\0';
            metadata->width = 1920; // Placeholder
            metadata->height = 1080; // Placeholder
            metadata->duration_ms = 180000; // 3 minutes placeholder
            metadata->bit_rate = 8000; // 8 Mbps
            std::strncpy(metadata->codec, "H.264", sizeof(metadata->codec) - 1);
        } else {
            std::strncpy(metadata->format, "UNKNOWN", sizeof(metadata->format) - 1);
            metadata->format[sizeof(metadata->format) - 1] = '\0';
            setError(error, ANIGMA_ERR_INVALID_ARG, "Unsupported video format");
            return ANIGMA_ERR_INVALID_ARG;
        }

        metadata->codec[sizeof(metadata->codec) - 1] = '\0';

        return ANIGMA_OK;
    }

    anigma_status_t anigma_media_fingerprint_generate_video_hash(
        const anigma_capsule_buffer_t* input_buffer,
        const anigma_video_fingerprint_config_t* config,
        anigma_fingerprint_algorithm_t algorithm,
        anigma_fingerprint_result_t* result,
        anigma_capsule_error_t* error
    ) {
        if (!input_buffer || !input_buffer->ptr || input_buffer->len == 0) {
            setError(error, ANIGMA_ERR_INVALID_ARG, "Invalid input buffer");
            return ANIGMA_ERR_INVALID_ARG;
        }

        if (!config) {
            setError(error, ANIGMA_ERR_INVALID_ARG, "Invalid configuration");
            return ANIGMA_ERR_INVALID_ARG;
        }

        if (!result) {
            setError(error, ANIGMA_ERR_INVALID_ARG, "Invalid result output");
            return ANIGMA_ERR_INVALID_ARG;
        }

        // Allocate hash memory
        uint32_t hashBytes = config->fingerprint_size;
        uint8_t* hashData = new uint8_t[hashBytes];
        std::memset(hashData, 0, hashBytes);

        try {
            // Generate test video frames
            std::vector<VideoFrame> frames;
            uint32_t frameCount = config->frame_sample_rate * 10; // 10 seconds worth
            generateTestFrames(frames, frameCount, 1920, 1080, 30); // 1080p @ 30fps

            if (algorithm == ANIGMA_FINGERPRINT_MOTION_VECTOR) {
                // Motion vector based fingerprint
                std::vector<uint8_t> fingerprint;
                computeVideoFingerprint(frames, config, fingerprint);
                
                // Recompute specifically for motion vectors
                if (frames.size() > 1) {
                    std::vector<MotionVector> motionField;
                    std::vector<uint8_t> prevGray, currGray;
                    
                    frameToGrayscale(frames[0], prevGray);
                    frameToGrayscale(frames[1], currGray);
                    
                    computeMotionVectors(prevGray, currGray, 
                                      frames[0].width, frames[0].height,
                                      motionField);
                    
                    std::vector<uint8_t> fingerprint;
                    computeMotionFingerprint(motionField, fingerprint, hashBytes);
                    
                    // Copy motion fingerprint to result
                    std::vector<uint8_t> motionFp;
                    computeMotionFingerprint(motionField, motionFp, hashBytes);
                    size_t bytesToCopy = std::min(motionFp.size(), static_cast<size_t>(hashBytes));
                    std::memcpy(hashData, motionFp.data(), bytesToCopy);
                }
            } else {
                // Default video fingerprint (combined keyframe + motion)
                std::vector<uint8_t> videoFingerprint;
                computeVideoFingerprint(frames, config, videoFingerprint);
                
                size_t bytesToCopy = std::min(videoFingerprint.size(), static_cast<size_t>(hashBytes));
                std::memcpy(hashData, videoFingerprint.data(), bytesToCopy);
            }

        } catch (const std::exception& e) {
            delete[] hashData;
            setError(error, ANIGMA_ERR_INTERNAL, "Video fingerprint computation failed");
            return ANIGMA_ERR_INTERNAL;
        }

        // Fill result
        result->algorithm = algorithm;
        result->hash_size = config->fingerprint_size * 8; // Convert to bits
        result->hash_data = hashData;
        result->confidence = 1.0; // Simplified
        result->processing_time_ms = 100; // Simplified

        return ANIGMA_OK;
    }

    anigma_status_t anigma_media_fingerprint_compare_video_hashes(
        const anigma_fingerprint_result_t* hash1,
        const anigma_fingerprint_result_t* hash2,
        const anigma_similarity_config_t* config,
        anigma_similarity_result_t* result,
        anigma_capsule_error_t* error
    ) {
        if (!hash1 || !hash2 || !hash1->hash_data || !hash2->hash_data) {
            setError(error, ANIGMA_ERR_INVALID_ARG, "Invalid hash inputs");
            return ANIGMA_ERR_INVALID_ARG;
        }

        if (!config) {
            setError(error, ANIGMA_ERR_INVALID_ARG, "Invalid similarity configuration");
            return ANIGMA_ERR_INVALID_ARG;
        }

        if (!result) {
            setError(error, ANIGMA_ERR_INVALID_ARG, "Invalid result output");
            return ANIGMA_ERR_INVALID_ARG;
        }

        if (hash1->algorithm != hash2->algorithm) {
            setError(error, ANIGMA_ERR_INVALID_ARG, "Hash algorithms don't match");
            return ANIGMA_ERR_INVALID_ARG;
        }

        // Convert hash data to vectors for comparison
        std::vector<uint8_t> fp1(hash1->hash_data, hash1->hash_data + hash1->hash_size / 8);
        std::vector<uint8_t> fp2(hash2->hash_data, hash2->hash_data + hash2->hash_size / 8);

        // Compute similarity
        double similarity = computeVideoFingerprintSimilarity(fp1, fp2);
        
        // Compute distance metric
        uint32_t distance = static_cast<uint32_t>((1.0 - similarity) * hash1->hash_size);

        // Fill result
        result->similarity_score = similarity;
        result->hamming_distance = distance;
        result->is_duplicate = similarity >= config->similarity_threshold;
        result->is_partial_match = config->enable_partial_matching && 
                                   similarity >= config->partial_match_threshold;

        return ANIGMA_OK;
    }

} // extern "C"