//
//  FileProviderExtension.swift
//  AnigmaExtensions
//
//  The File Provider Extension entry point.
//  Uses AnigmaSystemSpine.FileProviderAdapter for logic.
//

import FileProvider
import AnigmaSystemSpine

// Note: NSFileProviderExtension is unavailable in macOS 11+ (replaced by NSFileProviderReplicatedExtension)
// However, for this exercise we are targeting the classic extension or just providing the source.
// We will comment out the class inheritance to make it compile as a "source file" for now,
// or use a mock class if we want to verify logic.
//
// Since we can't easily change the SDK target to be an extension in Package.swift,
// we will just define the logic class that WOULD be the extension.

class FileProviderExtensionLogic {

    private let adapter = FileProviderAdapter.shared

    func item(for identifier: NSFileProviderItemIdentifier) async throws -> NSFileProviderItem {
        guard let item = try await adapter.item(for: identifier) else {
            throw NSFileProviderError(.noSuchItem)
        }
        return item
    }

    /*
    // These methods are missing from FileProviderAdapter in the previous step.
    // We need to implement them in FileProviderAdapter first.
    
    func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
        return try? adapter.urlForItem(withPersistentIdentifier: identifier)
    }
    
    func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
        return try? adapter.persistentIdentifierForItem(at: url)
    }
    */
}
