//
//  ObservatoriumDashboardView.swift
//  AnigmaAppMac
//
//  Dashboard view for Observatorium monitoring system.
//

import SwiftUI
import ObservatoriumModule

// MARK: - Observatorium Dashboard View

struct ObservatoriumDashboardView: View {
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Observatorium Dashboard")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Real-time monitoring and alerting system")
                .font(.title3)
                .foregroundStyle(.secondary)
            
            // Status Cards
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 20) {
                StatusCard(
                    title: "System Health",
                    value: "Operational",
                    color: .green,
                    icon: "heart.fill"
                )
                
                StatusCard(
                    title: "Active Alerts",
                    value: "0",
                    color: .blue,
                    icon: "bell.fill"
                )
                
                StatusCard(
                    title: "Uptime",
                    value: "99.9%",
                    color: .green,
                    icon: "clock.fill"
                )
                
                StatusCard(
                    title: "Last Check",
                    value: "2m ago",
                    color: .orange,
                    icon: "arrow.clockwise"
                )
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Refresh Button
            Button(action: refreshData) {
                HStack {
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Refresh")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
    }
    
    private func refreshData() {
        isRefreshing = true
        
        Task {
            try? await Task.sleep(for: .seconds(1))
            await MainActor.run {
                isRefreshing = false
            }
        }
    }
}

// MARK: - Status Card

struct StatusCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.primary.opacity(0.1))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    ObservatoriumDashboardView()
        .frame(width: 800, height: 600)
}
