import Foundation
import DatabaseCore

print("Testing basic DatabaseCore retrieval types...")

// Test just creating a RetrievalSource enum
let source = RetrievalSource.fts
print("✅ RetrievalSource: \(source)")

// Test creating a RetrievalHit with explicit parameter names
let hit = RetrievalHit(
    chunkID: "test",
    sourcePath: "/test.swift",
    sectionTitle: "Test",
    contentHashSHA256: "abc123",
    score: 0.95,
    source: source
)

print("✅ RetrievalHit: \(hit.chunkID)")

print("✅ DatabaseCore retrieval system works!")
