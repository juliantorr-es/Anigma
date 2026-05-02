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

        let artifactPath = URL(fileURLWithPath: model.installPath ?? model.sourceLocation)

        guard FileManager.default.fileExists(atPath: artifactPath.path) else {
            print("❌ Model artifact not found at: \(artifactPath.path)")
            return false
        }

        let computedHashes = try computeHashes(at: artifactPath)
        let legacyHashes = try computeLegacyHashes(at: artifactPath)
        let computedManifestHash = ArtifactHashing.manifestHash(from: computedHashes)
        let legacyManifestHash = ArtifactHashing.legacyManifestHash(from: legacyHashes)
        let storedManifestHash = ArtifactHashing.manifestHash(from: model.artifactHashes)
        let legacyStoredManifestHash = ArtifactHashing.legacyManifestHash(from: model.artifactHashes)

        let isValid =
            (computedHashes == model.artifactHashes && computedManifestHash == storedManifestHash && storedManifestHash == model.artifactHash)
            || (legacyHashes == model.artifactHashes && legacyManifestHash == legacyStoredManifestHash && legacyStoredManifestHash == model.artifactHash)

        if isValid {
            print("✅ Model \(modelId) integrity verified")
        } else {
            print("❌ Model \(modelId) integrity check FAILED")
            print("   Expected: \(model.artifactHash)")
            print("   Computed: \(computedManifestHash)")
        }

        return isValid
    }

    private func computeHashes(at url: URL) throws -> [String: String] {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return [:]
        }

        if isDirectory.boolValue {
            var hashes: [String: String] = [:]
            let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
            while let fileURL = enumerator?.nextObject() as? URL {
                let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                guard values.isRegularFile == true else { continue }
                let data = try Data(contentsOf: fileURL)
                let relativePath = fileURL.path.replacingOccurrences(of: url.path + "/", with: "")
                hashes[relativePath] = ArtifactHashing.hardwareBackedHex(for: data)
            }
            return hashes
        }

        let data = try Data(contentsOf: url)
        return [url.lastPathComponent: ArtifactHashing.hardwareBackedHex(for: data)]
    }

    private func computeLegacyHashes(at url: URL) throws -> [String: String] {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return [:]
        }

        if isDirectory.boolValue {
            var hashes: [String: String] = [:]
            let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
            while let fileURL = enumerator?.nextObject() as? URL {
                let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                guard values.isRegularFile == true else { continue }
                let data = try Data(contentsOf: fileURL)
                let relativePath = fileURL.path.replacingOccurrences(of: url.path + "/", with: "")
                hashes[relativePath] = ArtifactHashing.legacyHex(for: data)
            }
            return hashes
        }

        let data = try Data(contentsOf: url)
        return [url.lastPathComponent: ArtifactHashing.legacyHex(for: data)]
    }
}
