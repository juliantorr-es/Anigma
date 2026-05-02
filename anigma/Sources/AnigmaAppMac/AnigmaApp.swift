//
//  AnigmaApp.swift
//  AnigmaAppMac
//
//  Main application entry point for the launcher-first mac app.
//

import SwiftUI

@main
struct AnigmaApp: App {
    var body: some Scene {
        WindowGroup {
            LauncherRootView()
        }
    }
}
