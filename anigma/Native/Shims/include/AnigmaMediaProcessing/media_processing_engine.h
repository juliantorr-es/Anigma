#ifndef ANIGMA_MEDIA_PROCESSING_ENGINE_H
#define ANIGMA_MEDIA_PROCESSING_ENGINE_H

#include "anigma_capsule_core.h"

#ifdef __cplusplus
#include <memory>
#include <vector>
#include <unordered_map>
#include <mutex>
#include <chrono>
#include <cstdint>
#include <list>
#include <shared_mutex>

#ifdef ENABLE_OPENCV
#include <opencv2/opencv.hpp>
#endif

#ifdef ENABLE_FFMPEG
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/opt.h>
#include <libswscale/swscale.h>
}
#endif

namespace AnigmaMediaProcessing {

// Forward declarations
class MediaFingerprintProcessor;
class TextProcessor;
class AudioProcessor;
class VideoProcessor;

// Memory management with RAII
class MemoryManager {
private:
    struct MemoryPool {
        uint8_t* buffer;
        size_t size;
        size_t used;
        std::mutex poolMutex;
    };
    
    std::vector<std::unique_ptr<MemoryPool>> pools;
    std::mutex managerMutex;
    
public:
    MemoryManager();
    ~MemoryManager();
    
    void* allocate(size_t size, size_t alignment = 16);
    void deallocate(void* ptr);
    size_t getTotalUsage() const;
    void cleanup();
    
    // Singleton access
    static MemoryManager& getInstance();
};

// Performance monitoring
class PerformanceMonitor {
private:
    struct TimingStats {
        std::chrono::high_resolution_clock::time_point startTime;
        std::chrono::duration<double, std::milli> totalProcessingTime{0};
        uint64_t operationsCount{0};
        double minTime{std::numeric_limits<double>::max()};
        double maxTime{0.0};
    };
    
    std::unordered_map<std::string, TimingStats> stats;
    std::mutex statsMutex;
    
public:
    void startOperation(const std::string& operation);
    void endOperation(const std::string& operation);
    
    double getAverageTime(const std::string& operation) const;
    double getMinTime(const std::string& operation) const;
    double getMaxTime(const std::string& operation) const;
    uint64_t getOperationsCount(const std::string& operation) const;
    
    void resetStats();
    void printReport() const;
};

// Thread-safe LRU cache
template<typename Key, typename Value>
class LRUCache {
private:
    struct CacheNode {
        Key key;
        Value value;
        std::chrono::steady_clock::time_point accessTime;
        std::chrono::milliseconds ttl{std::chrono::minutes(30)}; // 30 minute TTL
    };
    
    size_t maxSize;
    std::unordered_map<Key, CacheNode> cache;
    std::list<Key> accessOrder;
    mutable std::shared_mutex cacheMutex;
    
    void evictExpired();
    void evictLRU();
    
public:
    explicit LRUCache(size_t maxSize = 1000) : maxSize(maxSize) {}
    
    bool get(const Key& key, Value& value) const {
        std::shared_lock<std::shared_mutex> lock(cacheMutex);
        
        auto it = cache.find(key);
        if (it == cache.end()) {
            return false;
        }
        
        auto now = std::chrono::steady_clock::now();
        if (now - it->second.accessTime > it->second.ttl) {
            cache.erase(it);
            accessOrder.remove(key);
            return false;
        }
        
        // Update access time and order
        accessOrder.remove(key);
        accessOrder.push_front(key);
        
        // Note: This is non-const but we're in const method
        const_cast<CacheNode&>(it->second).accessTime = now;
        
        value = it->second.value;
        return true;
    }
    
    void put(const Key& key, const Value& value) {
        std::unique_lock<std::shared_mutex> lock(cacheMutex);
        
        // Check if key already exists
        auto it = cache.find(key);
        if (it != cache.end()) {
            accessOrder.remove(key);
        }
        
        // Add new entry
        CacheNode node;
        node.key = key;
        node.value = value;
        node.accessTime = std::chrono::steady_clock::now();
        
        cache[key] = node;
        accessOrder.push_front(key);
        
        // Evict if necessary
        while (cache.size() > maxSize) {
            evictLRU();
        }
        evictExpired();
    }
    
    void clear() {
        std::unique_lock<std::shared_mutex> lock(cacheMutex);
        cache.clear();
        accessOrder.clear();
    }
    
    size_t size() const {
        std::shared_lock<std::shared_mutex> lock(cacheMutex);
        return cache.size();
    }
};

// Media processing base class
class MediaProcessor {
protected:
    MemoryManager& memoryManager;
    PerformanceMonitor& perfMonitor;
    anigma_capsule_error_t lastError;
    
