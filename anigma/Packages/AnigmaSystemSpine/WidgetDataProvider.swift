//
//  WidgetDataProvider.swift
//  AnigmaSystemSpine
//
//  Provides optimized data queries for Widgets and Live Activities.
//

import Foundation
import CoreData

public struct WidgetInboxStats: Sendable {
    public let count: Int
    public let lastItemDate: Date?
}

public struct WidgetTaskSummary: Sendable {
    public let id: UUID
    public let title: String
    public let isDone: Bool

    public init(id: UUID, title: String, isDone: Bool) {
        self.id = id
        self.title = title
        self.isDone = isDone
    }
}

public final class WidgetDataProvider: Sendable {
    public static let shared = WidgetDataProvider()

    private let spine: SystemSpine

    public init(spine: SystemSpine = .shared) {
        self.spine = spine
    }

    public func getInboxStats() async -> WidgetInboxStats {
        let context = spine.container.viewContext
        return await context.perform {
            let request = NSFetchRequest<AnigmaDocument>(entityName: "AnigmaDocument")
            // Assuming all docs are inbox for now
            let count = (try? context.count(for: request)) ?? 0

            // Get last item date
            // let dateRequest = NSFetchRequest<AnigmaDocument>(entityName: "AnigmaDocument")
            // Note: AnigmaDocument doesn't have createdAt in our stub model yet, so we skip date for now
            // In real app: dateRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            // dateRequest.fetchLimit = 1

            return WidgetInboxStats(count: count, lastItemDate: Date())
        }
    }

    public func getTodayTasks() async -> [WidgetTaskSummary] {
        let context = spine.container.viewContext
        return await context.perform {
            let request = NSFetchRequest<AnigmaTask>(entityName: "AnigmaTask")
            request.predicate = NSPredicate(format: "isDone == NO")
            request.fetchLimit = 5

            let tasks = (try? context.fetch(request)) ?? []
            return tasks.map { WidgetTaskSummary(id: $0.id, title: $0.title, isDone: $0.isDone) }
        }
    }
}
