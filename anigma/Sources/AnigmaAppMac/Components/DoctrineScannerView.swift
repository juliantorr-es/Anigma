//
//  DoctrineScannerView.swift
//  AnigmaAppMac
//
//  Scan code for doctrine violations.
//

import SwiftUI
import AnigmaHostMac

// NonPersistent
struct DoctrineScannerView: View, Sendable {
    @Environment(AppStore.self) private var store
    @State private var scanPath: String = ""
    @State private var selectedDomains: Set<String> = []
    @State private var isScanning = false
    @State private var errorMessage: String?
    @State private var showPathPicker = false

    private let availableDomains = [
        "cs", "stats", "law", "swe", "a11y",
        "privacy", "security", "architecture", "quality"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
            headerView

            pathSelectorView

            domainFilterView

            if let results = store.doctrineScanResults {
                resultsView(results)
            } else if !scanPath.isEmpty {
                emptyStateView
            }

            if let error = errorMessage {
                errorView(error)
            }
        }
        .padding(Bauhaus.Grid.x3)
        .background(Bauhaus.Color.surface)
        .bauhausSection()
        .fileImporter(
            isPresented: $showPathPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    scanPath = url.path
                }
            case .failure(let error):
                errorMessage = "Failed to select path: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.title2)
                .foregroundStyle(Bauhaus.Color.accent)

            Text("Doctrine Scanner")
                .font(Bauhaus.Font.header)

