import UIKit
import WebKit

open class NavigatorViewController: UIViewController {

    private let delegatee: Delegatee!
    private let triptychView: TriptychView
    public let spineURLs: [URL]

    public init(spineURLs: [URL], initialIndex: Int) {
        precondition(initialIndex >= 0)
        precondition(initialIndex < spineURLs.count)

        delegatee = Delegatee()
        self.spineURLs = spineURLs
        triptychView = TriptychView(frame: CGRect.zero, viewCount: spineURLs.count, initialIndex: initialIndex)

        super.init(nibName: nil, bundle: nil)

        delegatee.parent = self

        triptychView.delegate = delegatee
        triptychView.frame = view.bounds
        triptychView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        view.addSubview(triptychView)
    }

    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override var prefersStatusBarHidden: Bool {
        return false//true
    }

    /// [Safe] Display the spine item at `index`.
    ///
    /// - Parameter index: The index of the spine item to display.
    public func displaySpineItem(at index: Int) {
        // Check if index is in bounds.
        guard spineURLs.indices.contains(index) else {
            return
        }
        // Load the item in the triptychView.
        triptychView.displayItem(at: index)
    }
}

/// Used to hide conformance to package-private delegate protocols.
private final class Delegatee: NSObject {
    weak var parent: NavigatorViewController!
}

extension Delegatee: TriptychViewDelegate {

    public func triptychView(
        _ view: TriptychView,
        viewForIndex index: Int,
        location: BinaryLocation
        ) -> UIView {

        let url = self.parent.spineURLs[index]
        let urlRequest = URLRequest(url: url)

        let webView = WebView(frame: view.bounds, initialLocation: location)

        webView.load(urlRequest)
        return webView
    }
}
