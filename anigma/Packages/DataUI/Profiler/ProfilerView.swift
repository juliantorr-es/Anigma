//
//  ProfilerView.swift
//  DataUI
//
//  Created by Anigma Agent.
//

import SwiftUI
import RendererKit

public struct ProfilerView: View {
    let artifact: RenderArtifact
    @State private var viewModel: ProfileViewModel?

    public init(artifact: RenderArtifact) {
        self.artifact = artifact
    }

    public var body: some View {
        VStack {
            if let viewModel = viewModel {
                List {
                    Section(header: Text("Overview")) {
                        HStack {
                            Text("Total Rows")
                            Spacer()
                            Text("\(viewModel.totalRows)")
                        }
                        .accessibilityElement(children: .combine)

                        HStack {
                            Text("Health Score")
                            Spacer()
                            Text(String(format: "%.2f", viewModel.healthScore))
                        }
                        .accessibilityElement(children: .combine)
                    }

                    Section(header: Text("Columns")) {
                        ForEach(viewModel.columns, id: \.name) { column in
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(column.name).bold()
                                    Spacer()
                                    Text(column.type).foregroundColor(.secondary)
                                }
                                HStack {
                                    Text("Nulls: \(column.nullCount)")
                                    Spacer()
                                    Text("Distinct: \(column.distinctCount)")
                                }
                                .font(.caption)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Column \(column.name), type \(column.type). \(column.nullCount) nulls, \(column.distinctCount) distinct values.")
                        }
                    }
                }
            } else {
                ProgressView("Loading Profile...")
            }
        }
        .onAppear {
            decodeViewModel()
        }
        .onChange(of: artifact.id) { _, _ in
            decodeViewModel()
        }
    }

    private func decodeViewModel() {
        do {
            viewModel = try JSONDecoder().decode(ProfileViewModel.self, from: artifact.data)
        } catch {
            print("Failed to decode ProfileViewModel: \(error)")
        }
    }
}
