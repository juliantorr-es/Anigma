//
//  DeveloperMetricsView.swift
//  AnigmaAppMac
//
//  Developer metrics and performance monitoring.
//

import SwiftUI

struct DeveloperMetricsView: View {
    @Environment(AppStore.self) private var store
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Performance Metrics")
                .font(Bauhaus.Font.header)
                .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
                    Text("Performance metrics and monitoring")
                        .font(Bauhaus.Font.body)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                        .padding()
                }
            }
        }
        .navigationTitle("Metrics")
    }
}

/*#Preview {
    DeveloperMetricsView()
        .environment(AppStore.preview)
}*/