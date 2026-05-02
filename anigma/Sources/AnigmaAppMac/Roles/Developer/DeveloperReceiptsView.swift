//
//  DeveloperReceiptsView.swift
//  AnigmaAppMac
//
//  Developer receipts and execution traces.
//

import SwiftUI

struct DeveloperReceiptsView: View {
    @Environment(AppStore.self) private var store
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Execution Receipts")
                .font(Bauhaus.Font.header)
                .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
                    Text("Execution receipts and traces")
                        .font(Bauhaus.Font.body)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                        .padding()
                }
            }
        }
        .navigationTitle("Receipts")
    }
}

/*#Preview {
    DeveloperReceiptsView()
        .environment(AppStore.preview)
}*/