//
//  AITransparencyDashboard.swift
//  AnigmaAppMac
//
//  Comprehensive AI transparency dashboard showing all AI operations,
// receipts, and verification status in real-time.
//

import SwiftUI
import Charts
import Foundation

// MARK: - AI Transparency Dashboard

struct AITransparencyDashboard: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AITransparencyViewModel()
    @State private var selectedFilter: FilterOption = .all
    @State private var searchText = ""
    @State private var selectedTimeRange: TimeRange = .last24Hours
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with statistics
                headerView
                
                // Filters and search
                filtersView
                
                // Main content
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.operations.isEmpty {
                    emptyStateView
                } else {
                    mainContentView
                }
            }
            .navigationTitle("AI Transparency")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                viewModel.loadOperations()
            }
            .refreshable {
                viewModel.refreshOperations()
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Operations Monitor")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("Real-time transparency for all AI operations")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    StatCard(
                        title: "Total Operations",
                        value: "\(viewModel.stats.totalOperations)",
                        color: .blue
                    )
                    
                    StatCard(
                        title: "Success Rate",
                        value: String(format: "%.1f%%", viewModel.stats.successRate * 100),
                        color: viewModel.stats.successRate > 0.8 ? .green : .orange
                    )
                    
                    StatCard(
                        title: "Avg Time",
                        value: String(format: "%.1fs", viewModel.stats.averageInferenceTimeMs / 1000),
                        color: .purple
                    )
                }
            }
            
            // Token usage chart
            if viewModel.stats.totalTokens > 0 {
                TokenUsageChart(
                    inputTokens: viewModel.stats.totalInputTokens,
                    outputTokens: viewModel.stats.totalOutputTokens
                )
                .frame(height: 100)
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Filters View
    
    private var filtersView: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search operations...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // Filter buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FilterOption.allCases, id: \.self) { filter in
                        FilterChip(
                            title: filter.displayName,
                            isSelected: selectedFilter == filter
                        ) {
                            selectedFilter = filter
                            viewModel.applyFilter(filter, searchText: searchText)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Time range selector
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .onChange(of: selectedTimeRange) { _ in
                viewModel.setTimeRange(selectedTimeRange)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Main Content View
    
    private var mainContentView: some View {
        TabView {
            // Operations List
            operationsListTab
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Operations")
                }
            
            // Statistics Tab
            statisticsTab
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Statistics")
                }
            
            // Verification Tab
            verificationTab
                .tabItem {
                    Image(systemName: "checkmark.shield")
                    Text("Verification")
                }
        }
    }
    
    // MARK: - Operations List Tab
    
    private var operationsListTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredOperations) { operation in
                    AIOperationRow(operation: operation) {
                        viewModel.selectedOperation = operation
                        viewModel.showingDetail = true
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $viewModel.showingDetail) {
            if let operation = viewModel.selectedOperation {
                AIOperationDetailView(operation: operation)
            }
        }
    }
    
    // MARK: - Statistics Tab
    
    private var statisticsTab: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Provider distribution
                ProviderDistributionChart(stats: viewModel.stats)
                
                // Task type distribution
                TaskTypeDistributionChart(stats: viewModel.stats)
                
                // Model usage
                ModelUsageView(stats: viewModel.stats)
                
                // Performance metrics
                PerformanceMetricsView(stats: viewModel.stats)
            }
            .padding()
        }
    }
    
    // MARK: - Verification Tab
    
    private var verificationTab: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Chain integrity status
                ChainIntegrityView()
                
                // Recent verifications
                RecentVerificationsView()
                
                // Verification tools
                VerificationToolsView()
            }
            .padding()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading AI operations...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No AI Operations Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("AI operations will appear here as they are performed")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray6))
                .foregroundStyle(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TokenUsageChart: View {
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
    
    init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = inputTokens + outputTokens
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Token Usage")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("\(totalTokens) total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Label("\(inputTokens)", systemImage: "arrow.down.circle.fill")
                        .foregroundStyle(.blue)
                    Label("\(outputTokens)", systemImage: "arrow.up.circle.fill")
                        .foregroundStyle(.green)
                }
                .font(.caption)
            }
            
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: CGFloat(inputTokens) / CGFloat(totalTokens) * 200)
                Rectangle()
                    .fill(Color.green)
                    .frame(width: CGFloat(outputTokens) / CGFloat(totalTokens) * 200)
            }
            .frame(height: 8)
            .cornerRadius(4)
        }
    }
}

// MARK: - Enums

enum FilterOption: CaseIterable {
    case all
    case successful
    case failed
    case mlxCalls
    case toolExecutions
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .successful: return "Successful"
        case .failed: return "Failed"
        case .mlxCalls: return "MLX Calls"
        case .toolExecutions: return "Tool Executions"
        }
    }
}

enum TimeRange: CaseIterable {
    case lastHour
    case last24Hours
    case last7Days
    case last30Days
    
    var displayName: String {
        switch self {
        case .lastHour: return "1 Hour"
        case .last24Hours: return "24 Hours"
        case .last7Days: return "7 Days"
        case .last30Days: return "30 Days"
        }
    }
    
    var timeInterval: TimeInterval {
        switch self {
        case .lastHour: return 3600
        case .last24Hours: return 86400
        case .last7Days: return 604800
        case .last30Days: return 2592000
        }
    }
}

#Preview {
    AITransparencyDashboard()
}