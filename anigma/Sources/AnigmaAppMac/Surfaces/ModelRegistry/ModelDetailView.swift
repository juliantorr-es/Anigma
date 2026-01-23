//
//  ModelDetailView.swift
//  AnigmaAppMac
//
//  Detailed view for a HuggingFace model with download options.
//

import SwiftUI
import AnigmaCore
import AnigmaCLI

public struct ModelDetailView: View {
    let model: HFSearchResult
    let onDownload: ([String]) async -> Void

    @Environment(AppStore.self) private var appStore
    @State private var modelDetail: HFModelDetail?
    @State private var selectedFiles: Set<String> = []
    @State private var isLoading = false
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var showBenchmarkPrompt = false
    @State private var errorMessage: String?

    public init(model: HFSearchResult, onDownload: @escaping ([String]) async -> Void) {
        self.model = model
        self.onDownload = onDownload
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                modelHeader

                // Files section
                if let detail = modelDetail {
                    filesSection(detail: detail)
                } else if !isLoading {
                    Button("Load Model Details") {
                        Task {
                            await loadModelDetails()
                        }
                    }
                }

                // Download section
                downloadSection

                // Error message
                if let error = errorMessage {
                    errorView(message: error)
                }
            }
            .padding()
        }
        .task {
            await loadModelDetails()
        }
        .alert("System Benchmark", isPresented: $showBenchmarkPrompt) {
            Button("Run Benchmark") {
                Task {
                    await runBenchmark()
                }
            }
            Button("Skip", role: .cancel) {}
        } message: {
            Text("Run a benchmark to get model recommendations tailored to your system?")
        }
    }

    private var modelHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.id)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("by \(model.author)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let tier = appStore.benchmarkResult?.tier {
                    TierBadge(tier: tier)
                }
            }

            HStack(spacing: 8) {
                if let size = model.size {
                    HStack(spacing: 4) {
                        Image(systemName: "externaldrive")
                        Text(model.formattedSize)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if let downloads = model.downloads {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                        Text("\(downloads.formatted())")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if let likes = model.likes {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                        Text("\(likes.formatted())")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            if !model.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(model.tags.prefix(10), id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Bauhaus.Color.surface)
                                .cornerRadius(4)
                        }
                    }
                }
            }

            if let taskType = model.taskType {
                HStack(spacing: 6) {
                    Image(systemName: taskType.icon)
                    Text(taskType.displayName)
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Bauhaus.Color.accent.opacity(0.15))
                .foregroundStyle(Bauhaus.Color.accent)
                .cornerRadius(4)
            }
        }
    }

    private func filesSection(detail: HFModelDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Model Files")
                    .font(.headline)
                Spacer()
                Text("\(detail.files.count) files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if detail.files.isEmpty {
                Text("No files available")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(detail.files.filter { $0.isFile }, id: \.id) { file in
                        FileCard(
                            file: file,
                            isSelected: selectedFiles.contains(file.path),
                            isRecommended: isRecommended(file: file)
                        )
                        .onTapGesture {
                            toggleFileSelection(file)
                        }
                    }
                }
            }

            // Backend compatibility
            if !detail.compatibleBackends.isEmpty {
                HStack(spacing: 8) {
                    ForEach(detail.compatibleBackends, id: \.self) { backend in
                        HStack(spacing: 4) {
                            Image(systemName: backend.icon)
                            Text(backend.displayName)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Bauhaus.Color.surface)
                        .cornerRadius(4)
                    }
                }
            }
        }
    }

    private var downloadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Download")
                .font(.headline)

            HStack {
                Button {
                    Task {
                        await downloadSelected()
                    }
                } label: {
                    Label("Download Selected", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedFiles.isEmpty || isDownloading)

                Button("Select All") {
                    if let detail = modelDetail {
                        selectedFiles = Set(detail.files.filter { $0.isFile }.map { $0.path })
                    }
                }
                .disabled(modelDetail == nil || isDownloading)

                Button("Clear Selection") {
                    selectedFiles.removeAll()
                }
                .disabled(selectedFiles.isEmpty || isDownloading)

                Spacer()

                if isDownloading {
                    ProgressView(value: downloadProgress)
                        .frame(width: 150)
                    Text("\(Int(downloadProgress * 100))%")
                        .font(.caption)
                }
            }

            // Storage warning
            if let warning = appStore.storageWarning {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(warning)
                        .font(.caption)
                }
                .padding(8)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(6)
            }
        }
    }

    private func errorView(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
        }
        .padding(8)
        .background(Color.red.opacity(0.1))
        .cornerRadius(6)
    }

    private func loadModelDetails() async {
        isLoading = true
        errorMessage = nil

        do {
            let detail = try await appStore.hfClient.getModelInfo(repo: model.id)
            await MainActor.run {
                self.modelDetail = detail
                self.selectedFiles = Set(detail.files.filter { $0.isFile }.map { $0.path })
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }

        await MainActor.run {
            self.isLoading = false
        }
    }

    private func downloadSelected() async {
        guard !selectedFiles.isEmpty else { return }

        isDownloading = true
        downloadProgress = 0

        await onDownload(Array(selectedFiles))

        isDownloading = false
    }

    private func runBenchmark() async {
        let result = await appStore.systemBenchmark.runBenchmark()
        await MainActor.run {
            self.appStore.benchmarkResult = result
        }
    }

    private func toggleFileSelection(file: HFFileInfo) {
        if selectedFiles.contains(file.path) {
            selectedFiles.remove(file.path)
        } else {
            selectedFiles.insert(file.path)
        }
    }

    private func isRecommended(file: HFFileInfo) -> Bool {
        guard let tier = appStore.benchmarkResult?.tier else { return false }

        let path = file.path.lowercased()

        switch tier {
        case .minimum:
            return path.contains(".q4") || path.contains(".q5")
        case .standard:
            return path.contains(".q5") || path.contains(".q6")
        case .powerful:
            return path.contains(".q6") || path.contains(".q8")
        case .extreme:
            return !path.contains(".q4")
        }
    }
}

struct TierBadge: View {
    let tier: SystemBenchmark.Tier

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "cpu")
            Text(tier.displayName)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Bauhaus.Color.accent.opacity(0.15))
        .foregroundStyle(Bauhaus.Color.accent)
        .cornerRadius(4)
    }
}

struct FileCard: View {
    let file: HFFileInfo
    let isSelected: Bool
    let isRecommended: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(isSelected ? .white : Bauhaus.Color.accent)
                Spacer()
                if isRecommended {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }

            Text(file.path.split(separator: "/").last.map(String.init) ?? file.path)
                .font(.caption)
                .lineLimit(2)
                .foregroundStyle(isSelected ? .white : .primary)

            Text(file.formattedSize)
                .font(.caption2)
                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
        }
        .padding(8)
        .background(isSelected ? Bauhaus.Color.accent : Bauhaus.Color.surface)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Bauhaus.Color.accent : Bauhaus.Color.border, lineWidth: 1)
        )
    }
}

extension Int {
    func formatted() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
