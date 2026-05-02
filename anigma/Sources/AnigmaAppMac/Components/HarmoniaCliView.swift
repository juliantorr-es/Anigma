//
//  HarmoniaCliView.swift
//  AnigmaAppMac
//
//  Dedicated Harmonia CLI surface for command execution, streaming output, and history.
//

import SwiftUI

@MainActor
struct HarmoniaCliView: View {
    @State private var session: HarmoniaCliSession

    init(
        backendResolver: @escaping @MainActor () -> (any HarmoniaCliExecution)?,
        history: HarmoniaCommandHistory
    ) {
        _session = State(initialValue: HarmoniaCliSession(history: history, backendResolver: backendResolver))
    }

    var body: some View {
        @Bindable var session = session

        HSplitView {
            mainCliSurface(session: session)
                .frame(minWidth: 500)

            if session.showHistory {
                historySidebar(session: session)
                    .frame(minWidth: 300, idealWidth: 350, maxWidth: 500)
            }
        }
        .frame(minWidth: 800, idealWidth: 1000, minHeight: 600, idealHeight: 700)
        .background(Bauhaus.Color.background)
    }

    private func mainCliSurface(session: HarmoniaCliSession) -> some View {
        VStack(spacing: 0) {
            headerView(session: session)

            relatedActionsView(session: session)

            Divider()

            outputConsole(session: session)

            Divider()

            commandInputView(session: session)
        }
    }

    private func headerView(session: HarmoniaCliSession) -> some View {
        HStack(spacing: Bauhaus.Grid.x2) {
            Image(systemName: "terminal")
                .font(.title2)
                .foregroundStyle(Bauhaus.Color.accent)

            Text("Harmonia CLI")
                .font(Bauhaus.Font.header)

            Spacer()

            HStack(spacing: Bauhaus.Grid.unit) {
                Bauhaus.StatusDot(state: session.isBackendAvailable ? .running : .blocked)
                Text(session.isBackendAvailable ? session.backendStatusLabel : "Unavailable")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(session.isBackendAvailable ? Bauhaus.Color.textSecondary : Bauhaus.Color.error)
            }

            Button(action: { session.showHistory.toggle() }) {
                Label("History", systemImage: session.showHistory ? "sidebar.right" : "sidebar.left")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help(session.showHistory ? "Hide History" : "Show History")

            Button(action: { session.commandInput = "" }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            }
            .buttonStyle(.borderless)
            .help("Clear command input")
        }
        .padding(Bauhaus.Grid.x3)
    }

    private func relatedActionsView(session: HarmoniaCliSession) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Bauhaus.Grid.unit) {
                Text("Assistant shortcuts")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textTertiary)
                    .padding(.trailing, Bauhaus.Grid.unit)

