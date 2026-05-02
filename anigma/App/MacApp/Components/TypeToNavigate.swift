//
//  TypeToNavigate.swift
//  AnigmaAppMac
//
//  View modifier for list navigation via typing.
//

import SwiftUI
import Foundation

struct TypeToNavigateModifier<T: Identifiable>: ViewModifier {
    let items: [T]
    let keyPath: KeyPath<T, String>
    @Binding var selection: Set<T.ID>

    @State private var buffer = ""
    @State private var lastKeyPress = Date()

    func body(content: Content) -> some View {
        content
            .onKeyPress { press in
                let char = press.characters
                // Reset buffer if time elapsed (1.0s)
                if Date().timeIntervalSince(lastKeyPress) > 1.0 {
                    buffer = ""
                }
                lastKeyPress = Date()

                // Handle delete
                if press.key == .delete {
                    buffer = ""
                    return .handled
                }

                if !char.isEmpty && (char.first?.isLetter == true || char.first?.isNumber == true || char == " ") {
                    buffer += char

                    if let match = items.first(where: { $0[keyPath: keyPath].range(of: buffer, options: [.anchored, .caseInsensitive]) != nil }) {
                        selection = [match.id]
                    }
                    return .handled
                }
                return .ignored
            }
    }
}

extension View {
    func typeToNavigate<T: Identifiable>(items: [T], keyPath: KeyPath<T, String>, selection: Binding<Set<T.ID>>) -> some View {
        modifier(TypeToNavigateModifier(items: items, keyPath: keyPath, selection: selection))
    }
}
