import UIKit
import R2Streamer
import WebKit

open class NavigatorViewController: UIViewController {
    private let delegatee: Delegatee!
    fileprivate let triptychView: TriptychView
    //
    public let publication: Publication

    public init(for publication: Publication, initialIndex: Int) {
        self.publication = publication
        delegatee = Delegatee()
        triptychView = TriptychView(frame: CGRect.zero,
                                    viewCount: publication.spine.count,
                                    initialIndex: initialIndex)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        delegatee.parent = self
        triptychView.delegate = delegatee
        triptychView.frame = view.bounds
        triptychView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        view.addSubview(triptychView)
    }
}

extension NavigatorViewController {

    /// Display next spine item.
    public func displayNextSpineItem() {
        displaySpineItem(at: triptychView.index + 1)
    }

    /// Display previous spine item.
    public func displayPreviousSpineItem() {
        displaySpineItem(at: triptychView.index - 1)
    }

    /// TOFIX: Doesn't work properly. Winnie says that's it's related to the 
    /// preloading changes.
    /// [Safe] Display the spine item at `index`.
    ///
    /// - Parameter index: The index of the spine item to display.
    public func displaySpineItem(at index: Int) {
        // Check if index is in bounds.
        guard publication.spine.indices.contains(index) else {
            return
        }
        triptychView.moveToIndex(index)
    }

    public func getSpine() -> [Link] {
        return publication.spine
    }
}

/// Used to hide conformance to package-private delegate protocols.
private final class Delegatee: NSObject {
    weak var parent: NavigatorViewController!
}

extension Delegatee: TriptychViewDelegate {

    public func triptychView(_ view: TriptychView, viewForIndex index: Int,
                             location: BinaryLocation) -> UIView {
        let webView = WebView(frame: view.bounds, initialLocation: location)
        let link = parent.publication.spine[index]

        if let url = parent.publication.uriTo(link: link) {
            let urlRequest = URLRequest(url: url)

            webView.load(urlRequest)
        }
        return webView
    }
}
