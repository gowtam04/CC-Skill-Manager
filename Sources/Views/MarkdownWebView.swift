import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.underPageBackgroundColor = .clear
        webView.loadHTMLString(html, baseURL: nil)
        context.coordinator.lastHTMLHash = html.hashValue
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let newHash = html.hashValue
        guard newHash != context.coordinator.lastHTMLHash else { return }
        context.coordinator.lastHTMLHash = newHash

        // Extract inner content for JS injection to avoid full page reload flicker
        if let contentStart = html.range(of: "<div id=\"content\">"),
           let scriptStart = html.range(of: "\n<script>hljs", options: [], range: contentStart.upperBound..<html.endIndex),
           let contentEnd = html.range(of: "</div>", options: .backwards, range: contentStart.upperBound..<scriptStart.lowerBound) {
            let fragment = String(html[contentStart.upperBound..<contentEnd.lowerBound])
            let escaped = MarkdownRenderer.escapeForJavaScript(fragment)
            let js = "document.getElementById('content').innerHTML = '\(escaped)'; hljs.highlightAll();"
            Task { @MainActor in
                do {
                    _ = try await webView.evaluateJavaScript(js)
                } catch {
                    webView.loadHTMLString(self.html, baseURL: nil)
                }
            }
        } else {
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    class Coordinator: NSObject, WKNavigationDelegate {
        var lastHTMLHash: Int = 0

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}
