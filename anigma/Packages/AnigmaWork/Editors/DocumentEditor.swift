import SwiftUI

public struct DocumentEditor: View {
    @Binding var document: DocumentIR

    public init(document: Binding<DocumentIR>) {
        self._document = document
    }

    public var body: some View {
        VStack {
            TextField("Title", text: $document.title)
                .font(.title)
                .padding()

            List {
                ForEach(document.blocks) { block in
                    switch block {
                    case .paragraph(_, let text, _):
                        Text(text)
                    case .heading(_, let text, let level):
                        Text(text).font(level == 1 ? .title : .headline)
                    case .list(_, let items, let ordered):
                        VStack(alignment: .leading) {
                            ForEach(items, id: \.self) { item in
                                Text(ordered ? "1. \(item)" : "• \(item)")
                            }
                        }
                    case .table(_, let rows):
                        Text("Table (\(rows.count) rows)")
                    case .image(_, _, let caption):
                        VStack {
                            Image(systemName: "photo")
                            if let caption = caption {
                                Text(caption).font(.caption)
                            }
                        }
                    }
                }
            }
        }
    }
}
