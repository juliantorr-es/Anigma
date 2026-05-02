//
//  AdminAuditView.swift
//  AnigmaAppMac
//
//  Admin audit log interface.
//

import SwiftUI

struct AdminAuditView: View {
    @Environment(AppStore.self) private var store
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Audit Log")
                .font(Bauhaus.Font.header)
                .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
                    Text("Audit log interface")
                        .font(Bauhaus.Font.body)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                        .padding()
                }
            }
        }
        .navigationTitle("Audit")
    }
}

/*#Preview {
    AdminAuditView()
        .environment(AppStore.preview)
}*/