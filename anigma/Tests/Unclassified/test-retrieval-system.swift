#!/usr/bin/env swift

import Foundation
import DatabaseCore
import HarmoniaModule

// Test the retrieval system compilation and basic functionality
print("Testing retrieval system...")

// Test RetrievalRequest
let request = RetrievalRequest(
    query: "test query",
    mode: .lexical,
    limit: 5
)

print("✅ RetrievalRequest created: \(request.query)")

// Test RetrievalHit
let hit = RetrievalHit(
    chunkID: "test-chunk-123",
    sourcePath: "/test/file.swift",
    sectionTitle: "Test Section",
    contentHashSHA256: "abcdef123456",
    score: 0.95,
    source: RetrievalSource.fts
)

print("✅ RetrievalHit created: \(hit.chunkID)")

// Test RetrievalLoopSignature
let signature = RetrievalLoopSignature(
    queryHash: "query123",
    mode: "lexical",
    pathPrefix: "/test",
    limit: 10,
    resultHash: "result456"
)

print("✅ RetrievalLoopSignature created: \(signature.queryHash)")

// Test DatabaseParameter adapters
let params: [DatabaseParameter] = [
    dbp("test"),
    dbp(42),
    dbp(3.14),
    dbp(nil as String?)
]

print("✅ DatabaseParameter adapters work: \(params.count) parameters")

// Test Hashing
let hash = Hashing.sha256Hex("test string")
print("✅ Hashing works: \(hash)")

print("\n🎉 Retrieval system test complete!")
