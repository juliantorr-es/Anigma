import SwiftUI

public struct WorkbenchView: View {
    @State var project: WorkbenchProject
    @State private var selectedDocumentId: UUID?
    @State private var selectedSheetId: UUID?
    @State private var selectedDeckId: UUID?

    public init(project: WorkbenchProject) {
        self._project = State(initialValue: project)
    }

    public var body: some View {
        NavigationView {
            List {
                Section(header: Text("Documents").accessibilityAddTraits(.isHeader)) {
                    ForEach($project.documents) { $doc in
                        NavigationLink(destination: DocumentEditor(document: $doc), tag: doc.id, selection: $selectedDocumentId) {
                            Text(doc.title)
                        }
                        .accessibilityLabel("Document: \(doc.title)")
                        .accessibilityHint("Opens document editor")
                    }
                }

                Section(header: Text("Sheets").accessibilityAddTraits(.isHeader)) {
                    ForEach($project.sheets) { $sheet in
                        NavigationLink(destination: SheetEditor(sheet: $sheet), tag: sheet.id, selection: $selectedSheetId) {
                            Text(sheet.title)
                        }
                        .accessibilityLabel("Sheet: \(sheet.title)")
                        .accessibilityHint("Opens sheet editor")
                    }
                }

                Section(header: Text("Decks").accessibilityAddTraits(.isHeader)) {
                    ForEach($project.decks) { $deck in
                        NavigationLink(destination: DeckEditor(deck: $deck), tag: deck.id, selection: $selectedDeckId) {
                            Text(deck.title)
                        }
                        .accessibilityLabel("Deck: \(deck.title)")
                        .accessibilityHint("Opens deck editor")
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle(project.name)

            Text("Select an item to edit")
                .font(.largeTitle)
                .foregroundColor(.secondary)
                .accessibilityAddTraits(.isStaticText)
        }
    }
}