    virtual void setError(uint32_t code, const char* message, uint64_t aux = 0);
    
public:
    MediaProcessor();
    virtual ~MediaProcessor() = default;
    
    anigma_status_t getLastError(anigma_capsule_error_t* error) const;
    void clearError();
    
    // Pure virtual methods
    virtual anigma_status_t initialize(const anigma_capsule_buffer_t* config) = 0;
    virtual anigma_status_t process(const anigma_capsule_buffer_t* input, anigma_capsule_buffer_t* output) = 0;
    virtual anigma_status_t cleanup() = 0;
};

// Enhanced image processor with OpenCV support
class ImageProcessor : public MediaProcessor {
private:
#ifdef ENABLE_OPENCV
    cv::Mat currentImage;
    cv::Mat grayscaleImage;
    std::unique_ptr<cv::Feature2D> featureDetector;
#endif
    
    struct ImageMetadata {
        int width{0};
        int height{0};
        int channels{0};
        int depth{0};
        const char* format{nullptr};
    } metadata;
    
    anigma_status_t detectImageFormat(const anigma_capsule_buffer_t* input);
    anigma_status_t decodeImage(const anigma_capsule_buffer_t* input);
    anigma_status_t preprocessForFingerprinting();
    
public:
    ImageProcessor();
    ~ImageProcessor() override;
    
    anigma_status_t initialize(const anigma_capsule_buffer_t* config) override;
    anigma_status_t process(const anigma_capsule_buffer_t* input, anigma_capsule_buffer_t* output) override;
    anigma_status_t cleanup() override;
    
    // Image-specific methods
    anigma_status_t resize(int targetWidth, int targetHeight);
    anigma_status_t convertToGrayscale();
    anigma_status_t extractFeatures();
    
    const ImageMetadata& getMetadata() const { return metadata; }
};

// Enhanced audio processor with FFmpeg support  
class AudioProcessor : public MediaProcessor {
private:
#ifdef ENABLE_FFMPEG
    AVFormatContext* formatContext{nullptr};
    AVCodecContext* codecContext{nullptr};
    AVFrame* audioFrame{nullptr};
    SwsContext* swsContext{nullptr};
#endif
    
    struct AudioMetadata {
        int sampleRate{0};
        int channels{0};
        int64_t duration{0}; // in microseconds
        int bitRate{0};
        const char* codec{nullptr};
    } metadata;
    
    anigma_status_t openAudioFile(const anigma_capsule_buffer_t* input);
    anigma_status_t decodeAudioFrame();
    anigma_status_t convertToMono();
    
public:
    AudioProcessor();
    ~AudioProcessor() override;
    
    anigma_status_t initialize(const anigma_capsule_buffer_t* config) override;
    anigma_status_t process(const anigma_capsule_buffer_t* input, anigma_capsule_buffer_t* output) override;
    anigma_status_t cleanup() override;
    
    // Audio-specific methods
    anigma_status_t extractChromaprint();
    anigma_status_t computeSpectrogram();
    anigma_status_t detectOnsets();
    
    const AudioMetadata& getMetadata() const { return metadata; }
};

// Video processor combining audio and image processing
class VideoProcessor : public MediaProcessor {
private:
    std::unique_ptr<ImageProcessor> imageProcessor;
    std::unique_ptr<AudioProcessor> audioProcessor;
    
#ifdef ENABLE_FFMPEG
    AVFormatContext* formatContext{nullptr};
    AVCodecContext* videoCodecContext{nullptr};
    AVCodecContext* audioCodecContext{nullptr};
    AVStream* videoStream{nullptr};
    AVStream* audioStream{nullptr};
#endif
    
    struct VideoMetadata {
        int width{0};
        int height{0};
        double frameRate{0.0};
        int64_t duration{0}; // in microseconds
        int bitRate{0};
        const char* videoCodec{nullptr};
        const char* audioCodec{nullptr};
    } metadata;
    
    anigma_status_t openVideoFile(const anigma_capsule_buffer_t* input);
    anigma_status_t extractKeyframes();
    anigma_status_t analyzeMotionVectors();
    
public:
    VideoProcessor();
    ~VideoProcessor() override;
    
    anigma_status_t initialize(const anigma_capsule_buffer_t* config) override;
    anigma_status_t process(const anigma_capsule_buffer_t* input, anigma_capsule_buffer_t* output) override;
    anigma_status_t cleanup() override;
    
    // Video-specific methods
    anigma_status_t extractKeyframeFingerprint();
    anigma_status_t computeMotionFingerprint();
    anigma_status_t analyzeScenes();
    
    const VideoMetadata& getMetadata() const { return metadata; }
};

} // namespace AnigmaMediaProcessing

#endif // __cplusplus

#endif // ANIGMA_MEDIA_PROCESSING_ENGINE_H
