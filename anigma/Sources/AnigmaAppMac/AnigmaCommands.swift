//
//  AnigmaCommands.swift
//  AnigmaAppMac
//
//  Menu commands for the application.
//

import SwiftUI

struct AnigmaCommands: Commands {
    let store: AppStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Workspace") {
                Task {
                    await store.createWorkspace(name: "New Workspace")
                }
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Open Repository...") {
                // Open file picker via store state
                store.isRepoPickerPresented = true
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("Export...") {
                store.isExportPresented = true
            }
            .keyboardShortcut("e", modifiers: .command)
        }

        CommandGroup(after: .windowSize) {
            Button("Go to Command Bar") {
                store.focusOmniBar.toggle()
            }
            .keyboardShortcut("k", modifiers: .command)

            Button("Quick Look") {
                store.triggerQuickLook.toggle()
            }
            .keyboardShortcut(.space, modifiers: [])
        }

        CommandGroup(after: .toolbar) {
            Button("Refresh") {
                Task {
                    if let id = store.selectedWorkspaceID {
                        await store.selectWorkspace(id)
                    }
                }
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("Submit Test Job") {
                Task {
                    await store.submitJob(
                        action: "echo",
                        parameters: ["message": .string("Shortcut job!")]
                    )
                }
            }
            .keyboardShortcut("j", modifiers: .command)
        }
    }
}
