//
//  TransformPreview.swift
//  AnigmaAppMac
//
//  The "Look before you leap" contract.
//  Every data transformation must pass through this preview.
//  Flow: Input Summary -> Action Definition -> Expected Output -> user confirmation.
//

import SwiftUI

/// Data model for what we are about to do.
/// In a real app, this would be computed from the Job intent.
struct TransformProposal {
    let title: String
    let icon: String
    let description: String
    let inputs: [String]
    let action: String
    let expectedOutputs: [String]
    let privacyImpact: String
    let governanceCheck: GovernanceResult

    enum GovernanceResult {
        case allowed
        case restricted(reason: String)
        case blocked(reason: String)
    }
}

struct TransformPreview: View {
    let proposal: TransformProposal
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            // Header
            HStack {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(Bauhaus.Font.header)
                VStack(alignment: .leading) {
                    Text("Proposed Action Preview")
                        .font(Bauhaus.Font.header)
                    Text("Review the changes before applying them.")
                        .font(Bauhaus.Font.body)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(Bauhaus.Grid.x4)
            .background(Bauhaus.Color.background.opacity(0.5))

            ScrollView {
                VStack(spacing: Bauhaus.Grid.x4) {

                    // 1. The Transformation Graph
                    HStack(spacing: Bauhaus.Grid.x2) {
                        // Inputs
                        VStack(alignment: .leading) {
                            Text("INPUTS")
                                .font(Bauhaus.Font.caption)
                                .foregroundStyle(.secondary)
                            ForEach(proposal.inputs, id: \.self) { input in
                                HStack {
                                    Image(systemName: "doc")
                                    Text(input)
                                }
                                .padding(Bauhaus.Grid.x2)
                                .background(Bauhaus.Color.cardBackground)
                                .cornerRadius(4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Arrow
                        Image(systemName: "arrow.right")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        // Action
                        VStack {
                            Image(systemName: proposal.icon)
                                .font(.title)
                            Text(proposal.action)
                                .font(Bauhaus.Font.subHeader)
                        }
                        .padding(Bauhaus.Grid.x3)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)

                        // Arrow
                        Image(systemName: "arrow.right")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        // Outputs
                        VStack(alignment: .leading) {
                            Text("RESULTS")
                                .font(Bauhaus.Font.caption)
                                .foregroundStyle(.secondary)
                            ForEach(proposal.expectedOutputs, id: \.self) { output in
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                    Text(output)
                                }
                                .padding(Bauhaus.Grid.x2)
                                .background(Bauhaus.Color.cardBackground)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Bauhaus.Color.success, lineWidth: 1)
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                    }
                    .padding(Bauhaus.Grid.x4)
                    .background(Color.primary.opacity(0.02))
                    .cornerRadius(8)

                    // 2. Governance & Privacy Checks
                    VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {

                        // Privacy
                        HStack {
                            Image(systemName: "hand.raised.fill")
                            VStack(alignment: .leading) {
                                Text("Privacy Impact")
                                    .bold()
                                Text(proposal.privacyImpact)
                                    .font(Bauhaus.Font.body)
                            }
                            Spacer()
                            if proposal.privacyImpact.contains("On-Device") {
                                Bauhaus.StatusChip(
                                    label: "LOCAL", color: Bauhaus.Color.success, icon: "lock.fill")
                            } else {
                                Bauhaus.StatusChip(
                                    label: "NETWORK", color: Bauhaus.Color.warning,
                                    icon: "cloud.fill")
                            }
                        }
                        .padding(Bauhaus.Grid.x3)
                        .background(Bauhaus.Color.cardBackground)
                        .cornerRadius(8)

                        // Governance
                        HStack {
                            Image(systemName: "signature")
                            VStack(alignment: .leading) {
                                Text("Governance Policy")
                                    .bold()
                                switch proposal.governanceCheck {
                                case .allowed:
                                    Text("Action is compliant with current role policy.")
                                case .restricted(let reason):
                                    Text("Restricted: \(reason)")
                                case .blocked(let reason):
                                    Text("BLOCKED: \(reason)")
                                        .foregroundStyle(Bauhaus.Color.error)
                                }
                            }
                            Spacer()
                            switch proposal.governanceCheck {
                            case .allowed:
                                Bauhaus.StatusChip(
                                    label: "APPROVED", color: Bauhaus.Color.success,
                                    icon: "checkmark.seal.fill")
                            case .restricted:
                                Bauhaus.StatusChip(
                                    label: "WARNING", color: Bauhaus.Color.warning,
                                    icon: "exclamationmark.triangle.fill")
                            case .blocked:
                                Bauhaus.StatusChip(
                                    label: "BLOCKED", color: Bauhaus.Color.error,
                                    icon: "xmark.octagon.fill")
                            }
                        }
                        .padding(Bauhaus.Grid.x3)
                        .background(Bauhaus.Color.cardBackground)
                        .cornerRadius(8)
                    }

                }
                .padding(Bauhaus.Grid.x6)
            }

            Divider()

            // Footer Actions
            HStack(spacing: Bauhaus.Grid.x3) {
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.large)

                Spacer()

                Button(action: onConfirm) {
                    Text("Confirm & Run")
                        .bold()
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Bauhaus.Color.active)
                .disabled(isBlocked)
                .keyboardShortcut(.defaultAction)
            }
            .padding(Bauhaus.Grid.x4)
            .background(Bauhaus.Color.cardBackground)
        }
    }

    var isBlocked: Bool {
        if case .blocked = proposal.governanceCheck { return true }
        return false
    }
}
