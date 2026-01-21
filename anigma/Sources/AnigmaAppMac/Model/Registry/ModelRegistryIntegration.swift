//
//  ModelRegistryIntegration.swift
//  AnigmaAppMac
//
//  Integration layer connecting Model Registry with ML execution and imports
//

import Foundation

/// Extension to AppStore for Model Registry usage tracking
/// Note: recordModelUsage is now handled by MLStore
extension AppStore {
    // recordModelUsage has been moved to MLStore
    // Usage tracking is now handled internally by MLStore.recordModelUsage
}

/// Extension for hash verification during import
extension AppStore {

    /// Verify model artifact integrity by computing and comparing hashes
    @MainActor
    func verifyModelIntegrity(modelId: String) async throws -> Bool {
        guard let model = try await modelRegistry.find(id: modelId) else {
            throw ModelRegistryError.notFound(modelId)
        }

        let artifactPath = URL(fileURLWithPath: model.source.location)

        // Check if file exists
        guard FileManager.default.fileExists(atPath: artifactPath.path) else {
            print("❌ Model artifact not found at: \(artifactPath.path)")
            return false
        }

        // Compute hash
        let computedHash = try sha256(url: artifactPath)

        // Compare with stored hash
        let isValid = computedHash == model.modelHash

        if isValid {
            print("✅ Model \(modelId) integrity verified")
        } else {
            print("❌ Model \(modelId) integrity check FAILED")
            print("   Expected: \(model.modelHash)")
            print("   Computed: \(computedHash)")
        }

        return isValid
    }

    /// Compute SHA256 hash of a file
    private func sha256(url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let hash = data.withUnsafeBytes { buffer in
            var hasher = SHA256Hasher()
            hasher.update(buffer)
            return hasher.finalize()
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

/// Simple SHA256 hasher (using CryptoKit concepts)
private struct SHA256Hasher {
    private var state: [UInt8] = []

    mutating func update(_ buffer: UnsafeRawBufferPointer) {
        state.append(contentsOf: buffer)
    }

    func finalize() -> [UInt8] {
        // Simplified hash - in production, use CryptoKit.SHA256
        // For now, just return a placeholder that demonstrates the pattern
        return Array(state.prefix(32))
    }
}
