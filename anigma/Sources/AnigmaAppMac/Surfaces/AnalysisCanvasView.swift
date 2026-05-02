//
//  AnalysisCanvasView.swift
//  AnigmaAppMac
//
//  Expandable analysis workspace with live compute and provenance.
//  Real-time surface powered by Metal and compute capsules.
//

import SwiftUI
import AnigmaClientKit
#if canImport(TabularData)
import TabularData
#endif
#if canImport(SwiftUICharts)
import SwiftUICharts
#endif
#if canImport(Probably)
import Probably
#endif

struct AnalysisCanvasView: View {
    @ObservedObject var state: AnalysisAssistantState
    @Binding var isPresented: Bool
    @State private var showProvenancePanel = false
    @State private var selectedPane: AnalysisPane = .summary
    
    var body: some View {
        HSplitView {
            // Main Canvas
            mainCanvas
                .frame(minWidth: 400)
            
            // Provenance Panel (optional)
            if showProvenancePanel, let current = state.currentAnalysis {
                ProvenanceView(analysis: current)
                    .frame(minWidth: 280, maxWidth: 360)
                    .transition(.move(edge: .trailing))
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    withAnimation {
                        showProvenancePanel.toggle()
                    }
                } label: {
                    Label("Provenance", systemImage: showProvenancePanel ? "doc.text.fill" : "doc.text")
                }
                .accessibilityLabel(showProvenancePanel ? "Hide provenance" : "Show provenance")
                .help("Show sources and receipts")
            }
            
            ToolbarItem(placement: .automatic) {
                Button {
                    state.exportAnalysis()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(state.currentAnalysis == nil)
                .accessibilityLabel("Export analysis")
            }
        }
    }
    
    // MARK: - Main Canvas
    
    private var mainCanvas: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
                if let analysis = state.currentAnalysis {
                    analysisHero(analysis)
                    analysisModePicker
                    VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
                        switch selectedPane {
                        case .summary:
                            AnalysisSummaryView(analysis: analysis)
                        case .evidence:
                            AnalysisEvidenceView(analysis: analysis)
                        case .data:
                            AnalysisDataView(analysis: analysis)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: selectedPane)
                } else {
                    Bauhaus.EmptyState(
                        title: "No Active Analysis",
                        message: "Return to home and start a new query. The workbench will show capsule status, evidence, and reproducible data views.",
                        buttonTitle: "Go Home",
                        action: { isPresented = false }
                    )
                }
            }
            .padding(Bauhaus.Grid.x3)
        }
        .background(Bauhaus.Color.background)
    }

    private var analysisModePicker: some View {
        Picker("Analysis View", selection: $selectedPane) {
            ForEach(AnalysisPane.allCases) { pane in
                Text(pane.title).tag(pane)
            }
        }
        .pickerStyle(.segmented)
    }

    private func analysisHero(_ analysis: Analysis) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            HStack(alignment: .top, spacing: Bauhaus.Grid.x2) {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                    Text(analysis.query)
                        .font(Bauhaus.Font.header)
                        .foregroundStyle(Bauhaus.Color.textPrimary)
                        .textSelection(.enabled)
                    
                    HStack(spacing: Bauhaus.Grid.x2) {
                        HStack(spacing: 4) {
                            Bauhaus.StatusDot(state: statusForPhase(analysis.phase))
                            Text(analysis.phase.displayName)
                                .font(Bauhaus.Font.caption)
                                .foregroundStyle(Bauhaus.Color.textSecondary)
                        }
                        
                        Text("Run \(analysis.id.prefix(8))")
                            .font(Bauhaus.Font.caption)
                            .foregroundStyle(Bauhaus.Color.textTertiary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1fs", analysis.elapsedTime))
                        .font(Bauhaus.Font.subHeader)
                        .foregroundStyle(Bauhaus.Color.textPrimary)
                    Text("elapsed")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                }
            }
            
            AnalysisBadgeRow(analysis: analysis)
        }
        .padding(Bauhaus.Grid.x3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Bauhaus.Color.surface.opacity(0.3))
        .cornerRadius(Bauhaus.Grid.cornerRadius)
    }
    
    private func statusForPhase(_ phase: AnalysisPhase) -> Bauhaus.StatusState {
        switch phase {
        case .preparing: return .running
        case .computing: return .running
        case .complete: return .idle
        default: return .idle
        }
    }
}

