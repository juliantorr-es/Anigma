//
//  DenialBannerView.swift
//  AnigmaAppMac
//
//  Displays structured governance violations.
//

import SwiftUI
import GovernanceCore

struct DenialBannerView: View {
    let violation: GovernanceViolation?
    @State private var showingDetails = false
    
    var body: some View {
        if let v = violation {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading) {
                        Text("Governance Denial")
                            .font(.headline)
                        
                        if let firstCheck = v.failedChecks.first {
                            Text("Blocked by: \(firstCheck.checkId)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button(showingDetails ? "Hide Details" : "Show Details") {
                        showingDetails.toggle()
                    }
                    .buttonStyle(.link)
                }
                
                if showingDetails {
                    Divider()
                    
                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12) {
                        if let firstCheck = v.failedChecks.first {
                            GridRow {
                                Text("Check:").fontWeight(.medium)
                                Text(firstCheck.checkId)
                            }
                            GridRow {
                                Text("Reason:").fontWeight(.medium)
                                Text(firstCheck.message)
                            }
                        }
                        if let source = v.evaluatedModeSource {
                            GridRow {
                                Text("Mode Source:").fontWeight(.medium)
                                Text(source)
                            }
                        }
                        GridRow {
                            Text("Principal:").fontWeight(.medium)
                            Text(v.principal)
                        }
                        if let projectId = v.projectId {
                            GridRow {
                                Text("Project:").fontWeight(.medium)
                                Text(projectId)
                            }
                        }
                        GridRow {
                            Text("Violation ID:").fontWeight(.medium)
                            HStack {
                                Text(v.id.uuidString)
                                    .font(.caption.monospaced())
                                Button("Copy") {
                                    #if os(macOS)
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(v.id.uuidString, forType: .string)
                                    #endif
                                }
                                .buttonStyle(.link)
                            }
                        }
                    }
                    .font(.caption)
                }
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
        }
    }
}
