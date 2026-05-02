//
//  MemoPanelView.swift
//  AnigmaAppMac
//
//  Memo capture workflow UI.
//

import SwiftUI
import HarmoniaV2Surface

struct MemoPanelView: View {
    @ObservedObject var model: AppModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Memo Capture").font(.headline)
                Spacer()
                if let saved = model.memoState.lastSavedAt {
                    Text("Saved: \(saved.formatted(date: .omitted, time: .standard))")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Divider()
            
            // Text Editor
            TextEditor(text: $model.memoState.text)
                .font(.system(.body, design: .monospaced))
                .padding(4)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            
            // Footer Controls
            HStack {
                Text("\(model.memoState.characterCount) chars")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let error = model.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(1)
                        .padding(.leading)
                }
                
                Spacer()
                
                Button("Clear") {
                    model.clearMemo()
                }
                .disabled(model.memoState.isSaving || model.memoState.text.isEmpty)
                
                Button("Save Memo") {
                    model.saveMemo()
                }
                .disabled(model.memoState.isSaving || model.memoState.text.isEmpty || model.selectedProjectId == nil)
                .keyboardShortcut(.return, modifiers: [.command])
            }
            
            // Status Line
            if let status = model.appStatus {
                HStack {
                    Image(systemName: status.killSwitchActive ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundColor(status.killSwitchActive ? .red : .green)
                    Text(status.killSwitchActive ? "Kill Switch Active" : "Writes Allowed")
                    
                    Divider().frame(height: 12)
                    
                    Text("Mode: \(status.operatingMode.rawValue)")
                        .foregroundColor(status.operatingMode.rawValue == "readOnly" ? .orange : .primary)
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}