// MARK: - Analysis Modes

enum AnalysisPane: String, CaseIterable, Identifiable {
    case summary
    case evidence
    case data

    var id: String { rawValue }

    var title: String {
        switch self {
        case .summary: return "Summary"
        case .evidence: return "Evidence"
        case .data: return "Data"
        }
    }
}

struct AnalysisBadgeRow: View {
    let analysis: Analysis

    private var computeLabel: String {
        analysis.computeStatus.capsuleName ?? "Capsule pending"
    }

    private var metalLabel: String {
        analysis.computeStatus.metalDevice ?? "Metal pending"
    }

    var body: some View {
        HStack(spacing: Bauhaus.Grid.unit) {
            AnalysisBadge(icon: "cpu", text: computeLabel)
            AnalysisBadge(icon: "doc.text.magnifyingglass", text: "\(analysis.sources.count) sources")
            AnalysisBadge(icon: "checkmark.seal", text: "\(analysis.receipts.count) receipts")
            AnalysisBadge(icon: "dot.radiowaves.left.and.right", text: metalLabel)
        }
        .font(Bauhaus.Font.caption)
    }
}

struct AnalysisBadge: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .foregroundStyle(Bauhaus.Color.textSecondary)
        .padding(.horizontal, Bauhaus.Grid.unit)
        .padding(.vertical, 5)
        .background(Bauhaus.Color.surface.opacity(0.5))
        .cornerRadius(Bauhaus.Grid.cornerRadiusSmall)
    }
}

// MARK: - Analysis Summary

struct AnalysisSummaryView: View {
    let analysis: Analysis

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
            AnalysisMetricGrid(analysis: analysis)
            AnalysisInsightCard(analysis: analysis)
            LiveRenderCard(analysis: analysis)
            ComputeStatusCard(analysis: analysis)

            if analysis.results.isEmpty {
                Bauhaus.EmptyState(
                    title: "Waiting for capsule output",
                    message: "This run is scaffolded and will fill in as the compute capsule produces evidence.",
                    buttonTitle: "Stay on Workbench",
                    action: {}
                )
            } else {
                ForEach(analysis.results) { result in
                    AnalysisResultCard(result: result)
                }
            }
        }
    }
}

struct AnalysisMetricGrid: View {
    let analysis: Analysis

    private var averageConfidence: Double {
        guard !analysis.results.isEmpty else { return 0 }
        return analysis.results.map(\.confidence).reduce(0, +) / Double(analysis.results.count)
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Bauhaus.Grid.x2), count: 2), spacing: Bauhaus.Grid.x2) {
            AnalysisMetricCard(title: "Results", value: "\(analysis.results.count)", icon: "sparkles")
            AnalysisMetricCard(title: "Sources", value: "\(analysis.sources.count)", icon: "doc.text.magnifyingglass")
            AnalysisMetricCard(title: "Receipts", value: "\(analysis.receipts.count)", icon: "checkmark.seal")
            AnalysisMetricCard(title: "Confidence", value: String(format: "%.0f%%", averageConfidence * 100), icon: "gauge.with.dots.needle.50percent")
        }
    }
}

struct AnalysisInsightCard: View {
    let analysis: Analysis

    private var confidenceSamples: [Double] {
        analysis.results.map(\.confidence)
    }

    private var averageConfidence: Double {
        guard !confidenceSamples.isEmpty else { return 0 }
        return confidenceSamples.reduce(0, +) / Double(confidenceSamples.count)
    }

