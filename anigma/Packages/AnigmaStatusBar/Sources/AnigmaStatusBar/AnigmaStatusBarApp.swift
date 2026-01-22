import SwiftUI
import AnigmaSidecar
import AnigmaPrimitives

@main
struct AnigmaStatusBarApp: App {
    @StateObject private var viewModel = StatusBarViewModel()
    
    var body: some Scene {
        MenuBarExtra {
            StatusBarView(viewModel: viewModel)
        } label: {
            StatusIcon(status: viewModel.daemonStatus)
        }
        .menuBarExtraStyle(.window) // Use window style for richer UI
    }
}

enum DaemonStatus {
    case running
    case stopped
    case checking
    case unknown
}

class StatusBarViewModel: ObservableObject {
    @Published var daemonStatus: DaemonStatus = .checking
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: Double = 0.0
    @Published var pendingJobs: Int = 0
    @Published var lastCheck: Date = Date()
    @Published var daemonVersion: String = ""
    
    private var timer: Timer?
    
    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        checkStatus()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkStatus()
        }
    }
    
    func checkStatus() {
        Task {
            let status = await DaemonLifecycle.status()
            
            await MainActor.run {
                switch status {
                case .running:
                    self.daemonStatus = .running
                    // Fetch real stats from the daemon
                    self.fetchDaemonStats()
                case .stopped:
                    self.daemonStatus = .stopped
                    self.resetStats()
                case .unresponsive:
                    self.daemonStatus = .unknown
                    self.resetStats()
                }
                self.lastCheck = Date()
            }
        }
    }
    
    private func fetchDaemonStats() {
        Task {
            do {
                // Reuse existing bridge or create a new one (SidecarBridge manages connection)
                let bridge = try await SidecarBridge.create(clientName: "AnigmaStatusBar")
                let statusResponse = try await bridge.getStatus()
                
                await MainActor.run {
                    self.daemonVersion = statusResponse.daemonVersion
                    // Parse extraJson for extended stats if available
                    if let extraJson = statusResponse.extraJson,
                       let data = extraJson.data(using: .utf8),
                       let stats = try? JSONDecoder().decode(DaemonStats.self, from: data) {
                        self.cpuUsage = stats.cpuUsage
                        self.memoryUsage = stats.memoryUsageMB
                        self.pendingJobs = stats.pendingJobs
                    } else {
                        // Fallback if extraJson is missing or unparseable
                        self.cpuUsage = 0.0
                        self.memoryUsage = 0.0
                        self.pendingJobs = 0
                    }
                }
            } catch {
                print("Failed to fetch daemon stats: \(error)")
                await MainActor.run {
                    self.resetStats()
                }
            }
        }
    }
    
    func restartDaemon() {
        Task {
            do {
                _ = try await DaemonLifecycle.start()
                await checkStatus()
            } catch {
                print("Failed to restart daemon: \(error)")
            }
        }
    }
    
    func openCLI() {
        let script = """
        tell application "Terminal"
            do script "anigma"
            activate
        end tell
        """
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
        }
    }
    
    func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func resetStats() {
        self.cpuUsage = 0
        self.memoryUsage = 0
        self.pendingJobs = 0
        self.daemonVersion = ""
    }
}

// Helper struct for decoding JSON stats from daemon
struct DaemonStats: Codable {
    let cpuUsage: Double
    let memoryUsageMB: Double
    let pendingJobs: Int
}

struct StatusIcon: View {
    let status: DaemonStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "cpu")
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        }
    }
    
    var color: Color {
        switch status {
        case .running: return .green
        case .stopped: return .red
        case .checking: return .yellow
        case .unknown: return .gray
        }
    }
}

struct StatusBarView: View {
    @ObservedObject var viewModel: StatusBarViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Anigma Daemon")
                    .font(.headline)
                if !viewModel.daemonVersion.isEmpty {
                    Text(viewModel.daemonVersion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                StatusBadge(status: viewModel.daemonStatus)
            }
            .padding(.bottom, 4)
            
            Divider()
            
            // Stats Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatBox(title: "CPU", value: String(format: "%.1f%%", viewModel.cpuUsage), icon: "cpu")
                StatBox(title: "Memory", value: String(format: "%.0f MB", viewModel.memoryUsage), icon: "memorychip")
                StatBox(title: "Jobs", value: "\(viewModel.pendingJobs)", icon: "list.bullet.clipboard")
                StatBox(title: "Status", value: viewModel.daemonStatus == .running ? "OK" : "ERR", icon: "waveform.path.ecg") 
            }
            
            Divider()
            
            // Controls
            VStack(spacing: 8) {
                Button(action: { viewModel.restartDaemon() }) {
                    Label("Restart Daemon", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: { viewModel.openCLI() }) {
                    Label("Open CLI", systemImage: "terminal")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: { viewModel.quitApp() }) {
                    Label("Quit Helper", systemImage: "power")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            
            HStack {
                Spacer()
                Text("Last check: \(viewModel.lastCheck.formatted(date: .omitted, time: .standard))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 280)
    }
}

struct StatusBadge: View {
    let status: DaemonStatus
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(8)
    }
    
    var text: String {
        switch status {
        case .running: return "ACTIVE"
        case .stopped: return "STOPPED"
        case .checking: return "CHECKING"
        case .unknown: return "UNKNOWN"
        }
    }
    
    var color: Color {
        switch status {
        case .running: return .green
        case .stopped: return .red
        case .checking: return .yellow
        case .unknown: return .gray
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
}