                quickCommandButton("search \"<query>\"", description: "Find ledger items", session: session)
                quickCommandButton("techdebt audit .", description: "Check code health", session: session)
                quickCommandButton("vault status", description: "Inspect vault", session: session)
                quickCommandButton("vault verify", description: "Verify integrity", session: session)
                quickCommandButton("vault gc --dry-run", description: "Preview cleanup", session: session)
            }
            .padding(.horizontal, Bauhaus.Grid.x3)
            .padding(.vertical, Bauhaus.Grid.unit)
        }
        .background(Bauhaus.Color.surface)
    }

    private func outputConsole(session: HarmoniaCliSession) -> some View {
        Group {
            if session.outputLines.isEmpty && !session.isExecuting {
                emptyStateView(session: session)
            } else {
                ConsoleView(logs: session.outputLines)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyStateView(session: HarmoniaCliSession) -> some View {
        VStack(spacing: Bauhaus.Grid.x3) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 48))
                .foregroundStyle(Bauhaus.Color.textTertiary)

            Text("Assistant-ready command surface")
                .font(Bauhaus.Font.header)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            Text("Use a shortcut below or type directly into the command line")
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textTertiary)

            VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                Text("Quick commands")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)

                quickCommandButton("--version", description: "Check version", session: session)
                quickCommandButton("daemon status", description: "Check daemon status", session: session)
                quickCommandButton("vault status", description: "Check vault status", session: session)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Empty console, ready for commands")
    }

    private func quickCommandButton(
        _ command: String,
        description: String,
        session: HarmoniaCliSession
    ) -> some View {
        Button(action: {
            session.commandInput = command
        }) {
            HStack(spacing: Bauhaus.Grid.unit) {
                Text(command)
                    .font(Bauhaus.Font.mono)
                    .foregroundStyle(Bauhaus.Color.accent)

                Text("—")
                    .foregroundStyle(Bauhaus.Color.textTertiary)

                Text(description)
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Bauhaus.Grid.x2)
        .padding(.vertical, Bauhaus.Grid.unit)
        .background(Bauhaus.Color.surface)
        .cornerRadius(Bauhaus.Grid.cornerRadiusSmall)
    }

    private func commandInputView(session: HarmoniaCliSession) -> some View {
        HStack(spacing: Bauhaus.Grid.x2) {
            Text("harmonia")
                .font(Bauhaus.Font.mono)
                .foregroundStyle(Bauhaus.Color.textTertiary)

            TextField("Enter command...", text: $session.commandInput)
                .textFieldStyle(.plain)
                .font(Bauhaus.Font.mono)
                .disabled(session.isExecuting)
                .onSubmit {
                    session.executeCommand()
                }

            if session.isExecuting {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 100)
            } else {
                Button(action: session.executeCommand) {
                    Label("Execute", systemImage: "play.fill")
                }
                .primaryButtonStyle()
                .disabled(session.commandInput.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.return, modifiers: [.command])
            }

            Button(action: session.clearOutput) {
                Label("Clear", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
            .secondaryButtonStyle()
            .help("Clear output")
        }
        .padding(Bauhaus.Grid.x3)
        .background(Bauhaus.Color.surface)
    }

    private func historySidebar(session: HarmoniaCliSession) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Command History")
                    .font(Bauhaus.Font.subHeader)

                Spacer()

                if !session.history.entries.isEmpty {
                    Button(action: {
                        session.clearHistory()
                    }) {
                        Image(systemName: "trash")
                            .foregroundStyle(Bauhaus.Color.error)
                    }
                    .buttonStyle(.borderless)
                    .help("Clear history")
                }
            }
            .padding(Bauhaus.Grid.x3)

            Divider()

            ScrollView {
                LazyVStack(spacing: Bauhaus.Grid.unit) {
                    if session.history.entries.isEmpty {
                        Text("No history available")
                            .font(Bauhaus.Font.caption)
                            .foregroundStyle(Bauhaus.Color.textTertiary)
                            .padding(Bauhaus.Grid.x3)
                    } else {
                        ForEach(session.history.entries.prefix(50)) { entry in
                            historyEntryRow(entry, session: session)
                        }
                    }
                }
                .padding(Bauhaus.Grid.x2)
            }
        }
        .background(Bauhaus.Color.surface)
    }

    private func historyEntryRow(
        _ entry: HarmoniaCommandHistory.HistoryEntry,
        session: HarmoniaCliSession
    ) -> some View {
        Button(action: {
            session.selectedHistoryEntry = entry
            session.loadHistoryEntry(entry)
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Bauhaus.Grid.unit) {
                    Image(systemName: entry.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(entry.success ? Bauhaus.Color.success : Bauhaus.Color.error)

                    Text(entry.fullCommand)
                        .font(Bauhaus.Font.mono)
                        .foregroundStyle(Bauhaus.Color.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HStack(spacing: Bauhaus.Grid.unit) {
                    Text(formatRelativeDate(entry.timestamp))
                        .font(Bauhaus.Font.monoMicro)
                        .foregroundStyle(Bauhaus.Color.textTertiary)

                    Text("•")
                        .foregroundStyle(Bauhaus.Color.textTertiary)

                    Text(entry.formattedDuration)
                        .font(Bauhaus.Font.monoMicro)
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Bauhaus.Grid.x2)
            .background(session.selectedHistoryEntry?.id == entry.id ? Bauhaus.Color.accent.opacity(0.1) : Color.clear)
            .cornerRadius(Bauhaus.Grid.cornerRadiusSmall)
        }
        .buttonStyle(.plain)
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