    private var medianConfidence: Double {
        guard !confidenceSamples.isEmpty else { return 0 }
        let sorted = confidenceSamples.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        } else {
            return sorted[middle]
        }
    }

    private var confidenceVariance: Double {
        guard confidenceSamples.count > 1 else { return 0.0001 }
        let mean = averageConfidence
        return max(confidenceSamples.reduce(0) { $0 + pow($1 - mean, 2) } / Double(confidenceSamples.count), 0.0001)
    }

    private var confidenceSpread: Double {
        guard let min = confidenceSamples.min(),
              let max = confidenceSamples.max() else { return 0 }
        return max - min
    }

    private var chartPoints: [DataPoint] {
        confidenceSamples.enumerated().map { index, confidence in
            DataPoint(
                value: confidence * 100,
                label: "\(index + 1)",
                legend: confidenceLegend(for: confidence)
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Statistical lens")
                        .font(Bauhaus.Font.subHeader)
                        .foregroundStyle(Bauhaus.Color.textPrimary)
                    Text("A calm summary of result confidence, shaped for quick reading.")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                }

                Spacer()

                Text(String(format: "%.0f%% avg", averageConfidence * 100))
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
                    .padding(.horizontal, Bauhaus.Grid.unit)
                    .padding(.vertical, 4)
                    .background(Bauhaus.Color.surface.opacity(0.8))
                    .cornerRadius(Bauhaus.Grid.cornerRadiusSmall)
            }

            if chartPoints.isEmpty {
                Text("No confidence series yet.")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textTertiary)
            } else {
                confidenceChart
                    .frame(height: 120)
            }

            HStack(alignment: .top, spacing: Bauhaus.Grid.x2) {
                AnalysisStatChip(label: "Median", value: String(format: "%.0f%%", medianConfidence * 100))
                AnalysisStatChip(label: "Spread", value: String(format: "%.0f%%", confidenceSpread * 100))
                AnalysisStatChip(label: "Samples", value: "\(confidenceSamples.count)")
            }

            Text(statisticalExplanation)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.surface.opacity(0.4))
        .cornerRadius(Bauhaus.Grid.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                .stroke(Bauhaus.Color.border, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var confidenceChart: some View {
        #if canImport(SwiftUICharts)
        LineChartView(dataPoints: chartPoints)
        #else
        Text("Confidence chart requires SwiftUICharts.")
            .font(Bauhaus.Font.caption)
            .foregroundStyle(Bauhaus.Color.textTertiary)
        #endif
    }

    private var statisticalExplanation: String {
        guard !confidenceSamples.isEmpty else {
            return "Probabilistic explanation appears once results land."
        }

        #if canImport(Probably)
        let fit = Gaussian(mean: averageConfidence, variance: confidenceVariance)
        let belowHalf = fit.distribution(lessThan: 0.5)
        return String(
            format: "The fitted curve suggests %.0f%% of scores sit below 50%%, keeping the canvas focused on the stronger slice of evidence.",
            belowHalf * 100
        )
        #else
        let belowHalf = confidenceSamples.filter { $0 < 0.5 }.count
        return String(
            format: "%d of %d scores sit below 50%%. The surface keeps the story compact until a fuller probabilistic layer is wired.",
            belowHalf,
            confidenceSamples.count
        )
        #endif
    }

    private func confidenceLegend(for confidence: Double) -> Legend {
        if confidence >= 0.8 {
            return Legend(color: .green, label: "Trusted", order: 3)
        } else if confidence >= 0.5 {
            return Legend(color: .orange, label: "Review", order: 2)
        } else {
            return Legend(color: .red, label: "Weak", order: 1)
        }
    }
}

struct AnalysisStatChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Bauhaus.Font.micro)
                .foregroundStyle(Bauhaus.Color.textTertiary)
            Text(value)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textPrimary)
        }
        .padding(.horizontal, Bauhaus.Grid.unit)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Bauhaus.Color.surface.opacity(0.55))
        .cornerRadius(Bauhaus.Grid.cornerRadiusSmall)
    }
}

struct AnalysisMetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(Bauhaus.Color.accent)
                Spacer()
            }
            Text(value)
                .font(Bauhaus.Font.subHeader)
                .foregroundStyle(Bauhaus.Color.textPrimary)
            Text(title)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)
        }
        .padding(Bauhaus.Grid.x2)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(Bauhaus.Color.surface.opacity(0.5))
        .cornerRadius(Bauhaus.Grid.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                .stroke(Bauhaus.Color.border, lineWidth: 0.5)
        )
    }
}

struct LiveRenderCard: View {
    let analysis: Analysis

