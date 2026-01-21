# Ergasterion Monaco Bundle

Minimal Monaco editor bundle for embedding in Ergasterion's WKWebView.

## Purpose

Provides a VS Code-quality text editing surface inside the native macOS app.
Swift/SwiftUI handles everything else; Monaco just does text editing.

## Stack

- **Monaco Editor** (MIT) - The actual editor
- **Vite** (MIT) - Build tool, zero-config bundling
- No React needed - vanilla JS wrapper

## Build

```bash
npm install
npm run build
```

Output: `dist/` folder containing:
- `index.html` - Entry point loaded by WKWebView
- `assets/` - JS/CSS chunks

## Integration with Ergasterion

1. Build this project
2. Copy `dist/` contents to Ergasterion's Resources
3. Load in WKWebView:
   ```swift
   webView.loadFileURL(
       Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "monaco")!,
       allowingReadAccessTo: Bundle.main.resourceURL!
   )
   ```

## Swift ↔ Monaco Communication

Use `WKScriptMessageHandler` for bidirectional messaging:

**Swift → Monaco:**
```swift
webView.evaluateJavaScript("editor.setValue('\(escapedText)')")
```

**Monaco → Swift:**
```javascript
window.webkit.messageHandlers.editorBridge.postMessage({
    type: 'contentChanged',
    content: editor.getValue()
});
```

## Files to Create

```
src/
├── index.html        # Entry HTML
├── main.ts           # Editor init + bridge setup
├── bridge.ts         # Swift ↔ JS messaging
└── themes/           # Custom themes (optional)
```

## Minimal Example

```typescript
// main.ts
import * as monaco from 'monaco-editor';

const editor = monaco.editor.create(document.getElementById('editor')!, {
    value: '',
    language: 'markdown',
    theme: 'vs-dark',
    minimap: { enabled: false },
    wordWrap: 'on',
    automaticLayout: true,
});

// Notify Swift of changes
editor.onDidChangeModelContent(() => {
    window.webkit?.messageHandlers?.editorBridge?.postMessage({
        type: 'contentChanged',
        content: editor.getValue()
    });
});

// Expose to Swift
(window as any).setEditorContent = (text: string) => {
    editor.setValue(text);
};

(window as any).getEditorContent = () => {
    return editor.getValue();
};
```
