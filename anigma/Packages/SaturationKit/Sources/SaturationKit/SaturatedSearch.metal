#include <metal_stdlib>
using namespace metal;

struct SaturatedHeartbeatPacket {
    uchar missionID[16];
    uint32_t packetType;
    uint32_t sequence;
    uchar payloadHash[32];
    uint64_t timestamp;
};

struct SaturatedLoggingRingMetadata {
    uint32_t producerIndex;
    uint32_t consumerIndex;
    uint32_t ringSize;
    uint32_t statusBits;
    uint32_t padding[4];
};

// MARK: - Kernels

kernel void saturated_vector_search(
    device const float* query [[buffer(0)]],
    device const float* candidates [[buffer(1)]],
    device float* similarityScores [[buffer(2)]],
    device uint32_t* selectedIndices [[buffer(3)]],
    device atomic_uint* selectedCount [[buffer(4)]],
    device SaturatedLoggingRingMetadata* ringMetadata [[buffer(5)]],
    device SaturatedHeartbeatPacket* ringPackets [[buffer(6)]],
    device const uchar* heartbeatPayloadHash [[buffer(7)]],
    constant uint& dimension [[buffer(8)]],
    constant float& threshold [[buffer(9)]],
    constant uint& candidateCount [[buffer(10)]],
    uint id [[thread_position_in_grid]]
) {
    // 1. Compute Dot Product
    float dotProduct = 0.0;
    float queryMagSq = 0.0;
    float candMagSq = 0.0;
    
    for (uint i = 0; i < dimension; i++) {
        float q = query[i];
        float c = candidates[i * candidateCount + id];
        dotProduct += q * c;
        queryMagSq += q * q;
        candMagSq += c * c;
    }
    
    float similarity = 0.0;
    if (queryMagSq > 0 && candMagSq > 0) {
        similarity = dotProduct / (sqrt(queryMagSq) * sqrt(candMagSq));
    }
    
    similarityScores[id] = similarity;
    
    // 2. Threshold Check & Selection
    if (similarity > threshold) {
        uint index = atomic_fetch_add_explicit(selectedCount, 1, memory_order_relaxed);
        selectedIndices[index] = id;
        
        // 3. Telemetry Capture (Heartbeat)
        // Note: In a real ICB, we'd use atomics on producerIndex to safely append.
        // For the P1 prototype, we simulate a simple push if space is available.
        uint32_t currentProducer = atomic_fetch_add_explicit((device atomic_uint*)&ringMetadata->producerIndex, 1, memory_order_relaxed);
        uint32_t ringSize = ringMetadata->ringSize;
        
        if (currentProducer - ringMetadata->consumerIndex < ringSize) {
            uint slot = currentProducer % ringSize;
            device SaturatedHeartbeatPacket& packet = ringPackets[slot];
            packet.packetType = 2; // Heartbeat
            packet.timestamp = 123456789; // Placeholder for GPU timestamp
            for (uint i = 0; i < 32; i++) {
                packet.payloadHash[i] = heartbeatPayloadHash[i];
            }
        }
    }
}
