//
//  HarmoniaRootView.swift
//  AnigmaAppMac
//
//  Phase 3 Main View.
//

import SwiftUI
import HarmoniaV2Surface

struct HarmoniaRootView: View {
    @StateObject private var model: AppModel
    
    init() {
        // Check bundle identifier (required for macOS APIs)
        if let bundleId = Bundle.main.bundleIdentifier {
            print("✅ Bundle identifier: \(bundleId)")
        } else {
            print("⚠️  WARNING: No bundle identifier found!")
            print("⚠️  This app must be run as a .app bundle, not a raw executable.")
            print("⚠️  Use: ./run_prototype.sh")
        }
        
        // Initialize with LocalAppClient
        // DB Path: Application Support
        do {
            let appSupport = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let dbDir = appSupport.appendingPathComponent("Anigma")
            
            try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
            
            let dbPath = dbDir.appendingPathComponent("harmonia_v3.postgres").path
            
            print("✅ Database path: \(dbPath)")
            
            let client = LocalAppClient(databasePath: dbPath)
            _model = StateObject(wrappedValue: AppModel(client: client))
        } catch {
            print("❌ FATAL: Failed to initialize app: \(error)")
            fatalError("Failed to initialize: \(error)")
        }
    }
    
    var body: some View {
        HSplitView {
            // Sidebar
            VStack {
                Text("Projects").font(.headline).padding(.top)
                ProjectBootstrapView(model: model)
                Spacer()
                StatusPanelView(model: model)
            }
            .frame(minWidth: 200, maxWidth: 300)
            
            // Main Content
            VStack {
                if let projectId = model.selectedProjectId {
                    // Show active project
                    HStack {
                        Text("Project: \(model.projects.first(where: { $0.id == projectId })?.name ?? projectId)")
                            .font(.headline)
                        Spacer()
                        if let status = model.appStatus {
                            Text("Mode: \(status.operatingMode.rawValue)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    TabView {
                        IndexPanelView(model: model)
                            .tabItem {
                                Label("Index", systemImage: "doc.text.magnifyingglass")
                            }
                        
                        RecallPanelView(model: model)
                            .tabItem {
                                Label("Search", systemImage: "magnifyingglass")
                            }
                        
                        MemoPanelView(model: model)
                            .tabItem {
                                Label("Memo", systemImage: "square.and.pencil")
                            }
                    }
                    .padding()
                } else {
                    Text("Select a project to begin")
                        .font(.title)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
