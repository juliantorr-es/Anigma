//
//  SystemConnectors.swift
//  AnigmaSystemSpine
//
//  Connectors for Calendar, Reminders, and Contacts.
//  Wraps system frameworks with governed access patterns.
//

import Foundation

#if canImport(EventKit)
@preconcurrency import EventKit
#endif

#if canImport(Contacts)
@preconcurrency import Contacts
#endif

public final class SystemConnectors: @unchecked Sendable {
    public static let shared = SystemConnectors()

    public init() {}

    // MARK: - Calendar & Reminders

    #if canImport(EventKit)
    private let eventStore = EKEventStore()

    public func requestCalendarAccess() async throws -> Bool {
        if #available(macOS 14.0, iOS 17.0, *) {
            return try await eventStore.requestFullAccessToEvents()
        } else {
            return try await eventStore.requestAccess(to: .event)
        }
    }

    public func createEvent(title: String, startDate: Date, endDate: Date) async throws {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = eventStore.defaultCalendarForNewEvents

        try eventStore.save(event, span: .thisEvent)

        SystemSpine.shared.recordReceipt(
            action: "create_calendar_event",
            actor: "user",
            surface: "system_connector",
            details: "Event: \(title)"
        )
    }
    #endif

    // MARK: - Contacts

    #if canImport(Contacts)
    private let contactStore = CNContactStore()

    public func requestContactsAccess() async throws -> Bool {
        return try await contactStore.requestAccess(for: .contacts)
    }

    public func findContact(name: String) async throws -> [String] {
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey] as [CNKeyDescriptor]
        let predicate = CNContact.predicateForContacts(matchingName: name)

        let contacts = try contactStore.unifiedContacts(matching: predicate, keysToFetch: keys)
        return contacts.map { "\($0.givenName) \($0.familyName)" }
    }
    #endif
}
