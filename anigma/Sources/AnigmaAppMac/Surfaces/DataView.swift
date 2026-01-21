//
//  DataView.swift
//  AnigmaAppMac
//
//  Wrapper for DataWorkspaceView from DataUI.
//

import SwiftUI
import DataUI
import AnigmaClientKit
import DataEngine

struct DataView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        DataWorkspaceView(selectionId: Binding(
            get: {
                if case .entity(let id) = store.inspectorSelection {
                    return id
                }
                return nil
            },
            set: { newValue in
                if let id = newValue {
                    store.inspectorSelection = .entity(id: id)
                } else {
                    // Only clear if we were selecting an entity
                    if case .entity = store.inspectorSelection {
                        store.inspectorSelection = nil
                    }
                }
            }
        )) { title, html, url in
            Task {
                await store.submitJob(action: "web-capture", parameters: [
                    "title": .string(title),
                    "html": .string(html),
                    "url": .string(url.absoluteString)
                ])
            }
        }
    }
}
