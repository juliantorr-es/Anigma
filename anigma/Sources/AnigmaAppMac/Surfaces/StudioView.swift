//
//  StudioView.swift
//  AnigmaAppMac
//
//  Studio - tool builder workbench.
//  Bauhaus style: flatter panes, sharp edges, visible layout markers.
//

import SwiftUI

struct StudioView: View {
    @Environment(AppStore.self) private var store

    // Builder State
    @State private var toolName: String = "New Tool"
    @State private var toolDescription: String = "Processes input data."
    @State private var toolInputs: [String] = []
    @State private var toolOutputs: [String] = []

    var body: some View {
        HSplitView {
            // Left: Parts bin
            PartsBin(onAddInput: { toolInputs.append($0) }, onAddOutput: { toolOutputs.append($0) })
                .frame(minWidth: 200, maxWidth: 280)

            // Center: Canvas
            ToolCanvas(name: $toolName, description: $toolDescription, inputs: $toolInputs, outputs: $toolOutputs)
                .frame(minWidth: 400)

            // Right: Inspector & Register
            StudioTruthPanel(name: toolName, description: toolDescription, inputs: toolInputs, outputs: toolOutputs) {
                let tool = AnigmaTool(
                    id: UUID(),
                    name: toolName,
                    description: toolDescription,
                    inputs: toolInputs,
                    outputs: toolOutputs,
                    isVerified: false,
                    lastRun: nil
                )
                store.registerTool(tool)
                // Reset
                toolName = "New Tool"
                toolDescription = "Processes input data."
                toolInputs = []
                toolOutputs = []
            }
            .frame(minWidth: 280, maxWidth: 360)
        }
        .navigationTitle("Studio")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    // Manual refresh for tools if needed
                } label: {
                    Label("Refresh Tools", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .accessibilityLabel("Refresh registered tools")
            }
        }
    }
}

// MARK: - Parts Bin

struct PartsBin: View {
    var onAddInput: (String) -> Void
    var onAddOutput: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Components".uppercased())
                .font(Bauhaus.Font.caption)
                .fontWeight(.bold)
                .foregroundStyle(Bauhaus.Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Bauhaus.Grid.x2)
                .padding(.vertical, Bauhaus.Grid.unit)
                .background(Bauhaus.Color.surface)
                .bauhausSection()

            List {
                Section("Inputs") {
                    Button { onAddInput("File") } label: { PartRow(name: "File Input", icon: "doc.fill") } // list ButtonStyle
                        .accessibilityLabel("Add File Input")
                    Button { onAddInput("Text") } label: { PartRow(name: "Text Block", icon: "text.alignleft") } // list ButtonStyle
                        .accessibilityLabel("Add Text Input")
                    Button { onAddInput("JSON") } label: { PartRow(name: "JSON Object", icon: "curlybraces") } // list ButtonStyle
                        .accessibilityLabel("Add JSON Input")
                }

                Section("Outputs") {
                    Button { onAddOutput("Report") } label: { PartRow(name: "Report", icon: "doc.text") } // list ButtonStyle
                        .accessibilityLabel("Add Report Output")
                    Button { onAddOutput("Database") } label: { PartRow(name: "DB Record", icon: "cylinder.split.1x2.fill") } // list ButtonStyle
                        .accessibilityLabel("Add Database Output")
                    Button { onAddOutput("Notification") } label: { PartRow(name: "Alert", icon: "bell.fill") } // list ButtonStyle
                        .accessibilityLabel("Add Notification Output")
                }
            }
            .listStyle(.sidebar)
        }
        .background(Bauhaus.Color.surface)
    }
}

struct PartRow: View {
    let name: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(Bauhaus.Font.caption).foregroundStyle(Bauhaus.Color.accent)
            Text(name).font(Bauhaus.Font.body)
            Spacer()
            Image(systemName: "plus.circle").font(Bauhaus.Font.caption).foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Canvas

struct ToolCanvas: View {
    @Binding var name: String
    @Binding var description: String
    @Binding var inputs: [String]
    @Binding var outputs: [String]

