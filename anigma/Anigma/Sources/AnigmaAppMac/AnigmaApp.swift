//
//  AnigmaApp.swift
//  AnigmaAppMac
//
//  Main application entry point for the macOS Anigma app.
//

import SwiftUI
import ObservatoriumModule

@main
struct AnigmaApp: App {
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            MainContentView()
                .environment(appState)
                .onAppear {
                    Task {
                        await appState.initializeObservatorium()
                    }
                }
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1200, height: 800)
        .commands {
            SidebarCommands()
            ToolbarCommands()
        }
        
        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}
