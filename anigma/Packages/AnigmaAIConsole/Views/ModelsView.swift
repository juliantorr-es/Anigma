import AnigmaAgents
import SwiftUI

struct ModelsView: View {
    let client: AIConsoleClient
    @State private var models: [AIModel] = []

    @State private var isImporterPresented = false
    @State private var downloadUrlString = ""
    @State private var isDownloadSheetPresented = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: { isDownloadSheetPresented = true }) {
                    Label("Download Model", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding()
            }

            List(models) { model in
                HStack {
                    VStack(alignment: .leading) {
                        Text(model.name).font(.headline)
                        HStack {
                            Text(model.family).foregroundStyle(.secondary)
                            Text("•")
                            Text(model.format).foregroundStyle(.tertiary)
                            if let q = model.quantization {
                                Text("•")
                                Text(q).foregroundStyle(.tertiary)
                            }
                        }
                        .font(.subheadline)
                    }
                    Spacer()
                    if model.isValidated {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    }
                    Text(ByteCountFormatter.string(fromByteCount: model.sizeBytes, countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .sheet(isPresented: $isDownloadSheetPresented) {
            VStack(spacing: 20) {
                Text("Download New Model").font(.headline)
                TextField("Model URL (HuggingFace or local)", text: $downloadUrlString)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 400)

                HStack {
                    Button("Cancel") { isDownloadSheetPresented = false }
                    Spacer()
                    Button("Start Download") {
                        if let url = URL(string: downloadUrlString) {
                            Task {
                                _ = try? await client.installModel(url: url)
                                isDownloadSheetPresented = false
                                models = try await client.listModels()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(downloadUrlString.isEmpty)
                }
            }
            .padding()
        }
        .overlay {
            if let error = error {
                ContentUnavailableView("Connection Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if models.isEmpty {
                ContentUnavailableView("No Models Found", systemImage: "cube.box", description: Text("Connect a model provider to see available models."))
            }
        }
        .task {
            do {
                models = try await client.listModels()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    @State private var error: String?
}
