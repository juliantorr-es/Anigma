//
//  LauncherRootView.swift
//  AnigmaAppMac
//
//  Assistant-first launcher shell with secondary utility surfaces.
//

import SwiftUI
import HarmoniaV2Surface
import AnigmaHostMac

struct LauncherRootView: View {
    @StateObject private var appModel: AppModel
    @State private var binaryManager = BinaryManager()
    @State private var selectedUtility: LauncherUtilitySurface = .diagnostics
    @State private var showUtilities = false
    @State private var showModelStatus = false
    @State private var launcherBootstrap = LauncherBootstrapState(
        topology: .canonical,
        runtimeMode: .daemonUnavailable,
        daemonStatus: nil,
        lastError: nil
    )
    @State private var diagnostics = LauncherDiagnosticsState()
    private let daemonCapability: DaemonHostCapability
    
    enum LauncherUtilitySurface: String, CaseIterable {
        case diagnostics = "Diagnostics"
        case binaries = "Binaries"
        case vault = "Vault"
        case pipelines = "Pipelines"
        
        var icon: String {
            switch self {
            case .diagnostics: return "stethoscope"
            case .binaries: return "terminal"
            case .vault: return "shield.checkered"
            case .pipelines: return "arrow.triangle.branch"
            }
        }
    }
    
