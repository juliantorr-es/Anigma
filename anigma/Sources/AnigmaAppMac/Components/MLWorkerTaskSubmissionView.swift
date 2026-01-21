//
//  MLWorkerTaskSubmissionView.swift
//  AnigmaAppMac
//
//  Submit ML tasks to workers.
//

import SwiftUI
import AnigmaHostMac
import MLWorkerCommon
import ContractsCore
import CryptoKit

// NonPersistent
struct MLWorkerTaskSubmissionView: View, Sendable {
    @Environment(AppStore.self) private var store
    @State private var selectedEngine = "mlx"
    @State private var selectedTask: MLTaskKind = .chat
    @State private var inputPath = ""
    @State private var maxTokens = "1024"
    @State private var temperature = "0.7"
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showFilePicker = false
    @State private var useGovernedExecution = true
    @State private var selectedModelId = ""

    private let availableEngines = ["mlx", "llama", "deepseek"]
    private let availableTasks: [MLTaskKind] = [.chat, .embed, .transcribe]

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
            headerView

            engineSelectionView

            taskSelectionView

            inputConfigurationView

            optionsView

            submitButtonView

            if let error = errorMessage {
                errorView(error)
            }
        }
        .padding(Bauhaus.Grid.x3)
        .background(Bauhaus.Color.surface)
        .bauhausSection()
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    inputPath = url.path
                }
            case .failure(let error):
                errorMessage = "Failed to select file: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Image(systemName: "plus.app")
                .font(.title2)
                .foregroundStyle(Bauhaus.Color.accent)

            Text("Submit ML Task")
                .font(Bauhaus.Font.header)

            Spacer()
        }
    }

    private var engineSelectionView: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            Text("ML Engine")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            Picker("Engine", selection: $selectedEngine) {
                ForEach(availableEngines, id: \.self) { engine in
                    Text(engine.uppercased()).tag(engine)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Select ML Engine")
        }
    }

    private var taskSelectionView: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            Text("Task Type")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            Picker("Task", selection: $selectedTask) {
                ForEach(availableTasks, id: \.self) { task in
                    Text(taskLabel(task)).tag(task)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Select Task Type")
        }
    }

    private var inputConfigurationView: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            Text("Input")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            HStack(spacing: Bauhaus.Grid.x2) {
                TextField("Input file path", text: $inputPath)
                    .accessibilityLabel("ML Task Input File Path")
                    .textFieldStyle(.roundedBorder)
                    .font(Bauhaus.Font.mono)

                Button(action: { showFilePicker = true }) {
                    Image(systemName: "folder")
                }
                .accessibilityLabel("Browse for file")
                .buttonStyle(.bordered)
            }

            if !inputPath.isEmpty {
                Text(inputPath)
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var optionsView: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            Toggle("Governed Execution (with receipts)", isOn: $useGovernedExecution)
                .accessibilityLabel("Enable governed execution with cryptography receipts")
                .font(Bauhaus.Font.caption)
                .toggleStyle(.switch)

            if useGovernedExecution {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                    Text("Model")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textTertiary)

                    Picker("Model", selection: $selectedModelId) {
                        Text("Select model...").tag("")
                        ForEach(store.registeredModels.filter { $0.isRunnable }) { entry in
                            Text(entry.modelId).tag(entry.modelId)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel("Model Selector")
                }
            }

            Text("Options")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            HStack(spacing: Bauhaus.Grid.x3) {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                    Text("Max Tokens")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textTertiary)

                    TextField("1024", text: $maxTokens)
                        .accessibilityLabel("Maximum token count")
                        .textFieldStyle(.roundedBorder)
                        .font(Bauhaus.Font.mono)
                        .frame(width: 100) // OK: Fixed field width
                }

                VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                    Text("Temperature")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textTertiary)

                    TextField("0.7", text: $temperature)
                        .accessibilityLabel("Model Temperature")
                        .textFieldStyle(.roundedBorder)
                        .font(Bauhaus.Font.mono)
                        .frame(width: 100) // OK: Fixed field width
                }
            }
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.background)
        .cornerRadius(Bauhaus.Grid.unit)
    }

    private var submitButtonView: some View {
        HStack {
            Spacer()

            Button(action: { Task { await submitTask() } }) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }

                    Text("Submit Task")
                }
            }
            .accessibilityLabel("Submit task for execution")
            .buttonStyle(.borderedProminent)
            .disabled(inputPath.isEmpty || isSubmitting)

            Spacer()
        }
    }

    private func errorView(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Bauhaus.Grid.x2) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Bauhaus.Color.error)

            Text(message)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.error)
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.error.opacity(0.1))
        .cornerRadius(Bauhaus.Grid.unit)
    }

    // MARK: - Actions

    private func submitTask() async {
        guard !inputPath.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        do {
            if useGovernedExecution {
                guard !selectedModelId.isEmpty else {
                    errorMessage = "Please select a model for governed execution"
                    isSubmitting = false
                    return
                }

                // Hash input file
                let inputHash = try hashFile(at: inputPath)

                // Build governed input
                let runInput = ContractsCore.RunSpec.Input(
                    path: inputPath,
                    hash: inputHash,
                    kind: "text/plain"
                )

                // Execute governed run
                _ = try await store.executeGovernedMLRun(
                    modelId: selectedModelId,
                    taskKind: selectedTask,
                    inputs: [runInput],
                    backend: selectedEngine.uppercased(),
                    temperature: Double(temperature),
                    maxTokens: Int(maxTokens)
                )
            } else {
                // Legacy path
                let inputs = [
                    ContractsCore.MLArtifactRef(
                        path: inputPath,
                        hash: "placeholder-hash-\(UUID().uuidString)"
                    )
                ]

                let options = MLTaskOptions(
                    seed: 42,
                    maxTokens: Int(maxTokens),
                    temperature: Double(temperature),
                    topP: nil,
                    outputDirectory: nil
                )

                await store.submitMLTask(
                    engine: selectedEngine,
                    task: selectedTask,
                    inputs: inputs,
                    options: options
                )
            }

            // Clear form
            inputPath = ""
            maxTokens = "1024"
            temperature = "0.7"
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }

    private func hashFile(at path: String) throws -> String {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Helpers

    private func taskLabel(_ task: MLTaskKind) -> String {
        switch task {
        case .chat:
            return "Inference"
        case .embed:
            return "Embedding"
        case .transcribe:
            return "Transcription"
        case .classify:
            return "Classification"
        case .summarize:
            return "Summarize"
        case .rerank:
            return "Rerank"
        case .other:
            return "Other"
        }
    }
}

#Preview {
    MLWorkerTaskSubmissionView()
        .frame(width: 500, height: 600) // OK: Preview sizing
        .environment(AppStore())
}