            Spacer()
        }
    }

    private var pathSelectorView: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            Text("Scan Path")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            HStack(spacing: Bauhaus.Grid.x2) {
                TextField("Enter path to scan", text: $scanPath)
                    .accessibilityLabel("Scan directory path")
                    .textFieldStyle(.roundedBorder)
                    .font(Bauhaus.Font.mono)

                Button(action: { showPathPicker = true }) {
                    Image(systemName: "folder")
                }
                .accessibilityLabel("Select directory")
                .buttonStyle(.bordered)

                Button(action: { Task { await runScan() } }) {
                    Label("Scan", systemImage: "magnifyingglass")
                }
                .accessibilityLabel("Execute scan")
                .buttonStyle(.borderedProminent)
                .disabled(scanPath.isEmpty || isScanning)

                if isScanning {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if !scanPath.isEmpty {
                Text(scanPath)
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var domainFilterView: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            Text("Filter by Domain (optional)")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Bauhaus.Grid.x2) {
                ForEach(availableDomains, id: \.self) { domain in
                    Toggle(isOn: Binding(
                        get: { selectedDomains.contains(domain) },
                        set: { isSelected in
                            if isSelected {
                                selectedDomains.insert(domain)
                            } else {
                                selectedDomains.remove(domain)
                            }
                        }
                    )) {
                        Text(domain)
                            .font(Bauhaus.Font.caption)
                    }
                    .accessibilityLabel("Filter \(domain)")
                    .toggleStyle(.checkbox)
                }
            }

            if selectedDomains.isEmpty {
                Text("All domains will be scanned")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textTertiary)
            } else {
                Text("\(selectedDomains.count) domain(s) selected")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.accent)
            }
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.background)
        .cornerRadius(Bauhaus.Grid.unit)
    }

    private func resultsView(_ results: DoctrineClient.ScanResponse) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x3) {
            summaryView(results)

            if !results.violations.isEmpty {
                Divider()
                violationsListView(results.violations)
            }
        }
    }

    private func summaryView(_ results: DoctrineClient.ScanResponse) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            HStack {
                Text("Scan Results")
                    .font(Bauhaus.Font.subHeader)

                Spacer()

                Text("Scanned in \(String(format: "%.2f", results.scanDuration))s")
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)
            }

            HStack(spacing: Bauhaus.Grid.x3) {
                statCard(
                    label: "Total",
                    value: "\(results.totalViolations)",
                    color: results.totalViolations > 0 ? Bauhaus.Color.warning : Bauhaus.Color.success
                )

                statCard(
                    label: "Critical",
                    value: "\(results.criticalCount)",
                    color: results.criticalCount > 0 ? Bauhaus.Color.error : Bauhaus.Color.textSecondary
                )

                statCard(
                    label: "Error",
                    value: "\(results.errorCount)",
                    color: results.errorCount > 0 ? Bauhaus.Color.error : Bauhaus.Color.textSecondary
                )

                statCard(
                    label: "Warning",
                    value: "\(results.warningCount)",
                    color: results.warningCount > 0 ? Bauhaus.Color.warning : Bauhaus.Color.textSecondary
                )
            }
        }
    }

    private func statCard(label: String, value: String, color: Color) -> some View {
        VStack(spacing: Bauhaus.Grid.unit) {
            Text(value)
                .font(Bauhaus.Font.header)
                .foregroundStyle(color)

            Text(label)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.background)
        .cornerRadius(Bauhaus.Grid.unit)
    }

    private func violationsListView(_ violations: [DoctrineClient.ScanResponse.Violation]) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            Text("Violations (\(violations.count))")
                .font(Bauhaus.Font.subHeader)

            ScrollView {
                LazyVStack(spacing: Bauhaus.Grid.x2) {
                    ForEach(violations) { violation in
                        violationRow(violation)
                    }
                }
            }
            .frame(maxHeight: 400)
        }
    }

    private func violationRow(_ violation: DoctrineClient.ScanResponse.Violation) -> some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
            HStack {
                Image(systemName: severityIcon(violation.severity))
                    .foregroundStyle(severityColor(violation.severity)) // OK: Bauhaus
                    .frame(width: Bauhaus.Grid.x3)

                Text(violation.severity.uppercased())
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(severityColor(violation.severity)) // OK: Bauhaus

                Text("•")
                    .foregroundStyle(Bauhaus.Color.textTertiary)

                Text(violation.domain)
                    .font(Bauhaus.Font.caption)
                    .foregroundStyle(Bauhaus.Color.textSecondary)

                Spacer()

                Text(violation.ruleId)
                    .font(Bauhaus.Font.mono)
                    .foregroundStyle(Bauhaus.Color.textTertiary)
                    .lineLimit(1)
            }

            Text(violation.message)
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textPrimary)

            if let filePath = violation.filePath {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                        .frame(width: Bauhaus.Grid.x2)

                    Text(filePath)
                        .font(Bauhaus.Font.mono)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if let line = violation.lineNumber {
                        Text(":\(line)")
                            .font(Bauhaus.Font.mono)
                            .foregroundStyle(Bauhaus.Color.textSecondary)

                        if let col = violation.columnNumber {
                            Text(":\(col)")
                                .font(Bauhaus.Font.mono)
                                .foregroundStyle(Bauhaus.Color.textSecondary)
                        }
                    }
                }
            }

            if let context = violation.context, !context.isEmpty {
                Text(context)
                    .font(Bauhaus.Font.mono)
                    .foregroundStyle(Bauhaus.Color.textTertiary)
                    .padding(Bauhaus.Grid.unit)
                    .background(Bauhaus.Color.background)
                    .cornerRadius(Bauhaus.Grid.unit / 2)
            }
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.surface)
        .cornerRadius(Bauhaus.Grid.unit)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.unit)
                .stroke(severityColor(violation.severity).opacity(0.3), lineWidth: 1) // OK: Bauhaus
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: Bauhaus.Grid.x2) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundStyle(Bauhaus.Color.success)

            Text("No violations found")
                .font(Bauhaus.Font.body)
                .foregroundStyle(Bauhaus.Color.textSecondary)

            Text("The scanned code passes all doctrine checks")
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(Bauhaus.Grid.x4)
    }

    private func errorView(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Bauhaus.Grid.x2) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Bauhaus.Color.error)

            Text(message)
                .font(Bauhaus.Font.caption)
                .foregroundStyle(Bauhaus.Color.error)
        }
        .padding(Bauhaus.Grid.x2)
        .background(Bauhaus.Color.error.opacity(0.1))
        .cornerRadius(Bauhaus.Grid.unit)
    }

    // MARK: - Actions

    private func runScan() async {
        guard !scanPath.isEmpty else { return }

        isScanning = true
        errorMessage = nil

        let domains = selectedDomains.isEmpty ? nil : Array(selectedDomains)
        await store.scanDoctrine(path: scanPath, domains: domains)

        if store.doctrineScanResults == nil {
            errorMessage = "Scan failed. Check that the path exists and doctrine is installed."
        }

        isScanning = false
    }

    // MARK: - Helpers

    private func severityIcon(_ severity: String) -> String {
        switch severity.lowercased() {
        case "critical": return "exclamationmark.octagon.fill"
        case "error": return "xmark.circle.fill"
        case "warning": return "exclamationmark.triangle.fill"
        case "info": return "info.circle.fill"
        default: return "circle.fill"
        }
    }

    private func severityColor(_ severity: String) -> Color { // OK: Bauhaus
        switch severity.lowercased() {
        case "critical": return Bauhaus.Color.error
        case "error": return Bauhaus.Color.error
        case "warning": return Bauhaus.Color.warning
        case "info": return Bauhaus.Color.running
        default: return Bauhaus.Color.textSecondary
        }
    }
}
