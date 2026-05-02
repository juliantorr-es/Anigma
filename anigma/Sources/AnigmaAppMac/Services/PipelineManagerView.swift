//
//  PipelineManagerView.swift
//  AnigmaAppMac
//
//  Diaplasion pipeline management UI.
//

import SwiftUI

struct PipelineManagerView: View {
    @ObservedObject var model: AppModel
    @State private var showingCreatePipeline = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pipeline Manager")
                    .font(.headline)
                Spacer()
                Button("Create Pipeline") {
                    showingCreatePipeline = true
                }
                .buttonStyle(.borderedProminent)
            }

            List {
                Section("Pipelines") {
                    ForEach(model.pipelines) { pipeline in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(pipeline.name).font(.headline)
                                Text("\(pipeline.stageCount) stages").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Run") {
                                Task {
                                    await model.runPipeline(id: pipeline.id, inputs: [:])
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                Section("Active Runs") {
                    ForEach(model.pipelineRuns, id: \.runId) { run in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Run: \(run.runId.prefix(8))...")
                                    .font(.caption)
                                    .monospaced()
                                Text(run.status).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Monitor") {
                                // Monitor logic can be added to AppModel if needed
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            Button("Load Pipelines") {
                Task { await model.loadPipelines() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .task {
            await model.loadPipelines()
        }
        .sheet(isPresented: $showingCreatePipeline) {
            CreatePipelineView(model: model)
        }
    }
}

struct CreatePipelineView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var pipelineName = ""

    var body: some View {
        VStack {
            Form {
                TextField("Pipeline Name", text: $pipelineName)
                Text("Stages can be added after creation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            HStack {
                Button("Cancel") { dismiss() }
                Button("Create") {
                    Task {
                        await model.createPipeline(name: pipelineName, stages: [])
                        dismiss()
                    }
                }
                .disabled(pipelineName.isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 200)
    }
}
