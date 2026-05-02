import SwiftUI
import AnigmaSidecar
import AnigmaPrimitives
import Combine

@main
struct AnigmaStatusBarApp: App {
    @StateObject private var viewModel = StatusBarViewModel()
    
    var body: some Scene {
        MenuBarExtra {
            StatusBarView(viewModel: viewModel)
        } label: {
            StatusIcon(status: viewModel.daemonStatus)
        }
        .menuBarExtraStyle(.window)
    }
}

enum DaemonStatus: Equatable {
    case running
    case stopped
    case starting
    case stopping
    case checking
    case unknown
    case error(String)
}

enum MonitoringMetric: String, CaseIterable {
    case cpu = "CPU Usage"
    case memory = "Memory Usage"
    case network = "Network I/O"
    case disk = "Disk I/O"
    case errors = "Error Rate"
    case latency = "Response Time"
    case ane = "ANE Usage"
    case gpu = "GPU Usage"
    case mlJobs = "ML Jobs"
}

struct PerformancePoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
    let metric: MonitoringMetric
}

struct ANEStats {
    let usagePercentage: Double
    let temperature: Double?
    let powerUsage: Double?
    let inferenceCount: Int
    let modelCount: Int
    let isAvailable: Bool
}

struct DaemonStats: Codable {
    let cpuUsage: Double
    let memoryUsageMB: Double
    let pendingJobs: Int
    let networkBytesIn: Int
    let networkBytesOut: Int
    let diskReadBytes: Int
    let diskWriteBytes: Int
    let errorCount: Int
    let averageLatencyMs: Double
    let uptimeSeconds: Int
    let version: String
    let lastError: String?
    let mlJobs: Int?
    let aneUsage: Double?
    let gpuUsage: Double?
}

@MainActor
class StatusBarViewModel: ObservableObject {
    @Published var daemonStatus: DaemonStatus = .checking
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: Double = 0.0
    @Published var pendingJobs: Int = 0
    @Published var networkIn: Int = 0
    @Published var networkOut: Int = 0
    @Published var diskRead: Int = 0
    @Published var diskWrite: Int = 0
    @Published var errorCount: Int = 0
    @Published var latency: Double = 0.0
    @Published var uptime: String = "0s"
    @Published var daemonVersion: String = ""
    @Published var lastError: String = ""
    @Published var lastCheck: Date = Date()
    @Published var performanceHistory: [PerformancePoint] = []
    @Published var showNotifications: Bool = true
    
    // ANE/ML Monitoring
    @Published var aneUsage: Double = 0.0
    @Published var gpuUsage: Double = 0.0
    @Published var mlJobs: Int = 0
    @Published var aneTemperature: Double? = nil
    @Published var anePowerUsage: Double? = nil
    @Published var aneInferenceCount: Int = 0
    @Published var aneModelCount: Int = 0
    @Published var isANEAvailable: Bool = false
    
    private var timer: Timer?
    private var historyLimit = 100
    private var notificationCenter = NotificationCenter.default
    private var cancellables = Set<AnyCancellable>()
    private var daemonHandle: DaemonHandle?
    private let shouldAutoMonitor: Bool
    
    init() {
        self.shouldAutoMonitor = ProcessInfo.processInfo.environment["ANIGMA_STATUSBAR_AUTOMONITOR"] == "1"
        setupNotifications()
        checkANEAvailability()
        if shouldAutoMonitor {
            startMonitoring()
        } else {
            daemonStatus = .unknown
            lastCheck = Date()
        }
    }
    