    init() {
        let daemonCapability = DaemonHostCapability()
        self.daemonCapability = daemonCapability
        let client = AppClientFactory.makeAssistantClient(daemonCapability: daemonCapability)
        _appModel = StateObject(wrappedValue: AppModel(client: client))
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    assistantSurface
                    utilitiesSurface
                }
                .padding(.vertical, 16)
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        .task {
            binaryManager.refreshDiscovery()
            launcherBootstrap = await LauncherRuntimeBootstrapper.bootstrap(
                daemonCapability: daemonCapability
            )
            await appModel.bootstrap()
            await appModel.refreshStatus()
            if appModel.selectedProjectId == nil,
               let firstProjectId = appModel.projects.first?.id {
                await appModel.selectProject(firstProjectId)
            }
            await refreshDiagnostics()
        }
    }
    
    private var headerView: some View {
        let runtimeHealth = binaryManager.runtimeHealth
        let daemonInfo = binaryManager.availableBinaries.first(where: { $0.name == BinaryManager.AnigmaBinary.anigmad.rawValue })
        let daemonReady = binaryManager.isDaemonRunning || daemonInfo?.isAvailable == true

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: "app.dashed")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Anigma")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Assistant-first AI development environment")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Project Context Picker
                Picker("Context", selection: $appModel.selectedProjectId) {
                    Text("No Project").tag(String?.none)
                    ForEach(appModel.projects) { project in
                        Text(project.name).tag(String?.some(project.id))
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)
                .onChange(of: appModel.selectedProjectId) { _, newValue in
                    if let id = newValue {
                        Task { await appModel.selectProject(id) }
                    }
                }
            }

            HStack(spacing: 8) {
                HeaderTrackChip(
                    label: "Model",
                    value: selectedModelLabel,
                    tint: Color.accentColor
                )

                HeaderTrackChip(
                    label: "Readiness",
                    value: assistantReadinessLabel(
                        runtimeHealth: runtimeHealth,
                        daemonReady: daemonReady
                    ),
                    tint: assistantReadinessTint(
                        runtimeHealth: runtimeHealth,
                        daemonReady: daemonReady
                    )
                )

                HeaderTrackChip(
                    label: "Assistant Path",
                    value: assistantPathLabel(
                        runtimeHealth: runtimeHealth,
                        daemonReady: daemonReady
                    ),
                    tint: assistantPathTint(
                        runtimeHealth: runtimeHealth,
                        daemonReady: daemonReady
                    )
                )

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var selectedModelLabel: String {
        if let selectedProjectId = appModel.selectedProjectId,
           let model = appModel.projects.first(where: { $0.id == selectedProjectId })?.embeddingModel {
            return model
        }
        
        return "No selection"
    }

    private func assistantReadinessLabel(
        runtimeHealth: BinaryManager.RuntimeHealth,
        daemonReady: Bool
    ) -> String {
        if appModel.appStatus == nil {
            return "Booting"
        }

        if appModel.appStatus?.killSwitchActive == true {
            return "Paused"
        }

        if runtimeHealth.applicationSupportReady, runtimeHealth.databaseReady, daemonReady {
            return "Ready"
        }

        return "Degraded"
    }

    private func assistantReadinessTint(
        runtimeHealth: BinaryManager.RuntimeHealth,
        daemonReady: Bool
    ) -> Color {
        if appModel.appStatus?.killSwitchActive == true {
            return .orange
        }

        if runtimeHealth.applicationSupportReady, runtimeHealth.databaseReady, daemonReady {
            return .green
        }

        return .secondary
    }

    private func assistantPathLabel(
        runtimeHealth: BinaryManager.RuntimeHealth,
        daemonReady: Bool
    ) -> String {
        if launcherBootstrap.runtimeMode == .daemonUnavailable {
            return launcherBootstrap.runtimeMode.displayName
        }

        if runtimeHealth.applicationSupportReady, daemonReady {
            return "\(launcherBootstrap.runtimeMode.displayName)"
        }

        return "Bootstrap Needed"
    }

    private func assistantPathTint(
        runtimeHealth: BinaryManager.RuntimeHealth,
        daemonReady: Bool
    ) -> Color {
        if launcherBootstrap.runtimeMode == .daemonUnavailable {
            return .orange
        }

        if runtimeHealth.applicationSupportReady, daemonReady {
            return .green
        }

        return .secondary
    }

    private var assistantSurface: some View {
        VStack(alignment: .leading, spacing: 12) {
            AssistantView(model: appModel)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var utilitiesSurface: some View {
        DisclosureGroup(isExpanded: $showUtilities) {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Utility", selection: $selectedUtility) {
                    ForEach(LauncherUtilitySurface.allCases, id: \.self) { surface in
                        Label(surface.rawValue, systemImage: surface.icon)
                            .tag(surface)
                    }
                }
                .pickerStyle(.segmented)

                switch selectedUtility {
                case .diagnostics:
                    diagnosticsSurface
                case .binaries:
                    BinaryLauncherView(binaryManager: binaryManager)
                case .vault:
                    VaultManagementView(model: appModel)
                case .pipelines:
                    PipelineManagerView(model: appModel)
                }
            }
            .padding(.top, 4)
        } label: {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Utilities")
                        .font(.headline)
                    Text("Advanced tools and system diagnostics stay secondary to the assistant.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(selectedUtility.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private var assistantModeSourceLabel: String {
        guard let modeSource = appModel.appStatus?.modeSource else {
            return "Booting"
        }

        switch modeSource {
        case .project: return "Project"
        case .global: return "Global"
        case .defaultMode: return "Default"
        @unknown default: return "Booting"
        }
    }

    private var assistantModeSourceTint: Color {
        appModel.appStatus == nil ? .secondary : .blue
    }

    private func assistantModelHealthLabel(
        runtimeHealth: BinaryManager.RuntimeHealth,
        daemonReady: Bool
    ) -> String {
        if appModel.appStatus == nil {
            return "Loading"
        }

        if launcherBootstrap.runtimeMode == .daemonUnavailable {
            return "Unavailable"
        }

        if runtimeHealth.applicationSupportReady, runtimeHealth.databaseReady, daemonReady {
            return "Healthy"
        }

        return "Degraded"
    }

    private func assistantModelHealthTint(
        runtimeHealth: BinaryManager.RuntimeHealth,
        daemonReady: Bool
    ) -> Color {
        if appModel.appStatus == nil {
            return .secondary
        }

        if launcherBootstrap.runtimeMode == .daemonUnavailable {
            return .orange
        }

        if runtimeHealth.applicationSupportReady, runtimeHealth.databaseReady, daemonReady {
            return .green
        }

        return .red
    }

    private func assistantFallbackLabel(
        runtimeHealth: BinaryManager.RuntimeHealth,
        daemonReady: Bool
    ) -> String {
        if launcherBootstrap.runtimeMode == .daemonUnavailable {
            return "Unavailable"
        }

        return daemonReady && runtimeHealth.applicationSupportReady ? "Daemon" : "Pending"
    }

    private func assistantFallbackTint(
        runtimeHealth: BinaryManager.RuntimeHealth,
        daemonReady: Bool
    ) -> Color {
        if launcherBootstrap.runtimeMode == .daemonUnavailable {
            return .orange
        }

        return daemonReady && runtimeHealth.applicationSupportReady ? .green : .secondary
    }

    private func assistantRuntimeSummary(
        runtimeHealth: BinaryManager.RuntimeHealth,
        daemonReady: Bool
    ) -> String {
        if launcherBootstrap.runtimeMode == .daemonUnavailable {
            return "Daemon unavailable"
        }

        return runtimeHealth.databaseReady && daemonReady ? "Primary path active" : "Starting up"
    }

    private func assistantRuntimeTint(
        runtimeHealth: BinaryManager.RuntimeHealth,
        daemonReady: Bool
    ) -> Color {
        if launcherBootstrap.runtimeMode == .daemonUnavailable {
            return .orange
        }

        return runtimeHealth.databaseReady && daemonReady ? .green : .secondary
    }

    private var diagnosticsSurface: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Runtime diagnostics")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Check daemon bootstrap, control-plane health, and worker reachability from the bundled app.")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if diagnostics.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Button("Refresh") {
                        Task { await refreshDiagnostics() }
                    }
                }

                DiagnosticsSectionCard(title: "Assistant Runtime") {
                    DiagnosticsRow(label: "Assistant path", value: launcherBootstrap.runtimeMode.displayName, tint: launcherBootstrap.runtimeMode == .daemonPrimary ? .green : .orange)
                    DiagnosticsRow(label: "Bootstrap status", value: launcherBootstrap.daemonStatus?.description ?? "Unavailable", tint: launcherBootstrap.daemonStatus == nil ? .secondary : .green)
                    DiagnosticsRow(label: "Selected project", value: appModel.selectedProjectId ?? "None", tint: .secondary)
                    DiagnosticsRow(label: "App status", value: appModel.appStatus.map { "\($0.operatingMode.rawValue) / kill switch \($0.killSwitchActive ? "on" : "off")" } ?? "Unavailable", tint: appModel.appStatus == nil ? .secondary : .green)
                }

                DiagnosticsSectionCard(title: "Bundled Executables") {
                    ForEach(binaryManager.availableBinaries, id: \.name) { binary in
                        DiagnosticsRow(
                            label: binary.name,
                            value: binary.isAvailable ? binary.path : "Missing",
                            tint: binary.isAvailable ? .green : .red
                        )
                    }
                }

                DiagnosticsSectionCard(title: "Control Plane") {
                    DiagnosticsRow(label: "Daemon status", value: diagnostics.daemonStatus, tint: diagnostics.daemonStatusTint)
                    DiagnosticsRow(label: "Harmonia version", value: diagnostics.harmoniaVersion, tint: diagnostics.harmoniaVersionTint)
                    DiagnosticsRow(label: "Harmonia daemon JSON", value: diagnostics.harmoniaDaemonSummary, tint: diagnostics.harmoniaDaemonSummaryTint)
                }

                DiagnosticsSectionCard(title: "ML Worker") {
                    DiagnosticsRow(label: "Bundle reachability", value: diagnostics.mlWorkerStatus, tint: diagnostics.mlWorkerTint)
                    DiagnosticsRow(label: "Probe summary", value: diagnostics.mlWorkerSummary, tint: diagnostics.mlWorkerTint)
                }

                if let bootstrapError = launcherBootstrap.lastError, !bootstrapError.isEmpty {
                    DiagnosticsSectionCard(title: "Bootstrap Error") {
                        Text(bootstrapError)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.orange)
                            .textSelection(.enabled)
                    }
                }

                if let appError = appModel.lastError, !appError.isEmpty {
                    DiagnosticsSectionCard(title: "App Error") {
                        Text(appError)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.orange)
                            .textSelection(.enabled)
                    }
                }

                if let probeLog = diagnostics.probeLog, !probeLog.isEmpty {
                    DiagnosticsSectionCard(title: "Probe Log") {
                        Text(probeLog)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func refreshDiagnostics() async {
        diagnostics.isRefreshing = true
        binaryManager.refreshDiscovery()

        diagnostics.daemonStatus = (await daemonCapability.getDaemonStatus()).description
        diagnostics.daemonStatusTint = diagnostics.daemonStatus == DaemonStatus.stopped.description ? .secondary : .green

        do {
            let version = try await daemonCapability.harmonia.getVersion()
            diagnostics.harmoniaVersion = version
            diagnostics.harmoniaVersionTint = .green
        } catch {
            diagnostics.harmoniaVersion = error.localizedDescription
            diagnostics.harmoniaVersionTint = .orange
        }

        do {
            let status = try await daemonCapability.harmonia.daemonStatus()
            diagnostics.harmoniaDaemonSummary = status.running
                ? "running pid=\(status.pid.map(String.init) ?? "n/a")"
                : "stopped"
            diagnostics.harmoniaDaemonSummaryTint = status.running ? .green : .secondary
        } catch {
            diagnostics.harmoniaDaemonSummary = error.localizedDescription
            diagnostics.harmoniaDaemonSummaryTint = .orange
        }

        do {
            let result = try await binaryManager.runMLWorker(arguments: ["--help"])
            diagnostics.mlWorkerStatus = result.exitCode == 0 ? "Callable" : "Exited \(result.exitCode)"
            diagnostics.mlWorkerTint = result.exitCode == 0 ? .green : .orange
            diagnostics.mlWorkerSummary = firstNonEmptyLine(in: result.output) ?? firstNonEmptyLine(in: result.error) ?? "No output"
            diagnostics.probeLog = compactProbeLog([
                "ml-worker stdout: \(result.output)",
                "ml-worker stderr: \(result.error)"
            ])
        } catch {
            diagnostics.mlWorkerStatus = "Unavailable"
            diagnostics.mlWorkerTint = .orange
            diagnostics.mlWorkerSummary = error.localizedDescription
            diagnostics.probeLog = error.localizedDescription
        }

        diagnostics.isRefreshing = false
    }

    private func firstNonEmptyLine(in text: String) -> String? {
        text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

    private func compactProbeLog(_ entries: [String]) -> String {
        entries
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }
}

private struct LauncherDiagnosticsState {
    var isRefreshing = false
    var daemonStatus = "Unknown"
    var daemonStatusTint = Color.secondary
    var harmoniaVersion = "Unknown"
    var harmoniaVersionTint = Color.secondary
    var harmoniaDaemonSummary = "Unknown"
    var harmoniaDaemonSummaryTint = Color.secondary
    var mlWorkerStatus = "Unknown"
    var mlWorkerTint = Color.secondary
    var mlWorkerSummary = "Not probed"
    var probeLog: String?
}

private struct DiagnosticsSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

private struct DiagnosticsRow: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .fontWeight(.medium)
                .frame(width: 150, alignment: .leading)
            Text(value)
                .foregroundStyle(tint)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(.body, design: .monospaced))
    }
}

