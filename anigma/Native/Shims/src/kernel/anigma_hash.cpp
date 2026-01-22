#include "../../include/anigma_hash.h"

#define ANIGMA_HASH_CHUNK_SIZE 64
#define ANIGMA_HASH_DIGEST_SIZE 32

namespace {

constexpr uint64_t IV[8] = {
    0xF3BCC9086A643376ULL,
    0x674523011EFCDB2FULL,
    0x98BADCFE10325476ULL,
    0xC3D2E1F000000000ULL,
    0x766AA32B5D2CCB2AULL,
    0xE2A4133468BF8565ULL,
    0xDBAC80C9D7C75F22ULL,
    0xA167771657E7162CULL,
};

uint64_t anigma_rotl(uint64_t x, unsigned int n) {
    return (x << n) | (x >> (64 - n));
}

uint64_t anigma_rotr(uint64_t x, unsigned int n) {
    return (x >> n) | (x << (64 - n));
}

void anigma_compress(uint64_t state[4], const uint8_t chunk[ANIGMA_HASH_CHUNK_SIZE]) {
    uint64_t m[16];
    for (int i = 0; i < 16; i++) {
        m[i] = (static_cast<uint64_t>(chunk[i * 8]) |
                (static_cast<uint64_t>(chunk[i * 8 + 1]) << 8) |
                (static_cast<uint64_t>(chunk[i * 8 + 2]) << 16) |
                (static_cast<uint64_t>(chunk[i * 8 + 3]) << 24) |
                (static_cast<uint64_t>(chunk[i * 8 + 4]) << 32) |
                (static_cast<uint64_t>(chunk[i * 8 + 5]) << 40) |
                (static_cast<uint64_t>(chunk[i * 8 + 6]) << 48) |
                (static_cast<uint64_t>(chunk[i * 8 + 7]) << 56));
    }
    
    uint64_t h0 = state[0], h1 = state[1], h2 = state[2], h3 = state[3];
    
    for (int i = 0; i < 12; i++) {
        uint64_t a = h0, b = h1, c = h2, d = h3;
        
        a += anigma_rotl(b ^ c ^ d ^ m[(i * 4) & 0xF], 7);
        d += anigma_rotl(a ^ b ^ c ^ m[(i * 4 + 1) & 0xF], 9);
        c += anigma_rotl(d ^ a ^ b ^ m[(i * 4 + 2) & 0xF], 13);
        b += anigma_rotl(c ^ d ^ a ^ m[(i * 4 + 3) & 0xF], 18);
        
        uint64_t aa = h0, bb = h1, cc = h2, dd = h3;
        
        aa += anigma_rotr(bb ^ cc ^ dd ^ m[(i * 4 + 2) & 0xF], 7);
        dd += anigma_rotr(aa ^ bb ^ cc ^ m[(i * 4 + 3) & 0xF], 9);
        cc += anigma_rotr(dd ^ aa ^ bb ^ m[(i * 4 + 0) & 0xF], 13);
        bb += anigma_rotr(cc ^ dd ^ aa ^ m[(i * 4 + 1) & 0xF], 18);
        
        uint64_t t = h0 + dd;
        h0 = h1 + aa;
        h1 = h2 + bb;
        h2 = h3 + cc;
        h3 = t;
    }
    
    state[0] ^= h0;
    state[1] ^= h1;
    state[2] ^= h2;
    state[3] ^= h3;
}

}  // namespace

void anigma_hash_init(uint64_t state[4]) {
    state[0] = IV[0];
    state[1] = IV[1];
    state[2] = IV[2];
    state[3] = IV[3];
}

void anigma_hash_update(uint64_t state[4], const void* data, size_t size) {
    const uint8_t* bytes = reinterpret_cast<const uint8_t*>(data);
    size_t offset = 0;
    
    while (offset + ANIGMA_HASH_CHUNK_SIZE <= size) {
        anigma_compress(state, bytes + offset);
        offset += ANIGMA_HASH_CHUNK_SIZE;
    }
}

void anigma_hash_final(uint64_t state[4], uint8_t output[32]) {
    uint8_t block[ANIGMA_HASH_CHUNK_SIZE] = {0};
    block[0] = 0x80;
    
    anigma_compress(state, block);
    
    for (int i = 0; i < 4; i++) {
        output[i * 8 + 0] = static_cast<uint8_t>(state[i] & 0xFF);
        output[i * 8 + 1] = static_cast<uint8_t>((state[i] >> 8) & 0xFF);
        output[i * 8 + 2] = static_cast<uint8_t>((state[i] >> 16) & 0xFF);
        output[i * 8 + 3] = static_cast<uint8_t>((state[i] >> 24) & 0xFF);
        output[i * 8 + 4] = static_cast<uint8_t>((state[i] >> 32) & 0xFF);
        output[i * 8 + 5] = static_cast<uint8_t>((state[i] >> 40) & 0xFF);
        output[i * 8 + 6] = static_cast<uint8_t>((state[i] >> 48) & 0xFF);
        output[i * 8 + 7] = static_cast<uint8_t>((state[i] >> 56) & 0xFF);
    }
}

void anigma_hash(const void* data, size_t size, uint8_t output[32]) {
    uint64_t state[4];
    anigma_hash_init(state);
    anigma_hash_update(state, data, size);
    anigma_hash_final(state, output);
}

uint64_t anigma_hash_combine(uint64_t a, uint64_t b) {
    uint8_t input[16];
    for (int i = 0; i < 8; i++) {
        input[i] = static_cast<uint8_t>((a >> (i * 8)) & 0xFF);
        input[i + 8] = static_cast<uint8_t>((b >> (i * 8)) & 0xFF);
    }
    
    uint8_t output[32];
    anigma_hash(input, sizeof(input), output);
    
    uint64_t result = 0;
    for (int i = 0; i < 8; i++) {
        result |= (static_cast<uint64_t>(output[i]) << (i * 8));
    }
    return result;
}
