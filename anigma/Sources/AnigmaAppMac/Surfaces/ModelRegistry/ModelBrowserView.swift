//
//  ModelBrowserView.swift
//  AnigmaAppMac
//
//  HuggingFace model browser with search, filtering, and cache support.
//

import SwiftUI
import AnigmaCore
import AnigmaCLI

public struct ModelBrowserView: View {
    @Environment(AppStore.self) private var appStore
    @StateObject private var viewModel = ModelBrowserViewModel()
    @State private var searchQuery = ""
    @State private var selectedFilter: ModelTaskType?
    @State private var selectedModel: HFSearchResult?
    @State private var showBenchmarkPrompt = false
    @State private var showAuthSheet = false

    public init() {}

    public var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            if let model = selectedModel {
                ModelDetailView(
                    model: model,
                    onDownload: { files in
                        await viewModel.downloadModel(repo: model.id, files: files)
                    }
                )
            } else {
                ContentUnavailableView(
                    "Select a Model",
                    systemImage: "square.stack.3d.up",
                    description: Text("Choose a model from the list to view details")
                )
            }
        }
        .searchable(text: $searchQuery, prompt: "Search HuggingFace models...")
        .onSubmit(of: .search) {
            Task {
                await viewModel.search(query: searchQuery, filter: selectedFilter)
            }
        }
        .onChange(of: selectedFilter) { _, newValue in
            Task {
                await viewModel.search(query: searchQuery, filter: newValue)
            }
        }
        .task {
            await viewModel.loadInitialState()
        }
        .sheet(isPresented: $showAuthSheet) {
            HuggingFaceAuthSheet()
        }
        .alert("System Benchmark", isPresented: $showBenchmarkPrompt) {
            Button("Run Benchmark") {
                Task {
                    await viewModel.runBenchmark()
                }
            }
            Button("Skip", role: .cancel) {}
        } message: {
            Text("Run a benchmark to get model recommendations tailored to your system?")
        }
    }

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // Filter tabs
            filterTabs

            Divider()

            // Results
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            } else if viewModel.results.isEmpty && !searchQuery.isEmpty {
                ContentUnavailableView.search(text: searchQuery)
                    .frame(maxHeight: .infinity)
            } else if viewModel.results.isEmpty {
                ContentUnavailableView(
                    "No Models",
                    systemImage: "square.stack.3d.up",
                    description: Text("Search for models to get started")
                )
                .frame(maxHeight: .infinity)
            } else {
                List(viewModel.results, id: \.id, selection: $selectedModel) { model in
                    ModelSearchRow(model: model, benchmarkResult: viewModel.benchmarkResult)
                        .tag(model)
                }
                .listStyle(.plain)
            }

            Divider()

            // Cache status
            cacheStatusBar
        }
        .navigationTitle("Browse Models")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        Task {
                            await viewModel.refresh()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh")

                    Button {
                        showAuthSheet = true
                    } label: {
                        Image(systemName: viewModel.hasToken ? "lock.fill" : "lock.open")
                    }
                    .help(viewModel.hasToken ? "Token configured" : "Configure token")
                }
            }
        }
    }

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    icon: "square.grid.2x2",
                    isSelected: selectedFilter == nil,
                    action: { selectedFilter = nil }
                )

                ForEach(ModelTaskType.allCases, id: \.self) { task in
                    FilterChip(
                        title: task.displayName,
                        icon: task.icon,
                        isSelected: selectedFilter == task,
                        action: { selectedFilter = task }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(height: 50)
    }

    private var cacheStatusBar: some View {
        HStack {
            Image(systemName: viewModel.isCacheStale ? "exclamationmark.arrow.triangle.2.circlepath" : "checkmark.circle")
            Text(viewModel.cacheStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if viewModel.isCacheStale {
                Button("Refresh") {
                    Task {
                        await viewModel.refresh()
                    }
                }
                .font(.caption)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Bauhaus.Color.surface)
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Bauhaus.Color.accent : Bauhaus.Color.surface)
            .foregroundStyle(isSelected ? .white : Bauhaus.Color.textPrimary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Bauhaus.Color.accent : Bauhaus.Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct HuggingFaceAuthSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = HuggingFaceAuthService()

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("HuggingFace Authentication")
                    .font(.headline)
                Spacer()
                Button("Close") {
                    dismiss()
                }
            }

            Text("Enter your HuggingFace read token to access private models and increase rate limits.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                SecureField("HF Token", text: $authService.tokenInput)
                    .textFieldStyle(.roundedBorder)

                Button("Save") {
                    Task {
                        await authService.saveToken()
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(authService.tokenInput.isEmpty)
            }

            if authService.hasToken {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Token is configured")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Delete Token") {
                        Task {
                            await authService.deleteToken()
                        }
                    }
                    .foregroundStyle(.red)
                }
                .font(.caption)
            }

            Link(destination: URL(string: "https://huggingface.co/settings/tokens")!) {
                HStack {
                    Text("Get a token")
                    Image(systemName: "arrow.up.right.square")
                }
                .font(.caption)
            }
        }
        .padding()
        .frame(width: 500, height: 250)
    }
}

@MainActor
public final class ModelBrowserViewModel: ObservableObject {
    @Published var results: [HFSearchResult] = []
    @Published var isLoading = false
    @Published var isCacheStale = false
    @Published var cacheStatusText = "Cache ready"
    @Published var benchmarkResult: SystemBenchmark.Result?
    @Published var hasToken = false

    private var searchTask: Task<Void, Never>?

    func search(query: String, filter: ModelTaskType?) async {
        searchTask?.cancel()

        searchTask = Task {
            isLoading = true

            do {
                try await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }

                let results = try await appStore.hfClient.searchModels(
                    query: query,
                    filter: HFSearchFilter(query: query, task: filter)
                )

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.results = results
                    self.isCacheStale = false
                    self.cacheStatusText = "\(results.count) models found"
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.cacheStatusText = "Search failed: \(error.localizedDescription)"
                }
            }

            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    func refresh() async {
        isCacheStale = false
        cacheStatusText = "Refreshing..."
        await search(query: searchQuery, filter: selectedFilter)
    }

    func loadInitialState() async {
        hasToken = await appStore.hfKeychain.hasToken
        cacheStatusText = "Ready to search"
    }

    func runBenchmark() async {
        let result = await appStore.systemBenchmark.runBenchmark()
        await MainActor.run {
            self.benchmarkResult = result
        }
    }

    func downloadModel(repo: String, files: [String]) async {
        for file in files {
            _ = try? await appStore.downloadQueue.enqueue(
                repo: repo,
                file: file,
                priority: .normal
            )
        }
    }

    private var searchQuery = ""
    private var selectedFilter: ModelTaskType?
}
