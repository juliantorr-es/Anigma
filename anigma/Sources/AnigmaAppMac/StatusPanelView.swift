//
//  StatusPanelView.swift
//  AnigmaAppMac
//
//  Displays mode and kill switch status.
//

import SwiftUI
import HarmoniaV2Surface
import AnigmaCore

struct StatusPanelView: View {
    @ObservedObject var model: AppModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let status = model.appStatus {
                // Mode
                VStack(alignment: .leading) {
                    Text("Operating Mode").font(.caption).foregroundColor(.secondary)
                    Picker("Mode", selection: Binding(
                        get: { status.operatingMode },
                        set: { newMode in Task { await model.setMode(newMode) } }
                    )) {
                        Text("Assistive").tag(OperatingMode.assistive)
                        Text("Autopilot").tag(OperatingMode.autopilot)
                        Text("Read Only").tag(OperatingMode.readOnly)
                    }
                    .pickerStyle(.segmented)
                    
                    Text("Source: \(status.modeSource == .project ? "Project Override" : "Global/Default")")
                        .font(.caption2).foregroundColor(.secondary)
                }
                
                // Kill Switch
                VStack(alignment: .leading) {
                    Text("Kill Switch").font(.caption).foregroundColor(.secondary)
                    Toggle("Active", isOn: Binding(
                        get: { status.killSwitchActive },
                        set: { newValue in Task { await model.setKillSwitch(active: newValue) } }
                    ))
                    if let reason = status.killSwitchReason {
                        Text(reason).font(.caption2).foregroundColor(.red)
                    }
                }
                
                // Denial Banner
                if let denial = status.lastDenial {
                    VStack(alignment: .leading) {
                        Text("Last Denial").font(.caption).fontWeight(.bold).foregroundColor(.red)
                        Text(denial.summary)
                            .font(.caption2)
                            .lineLimit(2)
                        if !denial.failedChecks.isEmpty {
                            Text("Checks: " + denial.failedChecks.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                }
                
            } else {
                Text("Select a project to view status")
                    .foregroundColor(.secondary)
            }
            
            if let error = model.lastError {
                Text(error).foregroundColor(.red).font(.caption)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}
