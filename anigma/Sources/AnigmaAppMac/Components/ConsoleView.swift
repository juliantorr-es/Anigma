//
//  ConsoleView.swift
//  AnigmaAppMac
//
//  Streaming console for agent execution logs
//

import SwiftUI

// NonPersistent
struct ConsoleView: View, Sendable {
    let logs: [ConsoleEntry]
    @State private var scrollToBottom = true

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(logs) { entry in
                        HStack(alignment: .top, spacing: Bauhaus.Grid.x2) {
                            Text(entry.timestamp, style: .time)
                                .font(Bauhaus.Font.monoMicro)
                                .foregroundStyle(Bauhaus.Color.textSecondary)
                                .frame(width: 80, alignment: .leading) // OK: Fixed timestamp width

                            Image(systemName: entry.icon)
                                .font(Bauhaus.Font.small)
                                .foregroundStyle(entry.color)
                                .frame(width: Bauhaus.Grid.x2)
                                .accessibilityHidden(true)

                            Text(entry.message)
                                .font(Bauhaus.Font.caption)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, Bauhaus.Grid.x2)
                        .padding(.vertical, Bauhaus.Grid.unit / 2)
                        .background(entry.isError ? Bauhaus.Color.error.opacity(0.05) : Color.clear)
                        .id(entry.id)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(entry.level.rawValue): \(entry.message)")
                    }
                }
                .padding(.vertical, Bauhaus.Grid.unit)
            }
            .background(Bauhaus.Color.surfaceElevated.opacity(0.9))
            .onChange(of: logs.count) { _, _ in
                // Only auto-scroll if VoiceOver is not active, or if user explicitly enabled it
                if scrollToBottom, let last = logs.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !logs.isEmpty {
                HStack(spacing: Bauhaus.Grid.unit) {
                    Button {
                        scrollToBottom.toggle()
                    } label: {
                        Image(systemName: scrollToBottom ? "lock.fill" : "lock.open")
                            .font(Bauhaus.Font.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(scrollToBottom ? Bauhaus.Color.accent : Bauhaus.Color.textSecondary)
                    .help("Auto-scroll to bottom")
                    .accessibilityLabel(scrollToBottom ? "Disable Auto-scroll" : "Enable Auto-scroll")
                }
                .padding(Bauhaus.Grid.unit)
                .background(Bauhaus.Color.surfaceElevated.opacity(0.5))
                .cornerRadius(4)
                .padding(Bauhaus.Grid.unit)
            }
        }
    }
}

struct ConsoleEntry: Identifiable, Codable, Sendable {
    var id = UUID()
    let timestamp: Date
    let message: String
    let level: LogLevel

    private enum CodingKeys: String, CodingKey {
        case timestamp, message, level
    }

    var icon: String {
        switch level {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch level {
        case .info: return Bauhaus.Color.accent
        case .warning: return Bauhaus.Color.warning
        case .error: return Bauhaus.Color.error
        case .success: return Bauhaus.Color.trusted
        }
    }

    var isError: Bool {
        level == .error
    }
}

enum LogLevel: String, Codable, Sendable {
    case info
    case warning
    case error
    case success
}
