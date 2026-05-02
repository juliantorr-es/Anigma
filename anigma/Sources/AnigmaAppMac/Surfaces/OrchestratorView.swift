import AnigmaClientKit
//
//  OrchestratorView.swift
//  AnigmaAppMac
//
//  UI for the Local LLM Orchestrator - allows users to orchestrate CLI agents
//  using a local language model as the decision-making brain.
//

import SwiftUI

struct OrchestratorView: View {
    @Environment(AppStore.self) private var store
    @State private var orchestrator: LocalLLMOrchestrator?
    @State private var inputText: String = ""

    @State private var showToolDiscovery = false

    init() {
        // Orchestrator initialization will occur in .onAppear using the store
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Local LLM Orchestrator")
                .font(Bauhaus.Font.header)
            Text("Coming Soon - Initializing orchestration infrastructure...")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Bauhaus.Color.background)
        .padding()
        // TODO: Implement orchestrator initialization with MLWorkerClient
        // This view requires LocalLLMOrchestrator setup which depends on AppStore.mlWorkerClient
    }

    // MARK: - Header

    private var orchestratorHeader: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .font(Bauhaus.Font.subHeader)
                .foregroundStyle(Bauhaus.Color.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Local LLM Orchestrator")
                    .font(Bauhaus.Font.header)
                Text("Coordinate CLI agents with local AI")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            }

            Spacer()

            // Tool count badge
            if let orchestrator = orchestrator {
                Button {
                    showToolDiscovery = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "wrench.and.screwdriver")
                        Text("\(orchestrator.availableTools.filter { $0.isInstalled }.count) tools")
                    }
                    .font(Bauhaus.Font.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Bauhaus.Color.surfaceElevated)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Button {
                    orchestrator.clearConversation()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .help("Clear conversation")
            }
        }
        .padding()
        .background(Bauhaus.Color.surface)
    }

    // MARK: - Conversation Panel

    private var conversationPanel: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
                    if let orchestrator = orchestrator {
                        ForEach(orchestrator.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding()
            }
            .onChange(of: orchestrator?.messages.count ?? 0) { _, _ in
                if let lastMessage = orchestrator?.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
        .background(Bauhaus.Color.background)
    }

    // MARK: - Plan Panel

    private var planPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Plan header
            HStack {
                Text("EXECUTION PLAN")
                    .font(Bauhaus.Font.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
                Spacer()
            }
            .padding()
            .background(Bauhaus.Color.surface)

            Divider()

            if let plan = orchestrator?.currentPlan {
                ScrollView {
                    VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
                        // Reasoning
                        Text(plan.reasoning)
                            .font(Bauhaus.Font.caption)
                            .foregroundStyle(Bauhaus.Color.textSecondary)
                            .padding()
                            .background(Bauhaus.Color.surface.opacity(0.5))
                            .cornerRadius(8)

                        // Steps
                        ForEach(Array(plan.steps.enumerated()), id: \.offset) { index, step in
                            PlanStepRow(
                                step: step,
                                isActive: index == (orchestrator?.currentStepIndex ?? 0) && (orchestrator?.isProcessing ?? false)
                            )
                        }
                    }
                    .padding()
                }
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "list.bullet.clipboard")
                        .font(Bauhaus.Font.displayL)
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                    Text("No active plan")
                        .font(Bauhaus.Font.body)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                    Text("Submit a task to generate a plan")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                    Spacer()
                }
            }

            Divider()

            // Available tools quick view
            VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                Text("AVAILABLE TOOLS")
                    .font(Bauhaus.Font.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Bauhaus.Color.textSecondary)

                if let orchestrator = orchestrator {
                    ForEach(orchestrator.availableTools.filter { $0.isInstalled }) { tool in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Bauhaus.Color.trusted)
                                .frame(width: 6, height: 6) // OK: Bauhaus dot
                            Text(tool.tool.displayName)
                                .font(Bauhaus.Font.caption)
                        }
                    }

                    if orchestrator.availableTools.filter({ $0.isInstalled }).isEmpty {
                        Text("No tools installed")
                            .font(Bauhaus.Font.caption)
                            .foregroundStyle(Bauhaus.Color.warning)
                    }
                }
            }
            .padding()
            .background(Bauhaus.Color.surface)
        }
        .background(Bauhaus.Color.surfaceElevated.opacity(0.5))
    }

    // MARK: - Input Area

    private var inputArea: some View {
        HStack(spacing: Bauhaus.Grid.x2) {
            TextField("Describe what you want to accomplish...", text: $inputText, axis: .vertical)
                .accessibilityLabel("Task input")
                .textFieldStyle(.plain)
                .font(Bauhaus.Font.body)
                .lineLimit(1...5)
                .padding(Bauhaus.Grid.x2)
                .background(Bauhaus.Color.surface)
                .cornerRadius(8)

            Button {
                submitTask()
            } label: {
                if orchestrator?.isProcessing ?? false {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: Bauhaus.Grid.x3, height: Bauhaus.Grid.x3)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(Bauhaus.Font.subHeader)
                }
            }
            .primaryButtonStyle()
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (orchestrator?.isProcessing ?? false))
            .keyboardShortcut(.return, modifiers: .command)
            .accessibilityLabel("Submit task")
        }
        .padding()
        .background(Bauhaus.Color.surface)
    }

    // MARK: - Actions

    private func submitTask() {
        let task = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !task.isEmpty else { return }

        inputText = ""

        guard let workspace = store.workspaceStore.activeWorkspace else {
            orchestrator?.addMessage(.system, "⚠️ No workspace selected. Please open a repository first.")
            return
        }
        guard let orchestrator else { return }

        Task {
            await orchestrator.submitTask(
                task,
                workspace: WorkspaceSummary(
                    id: workspace.id.uuidString,
                    name: workspace.name,
                    description: workspace.rootURL.path
                )
            )
        }
    }
}

