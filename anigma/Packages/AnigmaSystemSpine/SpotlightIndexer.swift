//
//  SpotlightIndexer.swift
//  AnigmaSystemSpine
//
//  Handles Core Spotlight indexing for canonical Anigma objects.
//

@preconcurrency import CoreSpotlight
import CoreData
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

#if canImport(MobileCoreServices)
import MobileCoreServices
#endif

public final class SpotlightIndexer: Sendable {
    public static let shared = SpotlightIndexer()

    private let index = CSSearchableIndex.default()

    public init() {}

    /// Indexes a batch of managed objects.
    /// - Parameter objects: The objects to index. Must conform to SpotlightIndexable.
    public func index(objects: [NSManagedObject]) async throws {
        let items = objects.compactMap { ($0 as? SpotlightIndexable)?.searchableItem }
        guard !items.isEmpty else { return }

        try await index.indexSearchableItems(items)
    }

    /// Deletes items from the index by identifier.
    public func delete(identifiers: [String]) async throws {
        try await index.deleteSearchableItems(withIdentifiers: identifiers)
    }

    /// Deletes all items from the index.
    public func deleteAll() async throws {
        try await index.deleteAllSearchableItems()
    }
}

// MARK: - SpotlightIndexable Protocol

public protocol SpotlightIndexable {
    var searchableItem: CSSearchableItem? { get }
    var domainIdentifier: String { get }
    var uniqueIdentifier: String { get }
}

// MARK: - Entity Extensions

extension AnigmaCase: SpotlightIndexable {
    public var domainIdentifier: String { "com.anigma.case" }
    public var uniqueIdentifier: String { id.uuidString }

    public var searchableItem: CSSearchableItem? {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .folder)
        attributeSet.title = title
        attributeSet.contentCreationDate = createdAt
        attributeSet.keywords = ["Case", "Anigma", "Project"]

        return CSSearchableItem(
            uniqueIdentifier: uniqueIdentifier,
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )
    }
}

extension AnigmaDocument: SpotlightIndexable {
    public var domainIdentifier: String { "com.anigma.document" }
    public var uniqueIdentifier: String { id.uuidString }

    public var searchableItem: CSSearchableItem? {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .content)
        attributeSet.title = filename
        attributeSet.keywords = ["Document", "Anigma", "Artifact"]
        // In a real app, we'd extract text content or set a thumbnail here

        return CSSearchableItem(
            uniqueIdentifier: uniqueIdentifier,
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )
    }
}

extension AnigmaTask: SpotlightIndexable {
    public var domainIdentifier: String { "com.anigma.task" }
    public var uniqueIdentifier: String { id.uuidString }

    public var searchableItem: CSSearchableItem? {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .toDoItem)
        attributeSet.title = title
        attributeSet.keywords = ["Task", "Anigma", "Action"]
        // attributeSet.isUserCreated = true // Not available on all platforms directly via property in older SDKs, skipping for safety

        return CSSearchableItem(
            uniqueIdentifier: uniqueIdentifier,
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )
    }
}
