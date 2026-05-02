//
//  DoctrineGovernanceView.swift
//  AnigmaAppMac
//
//  Dedicated surface for doctrine governance, policy compliance, and risk auditing.
//  Migrated from HUD to formal privileged surface.
//

import SwiftUI
import AnigmaCore

struct DoctrineGovernanceView: View {
    @StateObject private var viewModel = GovernanceHUDViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                complianceOverview
                activePolicySection
                riskAuditSection
                
                Spacer()
            }
            .padding(24)
        }
        .background(Bauhaus.Color.background)
        .navigationTitle("Doctrine Governance")
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Doctrine Compliance")
                .font(Bauhaus.Font.header)
            Text("Real-time monitoring of system-wide governance invariants and ethical guardrails.")
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textSecondary)
        }
    }
    
    private var complianceOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compliance Score")
                .font(Bauhaus.Font.subHeader)
            
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Bauhaus.Color.border, lineWidth: 8)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: viewModel.complianceScore)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(viewModel.complianceScore * 100))%")
                        .font(Bauhaus.Font.header)
                        .fontWeight(.bold)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Label(
                        viewModel.complianceScore > 0.8 ? "Highly Compliant" : "Risk Detected",
                        systemImage: viewModel.complianceScore > 0.8 ? "shield.checkered" : "shield.exclamationmark.fill"
                    )
                    .font(Bauhaus.Font.bodyBold)
                    .foregroundStyle(scoreColor)
                    
                    Text("All active local inference runs are within established safety boundaries.")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
            .background(Bauhaus.Color.surface)
            .cornerRadius(Bauhaus.Grid.radius)
            .overlay(
                RoundedRectangle(cornerRadius: Bauhaus.Grid.radius)
                    .stroke(Bauhaus.Color.border, lineWidth: 1)
            )
        }
    }
    
    private var activePolicySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Doctrine Policy")
                .font(Bauhaus.Font.subHeader)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.activePolicy)
                        .font(Bauhaus.Font.bodyBold)
                    Text("ID: canonical-institutional-v1")
                        .font(Bauhaus.Font.mono)
                        .font(.system(size: 10))
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                }
                
                Spacer()
                
                Button("Switch Policy") {
                    // Logic to switch doctrine
                }
                .controlSize(.small)
            }
            .padding(16)
            .background(Bauhaus.Color.surface)
            .cornerRadius(Bauhaus.Grid.radius)
            .overlay(
                RoundedRectangle(cornerRadius: Bauhaus.Grid.radius)
                    .stroke(Bauhaus.Color.border, lineWidth: 1)
            )
        }
    }
    
    private var riskAuditSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Risk Audit")
                .font(Bauhaus.Font.subHeader)
            
            if let risk = viewModel.detectedRisk {
                RiskRow(title: risk, severity: .high)
            } else {
                Text("No risk alerts detected in recent sessions.")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textTertiary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Bauhaus.Color.surface.opacity(0.5))
                    .cornerRadius(Bauhaus.Grid.radius)
            }
        }
    }
    
    private var scoreColor: Color {
        if viewModel.complianceScore > 0.8 { return Bauhaus.Color.success }
        if viewModel.complianceScore > 0.5 { return Bauhaus.Color.warning }
        return Bauhaus.Color.error
    }
}

private struct RiskRow: View {
    let title: String
    let severity: RiskSeverity
    
    enum RiskSeverity {
        case low, medium, high
        
        var color: Color {
            switch self {
            case .low: return .blue
            case .medium: return .orange
            case .high: return .red
            }
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(severity.color)
            Text(title)
                .font(Bauhaus.Font.caption)
            Spacer()
            Text(String(describing: severity).uppercased())
                .font(Bauhaus.Font.micro)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(severity.color.opacity(0.1))
                .foregroundStyle(severity.color)
                .cornerRadius(4)
        }
        .padding(12)
        .background(Bauhaus.Color.surface)
        .cornerRadius(Bauhaus.Grid.radius)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.radius)
                .stroke(Bauhaus.Color.border, lineWidth: 1)
        )
    }
}

@MainActor
public final class GovernanceHUDViewModel: ObservableObject {
    @Published public var complianceScore: Double
    @Published public var activePolicy: String
    @Published public var detectedRisk: String?

    public init(
        complianceScore: Double = 0.96,
        activePolicy: String = "Canonical Institutional Doctrine",
        detectedRisk: String? = nil
    ) {
        self.complianceScore = complianceScore
        self.activePolicy = activePolicy
        self.detectedRisk = detectedRisk
    }

    public func update(with classification: PromptClassification) {
        activePolicy = classification.applicablePolicyId
        complianceScore = max(0, min(1, 1 - classification.riskScore))
        detectedRisk = classification.riskScore > 0.5
            ? "Elevated risk (\(Int(classification.riskScore * 100))%)"
            : nil
    }
}
