//
//  AnigmaApp.swift
//  AnigmaAppMac
//
//  Main application entry point.
//

import SwiftUI

@main
struct AnigmaApp: App {
  @State private var store = AppStore()
  @State private var appState = AppState.shared

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(store)
        .environment(appState)
    }
    .commands {
      AnigmaCommands(store: store)
    }

    Settings {
      SettingsView()
        .environment(store)
        .environment(appState)
    }
  }
}