// MARK: - Supporting Views

private struct MessageBubble: View {
    let message: OrchestratorMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            roleIcon
                .frame(width: 28, height: 28) // OK: Bauhaus avatar
                .background(roleColor.opacity(0.1))
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 4) {
                // Role label
                HStack {
                    Text(roleLabel)
                        .font(Bauhaus.Font.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(roleColor)

                    if let toolCall = message.toolCall {
                        let tool = CLIToolRegistry.Tool(rawValue: toolCall.toolName)
                        Text("• \(tool?.displayName ?? toolCall.toolName)")
                            .font(Bauhaus.Font.caption)
                            .foregroundStyle(Bauhaus.Color.textSecondary)
                    }

                    Spacer()

                    Text(message.timestamp, style: .time)
                        .font(Bauhaus.Font.monoMicro)
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                }

                // Content
                Text(LocalizedStringKey(message.content))
                    .font(message.role == .tool ? Bauhaus.Font.mono : Bauhaus.Font.body)
                    .textSelection(.enabled)
            }
        }
        .padding()
        .background(bubbleBackground)
        .cornerRadius(Bauhaus.Grid.cornerRadius)
    }

    private var roleIcon: some View {
        Image(systemName: roleIconName)
            .foregroundStyle(roleColor)
    }

    private var roleIconName: String {
        switch message.role {
        case .user: return "person.fill"
        case .orchestrator: return "brain.head.profile"
        case .tool: return "terminal.fill"
        case .system: return "info.circle.fill"
        }
    }

    private var roleLabel: String {
        switch message.role {
        case .user: return "You"
        case .orchestrator: return "Orchestrator"
        case .tool: return "Tool Output"
        case .system: return "System"
        }
    }

    private var roleColor: Color {
        switch message.role {
        case .user: return Bauhaus.Color.accent
        case .orchestrator: return Bauhaus.Color.trusted
        case .tool: return Bauhaus.Color.textSecondary
        case .system: return Bauhaus.Color.warning
        }
    }

    private var bubbleBackground: Color {
        switch message.role {
        case .user: return Bauhaus.Color.accent.opacity(0.1)
        case .orchestrator: return Bauhaus.Color.surface
        case .tool: return Bauhaus.Color.surface.opacity(0.7)
        case .system: return Bauhaus.Color.warning.opacity(0.1)
        }
    }
}

private struct PlanStepRow: View {
    let step: OrchestrationStep
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.1))
                    .frame(width: 28, height: 28) // OK: Bauhaus step

                if isActive {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: statusIcon)
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(statusColor)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Step \(step.order)")
                        .font(Bauhaus.Font.caption)
                        .fontWeight(.semibold)
                    Text("• \(step.tool.displayName)")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                }

                Text(step.instruction)
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(Bauhaus.Grid.unit)
        .background(isActive ? Bauhaus.Color.accent.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }

    private var statusColor: Color {
        switch step.status {
        case .pending: return Bauhaus.Color.textTertiary
        case .running: return Bauhaus.Color.accent
        case .completed: return Bauhaus.Color.trusted
        case .failed: return Bauhaus.Color.error
        case .skipped: return Bauhaus.Color.textTertiary
        }
    }

    private var statusIcon: String {
        switch step.status {
        case .pending: return "circle"
        case .running: return "play.fill"
        case .completed: return "checkmark"
        case .failed: return "xmark"
        case .skipped: return "forward.fill"
        }
    }
}

// MARK: - Tool Discovery Sheet

struct ToolDiscoverySheet: View {
    let orchestrator: LocalLLMOrchestrator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Installed") {
                    ForEach(orchestrator.availableTools.filter { $0.isInstalled }) { tool in
                        ToolRow(availability: tool, isInstalled: true)
                    }
                }

                Section("Not Installed") {
                    ForEach(orchestrator.availableTools.filter { !$0.isInstalled }) { tool in
                        ToolRow(availability: tool, isInstalled: false)
                    }
                }
            }
            .navigationTitle("CLI Agents")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() } // primaryButtonStyle
                        .primaryButtonStyle()
                        .accessibilityLabel("Close tool discovery")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await orchestrator.refreshAvailableTools()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh tool availability")
                    .accessibilityLabel("Refresh tool availability")
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

private struct ToolRow: View {
    let availability: ToolAvailability
    let isInstalled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(availability.tool.displayName)
                    .font(Bauhaus.Font.bodyBold)

                Spacer()

                if isInstalled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Bauhaus.Color.trusted)
                }
            }

            Text(availability.tool.description)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            if isInstalled {
                if let path = availability.binaryPath {
                    Text(path)
                        .font(Bauhaus.Font.mono)
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                }

                if let version = availability.version {
                    Text("v\(version)")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.accent)
                }
            } else {
                HStack {
                    Text("Strengths:")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                    Text(availability.tool.strengths.joined(separator: ", "))
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
