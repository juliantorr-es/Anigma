//
//  ConsoleView.swift
//  AnigmaAppMac
//
//  Streaming console for agent execution logs
//

import SwiftUI

struct ConsoleView: View {
    let logs: [ConsoleEntry]
    @State private var scrollToBottom = true

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(logs) { entry in
                        HStack(alignment: .top, spacing: 12) {
                            Text(entry.timestamp, style: .time)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 80, alignment: .leading)

                            Image(systemName: entry.icon)
                                .font(.system(size: 10))
                                .foregroundStyle(entry.color)
                                .frame(width: 16)
                                .accessibilityHidden(true)

                            Text(entry.message)
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(entry.isError ? Color.red.opacity(0.05) : Color.clear)
                        .id(entry.id)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(entry.level.rawValue): \(entry.message)")
                    }
                }
                .padding(.vertical, 8)
            }
            .background(Color.black.opacity(0.8))
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
                HStack(spacing: 8) {
                    Button {
                        scrollToBottom.toggle()
                    } label: {
                        Image(systemName: scrollToBottom ? "lock.fill" : "lock.open")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(scrollToBottom ? .blue : .secondary)
                    .help("Auto-scroll to bottom")
                    .accessibilityLabel(scrollToBottom ? "Disable Auto-scroll" : "Enable Auto-scroll")
                }
                .padding(8)
            }
        }
    }
}

struct ConsoleEntry: Identifiable, Codable {
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
        case .info: return .blue
        case .warning: return .yellow
        case .error: return .red
        case .success: return .green
        }
    }

    var isError: Bool {
        level == .error
    }
}

enum LogLevel: String, Codable {
    case info
    case warning
    case error
    case success
}
