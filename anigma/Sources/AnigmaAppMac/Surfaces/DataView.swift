//
//  DataView.swift
//  AnigmaAppMac
//
//  Wrapper for DataWorkspaceView from DataUI.
//

import SwiftUI
import AnigmaClientKit

struct DataView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack {
            Text("Data Workspace")
                .font(.title2)
            Text("The data workspace UI is not available in this build configuration.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .background(Color(nsColor: NSColor.controlBackgroundColor))
    }
}
