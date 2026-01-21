//
//  UserActivityFactory.swift
//  AnigmaSystemSpine
//
//  Generates NSUserActivity objects for Handoff and Spotlight continuity.
//

import Foundation
import CoreSpotlight

#if canImport(Intents)
import Intents
#endif

public final class UserActivityFactory: Sendable {
    public static let shared = UserActivityFactory()

    public init() {}

    public func activity(for kase: AnigmaCase) -> NSUserActivity {
        let activity = NSUserActivity(activityType: "com.anigma.viewCase")
        activity.title = kase.title
        activity.userInfo = ["id": kase.id.uuidString]
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = true

        // Spotlight metadata
        let attributes = CSSearchableItemAttributeSet(contentType: .folder)
        attributes.title = kase.title
        attributes.contentCreationDate = kase.createdAt
        activity.contentAttributeSet = attributes

        return activity
    }

    public func activity(for document: AnigmaDocument) -> NSUserActivity {
        let activity = NSUserActivity(activityType: "com.anigma.viewDocument")
        activity.title = document.filename
        activity.userInfo = ["id": document.id.uuidString]
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = true

        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = document.filename
        activity.contentAttributeSet = attributes

        return activity
    }
}
