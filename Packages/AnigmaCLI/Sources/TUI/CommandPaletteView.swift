import Foundation

public struct Command: Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let action: @Sendable () async -> Void

    public init(id: String, title: String, description: String, action: @escaping @Sendable () async -> Void) {
        self.id = id
        self.title = title
        self.description = description
        self.action = action
    }
}

/// Modular command palette component
public class CommandPaletteView: TUIBaseComponent {
    private var commands: [Command] = []
    private var selectedIndex = 0
    private var filter = ""
    private let theme = Theme.defaultTheme

    public init() {
        super.init(id: "command_palette")
        self.isVisible = false // Hidden by default
    }

    public func setCommands(_ commands: [Command]) {
        self.commands = commands
        markDirty()
    }

    public func toggle() {
        self.isVisible.toggle()
        if isVisible {
            filter = ""
            selectedIndex = 0
        }
        markDirty()
    }

    public override func render(engine: TUIEngine, rect: TUIRect) async {
        guard isVisible else { return }

        let filtered = filteredCommands()
        let width = 50
        let height = min(filtered.count + 4, 15)
        let row = (rect.height - height) / 2
        let col = (rect.width - width) / 2

        await engine.drawBox(row: row, col: col, width: width, height: height, title: "Commands", color: theme.borderActive.color)

        await engine.addToFrame(row: row + 1, col: col + 2, text: engine.styled("> \(filter)_", style: theme.input))

        for (i, cmd) in filtered.prefix(height - 4).enumerated() {
            let isSelected = i == selectedIndex
            let style = isSelected ? theme.borderActive : theme.text
            let prefix = isSelected ? "> " : "  "
            await engine.addToFrame(row: row + 3 + i, col: col + 2, text: engine.styled("\(prefix)\(cmd.title)", style: style))
        }
    }

    public override func handleKey(_ key: InputHandler.Key) async -> Bool {
        guard isVisible else {
            if case .ctrlP = key { toggle(); return true }
            return false
        }

        switch key {
        case .char(let c):
            filter.append(c); selectedIndex = 0; markDirty(); return true
        case .backspace:
            if !filter.isEmpty { filter.removeLast(); selectedIndex = 0; markDirty() }
            return true
        case .up:
            if selectedIndex > 0 { selectedIndex -= 1; markDirty() }
            return true
        case .down:
            let filtered = filteredCommands()
            if selectedIndex < filtered.count - 1 { selectedIndex += 1; markDirty() }
            return true
        case .enter:
            let filtered = filteredCommands()
            if selectedIndex < filtered.count {
                let cmd = filtered[selectedIndex]
                toggle()
                Task { await cmd.action() }
            }
            return true
        case .escape, .ctrlP:
            toggle(); return true
        default:
            return false
        }
    }

    private func filteredCommands() -> [Command] {
        if filter.isEmpty { return commands }
        return commands.filter { $0.title.lowercased().contains(filter.lowercased()) }
    }
}
