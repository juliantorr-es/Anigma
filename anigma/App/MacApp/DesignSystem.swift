//
//  DesignSystem.swift
//  AnigmaAppMac
//
//  Bauhaus design tokens - geometry with conviction.
//  Flatter planes, sharper edges, intentional color accents.
//

import SwiftUI

// MARK: - Bauhaus Design System

enum Bauhaus {

    // MARK: - Color Palette

    enum Color {
        // Primary accent - olive/sage green (governance, trust, local)
        static let accent = SwiftUI.Color(red: 0.42, green: 0.52, blue: 0.35)
        static let accentLight = SwiftUI.Color(red: 0.52, green: 0.62, blue: 0.45)
        static let accentDark = SwiftUI.Color(red: 0.32, green: 0.42, blue: 0.25)

        // Status colors
        static let trusted = SwiftUI.Color(red: 0.42, green: 0.52, blue: 0.35) // same as accent
        static let running = SwiftUI.Color(red: 0.45, green: 0.55, blue: 0.65)
        static let warning = SwiftUI.Color(red: 0.75, green: 0.55, blue: 0.35)
        static let error = SwiftUI.Color(red: 0.70, green: 0.35, blue: 0.35)
        static let success = SwiftUI.Color(red: 0.42, green: 0.52, blue: 0.35)

        // Queue specific
        static let queueRunning = SwiftUI.Color(red: 0.45, green: 0.55, blue: 0.65)
        static let queueComplete = SwiftUI.Color(red: 0.42, green: 0.52, blue: 0.35)
        static let queueQueued = SwiftUI.Color(white: 0.5)

        // Surfaces - flat, minimal gradient
        static let background = SwiftUI.Color(nsColor: .windowBackgroundColor)
        static let surface = SwiftUI.Color(nsColor: .controlBackgroundColor)
        static let surfaceElevated = SwiftUI.Color(white: 0.18)
        static let cardBackground = SwiftUI.Color(nsColor: .controlBackgroundColor)

        // Text
        static let textPrimary = SwiftUI.Color.primary
        static let textSecondary = SwiftUI.Color.secondary
        static let textTertiary = SwiftUI.Color(white: 0.5)

        // Borders - thin, visible
        static let border = SwiftUI.Color.primary.opacity(0.12)
        static let borderStrong = SwiftUI.Color.primary.opacity(0.2)
        static let active = SwiftUI.Color(red: 0.42, green: 0.52, blue: 0.35)

        static let governanceReadOnly = SwiftUI.Color(white: 0.5)
        static let governanceAllowed = SwiftUI.Color(red: 0.42, green: 0.52, blue: 0.35)
        static let governanceBlocked = SwiftUI.Color(red: 0.70, green: 0.35, blue: 0.35)
    }

    // MARK: - Components

    struct StatusChip: View {
        let label: String
        let color: SwiftUI.Color
        let icon: String?