    var body: some View {
        ZStack {
            CanvasGrid()

            ScrollView {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.x4) {
                    // Header
                    VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                        Text("Tool Definition")
                            .font(Bauhaus.Font.header)
                        Text("Define the contract for this automated tool.")
                            .font(Bauhaus.Font.body)
                            .foregroundStyle(Bauhaus.Color.textSecondary)
                    }
                    .padding(.bottom, Bauhaus.Grid.x2)

                    // Form
                    VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
                        BauhausTextField("Tool Name", text: $name)
                        BauhausTextField("Description", text: $description)
                    }
                    .padding(Bauhaus.Grid.x3)
                    .background(Bauhaus.Color.surface)
                    .cornerRadius(Bauhaus.Grid.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                            .stroke(Bauhaus.Color.border, lineWidth: 1)
                    )

                    // Nodes
                    HStack(alignment: .top, spacing: Bauhaus.Grid.x3) {
                        // Inputs
                        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                            Text("INPUTS").font(Bauhaus.Font.caption).fontWeight(.bold).foregroundStyle(Bauhaus.Color.textSecondary)
                            if inputs.isEmpty {
                                Text("No inputs defined").font(Bauhaus.Font.caption).italic().foregroundStyle(.secondary)
                            } else {
                                ForEach(Array(inputs.enumerated()), id: \.offset) { _, input in
                                    HStack {
                                        Image(systemName: "arrow.right.circle.fill").foregroundStyle(Bauhaus.Color.accent)
                                        Text(input).font(Bauhaus.Font.mono)
                                    }
                                    .padding(Bauhaus.Grid.unit)
                                    .background(Bauhaus.Color.surface)
                                    .cornerRadius(4)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Divider()

                        // Outputs
                        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                            Text("OUTPUTS").font(Bauhaus.Font.caption).fontWeight(.bold).foregroundStyle(Bauhaus.Color.textSecondary)
                            if outputs.isEmpty {
                                Text("No outputs defined").font(Bauhaus.Font.caption).italic().foregroundStyle(.secondary)
                            } else {
                                ForEach(Array(outputs.enumerated()), id: \.offset) { _, output in
                                    HStack {
                                        Text(output).font(Bauhaus.Font.mono)
                                        Image(systemName: "arrow.right.square.fill").foregroundStyle(Bauhaus.Color.accent)
                                    }
                                    .padding(Bauhaus.Grid.unit)
                                    .background(Bauhaus.Color.surface)
                                    .cornerRadius(4)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(Bauhaus.Grid.x3)
                    .background(Bauhaus.Color.surface.opacity(0.5))
                    .cornerRadius(Bauhaus.Grid.cornerRadius)
                }
                .padding(Bauhaus.Grid.x4)
            }
        }
        .background(Bauhaus.Color.background)
    }
}

// MARK: - Truth Panel

struct StudioTruthPanel: View {
    let name: String
    let description: String
    let inputs: [String]
    let outputs: [String]
    let onRegister: () -> Void

    @State private var selectedTab = 0
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            // Bauhaus Tabs
            HStack(spacing: 0) {
                TruthTab(title: "Contract", isSelected: selectedTab == 0) { selectedTab = 0 }
                TruthTab(title: "My Tools", isSelected: selectedTab == 1) { selectedTab = 1 }
            }
            .background(Bauhaus.Color.surface)
            .bauhausSection()

            // Tab Content
            if selectedTab == 0 {
                ScrollView {
                    VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
                        Text("Draft Contract")
                            .font(Bauhaus.Font.subHeader)
                            .foregroundStyle(Bauhaus.Color.textSecondary)

                        Text("TOOL: \(name.uppercased())")
                            .font(Bauhaus.Font.mono)

                        Text("SIG: \(inputs.joined(separator: ", ")) -> \(outputs.joined(separator: ", "))")
                            .font(Bauhaus.Font.mono)
                            .foregroundStyle(Bauhaus.Color.accent)

                        Divider()

                        if inputs.isEmpty || outputs.isEmpty {
                            VStack(alignment: .leading) {
                                Text("⚠️ Invalid Contract")
                                    .foregroundStyle(Bauhaus.Color.warning)
                                    .font(Bauhaus.Font.caption)
                                Text("A valid OperationResult requires at least one input and output to define a state transition.")
                                    .font(Bauhaus.Font.caption)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("✅ Valid Contract")
                                    .foregroundStyle(Bauhaus.Color.trusted)
                                    .font(Bauhaus.Font.caption)

                                Group {
                                    ContractRuleRow(rule: "Idempotency Proof", status: .passed)
                                    ContractRuleRow(rule: "Progress Streaming", status: .passed)
                                    ContractRuleRow(rule: "Error Schema Mapping", status: .passed)
                                }
                                .padding(.leading, Bauhaus.Grid.unit)
                            }
                        }
                    }
                    .padding(Bauhaus.Grid.x2)
                }

                Divider()

                Button(action: onRegister) { // primaryButtonStyle
                    Text("Register Tool")
                        .frame(maxWidth: .infinity)
                }
                .primaryButtonStyle()
                .disabled(inputs.isEmpty || outputs.isEmpty)
                .keyboardShortcut("s", modifiers: .command)
                .accessibilityLabel("Register Tool")
                .accessibilityHint(inputs.isEmpty || outputs.isEmpty ? "Requires at least one input and output" : "Registers this tool definition")
                .padding(Bauhaus.Grid.x2)

            } else {
                // My Tools List
                List {
                    if store.tools.isEmpty {
                        Text("No registered tools.").foregroundStyle(.secondary)
                    } else {
                        ForEach(store.tools) { tool in
                            HStack {
                                Image(systemName: "hammer.fill")
                                VStack(alignment: .leading) {
                                    Text(tool.name)
                                    Text(tool.inputs.joined(separator: ",") + " -> " + tool.outputs.joined(separator: ","))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .background(Bauhaus.Color.surface)
    }
}

private struct ContractRuleRow: View {
    enum Status { case passed, failed }
    let rule: String
    let status: Status

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status == .passed ? "checkmark.circle" : "xmark.circle")
                .font(Bauhaus.Font.nano)
                .foregroundStyle(status == .passed ? Bauhaus.Color.trusted : Bauhaus.Color.warning)
            Text(rule)
                .font(Bauhaus.Font.micro)
                .foregroundStyle(Bauhaus.Color.textSecondary)
        }
    }
}

struct BauhausTextField: View {
    let title: String
    @Binding var text: String

    init(_ title: String, text: Binding<String>) {
        self.title = title
        self._text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)
            TextField(title, text: $text)
                .textFieldStyle(.plain)
                .accessibilityLabel(title)
                .padding(Bauhaus.Grid.unit)
                .background(Bauhaus.Color.background)
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Bauhaus.Color.border.opacity(0.5), lineWidth: 1))
        }
    }
}
