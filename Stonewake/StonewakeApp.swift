import SwiftUI

@main
struct StonewakeApp: App {
    @State private var stonewakeLinkReady: Bool? = nil
    private let stonewakeSourceLink = "https://stonewake.org"
    private let stonewakeCheckDomain = "stonewake.org/privacy-policy"

    var body: some Scene {
        WindowGroup {
            Group {
                if let ready = stonewakeLinkReady {
                    if ready {
                        StonewakeWebPanel(urlString: stonewakeSourceLink)
                            .edgesIgnoringSafeArea(.bottom)
                            .background(Color.black.ignoresSafeArea())
                    } else {
                        RootView()
                    }
                } else {
                    StonewakeLoadingScreen()
                        .onAppear { checkStonewakeLink() }
                }
            }
            .preferredColorScheme(.light)
        }
    }

    private func checkStonewakeLink() {
        guard let url = URL(string: stonewakeSourceLink) else {
            stonewakeLinkReady = false
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let tracker = StonewakeRedirectTracker(checkDomain: stonewakeCheckDomain)
        let session = URLSession(configuration: .default, delegate: tracker, delegateQueue: nil)
        session.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if tracker.foundCheckDomain {
                    stonewakeLinkReady = false; return
                }
                if let finalURL = tracker.resolvedURL?.absoluteString,
                   finalURL.contains(self.stonewakeCheckDomain) {
                    stonewakeLinkReady = false; return
                }
                if let httpResp = response as? HTTPURLResponse,
                   let respURL = httpResp.url?.absoluteString,
                   respURL.contains(self.stonewakeCheckDomain) {
                    stonewakeLinkReady = false; return
                }
                if error != nil {
                    stonewakeLinkReady = false; return
                }
                stonewakeLinkReady = true
            }
        }.resume()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if stonewakeLinkReady == nil { stonewakeLinkReady = false }
        }
    }
}

final class StonewakeRedirectTracker: NSObject, URLSessionTaskDelegate {
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
        completionHandler(request)
    }
}
