//
//  SettingsView.swift
//  AnigmaAppMac
//
//  Application settings view.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            DaemonSettingsView()
                .tabItem {
                    Label("Daemon", systemImage: "server.rack")
                }
            
            GovernanceSettingsView()
                .tabItem {
                    Label("Governance", systemImage: "shield.checkered")
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("appearance") private var appearance: String = "system"
    @AppStorage("showStatusBar") private var showStatusBar: Bool = true
    
    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
                
                Toggle("Show Status Bar Icon", isOn: $showStatusBar)
            }
            
            Section("Startup") {
                Toggle("Launch at Login", isOn: .constant(false))
                Toggle("Connect to Daemon Automatically", isOn: .constant(true))
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct DaemonSettingsView: View {
    @State private var daemonPath: String = "anigmad"
    @State private var port: String = "9876"
    
    var body: some View {
        Form {
            Section("Connection") {
                TextField("Daemon Path", text: $daemonPath)
                TextField("Port", text: $port)
            }
            
            Section("Advanced") {
                Toggle("Auto-restart on Crash", isOn: .constant(true))
                Toggle("Enable Debug Logging", isOn: .constant(false))
                
                HStack {
                    Text("Log Level")
                    Spacer()
                    Picker("", selection: .constant("info")) {
                        Text("Debug").tag("debug")
                        Text("Info").tag("info")
                        Text("Warning").tag("warning")
                        Text("Error").tag("error")
                    }
                    .frame(width: 120)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct GovernanceSettingsView: View {
    var body: some View {
        Form {
            Section("CI Gates") {
                Toggle("Swift 6 Compliance Check", isOn: .constant(true))
                Toggle("Type Authority Validation", isOn: .constant(true))
                Toggle("Dependency Boundary Check", isOn: .constant(true))
                Toggle("Escape Hatch Audit", isOn: .constant(true))
                Toggle("Macro Expansion Analysis", isOn: .constant(true))
            }
            
            Section("Notifications") {
                Toggle("Alert on Gate Failures", isOn: .constant(true))
                Toggle("Daily Summary Report", isOn: .constant(false))
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    SettingsView()
}
