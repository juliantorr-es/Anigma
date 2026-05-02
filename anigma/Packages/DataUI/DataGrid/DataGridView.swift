//
//  DataGridView.swift
//  DataUI
//
//  Created by Anigma Agent.
//

import SwiftUI
import RendererKit

public struct DataGridView: View {
    let artifact: RenderArtifact
    @State private var viewModel: GridViewModel?

    public init(artifact: RenderArtifact) {
        self.artifact = artifact
    }

    public var body: some View {
        VStack {
            if let viewModel = viewModel {
                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(alignment: .leading) {
                        // Header
                        HStack {
                            ForEach(viewModel.columns, id: \.self) { column in
                                Text(column)
                                    .font(.caption)
                                    .bold()
                                    .frame(width: 100, alignment: .leading)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isHeader)

                        // Rows
                        ForEach(0..<viewModel.rows.count, id: \.self) { rowIndex in
                            HStack {
                                ForEach(0..<viewModel.rows[rowIndex].count, id: \.self) { colIndex in
                                    Text(viewModel.rows[rowIndex][colIndex])
                                        .font(.caption)
                                        .frame(width: 100, alignment: .leading)
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Row \(rowIndex + 1)")
                        }
                    }
                }
            } else {
                ProgressView("Loading Grid...")
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
            viewModel = try JSONDecoder().decode(GridViewModel.self, from: artifact.data)
        } catch {
            print("Failed to decode GridViewModel: \(error)")
        }
    }
}
