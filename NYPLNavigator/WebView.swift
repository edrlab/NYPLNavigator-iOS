//
//
//

import WebKit
import SafariServices

protocol ViewDelegate: class {
    func displayNextDocument()
    func displayPreviousDocument()
    func handleCenterTap()
    func publicationIdentifier() -> String?
    func publicationBaseUrl() -> URL?
    func displaySpineItem(with href: String)
}

final class WebView: WKWebView {

    public weak var viewDelegate: ViewDelegate?
    fileprivate let initialLocation: BinaryLocation

    public var initialPositionOverride: Double?
    public var initialId: String?

    public var documentLoaded = false

    let jsEvents = ["leftTap": leftTapped,
                    "centerTap": centerTapped,
                    "rightTap": rightTapped,
                    "didLoad": documentDidLoad,
                    "updateProgression": progressionDidChange]

    init(frame: CGRect, initialLocation: BinaryLocation) {
        self.initialLocation = initialLocation
        super.init(frame: frame, configuration: .init())

        scrollView.delegate = self
        scrollView.bounces = false
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        navigationDelegate = self

    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension WebView {

    /// Called from the JS code when a tap is detected in the 2/10 left 
    /// part of the screen.
    ///
    /// - Parameter body: Unused.
    internal func leftTapped(body: String) {
        // Verify that the document is properly loaded.
        guard documentLoaded else {
            return
        }
//        // If we are at the left edge.
//        if scrollView.contentOffset.x == 0 {
//            // Move to previous document
//            viewDelegate?.displayPreviousDocument()
////            updateProgression(to: 0.0)
//            return
//        } else { // Move to previous position in document.
            scroll(.left)
//        }
    }

    /// Called from the JS code when a tap is detected in the 2/10 right
    /// part of the screen.
    ///
    /// - Parameter body: Unused.
    internal func rightTapped(body: String) {
        // Verify that the document is properly loaded.
        guard documentLoaded else {
            return
        }
        scroll(.right)
    }

    /// Called from the JS code when a tap is detected in the 6/10 center
    /// part of the screen.
    ///
    /// - Parameter body: Unused.
    internal func centerTapped(body: String) {
        viewDelegate?.handleCenterTap()
    }

    enum Scroll {
        case left
        case right

        func proceed(on target: WebView) {
            switch self {
            case .left:
                target.evaluateJavaScript("scrollLeft();", completionHandler: { result, error in
                    if error == nil, let result = result as? String, result == "edge" {
                        target.viewDelegate?.displayPreviousDocument()
                    }
                })
            case .right:
                target.evaluateJavaScript("scrollRight();", completionHandler: { result, error in
                    if error == nil, let result = result as? String, result == "edge" {
                        target.viewDelegate?.displayNextDocument()
                    }
                })
            }
        }
    }

    internal func scroll(_ scroll: Scroll) {
        scroll.proceed(on: self)
    }

    /// Called by the javascript code to notify on DocumentReady.
    ///
    /// - Parameter body: Unused.
    internal func documentDidLoad(body: String) {
        documentLoaded = true
        scrollToInitialPosition()
    }

    /// Moves the webView to the initial location BinaryLocation.
    private func scrollToInitialPosition() {

        /// If the savedProgression property has been set by the navigator.
        if let initialPosition = self.initialPositionOverride, initialPosition > 0.0 {
            self.scrollAt(position: initialPosition)
        } else if let initialId = self.initialId {
            self.scrollAt(tagId: initialId)
        } else {
            scrollAt(location: initialLocation)
        }
    }

    // Called by the javascript code to notify that scrolling ended.
    internal func progressionDidChange(body: String) {
        guard documentLoaded, let position = Double(body) else {
            return
        }
        updateProgression(to: position)
    }

    //////

    // Scroll at position 0-1 (0%-100%)
    internal func scrollAt(position: Double) {
        guard position >= 0 && position <= 1 else { return }

        self.evaluateJavaScript("scrollToPosition(\'\(position)\')",
            completionHandler: nil)
    }

    // Scroll at the tag with id `tagId`.
    internal func scrollAt(tagId: String) {
        evaluateJavaScript("scrollToId(\'\(tagId)\');",
            completionHandler: nil)
    }

    // Scroll to .beggining or .end.
    internal func scrollAt(location: BinaryLocation) {
        switch location {
        case .beginning:
            scrollAt(position: 0)
        case .end:
            scrollAt(position: 1)
        }
    }

    /// Save current document progression in the userDefault for later reopening
    /// of the book.
    /// A specific progression can be given, and if not, it will try to determine
    /// it unprecisely using screenIndex over the total number of screens. 
    /// (Imprecise cause not always up to date)
    fileprivate func updateProgression(to value: Double) {
        guard let publicationIdentifier = viewDelegate?.publicationIdentifier() else {
            return
        }
        UserDefaults.standard.set(value,
                                  forKey: "\(publicationIdentifier)-documentProgression")
    }
}

// MARK: - WKScriptMessageHandler for handling incoming message from the Bridge.js
// javascript code.
extension WebView: WKScriptMessageHandler {

    // Handles incoming calls from JS.
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let body = message.body as? String else {
            return
        }
        if let handler = jsEvents[message.name] {
            handler(self)(body)
        }
    }

    /// Add a message handler for incoming javascript events.
    internal func addMessageHandlers() {
        // Add the message handlers.
        for eventName in jsEvents.keys {
            configuration.userContentController.add(self, name: eventName)
        }
    }

    // Deinit message handlers (preventing strong reference cycle).
    internal func removeMessageHandlers() {
        for eventName in jsEvents.keys {
            configuration.userContentController.removeScriptMessageHandler(forName: eventName)
        }
    }
}

extension WebView: WKNavigationDelegate {


//    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
//
//    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let navigationType = navigationAction.navigationType

        if navigationType == .linkActivated {
            if let url = navigationAction.request.url {
                // TO/DO add URL normalisation.
                //check url if internal or external
                let publicationBaseUrl = viewDelegate?.publicationBaseUrl()
                if url.host == publicationBaseUrl?.host,
                    let baseUrlString = publicationBaseUrl?.absoluteString {
                    // Internal link.
                    let href = url.absoluteString.replacingOccurrences(of: baseUrlString, with: "")

                    viewDelegate?.displaySpineItem(with: href)
                } else if url.absoluteString.contains("http") { // TEMPORARY, better checks coming.
                    // External Link.
                    let view = SFSafariViewController(url: url)

                    UIApplication.shared.keyWindow?.rootViewController?.present(view,
                                                                                animated: true,
                                                                                completion: nil)
                }
            }
        }

        decisionHandler(navigationType == .other ? .allow : .cancel)
    }
}

extension WebView: UIScrollViewDelegate {
    func viewForZooming(in: UIScrollView) -> UIView? {
        return nil
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // Update the DocumentProgression in userDefault when user swipe.
        let offset = scrollView.contentOffset.x / scrollView.contentSize.width

        updateProgression(to: Double(offset))
    }
}
