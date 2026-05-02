//
//  OmniBar.swift
//  AnigmaAppMac
//
//  Command palette - the ONE front door.
//  Shows action palette on focus, adapts to current mode and surface.
//

import SwiftUI
import UniformTypeIdentifiers
import AnigmaClientKit

// MARK: - Omni Scope

enum OmniScope: Equatable {
    case all
    case inbox
    case project(String)
    case selection(Int)

    var label: String {
        switch self {
        case .all: return "All content"
        case .inbox: return "Inbox"
        case .project(let name): return "Project: \(name)"
        case .selection(let count): return "\(count) selected"
        }
    }

    var icon: String {
        switch self {
        case .all: return "square.stack.3d.up"
        case .inbox: return "tray.fill"
        case .project: return "folder.fill"
        case .selection: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Omni Action

struct OmniAction: Identifiable {
    let id: String
    var job: AnigmaClientKit.JobSummary? // Made optional as some actions might not directly map to a job
    let title: String
    let subtitle: String
    let icon: String
    let shortcut: String?
    let modes: Set<AppMode>
    let action: () -> Void
}

// MARK: - OmniBar

struct OmniBar: View {
    @Environment(AppStore.self) private var store
    @State private var query = ""
    @State private var isExpanded = false
    @State private var isDropTargeted = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Main bar
            HStack(spacing: 12) {
                // Scope chip
                ScopeChip(scope: currentScope)

                // Divider
                Rectangle()
                    .fill(Bauhaus.Color.border)
                    .frame(width: 1, height: 20)

                // Input
                Image(systemName: "command")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Bauhaus.Color.textTertiary)

                TextField(placeholder, text: $query)
                    .textFieldStyle(.plain)
                    .font(Bauhaus.Font.body)
                    .focused($isFocused)
                    .onSubmit {
                        handleSubmit()
                    }
                    .accessibilityLabel("Command Palette")
                    .accessibilityHint("Type to search commands or files. Press Return to execute.")

                // Shortcut hint
                if !isFocused {
                    Text("⌘K")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Bauhaus.Color.border)
                        .cornerRadius(3)
                }
            }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .background(Bauhaus.Color.cardBackground.opacity(0.4))
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                .stroke(isFocused ? Bauhaus.Color.accent : Bauhaus.Color.border, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(isFocused ? 0.15 : 0.05), radius: isFocused ? 12 : 4, x: 0, y: isFocused ? 6 : 2)
        .clipShape(RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius))
            .onTapGesture {
                isFocused = true
                isExpanded = true
            }

            // Action palette (shown when focused)
            if isExpanded && isFocused {
                ActionPalette(query: query) { action in
                    action.action()
                    isExpanded = false
                    isFocused = false
                    query = ""
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeOut(duration: 0.15), value: isExpanded)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
        .onChange(of: isFocused) { _, focused in
            if !focused {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(100))
                    isExpanded = false
                }
            }
        }
        .onChange(of: store.focusOmniBar) { _, _ in
            isFocused = true
            isExpanded = true
        }
    }

    private var currentScope: OmniScope {
        if let _ = store.inspectorSelection {
            return .selection(1)
        } else if store.userSurface == .inbox {
            return .inbox
        } else if let workspace = store.workspaces.first(where: { $0.id == store.selectedWorkspaceID }) {
            return .project(workspace.name)
        }
        return .all
    }

    private var placeholder: String {
        switch store.mode {
        case .life:
            return "Ask, import, or start a project…"
        case .develop:
            return "Search files, symbols, or run commands…"
        case .work:
            return "Triage, extract deadlines, or generate deliverables…"
        case .insight:
            return "Map entities, find contradictions, or verify claims…"
        case .build:
            return "Run, build, or export…"
        }
    }

    private func handleSubmit() {
        guard !query.isEmpty else { return }

        // Route based on query
        if query.contains("?") || query.lowercased().starts(with: "what") || query.lowercased().starts(with: "how") {
            store.userSurface = .ask
        }

        query = ""
        isExpanded = false
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }

                Task { @MainActor in
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        if let fileData = try? Data(contentsOf: url) {
                            await store.uploadArtifact(name: url.lastPathComponent, data: fileData)
                            store.userSurface = .inbox
                        }
                    }
                }
            }
        }
        return true
    }
}

// MARK: - Scope Chip

struct ScopeChip: View {
    let scope: OmniScope

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: scope.icon)
                .font(.system(size: 10))
            Text(scope.label)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Bauhaus.Color.accent.opacity(0.1))
        .foregroundStyle(Bauhaus.Color.accent)
        .overlay(
            Capsule()
                .stroke(Bauhaus.Color.accent.opacity(0.2), lineWidth: 0.5)
        )
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Scope: \(scope.label)")
        .accessibilityHint("Limits commands to the current context.")
    }
}

// MARK: - Action Palette

