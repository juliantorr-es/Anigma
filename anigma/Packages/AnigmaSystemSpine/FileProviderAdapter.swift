//
//  FileProviderAdapter.swift
//  AnigmaSystemSpine
//
//  Adapts canonical Anigma objects to FileProviderItem structures.
//  This logic lives in the spine so the File Provider extension can stay thin.
//

import Foundation
import FileProvider
import CoreData
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

// MARK: - File Provider Item Adapter

public final class AnigmaFileProviderItem: NSObject, NSFileProviderItem, Sendable {
    public let itemIdentifier: NSFileProviderItemIdentifier
    public let parentItemIdentifier: NSFileProviderItemIdentifier
    public let filename: String
    public let contentType: UTType
    public let documentSize: NSNumber?
    public let creationDate: Date?
    public let contentModificationDate: Date?
    public let lastUsedDate: Date?
    public let tagData: Data?
    public let isUploaded: Bool
    public let isUploading: Bool
    public let uploadingError: Error?
    public let isDownloaded: Bool
    public let isDownloading: Bool
    public let downloadingError: Error?
    public let mostRecentEditorNameComponents: PersonNameComponents?
    public let ownerNameComponents: PersonNameComponents?
    // userInfo is [AnyHashable: Any]? which is not Sendable.
    // We can omit it or use a Sendable wrapper if needed, but for now we'll omit it to satisfy strict concurrency.
    // public let userInfo: [AnyHashable : Any]?

    public init(
        identifier: NSFileProviderItemIdentifier,
        parentIdentifier: NSFileProviderItemIdentifier,
        filename: String,
        contentType: UTType,
        size: Int? = nil,
        creationDate: Date? = nil,
        modificationDate: Date? = nil
    ) {
        self.itemIdentifier = identifier
        self.parentItemIdentifier = parentIdentifier
        self.filename = filename
        self.contentType = contentType
        self.documentSize = size.map { NSNumber(value: $0) }
        self.creationDate = creationDate
        self.contentModificationDate = modificationDate
        self.lastUsedDate = modificationDate
        self.tagData = nil
        self.isUploaded = true
        self.isUploading = false
        self.uploadingError = nil
        self.isDownloaded = true
        self.isDownloading = false
        self.downloadingError = nil
        self.mostRecentEditorNameComponents = nil
        self.ownerNameComponents = nil
        // self.userInfo = nil
        super.init()
    }
}

public final class FileProviderAdapter: Sendable {
    public static let shared = FileProviderAdapter()

    public init() {}

    /// Returns the root item for the File Provider.
    public func rootItem() -> AnigmaFileProviderItem {
        AnigmaFileProviderItem(
            identifier: .rootContainer,
            parentIdentifier: .rootContainer,
            filename: "Anigma",
            contentType: .folder
        )
    }

    /// Fetches items for a given parent identifier.
    public func items(for parentIdentifier: NSFileProviderItemIdentifier) async throws -> [AnigmaFileProviderItem] {
        let context = SystemSpine.shared.container.viewContext

        if parentIdentifier == .rootContainer {
            // Root level: List all Cases
            return try await context.perform {
                let request = NSFetchRequest<AnigmaCase>(entityName: "AnigmaCase")
                let cases = try context.fetch(request)

                return cases.map { kase in
                    AnigmaFileProviderItem(
                        identifier: NSFileProviderItemIdentifier(kase.id.uuidString),
                        parentIdentifier: .rootContainer,
                        filename: kase.title,
                        contentType: .folder,
                        creationDate: kase.createdAt,
                        modificationDate: kase.createdAt
                    )
                }
            }
        } else {
            // Case level: List Documents (assuming flat structure for now)
            // In a real app, we'd check if parentIdentifier matches a Case ID
            guard UUID(uuidString: parentIdentifier.rawValue) != nil else { return [] }

            return try await context.perform {
                // Fetch documents linked to this case (mocking relationship for now)
                // In reality: request.predicate = NSPredicate(format: "case.id == %@", caseUUID)
                let request = NSFetchRequest<AnigmaDocument>(entityName: "AnigmaDocument")
                let docs = try context.fetch(request)

                return docs.map { doc in
                    AnigmaFileProviderItem(
                        identifier: NSFileProviderItemIdentifier(doc.id.uuidString),
                        parentIdentifier: parentIdentifier,
                        filename: doc.filename,
                        contentType: .content, // Should infer from filename extension
                        size: 1024, // Mock size
                        creationDate: Date(),
                        modificationDate: Date()
                    )
                }
            }
        }
    }

    /// Resolves a single item by identifier.
    public func item(for identifier: NSFileProviderItemIdentifier) async throws -> AnigmaFileProviderItem? {
        if identifier == .rootContainer { return rootItem() }

        let context = SystemSpine.shared.container.viewContext
        guard let uuid = UUID(uuidString: identifier.rawValue) else { return nil }

        return try await context.perform {
            // Try Case
            let caseReq = NSFetchRequest<AnigmaCase>(entityName: "AnigmaCase")
            caseReq.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            if let kase = try context.fetch(caseReq).first {
                return AnigmaFileProviderItem(
                    identifier: identifier,
                    parentIdentifier: .rootContainer,
                    filename: kase.title,
                    contentType: .folder,
                    creationDate: kase.createdAt,
                    modificationDate: kase.createdAt
                )
            }

            // Try Document
            let docReq = NSFetchRequest<AnigmaDocument>(entityName: "AnigmaDocument")
            docReq.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            if let doc = try context.fetch(docReq).first {
                return AnigmaFileProviderItem(
                    identifier: identifier,
                    parentIdentifier: .rootContainer, // Should be case ID
                    filename: doc.filename,
                    contentType: .content,
                    size: 1024,
                    creationDate: Date(),
                    modificationDate: Date()
                )
            }

            return nil
        }
    }
}
