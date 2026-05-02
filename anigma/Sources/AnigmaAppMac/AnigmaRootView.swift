//
//  AnigmaRootView.swift
//  AnigmaAppMac
//
//  Root view with platform-aware shell routing.
//

import SwiftUI

struct AnigmaRootView: View {
    @State private var store: AppStore

    init(store: AppStore) {
        _store = State(initialValue: store)
    }

    var body: some View {
        Group {
            #if os(macOS)
            MacShell()
            #elseif os(iOS)
            IOSShell()
            #endif
        }
        .environment(store)
    }
}
