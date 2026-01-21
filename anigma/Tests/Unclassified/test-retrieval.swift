import Foundation
import DatabaseCore

// Simple test to verify retrieval system compiles
func testRetrievalSystem() {
    let request = RetrievalRequest(
        query: "test query",
        mode: .lexical,
        limit: 10
    )

    let hit = RetrievalHit(
        chunkID: "test-chunk",
        sourcePath: "/test/path",
        sectionTitle: "Test Section",
        contentHashSHA256: "abc123",
        score: 0.95,
        source: .fts
    )

    print("Retrieval system compiles successfully")
    print("Request: \(request.query)")
    print("Hit: \(hit.chunkID)")
}
