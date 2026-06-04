import SwiftUI
import WebKit

// Fullscreen / sheet WebView wrapper. Renamed per-app: hexRealm* prefix.
struct HexRealmWebPanel: UIViewRepresentable {
    let hexRealmURLString: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .always
        webView.isOpaque = true
        webView.backgroundColor = .black
        if let url = URL(string: hexRealmURLString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    // MUST be empty — never reload on SwiftUI re-renders.
    func updateUIView(_ uiView: WKWebView, context: Context) {
    }
}
