import SwiftUI
import ExportCore

public struct ProfileStudioView: View {
    @State private var profiles: [ExportProfileSpec] = []
    @State private var selectedProfileId: String?

    public init() {}

    public var body: some View {
        HSplitView {
            // Profile List
            List(profiles) { profile in
                Text(profile.name)
                    .tag(profile.id)
                    .onTapGesture {
                        selectedProfileId = profile.id
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Selects profile \(profile.name)")
            }
            .frame(minWidth: 200)
            .accessibilityLabel("Export Profiles")

            // Editor
            if let profileId = selectedProfileId, let profile = profiles.first(where: { $0.id == profileId }) {
                ProfileEditor(profile: profile)
                    .accessibilityLabel("Profile Editor for \(profile.name)")
            } else {
                Text("Select a profile")
                    .accessibilityHidden(true)
            }

            // Preview
            PreviewView()
                .frame(minWidth: 300)
        }
    }
}

struct ProfileEditor: View {
    let profile: ExportProfileSpec

    var body: some View {
        Form {
            Text(profile.name).font(.headline)
            Text(profile.description).font(.subheadline)

            Section("Intent") {
                Text(profile.intent.rawValue)
            }

            Section("Pipeline") {
                ForEach(profile.pipelineSteps, id: \.self) { step in
                    Text(step)
                }
            }
        }
        .padding()
    }
}
