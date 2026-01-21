//
//  ToolRunnerView.swift
//  AnigmaAppMac
//
//  A unified, dynamically generated UI for running system tools and workers.
//

import SwiftUI
import ContractsCore
import AnigmaDaemonCore

/// A view that dynamically generates a form for an ActionDefinition and submits it to the daemon.
// NonPersistent
struct ToolRunnerView: View, Sendable {
    let action: ActionDefinition
    @Environment(AppStore.self) private var store

    @State private var parameterValues: [String: ParameterValue] = [:]
    @State private var selectedArtifacts: [String: String] = [:] // key: parameter name, value: artifact hash
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var submissionReceipt: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
                headerView

                if !action.parameters.isEmpty {
                    formSection
                } else {
                    noParametersView
                }

                actionSection

                if let error = errorMessage {
                    errorView(error)
                }

                if let receipt = submissionReceipt {
                    successView(receipt)
                }
            }
            .padding(Bauhaus.Grid.x4)
        }
        .background(Bauhaus.Color.background)
        .onAppear(perform: initializeParameters)
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            HStack {
                if let icon = action.icon {
                    Image(systemName: icon)
                        .font(Bauhaus.Font.header)
                        .foregroundStyle(Bauhaus.Color.accent)
                }

                VStack(alignment: .leading) {
                    Text(action.displayName)
                        .font(Bauhaus.Font.header)
                        .fontWeight(.bold)

                    Text(action.family.uppercased())
                        .font(Bauhaus.Font.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                }
            }

            Text(action.description)
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            if let help = action.helpText {
                Text(help)
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textTertiary)
                    .padding(.top, Bauhaus.Grid.unit / 2)
            }
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            Text("Configuration")
                .font(Bauhaus.Font.subHeader)

            ForEach(action.parameters.keys.sorted(), id: \.self) { key in
                guard let schema = action.parameters[key] else {
                    fatalError("Failed to unwrap schema")
                }
                parameterRow(key: key, schema: schema)
            }
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.surface.opacity(0.5))
        .cornerRadius(Bauhaus.Grid.radius)
    }

    private func parameterRow(key: String, schema: ActionParameterSchema) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(schema.displayName)
                    .font(Bauhaus.Font.body)
                    .fontWeight(.medium)

                if schema.required {
                    Text("*")
                        .foregroundStyle(Bauhaus.Color.error)
                }

                Spacer()
            }

            inputControl(key: key, schema: schema)

            if let desc = schema.description {
                Text(desc)
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func inputControl(key: String, schema: ActionParameterSchema) -> some View {
        switch schema.variant {
        case .text:
            TextField(schema.placeholder ?? "", text: stringBinding(for: key))
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(schema.displayName)

        case .longText:
            TextEditor(text: stringBinding(for: key))
                .frame(minHeight: 80)
                .padding(Bauhaus.Grid.unit / 2)
                .background(Bauhaus.Color.surface)
                .cornerRadius(Bauhaus.Grid.unit / 2)
                .overlay(RoundedRectangle(cornerRadius: Bauhaus.Grid.unit / 2).stroke(Bauhaus.Color.border, lineWidth: 1))

        case .number:
            TextField("0", text: stringBinding(for: key))
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(schema.displayName)

        case .toggle:
            Toggle("", isOn: boolBinding(for: key))
                .labelsHidden()
                .accessibilityLabel(schema.displayName)

        case .choice:
            Picker("", selection: stringBinding(for: key)) {
                ForEach(schema.options ?? [], id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel(schema.displayName)

        case .artifact:
            artifactSelector(key: key)

        case .date:
            DatePicker("", selection: dateBinding(for: key), displayedComponents: .date)
                .labelsHidden()
        }
    }

    private func artifactSelector(key: String) -> some View {
        HStack {
            if let hash = selectedArtifacts[key] {
                Label(hash.prefix(8) + "...", systemImage: "doc.fill")
                    .font(Bauhaus.Font.caption)
                    .padding(Bauhaus.Grid.unit / 2)
                    .background(Bauhaus.Color.accent.opacity(0.1))
                    .cornerRadius(Bauhaus.Grid.unit / 2)
            } else {
                Text("No artifact selected")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            }

            Spacer()

            Button("Select...") {
                // In a real app, this would open an artifact picker popover
            }
            .accessibilityLabel("Select artifact")
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(Bauhaus.Grid.unit)
        .background(Bauhaus.Color.surface)
        .cornerRadius(Bauhaus.Grid.unit)
    }

    private var noParametersView: some View {
        Text("Continuous execution with default settings.")
            .font(Bauhaus.Font.body)
            .foregroundStyle(Bauhaus.Color.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
    }

    private var actionSection: some View {
        VStack(spacing: Bauhaus.Grid.x2) {
            // Daemon connection status
            HStack {
                Circle()
                    .fill(store.isDaemonConnected ? Bauhaus.Color.success : Bauhaus.Color.error)
                    .frame(width: Bauhaus.Grid.unit, height: Bauhaus.Grid.unit)
                Text(store.isDaemonConnected ? "Connected to Daemon" : "Daemon Disconnected")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(store.isDaemonConnected ? Bauhaus.Color.success : Bauhaus.Color.error)

                Spacer()

                if store.daemonBridge == nil {
                    Button("Reconnect") {
                        Task {
                            do {
                                _ = try await store.daemonCapability.ensureDaemonRunning()
                                store.showToast(title: "Reconnected", subtitle: "Daemon is now available", icon: "checkmark.circle.fill")
                            } catch {
                                store.showError("Failed to reconnect: \(error.localizedDescription)")
                            }
                        }
                    }
                    .accessibilityLabel("Reconnect to daemon")
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, Bauhaus.Grid.x2)
            .padding(.vertical, Bauhaus.Grid.unit)
            .background(
                RoundedRectangle(cornerRadius: Bauhaus.Grid.unit)
                    .fill((store.isDaemonConnected ? Bauhaus.Color.success : Bauhaus.Color.error).opacity(0.1))
            )

            // Run button
            HStack {
                Spacer()

                Button(action: runTool) {
                    HStack {
                        if isSubmitting {
                            ProgressView().controlSize(.small)
                                .padding(.trailing, Bauhaus.Grid.unit / 2)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text("Run \(action.displayName)")
                    }
                    .frame(minWidth: 160)
                }
                .accessibilityLabel("Run \(action.displayName)")
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting || store.daemonBridge == nil)

                Spacer()
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(Bauhaus.Font.subHeader)
                    .foregroundStyle(Bauhaus.Color.surface)
                Text("Execution Failed")
                    .font(Bauhaus.Font.bodyBold)
                    .foregroundStyle(Bauhaus.Color.surface)
                Spacer()
                Button(action: { errorMessage = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Bauhaus.Color.surface.opacity(0.8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss error")
            }

            Text(message)
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.surface.opacity(0.9))

            HStack(spacing: Bauhaus.Grid.unit) {
                Button("Retry") {
                    errorMessage = nil
                    runTool()
                }
                .buttonStyle(.borderedProminent)
                .tint(Bauhaus.Color.surface)
                .foregroundStyle(Bauhaus.Color.error)
                .accessibilityLabel("Retry execution")

                Button("Copy Error") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(message, forType: .string)
                }
                .buttonStyle(.bordered)
                .tint(Bauhaus.Color.surface)
                .accessibilityLabel("Copy error to clipboard")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.radius)
                .fill(Bauhaus.Color.error)
                .shadow(color: Bauhaus.Color.error.opacity(0.4), radius: 8, y: 4)
        )
    }

    private func successView(_ receipt: String) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .font(Bauhaus.Font.subHeader)
                    .foregroundStyle(Bauhaus.Color.surface)
                Text("Job Submitted Successfully")
                    .font(Bauhaus.Font.bodyBold)
                    .foregroundStyle(Bauhaus.Color.surface)
                Spacer()
            }

            VStack(alignment: .leading, spacing: Bauhaus.Grid.unit / 2) {
                Text("Receipt Hash")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.surface.opacity(0.7))

                Text(receipt)
                    .font(Bauhaus.Font.mono)
                    .foregroundStyle(Bauhaus.Color.surface)
                    .textSelection(.enabled)
            }

            HStack(spacing: Bauhaus.Grid.unit) {
                Button("View in Activity") {
                    store.selectedReceiptJson = nil // Reset first
                    Task { await store.fetchReceipt(hash: receipt) }
                }
                .buttonStyle(.borderedProminent)
                .tint(Bauhaus.Color.surface)
                .foregroundStyle(Bauhaus.Color.success)
                .accessibilityLabel("View job details in activity")

                Button("Copy Receipt") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(receipt, forType: .string)
                }
                .buttonStyle(.bordered)
                .tint(Bauhaus.Color.surface)
                .accessibilityLabel("Copy receipt hash to clipboard")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.radius)
                .fill(Bauhaus.Color.success)
                .shadow(color: Bauhaus.Color.success.opacity(0.4), radius: 8, y: 4)
        )
    }

    // MARK: - Logic

    private func initializeParameters() {
        var initial: [String: ParameterValue] = [:]
        for (key, schema) in action.parameters {
            switch schema.type {
            case .string: initial[key] = .string("")
            case .number: initial[key] = .number(0)
            case .bool: initial[key] = .bool(false)
            default: initial[key] = .string("")
            }

            // Set defaults for choices
            if schema.variant == .choice, let first = schema.options?.first {
                initial[key] = .string(first)
            }
        }
        parameterValues = initial
    }

    private func runTool() {
        isSubmitting = true
        errorMessage = nil
        submissionReceipt = nil

        Task {
            do {
                // 1. Prepare Config Data (Canonical JSON)
                var configDict: [String: BindingValue] = [:]
                for (key, val) in parameterValues {
                    switch val {
                    case .string(let s): configDict[key] = .string(s)
                    case .number(let n): configDict[key] = .number(n)
                    case .bool(let b): configDict[key] = .bool(b)
                    }
                }

                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                let configData = try encoder.encode(configDict)

                // 2. Prepare Inputs (Artifacts)
                var inputRefs: [AnigmaArtifactRef] = []
                for (key, schema) in action.parameters where schema.variant == .artifact {
                    if let hash = selectedArtifacts[key] {
                        var ref = AnigmaArtifactRef()
                        ref.hash = hash
                        ref.mediaType = "application/octet-stream"
                        ref.sizeBytes = 0
                        inputRefs.append(ref)
                    } else if schema.required {
                        throw ToolError.missingRequiredParameter(schema.displayName)
                    }
                }

                // 3. Dispatch Job
                var spec = AnigmaJobSpec()
                spec.kind = action.name
                spec.configCanonical = configData
                spec.inputs = inputRefs

                let result = try await store.dispatchJob(spec)

                await MainActor.run {
                    submissionReceipt = result.receiptHash
                    isSubmitting = false
                    store.showToast(title: "Tool Started", subtitle: action.displayName, icon: "play.circle.fill")
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubmitting = false
                }
            }
        }
    }

    // MARK: - Bindings

    private func stringBinding(for key: String) -> Binding<String> {
        Binding(
            get: {
                if case .string(let s) = parameterValues[key] { return s }
                return ""
            },
            set: { parameterValues[key] = .string($0) }
        )
    }

    private func boolBinding(for key: String) -> Binding<Bool> {
        Binding(
            get: {
                if case .bool(let b) = parameterValues[key] { return b }
                return false
            },
            set: { parameterValues[key] = .bool($0) }
        )
    }

    private func dateBinding(for key: String) -> Binding<Date> {
        Binding(
            get: { Date() }, // Mock
            set: { _ in }
        )
    }
}

// MARK: - Helper Types

enum ParameterValue {
    case string(String)
    case number(Double)
    case bool(Bool)
}

enum ToolError: LocalizedError {
    case missingRequiredParameter(String)

    var errorDescription: String? {
        switch self {
        case .missingRequiredParameter(let name):
            return "Required parameter '\(name)' is missing."
        }
    }
}
