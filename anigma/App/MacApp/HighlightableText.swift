import SwiftUI

struct HighlightableText: View {
    let text: String
    let highlight: String

    var body: some View {
        if highlight.isEmpty || !text.localizedCaseInsensitiveContains(highlight) {
            Text(text)
        } else {
            Text(text)
                .background(Color.yellow.opacity(0.3))
        }
    }
}
