import UIKit
import R2Streamer
import WebKit

public protocol NavigatorDelegate: class {
    func middleTapHandler()
//    func currentDocumentProgressionDidChange()
}

open class NavigatorViewController: UIViewController {
    private let delegatee: Delegatee!
    fileprivate let triptychView: TriptychView
    //
    public let publication: Publication
    public weak var delegate: NavigatorDelegate?

//    /// Give the index of the current screen for the currently displayed document.
//    public var currentScreenInDocument: Int? {
//        didSet {
//            delegate?.currentDocumentProgressionDidChange()
//        }
//    }
//    /// Give the total numbers of screen for the currently displayed document.
//    public var totalScreenInDocument: Int? = 0 {
//        didSet {
//            delegate?.currentDocumentProgressionDidChange()
//        }
//    }

    /// - Parameters:
    ///   - publication: The publication.
    ///   - initialIndex: Inital index of -1 will open the publication's document
    ///                   to last opened place or 0.
    public init(for publication: Publication, initialIndex: Int) {
        self.publication = publication
        delegatee = Delegatee()
        var index = initialIndex

        if index == -1 {
            let publicationIdentifier = publication.metadata.identifier!
            let savedIndex = UserDefaults.standard.integer(forKey: "\(publicationIdentifier)-lastDocument")

            index = savedIndex
        }

        triptychView = TriptychView(frame: CGRect.zero,
                                    viewCount: publication.spine.count,
                                    initialIndex: index)
        super.init(nibName: nil, bundle: nil)
    }

    deinit {
        /// Saves the index of the last read spineItem.
        let publicationIdentifier = publication.metadata.identifier!

        UserDefaults.standard.set(triptychView.index,
                     forKey: "\(publicationIdentifier)-lastDocument")
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

extension NavigatorViewController: ViewDelegate {

    /// Display next spine item.
    public func displayNextDocument() {
        displaySpineItem(at: triptychView.index + 1)
    }

    /// Display previous spine item.
    public func displayPreviousDocument() {
        displaySpineItem(at: triptychView.index - 1)
    }

    func handleCenterTap() {
        delegate?.middleTapHandler()
    }

//    func currentDocumentProgressionChanged(_ current: Int, _ total: Int) {
//        let publicationIdentifier = publication.metadata.identifier!
//
//        currentScreenInDocument = current + 1
//        totalScreenInDocument = total
//        if total != 0 {
//            let progression = Double(currentScreenInDocument!) / Double(total)
//
//            UserDefaults.standard.set(progression,
//                                      forKey: "\(publicationIdentifier)-documentProgression")
//        }
//    }
}

/// Used to hide conformance to package-private delegate protocols.
private final class Delegatee: NSObject {
    weak var parent: NavigatorViewController!
    fileprivate var firstView = true
}

extension Delegatee: TriptychViewDelegate {

    public func triptychView(_ view: TriptychView, viewForIndex index: Int,
                             location: BinaryLocation) -> UIView {
        let webView = WebView(frame: view.bounds, initialLocation: location)
        let link = parent.publication.spine[index]

        if let url = parent.publication.uriTo(link: link) {
            let urlRequest = URLRequest(url: url)

            webView.viewDelegate = parent
            webView.load(urlRequest)

//            // Load last saved regionIndex for the first view.
//            if firstView {
//                firstView = false
//                let defaults = UserDefaults.standard
//                let publicationIdentifier = parent.publication.metadata.identifier!
//                let savedProgression = defaults.double(forKey: "\(publicationIdentifier)-documentProgression")
//
//                webView.savedProgression = savedProgression
//            }
        }
        return webView
    }
}