    private var renderLabel: String {
        analysis.computeStatus.metalDevice ?? "Metal render pending"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Live Render")
                        .font(Bauhaus.Font.subHeader)
                        .foregroundStyle(Bauhaus.Color.textPrimary)
                    Text(renderLabel)
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                }

                Spacer()

                Text(analysis.phase.displayName)
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textTertiary)
                    .padding(.horizontal, Bauhaus.Grid.unit)
                    .padding(.vertical, 4)
                    .background(Bauhaus.Color.surface.opacity(0.8))
                    .cornerRadius(Bauhaus.Grid.cornerRadiusSmall)
            }

            TimelineView(.periodic(from: .now, by: 1/60)) { context in
                Canvas { canvas, size in
                    let phase = max(0, analysis.elapsedTime)
                    let barCount = 10
                    let width = size.width / CGFloat(barCount)

                    for index in 0..<barCount {
                        let progress = Double(index) / Double(barCount - 1)
                        let height = size.height * 0.2 + CGFloat((sin(phase * 2.0 + progress * .pi * 2.0) + 1.0) / 2.0) * size.height * 0.6
                        let x = CGFloat(index) * width + 4
                        let rect = CGRect(x: x, y: size.height - height, width: width - 8, height: height)
                        let path = Path(roundedRect: rect, cornerRadius: 6)
                        canvas.fill(path, with: .color(Bauhaus.Color.accent.opacity(0.25 + progress * 0.5)))
                    }
                }
            }
            .frame(height: 120)
            .background(Bauhaus.Color.surface.opacity(0.4))
            .cornerRadius(Bauhaus.Grid.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                    .stroke(Bauhaus.Color.border, lineWidth: 0.5)
            )

            Text("Metal binding is scaffolded here. The native adapter can replace this preview without changing the workbench flow.")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textTertiary)
        }
    }
}

// MARK: - Evidence

struct AnalysisEvidenceView: View {
    let analysis: Analysis

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
            SourcesDisclosureGroup(sources: analysis.sources)
            ReceiptsDisclosureGroup(receipts: analysis.receipts)
            ReproducibilityCard(analysis: analysis)
        }
    }
}

struct ReceiptsDisclosureGroup: View {
    let receipts: [AnalysisReceipt]
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                if receipts.isEmpty {
                    Text("No receipts available yet.")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                } else {
                    ForEach(receipts) { receipt in
                        AnalysisReceiptRow(receipt: receipt)
                    }
                }
            }
            .padding(.top, Bauhaus.Grid.unit)
        } label: {
            HStack {
                Image(systemName: "checkmark.seal")
                    .font(Bauhaus.Font.icon)
                    .foregroundStyle(Bauhaus.Color.accent)
                Text("\(receipts.count) Receipts")
                    .font(Bauhaus.Font.subHeader)
                    .foregroundStyle(Bauhaus.Color.textPrimary)
            }
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.surface.opacity(0.3))
        .cornerRadius(Bauhaus.Grid.cornerRadius)
    }
}

struct AnalysisReceiptRow: View {
    let receipt: AnalysisReceipt

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(receipt.message)
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textPrimary)
                Text(receipt.timestamp.formatted(date: .abbreviated, time: .standard))
                    .font(Bauhaus.Font.micro)
                    .foregroundStyle(Bauhaus.Color.textTertiary)
            }

            Spacer()

            Text(receipt.hash?.prefix(12).description ?? "no hash")
                .font(Bauhaus.Font.micro)
                .foregroundStyle(Bauhaus.Color.textTertiary)
        }
        .padding(.vertical, 4)
    }
}

struct ReproducibilityCard: View {
    let analysis: Analysis

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            Text("Reproducible run")
                .font(Bauhaus.Font.subHeader)
                .foregroundStyle(Bauhaus.Color.textPrimary)

            InfoRow(label: "Run ID", value: analysis.id)
            InfoRow(label: "Query", value: analysis.query)
            InfoRow(label: "Phase", value: analysis.phase.displayName)
            InfoRow(label: "Timestamp", value: analysis.timestamp.formatted(date: .abbreviated, time: .standard))

