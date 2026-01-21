//
//  BrowserLens.swift
//  DataUI
//
//  A WKWebView wrapper that serves as an ingestion surface.
//  Interaction: Browse, Capture, Extract.
//

import SwiftUI
import WebKit
import DataCore
import AnigmaClientKit

public struct BrowserLens: View {
    @State private var urlString: String
    @State private var currentURL: URL
    @Binding var selection: String?
    let onNavigate: ((URL) -> Void)?
    let onCapture: (String, String, URL) -> Void

    // Webview Coordinator triggers
    @State private var reloadTrigger = false
    @State private var goBackTrigger = false
    @State private var goForwardTrigger = false
    @State private var captureTrigger = false
    @State private var estimatedProgress: Double = 0.0
    @State private var isCapturing = false

    public init(
        selection: Binding<String?>,
        initialURL: URL? = nil,
        onNavigate: ((URL) -> Void)? = nil,
        onCapture: @escaping (String, String, URL) -> Void
    ) {
        self._selection = selection
        guard let startURL = initialURL ?? URL(string: "https://www.wikipedia.org") else {
            fatalError("Failed to unwrap startURL")
        }
        self._urlString = State(initialValue: startURL.absoluteString)
        self._currentURL = State(initialValue: startURL)
        self.onNavigate = onNavigate
        self.onCapture = onCapture
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Browser Toolbar
            HStack(spacing: 12) {
                // Navigation Controls
                HStack(spacing: 0) {
                    Button(action: { goBackTrigger.toggle() }) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .frame(width: 28, height: 28)
                    .accessibilityLabel("Go Back")

                    Button(action: { goForwardTrigger.toggle() }) {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.plain)
                    .frame(width: 28, height: 28)
                    .accessibilityLabel("Go Forward")

                    Button(action: { reloadTrigger.toggle() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .frame(width: 28, height: 28)
                    .accessibilityLabel("Reload Page")
                }
                .padding(.horizontal, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Navigation")

                // Address Bar
                TextField("Address", text: $urlString)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                    .accessibilityLabel("Address Bar")
                    .accessibilityAddTraits(.isSearchField)
                    .accessibilityHint("Enter a URL to navigate")
                    .onSubmit {
                        if let url = normalizeURL(from: urlString) {
                            currentURL = url
                            urlString = url.absoluteString
                        }
                    }

                // Capture Action
                Button(action: {
                    isCapturing = true
                    captureTrigger.toggle()
                    // Reset UI state after delay (actual capture is async but fast)
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        await MainActor.run {
                            isCapturing = false
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        if isCapturing {
                            Image(systemName: "arrow.down.circle.fill")
                                .symbolEffect(.bounce, value: isCapturing)
                        } else {
                            Image(systemName: "camera.aperture")
                        }
                        Text(isCapturing ? "Saved" : "Capture")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(isCapturing ? Color.green : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isCapturing)
                }
                .buttonStyle(.plain)
                .disabled(isCapturing)
                .accessibilityLabel(isCapturing ? "Saved" : "Capture Page")
                .accessibilityHint("Captures the current page content to the workspace")
            }
            .padding(10)
            .background(Color(nsColor: .windowBackgroundColor))
            .overlay(alignment: .bottom) {
                VStack(spacing: 0) {
                    if estimatedProgress < 1.0 {
                        ProgressView(value: estimatedProgress)
                            .progressViewStyle(.linear)
                            .tint(.blue)
                            .frame(height: 2)
                    }
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(nsColor: .separatorColor))
                }
            }

            // Web Content
            WebViewWrapper(
                url: currentURL,
                currentURL: $currentURL,
                reload: $reloadTrigger,
                goBack: $goBackTrigger,
                goForward: $goForwardTrigger,
                capture: $captureTrigger,
                estimatedProgress: $estimatedProgress,
                onCapture: onCapture
            )
        }
        .onChange(of: currentURL) { _, newValue in
            let next = newValue.absoluteString
            if urlString != next {
                urlString = next
            }
            onNavigate?(newValue)
        }
    }

    private func normalizeURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }
}

#if os(macOS)
struct WebViewWrapper: NSViewRepresentable {
    let url: URL
    @Binding var currentURL: URL
    @Binding var reload: Bool
    @Binding var goBack: Bool
    @Binding var goForward: Bool
    @Binding var capture: Bool
    @Binding var estimatedProgress: Double
    let onCapture: (String, String, URL) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.setupObservation(webView: webView)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastLoadedURL != url {
            webView.load(URLRequest(url: url))
            context.coordinator.lastLoadedURL = url
        }

        if reload {
            webView.reload()
            Task { @MainActor in reload = false }
        }

        if goBack {
            webView.goBack()
            Task { @MainActor in goBack = false }
        }

        if goForward {
            webView.goForward()
            Task { @MainActor in goForward = false }
        }

        if capture {
            WebViewWrapper.captureContent(from: webView, completion: onCapture)
            Task { @MainActor in capture = false }
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewWrapper
        var lastLoadedURL: URL?
        var progressObservation: NSKeyValueObservation?

        init(parent: WebViewWrapper) {
            self.parent = parent
        }

        func setupObservation(webView: WKWebView) {
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.parent.estimatedProgress = webView.estimatedProgress
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let url = webView.url else { return }
            Task { @MainActor in
                self.parent.currentURL = url
            }
            self.lastLoadedURL = url
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    static func captureContent(from webView: WKWebView, completion: @escaping (String, String, URL) -> Void) {
        guard let url = webView.url ?? URL(string: "about:blank") else {
            fatalError("Failed to unwrap url")
        }
        webView.evaluateJavaScript("document.title") { titleResult, _ in
            let title = (titleResult as? String) ?? "Untitled"
            webView.evaluateJavaScript("document.documentElement.outerHTML") { htmlResult, _ in
                let html = (htmlResult as? String) ?? ""
                completion(title, html, url)
            }
        }
    }
}
#endif
