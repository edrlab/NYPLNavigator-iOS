import WebKit

final class WebView: WKWebView {

    let jsEvents = ["leftTap": leftTapHandler,
                      "centerTap": centerTapHandler,
                      "rightTap": rightTapHandler]

    fileprivate let initialLocation: BinaryLocation
    internal var lastPosition: Int?
    
    public var totalPositions: Int = 0 {
        didSet {
            print("pages -- \(totalPositions)")
        }
    }

    public func currentPosition() -> Int {
        return Int(round(scrollView.contentOffset.x / scrollView.frame.width))
    }

    public weak var viewDelegate: ViewDelegate?

    init(frame: CGRect, initialLocation: BinaryLocation) {
//        let configuration = WKWebViewConfiguration()
//        let contentController = WKUserContentController()
//
//        // Add the Bridge.js file to the webview.
//        if let bundle = Bundle.init(identifier: "org.nypl.simplified.NYPLNavigator"),
//            let bridgeFilePath = bundle.path(forResource: "Bridge", ofType: "js"),
//            let js = try? String(contentsOfFile: bridgeFilePath) {
//            let userScript = WKUserScript(source: js,
//                                          injectionTime: .atDocumentEnd,
//                                          forMainFrameOnly: false)
//            contentController.addUserScript(userScript)
//        }
//
//        configuration.userContentController = contentController
        self.initialLocation = initialLocation
        super.init(frame: frame, configuration: .init())

        navigationDelegate = self

        scrollView.delegate = self
        scrollView.bounces = false
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func leftTapHandler(body: String) {
        guard currentPosition() > 0 else {
            viewDelegate?.displayPreviousView()
            return
        }
        moveTo(regionIndex: currentPosition() - 1)
    }

    func centerTapHandler(body: String) {
        viewDelegate?.centerAreaTapped()
    }

    func rightTapHandler(body: String) {
        guard currentPosition() < totalPositions - 1 else {
            viewDelegate?.displayNextView()
            return
        }
        moveTo(regionIndex: currentPosition() + 1)
    }

    internal func moveTo(regionIndex: Int, animated: Bool = false) {
        let offset = Int(scrollView.frame.size.width) * regionIndex
        let regionIndexPoint = CGPoint(x: offset, y: 0)

        scrollView.setContentOffset(regionIndexPoint, animated: animated)
        viewDelegate?.updateLastPosition(currentPosition())
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

                self.totalPositions = Int(ceil(scrollViewTotalWidth / scrollViewPageWidth))
            }
        }

        /// If the user already browsed the book then the last position has been saved.
        if lastPosition != nil {
            let offset = Double(lastPosition!) * scrollViewPageWidth

            evaluateJavaScript("document.body.scrollLeft = \(offset)", completionHandler: nil)
            return
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
        viewDelegate?.updateLastPosition(currentPosition())
    }
}
