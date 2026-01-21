# TUI Development Guide

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Creating New TUI Views](#creating-new-tui-views)
- [TUIComponent Protocol](#tuicomponent-protocol)
- [TUIEngine Rendering Methods](#tuiengine-rendering-methods)
- [Color and Styling System](#color-and-styling-system)
- [Input Handling](#input-handling)
- [Layout System](#layout-system)
- [Event Bus Communication](#event-bus-communication)
- [Best Practices](#best-practices)
- [Testing TUI Views](#testing-tui-views)
- [Common Patterns](#common-patterns)

## Architecture Overview

The Anigma CLI TUI system is built on several core components:

### Core Components

1. **TUIEngine** - Low-level rendering engine with double buffering and ANSI support
2. **TUIComponent** - Protocol for modular TUI components
3. **TUILayout** - Flexible layout system for positioning components
4. **TUITheme** - Centralized color and style management
5. **InputHandler** - Keyboard and mouse event handling
6. **TUIEventBus** - Component communication via events

### Architecture Principles

- **Double Buffering**: All rendering goes through back buffer to prevent flicker
- **Actor-based Concurrency**: TUIEngine uses Swift actors for thread-safe rendering
- **Component Modularity**: Views are independent and composable
- **ANSI Terminal Codes**: Direct terminal control for maximum compatibility

## Creating New TUI Views

### Basic View Structure

```swift
import Foundation

/// Example model management view
public actor ModelManagerView {
    private let engine: TUIEngine

    public init(engine: TUIEngine) {
        self.engine = engine
    }

    public func render(models: [ModelInfo], selectedIndex: Int = 0) async {
        await engine.clearScreen()
        let size = await engine.getTerminalSize()

        // Title
        let title = engine.styled("📦 Model Management", color: .magenta, style: .bold)
        await engine.renderText(row: 2, col: (size.cols - 20) / 2, text: title)

        // Content box
        await engine.drawBox(
            row: 4,
            col: 3,
            width: size.cols - 6,
            height: size.rows - 8,
            title: "Available Models"
        )

        // Render list items
        var row = 6
        for (index, model) in models.enumerated() {
            let isSelected = index == selectedIndex
            let prefix = isSelected ? "→ " : "  "
            let modelText = isSelected ? engine.styled(model.name, style: .bold) : model.name

            await engine.renderText(row: row, col: 5, text: "\(prefix)\(modelText)")
            row += 1
        }
    }
}
```

### View Development Checklist

- [ ] Make view an `actor` for thread safety
- [ ] Store `TUIEngine` reference
- [ ] Implement main `render()` method
- [ ] Use `clearScreen()` at start of render
- [ ] Get terminal size for responsive layout
- [ ] Center titles and important content
- [ ] Add visual hierarchy with colors
- [ ] Include keyboard shortcuts in footer

## TUIComponent Protocol

For modular, reusable components, implement `TUIComponent`:

```swift
/// Protocol for a modular TUI component
public protocol TUIComponent: AnyObject {
    /// Unique identifier for the component
    var id: String { get }

    /// Whether the component is currently visible
    var isVisible: Bool { get set }

    /// Whether the component needs re-rendering
    var isDirty: Bool { get set }

    /// Renders the component
    func render(engine: TUIEngine, rect: TUIRect) async

    /// Handles keyboard input
    func handleKey(_ key: InputHandler.Key) async -> Bool

    /// Focus lifecycle methods
    func onFocus() async
    func onBlur() async
}
```

### Using TUIBaseComponent

Extend `TUIBaseComponent` for common functionality:

```swift
public class MyCustomComponent: TUIBaseComponent {
    private var items: [String] = []

    public override init(id: String) {
        super.init(id: id)
    }

    public override func render(engine: TUIEngine, rect: TUIRect) async {
        guard isVisible else { return }

        // Render your component
        await engine.renderText(
            row: rect.row,
            col: rect.col,
            text: "My Component"
        )

        isDirty = false
    }

    public override func handleKey(_ key: InputHandler.Key) async -> Bool {
        switch key {
        case .up:
            // Handle up arrow
            markDirty()
            return true
        case .down:
            // Handle down arrow
            markDirty()
            return true
        default:
            return false
        }
    }
}
```

## TUIEngine Rendering Methods

### Basic Text Rendering

```swift
// Simple text at position
await engine.renderText(row: 5, col: 10, text: "Hello World")

// Text with maximum width
await engine.renderText(row: 5, col: 10, text: longText, maxWidth: 50)

// Styled text
let styled = engine.styled("Error", color: .red, style: .bold)
await engine.renderText(row: 5, col: 10, text: styled)
```

### Drawing Boxes

```swift
// Basic box
await engine.drawBox(row: 2, col: 5, width: 60, height: 20)

// Box with title
await engine.drawBox(
    row: 2,
    col: 5,
    width: 60,
    height: 20,
    title: "Status"
)

// Active (highlighted) box
await engine.drawBox(
    row: 2,
    col: 5,
    width: 60,
    height: 20,
    title: "Focused",
    active: true
)
```

### Progress Indicators

```swift
// Progress bar
await engine.renderProgressBar(
    row: 10,
    col: 5,
    width: 40,
    progress: 0.75  // 0.0 to 1.0
)

// Progress bar with label
await engine.renderProgressBar(
    row: 10,
    col: 5,
    width: 40,
    progress: downloadProgress,
    label: "Downloading"
)

// Spinner animation
await engine.renderSpinner(row: 5, col: 10, label: "Processing...")
```

### Error and Warning Display

```swift
// Error message
await engine.renderError(
    row: 15,
    col: 5,
    message: "Failed to load model",
    maxWidth: 60
)

// Warning message
await engine.renderWarning(
    row: 16,
    col: 5,
    message: "Low disk space",
    maxWidth: 60
)
```

### Multiline Text

```swift
let lines = [
    "Line 1",
    "Line 2",
    "Line 3"
]

await engine.renderMultiline(
    startRow: 5,
    col: 10,
    lines: lines,
    maxWidth: 50
)
```

### Frame Management

```swift
// Start a new frame
await engine.beginFrame()

// ... perform all rendering ...

// Commit frame to screen (differential rendering)
await engine.endFrame()
```

## Color and Styling System

### Available Colors

```swift
public enum Color: String {
    // Standard colors
    case black, red, green, yellow
    case blue, magenta, cyan, white

    // Bright variants
    case brightBlack, brightRed, brightGreen, brightYellow
    case brightBlue, brightMagenta, brightCyan, brightWhite
}
```

### Styling Text

```swift
// Single color
let text = engine.styled("Warning", color: .yellow)

// Color with background
let text = engine.styled("Error", color: .white, bg: .red)

// Color with style
let text = engine.styled("Important", color: .cyan, style: .bold)

// Using Theme.Style
let style = Theme.Style(
    color: .brightGreen,
    bg: nil,
    bold: true,
    italic: false,
    dim: false
)
let text = engine.styled("Success", style: style)
```

### Color Semantics

Use consistent colors for meaning:

- **Red** - Errors, destructive actions
- **Yellow** - Warnings, pending actions
- **Green** - Success, installed items
- **Blue** - Information, user input
- **Cyan** - Focus, active state
- **Magenta** - Titles, branding
- **BrightBlack (Gray)** - Disabled, unavailable

### Theme System

```swift
// Define custom theme
let customTheme = TUITheme(
    border: TUITheme.Style(color: .cyan),
    borderActive: TUITheme.Style(color: .brightCyan, bold: true),
    text: TUITheme.Style(color: .white),
    userRole: TUITheme.Style(color: .brightBlue, bold: true),
    assistantRole: TUITheme.Style(color: .brightGreen, bold: true),
    systemRole: TUITheme.Style(color: .brightBlack, italic: true),
    input: TUITheme.Style(color: .brightWhite),
    statusBar: TUITheme.Style(color: .black, bg: .white),
    error: TUITheme.Style(color: .brightRed, bold: true)
)

// Apply theme
await TUIThemeManager.shared.setTheme(customTheme)

// Get current theme
let theme = await TUIThemeManager.shared.getTheme()
```

## Input Handling

### Reading Keyboard Input

```swift
let inputHandler = InputHandler()

// Read single key
if let key = await inputHandler.readKey() {
    switch key {
    case .char(let c):
        print("Character: \(c)")
    case .up, .down, .left, .right:
        print("Arrow key")
    case .enter:
        print("Enter pressed")
    case .escape:
        print("Escape pressed")
    case .ctrlC:
        print("Ctrl+C pressed")
    default:
        break
    }
}

// Read full line
if let line = await inputHandler.readLine() {
    print("User entered: \(line)")
}

// Stream events
for await key in inputHandler.events {
    // Process key events
    if case .ctrlC = key {
        break
    }
}
```

### Supported Key Events

```swift
public enum Key {
    case char(Character)           // Any character
    case up, down, left, right    // Arrow keys
    case home, end                // Home/End
    case delete, backspace        // Deletion
    case enter, escape, tab, space
    case ctrlC, ctrlP             // Control keys
    case scrollUp, scrollDown     // Scroll wheel
    case mouseDown(row: Int, col: Int)
    case mouseUp(row: Int, col: Int)
    case mouseDrag(row: Int, col: Int)
    case unknown
}
```

## Layout System

### Layout Direction

```swift
public enum Direction {
    case vertical    // Stack components top-to-bottom
    case horizontal  // Stack components left-to-right
}
```

### Component Sizing

```swift
public enum TUISize {
    case fixed(Int)      // Fixed size in rows/cols
    case flex(Double)    // Proportional weight
    case content         // Size to content (limited support)
}
```

### Creating Layouts

```swift
// Vertical layout: header + content + footer
let layout = TUILayout(
    direction: .vertical,
    items: [
        (id: "header", size: .fixed(3)),
        (id: "content", size: .flex(1.0)),
        (id: "footer", size: .fixed(2))
    ]
)

let size = await engine.getTerminalSize()
let rootRect = TUIRect(row: 1, col: 1, width: size.cols, height: size.rows)

// Calculate regions
let regions = layout.calculate(in: rootRect)

// Render components in their regions
await headerComponent.render(engine: engine, rect: regions["header"]!)
await contentComponent.render(engine: engine, rect: regions["content"]!)
await footerComponent.render(engine: engine, rect: regions["footer"]!)
```

### Horizontal Split Example

```swift
// Two-column layout
let layout = TUILayout(
    direction: .horizontal,
    items: [
        (id: "sidebar", size: .fixed(20)),
        (id: "main", size: .flex(1.0))
    ]
)
```

## Event Bus Communication

### Publishing Events

```swift
// Status update
await TUIEventBus.shared.publish(.statusUpdated(message: "Processing..."))

// Message added
await TUIEventBus.shared.publish(.messageAdded(role: "user", content: "Hello"))

// Token received (streaming)
await TUIEventBus.shared.publish(.tokenReceived(token: "world"))

// Tool call events
await TUIEventBus.shared.publish(.toolCallStarted(name: "search"))
await TUIEventBus.shared.publish(.toolCallCompleted(name: "search", success: true))

// Focus change
await TUIEventBus.shared.publish(.focusChanged(toId: "message-list"))
```

### Subscribing to Events

```swift
let subscriptionId = await TUIEventBus.shared.subscribe { event in
    switch event {
    case .messageAdded(let role, let content):
        // Update message list
        print("New message from \(role): \(content)")

    case .statusUpdated(let message):
        // Update status bar
        print("Status: \(message ?? "idle")")

    case .tokenReceived(let token):
        // Append to streaming message
        print("Token: \(token)")

    case .focusChanged(let toId):
        // Update focus state
        print("Focus moved to: \(toId)")

    default:
        break
    }
}

// Unsubscribe when done
await TUIEventBus.shared.unsubscribe(id: subscriptionId)
```

## Best Practices

### 1. Terminal Management

```swift
// Always enable raw mode at start
let engine = TUIEngine()
try await engine.enableRawMode()

// Always disable raw mode on exit (use defer)
defer {
    Task {
        await engine.disableRawMode()
        await engine.clearScreen()
    }
}
```

### 2. Responsive Layout

```swift
// Always get current terminal size
let size = await engine.getTerminalSize()

// Center important content
let titleWidth = 20
let centerCol = (size.cols - titleWidth) / 2
await engine.renderText(row: 2, col: centerCol, text: title)

// Respect terminal boundaries
let maxWidth = size.cols - 6  // Leave 3 cols padding on each side
```

### 3. Visual Hierarchy

```swift
// Use consistent spacing
await engine.renderText(row: 2, col: 5, text: sectionTitle)  // Title
// (blank line at row 3)
await engine.renderText(row: 4, col: 7, text: content)       // Indented content

// Use colors for importance
let error = engine.styled("Error", color: .red, style: .bold)
let info = engine.styled("Info", color: .blue)
let hint = engine.styled("Tip", color: .brightBlack)
```

### 4. User Feedback

```swift
// Show selection clearly
let prefix = isSelected ? "→ " : "  "
let itemStyle = isSelected ? engine.styled(item, style: .bold) : item

// Provide status indicators
let statusIcon = switch status {
    case .available: "○"
    case .downloading: "⟳"
    case .installed: "●"
    case .error: "✗"
}

// Show keyboard shortcuts
let footer = "↑/↓: Navigate  •  Enter: Select  •  Q: Quit"
```

### 5. Performance

```swift
// Use frame buffering for multiple updates
await engine.beginFrame()
// ... all rendering operations ...
await engine.endFrame()  // Single screen update

// Avoid rendering when not visible
guard isVisible else { return }

// Mark dirty only when changed
if valueChanged {
    markDirty()
}
```

### 6. Error Handling

```swift
// Use standardized error display
await engine.renderError(
    row: errorRow,
    col: 5,
    message: error.localizedDescription,
    maxWidth: size.cols - 10
)

// Provide actionable messages
await engine.renderError(
    row: row,
    col: 5,
    message: "Model not found. Press R to refresh."
)
```

### 7. Accessibility

```swift
// Use Unicode symbols sparingly
// Good: "✓ Success"
// Better: "✓ Success" with color
// Best: "[OK] Success" with color (ASCII fallback)

// Provide text alternatives to colors
let status = engine.styled("[ONLINE]", color: .green)  // Text + color

// Include keyboard shortcuts
// Don't rely only on mouse input
```

## Testing TUI Views

### Manual Testing

1. **Run the command:**
   ```bash
   swift run anigma models-ui
   ```

2. **Test checklist:**
   - [ ] TUI displays without crashes
   - [ ] Colors render correctly
   - [ ] Text is readable and not truncated
   - [ ] Navigation keys work (↑↓←→)
   - [ ] Selection is clearly visible
   - [ ] Progress indicators animate smoothly
   - [ ] Resize terminal - layout adjusts correctly
   - [ ] Error messages display properly
   - [ ] Exit cleanly with Q or Ctrl+C

### Automated Testing

Since TUI is visual, testing focuses on logic:

```swift
import XCTest
@testable import AnigmaCLITUI

final class ModelManagerViewTests: XCTestCase {
    func testModelStatusRendering() async {
        let engine = TUIEngine()
        let view = ModelManagerView(engine: engine)

        let models = [
            ModelManagerView.ModelInfo(
                name: "test-model",
                size: "1GB",
                status: .installed
            )
        ]

        // Test doesn't crash
        await view.render(models: models, selectedIndex: 0)
    }
}
```

### Code Review Checklist

- [ ] All user-facing text is clear and concise
- [ ] Colors follow semantic conventions
- [ ] Keyboard shortcuts are documented
- [ ] Error messages are actionable
- [ ] Layout adapts to terminal size
- [ ] No hard-coded dimensions
- [ ] Raw mode is properly cleaned up
- [ ] Actor isolation is respected

## Common Patterns

### Pattern 1: List View with Selection

```swift
public actor ListView {
    private let engine: TUIEngine
    private var items: [String]
    private var selectedIndex: Int = 0

    public func render() async {
        await engine.clearScreen()
        let size = await engine.getTerminalSize()

        var row = 4
        for (index, item) in items.enumerated() {
            let isSelected = index == selectedIndex
            let prefix = isSelected ? "→ " : "  "
            let text = isSelected ? engine.styled(item, style: .bold) : item

            await engine.renderText(row: row, col: 5, text: "\(prefix)\(text)")
            row += 1
        }
    }

    public func moveUp() {
        if selectedIndex > 0 {
            selectedIndex -= 1
        }
    }

    public func moveDown() {
        if selectedIndex < items.count - 1 {
            selectedIndex += 1
        }
    }
}
```

### Pattern 2: Status Bar with Metrics

```swift
private func renderStatusBar(row: Int) async {
    let size = await engine.getTerminalSize()

    let items = [
        ("STATUS", status, statusColor),
        ("MODE", mode, .cyan),
        ("MODEL", modelName, .magenta)
    ]

    var col = 2
    for (label, value, color) in items {
        let labelText = engine.styled("\(label): ", color: .brightBlack)
        let valueText = engine.styled(value, color: color, style: .bold)

        await engine.renderText(row: row, col: col, text: "\(labelText)\(valueText)")
        col += label.count + value.count + 6  // spacing
    }
}
```

### Pattern 3: Input Form

```swift
public actor InputFormView {
    private let engine: TUIEngine
    private var fields: [String] = []
    private var values: [String] = []
    private var focusedField: Int = 0

    public func render() async {
        await engine.clearScreen()

        var row = 5
        for (index, field) in fields.enumerated() {
            let isFocused = index == focusedField
            let label = engine.styled("\(field): ", color: .white)
            let value = values[index]
            let valueText = isFocused
                ? engine.styled(value, color: .cyan, style: .bold)
                : value

            await engine.renderText(row: row, col: 5, text: "\(label)\(valueText)")

            if isFocused {
                await engine.renderText(row: row, col: 5 + field.count + 2 + value.count, text: "█")
            }

            row += 2
        }
    }
}
```

### Pattern 4: Loading Spinner

```swift
private func renderWithSpinner(message: String, frame: Int) async {
    let spinnerFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    let spinner = spinnerFrames[frame % spinnerFrames.count]

    let text = engine.styled("\(spinner) \(message)", color: .cyan)
    await engine.renderText(row: 10, col: 5, text: text)
}

// In main loop
var frame = 0
while processing {
    await renderWithSpinner(message: "Loading...", frame: frame)
    frame += 1
    try await Task.sleep(nanoseconds: 100_000_000)  // 0.1s
}
```

### Pattern 5: Error Recovery

```swift
do {
    let result = try await performOperation()
    await renderSuccess(result)
} catch {
    await engine.renderError(
        row: size.rows - 3,
        col: 3,
        message: "Operation failed: \(error.localizedDescription)",
        maxWidth: size.cols - 6
    )

    // Show retry option
    await engine.renderText(
        row: size.rows - 2,
        col: 3,
        text: engine.styled("Press R to retry, Q to quit", color: .yellow)
    )
}
```

---

## Quick Reference

### Most Common Operations

```swift
// Setup
let engine = TUIEngine()
try await engine.enableRawMode()
defer { await engine.disableRawMode() }

// Get dimensions
let size = await engine.getTerminalSize()

// Basic rendering
await engine.clearScreen()
await engine.renderText(row: 5, col: 10, text: "Hello")
await engine.drawBox(row: 2, col: 5, width: 40, height: 10)

// Styling
let text = engine.styled("Error", color: .red, style: .bold)

// Input
let inputHandler = InputHandler()
if let key = await inputHandler.readKey() {
    // Handle key
}

// Progress
await engine.renderProgressBar(row: 10, col: 5, width: 40, progress: 0.5)

// Errors
await engine.renderError(row: 15, col: 5, message: "Failed")
```

---

## Additional Resources

- **Source Files**: `Packages/AnigmaCLI/Sources/TUI/`
- **Examples**: `Packages/AnigmaCLI/Executable/ModelsUICommand.swift`
- **Theme Definitions**: `Packages/AnigmaCLI/Sources/TUI/TUITheme.swift`

## Contributing

When adding new TUI features:

1. Follow existing naming conventions
2. Use actors for thread safety
3. Document public APIs with doc comments
4. Add examples to this guide
5. Test on different terminal sizes
6. Verify color rendering in different terminals

---

**Last Updated**: 2026-01-21
