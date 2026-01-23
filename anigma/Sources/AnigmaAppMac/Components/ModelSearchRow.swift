//
//  ModelSearchRow.swift
//  AnigmaAppMac
//
//  Row component for displaying model search results.
//

import SwiftUI
import AnigmaCore
import AnigmaCLI

struct ModelSearchRow: View {
    let model: HFSearchResult
    let benchmarkResult: SystemBenchmark.Result?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.id)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                if let tier = benchmarkResult?.tier {
                    TierIndicator(tier: tier, model: model)
                }
            }

            HStack(spacing: 12) {
                if let size = model.size {
                    HStack(spacing: 4) {
                        Image(systemName: "externaldrive")
                        Text(model.formattedSize)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                if let downloads = model.downloads {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                        Text("\(downloads.formatted())")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                if let task = model.taskType {
                    HStack(spacing: 4) {
                        Image(systemName: task.icon)
                        Text(task.displayName)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }

            if !model.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(model.tags.prefix(5), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Bauhaus.Color.surface)
                                .cornerRadius(2)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct TierIndicator: View {
    let tier: SystemBenchmark.Tier
    let model: HFSearchResult

    var body: some View {
        Group {
            if isCompatible {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            } else if isLargeForTier {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
        .help(compatibilityHelp)
    }

    private var isCompatible: Bool {
        guard let size = model.size else { return true }
        let sizeGB = Double(size) / (1024 * 1024 * 1024)
        return sizeGB <= Double(tier.maxModelSizeGB) * 0.7
    }

    private var isLargeForTier: Bool {
        guard let size = model.size else { return false }
        let sizeGB = Double(size) / (1024 * 1024 * 1024)
        return sizeGB > Double(tier.maxModelSizeGB) * 0.7 && sizeGB <= Double(tier.maxModelSizeGB)
    }

    private var compatibilityHelp: String {
        guard let size = model.size else { return "Unknown size" }
        let sizeGB = Double(size) / (1024 * 1024 * 1024)
        if isCompatible {
            return "Good fit for \(tier.displayName) tier (\(String(format: "%.1f", sizeGB))GB)"
        } else if isLargeForTier {
            return "May be slow on \(tier.displayName) tier (\(String(format: "%.1f", sizeGB))GB)"
        }
        return "Too large for \(tier.displayName) tier (\(String(format: "%.1f", sizeGB))GB, max \(tier.maxModelSizeGB)GB)"
    }
}

struct ModelHeaderCard: View {
    let model: HFSearchResult
    let benchmarkResult: SystemBenchmark.Result?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.id)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("by \(model.author)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let tier = benchmarkResult?.tier {
                    VStack {
                        Text(tier.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Bauhaus.Color.accent.opacity(0.15))
                            .foregroundStyle(Bauhaus.Color.accent)
                            .cornerRadius(4)
                    }
                }
            }

            HStack(spacing: 16) {
                if let size = model.size {
                    Label(model.formattedSize, systemImage: "externaldrive")
                }

                if let downloads = model.downloads {
                    Label("\(downloads.formatted()) downloads", systemImage: "arrow.down.circle")
                }

                if let likes = model.likes {
                    Label("\(likes.formatted()) likes", systemImage: "heart")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Bauhaus.Color.surface)
        .cornerRadius(8)
    }
}

struct FileSelectionSection: View {
    let files: [HFFileInfo]
    @Binding var selected: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Files")
                    .font(.headline)
                Spacer()
                Text("\(selected.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(files.filter { $0.isFile }, id: \.id) { file in
                    FileSelectionRow(
                        file: file,
                        isSelected: selected.contains(file.path)
                    )
                    .onTapGesture {
                        if selected.contains(file.path) {
                            selected.remove(file.path)
                        } else {
                            selected.insert(file.path)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Bauhaus.Color.surface)
        .cornerRadius(8)
    }
}

struct FileSelectionRow: View {
    let file: HFFileInfo
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "doc.text")
                Text(file.path.split(separator: "/").last.map(String.init) ?? file.path)
                    .lineLimit(1)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Bauhaus.Color.accent)
                }
            }
            .font(.caption)

            Text(file.formattedSize)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(isSelected ? Bauhaus.Color.accent.opacity(0.1) : Bauhaus.Color.surface)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Bauhaus.Color.accent : Bauhaus.Color.border, lineWidth: 1)
        )
    }
}

struct SizeWarningCard: View {
    let model: HFSearchResult
    let tier: SystemBenchmark.Tier?

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading) {
                Text("Large Model")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let tier = tier {
                    Text("This model may be slow on your \(tier.displayName) system")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}
