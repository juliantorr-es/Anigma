//
//  GovernanceHUD.swift
//  AnigmaAppMac
//
//  Floating overlay for system-wide governance awareness.
//  Displays policy compliance and risk scores for active context.
//

import SwiftUI
import AnigmaCore

@MainActor
public class GovernanceHUDViewModel: ObservableObject {
    @Published public var complianceScore: Double = 1.0
    @Published public var activePolicy: String = "Standard Institutional Policy"
    @Published public var detectedRisk: String?
    @Published public var lastClassification: PromptClassification?

    public init() {}

    public func update(with classification: PromptClassification) {
        self.lastClassification = classification
        self.complianceScore = 1.0 - classification.riskScore

        if classification.riskScore > 0.5 {
            self.detectedRisk = "High Risk Intent: \(classification.intent.rawValue)"
        } else {
            self.detectedRisk = nil
        }
    }
}

public struct GovernanceHUD: View {
    @ObservedObject var viewModel: GovernanceHUDViewModel

    public init(viewModel: GovernanceHUDViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            HStack {
                Image(systemName: viewModel.complianceScore > 0.8 ? "shield.checkered" : "shield.exclamationmark.fill")
                    .foregroundStyle(viewModel.complianceScore > 0.8 ? Bauhaus.Color.success : Bauhaus.Color.warning)
                Text("Anigma Governed")
                    .font(Bauhaus.Font.caption)
                    .fontWeight(.bold)
            }

            Divider()

            HStack {
                Text("Compliance")
                Spacer()
                Text("\(Int(viewModel.complianceScore * 100))%")
                    .foregroundStyle(scoreColor)
            }
            .font(Bauhaus.Font.mono)
            .fontWeight(.medium)

            Text("Active: \(viewModel.activePolicy)")
                .font(Bauhaus.Font.micro)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            if let risk = viewModel.detectedRisk {
                Label(risk, systemName: "exclamationmark.triangle.fill")
                    .font(Bauhaus.Font.small)
                    .foregroundStyle(Bauhaus.Color.warning)
                    .padding(.top, Bauhaus.Grid.unit / 2)
            }
        }
        .padding(Bauhaus.Grid.unit)
        .background(.ultraThinMaterial)
        .background(Bauhaus.Color.surface.opacity(0.1))
        .cornerRadius(Bauhaus.Grid.radius)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.radius)
                .stroke(Bauhaus.Color.border, lineWidth: 1)
        )
        .frame(width: 180) // OK: Fixed HUD width
    }

    private var scoreColor: Color {
        if viewModel.complianceScore > 0.8 { return Bauhaus.Color.success }
        if viewModel.complianceScore > 0.5 { return Bauhaus.Color.warning }
        return Bauhaus.Color.error
    }
}
