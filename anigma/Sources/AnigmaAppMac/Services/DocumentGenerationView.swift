//
//  DocumentGenerationView.swift
//  AnigmaAppMac
//
//  Outlineum zine and document generation UI.
//

import SwiftUI

struct DocumentGenerationView: View {
    @Environment(AppStore.self) private var store
    @State private var contentText = ""
    @State private var outlineDepth = 3
    @State private var selectedTemplate: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Document Generation & Zines")
                .font(.headline)

            HStack {
                TextField("Content to outline", text: $contentText)
                    .textFieldStyle(.roundedBorder)
                Stepper("Depth: \(outlineDepth)", value: $outlineDepth, in: 1...5)
                Button("Generate Outline") {
                    Task { await store.generateOutline(content: contentText, depth: outlineDepth) }
                }
                .disabled(contentText.isEmpty)
            }

            if !store.outlines.isEmpty {
                Text("Generated Outlines").font(.subheadline).bold()
                List(store.outlines.indices, id: \.self) { index in
                    let outline = store.outlines[index]
                    VStack(alignment: .leading) {
                        Text(outline.outline.title).font(.headline)
                        HStack {
                            Label("\(outline.statistics.totalSections) sections", systemImage: "list.bullet")
                            Label("\(outline.statistics.wordCount) words", systemImage: "doc.text")
                            Label("Depth: \(outline.statistics.maxDepth)", systemImage: "arrow.down.right")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Button("Create Zine") {
                            Task {
                                await store.createZine(outline: outline.outline, template: selectedTemplate)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 150)
            }

            Divider()

            Text("Zine Templates").font(.subheadline).bold()
            if store.zineTemplates.isEmpty {
                Button("Load Templates") {
                    Task { await store.loadZineTemplates() }
                }
                .buttonStyle(.bordered)
            } else {
                Picker("Template", selection: $selectedTemplate) {
                    Text("Default").tag(nil as String?)
                    ForEach(store.zineTemplates) { template in
                        Text(template.name).tag(template.id as String?)
                    }
                }
            }
        }
        .padding()
        .task {
            await store.loadZineTemplates()
        }
    }
}
