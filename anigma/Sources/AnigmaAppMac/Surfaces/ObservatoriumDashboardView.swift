import SwiftUI

struct ObservatoriumDashboardView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppState.self) private var appState
    @State private var isRefreshing = false

    private var recentNetworkActivity: [NetworkActivityEntry] {
        store.networkActivityLog
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Bauhaus.Grid.x4) {
                header

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: Bauhaus.Grid.x3)], spacing: Bauhaus.Grid.x3) {
                    ObservatoriumStatusCard(
                        title: "Daemon",
                        value: store.isDaemonConnected ? "Connected" : "Disconnected",
                        detail: store.daemonStatus,
                        icon: "server.rack",
                        accent: store.isDaemonConnected ? Bauhaus.Color.trusted : Bauhaus.Color.error
                    )

                    ObservatoriumStatusCard(
                        title: "Jobs",
                        value: "\(appState.runningJobsCount) running",
                        detail: "\(appState.blockedJobsCount) blocked",
                        icon: "play.circle.fill",
                        accent: appState.runningJobsCount > 0 ? Bauhaus.Color.accent : Bauhaus.Color.textSecondary
                    )

                    ObservatoriumStatusCard(
                        title: "Contexts",
                        value: "\(store.contexts.count) active",
                        detail: "\(store.scopes.count) scopes",
                        icon: "circle.hexagongrid.fill",
                        accent: Bauhaus.Color.accent
                    )

                    ObservatoriumStatusCard(
                        title: "Network",
                        value: "\(store.networkActivityLog.count) events",
                        detail: recentNetworkActivity.first.map { $0.domain } ?? "No recent traffic",
                        icon: "network",
                        accent: store.networkActivityLog.last?.isAllowed == false ? Bauhaus.Color.warning : Bauhaus.Color.textSecondary
                    )
                }

                ObservatoriumActivitySection(entries: recentNetworkActivity)
            }
            .padding(Bauhaus.Grid.x4)
        }
        .navigationTitle("Observatorium")
        .background(Bauhaus.Color.background)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Observatorium")
                    .font(Bauhaus.Font.displayS)
                Text("System telemetry, connectivity, and governance watch")
                    .font(Bauhaus.Font.body)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            }

            Spacer()

            Button {
                isRefreshing = true
                Task {
                    await store.refreshDaemonStatus()
                    await store.refreshDaemonInfo()
                    isRefreshing = false
                }
            } label: {
                HStack(spacing: 6) {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Refresh")
                        .font(Bauhaus.Font.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Bauhaus.Color.surface)
                .cornerRadius(Bauhaus.Grid.cornerRadiusSmall)
                .overlay(
                    RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadiusSmall)
                        .stroke(Bauhaus.Color.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isRefreshing)
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.surface)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                .stroke(Bauhaus.Color.border, lineWidth: 0.5)
        )
        .cornerRadius(Bauhaus.Grid.cornerRadius)
    }
}

private struct ObservatoriumStatusCard: View {
    let title: String
    let value: String
    let detail: String
    let icon: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(accent)
                Spacer()
            }

            Text(value)
                .font(Bauhaus.Font.header)
                .foregroundStyle(Bauhaus.Color.textPrimary)

            Text(detail)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            Text(title.uppercased())
                .font(Bauhaus.Font.caption)
                .fontWeight(.bold)
                .foregroundStyle(Bauhaus.Color.textTertiary)
        }
        .bauhausCard()
    }
}

private struct ObservatoriumActivitySection: View {
    let entries: [NetworkActivityEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            Text("Recent Network Activity")
                .font(Bauhaus.Font.caption)
                .fontWeight(.bold)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            if entries.isEmpty {
                ContentUnavailableView {
                    Label("No Activity", systemImage: "network")
                } description: {
                    Text("Network activity will appear as services sync.")
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: Bauhaus.Grid.unit) {
                    ForEach(entries) { entry in
                        ObservatoriumActivityRow(entry: entry)
                    }
                }
            }
        }
        .bauhausCard()
    }
}

private struct ObservatoriumActivityRow: View {
    let entry: NetworkActivityEntry

    var body: some View {
        HStack(spacing: Bauhaus.Grid.x2) {
            Image(systemName: entry.isAllowed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(entry.isAllowed ? Bauhaus.Color.trusted : Bauhaus.Color.warning)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.domain)
                    .font(Bauhaus.Font.body)
                if let reason = entry.reason {
                    Text(reason)
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                }
            }

            Spacer()

            Text(entry.timestamp.formatted(.relative(presentation: .numeric)))
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textTertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Bauhaus.Color.surface)
        .cornerRadius(Bauhaus.Grid.cornerRadiusSmall)
    }
}

#Preview {
    ObservatoriumDashboardView()
        .environment(AppStore())
        .environment(AppState.shared)
        .frame(width: 900, height: 700)
}
