//
//
//

import WebKit

protocol ViewDelegate: class {
    func displayNextDocument()
    func displayPreviousDocument()
    func handleCenterTap()
    func publicationIdentifier() -> String?
}

final class WebView: WKWebView {

    let jsEvents = ["leftTap": leftTapped,
                      "centerTap": centerTapped,
                      "rightTap": rightTapped]

    fileprivate let initialLocation: BinaryLocation

    public var savedProgression: Double? = nil

    // Max number of screen for representing the html document.
    public var totalScreens = 0
    // Currently displayed screen Index.
    public func currentScreenIndex() -> Int {
        return Int(round(scrollView.contentOffset.x / scrollView.frame.width))
    }

    public weak var viewDelegate: ViewDelegate?

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
    func leftTapped(body: String) {
        let index = currentScreenIndex()

        guard index > 0 else {
            viewDelegate?.displayPreviousDocument()
            return
        }
        moveTo(screenIndex: index - 1)
    }

    /// Called from the JS code when a tap is detected in the 2/10 right
    /// part of the screen.
    ///
    /// - Parameter body: Unused.
    func rightTapped(body: String) {
        let index = currentScreenIndex()

        guard index < totalScreens - 1 else {
            viewDelegate?.displayNextDocument()
            return
        }
        moveTo(screenIndex: index + 1)
    }

    /// Called from the JS code when a tap is detected in the 6/10 center
    /// part of the screen.
    ///
    /// - Parameter body: Unused.
    func centerTapped(body: String) {
        viewDelegate?.handleCenterTap()
    }

    internal func moveTo(screenIndex: Int, animated: Bool = false) {
        let offset = Int(scrollView.frame.size.width) * screenIndex
        let regionIndexPoint = CGPoint(x: offset, y: 0)

        scrollView.setContentOffset(regionIndexPoint, animated: animated)
        // Update the DocumentProgression in the userDefault when the user tap.
        updateProgression()
    }

    /// Save current document progression in the userDefault for later reopening
    /// of the book.
    fileprivate func updateProgression() {
        guard let publicationIdentifier = viewDelegate?.publicationIdentifier() else {
            return
        }
        let progression = Double(currentScreenIndex()) / Double(totalScreens)

        UserDefaults.standard.set(progression,
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

    /// Moves the webView to the initial location BinaryLocation. 
    private func scrollToInitialLocation() {
        let scrollViewPageWidth = Double(scrollView.frame.size.width)

        evaluateJavaScript("document.body.scrollWidth") { (result, error) in
            if error == nil, let result = result {
                let resultString = String(describing: result)
                let scrollViewTotalWidth = Double(resultString)!

                self.totalScreens = Int(ceil(scrollViewTotalWidth / scrollViewPageWidth))
            }
            /// If the savedProgression property has been set by the navigator.
            /// (means this webview is the first webView to appear).
            if self.savedProgression != nil && self.savedProgression! > 0.0 {
                let lastScreen = floor(Double(self.totalScreens) * self.savedProgression!)

                let offset = lastScreen * scrollViewPageWidth

                self.evaluateJavaScript("document.body.scrollLeft = \(offset)", completionHandler: nil)
                return
            }
        }

        switch self.initialLocation {
        case .beginning:
            evaluateJavaScript("document.body.scrollLeft = 0", completionHandler: nil)
        case .end:
            evaluateJavaScript("document.body.scrollLeft = document.body.scrollWidth", completionHandler: nil)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        scrollToInitialLocation()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        decisionHandler(navigationAction.navigationType == .other ? .allow : .cancel)
    }
}

extension WebView: UIScrollViewDelegate {
    func viewForZooming(in: UIScrollView) -> UIView? {
        return nil
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // Update the DocumentProgression in userDefault when user swipe.
        updateProgression()
    }
}
