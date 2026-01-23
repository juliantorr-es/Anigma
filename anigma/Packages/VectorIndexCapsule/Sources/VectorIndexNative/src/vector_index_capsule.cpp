#include "../include/anigma_vector_index_capsule.h"
#include <vector>
#include <queue>
#include <map>
#include <set>
#include <mutex>
#include <random>
#include <cmath>
#include <algorithm>
#include <cstring>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>

#if defined(__ARM_NEON)
#include <arm_neon.h>
#endif

// --- Math Utilities ---

static float dot_product(const float* a, const float* b, uint32_t dim) {
    float sum = 0;
#if defined(__ARM_NEON)
    uint32_t i = 0;
    float32x4_t vsum = vdupq_n_f32(0);
    for (; i + 3 < dim; i += 4) {
        float32x4_t va = vld1q_f32(a + i);
        float32x4_t vb = vld1q_f32(b + i);
        vsum = vfmaq_f32(vsum, va, vb);
    }
    sum = vgetq_lane_f32(vsum, 0) + vgetq_lane_f32(vsum, 1) + vgetq_lane_f32(vsum, 2) + vgetq_lane_f32(vsum, 3);
    for (; i < dim; ++i) {
        sum += a[i] * b[i];
    }
#else
    for (uint32_t i = 0; i < dim; ++i) {
        sum += a[i] * b[i];
    }
#endif
    return sum;
}

static float l2_distance(const float* a, const float* b, uint32_t dim) {
    float sum = 0;
#if defined(__ARM_NEON)
    uint32_t i = 0;
    float32x4_t vsum = vdupq_n_f32(0);
    for (; i + 3 < dim; i += 4) {
        float32x4_t va = vld1q_f32(a + i);
        float32x4_t vb = vld1q_f32(b + i);
        float32x4_t diff = vsubq_f32(va, vb);
        vsum = vfmaq_f32(vsum, diff, diff);
    }
    sum = vgetq_lane_f32(vsum, 0) + vgetq_lane_f32(vsum, 1) + vgetq_lane_f32(vsum, 2) + vgetq_lane_f32(vsum, 3);
    for (; i < dim; ++i) {
        float diff = a[i] - b[i];
        sum += diff * diff;
    }
#else
    for (uint32_t i = 0; i < dim; ++i) {
        float diff = a[i] - b[i];
        sum += diff * diff;
    }
#endif
    return sum;
}

// --- HNSW Data Structures ---

struct Node {
    uint64_t external_id = 0;
    std::vector<float> vector;
    std::vector<std::vector<uint32_t>> neighbors; // Per layer
};

struct anigma_vector_index_capsule_t {
    anigma_vector_index_config_t config;
    std::vector<Node> nodes;
    std::map<uint64_t, uint32_t> id_map; // external_id -> internal_index
    int32_t entry_point = -1;
    int32_t max_layer = -1;
    std::mutex mutex;
    std::mt19937 level_generator;
    double level_mult = 0.0;

    explicit anigma_vector_index_capsule_t(const anigma_vector_index_config_t& cfg) 
        : config(cfg), level_generator(42) {
        level_mult = 1.0 / log(static_cast<double>(config.M));
        nodes.reserve(config.max_elements);
    }

    int getRandomLevel() {
        std::uniform_real_distribution<double> dist(0.0, 1.0);
        double r = -log(dist(level_generator)) * level_mult;
        return static_cast<int>(r);
    }
};

// --- C Interface Implementation ---

