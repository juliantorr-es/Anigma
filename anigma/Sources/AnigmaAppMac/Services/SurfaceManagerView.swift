//
//  SurfaceManagerView.swift
//  AnigmaAppMac
//
//  Surface rendering and visualization management UI.
//

import SwiftUI
import AnigmaHostMac

private extension SurfaceType {
    static let allCases: [SurfaceType] = [.canvas, .graph, .timeline, .dashboard, .report]
}

struct SurfaceManagerView: View {
    @Environment(AppStore.self) private var store
    @State private var showingCreateSheet = false
    @State private var newSurfaceName = ""
    @State private var selectedSurfaceType: SurfaceType = .canvas
    @State private var newSurfaceWidth = ""
    @State private var newSurfaceHeight = ""
    @State private var newSurfaceBackgroundColor = ""
    @State private var newSurfaceInteractive = true
    @State private var newSurfaceTheme = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Surfaces")
                    .font(.headline)
                Spacer()
                Button(action: { showingCreateSheet = true }) {
                    Label("New Surface", systemImage: "plus")
                }
            }
            .padding(.horizontal)

            if store.surfaces.isEmpty {
                ContentUnavailableView(
                    "No Surfaces",
                    systemImage: "rectangle.on.rectangle.angled",
                    description: Text("Create a surface to start rendering visualizations")
                )
            } else {
                List(store.surfaces) { surface in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(surface.name)
                                .font(.body)
                            Text(surface.type.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(surface.createdAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button(role: .destructive, action: { deleteSurface(id: surface.id) }) {
                            Image(systemName: "trash")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .padding()
        .task {
            await store.loadSurfaces()
        }
        .sheet(isPresented: $showingCreateSheet) {
            createSurfaceSheet
        }
    }

    private var createSurfaceSheet: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $newSurfaceName)
                Picker("Type", selection: $selectedSurfaceType) {
                    ForEach(SurfaceType.allCases, id: \.self) { type in
                        Text(type.rawValue.capitalized).tag(type)
                    }
                }
                TextField("Width (optional)", text: $newSurfaceWidth)
                TextField("Height (optional)", text: $newSurfaceHeight)
                TextField("Background Color (optional, e.g., #FFFFFF)", text: $newSurfaceBackgroundColor)
                Toggle("Interactive", isOn: $newSurfaceInteractive)
                TextField("Theme (optional)", text: $newSurfaceTheme)
            }
            .formStyle(.grouped)
            .navigationTitle("New Surface")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCreateSheet = false
                        resetForm()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createSurface()
                    }
                    .disabled(newSurfaceName.isEmpty)
                }
            }
        }
        .frame(width: 400, height: 500)
    }

    private func createSurface() {
        let config = SurfaceConfig(
            width: Int(newSurfaceWidth),
            height: Int(newSurfaceHeight),
            backgroundColor: newSurfaceBackgroundColor.isEmpty ? nil : newSurfaceBackgroundColor,
            interactive: newSurfaceInteractive,
            theme: newSurfaceTheme.isEmpty ? nil : newSurfaceTheme
        )
        Task {
            await store.surfaceStore.createSurface(
                name: newSurfaceName,
                type: selectedSurfaceType,
                config: config
            )
            showingCreateSheet = false
            resetForm()
        }
    }

    private func deleteSurface(id: String) {
        Task {
            await store.surfaceStore.deleteSurface(id: id)
        }
    }

    private func resetForm() {
        newSurfaceName = ""
        selectedSurfaceType = .canvas
        newSurfaceWidth = ""
        newSurfaceHeight = ""
        newSurfaceBackgroundColor = ""
        newSurfaceInteractive = true
        newSurfaceTheme = ""
    }
}
