#include "anigma_vector_index_capsule.h"

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <limits>
#include <new>
#include <unordered_map>
#include <utility>
#include <vector>

namespace {

struct VectorIndexState {
    uint32_t dimension;
    uint32_t max_elements;
    uint32_t M;
    uint32_t ef_construction;
    uint32_t ef_search;
    bool allow_replace_deleted;
    std::unordered_map<uint64_t, std::vector<float>> vectors;

    explicit VectorIndexState(const anigma_vector_index_config_t* config)
        : dimension(config ? config->dimension : 0),
          max_elements(config ? config->max_elements : 0),
          M(config ? config->M : 0),
          ef_construction(config ? config->ef_construction : 0),
          ef_search(config ? config->ef_search : 0),
          allow_replace_deleted(config ? config->allow_replace_deleted != 0 : false) {}
};

struct ScoredVector {
    uint64_t id;
    float similarity;
    float distance;
};

static void set_error(
    anigma_capsule_error_t* err,
    anigma_status_t code,
    const char* message
) {
    if (!err) {
        return;
    }
    err->code = code;
    err->message = message;
    err->detail = nullptr;
    err->aux = 0;
}

static bool validate_vector(const VectorIndexState* state, const float* vector, anigma_capsule_error_t* err) {
    if (!state || !vector) {
        set_error(err, ANIGMA_ERR_INVALID_ARG, "Invalid vector index argument");
        return false;
    }
    if (state->dimension == 0) {
        set_error(err, ANIGMA_ERR_INVALID_ARG, "Vector dimension must be greater than zero");
        return false;
    }
    return true;
}

static float saturated_cosine_similarity(const std::vector<float>& query, const std::vector<float>& candidate) {
    if (query.size() != candidate.size() || query.empty()) {
        return 0.0f;
    }

    double dot = 0.0;
    double query_norm_sq = 0.0;
    double candidate_norm_sq = 0.0;

    for (size_t i = 0; i < query.size(); ++i) {
        const double q = static_cast<double>(query[i]);
        const double c = static_cast<double>(candidate[i]);
        dot += q * c;
        query_norm_sq += q * q;
        candidate_norm_sq += c * c;
    }

    if (query_norm_sq <= 0.0 || candidate_norm_sq <= 0.0) {
        return 0.0f;
    }

    const double denom = std::sqrt(query_norm_sq) * std::sqrt(candidate_norm_sq);
    if (denom <= 0.0) {
        return 0.0f;
    }

    const double similarity = dot / denom;
    return static_cast<float>(std::clamp(similarity, 0.0, 1.0));
}

static std::vector<ScoredVector> rank_candidates(
    const VectorIndexState* state,
    const std::vector<float>& query,
    const std::vector<uint64_t>* candidate_ids
) {
    std::vector<ScoredVector> scored;
    if (!state || query.size() != state->dimension) {
        return scored;
    }

    scored.reserve(candidate_ids ? candidate_ids->size() : state->vectors.size());

    auto score_one = [&](uint64_t id, const std::vector<float>& candidate) {
        const float similarity = saturated_cosine_similarity(query, candidate);
        scored.push_back(ScoredVector{
            id,
            similarity,
            static_cast<float>(1.0f - similarity)
        });
    };

    if (candidate_ids) {
        for (uint64_t id : *candidate_ids) {
            const auto it = state->vectors.find(id);
            if (it != state->vectors.end() && it->second.size() == state->dimension) {
                score_one(id, it->second);
            }
        }
    } else {
        for (const auto& entry : state->vectors) {
            if (entry.second.size() == state->dimension) {
                score_one(entry.first, entry.second);
            }
        }
    }

    std::sort(
        scored.begin(),
        scored.end(),
        [](const ScoredVector& a, const ScoredVector& b) {
            if (a.distance != b.distance) {
                return a.distance < b.distance;
            }
            return a.id < b.id;
        }
    );

    return scored;
}

static anigma_status_t write_ranked_results(
    const std::vector<ScoredVector>& scored,
    uint32_t k,
    uint64_t* out_ids,
    float* out_distances,
    uint32_t* out_count
) {
    if (!out_count) {
        return ANIGMA_ERR_INVALID_ARG;
    }
    if (k > 0 && (!out_ids || !out_distances)) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    const uint32_t count = static_cast<uint32_t>(std::min<size_t>(scored.size(), k));
    for (uint32_t i = 0; i < count; ++i) {
        out_ids[i] = scored[i].id;
        out_distances[i] = scored[i].distance;
    }
    *out_count = count;
    return ANIGMA_OK;
}

} // namespace

