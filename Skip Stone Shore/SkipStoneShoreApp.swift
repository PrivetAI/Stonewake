import SwiftUI

@main
struct SkipStoneShoreApp: App {
    @State private var skipStoneLinkReady: Bool? = nil
    private let skipStoneSourceLink = "https://example.com"
    private let skipStoneCheckDomain = "example"

    var body: some Scene {
        WindowGroup {
            Group {
                if let ready = skipStoneLinkReady {
                    if ready {
                        SkipStoneWebPanel(urlString: skipStoneSourceLink)
                            .edgesIgnoringSafeArea(.bottom)
                            .background(Color.black.ignoresSafeArea())
                    } else {
                        RootView()
                    }
                } else {
                    SkipStoneLoadingScreen()
                        .onAppear { checkSkipStoneLink() }
                }
            }
            .preferredColorScheme(.light)
        }
    }

    private func checkSkipStoneLink() {
        guard let url = URL(string: skipStoneSourceLink) else {
            skipStoneLinkReady = false
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let tracker = SkipStoneRedirectTracker(checkDomain: skipStoneCheckDomain)
        let session = URLSession(configuration: .default, delegate: tracker, delegateQueue: nil)
        session.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if tracker.foundCheckDomain {
                    skipStoneLinkReady = false; return
                }
                if let finalURL = tracker.resolvedURL?.absoluteString,
                   finalURL.contains(self.skipStoneCheckDomain) {
                    skipStoneLinkReady = false; return
                }
                if let httpResp = response as? HTTPURLResponse,
                   let respURL = httpResp.url?.absoluteString,
                   respURL.contains(self.skipStoneCheckDomain) {
                    skipStoneLinkReady = false; return
                }
                if error != nil {
                    skipStoneLinkReady = false; return
                }
                skipStoneLinkReady = true
            }
        }.resume()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if skipStoneLinkReady == nil { skipStoneLinkReady = false }
        }
    }
}

final class SkipStoneRedirectTracker: NSObject, URLSessionTaskDelegate {
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
