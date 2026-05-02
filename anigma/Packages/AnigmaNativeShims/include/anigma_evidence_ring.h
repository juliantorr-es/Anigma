#ifndef ANIGMA_EVIDENCE_RING_H
#define ANIGMA_EVIDENCE_RING_H

#include <stdint.h>
#include <stddef.h>

#if defined(__cplusplus)
extern "C" {
#endif

/**
 * Metadata for the mmap-backed evidence ring.
 * Mirrors Swift SaturatedLoggingRingMetadata layout.
 */
typedef struct {
    uint32_t producer_index;
    uint32_t consumer_index;
    uint32_t ring_size;
    uint32_t status_bits;
    uint8_t reserved[16];
} anigma_evidence_ring_metadata_t;

/**
 * A single evidence packet (heartbeat) in the ring.
 * Mirrors Swift SaturatedHeartbeatPacket layout.
 */
typedef struct {
    uint8_t mission_id[16];   // UUID
    uint32_t packet_type;     // 1=start, 2=heartbeat, 3=end, 4=violation
    uint32_t sequence;
    uint8_t payload_hash[32]; // Blake3 hash of operation
    uint64_t timestamp;
    float power_watts;
    float ops_per_joule;
} anigma_evidence_packet_t;

/**
 * The Evidence Ring descriptor.
 * Pointers must point into shared mmap-backed memory.
 */
typedef struct {
    anigma_evidence_ring_metadata_t* metadata;
    anigma_evidence_packet_t* packets;
} anigma_evidence_ring_t;

#if defined(__cplusplus)
}
#endif

#endif // ANIGMA_EVIDENCE_RING_H