extern "C" {

anigma_capsule_identity_t anigma_vector_index_capsule_get_identity(void) {
    static const char* capsule_id = "vector_index_capsule";
    static const char* build_hash = "v1.1.0-saturated-search";
    static const char* algo_version = "1.1";

    return (anigma_capsule_identity_t) {
        .capsule_id = capsule_id,
        .build_hash = build_hash,
        .algo_version = algo_version,
        .determinism_tier = ANIGMA_DETERMINISM_TIER_2_CANONICAL_BOUNDARY
    };
}

anigma_status_t anigma_vector_index_capsule_create(
    const anigma_vector_index_config_t* config,
    anigma_vector_index_capsule_t* out_handle,
    anigma_capsule_error_t* err
) {
    if (!config || !out_handle || config->dimension == 0) {
        set_error(err, ANIGMA_ERR_INVALID_ARG, "Invalid vector index configuration");
        return ANIGMA_ERR_INVALID_ARG;
    }

    auto* state = new (std::nothrow) VectorIndexState(config);
    if (!state) {
        set_error(err, ANIGMA_ERR_OUT_OF_MEMORY, "Failed to allocate vector index state");
        return ANIGMA_ERR_OUT_OF_MEMORY;
    }

    *out_handle = static_cast<anigma_vector_index_capsule_t>(state);
    return ANIGMA_OK;
}

void anigma_vector_index_capsule_destroy(anigma_vector_index_capsule_t* handle) {
    if (!handle || !*handle) {
        return;
    }
    delete static_cast<VectorIndexState*>(*handle);
    *handle = nullptr;
}

anigma_status_t anigma_vector_index_capsule_add_vector(
    anigma_vector_index_capsule_t handle,
    uint64_t id,
    const float* vector,
    anigma_capsule_error_t* error
) {
    auto* state = static_cast<VectorIndexState*>(handle);
    if (!validate_vector(state, vector, error)) {
        return error ? error->code : ANIGMA_ERR_INVALID_ARG;
    }

    std::vector<float> copy(vector, vector + state->dimension);
    const bool exists = state->vectors.find(id) != state->vectors.end();
    if (!exists && state->vectors.size() >= state->max_elements && state->max_elements != 0) {
        set_error(error, ANIGMA_STATUS_OUT_OF_BOUNDS, "Vector index capacity reached");
        return ANIGMA_STATUS_OUT_OF_BOUNDS;
    }

    state->vectors[id] = std::move(copy);
    return ANIGMA_OK;
}

anigma_status_t anigma_vector_index_capsule_add_vectors(
    anigma_vector_index_capsule_t handle,
    const uint64_t* ids,
    const float* vectors,
    size_t count,
    anigma_capsule_error_t* error
) {
    auto* state = static_cast<VectorIndexState*>(handle);
    if (!state || (!ids && count > 0) || (!vectors && count > 0)) {
        set_error(error, ANIGMA_ERR_INVALID_ARG, "Invalid vector batch arguments");
        return ANIGMA_ERR_INVALID_ARG;
    }

    for (size_t i = 0; i < count; ++i) {
        const float* vector = vectors + (i * state->dimension);
        anigma_status_t status = anigma_vector_index_capsule_add_vector(handle, ids[i], vector, error);
        if (status != ANIGMA_OK) {
            return status;
        }
    }

    return ANIGMA_OK;
}

anigma_status_t anigma_vector_index_capsule_search(
    anigma_vector_index_capsule_t handle,
    const float* query_vector,
    uint32_t k,
    uint64_t* out_ids,
    float* out_distances,
    uint32_t* out_count,
    anigma_capsule_error_t* error
) {
    auto* state = static_cast<VectorIndexState*>(handle);
    if (!validate_vector(state, query_vector, error)) {
        return error ? error->code : ANIGMA_ERR_INVALID_ARG;
    }

    std::vector<float> query(query_vector, query_vector + state->dimension);
    const auto scored = rank_candidates(state, query, nullptr);
    anigma_status_t status = write_ranked_results(scored, k, out_ids, out_distances, out_count);
    if (status != ANIGMA_OK) {
        set_error(error, status, "Invalid search output buffers");
    }
    return status;
}

anigma_status_t anigma_vector_index_capsule_search_pool(
    anigma_vector_index_capsule_t handle,
    const float* query_vector,
    const uint64_t* candidate_ids,
    size_t candidate_count,
    uint32_t k,
    uint64_t* out_ids,
    float* out_distances,
    uint32_t* out_count,
    anigma_capsule_error_t* error
) {
    auto* state = static_cast<VectorIndexState*>(handle);
    if (!validate_vector(state, query_vector, error) || (candidate_count > 0 && !candidate_ids)) {
        if (candidate_count > 0 && !candidate_ids) {
            set_error(error, ANIGMA_ERR_INVALID_ARG, "Candidate IDs are required");
        }
        return error ? error->code : ANIGMA_ERR_INVALID_ARG;
    }

    std::vector<float> query(query_vector, query_vector + state->dimension);
    std::vector<uint64_t> candidates;
    candidates.reserve(candidate_count);
    for (size_t i = 0; i < candidate_count; ++i) {
        candidates.push_back(candidate_ids[i]);
    }

    const auto scored = rank_candidates(state, query, &candidates);
    anigma_status_t status = write_ranked_results(scored, k, out_ids, out_distances, out_count);
    if (status != ANIGMA_OK) {
        set_error(error, status, "Invalid search output buffers");
    }
    return status;
}

anigma_status_t anigma_vector_index_capsule_save(
    anigma_vector_index_capsule_t handle,
    const char* path,
    anigma_capsule_error_t* error
) {
    (void)handle;
    (void)path;
    set_error(error, ANIGMA_ERR_NOT_IMPLEMENTED, "Vector index persistence is not implemented");
    return ANIGMA_ERR_NOT_IMPLEMENTED;
}

anigma_status_t anigma_vector_index_capsule_load(
    anigma_vector_index_capsule_t handle,
    const char* path,
    anigma_capsule_error_t* error
) {
    (void)handle;
    (void)path;
    set_error(error, ANIGMA_ERR_NOT_IMPLEMENTED, "Vector index persistence is not implemented");
    return ANIGMA_ERR_NOT_IMPLEMENTED;
}

uint32_t anigma_vector_index_capsule_get_count(anigma_vector_index_capsule_t handle) {
    auto* state = static_cast<VectorIndexState*>(handle);
    return state ? static_cast<uint32_t>(state->vectors.size()) : 0;
}

// Zero-copy bulk vector retrieval for GPU processing
// Uses unified memory - no data copy needed on Apple Silicon
uint32_t anigma_vector_index_capsule_get_all_vectors(
    anigma_vector_index_capsule_t handle,
    float* out_vectors,
    uint32_t max_vectors
) {
    auto* state = static_cast<VectorIndexState*>(handle);
    if (!state || !out_vectors) {
        return 0;
    }
    
    uint32_t count = std::min(static_cast<uint32_t>(state->vectors.size()), max_vectors);
    uint32_t dim = state->dimension;
    
    // Iterate through the map and copy vectors to output buffer
    uint32_t idx = 0;
    for (const auto& kv : state->vectors) {
        if (idx >= count) break;
        const auto& vector = kv.second;
        if (vector.size() == dim) {
            std::memcpy(out_vectors + (idx * dim), vector.data(), dim * sizeof(float));
            idx++;
        }
    }
    
    return idx;
}

anigma_status_t anigma_vector_index_capsule_clear(
    anigma_vector_index_capsule_t handle,
    anigma_capsule_error_t* error
) {
    auto* state = static_cast<VectorIndexState*>(handle);
    if (!state) {
        set_error(error, ANIGMA_ERR_INVALID_ARG, "Invalid handle");
        return ANIGMA_ERR_INVALID_ARG;
    }

    state->vectors.clear();
    return ANIGMA_OK;
}

} // extern "C"