            Text("TabularData-backed slicing is scaffolded for the structured view layer; this card makes the run recipe visible even before a live dataframe store is wired.")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textTertiary)
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.surface.opacity(0.4))
        .cornerRadius(Bauhaus.Grid.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                .stroke(Bauhaus.Color.border, lineWidth: 0.5)
        )
    }
}

// MARK: - Data

struct AnalysisDataView: View {
    let analysis: Analysis

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
            AnalysisDataTable(rows: analysisDataRows)
            DataLayerCallout()
        }
    }

    private var analysisDataRows: [AnalysisDataRow] {
        var rows: [AnalysisDataRow] = [
            AnalysisDataRow(field: "Query", value: analysis.query, evidence: "run input", note: "Reproducible front door"),
            AnalysisDataRow(field: "Phase", value: analysis.phase.displayName, evidence: "state", note: "Live run stage"),
            AnalysisDataRow(field: "Results", value: "\(analysis.results.count)", evidence: "result set", note: "Structured output"),
            AnalysisDataRow(field: "Sources", value: "\(analysis.sources.count)", evidence: "provenance", note: "Evidence trail"),
            AnalysisDataRow(field: "Receipts", value: "\(analysis.receipts.count)", evidence: "audit chain", note: "Chain of custody")
        ]

        let status = analysis.computeStatus
        rows.append(AnalysisDataRow(field: "Capsule", value: status.capsuleName ?? "Unknown", evidence: "compute status", note: status.capsuleName ?? "N/A"))
        rows.append(AnalysisDataRow(field: "Metal", value: status.metalDevice ?? "Unavailable", evidence: "device probe", note: "Native render target"))

        rows.append(contentsOf: analysis.results.enumerated().map { index, result in
            AnalysisDataRow(
                field: "Result \(index + 1)",
                value: result.value,
                evidence: String(format: "%.0f%%", result.confidence * 100),
                note: "Confidence metric"
            )
        })

        return rows
    }
}

struct AnalysisDataRow: Identifiable {
    let id = UUID()
    let field: String
    let value: String
    let evidence: String
    let note: String
}

struct AnalysisDataTable: View {
    let rows: [AnalysisDataRow]

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            Text("Structured Data")
                .font(Bauhaus.Font.subHeader)
                .foregroundStyle(Bauhaus.Color.textPrimary)

            if rows.isEmpty {
                Text("No structured rows yet.")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textTertiary)
            } else {
                Grid(alignment: .leading, horizontalSpacing: Bauhaus.Grid.x2, verticalSpacing: Bauhaus.Grid.unit) {
                    GridRow {
                        tableHeader("Field")
                        tableHeader("Value")
                        tableHeader("Evidence")
                        tableHeader("Note")
                    }

                    ForEach(rows) { row in
                        GridRow {
                            tableCell(row.field)
                            tableCell(row.value)
                            tableCell(row.evidence)
                            tableCell(row.note)
                        }
                    }
                }
                .frame(minHeight: 220)
            }
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.surface.opacity(0.4))
        .cornerRadius(Bauhaus.Grid.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                .stroke(Bauhaus.Color.border, lineWidth: 0.5)
        )
    }

    private func tableHeader(_ text: String) -> some View {
        Text(text)
            .font(Bauhaus.Font.caption)
            .fontWeight(.semibold)
            .foregroundStyle(Bauhaus.Color.textSecondary)
            .textSelection(.enabled)
    }

    private func tableCell(_ text: String) -> some View {
        Text(text)
            .font(Bauhaus.Font.caption)
            .foregroundStyle(Bauhaus.Color.textPrimary)
            .textSelection(.enabled)
            .lineLimit(2)
    }
}

struct DataLayerCallout: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            Text("TabularData / SwiftUICharts / Probably")
                .font(Bauhaus.Font.subHeader)
                .foregroundStyle(Bauhaus.Color.textPrimary)
            Text("The analysis canvas now keeps the calm summary view, adds a lightweight confidence chart, and leaves the structured table layer ready for TabularData-backed slicing.")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.surface.opacity(0.25))
        .cornerRadius(Bauhaus.Grid.cornerRadius)
    }
}