// MARK: - Binary Launcher View (Extracted)

private struct BinaryLauncherView: View {
    @Bindable var binaryManager: BinaryManager
    @State private var selectedBinary: BinaryManager.AnigmaBinary = .harmonia
    @State private var arguments: String = ""
    @State private var output: String = ""
    @State private var errorMessage: String?
    @State private var showInventory = false
    @State private var showOutput = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Keep ops quiet until you need them.")
                    .foregroundStyle(.secondary)

                BinarySummaryCard(
                    binaryManager: binaryManager,
                    selectedBinary: selectedBinary,
                    isSelectedAvailable: isSelectedAvailable,
                    isSelectedRunning: isSelectedRunning
                )

                HStack(spacing: 12) {
                    Picker("Binary", selection: $selectedBinary) {
                        ForEach(BinaryManager.AnigmaBinary.allCases, id: \.self) { binary in
                            Text(binary.rawValue).tag(binary)
                        }
                    }
                    .frame(minWidth: 180)

                    TextField("Arguments (space-separated)", text: $arguments)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 260)

                    Button("Launch", action: launchSelected)
                        .disabled(!isSelectedAvailable || isSelectedRunning)

                    Button("Terminate", action: terminateSelected)
                        .disabled(!isSelectedRunning)

                    Button("Clear Output") {
                        output = ""
                        errorMessage = nil
                    }
                    .disabled(output.isEmpty && errorMessage == nil)
                }

                DisclosureGroup("Bundled binaries", isExpanded: $showInventory) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(binaryManager.availableBinaries, id: \.name) { info in
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(info.name)
                                        .font(.headline)
                                    Text(info.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                statusLabel(for: info)
                            }
                        }
                    }
                    .padding(.top, 4)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                }

                if !output.isEmpty {
                    DisclosureGroup("Launch output", isExpanded: $showOutput) {
                        ScrollView {
                            Text(output)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 240)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    private var isSelectedAvailable: Bool {
        binaryManager.availableBinaries.first(where: { $0.name == selectedBinary.rawValue })?.isAvailable ?? false
    }

    private var isSelectedRunning: Bool {
        binaryManager.isRunning(selectedBinary)
    }

    private func launchSelected() {
        errorMessage = nil
        output = ""

        let args = arguments.split(separator: " ").map(String.init)
        do {
            try binaryManager.launch(selectedBinary, arguments: args) { chunk in
                output.append(chunk)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func terminateSelected() {
        binaryManager.terminate(selectedBinary)
    }

    @ViewBuilder
    private func statusLabel(for info: BinaryManager.BinaryInfo) -> some View {
        let running = isRunning(info)
        let label = running ? "Running" : (info.isAvailable ? "Ready" : "Missing")
        let color: Color = running ? .green : (info.isAvailable ? .secondary : .red)
        Text(label)
            .font(.caption)
            .foregroundStyle(color)
    }

    private func isRunning(_ info: BinaryManager.BinaryInfo) -> Bool {
        guard let binary = BinaryManager.AnigmaBinary(rawValue: info.name) else {
            return false
        }
        return binaryManager.isRunning(binary)
    }
}

private struct HeaderTrackChip: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct BinarySummaryCard: View {
    @Bindable var binaryManager: BinaryManager
    let selectedBinary: BinaryManager.AnigmaBinary
    let isSelectedAvailable: Bool
    let isSelectedRunning: Bool

    var body: some View {
        let runtimeHealth = binaryManager.runtimeHealth
        HStack(alignment: .top, spacing: 12) {
            SummaryChip(
                label: "Selected",
                value: selectedBinary.rawValue,
                tint: .accentColor
            )
            SummaryChip(
                label: "State",
                value: isSelectedRunning ? "Running" : (isSelectedAvailable ? "Ready" : "Missing"),
                tint: isSelectedRunning ? .green : (isSelectedAvailable ? .secondary : .red)
            )
            SummaryChip(
                label: "Bundle",
                value: "\(runtimeHealth.bundledBinaryCount)/\(runtimeHealth.totalBinaryCount)",
                tint: .blue
            )
            Spacer()
        }
    }
}

private struct SummaryChip: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct StatusDetailRow: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
