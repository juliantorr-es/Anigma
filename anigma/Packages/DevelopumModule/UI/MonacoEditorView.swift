//
//  MonacoEditorView.swift
//  DevelopumModule
//
//  SwiftUI wrapper for Monaco editor running in WKWebView.
//  This component is UI-only; all side effects are handled via
//  the DevelopumBridge contract and job/receipt systems.
//

import SwiftUI
import WebKit

#if canImport(AppKit)
import AppKit
public typealias PlatformView = NSView
public typealias PlatformViewRepresentable = NSViewRepresentable
#elseif canImport(UIKit)
import UIKit
public typealias PlatformView = UIView
public typealias PlatformViewRepresentable = UIViewRepresentable
#endif

/// SwiftUI view that wraps Monaco editor in a WKWebView.
/// Communicates via DevelopumBridge contract messages.
public struct MonacoEditorView: PlatformViewRepresentable {
    /// File URI to display (anigma:// scheme).
    public let fileUri: String
    
    /// Initial content to display.
    public let content: String
    
    /// Language identifier for syntax highlighting.
    public let languageId: String
    
    /// Whether the editor is read-only.
    public let readOnly: Bool
    
    /// Bridge message handler.
    public let onBridgeMessage: ((DevelopumBridgeMessage) -> Void)?
    
    /// Chunk boundaries to visualize.
    public let chunkBoundaries: [CodeChunk]?
    
    /// Creates a Monaco editor view.
    public init(
        fileUri: String,
        content: String,
        languageId: String = "plaintext",
        readOnly: Bool = false,
        chunkBoundaries: [CodeChunk]? = nil,
        onBridgeMessage: ((DevelopumBridgeMessage) -> Void)? = nil
    ) {
        self.fileUri = fileUri
        self.content = content
        self.languageId = languageId
        self.readOnly = readOnly
        self.chunkBoundaries = chunkBoundaries
        self.onBridgeMessage = onBridgeMessage
    }
    
    #if canImport(AppKit)
    public func makeNSView(context: Context) -> WKWebView {
        makeWebView(context: context)
    }
    
    public func updateNSView(_ webView: WKWebView, context: Context) {
        updateWebView(webView, context: context)
    }
    #elseif canImport(UIKit)
    public func makeUIView(context: Context) -> WKWebView {
        makeWebView(context: context)
    }
    
    public func updateUIView(_ webView: WKWebView, context: Context) {
        updateWebView(webView, context: context)
    }
    #endif
    
