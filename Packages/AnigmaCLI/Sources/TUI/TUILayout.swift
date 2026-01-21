import Foundation

/// Defines how a component should be sized within a layout
public enum TUISize {
    case fixed(Int)
    case flex(Double) // Proportional weight
    case content // Size to content (not yet fully implemented)
}

/// A layout region for a component
public struct TUIRect {
    public var row: Int
    public var col: Int
    public var width: Int
    public var height: Int
}

/// Manages layout for TUI components
public struct TUILayout {
    public enum Direction {
        case vertical
        case horizontal
    }

    public let direction: Direction
    public let items: [(id: String, size: TUISize)]

    public init(direction: Direction, items: [(id: String, size: TUISize)]) {
        self.direction = direction
        self.items = items
    }

    public func calculate(in rect: TUIRect) -> [String: TUIRect] {
        var results: [String: TUIRect] = [:]

        let totalSize = direction == .vertical ? rect.height : rect.width
        var remainingSize = totalSize
        var totalFlex: Double = 0

        // First pass: fixed sizes
        for item in items {
            if case .fixed(let size) = item.size {
                remainingSize -= size
            } else if case .flex(let flex) = item.size {
                totalFlex += flex
            }
        }

        // Second pass: distribute flex
        var currentOffset = direction == .vertical ? rect.row : rect.col

        for item in items {
            let itemSize: Int
            switch item.size {
            case .fixed(let size):
                itemSize = size
            case .flex(let flex):
                itemSize = Int(Double(remainingSize) * (flex / totalFlex))
            case .content:
                itemSize = 1 // Fallback
            }

            if direction == .vertical {
                results[item.id] = TUIRect(row: currentOffset, col: rect.col, width: rect.width, height: itemSize)
            } else {
                results[item.id] = TUIRect(row: rect.row, col: currentOffset, width: itemSize, height: rect.height)
            }

            currentOffset += itemSize
        }

        return results
    }
}