// MARK: - Analysis Result Card

struct AnalysisResultCard: View {
    let result: AnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            // Result text
            Text(result.value)
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Metadata footer
            if result.confidence > 0 {
                Divider()
                
                HStack(spacing: Bauhaus.Grid.x2) {
                    if result.confidence > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: confidenceIcon(result.confidence))
                                .font(Bauhaus.Font.small)
                                .foregroundStyle(confidenceColor(result.confidence))
                            Text(String(format: "%.0f%%", result.confidence * 100))
                                .font(Bauhaus.Font.caption)
                                .foregroundStyle(Bauhaus.Color.textSecondary)
                        }
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.surface)
        .cornerRadius(Bauhaus.Grid.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                .stroke(Bauhaus.Color.border, lineWidth: 0.5)
        )
    }
    
    private func confidenceIcon(_ confidence: Double) -> String {
        if confidence >= 0.8 { return "checkmark.circle.fill" }
        if confidence >= 0.5 { return "exclamationmark.circle.fill" }
        return "questionmark.circle.fill"
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 { return Bauhaus.Color.trusted }
        if confidence >= 0.5 { return Bauhaus.Color.warning }
        return Bauhaus.Color.error
    }
}

// MARK: - Compute Status Card

struct ComputeStatusCard: View {
    let analysis: Analysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            HStack(spacing: Bauhaus.Grid.unit) {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
                
                Text("Computing...")
                    .font(Bauhaus.Font.body)
                    .foregroundStyle(Bauhaus.Color.textPrimary)
            }
            
            let status = analysis.computeStatus
            VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                InfoRow(label: "Capsule", value: status.capsuleName ?? "Unknown")
                InfoRow(label: "Phase", value: analysis.phase.displayName)
                
                if let device = status.metalDevice {
                    InfoRow(label: "Device", value: device)
                }
            }
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.surface.opacity(0.5))
        .cornerRadius(Bauhaus.Grid.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                .stroke(Bauhaus.Color.running.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Sources Disclosure

struct SourcesDisclosureGroup: View {
    let sources: [SourceReference]
    @State private var isExpanded = false
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                ForEach(sources) { source in
                    SourceReferenceRow(source: source)
                }
            }
            .padding(.top, Bauhaus.Grid.unit)
        } label: {
            HStack {
                Image(systemName: "doc.on.doc")
                    .font(Bauhaus.Font.icon)
                    .foregroundStyle(Bauhaus.Color.accent)
                
                Text("\(sources.count) Sources")
                    .font(Bauhaus.Font.subHeader)
                    .foregroundStyle(Bauhaus.Color.textPrimary)
            }
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.surface.opacity(0.3))
        .cornerRadius(Bauhaus.Grid.cornerRadius)
    }
}

struct SourceReferenceRow: View {
    let source: SourceReference
    
    var confidenceColor: Color {
        guard let confidence = source.confidence else { return Bauhaus.Color.textTertiary }
        if confidence >= 0.8 { return .green }
        if confidence >= 0.5 { return .yellow }
        return .red
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: Bauhaus.Grid.unit) {
            Image(systemName: "doc")
                .font(Bauhaus.Font.small)
                .foregroundStyle(Bauhaus.Color.textTertiary)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(source.title)
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textPrimary)
                    .lineLimit(1)
                
