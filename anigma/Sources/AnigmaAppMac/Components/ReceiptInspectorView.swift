//
//  ReceiptInspectorView.swift
//  AnigmaAppMac
//
//  Shared component for auditing CoreReceipt JSON details.
//

import SwiftUI

struct ReceiptInspectorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
                    if let json = store.selectedReceiptJson {
                        Text(json)
                            .font(Bauhaus.Font.mono)
                            .padding()
                            .textSelection(.enabled)
                    } else {
                        VStack(spacing: 20) {
                            ProgressView()
                            Text("Fetching receipt from daemon...")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                    }
                }
            }
            .navigationTitle("CoreReceipt Audit")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.return, modifiers: [])
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if let json = store.selectedReceiptJson {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(json, forType: .string)
                        }
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .keyboardShortcut("c", modifiers: .command)
                }
            }
            .frame(minWidth: 500, minHeight: 400)
        }
    }
}
