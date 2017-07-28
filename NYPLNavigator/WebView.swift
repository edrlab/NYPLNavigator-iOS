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

    let jsEvents = ["leftTap": leftTapped,
                      "centerTap": centerTapped,
                      "rightTap": rightTapped]

    fileprivate let initialPosition: BinaryLocation

    public var initialPositionOverride: Double?

    // Max number of screen for representing the html document.
    public var totalScreens = 0
    // Currently displayed screen Index.
    public func currentScreenIndex() -> Int {
        return Int(round(scrollView.contentOffset.x / scrollView.frame.width))
    }

    public weak var viewDelegate: ViewDelegate?

    init(frame: CGRect, initialPosition: BinaryLocation) {
        self.initialPosition = initialPosition
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
        let index = currentScreenIndex()

        guard index > 0 else {
                viewDelegate?.displayPreviousDocument()
                updateProgression(to: 1.0)
            return
        }
        moveTo(screenIndex: index - 1)
    }

    /// Called from the JS code when a tap is detected in the 2/10 right
    /// part of the screen.
    ///
    /// - Parameter body: Unused.
    internal func rightTapped(body: String) {
        let index = currentScreenIndex()

        guard index < totalScreens - 1 else {
                viewDelegate?.displayNextDocument()
                updateProgression(to: 0.0)
            return
        }
        moveTo(screenIndex: index + 1)
    }

    /// Called from the JS code when a tap is detected in the 6/10 center
    /// part of the screen.
    ///
    /// - Parameter body: Unused.
    internal func centerTapped(body: String) {
        viewDelegate?.handleCenterTap()
    }

    internal func moveTo(screenIndex: Int, animated: Bool = false) {
        let screenSize = Int(scrollView.frame.size.width)
        let offset = screenSize * screenIndex

        let progression = Double(offset) / Double(scrollView.contentSize.width)

        updateProgression(to: progression)
        self.evaluateJavaScript("document.body.scrollLeft = \(offset)", completionHandler: nil)
    }

    internal func scroll(to tagId: String) {
        evaluateJavaScript("document.getElementById('\(tagId)').scrollIntoView();", completionHandler: { _ in
            self.updateProgression()
        })
    }

    internal func scroll(to location: BinaryLocation) {
        switch location {
        case .beginning:
            evaluateJavaScript("document.body.scrollLeft = 0", completionHandler: nil)
        case .end:
            evaluateJavaScript("document.body.scrollLeft = document.body.scrollWidth", completionHandler: nil)
        }
    }

    /// Save current document progression in the userDefault for later reopening
    /// of the book.
    /// A specific progression can be given, and if not, it will try to determine
    /// it unprecisely using screenIndex over the total number of screens. 
    /// (Imprecise cause not always up to date)
    fileprivate func updateProgression(to value: Double? = nil) {
        guard let publicationIdentifier = viewDelegate?.publicationIdentifier() else {
            return
        }
        let progression = (value != nil ? value : Double(currentScreenIndex()) / Double(totalScreens))

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
    private func scrollToInitialPosition() {
        let scrollViewPageWidth = Double(scrollView.frame.size.width)

        evaluateJavaScript("document.body.scrollWidth") { (result, error) in
            if error == nil, let result = result {
                let resultString = String(describing: result)
                let scrollViewTotalWidth = Double(resultString)!

                self.totalScreens = Int(ceil(scrollViewTotalWidth / scrollViewPageWidth))
            }
            /// If the savedProgression property has been set by the navigator.
            /// (means this webview is the first webView to appear).
            if let initialLocation = self.initialPositionOverride, initialLocation > 0.0 {
                let lastScreen = floor(Double(self.totalScreens) * initialLocation)

                let offset = lastScreen * scrollViewPageWidth

                self.evaluateJavaScript("document.body.scrollLeft = \(offset)", completionHandler: nil)
            }
        }
        if initialPositionOverride != nil {
            return // Will be handled in the js func above asynchronously.
        }

        // In case the above wasn't meet.
        scroll(to: initialPosition)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        scrollToInitialPosition()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let navigationType = navigationAction.navigationType

        if navigationType == .linkActivated {
            if let url = navigationAction.request.url {
                // TO/DO add URL normalisation.
                //check url if internal or external
                let publicationBaseUrl = viewDelegate?.publicationBaseUrl()
                if url.host == publicationBaseUrl?.host {
                    // DO internal
                    //-- remove base
                    
                    //let properUrl = url.absoluteString.replacingCharacters(in: publicationBaseUrl?.absoluteString, with: "")
                    viewDelegate?.displaySpineItem(with: url.absoluteString)
                } else if url.absoluteString.contains("https") { // TEMPORARY, better checks coming.
                    // External Link in
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
        updateProgression()
    }
}
