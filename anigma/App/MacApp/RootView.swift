//
//  RootView.swift
//  AnigmaAppMac
//
//  Legacy root view - now forwards to AnigmaRootView.
//

import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        // Forward to new Bauhaus architecture
        AnigmaRootView(store: store)
    }
}
