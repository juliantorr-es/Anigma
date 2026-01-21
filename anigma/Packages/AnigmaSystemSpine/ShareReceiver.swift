//
//  ShareReceiver.swift
//  AnigmaSystemSpine
//
//  Logic for processing incoming content from the Share Sheet.
//  Handles NSItemProvider loading, file persistence, and database entry.
//

import Foundation
import CoreData
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

public final class ShareReceiver: Sendable {
    public static let shared = ShareReceiver()

    public init() {}

    /// Accepts a list of attachments (e.g. from NSExtensionContext).
    /// - Parameter attachments: The list of NSItemProvider objects to process.
    public func accept(attachments: [NSItemProvider]) async throws {
        for provider in attachments {
            try await process(provider: provider)
        }
    }

    private func process(provider: NSItemProvider) async throws {
        // 1. Determine Type
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            try await handleFile(provider: provider)
        } else if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            try await handleText(provider: provider)
        } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            try await handleURL(provider: provider)
        } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            try await handleImage(provider: provider)
        }
    }

    // MARK: - Handlers

    private func handleFile(provider: NSItemProvider) async throws {
        // Load in-place or copy
        let url = try await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) as? URL
        guard let sourceURL = url else { return }

        try await saveToInbox(sourceURL: sourceURL, filename: sourceURL.lastPathComponent)
    }

    private func handleText(provider: NSItemProvider) async throws {
        let text = try await provider.loadItem(forTypeIdentifier: UTType.text.identifier) as? String
        guard let content = text else { return }

        let filename = "Text-\(Date().ISO8601Format()).txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try content.write(to: tempURL, atomically: true, encoding: String.Encoding.utf8)

        try await saveToInbox(sourceURL: tempURL, filename: filename)
    }

    private func handleURL(provider: NSItemProvider) async throws {
        let url = try await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL
        guard let content = url else { return }

        // Save as a .webloc or .url file, or just text
        let filename = "Link-\(Date().ISO8601Format()).txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try content.absoluteString.write(to: tempURL, atomically: true, encoding: String.Encoding.utf8)

        try await saveToInbox(sourceURL: tempURL, filename: filename)
    }

    private func handleImage(provider: NSItemProvider) async throws {
        // Images often come as Data or URL
        // Simplified: try to load as URL first, else Data
        if let url = try? await provider.loadItem(forTypeIdentifier: UTType.image.identifier) as? URL {
            try await saveToInbox(sourceURL: url, filename: url.lastPathComponent)
        } else if let data = try? await provider.loadItem(forTypeIdentifier: UTType.image.identifier) as? Data {
            let filename = "Image-\(Date().ISO8601Format()).jpg" // Guessing extension
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: tempURL)
            try await saveToInbox(sourceURL: tempURL, filename: filename)
        }
    }

    // MARK: - Persistence

    private func saveToInbox(sourceURL: URL, filename: String) async throws {
        let spine = SystemSpine.shared

        // 1. Copy to App Group Container
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: spine.appGroupIdentifier) else {
            print("Error: No App Group container found.")
            return
        }

        let inboxURL = groupURL.appendingPathComponent("Inbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)

        let destURL = inboxURL.appendingPathComponent(filename)

        // Remove existing if needed (simple conflict resolution)
        if FileManager.default.fileExists(atPath: destURL.path) {
            try? FileManager.default.removeItem(at: destURL)
        }

        try FileManager.default.copyItem(at: sourceURL, to: destURL)

        // 2. Create Core Data Record
        let context = spine.container.newBackgroundContext()
        try await context.perform {
            let doc = AnigmaDocument(context: context)
            doc.id = UUID()
            doc.filename = filename
            // In real app: doc.path = "Inbox/\(filename)"

            try context.save()
        }

        // 3. Record Receipt
        spine.recordReceipt(
            action: "share_import",
            actor: "user",
            surface: "share_sheet",
            details: "Imported \(filename)"
        )
    }
}