struct ActionPalette: View {
    @Environment(AppStore.self) private var store
    let query: String
    let onSelect: (OmniAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Actions filtered by mode and query
            ForEach(filteredActions) { action in
                OmniActionRow(action: action) {
                    onSelect(action)
                }
            }

            if filteredActions.isEmpty {
                Text("No matching actions")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textTertiary)
                    .padding(Bauhaus.Grid.x2)
            }
        }
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .background(Bauhaus.Color.cardBackground.opacity(0.6))
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                .stroke(Bauhaus.Color.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius))
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .padding(.top, 4)
    }

    private var allActions: [OmniAction] {
        [
            // --- LIFE VERBS ---
            OmniAction(id: "ocr", title: "OCR Document", subtitle: "Extract text from local images/PDFs", icon: "text.viewfinder", shortcut: Optional<String>.none, modes: Set<AppMode>([.life])) {
                Task { await store.submitJob(action: "ocr", parameters: [:]) }
            },
            OmniAction(id: "translate", title: "Translate", subtitle: "Governed local translation", icon: "globe", shortcut: Optional<String>.none, modes: Set<AppMode>([.life])) {
                Task { await store.submitJob(action: "translate", parameters: [:]) }
            },

            // --- DEVELOP VERBS ---
            OmniAction(id: "refactor", title: "Refactor Module", subtitle: "Propose structural improvements", icon: "square.grid.3x1.below.line.grid.1x2", shortcut: Optional<String>.none, modes: Set<AppMode>([.develop])) {
                Task { await store.submitJob(action: "refactor", parameters: [:]) }
            },
            OmniAction(id: "test", title: "Run Test Suite", subtitle: "Execute check profile", icon: "play.circle", shortcut: "T", modes: Set<AppMode>([.develop])) {
                Task { await store.submitJob(action: "test", parameters: [:]) }
            },
            OmniAction(id: "sync", title: "Sync Repository", subtitle: "Verify index and git head", icon: "arrow.triangle.2.circlepath", shortcut: Optional<String>.none, modes: Set<AppMode>([.develop])) {
                Task { await store.submitJob(action: "sync", parameters: [:]) }
            },

            OmniAction(id: "summarize", title: "Summarize", subtitle: "Briefing of selected content", icon: "text.quote", shortcut: Optional<String>.none, modes: Set<AppMode>([.life, .work])) {
                Task { await store.submitJob(action: "summarize", parameters: [:]) }
            },

            // --- WORK VERBS ---
            OmniAction(id: "triage", title: "Triage Inbox", subtitle: "File items into project workspaces", icon: "tray.and.arrow.down.fill", shortcut: "⌘T", modes: Set<AppMode>([.work])) {
                store.userSurface = .inbox
            },
            OmniAction(id: "run-deadline-scan", title: "Extract Deadlines", subtitle: "Scan inbox for dates", icon: "calendar.badge.clock", shortcut: Optional<String>.none, modes: Set<AppMode>([.life, .work])) {
                Task { await store.submitJob(action: "extract_deadlines", parameters: [:]) }
            },
            OmniAction(id: "dossier", title: "Create Dossier", subtitle: "Package artifacts for a project", icon: "briefcase.fill", shortcut: Optional<String>.none, modes: Set<AppMode>([.work])) {
                Task { await store.submitJob(action: "create_dossier", parameters: [:]) }
            },
            OmniAction(id: "deliverable", title: "Generate Deliverable", subtitle: "Draft output for this project", icon: "doc.badge.plus", shortcut: Optional<String>.none, modes: Set<AppMode>([.work])) {
                store.userSurface = .ask // Could trigger a specialized view
            },

            // --- INSIGHT VERBS ---
            OmniAction(id: "map-entities", title: "Map Entities", subtitle: "Build relationship graph", icon: "person.2.circle.fill", shortcut: Optional<String>.none, modes: Set<AppMode>([.insight])) {
                store.userSurface = .atlas
                Task { await store.submitJob(action: "map_entities", parameters: [:]) }
            },
            OmniAction(id: "contradictions", title: "Find Contradictions", subtitle: "Detect conflicting data points", icon: "exclamationmark.triangle.fill", shortcut: Optional<String>.none, modes: Set<AppMode>([.insight])) {
                Task { await store.submitJob(action: "find_contradictions", parameters: [:]) }
            },
            OmniAction(id: "verify-claims", title: "Verify Claims", subtitle: "Cross-reference with receipts/evidence", icon: "checkmark.shield.fill", shortcut: Optional<String>.none, modes: Set<AppMode>([.insight])) {
                Task { await store.submitJob(action: "verify_claims", parameters: [:]) }
            },

            // --- BUILD VERBS ---
            OmniAction(id: "create-project", title: "New Project", subtitle: "Create a governed workspace", icon: "folder.badge.plus", shortcut: "⌘N", modes: Set<AppMode>([.life, .work, .develop])) {
                store.userSurface = .studio
            },
            OmniAction(id: "action-catalog", title: "Action Catalog", subtitle: "View all underlying capabilities", icon: "tray.2.fill", shortcut: Optional<String>.none, modes: Set<AppMode>([.build])) {
                store.userSurface = .activity // Transition to catalog view
            },

            // --- SHARED ---
            OmniAction(id: "connect-sources", title: "Connect Sources", subtitle: "Mac, Email, Photos", icon: "link.badge.plus", shortcut: "⌘K", modes: Set<AppMode>([AppMode.life, AppMode.work, AppMode.insight])) {
                store.isSourceConnectionPresented = true
            }
        ]
    }

    private var filteredActions: [OmniAction] {
        let modeActions = allActions.filter { $0.modes.contains(store.mode) }

        if query.isEmpty {
            return modeActions
        }

        return modeActions.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }
}

struct OmniActionRow: View {
    let action: OmniAction
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: action.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Bauhaus.Color.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(action.title)
                        .font(Bauhaus.Font.body)
                    Text(action.subtitle)
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                }

                Spacer()

                if let shortcut = action.shortcut {
                    Text(shortcut)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered ? Bauhaus.Color.accent.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(action.title), \(action.subtitle)")
        .accessibilityHint(action.shortcut.map { "Shortcut \( $0 ). Activate to run." } ?? "Activate to run.")
    }
}

