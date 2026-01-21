//
//  ProjectPlanningView.swift
//  AnigmaAppMac
//
//  Project Planning - curating a deliverable set from a context.
//  Bauhaus utility: clear inputs, structured steps.
//

import SwiftUI
import AnigmaClientKit

struct ProjectPlanningView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var projectName: String = ""
    @State private var selectedContextId: UUID?
    @State private var governanceLevel: GovernanceMode = .local
    @State private var showSuccess = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PROJECT PLANNING")
                        .font(Bauhaus.Font.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                    Text("Define Governance & Scope")
                        .font(Bauhaus.Font.header)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(Bauhaus.Font.displayS)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(Bauhaus.Grid.x4)
            .background(Bauhaus.Color.surface)
            .bauhausSection()

            Form {
                Section("Identity") {
                    TextField("Project Name", text: $projectName)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Project Name")
                }

                Section("Context (Knowledge Source)") {
                    Picker("Active Context", selection: $selectedContextId) {
                        Text("Select a context").tag(Optional<UUID>.none)
                        ForEach(store.contexts) { context in
                            Text(context.name).tag(Optional(context.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Select knowledge context")
                    .accessibilityHint("Choose which context to use as the knowledge source for this project")
                }

                Section("Governance") {
                    Picker("Trust Boundary", selection: $governanceLevel) {
                        Text("Local Only (Private)").tag(GovernanceMode.local)
                        Text("Verify Only (Ledgered)").tag(GovernanceMode.verify)
                        Text("Trusted Host").tag(GovernanceMode.trusted)
                        Text("Ungoverned").tag(GovernanceMode.off)
                    }
                    .pickerStyle(.radioGroup)
                    .accessibilityLabel("Select trust boundary")
                    .accessibilityHint("Choose the governance level for this project")

                    Text(governanceHint)
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                        .padding(.top, 4)
                }
            }
            .formStyle(.grouped)

            Spacer()

            // Footer
            HStack {
                Button("Cancel") { dismiss() } // plain ButtonStyle
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel project creation")

                Spacer()

                Button("Create Project") { // primaryButtonStyle
                    createProject()
                }
                .primaryButtonStyle()
                .disabled(projectName.isEmpty || selectedContextId == nil)
                .accessibilityLabel("Create project")
                .accessibilityHint("Creates a new project with the specified name and context")
            }
            .padding(Bauhaus.Grid.x4)
            .background(Bauhaus.Color.surface)
            .bauhausSection()
        }
        .frame(width: 450, height: 500) // OK: Bauhaus form
        .background(Bauhaus.Color.background)
        .alert("Project Created", isPresented: $showSuccess) {
            Button("OK") { dismiss() } // alert ButtonStyle
                .accessibilityLabel("Dismiss success message")
        } message: {
            Text("Your new project '\(projectName)' is ready in the workbench.")
        }
    }

    private var governanceHint: String {
        switch governanceLevel {
        case .local: return "Data never leaves this machine. No external verification."
        case .verify: return "Activity is logged to the local ledger with cryptographic receipts."
        case .trusted: return "Operations run on a trusted host with governance controls enabled."
        case .off: return "No governance enforcement; use only in isolated environments."
        }
    }

    private func createProject() {
        // In a real implementation, this would call store.createProject(...)
        // For now, we simulate success and show a toast.
        store.showToast(
            title: "Project Initialized",
            subtitle: projectName,
            icon: "folder.badge.plus"
        )

        // Switch to the projects surface
        store.userSurface = .projects
        showSuccess = true
    }
}

#Preview {
    ProjectPlanningView()
        .environment(AppStore())
}
