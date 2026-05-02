//
//  AdminPoliciesView.swift
//  AnigmaAppMac
//
//  Admin policies management interface.
//

import SwiftUI

struct AdminPoliciesView: View {
    @Environment(AppStore.self) private var store
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Admin Policies")
                .font(Bauhaus.Font.header)
                .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
                    Text("Policy management interface")
                        .font(Bauhaus.Font.body)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                        .padding()
                }
            }
        }
        .navigationTitle("Policies")
    }
}

/*#Preview {
    AdminPoliciesView()
        .environment(AppStore.preview)
}*/