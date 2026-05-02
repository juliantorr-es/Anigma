//
//  BinaryTestView.swift
//  AnigmaAppMac
//
//  Test view for verifying binary integration.
//

import SwiftUI

// NonPersistent
struct BinaryTestView: View, Sendable {
    @State private var binaryManager = BinaryManager()
    @State private var selectedBinary: BinaryManager.AnigmaBinary = .harmonia
    @State private var arguments: String = "--help"
    @State private var isExecuting = false
    @State private var result: BinaryManager.ExecutionResult?
    @State private var error: String?

    var body: some View {
        VStack(spacing: Bauhaus.Grid.x2) {
            // Header
            VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                Text("Binary Test Console")
                    .font(Bauhaus.Font.title)
                    .fontWeight(.bold)

                Text("Test the bundled Anigma binaries")
                    .font(Bauhaus.Font.subHeader)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Binary Status
            GroupBox("Binary Status") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: Bauhaus.Grid.x2) {
                    ForEach(binaryManager.availableBinaries, id: \.name) { binary in
                        BinaryStatusCard(binary: binary, manager: binaryManager)
                    }
                }
                .padding(.vertical, Bauhaus.Grid.unit)
            }

            Divider()

            // Execution Test
            GroupBox("Execution Test") {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
                    // Binary selection
                    Picker("Binary", selection: $selectedBinary) {
                        ForEach(BinaryManager.AnigmaBinary.allCases, id: \.self) { binary in
                            Text(binary.rawValue).tag(binary)
                        }
                    }
                    .accessibilityLabel("Select Binary")

                    // Arguments
                    TextField("Arguments (space-separated)", text: $arguments)
                        .accessibilityLabel("Execution Arguments")
                        .textFieldStyle(.roundedBorder)

                    // Execute button
                    Button(action: executeBinary) {
                        if isExecuting {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: Bauhaus.Grid.x2, height: Bauhaus.Grid.x2)
                        }
                        Text(isExecuting ? "Executing..." : "Execute")
                    }
                    .accessibilityLabel(isExecuting ? "Executing binary" : "Execute binary")
                    .disabled(isExecuting)
                    .primaryButtonStyle()
                }
                .padding(.vertical, Bauhaus.Grid.unit)
            }

            // Results
            if let result = result {
                ResultView(result: result)
            } else if let error = error {
                BinaryExecutionErrorView(error: error)
            }

            Spacer()
        }
        .padding(Bauhaus.Grid.x2)
        .frame(minWidth: 700, minHeight: 600) // OK: Bauhaus form
    }

    private func executeBinary() {
        isExecuting = true
        result = nil
        error = nil

        Task {
            do {
                let args = arguments.split(separator: " ").map(String.init)
                let execResult = try await binaryManager.execute(
                    selectedBinary,
                    arguments: args,
                    timeout: 30
                )
                await MainActor.run {
                    result = execResult
                    isExecuting = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isExecuting = false
                }
            }
        }
    }
}

// MARK: - Supporting Views

// NonPersistent
struct BinaryStatusCard: View, Sendable {
    let binary: BinaryManager.BinaryInfo
    let manager: BinaryManager

    var body: some View {
        HStack(spacing: Bauhaus.Grid.unit + 4) {
            // Status indicator
            Circle()
                .fill(binary.isAvailable ? Bauhaus.Color.success : Bauhaus.Color.error)
                .frame(width: Bauhaus.Grid.unit, height: Bauhaus.Grid.unit)

            VStack(alignment: .leading, spacing: 4) {
                Text(binary.name)
                    .font(Bauhaus.Font.mono)
                    .fontWeight(.medium)

                Text(binary.isAvailable ? "Available" : "Not Found")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            }

            Spacer()

            if binary.isAvailable {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Bauhaus.Color.success)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Bauhaus.Color.error)
            }
        }
        .padding(Bauhaus.Grid.unit + 4)
        .background(Bauhaus.Color.surface)
        .cornerRadius(Bauhaus.Grid.radius)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.radius)
                .stroke(Bauhaus.Color.border, lineWidth: 1)
        )
    }
}

// NonPersistent
struct ResultView: View, Sendable {
    let result: BinaryManager.ExecutionResult

    var body: some View {
        GroupBox("Execution Result") {
            VStack(alignment: .leading, spacing: Bauhaus.Grid.x1) {
                // Exit code
                HStack {
                    Text("Exit Code:")
                        .fontWeight(.semibold)
                    Text("\(result.exitCode)")
                        .font(Bauhaus.Font.mono)
                        .foregroundStyle(result.exitCode == 0 ? Bauhaus.Color.success : Bauhaus.Color.error)
                }

                Divider()

                // Output
                if !result.output.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Output:")
                            .fontWeight(.semibold)
                        ScrollView {
                            Text(result.output)
                                .font(Bauhaus.Font.mono)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 200)
                        .padding(Bauhaus.Grid.unit / 2)
                        .background(Bauhaus.Color.background)
                        .cornerRadius(Bauhaus.Grid.cornerRadiusSmall)
                    }
                }

                // Error
                if !result.error.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Error:")
                            .fontWeight(.semibold)
                        ScrollView {
                            Text(result.error)
                                .font(Bauhaus.Font.mono)
                                .textSelection(.enabled)
                                .foregroundStyle(Bauhaus.Color.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 200)
                        .padding(Bauhaus.Grid.unit / 2)
                        .background(Bauhaus.Color.background)
                        .cornerRadius(Bauhaus.Grid.cornerRadiusSmall)
                    }
                }
            }
            .padding(.vertical, Bauhaus.Grid.unit)
        }
    }
}

// NonPersistent
struct BinaryExecutionErrorView: View, Sendable {
    let error: String

    var body: some View {
        GroupBox {
            HStack(spacing: Bauhaus.Grid.unit + 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Bauhaus.Color.error)
                    .font(.title2)

                Text(error)
                    .foregroundStyle(Bauhaus.Color.error)

                Spacer()
            }
            .padding(Bauhaus.Grid.unit)
        }
    }
}