        var body: some View {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon).font(.system(size: 10))
                }
                Text(label.uppercased())
                    .font(Bauhaus.Font.caption)
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .cornerRadius(2)
        }
    }

    enum StatusState {
        case idle
        case running
        case attention
        case blocked
        case newOutput
    }

    struct StatusDot: View {
        let state: Bauhaus.StatusState

        var body: some View {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
        }

        var color: SwiftUI.Color {
            switch state {
            case .idle: return Bauhaus.Color.textTertiary
            case .running: return Bauhaus.Color.running
            case .attention: return Bauhaus.Color.warning
            case .blocked: return Bauhaus.Color.error
            case .newOutput: return Bauhaus.Color.accent
            }
        }
    }

    struct EmptyState: View {
        let title: String
        let message: String
        let buttonTitle: String
        let action: () -> Void

        var body: some View {
            VStack(spacing: Bauhaus.Grid.x2) {
                Text(title)
                    .font(Bauhaus.Font.header)
                    .foregroundStyle(Bauhaus.Color.textPrimary)
                Text(message)
                    .font(Bauhaus.Font.body)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .accessibilityLabel("\(title), \(message)")

                Button(action: action) {
                    Text(buttonTitle)
                        .font(Bauhaus.Font.subHeader)
                }
                .bauhausAccentButton()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .contain)
        }
    }

    struct Card<Content: View>: View {
        let content: Content

        init(@ViewBuilder content: () -> Content) {
            self.content = content()
        }

        var body: some View {
            content
                .padding(Bauhaus.Grid.x2)
                .background(Bauhaus.Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                        .stroke(Bauhaus.Color.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius))
        }
    }

    // MARK: - Grid

    enum Grid {
        static let unit: CGFloat = 8
        static let x2: CGFloat = 16
        static let x3: CGFloat = 24
        static let x4: CGFloat = 32
        static let x5: CGFloat = 40
        static let x6: CGFloat = 48
        static let x8: CGFloat = 64

        static let sidebarWidth: CGFloat = 220
        static let inspectorWidth: CGFloat = 320

        static let cornerRadius: CGFloat = 6
        static let cornerRadiusSmall: CGFloat = 4
        static let radius: CGFloat = 6
    }

    // MARK: - Typography

    enum Font {
        static let title = SwiftUI.Font.system(size: 24, weight: .bold)
        static let header = SwiftUI.Font.system(size: 18, weight: .semibold)
        static let subHeader = SwiftUI.Font.system(size: 15, weight: .medium)
        static let body = SwiftUI.Font.system(size: 13)
        static let bodyBold = SwiftUI.Font.system(size: 13, weight: .bold)
        static let caption = SwiftUI.Font.system(size: 11)
        static let mono = SwiftUI.Font.system(size: 11, design: .monospaced)
        static let monoBold = SwiftUI.Font.system(size: 11, weight: .bold, design: .monospaced)
    }
}

// MARK: - Bauhaus View Modifiers

extension View {
    func bauhausCard(selected: Bool = false) -> some View {
        self
            .padding(Bauhaus.Grid.x2)
            .background(Bauhaus.Color.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                    .stroke(selected ? Bauhaus.Color.accent : Bauhaus.Color.border, lineWidth: selected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius))
    }

    func bauhausSection() -> some View {
        self
            .padding(.vertical, Bauhaus.Grid.x2)
            .overlay(
                Rectangle()
                    .fill(Bauhaus.Color.border)
                    .frame(height: 1),
                alignment: .bottom
            )
    }

    func bauhausAccentButton() -> some View {
        self
            .padding(.horizontal, Bauhaus.Grid.x2)
            .padding(.vertical, Bauhaus.Grid.unit)
            .background(Bauhaus.Color.accent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadiusSmall))
    }
}

// MARK: - Shared Bauhaus Components

struct JobStatusBadge: View {
    let status: String

    var body: some View {
        HStack(spacing: 4) {
            Bauhaus.StatusDot(state: mapStatus(status))
            Text(status.capitalized)
                .font(Bauhaus.Font.caption)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(status)")
    }

    private func mapStatus(_ status: String) -> Bauhaus.StatusState {
        switch status.uppercased() {
        case "RUNNING", "QUEUED": return .running
        case "SUCCEEDED", "COMPLETED": return .newOutput
        case "FAILED", "CANCELED": return .blocked
        case "BLOCKED": return .blocked
        case "ATTENTION": return .attention
        default: return .idle
        }
    }
}

struct CanvasGrid: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = Bauhaus.Grid.x3
            let color = Bauhaus.Color.border.opacity(0.5)

            for x in stride(from: 0, to: size.width, by: step) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(color), lineWidth: 0.5)
            }

            for y in stride(from: 0, to: size.height, by: step) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(color), lineWidth: 0.5)
            }
        }
        .accessibilityHidden(true)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textPrimary)
                .textSelection(.enabled)

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct TruthTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(title.uppercased())
                    .font(Bauhaus.Font.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(isSelected ? Bauhaus.Color.textPrimary : Bauhaus.Color.textTertiary)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(isSelected ? Bauhaus.Color.accent : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
