//
//  Intents.swift
//  AnigmaSystemSpine
//
//  App Intents for system-wide integration (Shortcuts, Spotlight, Siri).
//

@preconcurrency import CoreData
import Foundation
#if canImport(AppIntents)
import AppIntents

// MARK: - Entities

public struct AnigmaCaseEntity: AppEntity {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Anigma Case"
    public static let defaultQuery = AnigmaCaseQuery()

    public var id: UUID
    public var title: String

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    public init(id: UUID, title: String) {
        self.id = id
        self.title = title
    }

    public init(from managedObject: AnigmaCase) {
        self.id = managedObject.id
        self.title = managedObject.title
    }
}

public struct AnigmaCaseQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [UUID]) async throws -> [AnigmaCaseEntity] {
        let context = SystemSpine.shared.container.viewContext
        return try await context.perform {
            let request = NSFetchRequest<AnigmaCase>(entityName: "AnigmaCase")
            request.predicate = NSPredicate(format: "id IN %@", identifiers)
            let results = try context.fetch(request)
            return results.map { AnigmaCaseEntity(from: $0) }
        }
    }

    public func suggestedEntities() async throws -> [AnigmaCaseEntity] {
        let context = SystemSpine.shared.container.viewContext
        return try await context.perform {
            let request = NSFetchRequest<AnigmaCase>(entityName: "AnigmaCase")
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            request.fetchLimit = 20
            let results = try context.fetch(request)
            return results.map { AnigmaCaseEntity(from: $0) }
        }
    }
}

// MARK: - Intents

public struct CaptureToInboxIntent: AppIntent {
    public static let title: LocalizedStringResource = "Capture to Anigma Inbox"
    public static let description = IntentDescription("Adds text or a file to the Anigma Inbox.")
    public static let openAppWhenRun: Bool = false

    @Parameter(title: "Content")
    public var content: String

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let spine = SystemSpine.shared
        let context = spine.container.newBackgroundContext()

        try await context.perform {
            let doc = AnigmaDocument(context: context)
            doc.id = UUID()
            doc.filename = "Capture-\(Date().ISO8601Format()).txt"
            // In a real app, we'd save the content to a file in the App Group container
            // and link it here. For now, we just create the record.

            try context.save()
        }

        spine.recordReceipt(
            action: "capture_inbox",
            actor: "user",
            surface: "shortcuts",
            details: "Captured text length: \(content.count)"
        )

        return .result(value: "Captured to Inbox")
    }
}

public struct CreateTaskIntent: AppIntent {
    public static let title: LocalizedStringResource = "Create Anigma Task"
    public static let description = IntentDescription("Creates a new task in Anigma.")
    public static let openAppWhenRun: Bool = false

    @Parameter(title: "Title")
    public var title: String

    @Parameter(title: "Case")
    public var caseEntity: AnigmaCaseEntity?

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let spine = SystemSpine.shared
        let context = spine.container.newBackgroundContext()

        try await context.perform {
            let task = AnigmaTask(context: context)
            task.id = UUID()
            task.title = self.title
            task.isDone = false

            // Link to case if provided (requires relationship in model, skipping for now as model is simple)

            try context.save()
        }

        spine.recordReceipt(
            action: "create_task",
            actor: "user",
            surface: "shortcuts",
            details: "Task: \(title)"
        )

        return .result(value: "Task Created")
    }
}
#endif
