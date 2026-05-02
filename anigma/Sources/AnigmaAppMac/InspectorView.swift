//
//  InspectorView.swift
//  AnigmaAppMac
//
//  Inspector panel showing details for selected items.
//

import SwiftUI

struct InspectorView: View {
    let selection: InspectorSelection?

    var body: some View {
        Group {
            if let selection = selection {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch selection {
                        case .artifact(let id):
                            ArtifactInspector(artifactId: id)
                        case .job(let id):
                            JobInspector(jobId: id)
                        case .receipt(let hash):
                            ReceiptInspector(receiptHash: hash)
                        case .entity(let id):
                            Text("Entity Details: \(id)")
                                .font(Bauhaus.Font.header)
                        }
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView {
                    Label("No Selection", systemImage: "sidebar.right")
                } description: {
                    Text("Select an item to view details")
                }
            }
        }
        .accessibilityLabel("Inspector Panel")
        .accessibilityElement(children: .contain)
    }
}
