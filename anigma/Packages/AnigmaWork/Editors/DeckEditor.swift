import SwiftUI

public struct DeckEditor: View {
    @Binding var deck: DeckIR

    public init(deck: Binding<DeckIR>) {
        self._deck = deck
    }

    public var body: some View {
        VStack {
            TextField("Title", text: $deck.title)
                .font(.title)
                .padding()

            ScrollView(.horizontal) {
                HStack {
                    ForEach(deck.slides) { slide in
                        VStack {
                            Text(slide.title)
                            Rectangle()
                                .fill(Color.white)
                                .border(Color.black)
                                .frame(width: 200, height: 150)
                                .overlay(
                                    Text("\(slide.layers.count) layers")
                                )
                        }
                        .padding()
                    }
                }
            }
        }
    }
}
