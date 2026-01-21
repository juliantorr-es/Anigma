//
//  PlotLens.swift
//  DataUI
//
//  A plotting view backed by a dataset.
//  Interaction: Filter, Zoom, Inspect Points.
//

import SwiftUI
import Charts
import DataCore

public struct PlotLens: View {
    @Binding var selection: String?

    // Mock Data
    struct DataPoint: Identifiable {
        let id: String
        let category: String
        let value: Double
        let date: Date
    }

    let data: [DataPoint] = [
        DataPoint(id: "pt-1", category: "A", value: 10, date: Date().addingTimeInterval(-86400 * 3)),
        DataPoint(id: "pt-2", category: "B", value: 15, date: Date().addingTimeInterval(-86400 * 2)),
        DataPoint(id: "pt-3", category: "A", value: 20, date: Date().addingTimeInterval(-86400 * 1)),
        DataPoint(id: "pt-4", category: "B", value: 12, date: Date()),
        DataPoint(id: "pt-5", category: "C", value: 25, date: Date())
    ]

    public init(selection: Binding<String?>) {
        self._selection = selection
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Plot Configuration Bar (simplified inspector)
            HStack {
                Label("Scatter Plot", systemImage: "chart.xyaxis.line")
                    .font(.caption).bold()
                Spacer()
                Text("X: Date").font(.caption).foregroundColor(.secondary)
                Text("Y: Value").font(.caption).foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)

            Chart {
                ForEach(data) { point in
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(by: .value("Category", point.category))
                    .symbolSize(selection == point.id ? 200 : 100) // visual feedback
                    .accessibilityLabel("\(point.category): \(Int(point.value))")
                    .accessibilityValue("Date: \(point.date.formatted(date: .abbreviated, time: .omitted))")
                }

                if let selectedId = selection, let point = data.first(where: { $0.id == selectedId }) {
                    RuleMark(x: .value("Selected Date", point.date))
                        .foregroundStyle(.gray.opacity(0.5))
                    RuleMark(y: .value("Selected Value", point.value))
                        .foregroundStyle(.gray.opacity(0.5))
                }

                RuleMark(y: .value("Threshold", 15))
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Limit").font(.caption).foregroundColor(.red)
                    }
            }
            .accessibilityLabel("Scatter Plot of Value over Date")
            .accessibilityHint("Shows data points for categories A, B, and C.")
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartOverlay { _ in
                GeometryReader { _ in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onTapGesture { _ in
                            // Simple hit testing for demo
                            // In real app, map location to data using proxy
                            // Here we just deselect if tapping background
                            selection = nil
                        }
                        .accessibilityHidden(true)
                }
            }
            // Basic tap handler for points needs richer interaction in Charts,
            // or we simulate by iterating points and finding closest.
            // For this scaffold, we rely on the visual change.
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