                if let path = source.path {
                    Text(path)
                        .font(Bauhaus.Font.micro)
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                if let trustTier = source.trustTier {
                    Text("Trust: \(trustTier)")
                        .font(Bauhaus.Font.micro)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if let confidence = source.confidence {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(confidenceColor)
                        Text(String(format: "%.0f%%", confidence * 100))
                            .font(Bauhaus.Font.micro)
                            .foregroundStyle(confidenceColor)
                    }
                    .help("Confidence level: \(String(format: "%.0f%%", confidence * 100)). \(confidenceLevel(confidence)) confidence.")
                }
                
                if let similarity = source.similarity {
                    Text(String(format: "%.2f", similarity))
                        .font(Bauhaus.Font.micro)
                        .foregroundStyle(Bauhaus.Color.textTertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Source: \(source.path ?? source.title), confidence: \(source.confidence.map { String(format: "%.0f%%", $0 * 100) } ?? "unknown")")
    }
    
    private func confidenceLevel(_ confidence: Double) -> String {
        if confidence >= 0.8 { return "High" }
        if confidence >= 0.5 { return "Medium" }
        return "Low"
    }
}

// MARK: - Analysis Type Stub

struct Analysis: Identifiable {
    let id: String
    let query: String
    let summary: String
    let sources: [SourceReference]
    let results: [AnalysisResult]
    let computeStatus: AnalysisStatus
    let isVerified: Bool
    let phase: AnalysisPhase
    let timestamp: Date
    let receipts: [AnalysisReceipt]
    
    var elapsedTime: TimeInterval {
        Date().timeIntervalSince(timestamp)
    }
    
    init(query: String, summary: String = "Analysis summary") {
        self.id = UUID().uuidString
        self.query = query
        self.summary = summary
        self.sources = []
        self.results = []
        self.computeStatus = .pending
        self.isVerified = false
        self.phase = .initial
        self.timestamp = Date()
        self.receipts = []
    }
}

enum AnalysisStatus: String {
    case pending
    case running
    case complete
    case failed
    
    var capsuleName: String? {
        switch self {
        case .running: return "Computing"
        default: return nil
        }
    }
    
    var metalDevice: String? {
        switch self {
        case .running: return "Metal Active"
        default: return nil
        }
    }
}

enum AnalysisPhase: String, CaseIterable {
    case initial
    case preprocessing
    case preparing
    case analysis
    case computing
    case verification
    case complete
    
    var displayName: String {
        switch self {
        case .initial: return "Initial"
        case .preprocessing: return "Preprocessing"
        case .preparing: return "Preparing"
        case .analysis: return "Analysis"
        case .computing: return "Computing"
        case .verification: return "Verification"
        case .complete: return "Complete"
        }
    }
}

struct AnalysisResult: Identifiable {
    let id: String
    let title: String
    let value: String
    let confidence: Double
    let timestamp: Date
    
    init(title: String, value: String, confidence: Double = 0.0, timestamp: Date = Date()) {
        self.id = UUID().uuidString
        self.title = title
        self.value = value
        self.confidence = confidence
        self.timestamp = timestamp
    }
}

struct AnalysisReceipt: Identifiable {
    let id: String
    let timestamp: Date
    let message: String
    let hash: String?
    let operationType: String
    
    init(message: String, hash: String? = nil, operationType: String = "analysis") {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.message = message
        self.hash = hash
        self.operationType = operationType
    }
    
    func toCoreReceipt() -> CoreReceipt {
        CoreReceipt(id: id, operationType: operationType, summary: message, metadata: [:])
    }
}

struct SourceReference: Identifiable {
    let id: String
    let title: String
    let path: String?
    let excerpt: String?
    let similarity: Double?
    let confidence: Double?
    let trustTier: String?
    
    init(title: String, path: String? = nil, excerpt: String? = nil, similarity: Double? = nil, confidence: Double? = nil, trustTier: String? = nil) {
        self.id = UUID().uuidString
        self.title = title
        self.path = path
        self.excerpt = excerpt
        self.similarity = similarity
        self.confidence = confidence
        self.trustTier = trustTier
    }
}

// MARK: - Analysis Assistant State

@Observable
final class AnalysisAssistantState: NSObject, ObservableObject {
    @ObservationIgnored @Published var id: String
    @ObservationIgnored @Published var name: String
    @ObservationIgnored @Published var status: String
    @ObservationIgnored @Published var currentAnalysis: Analysis?
    
    init(id: String = "analysis", name: String = "Analysis Assistant", status: String = "ready", currentAnalysis: Analysis? = nil) {
        self.id = id
        self.name = name
        self.status = status
        self.currentAnalysis = currentAnalysis
        super.init()
    }
    
    func exportAnalysis() {
        // Stub: In a real app, this would export the analysis to a file
        print("Exporting analysis: \(currentAnalysis?.summary ?? "Unknown")")
    }
}

// MARK: - InfoRow Helper View

// Using DesignSystem.InfoRow for consistency
