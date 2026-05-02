import Foundation

/// Container that manages multiple TUI components and coordinates rendering
public actor TUIContainer {
    private let engine: TUIEngine
    private var components: [TUIComponent] = []
    private var focusedComponentId: String?

    public init(engine: TUIEngine) {
        self.engine = engine
    }

    public func addComponent(_ component: TUIComponent) {
        components.append(component)
        if focusedComponentId == nil {
            focusedComponentId = component.id
        }
    }

    public func setFocus(_ id: String) async {
        guard focusedComponentId != id else { return }

        // Notify old component
        if let oldId = focusedComponentId,
           let oldComp = components.first(where: { $0.id == oldId }) {
            await oldComp.onBlur()
        }

        focusedComponentId = id

        // Notify new component
        if let newComp = components.first(where: { $0.id == id }) {
            await newComp.onFocus()
        }
    }

    public func cycleFocus() async {
        let visibleIds = components.filter { $0.isVisible }.map { $0.id }
        guard !visibleIds.isEmpty else { return }

        let currentIndex = visibleIds.firstIndex(of: focusedComponentId ?? "") ?? -1
        let nextIndex = (currentIndex + 1) % visibleIds.count
        await setFocus(visibleIds[nextIndex])
    }

    public func resize() async {
        // Mark all visible components as dirty to force a full re-layout and re-render
        for comp in components where comp.isVisible {
            (comp as? TUIBaseComponent)?.markDirty()
        }
        await render()
    }

    private var isChatExpanded: Bool = false
    
    public func toggleChatExpansion() {
        self.isChatExpanded.toggle()
        for comp in components {
            if comp.id == "data_inspector" {
                comp.isVisible = !isChatExpanded
            }
            comp.isDirty = true
        }
    }

    public func render() async {
        let size = await engine.getTerminalSize()
        let rootRect = TUIRect(row: 1, col: 1, width: size.cols, height: size.rows)

        // 1. Vertical Split: (Main Area + Input Area + Status Bar)
        let mainVLayout = TUILayout(direction: .vertical, items: [
            ("main_content", .flex(1.0)),
            ("input_area", .fixed(min(6, components.first { $0.id == "input_area" }.map { ($0 as? InputAreaView)?.lineCount ?? 1 } ?? 1) + 2)),
            ("status_bar", .fixed(1))
        ])
        
        let vRects = mainVLayout.calculate(in: rootRect)
        
        // 2. Horizontal Split in Main Area: (Chat + Inspector)
        var finalRects = vRects
        if let contentRect = vRects["main_content"] {
            if isChatExpanded {
                finalRects["message_list"] = contentRect
            } else {
                let hLayout = TUILayout(direction: .horizontal, items: [
                    ("message_list", .flex(2.0)),
                    ("data_inspector", .flex(1.0))
                ])
                let hRects = hLayout.calculate(in: contentRect)
                for (id, rect) in hRects {
                    finalRects[id] = rect
                }
            }
        }

        // Only trigger render if any visible component is dirty
        var anyDirty = false
        for comp in components where comp.isVisible && comp.isDirty {
            anyDirty = true
            break
        }

        guard anyDirty else { return }

        await engine.beginFrame()

        for comp in components where comp.isVisible {
            if let rect = finalRects[comp.id] {
                // Pass the specific rect to the component
                await (comp as? TUIBaseComponent)?.render(engine: engine, rect: rect)
                comp.isDirty = false
            }
        }

        await engine.endFrame()
    }

    public func dispatchKey(_ key: InputHandler.Key) async -> Bool {
        // Handle global focus cycling and view toggles
        if case .tab = key {
            toggleChatExpansion()
            return true
        }
        
        if case .ctrlP = key {
            if let palette = components.first(where: { $0.id == "command_palette" }) {
                palette.isVisible.toggle()
                palette.isDirty = true
                if palette.isVisible {
                    await setFocus(palette.id)
                } else {
                    await setFocus("input_area")
                }
                return true
            }
        }

        // First try the focused component
        if let focusedId = focusedComponentId,
           let focusedComp = components.first(where: { $0.id == focusedId }) {
            if await focusedComp.handleKey(key) {
                return true
            }
        }

        // Then try other components in reverse order (top to bottom)
        for comp in components.reversed() where comp.id != focusedComponentId && comp.isVisible {
            if await comp.handleKey(key) {
                return true
            }
        }

        return false
    }
}