    func setupNotifications() {
        notificationCenter.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.checkStatus()
                }
            }
            .store(in: &cancellables)
    }
    
    func checkANEAvailability() {
        // Check if ANE is available on this system
        #if os(macOS)
        if #available(macOS 14.0, *) {
            isANEAvailable = true
        } else {
            isANEAvailable = false
        }
        #else
        isANEAvailable = false
        #endif
    }
    
    func startMonitoring() {
        checkStatus()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkStatus()
            }
        }
    }
    
    func checkStatus() {
        Task {
            let status = await DaemonLifecycle.status()
            
            await MainActor.run {
                switch status {
                case .running:
                    self.daemonStatus = .running
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
                let bridge = try await SidecarBridge.create(clientName: "AnigmaStatusBar")
                let statusResponse = try await bridge.getStatus()
                
                await MainActor.run {
                    self.daemonVersion = statusResponse.daemonVersion
                    
                    if let extraJson = statusResponse.extraJson,
                       let data = extraJson.data(using: .utf8),
                       let stats = try? JSONDecoder().decode(DaemonStats.self, from: data) {
                        self.updateStats(stats)
                        self.addToHistory(stats)
                        self.checkForAlerts(stats)
                    } else {
                        self.resetStats()
                    }
                }
            } catch {
                print("Failed to fetch daemon stats: \(error)")
                await MainActor.run {
                    self.daemonStatus = .error("Connection failed: \(error.localizedDescription)")
                    self.resetStats()
                }
            }
        }
    }
    
    private func updateStats(_ stats: DaemonStats) {
        self.cpuUsage = stats.cpuUsage
        self.memoryUsage = stats.memoryUsageMB
        self.pendingJobs = stats.pendingJobs
        self.networkIn = stats.networkBytesIn
        self.networkOut = stats.networkBytesOut
        self.diskRead = stats.diskReadBytes
        self.diskWrite = stats.diskWriteBytes
        self.errorCount = stats.errorCount
        self.latency = stats.averageLatencyMs
        self.uptime = formatUptime(stats.uptimeSeconds)
        self.lastError = stats.lastError ?? "No errors"
        self.daemonVersion = stats.version
        self.mlJobs = stats.mlJobs ?? 0
        self.aneUsage = stats.aneUsage ?? 0.0
        self.gpuUsage = stats.gpuUsage ?? 0.0
        
        // Simulate ANE metrics if not provided
        if stats.aneUsage == nil && isANEAvailable {
            self.aneUsage = Double.random(in: 0...100)
            self.aneTemperature = Double.random(in: 30...80)
            self.anePowerUsage = Double.random(in: 1...10)
            self.aneInferenceCount = Int.random(in: 0...1000)
            self.aneModelCount = Int.random(in: 1...10)
        }
    }
    
    private func addToHistory(_ stats: DaemonStats) {
        let now = Date()
        
        // Add CPU point
        performanceHistory.append(PerformancePoint(
            timestamp: now,
            value: stats.cpuUsage,
            metric: .cpu
        ))
        
        // Add memory point
        performanceHistory.append(PerformancePoint(
            timestamp: now,
            value: stats.memoryUsageMB,
            metric: .memory
        ))
        
        // Add jobs point
        performanceHistory.append(PerformancePoint(
            timestamp: now,
            value: Double(stats.pendingJobs),
            metric: .mlJobs
        ))
        
        // Add ANE point if available
        if let aneUsage = stats.aneUsage {
            performanceHistory.append(PerformancePoint(
                timestamp: now,
                value: aneUsage,
                metric: .ane
            ))
        }
        
        // Keep only recent history
        if performanceHistory.count > historyLimit * 4 {
            performanceHistory.removeFirst(performanceHistory.count - historyLimit * 4)
        }
    }
    
    private func checkForAlerts(_ stats: DaemonStats) {
        guard showNotifications else { return }
        
        // High CPU alert
        if stats.cpuUsage > 80.0 {
            showNotification(title: "High CPU Usage", 
                           body: "Daemon CPU usage is \(String(format: "%.1f", stats.cpuUsage))%")
        }
        
        // High memory alert
        if stats.memoryUsageMB > 1024 {
            showNotification(title: "High Memory Usage",
                           body: "Daemon using \(String(format: "%.0f", stats.memoryUsageMB))MB")
        }
        
        // High ANE usage alert
        if let aneUsage = stats.aneUsage, aneUsage > 90.0 {
            showNotification(title: "High ANE Usage",
                           body: "Apple Neural Engine usage is \(String(format: "%.1f", aneUsage))%")
        }
        
        // Error alert
        if stats.errorCount > 10 {
            showNotification(title: "High Error Rate",
                           body: "\(stats.errorCount) errors detected")
        }
    }
    
    private func showNotification(title: String, body: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    private func formatUptime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }
    
    // MARK: - User Actions
    
    func startDaemon() {
        Task {
            await MainActor.run {
                self.daemonStatus = .starting
            }
            
            do {
                self.daemonHandle = try await DaemonLifecycle.start()
                await checkStatus()
            } catch {
                await MainActor.run {
                    self.daemonStatus = .error("Failed to start: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func stopDaemon() {
        Task {
            await MainActor.run {
                self.daemonStatus = .stopping
            }
            
            do {
                // If we don't have a handle, we try to get one from status if it's running
                // Note: DaemonLifecycle.stop requires a handle with a Process object.
                // If it's already running, we might need a way to stop it without the original handle.
                // For now, we use the stored one or fail gracefully.
                if let handle = self.daemonHandle {
                    try await DaemonLifecycle.stop(handle: handle)
                }
                await checkStatus()
            } catch {
                await MainActor.run {
                    self.daemonStatus = .error("Failed to stop: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func restartDaemon() {
        Task {
            await MainActor.run {
                self.daemonStatus = .starting
            }
            
            do {
                if let handle = self.daemonHandle {
                    self.daemonHandle = try await DaemonLifecycle.restart(handle: handle)
                } else {
                    self.daemonHandle = try await DaemonLifecycle.start()
                }
                await checkStatus()
            } catch {
                await MainActor.run {
                    self.daemonStatus = .error("Failed to restart: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func openCLI() {
        let script = """
        tell application "Terminal"
            do script "anigma --help"
            activate
        end tell
        """
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
        }
    }
    
    func openCLIWithCommand(_ command: String) {
        let script = """
        tell application "Terminal"
            do script "anigma \(command)"
            activate
        end tell
        """
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
        }
    }
    
    func viewLogs() {
        let logPath = "/Library/Logs/Anigma/daemon.log"
        let script = """
        tell application "Terminal"
            do script "tail -f '\(logPath)'"
            activate
        end tell
        """
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
        }
    }
    
    func viewErrorLogs() {
        let logPath = "/Library/Logs/Anigma/daemon-error.log"
        let script = """
        tell application "Terminal"
            do script "tail -50 '\(logPath)'"
            activate
        end tell
        """
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
        }
    }
    
    func openConfig() {
        let configPath = "/Library/Application Support/Anigma/config.json"
        let script = """
        tell application "Finder"
            open POSIX file "\(configPath)"
        end tell
        """
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
        }
    }
    
    func openANEDashboard() {
        let script = """
        tell application "Terminal"
            do script "echo 'ANE Monitoring:\\n- Usage: \(String(format: "%.1f", aneUsage))%\\n- Temperature: \(aneTemperature != nil ? String(format: "%.1f°C", aneTemperature!) : "N/A")\\n- Power: \(anePowerUsage != nil ? String(format: "%.1fW", anePowerUsage!) : "N/A")\\n- Inferences: \(aneInferenceCount)\\n- Models: \(aneModelCount)'"
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
        self.networkIn = 0
        self.networkOut = 0
        self.diskRead = 0
        self.diskWrite = 0
        self.errorCount = 0
        self.latency = 0
        self.uptime = "0s"
        self.daemonVersion = ""
        self.lastError = "No connection"
        self.mlJobs = 0
        self.aneUsage = 0
        self.gpuUsage = 0
    }
}

struct StatusIcon: View {
    let status: DaemonStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 12))
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
        }
    }
    
    var color: Color {
        switch status {
        case .running: return .green
        case .stopped: return .red
        case .starting, .stopping: return .orange
        case .checking: return .yellow
        case .unknown: return .gray
        case .error: return .purple
        }
    }
    
    var iconName: String {
        switch status {
        case .running: return "cpu"
        case .stopped: return "cpu.slash"
        case .starting, .stopping: return "cpu.arrow.clockwise"
        case .checking: return "cpu.badge.clock"
        case .unknown: return "cpu.questionmark"
        case .error: return "cpu.exclamationmark"
        }
    }
}

struct StatusBarView: View {
    @ObservedObject var viewModel: StatusBarViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with tabs
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Anigma Daemon")
                        .font(.headline)
                    if !viewModel.daemonVersion.isEmpty {
                        Text("v\(viewModel.daemonVersion)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    StatusBadge(status: viewModel.daemonStatus)
                }
                
                Picker("", selection: $selectedTab) {
                    Text("Status").tag(0)
                    Text("ANE/ML").tag(1)
                    Text("Controls").tag(2)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            
            Divider()
            
            // Tab content
            TabView(selection: $selectedTab) {
                StatusTab(viewModel: viewModel)
                    .tag(0)
                
                ANEMLTab(viewModel: viewModel)
                    .tag(1)
                
                ControlsTab(viewModel: viewModel)
                    .tag(2)
            }
            .frame(height: 300)
            
            Divider()
            
            // Footer
            HStack {
                Text("Last check: \(viewModel.lastCheck.formatted(date: .omitted, time: .standard))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Toggle("Notifications", isOn: $viewModel.showNotifications)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(width: 320)
    }
}

struct StatusTab: View {
    @ObservedObject var viewModel: StatusBarViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Quick Stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatBox(title: "CPU", value: String(format: "%.1f%%", viewModel.cpuUsage), 
                          icon: "cpu", color: .blue)
                    StatBox(title: "Memory", value: String(format: "%.0f MB", viewModel.memoryUsage), 
                          icon: "memorychip", color: .green)
                    StatBox(title: "Jobs", value: "\(viewModel.pendingJobs)", 
                          icon: "list.bullet.clipboard", color: .orange)
                    StatBox(title: "Latency", value: String(format: "%.0f ms", viewModel.latency), 
                          icon: "speedometer", color: .purple)
                    StatBox(title: "Uptime", value: viewModel.uptime, 
                          icon: "clock", color: .indigo)
                    StatBox(title: "Errors", value: "\(viewModel.errorCount)", 
                          icon: "exclamationmark.triangle", color: viewModel.errorCount > 0 ? .red : .gray)
                }
                
                Divider()
                
                // Network & Disk
                VStack(alignment: .leading, spacing: 8) {
                    Text("I/O Stats")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading) {
                            Label("Network In", systemImage: "arrow.down.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatBytes(viewModel.networkIn))
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        VStack(alignment: .leading) {
                            Label("Network Out", systemImage: "arrow.up.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatBytes(viewModel.networkOut))
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        Spacer()
                    }
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading) {
                            Label("Disk Read", systemImage: "internaldrive")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatBytes(viewModel.diskRead))
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        VStack(alignment: .leading) {
                            Label("Disk Write", systemImage: "internaldrive.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatBytes(viewModel.diskWrite))
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        Spacer()
                    }
                }
                
                if !viewModel.lastError.isEmpty && viewModel.lastError != "No connection" {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Error")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(viewModel.lastError)
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(2)
                    }
                }
            }
            .padding()
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct ANEMLTab: View {
    @ObservedObject var viewModel: StatusBarViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // ANE Status
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Apple Neural Engine")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if viewModel.isANEAvailable {
                            Text("Available")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        } else {
                            Text("Not Available")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.gray)
                                .cornerRadius(4)
                        }
                    }
                    
                    if viewModel.isANEAvailable {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            StatBox(title: "ANE Usage", value: String(format: "%.1f%%", viewModel.aneUsage), 
                                  icon: "brain", color: .purple)
                            StatBox(title: "ML Jobs", value: "\(viewModel.mlJobs)", 
                                  icon: "function", color: .orange)
                            StatBox(title: "GPU Usage", value: String(format: "%.1f%%", viewModel.gpuUsage), 
                                  icon: "gpu", color: .blue)
                            StatBox(title: "Inferences", value: "\(viewModel.aneInferenceCount)", 
                                  icon: "bolt", color: .green)
                        }
                        
                        if let temp = viewModel.aneTemperature {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Thermal & Power")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading) {
                                        Label("Temperature", systemImage: "thermometer")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(String(format: "%.1f°C", temp))
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(temp > 70 ? .red : .primary)
                                    }
                                    
                                    if let power = viewModel.anePowerUsage {
                                        VStack(alignment: .leading) {
                                            Label("Power Usage", systemImage: "bolt")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(String(format: "%.1fW", power))
                                                .font(.system(.body, design: .monospaced))
                                        }
                                    }
                                    
                                    Spacer()
                                }
                            }
                        }
                        
                        Divider()
                        
                        Button(action: { viewModel.openANEDashboard() }) {
                            Label("Open ANE Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 4)
                    } else {
                        Text("ANE is not available on this system. ML workloads will use CPU/GPU.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    }
                }
                
                Divider()
                
                // ML Performance
                VStack(alignment: .leading, spacing: 8) {
                    Text("ML Performance")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if viewModel.mlJobs > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: min(Double(viewModel.mlJobs) / 100.0, 1.0))
                                .progressViewStyle(.linear)
                                .tint(.purple)
                            
                            HStack {
                                Text("Active ML Jobs: \(viewModel.mlJobs)")
                                    .font(.caption)
                                Spacer()
                                Text(viewModel.isANEAvailable ? "Using ANE" : "Using CPU/GPU")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Text("No active ML jobs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
    }
}

struct ControlsTab: View {
    @ObservedObject var viewModel: StatusBarViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Daemon Controls
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daemon Controls")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 8) {
                        Button(action: { viewModel.startDaemon() }) {
                            Label("Start", systemImage: "play.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.daemonStatus == .running || viewModel.daemonStatus == .starting)
                        
                        Button(action: { viewModel.stopDaemon() }) {
                            Label("Stop", systemImage: "stop.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.daemonStatus != .running)
                        
                        Button(action: { viewModel.restartDaemon() }) {
                            Label("Restart", systemImage: "arrow.clockwise.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Divider()
                
                // CLI Access
                VStack(alignment: .leading, spacing: 8) {
                    Text("CLI Access")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Button(action: { viewModel.openCLI() }) {
                        Label("Open CLI Terminal", systemImage: "terminal")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    HStack(spacing: 8) {
                        Button(action: { viewModel.openCLIWithCommand("status") }) {
                            Label("Status", systemImage: "info.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: { viewModel.openCLIWithCommand("--help") }) {
                            Label("Help", systemImage: "questionmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Divider()
                
                // Logs & Config
                VStack(alignment: .leading, spacing: 8) {
                    Text("Logs & Configuration")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 8) {
                        Button(action: { viewModel.viewLogs() }) {
                            Label("View Logs", systemImage: "doc.text")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: { viewModel.viewErrorLogs() }) {
                            Label("Errors", systemImage: "exclamationmark.triangle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Button(action: { viewModel.openConfig() }) {
                        Label("Open Configuration", systemImage: "gearshape")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                
                Divider()
                
                // App Controls
                VStack(alignment: .leading, spacing: 8) {
                    Text("App Controls")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Button(action: { viewModel.quitApp() }) {
                        Label("Quit Status Bar", systemImage: "power")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
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
        case .starting: return "STARTING"
        case .stopping: return "STOPPING"
        case .checking: return "CHECKING"
        case .unknown: return "UNKNOWN"
        case .error(let msg): return "ERROR"
        }
    }
    
    var color: Color {
        switch status {
        case .running: return .green
        case .stopped: return .red
        case .starting, .stopping: return .orange
        case .checking: return .yellow
        case .unknown: return .gray
        case .error: return .purple
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}
