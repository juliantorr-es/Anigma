//
//  SystemUXSupport.swift
//  AnigmaSystemSpine
//
//  Support logic for System UX features: Notifications, Previews, and Scanning.
//

import Foundation
import UserNotifications

#if canImport(PDFKit)
import PDFKit
#endif

public final class SystemUXSupport: Sendable {
    public static let shared = SystemUXSupport()

    public init() {}

    // MARK: - Notifications

    public func requestNotificationPermissions() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        return try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    public func registerNotificationCategories() {
        let markDoneAction = UNNotificationAction(
            identifier: "MARK_DONE",
            title: "Mark Done",
            options: .authenticationRequired
        )

        let taskCategory = UNNotificationCategory(
            identifier: "ANIGMA_TASK",
            actions: [markDoneAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        UNUserNotificationCenter.current().setNotificationCategories([taskCategory])
    }

    public func scheduleTaskNotification(task: AnigmaTask, triggerDate: Date) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Anigma Task"
        content.body = task.title
        content.sound = .default
        content.categoryIdentifier = "ANIGMA_TASK"
        content.userInfo = ["taskId": task.id.uuidString]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)

        SystemSpine.shared.recordReceipt(
            action: "schedule_notification",
            actor: "user",
            surface: "system_ux",
            details: "Task: \(task.title) at \(triggerDate.ISO8601Format())"
        )
    }

    // MARK: - Preview Support

    /// Resolves the file URL for a document in the shared container.
    public func fileURL(for document: AnigmaDocument) -> URL? {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SystemSpine.shared.appGroupIdentifier) else { return nil }

        // Logic matches ShareReceiver's save location (Inbox)
        // In a real app, we'd have a more robust path resolver in SystemSpine
        let inboxURL = groupURL.appendingPathComponent("Inbox", isDirectory: true)
        return inboxURL.appendingPathComponent(document.filename)
    }

    // MARK: - Scanner Ingest

    #if canImport(PDFKit)
    /// Ingests scanned pages as a PDF document.
    /// - Parameter pages: Array of image data representing scanned pages.
    public func ingestScannedPages(_ pages: [Data]) async throws {
        guard !pages.isEmpty else { return }

        let pdfDocument = PDFDocument()

        for (index, pageData) in pages.enumerated() {
            if let image = UIImage(data: pageData), let page = PDFPage(image: image) {
                pdfDocument.insert(page, at: index)
            }
        }

        let filename = "Scan-\(Date().ISO8601Format()).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        if pdfDocument.write(to: tempURL) {
            // Reuse ShareReceiver logic to save to inbox and record receipt
            // We can't call ShareReceiver.accept directly easily with URL, but we can reuse the save logic if we expose it or duplicate it.
            // For now, let's duplicate the save logic to keep modules decoupled or add a helper in Spine.
            // Actually, ShareReceiver is in the same module.

            // We need to create a temporary NSItemProvider to use ShareReceiver, OR refactor ShareReceiver.
            // Let's refactor ShareReceiver to expose a save method? 
            // Or just implement save here.

            try await saveToInbox(sourceURL: tempURL, filename: filename)
        }
    }

    // Helper for UIImage cross-platform
    #if os(macOS)
    private typealias UIImage = NSImage
    #else
    private typealias UIImage = UIKit.UIImage
    #endif

    private func saveToInbox(sourceURL: URL, filename: String) async throws {
        let spine = SystemSpine.shared
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: spine.appGroupIdentifier) else { return }

        let inboxURL = groupURL.appendingPathComponent("Inbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        let destURL = inboxURL.appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: destURL.path) {
            try? FileManager.default.removeItem(at: destURL)
        }

        try FileManager.default.copyItem(at: sourceURL, to: destURL)

        let context = spine.container.newBackgroundContext()
        try await context.perform {
            let doc = AnigmaDocument(context: context)
            doc.id = UUID()
            doc.filename = filename
            try context.save()
        }

        spine.recordReceipt(
            action: "scan_import",
            actor: "user",
            surface: "scanner",
            details: "Imported \(filename)"
        )
    }
    #endif
}

// Cross-platform image support for PDFKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif
