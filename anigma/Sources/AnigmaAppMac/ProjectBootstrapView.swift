//
//  ProjectBootstrapView.swift
//  AnigmaAppMac
//
//  Project creation and selection.
//

import SwiftUI
import HarmoniaV2Surface

struct ProjectBootstrapView: View {
    @ObservedObject var model: AppModel
    @State private var showingCreateSheet = false
    @State private var newProjectName = ""
    @State private var newProjectModel = "text-embedding-3-small"
    
    var body: some View {
        VStack {
            List(model.projects, id: \.id) { project in
                HStack {
                    VStack(alignment: .leading) {
                        Text(project.name).font(.headline)
                        Text(project.embeddingModel).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    if model.selectedProjectId == project.id {
                        Image(systemName: "checkmark")
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    Task { await model.selectProject(project.id) }
                }
            }
            
            Button("New Project") {
                showingCreateSheet = true
            }
            .padding()
        }
        .sheet(isPresented: $showingCreateSheet) {
            Form {
                TextField("Project Name", text: $newProjectName)
                TextField("Embedding Model", text: $newProjectModel)
                Button("Create") {
                    Task {
                        await model.createProject(name: newProjectName, embeddingModel: newProjectModel)
                        showingCreateSheet = false
                    }
                }
            }
            .padding()
        }
        .onAppear {
            Task { await model.bootstrap() }
        }
    }
}
