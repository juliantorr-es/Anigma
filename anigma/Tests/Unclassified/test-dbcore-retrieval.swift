import Foundation
import DatabaseCore

// Test just DatabaseCore retrieval system
print("Testing DatabaseCore retrieval system...")

// Test RetrievalRequest
let request = RetrievalRequest(
    query: "test query",
    mode: .lexical,
    limit: 5
)

print("✅ RetrievalRequest created: \(request.query)")

// Test RetrievalHit - using memberwise init
let hit = RetrievalHit(
    chunkID: "test-chunk-123",
    sourcePath: "/test/file.swift",
    sectionTitle: "Test Section",
    contentHashSHA256: "abcdef123456",
    score: 0.95,
    source: RetrievalSource.fts
)

print("✅ RetrievalHit created: \(hit.chunkID)")

// Test Hashing
let hash = Hashing.sha256Hex("test string")
print("✅ Hashing works: \(hash)")

print("\n🎉 DatabaseCore retrieval system test complete!")
