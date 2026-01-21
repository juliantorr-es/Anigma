import SwiftUI

struct ErrorView: View {
    let error: Error
    let retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Error: Something went wrong. \(error.localizedDescription)")

            if let retryAction = retryAction {
                Button(action: retryAction) {
                    Label("Try Again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel("Try Again")
                .accessibilityHint("Attempts to reload the failed operation.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 14, weight: .bold))
                .accessibilityHidden(true)
            Text("Offline Mode")
                .font(.system(size: 13, weight: .semibold))
            Text("— Showing Cached Data")
                .font(.system(size: 13))
                .opacity(0.8)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.15), Color.orange.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .foregroundStyle(.orange)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.orange.opacity(0.2)),
            alignment: .bottom
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Offline Mode. Showing Cached Data.")
        .accessibilityAddTraits(.isStaticText)
    }
}
