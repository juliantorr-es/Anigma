//
//  DiagramLens.swift
//  DataUI
//
//  A canvas view where entities are nodes.
//  Interaction: Direct manipulation, pan/zoom.
//

import SwiftUI
import DataCore

public struct DiagramLens: View {
    @Binding var selection: String?
    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 1.0

    // In real app, this comes from the entity graph
    let nodes: [DiagramNode] = [
        DiagramNode(id: "node-1", label: "Housing Move", position: CGPoint(x: 100, y: 100), type: .project),
        DiagramNode(id: "node-2", label: "Budget", position: CGPoint(x: 300, y: 100), type: .document),
        DiagramNode(id: "node-3", label: "Contract", position: CGPoint(x: 300, y: 250), type: .document)
    ]

    let edges: [DiagramEdge] = [
        DiagramEdge(from: 0, to: 1),
        DiagramEdge(from: 0, to: 2)
    ]

    public init(selection: Binding<String?>) {
        self._selection = selection
    }

    public var body: some View {
        GeometryReader { _ in
            ZStack {
                // Infinite Canvas Background
                Color(nsColor: .controlBackgroundColor)
                    .overlay(
                        GridPattern(spacing: 20)
                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(width: offset.width + value.translation.width, height: offset.height + value.translation.height)
                            }
                    )
                    .onTapGesture {
                        selection = nil
                    }
                    .accessibilityHidden(true)

                // Diagram Content
                ZStack {
                    // Edges
                    ForEach(edges.indices, id: \.self) { i in
                        let edge = edges[i]
                        Path { path in
                            let start = nodes[edge.from].position
                            let end = nodes[edge.to].position
                            path.move(to: start)
                            path.addCurve(
                                to: end,
                                control1: CGPoint(x: start.x + 50, y: start.y),
                                control2: CGPoint(x: end.x - 50, y: end.y)
                            )
                        }
                        .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                    }

                    // Nodes
                    ForEach(nodes) { node in
                        DiagramNodeView(node: node, isSelected: selection == node.id)
                            .position(node.position)
                            .onTapGesture {
                                selection = node.id
                            }
                    }
                }
                .offset(offset)
                .scaleEffect(scale)
            }
            .clipShape(Rectangle())
        }
    }
}

struct DiagramNode: Identifiable {
    let id: String
    let label: String
    let position: CGPoint
    let type: NodeType

    enum NodeType {
        case project, document, entity
    }
}

struct DiagramEdge {
    let from: Int
    let to: Int
}

struct DiagramNodeView: View {
    let node: DiagramNode
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(radius: isSelected ? 4 : 2, y: isSelected ? 2 : 1)

                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : borderColor, lineWidth: isSelected ? 3 : 2)

                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundColor(borderColor)
            }
            .frame(width: 60, height: 60)

            Text(node.label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(node.label), Type: \(node.type)")
        .accessibilityHint("Double tap to select this node.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    var iconName: String {
        switch node.type {
        case .project: return "folder.fill"
        case .document: return "doc.fill"
        case .entity: return "cube.fill"
        }
    }

    var borderColor: Color {
        switch node.type {
        case .project: return .blue
        case .document: return .gray
        case .entity: return .orange
        }
    }
}

struct GridPattern: Shape {
    let spacing: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for x in stride(from: 0, to: rect.width, by: spacing) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        for y in stride(from: 0, to: rect.height, by: spacing) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        return path
    }
}
