import SwiftUI

struct TrustWarningView: View {
    let title: String
    let message: String
    let actionLabel: String?
    let action: (() -> Void)?

    init(
        title: String = "Verification Required",
        message: String =
            "This content has not yet been verified by the authority. Access is restricted until a valid receipt chain is confirmed.",
        actionLabel: String? = "Verify Now",
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.actionLabel = actionLabel
        self.action = action
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.shield")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title). \(message)")

            if let actionLabel = actionLabel, let action = action {
                Button(action: action) {
                    Text(actionLabel)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Trust Warning: \(title)")
    }
}
