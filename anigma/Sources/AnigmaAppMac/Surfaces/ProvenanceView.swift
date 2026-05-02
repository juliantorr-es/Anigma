import AnigmaClientKit
//
//  ProvenanceView.swift
//  AnigmaAppMac
//
//  Receipt and evidence tracking for trusted answers.
//  Shows provenance chain with receipts, timestamps, and verification status.
//

import SwiftUI

struct ProvenanceView: View {
    let analysis: Analysis
    @State private var selectedReceiptId: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                Text("Provenance")
                    .font(Bauhaus.Font.header)
                    .foregroundStyle(Bauhaus.Color.textPrimary)
                
                Text("Sources and receipts for this analysis")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            }
            .padding(Bauhaus.Grid.x2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Bauhaus.Color.surface.opacity(0.5))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
                    
                    // Verification Status
                    verificationBadge
                    
                    // Source Chain
                    if !analysis.sources.isEmpty {
                        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                            Text("Sources")
                                .font(Bauhaus.Font.subHeader)
                                .foregroundStyle(Bauhaus.Color.textSecondary)
                            
                            ForEach(analysis.sources) { source in
                                ProvenanceSourceCard(source: source)
                            }
                        }
                    }
                    
                    // Receipts
                    if !analysis.receipts.isEmpty {
                        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                            Text("Receipts")
                                .font(Bauhaus.Font.subHeader)
                                .foregroundStyle(Bauhaus.Color.textSecondary)
                            
                            ForEach(analysis.receipts.map { $0.toCoreReceipt() }) { receipt in
                                ReceiptCard(receipt: receipt, isSelected: selectedReceiptId == receipt.id) {
                                    selectedReceiptId = selectedReceiptId == receipt.id ? nil : receipt.id
                                }
                            }
                        }
                    }
                    
                    // Timeline
                    if analysis.phase == .complete {
                        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                            Text("Timeline")
                                .font(Bauhaus.Font.subHeader)
                                .foregroundStyle(Bauhaus.Color.textSecondary)
                            
                            AnalysisTimelineView(analysis: analysis)
                        }
                    }
                }
                .padding(Bauhaus.Grid.x2)
            }
        }
        .background(Bauhaus.Color.background)
    }
    
    // MARK: - Verification Badge
    
    private var verificationBadge: some View {
        HStack(spacing: Bauhaus.Grid.unit) {
            Image(systemName: analysis.isVerified ? "checkmark.shield.fill" : "shield")
                .font(Bauhaus.Font.icon)
                .foregroundStyle(analysis.isVerified ? Bauhaus.Color.trusted : Bauhaus.Color.textTertiary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(analysis.isVerified ? "Verified" : "Unverified")
                    .font(Bauhaus.Font.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Bauhaus.Color.textPrimary)
                
                Text(analysis.isVerified ? "All sources tracked" : "Missing receipts")
                    .font(Bauhaus.Font.micro)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            }
        }
        .padding(Bauhaus.Grid.x2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(analysis.isVerified ? Bauhaus.Color.trusted.opacity(0.08) : Bauhaus.Color.surface)
        .cornerRadius(Bauhaus.Grid.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                .stroke(analysis.isVerified ? Bauhaus.Color.trusted.opacity(0.3) : Bauhaus.Color.border, lineWidth: 1)
        )
    }
}

// MARK: - Provenance Source Card

struct ProvenanceSourceCard: View {
    let source: SourceReference
    
    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            HStack(alignment: .top, spacing: Bauhaus.Grid.unit) {
                Image(systemName: "doc.text")
                    .font(Bauhaus.Font.small)
                    .foregroundStyle(Bauhaus.Color.accent)
                    .frame(width: 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.title)
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textPrimary)
                        .fontWeight(.medium)
                    
                    if let path = source.path {
                        Text(path)
                            .font(Bauhaus.Font.micro)
                            .foregroundStyle(Bauhaus.Color.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                
                Spacer()
            }
            
            if let excerpt = source.excerpt {
                Text(excerpt)
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
                    .lineLimit(3)
                    .padding(.leading, 20)
            }
        }
        .padding(Bauhaus.Grid.unit)
        .background(Bauhaus.Color.surface.opacity(0.5))
        .cornerRadius(Bauhaus.Grid.cornerRadiusSmall)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Source: \(source.title)")
    }
}

// MARK: - Receipt Card

struct ReceiptCard: View {
    let receipt: Receipt
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                HStack {
                    Image(systemName: "receipt")
                        .font(Bauhaus.Font.small)
                        .foregroundStyle(Bauhaus.Color.accent)
                    
                    Text(receipt.operationType)
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textPrimary)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                        .font(Bauhaus.Font.micro)
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                }
                
                if isSelected {
                    VStack(alignment: .leading, spacing: 4) {
                        Divider()
                        
                        InfoRow(label: "ID", value: String(receipt.id.prefix(12)))
                        InfoRow(label: "Time", value: receipt.timestamp.formatted(date: .omitted, time: .standard))
                    }
                    .transition(.opacity)
                }
            }
            .padding(Bauhaus.Grid.unit)
            .background(Bauhaus.Color.surface)
            .cornerRadius(Bauhaus.Grid.cornerRadiusSmall)
            .overlay(
                RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadiusSmall)
                    .stroke(isSelected ? Bauhaus.Color.accent.opacity(0.5) : Bauhaus.Color.border, lineWidth: isSelected ? 1 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Receipt: \(receipt.operationType)")
    }
}

// MARK: - Timeline View

struct AnalysisTimelineView: View {
    let analysis: Analysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            TimelineEvent(
                icon: "play.circle.fill",
                label: "Started",
                timestamp: analysis.timestamp,
                color: Bauhaus.Color.accent
            )
            
            if let firstResultTime = analysis.results.first?.timestamp {
                TimelineEvent(
                    icon: "sparkles",
                    label: "First result",
                    timestamp: firstResultTime,
                    color: Bauhaus.Color.running
                )
            }
            
            if analysis.phase == .complete {
                TimelineEvent(
                    icon: "checkmark.circle.fill",
                    label: "Completed",
                    timestamp: analysis.timestamp,
                    color: Bauhaus.Color.trusted
                )
            }
        }
        .padding(Bauhaus.Grid.unit)
        .background(Bauhaus.Color.surface.opacity(0.3))
        .cornerRadius(Bauhaus.Grid.cornerRadiusSmall)
    }
}

struct TimelineEvent: View {
    let icon: String
    let label: String
    let timestamp: Date
    let color: Color
    
    var body: some View {
        HStack(spacing: Bauhaus.Grid.unit) {
            Image(systemName: icon)
                .font(Bauhaus.Font.small)
                .foregroundStyle(color)
                .frame(width: 16)
            
            Text(label)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)
            
            Spacer()
            
            Text(timestamp.formatted(date: .omitted, time: .standard))
                .font(Bauhaus.Font.micro)
                .foregroundStyle(Bauhaus.Color.textTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) at \(timestamp.formatted(date: .omitted, time: .standard))")
    }
}
