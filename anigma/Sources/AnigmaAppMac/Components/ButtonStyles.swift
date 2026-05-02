//
//  ButtonStyles.swift
//  AnigmaAppMac
//
//  Standardized Bauhaus button styles.
//  Semantic affordance for primary, secondary, and destructive actions.
//

import SwiftUI

// NonPersistent
struct PrimaryButtonStyle: ButtonStyle, Sendable {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, Bauhaus.Grid.x3)
            .padding(.vertical, 10)
            .background(Bauhaus.Color.accentGradient)
            .foregroundStyle(.white)
            .font(Bauhaus.Font.bodyBold)
            .clipShape(RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius))
            .shadow(color: Bauhaus.Color.accent.opacity(isEnabled ? 0.3 : 0), radius: 8, x: 0, y: 4)
            .opacity(isEnabled ? (configuration.isPressed ? 0.9 : 1.0) : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: configuration.isPressed)
    }
}

// NonPersistent
struct SecondaryButtonStyle: ButtonStyle, Sendable {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, Bauhaus.Grid.x3)
            .padding(.vertical, 10)
            .background(Bauhaus.Color.surface)
            .foregroundStyle(Bauhaus.Color.textPrimary)
            .font(Bauhaus.Font.bodyBold)
            .clipShape(RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                    .stroke(Bauhaus.Color.border, lineWidth: 1)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.9 : 1.0) : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: configuration.isPressed)
    }
}

// NonPersistent
struct DestructiveButtonStyle: ButtonStyle, Sendable {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, Bauhaus.Grid.x3)
            .padding(.vertical, 10)
            .background(Bauhaus.Color.error.opacity(0.1))
            .foregroundStyle(Bauhaus.Color.error)
            .font(Bauhaus.Font.bodyBold)
            .clipShape(RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                    .stroke(Bauhaus.Color.error.opacity(0.3), lineWidth: 1)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.9 : 1.0) : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: configuration.isPressed)
    }
}

// NonPersistent
struct GhostButtonStyle: ButtonStyle, Sendable {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, Bauhaus.Grid.unit)
            .padding(.vertical, 6)
            .foregroundStyle(Bauhaus.Color.textSecondary)
            .font(Bauhaus.Font.caption)
            .background(configuration.isPressed ? Bauhaus.Color.surface : Color.clear)
            .cornerRadius(Bauhaus.Grid.cornerRadiusSmall)
            .opacity(isEnabled ? 1.0 : 0.5)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension View {
    func primaryButtonStyle() -> some View {
        self.buttonStyle(PrimaryButtonStyle())
    }

    func secondaryButtonStyle() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }

    func destructiveButtonStyle() -> some View {
        self.buttonStyle(DestructiveButtonStyle())
    }

    func ghostButtonStyle() -> some View {
        self.buttonStyle(GhostButtonStyle())
    }
}