extern "C" {

anigma_status_t anigma_vector_index_capsule_create(
    const anigma_vector_index_config_t* config,
    anigma_vector_index_capsule_t** handle,
    anigma_capsule_error_t* error
) {
    if (config == nullptr || handle == nullptr) {
        if (error != nullptr) {
            error->code = ANIGMA_ERR_INVALID_ARG;
            error->message = "Invalid arguments";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }

    *handle = new anigma_vector_index_capsule_t(*config);
    return ANIGMA_OK;
}

void anigma_vector_index_capsule_destroy(anigma_vector_index_capsule_t* handle) {
    delete handle;
}

anigma_status_t anigma_vector_index_capsule_add_vector(
    anigma_vector_index_capsule_t* handle,
    uint64_t id,
    const float* vector,
    anigma_capsule_error_t* error
) {
    std::lock_guard<std::mutex> lock(handle->mutex);

    if (handle->id_map.find(id) != handle->id_map.end()) {
        if (error != nullptr) {
            error->code = ANIGMA_ERR_ALREADY_EXISTS;
            error->message = "ID already exists";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }

    auto internal_id = static_cast<uint32_t>(handle->nodes.size());
    if (internal_id >= handle->config.max_elements) {
        if (error != nullptr) {
            error->code = ANIGMA_ERR_INTERNAL;
            error->message = "Index full";
        }
        return ANIGMA_ERR_INTERNAL;
    }

    int level = handle->getRandomLevel();
    Node node;
    node.external_id = id;
    node.vector.assign(vector, vector + handle->config.dimension);
    node.neighbors.resize(level + 1);
    
    handle->nodes.push_back(std::move(node));
    handle->id_map[id] = internal_id;

    if (handle->entry_point == -1) {
        handle->entry_point = static_cast<int32_t>(internal_id);
        handle->max_layer = level;
        return ANIGMA_OK;
    }

    // Simplified HNSW insertion
    int32_t curr_ep = handle->entry_point;
    int cur_l = handle->max_layer;

    // 1. Search in upper layers
    for (; cur_l > level; --cur_l) {
        bool changed = true;
        float curr_dist = l2_distance(vector, handle->nodes[static_cast<size_t>(curr_ep)].vector.data(), handle->config.dimension);
        while (changed) {
            changed = false;
            for (uint32_t neighbor : handle->nodes[static_cast<size_t>(curr_ep)].neighbors[static_cast<size_t>(cur_l)]) {
                float d = l2_distance(vector, handle->nodes[neighbor].vector.data(), handle->config.dimension);
                if (d < curr_dist) {
                    curr_dist = d;
                    curr_ep = static_cast<int32_t>(neighbor);
                    changed = true;
                }
            }
        }
    }

    // 2. Insert and link in bottom layers
    for (; cur_l >= 0; --cur_l) {
        // Find neighbors at this layer (simple greedy)
        std::priority_queue<std::pair<float, uint32_t>> candidates;
        candidates.emplace(-l2_distance(vector, handle->nodes[static_cast<size_t>(curr_ep)].vector.data(), handle->config.dimension), static_cast<uint32_t>(curr_ep));
        
        std::set<uint32_t> visited;
        visited.insert(static_cast<uint32_t>(curr_ep));
        
        std::priority_queue<std::pair<float, uint32_t>> top_k;

        while (!candidates.empty()) {
            auto curr = candidates.top();
            candidates.pop();
            float d = -curr.first;
            
            if (!top_k.empty() && d > -top_k.top().first) break;

            top_k.push(curr);
            if (top_k.size() > handle->config.M) top_k.pop();

            for (uint32_t neighbor : handle->nodes[curr.second].neighbors[static_cast<size_t>(cur_l)]) {
                if (visited.find(neighbor) == visited.end()) {
                    visited.insert(neighbor);
                    float d_n = l2_distance(vector, handle->nodes[neighbor].vector.data(), handle->config.dimension);
                    candidates.emplace(-d_n, neighbor);
                }
            }
        }

        // Link
        while (!top_k.empty()) {
            uint32_t neighbor = top_k.top().second;
            top_k.pop();
            handle->nodes[internal_id].neighbors[static_cast<size_t>(cur_l)].push_back(neighbor);
            handle->nodes[neighbor].neighbors[static_cast<size_t>(cur_l)].push_back(internal_id);
        }
    }

    if (level > handle->max_layer) {
        handle->max_layer = level;
        handle->entry_point = static_cast<int32_t>(internal_id);
    }

    return ANIGMA_OK;
}

anigma_status_t anigma_vector_index_capsule_search(
    anigma_vector_index_capsule_t* handle,
    const float* query_vector,
    uint32_t k,
    uint64_t* out_ids,
    float* out_distances,
    uint32_t* out_count,
    anigma_capsule_error_t* error
) {
    std::lock_guard<std::mutex> lock(handle->mutex);

    if (handle->entry_point == -1) {
        if (out_count != nullptr) *out_count = 0;
        return ANIGMA_OK;
    }

    int32_t curr_ep = handle->entry_point;
    int cur_l = handle->max_layer;

    // Search upper layers
    for (; cur_l > 0; --cur_l) {
        bool changed = true;
        float curr_dist = l2_distance(query_vector, handle->nodes[static_cast<size_t>(curr_ep)].vector.data(), handle->config.dimension);
        while (changed) {
            changed = false;
            for (uint32_t neighbor : handle->nodes[static_cast<size_t>(curr_ep)].neighbors[static_cast<size_t>(cur_l)]) {
                float d = l2_distance(query_vector, handle->nodes[neighbor].vector.data(), handle->config.dimension);
                if (d < curr_dist) {
                    curr_dist = d;
                    curr_ep = static_cast<int32_t>(neighbor);
                    changed = true;
                }
            }
        }
    }

    // Final layer search
    std::priority_queue<std::pair<float, uint32_t>> candidates;
    candidates.emplace(-l2_distance(query_vector, handle->nodes[static_cast<size_t>(curr_ep)].vector.data(), handle->config.dimension), static_cast<uint32_t>(curr_ep));
    
    std::set<uint32_t> visited;
    visited.insert(static_cast<uint32_t>(curr_ep));
    
    std::priority_queue<std::pair<float, uint32_t>> top_k;

    while (!candidates.empty()) {
        auto curr = candidates.top();
        candidates.pop();
        float d = -curr.first;
        
        if (!top_k.empty() && d > -top_k.top().first && top_k.size() >= handle->config.ef_search) break;

        top_k.push(curr);
        if (top_k.size() > handle->config.ef_search) top_k.pop();

        for (uint32_t neighbor : handle->nodes[curr.second].neighbors[0]) {
            if (visited.find(neighbor) == visited.end()) {
                visited.insert(neighbor);
                float d_n = l2_distance(query_vector, handle->nodes[neighbor].vector.data(), handle->config.dimension);
                candidates.emplace(-d_n, neighbor);
            }
        }
    }

    // Extract results
    std::vector<std::pair<float, uint64_t>> results;
    while (!top_k.empty()) {
        results.push_back({-top_k.top().first, handle->nodes[top_k.top().second].external_id});
        top_k.pop();
    }
    std::reverse(results.begin(), results.end());

    uint32_t count = std::min(static_cast<uint32_t>(results.size()), k);
    for (uint32_t i = 0; i < count; ++i) {
        out_ids[i] = results[i].second;
        out_distances[i] = results[i].first;
    }
    if (out_count != nullptr) *out_count = count;

    return ANIGMA_OK;
}

anigma_status_t anigma_vector_index_capsule_search_pool(
    anigma_vector_index_capsule_t* handle,
    const float* query_vector,
    const uint64_t* candidate_ids,
    size_t candidate_count,
    uint32_t k,
    uint64_t* out_ids,
    float* out_distances,
    uint32_t* out_count,
    anigma_capsule_error_t* error
) {
    std::lock_guard<std::mutex> lock(handle->mutex);

    // Two-stage funnel: Brute force within the limited pool (which should be small)
    std::vector<std::pair<float, uint64_t>> results;
    for (size_t i = 0; i < candidate_count; ++i) {
        auto it = handle->id_map.find(candidate_ids[i]);
        if (it != handle->id_map.end()) {
            float d = l2_distance(query_vector, handle->nodes[it->second].vector.data(), handle->config.dimension);
            results.push_back({d, candidate_ids[i]});
        }
    }

    std::sort(results.begin(), results.end());
    uint32_t count = std::min(static_cast<uint32_t>(results.size()), k);
    for (uint32_t i = 0; i < count; ++i) {
        out_ids[i] = results[i].second;
        out_distances[i] = results[i].first;
    }
    if (out_count != nullptr) *out_count = count;

    return ANIGMA_OK;
}

uint32_t anigma_vector_index_capsule_get_count(anigma_vector_index_capsule_t* handle) {
    std::lock_guard<std::mutex> lock(handle->mutex);
    return static_cast<uint32_t>(handle->nodes.size());
}

anigma_status_t anigma_vector_index_capsule_clear(
    anigma_vector_index_capsule_t* handle,
    anigma_capsule_error_t* error
) {
    std::lock_guard<std::mutex> lock(handle->mutex);
    handle->nodes.clear();
    handle->id_map.clear();
    handle->entry_point = -1;
    handle->max_layer = -1;
    return ANIGMA_OK;
}

anigma_status_t anigma_vector_index_capsule_save(anigma_vector_index_capsule_t* handle, const char* path, anigma_capsule_error_t* error) {
    std::lock_guard<std::mutex> lock(handle->mutex);
    FILE* f = fopen(path, "wb");
    if (!f) {
        if (error) { error->code = ANIGMA_ERR_IO; error->message = "Failed to open file for writing"; }
        return ANIGMA_ERR_IO;
    }
    
    // Header
    uint32_t count = static_cast<uint32_t>(handle->nodes.size());
    fwrite(&handle->config.dimension, sizeof(uint32_t), 1, f);
    fwrite(&count, sizeof(uint32_t), 1, f);
    fwrite(&handle->entry_point, sizeof(int32_t), 1, f);
    fwrite(&handle->max_layer, sizeof(int32_t), 1, f);
    
    // Nodes
    for (const auto& node : handle->nodes) {
        fwrite(&node.external_id, sizeof(uint64_t), 1, f);
        fwrite(node.vector.data(), sizeof(float), handle->config.dimension, f);
        uint32_t layer_count = static_cast<uint32_t>(node.neighbors.size());
        fwrite(&layer_count, sizeof(uint32_t), 1, f);
        for (const auto& layer : node.neighbors) {
            uint32_t neighbor_count = static_cast<uint32_t>(layer.size());
            fwrite(&neighbor_count, sizeof(uint32_t), 1, f);
            fwrite(layer.data(), sizeof(uint32_t), neighbor_count, f);
        }
    }
    
    fclose(f);
    return ANIGMA_OK;
}

anigma_status_t anigma_vector_index_capsule_load(anigma_vector_index_capsule_t* handle, const char* path, anigma_capsule_error_t* error) {
    std::lock_guard<std::mutex> lock(handle->mutex);
    FILE* f = fopen(path, "rb");
    if (!f) {
        if (error) { error->code = ANIGMA_ERR_IO; error->message = "Failed to open file for reading"; }
        return ANIGMA_ERR_IO;
    }
    
    handle->nodes.clear();
    handle->id_map.clear();
    
    uint32_t dim, count;
    fread(&dim, sizeof(uint32_t), 1, f);
    if (dim != handle->config.dimension) {
        fclose(f);
        if (error) { error->code = ANIGMA_ERR_VERSION_MISMATCH; error->message = "Dimension mismatch"; }
        return ANIGMA_ERR_VERSION_MISMATCH;
    }
    
    fread(&count, sizeof(uint32_t), 1, f);
    fread(&handle->entry_point, sizeof(int32_t), 1, f);
    fread(&handle->max_layer, sizeof(int32_t), 1, f);
    
    handle->nodes.resize(count);
    for (uint32_t i = 0; i < count; ++i) {
        auto& node = handle->nodes[i];
        fread(&node.external_id, sizeof(uint64_t), 1, f);
        node.vector.resize(dim);
        fread(node.vector.data(), sizeof(float), dim, f);
        uint32_t layer_count;
        fread(&layer_count, sizeof(uint32_t), 1, f);
        node.neighbors.resize(layer_count);
        for (uint32_t l = 0; l < layer_count; ++l) {
            uint32_t neighbor_count;
            fread(&neighbor_count, sizeof(uint32_t), 1, f);
            node.neighbors[l].resize(neighbor_count);
            fread(node.neighbors[l].data(), sizeof(uint32_t), neighbor_count, f);
        }
        handle->id_map[node.external_id] = i;
    }
    
    fclose(f);
    return ANIGMA_OK;
}

anigma_status_t anigma_vector_index_capsule_add_vectors(anigma_vector_index_capsule_t* handle, const uint64_t* ids, const float* vectors, size_t count, anigma_capsule_error_t* error) {
    for (size_t i = 0; i < count; ++i) {
        anigma_status_t status = anigma_vector_index_capsule_add_vector(handle, ids[i], vectors + i * handle->config.dimension, error);
        if (status != ANIGMA_OK) return status;
    }
    return ANIGMA_OK;
}

} // extern "C"
