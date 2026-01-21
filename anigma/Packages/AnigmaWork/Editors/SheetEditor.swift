import SwiftUI

public struct SheetEditor: View {
    @Binding var sheet: SheetIR

    public init(sheet: Binding<SheetIR>) {
        self._sheet = sheet
    }

    public var body: some View {
        VStack {
            TextField("Title", text: $sheet.title)
                .font(.title)
                .padding()

            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading) {
                    HStack {
                        ForEach(sheet.columns) { column in
                            Text(column.name)
                                .frame(width: 100)
                                .border(Color.gray)
                        }
                    }

                    ForEach(sheet.rows) { row in
                        HStack {
                            ForEach(sheet.columns) { column in
                                Text(row.cells[column.id]?.value ?? "")
                                    .frame(width: 100)
                                    .border(Color.gray)
                            }
                        }
                    }
                }
            }
        }
    }
}
