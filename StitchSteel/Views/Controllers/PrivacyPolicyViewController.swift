import UIKit
import WebKit

final class PrivacyPolicyViewController: UIViewController {
    private let addressString: String
    private var contentView: WKWebView!
    private var loadingIndicator: UIActivityIndicatorView!

    init(addressString: String) {
        self.addressString = addressString
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Privacy Policy"
        view.backgroundColor = DraftLook.paper

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Close",
            style: .done,
            target: self,
            action: #selector(closeTapped)
        )

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        contentView = WKWebView(frame: .zero, configuration: configuration)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.allowsBackForwardNavigationGestures = true
        contentView.scrollView.contentInsetAdjustmentBehavior = .never
        contentView.customUserAgent = SafariAgent.current
        contentView.navigationDelegate = self
        view.addSubview(contentView)

        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = DraftLook.ink
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: view.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        guard let address = URL(string: addressString) else { return }
        let request = NetworkTransport.request(address: address)
        loadingIndicator.startAnimating()
        contentView.load(request)
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}

extension PrivacyPolicyViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadingIndicator.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadingIndicator.stopAnimating()
    }
}