    private func makeWebView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        
        // Set up message handler for bridge communication
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "developumBridge")
        configuration.userContentController = userContentController
        
        // Allow local file access for loading Monaco
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        // Load Monaco editor HTML
        if let monacoHtmlPath = Bundle.module.path(forResource: "monaco-editor", ofType: "html") {
            let monacoHtmlUrl = URL(fileURLWithPath: monacoHtmlPath)
            webView.loadFileURL(monacoHtmlUrl, allowingReadAccessTo: monacoHtmlUrl.deletingLastPathComponent())
        } else {
            // Fallback to a basic HTML page with Monaco CDN (for development)
            let html = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <title>Monaco Editor</title>
                <style>
                    body { margin: 0; padding: 0; overflow: hidden; }
                    #editor { width: 100vw; height: 100vh; }
                </style>
            </head>
            <body>
                <div id="editor"></div>
                <script src="https://unpkg.com/monaco-editor@latest/min/vs/loader.js"></script>
                <script>
                    require.config({ paths: { vs: 'https://unpkg.com/monaco-editor@latest/min/vs' } });
                    require(['vs/editor/editor.main'], function() {
                        window.editor = monaco.editor.create(document.getElementById('editor'), {
                            value: '',
                            language: 'plaintext',
                            theme: 'vs-dark',
                            automaticLayout: true
                        });
                        
                        // Bridge to native
                        window.developumBridge = {
                            postMessage: function(message) {
                                window.webkit.messageHandlers.developumBridge.postMessage(message);
                            }
                        };
                    });
                </script>
            </body>
            </html>
            """
            webView.loadHTMLString(html, baseURL: nil)
        }
        
        return webView
    }
    
    private func updateWebView(_ webView: WKWebView, context: Context) {
        // Update editor content if needed
        var script = """
        if (window.editor && window.editor.getValue() !== `\(content.escapingQuotes)`) {
            window.editor.setValue(`\(content.escapingQuotes)`);
        }
        if (window.editor) {
            monaco.editor.setModelLanguage(window.editor.getModel(), '\(languageId)');
            window.editor.updateOptions({ readOnly: \(readOnly) });
        }
        """
        
        if let chunks = chunkBoundaries {
            let decorationsJson = chunks.map { chunk -> String in
                // Map offset/length to line/column is complex without Monaco API
                // For now, we rely on byte offsets which Monaco doesn't natively support well without model access
                // So we send offsets to JS and let JS handle it using getPositionAt
                return "{ start: \(chunk.offset), end: \(chunk.offset + chunk.length), hash: '\(chunk.hash)' }"
            }.joined(separator: ",")
            
            script += """
            if (window.editor) {
                window.currentChunks = [\(decorationsJson)];
                const chunks = window.currentChunks;
                const model = window.editor.getModel();
                const decorations = chunks.map(chunk => {
                    const startPos = model.getPositionAt(chunk.start);
                    const endPos = model.getPositionAt(chunk.end);
                    return {
                        range: new monaco.Range(startPos.lineNumber, startPos.column, endPos.lineNumber, endPos.column),
                        options: {
                            isWholeLine: false,
                            className: 'chunkHighlight',
                            hoverMessage: { value: 'Chunk Hash: ' + chunk.hash }
                        }
                    };
                });
                window.chunkDecorations = window.editor.deltaDecorations(window.chunkDecorations || [], decorations);
            }
            """
        } else {
            script += """
            if (window.editor) {
                window.currentChunks = [];
                if (window.chunkDecorations) {
                    window.chunkDecorations = window.editor.deltaDecorations(window.chunkDecorations, []);
                }
            }
            """
        }
        
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self, onBridgeMessage: onBridgeMessage)
    }
    
    public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: MonacoEditorView
        var onBridgeMessage: ((DevelopumBridgeMessage) -> Void)?
        
        init(_ parent: MonacoEditorView, onBridgeMessage: ((DevelopumBridgeMessage) -> Void)?) {
            self.parent = parent
            self.onBridgeMessage = onBridgeMessage
        }
        
        // MARK: - WKScriptMessageHandler

        
        public func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "developumBridge",
                  let messageBody = message.body as? String,
                  let messageData = messageBody.data(using: .utf8) else {
                return
            }
            
            do {
                let bridgeMessage = try JSONDecoder().decode(DevelopumBridgeMessage.self, from: messageData)
                // Forward message to callback via parent
                parent.onBridgeMessage?(bridgeMessage)
            } catch {
                print("Failed to decode bridge message: \(error)")
            }
        }
        
        // MARK: - WKNavigationDelegate
        
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Initialize editor with content and settings
            let initScript = """
            if (window.editor) {
                window.editor.setValue(`\(parent.content.escapingQuotes)`);
                monaco.editor.setModelLanguage(window.editor.getModel(), '\(parent.languageId)');
                window.editor.updateOptions({ readOnly: \(parent.readOnly) });
                
                // Notify native that editor is ready
                window.developumBridge.postMessage(JSON.stringify({
                    version: '1.0',
                    type: 'editorReady',
                    messageId: '\(UUID().uuidString)',
                    sessionId: 'default',
                    timestampMs: \(Int64(Date().timeIntervalSince1970 * 1000)),
                    payload: {
                        type: 'editorReady',
                        payload: {
                            editorId: 'editor-\(UUID().uuidString)',
                            editorVersion: 'monaco',
                            capabilities: ['syntaxHighlighting', 'intellisense']
                        }
                    }
                }));
                
                // Add Chunk Action
                editor.addAction({
                    id: 'anigma.chunkAction',
                    label: 'Inspect Chunk',
                    contextMenuGroupId: 'navigation',
                    run: function(ed) {
                        if (!window.currentChunks) return;
                        var pos = ed.getPosition();
                        var model = ed.getModel();
                        var offset = model.getOffsetAt(pos);
                        var chunk = window.currentChunks.find(c => offset >= c.start && offset < c.end);
                        
                        if (chunk) {
                            window.developumBridge.postMessage(JSON.stringify({
                                version: '1.0',
                                type: 'chunkAction',
                                messageId: '\(UUID().uuidString)',
                                sessionId: 'default',
                                timestampMs: Date.now(),
                                payload: {
                                    type: 'chunkAction',
                                    payload: {
                                        hash: chunk.hash,
                                        start: chunk.start,
                                        end: chunk.end
                                    }
                                }
                            }));
                        }
                    }
                });
            }
            """
            webView.evaluateJavaScript(initScript, completionHandler: nil)
        }
    }
}

// MARK: - String Extension

private extension String {
    var escapingQuotes: String {
        return self.replacingOccurrences(of: "`", with: "\\`")
                   .replacingOccurrences(of: "$", with: "\\$")
    }
}

// MARK: - Preview

#if DEBUG
struct MonacoEditorView_Previews: PreviewProvider {
    static var previews: some View {
        MonacoEditorView(
            fileUri: "anigma://test.swift",
            content: "print(\"Hello, World!\")",
            languageId: "swift"
        )
        .frame(width: 800, height: 600)
    }
}
#endif