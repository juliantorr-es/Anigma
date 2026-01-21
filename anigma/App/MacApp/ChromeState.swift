//
//  ChromeState.swift
//  AnigmaAppMac
//
//  Global UI chrome state (toolbar, governance, activity).
//

import SwiftUI

/// Chrome state for global UI elements
struct ChromeState {
    var governanceLabel: String = "Local • Read"
    var governanceTint: Color = .primary
    var activityCount: Int = 0
    var unreadInboxCount: Int = 0
}

/// Session state (auth, preferences)
struct SessionState {
    var isAuthenticatedForPrivileged: Bool = false
    var username: String = "User"

    /// Return a stable user ID for receipts and audit trails
    var currentUserId: String? {
        isAuthenticatedForPrivileged ? username : nil
    }
}
