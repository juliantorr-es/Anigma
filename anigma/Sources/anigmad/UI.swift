import SwiftUI
import AppKit

// MARK: - Menu Bar App

@main
struct AnigmaDaemonApp: App {
@StateObject private var daemonManager = DaemonManager()
@State private var showingConfig = false

var body: some Scene {
MenuBarExtra("Anigma Daemon", systemImage: daemonManager.isRunning ? "server.rack.fill" : "server.rack") {
VStack(spacing: 12) {
// Header
VStack(spacing: 4) {
Text("Anigma Daemon")
.font(.headline)
Text(daemonManager.isRunning ? "Status: Running" : "Status: Stopped")
.font(.caption)
.foregroundColor(daemonManager.isRunning ? .green : .red)
}
.padding(.horizontal)

Divider()

// Metrics Display
if daemonManager.isRunning {
VStack(alignment: .leading, spacing: 6) {
MetricRow(label: "CPU:", value: "\(String(format: "%.1f", daemonManager.metrics.cpuUsage))%")
MetricRow(label: "Memory:", value: "\(String(format: "%.1f", daemonManager.metrics.memoryUsage))%")
MetricRow(label: "Uptime:", value: formatUptime(daemonManager.metrics.uptime))
MetricRow(label: "Connections:", value: "\(daemonManager.metrics.networkConnections)")
}
.padding(.horizontal)

Divider()
}

// AI Services Status
if !daemonManager.aiServiceStatus.isEmpty {
VStack(alignment: .leading, spacing: 4) {
Text("AI Services")
.font(.caption)
.foregroundColor(.secondary)

ForEach(daemonManager.aiServiceStatus.keys.sorted(), id: \.self) { service in
HStack {
Image(systemName: daemonManager.aiServiceStatus[service] ?? false ? "checkmark.circle.fill" : "xmark.circle.fill")
.foregroundColor(daemonManager.aiServiceStatus[service] ?? false ? .green : .red)
Text(service)
.font(.caption)
}
}
}
.padding(.horizontal)

Divider()
}

// Control Buttons
VStack(spacing: 8) {
if daemonManager.isRunning {
// swiftlint:disable:next accessibility_label_required
Button("Stop Daemon") {
Task {
await daemonManager.stop()
}
}
.accessibilityLabel("Stop Daemon")

// swiftlint:disable:next accessibility_label_required
Button("Restart Daemon") {
Task {
await daemonManager.restart()
}
}
.accessibilityLabel("Restart Daemon")
} else {
// swiftlint:disable:next accessibility_label_required
Button("Start Daemon") {
Task {
await daemonManager.start()
}
}
.accessibilityLabel("Start Daemon")
}

// swiftlint:disable:next accessibility_label_required
Button("Configuration") {
showingConfig = true
}
.accessibilityLabel("Configuration")

Divider()

// swiftlint:disable:next accessibility_label_required
Button("Open Logs") {
openLogs()
}
.accessibilityLabel("Open Logs")

// swiftlint:disable:next accessibility_label_required
Button("Diagnostics") {
showDiagnostics()
}
.accessibilityLabel("Diagnostics")

Divider()

// swiftlint:disable:next accessibility_label_required
Button("Quit") {
Task {
await daemonManager.stop()
}
NSApplication.shared.terminate(nil)
}
.accessibilityLabel("Quit")
}
.padding(.horizontal)
}
.frame(minWidth: 350, idealWidth: 400, maxWidth: 500)
.sheet(isPresented: $showingConfig) {
ConfigView(daemonManager: daemonManager, isPresented: $showingConfig)
}
}
}

private func openLogs() {
if let logPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("Logs/com.anigma.daemon") {
NSWorkspace.shared.open(logPath)
}
}

private func showDiagnostics() {
let alert = NSAlert()
alert.messageText = "Daemon Diagnostics"
alert.alertStyle = .informational
alert.informativeText = """
Server Port: \(daemonManager.config.serverPort)
Log Level: \(daemonManager.config.logLevel.rawValue)
Auto Start: \(daemonManager.config.autoStart ? "Yes" : "No")
Notifications: \(daemonManager.config.enableNotifications ? "Enabled" : "Disabled")

Current Metrics:
CPU: \(String(format: "%.1f", daemonManager.metrics.cpuUsage))%
Memory: \(String(format: "%.1f", daemonManager.metrics.memoryUsage))%
Uptime: \(formatUptime(daemonManager.metrics.uptime))
"""
// swiftlint:disable:next accessibility_label_required
alert.addButton(withTitle: "OK")
alert.runModal()
}

private func formatUptime(_ seconds: TimeInterval) -> String {
let hours = Int(seconds) / 3600
let minutes = (Int(seconds) % 3600) / 60
let secs = Int(seconds) % 60
return String(format: "%02d:%02d:%02d", hours, minutes, secs)
}

// MARK: - UI Components

struct MetricRow: View {
let label: String
let value: String

var body: some View {
HStack {
Text(label)
.font(.caption)
.foregroundColor(.secondary)
Spacer()
Text(value)
.font(.caption.monospaced())
}
}
}

struct ConfigView: View {
@ObservedObject var daemonManager: DaemonManager
@Binding var isPresented: Bool
@State private var localConfig: DaemonConfig
@State private var showingSaveAlert = false
@State private var saveMessage = ""

init(daemonManager: DaemonManager, isPresented: Binding<Bool>) {
self.daemonManager = daemonManager
self._isPresented = isPresented
self._localConfig = State(initialValue: daemonManager.config)
}

var body: some View {
VStack {
Text("Daemon Configuration")
.font(.headline)

Form {
Section("Server Configuration") {
HStack {
Text("Port:")
// swiftlint:disable:next accessibility_label_required
TextField("Port", value: $localConfig.serverPort, format: .number)
.textFieldStyle(.roundedBorder)
.frame(width: 80)
.accessibilityLabel("Server Port")
}

// swiftlint:disable:next accessibility_label_required
Toggle("Auto Start on Login", isOn: $localConfig.autoStart)
.accessibilityLabel("Auto Start on Login")
// swiftlint:disable:next accessibility_label_required
Toggle("Enable Notifications", isOn: $localConfig.enableNotifications)
.accessibilityLabel("Enable Notifications")
}

Section("Logging Configuration") {
Picker("Log Level", selection: $localConfig.logLevel) {
ForEach(LogLevel.allCases, id: \.self) { level in
Text(level.rawValue.capitalized).tag(level)
}
}
.accessibilityLabel("Log Level")

HStack {
Text("Max Log Size:")
// swiftlint:disable:next accessibility_label_required
TextField("MB", value: $localConfig.maxLogSizeMB, format: .number)
.textFieldStyle(.roundedBorder)
.frame(width: 60)
.accessibilityLabel("Max Log Size in MB")
Text("MB")
}

HStack {
Text("Max Log Files:")
// swiftlint:disable:next accessibility_label_required
TextField("Files", value: $localConfig.maxLogFiles, format: .number)
.textFieldStyle(.roundedBorder)
.frame(width: 60)
.accessibilityLabel("Max Log Files")
}
}

Section {
HStack {
// swiftlint:disable:next accessibility_label_required
Button("Save") {
saveConfig()
}
.accessibilityLabel("Save Configuration")
.keyboardShortcut(.defaultAction)

// swiftlint:disable:next accessibility_label_required
Button("Cancel") {
isPresented = false
}
.accessibilityLabel("Cancel")
.keyboardShortcut(.cancelAction)
}
}
}
.padding()
.frame(width: 400, height: 500)
.alert("Configuration Saved", isPresented: $showingSaveAlert) {
// swiftlint:disable:next accessibility_label_required
Button("OK") {
isPresented = false
}
.accessibilityLabel("OK")
} message: {
Text(saveMessage)
}
}

private func saveConfig() {
Task {
do {
try await daemonManager.updateConfig(localConfig)
saveMessage = "Configuration saved successfully. Daemon will restart if running."
showingSaveAlert = true
} catch {
saveMessage = "Failed to save configuration: \(error.localizedDescription)"
showingSaveAlert = true
}
}
}
}
