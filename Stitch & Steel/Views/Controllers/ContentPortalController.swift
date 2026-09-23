import UIKit
import WebKit
import AVFoundation
import UniformTypeIdentifiers

final class ContentPortalController: UIViewController {
    private static var liveInstanceCount = 0

    var destination: String = ""

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        ContentPortalController.liveInstanceCount += 1
        print("[Portal] ContentPortalController CREATED — live instances: \(ContentPortalController.liveInstanceCount)")
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        ContentPortalController.liveInstanceCount += 1
        print("[Portal] ContentPortalController CREATED (coder) — live instances: \(ContentPortalController.liveInstanceCount)")
    }

    deinit {
        ContentPortalController.liveInstanceCount -= 1
        print("[Portal] ContentPortalController DEINIT — live instances: \(ContentPortalController.liveInstanceCount)")
    }

    private var contentView: WKWebView!
    private var loadingOverlay: UIView!
    private var loadingIndicator: UIActivityIndicatorView!
    private var loadingIndicatorCenterY: NSLayoutConstraint?
    private var navigationCoordinator: ContentNavigationCoordinator!
    private var hasFinishedInitialLoad = false

    private var errorView: UIView?
    private var errorMessageLabel: UILabel?
    private var didAutoRetryAfterFailure = false
    private var hasLoadedMainContent = false

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationCoordinator = ContentNavigationCoordinator(controller: self)
        setupContentView()
        setupLoadingOverlay()
        loadDestination()
    }

    private func setupContentView() {
        HTTPCookieStorage.shared.cookieAcceptPolicy = .always

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.suppressesIncrementalRendering = false
        if #available(iOS 15.4, *) {
            configuration.preferences.isElementFullscreenEnabled = true
        }

        let pagePreferences = WKWebpagePreferences()
        pagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = pagePreferences

        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.preferences = preferences

        let disableZoomSource = """
        var meta = document.querySelector('meta[name=viewport]');
        if (!meta) {
            meta = document.createElement('meta');
            meta.name = 'viewport';
            (document.head || document.getElementsByTagName('head')[0]).appendChild(meta);
        }
        meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no');
        """
        let disableZoomScript = WKUserScript(source: disableZoomSource, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(disableZoomScript)

        contentView = WKWebView(frame: .zero, configuration: configuration)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.navigationDelegate = navigationCoordinator
        contentView.uiDelegate = navigationCoordinator
        contentView.scrollView.contentInsetAdjustmentBehavior = .never
        contentView.scrollView.contentInset = .zero
        contentView.scrollView.scrollIndicatorInsets = .zero
        contentView.allowsBackForwardNavigationGestures = true
        contentView.backgroundColor = .black
        contentView.isOpaque = false
        contentView.scrollView.delegate = navigationCoordinator
        contentView.scrollView.bouncesZoom = false
        contentView.scrollView.pinchGestureRecognizer?.isEnabled = false
        contentView.customUserAgent = SafariAgent.current
        if #available(iOS 16.4, *) {
            contentView.isInspectable = false
        }

        view.backgroundColor = .black
        view.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: view.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        syncSharedCookiesIntoContentStore()
    }

    private func syncSharedCookiesIntoContentStore() {
        let store = contentView.configuration.websiteDataStore.httpCookieStore
        guard let sharedCookies = HTTPCookieStorage.shared.cookies else { return }
        for cookie in sharedCookies {
            store.setCookie(cookie)
        }
    }

    private func setupLoadingOverlay() {
        loadingOverlay = UIView()
        loadingOverlay.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.backgroundColor = DraftLook.inkDark
        view.addSubview(loadingOverlay)

        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.addSubview(loadingIndicator)

        let centerY = loadingIndicator.centerYAnchor.constraint(equalTo: loadingOverlay.centerYAnchor)
        loadingIndicatorCenterY = centerY

        NSLayoutConstraint.activate([
            loadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            centerY
        ])

        loadingIndicator.startAnimating()
        updateLoadingLayout(for: view.bounds.size)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        updateLoadingLayout(for: size)
    }

    private func updateLoadingLayout(for size: CGSize) {
        let isLandscape = size.width > size.height
        loadingIndicatorCenterY?.constant = isLandscape ? 70 : 0
    }

    private func loadDestination() {
        guard let address = URL(string: destination) else {
            finishInitialLoading()
            return
        }
        hideErrorView()
        hasLoadedMainContent = false
        navigationCoordinator.lastNavigatedAddress = address
        contentView.load(noCacheRequest(for: address))

        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self = self else { return }
            if !self.hasLoadedMainContent && self.contentView.url == nil {
                print("[Portal] Load timed out with no content — showing error screen")
                self.showErrorView(message: "Can't reach the server right now.\nPlease try again later.")
            } else {
                self.finishInitialLoading()
            }
        }
    }

    func markMainContentLoaded() {
        hasLoadedMainContent = true
        finishInitialLoading()
        syncContentStoreCookiesToShared()
    }

    func reload(address: URL) {
        contentView.load(noCacheRequest(for: address))
    }

    func handleMainFrameLoadFailure(_ error: NSError) {
        if !didAutoRetryAfterFailure {
            didAutoRetryAfterFailure = true
            print("[Portal] Main-frame load failed (\(error.code)) — auto-retrying once")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                self.reloadDestination()
            }
            return
        }
        print("[Portal] Main-frame load failed again (\(error.code)) — showing error screen")
        showErrorView(message: errorMessage(for: error))
    }

    private func reloadDestination() {
        guard let address = navigationCoordinator.lastNavigatedAddress ?? URL(string: destination) else {
            return
        }
        contentView.load(noCacheRequest(for: address))
    }

    private func noCacheRequest(for address: URL) -> URLRequest {
        return NetworkTransport.request(address: address)
    }

    private func errorMessage(for error: NSError) -> String {
        if error.domain == NSURLErrorDomain {
            switch error.code {
            case NSURLErrorNotConnectedToInternet:
                return "No internet connection.\nCheck your network and try again."
            case NSURLErrorTimedOut:
                return "The connection timed out.\nPlease try again."
            case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorDNSLookupFailed:
                return "Can't reach the server right now.\nPlease try again later."
            default:
                break
            }
        }
        return "Couldn't load the page.\nPlease try again."
    }

    func finishInitialLoading() {
        guard !hasFinishedInitialLoad else { return }
        hasFinishedInitialLoad = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let overlay = self.loadingOverlay else { return }
            self.loadingIndicator.stopAnimating()
            UIView.animate(withDuration: 0.2, animations: {
                overlay.alpha = 0
            }, completion: { _ in
                overlay.isHidden = true
            })
        }
    }

    func requestCameraAccessIfNeeded(completion: ((Bool) -> Void)? = nil) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            completion?(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion?(granted) }
            }
        default:
            completion?(false)
        }
    }

    func requestMicrophoneAccessIfNeeded(completion: ((Bool) -> Void)? = nil) {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            completion?(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { completion?(granted) }
            }
        default:
            completion?(false)
        }
    }

    func presentAttachmentPicker(allowsMultiple: Bool, completion: @escaping ([URL]?) -> Void) {
        let sheet = UIAlertController(title: "Choose file", message: nil, preferredStyle: .actionSheet)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sheet.addAction(UIAlertAction(title: "Camera", style: .default) { [weak self] _ in
                self?.requestCameraAccessIfNeeded { granted in
                    guard granted else {
                        completion(nil)
                        return
                    }
                    self?.showImagePicker(source: .camera, completion: completion)
                }
            })
        }
        sheet.addAction(UIAlertAction(title: "Photo Library", style: .default) { [weak self] _ in
            self?.showImagePicker(source: .photoLibrary, completion: completion)
        })
        sheet.addAction(UIAlertAction(title: "Browse Files", style: .default) { [weak self] _ in
            self?.showDocumentPicker(allowsMultiple: allowsMultiple, completion: completion)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completion(nil)
        })
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 40, width: 1, height: 1)
        }
        present(sheet, animated: true)
    }

    private func showImagePicker(source: UIImagePickerController.SourceType, completion: @escaping ([URL]?) -> Void) {
        let picker = UIImagePickerController()
        picker.sourceType = source
        picker.allowsEditing = false
        picker.delegate = navigationCoordinator
        picker.mediaTypes = ["public.image", "public.movie"]
        navigationCoordinator.pendingFileCompletion = completion
        if source == .camera {
            picker.cameraCaptureMode = .photo
        }
        present(picker, animated: true)
    }

    private func showDocumentPicker(allowsMultiple: Bool, completion: @escaping ([URL]?) -> Void) {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = allowsMultiple
        picker.delegate = navigationCoordinator
        navigationCoordinator.pendingFileCompletion = completion
        present(picker, animated: true)
    }

    private func syncContentStoreCookiesToShared() {
        contentView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            for cookie in cookies {
                HTTPCookieStorage.shared.setCookie(cookie)
            }
        }
    }

    private func showErrorView(message: String) {
        finishInitialLoading()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let existing = self.errorView {
                self.errorMessageLabel?.text = message
                existing.isHidden = false
                self.view.bringSubviewToFront(existing)
                return
            }

            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false
            container.backgroundColor = DraftLook.inkDark

            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.numberOfLines = 0
            label.textAlignment = .center
            label.textColor = .white
            label.font = .systemFont(ofSize: 17, weight: .medium)
            label.text = message
            container.addSubview(label)

            var configuration = UIButton.Configuration.filled()
            configuration.title = "Retry"
            configuration.baseForegroundColor = .white
            configuration.baseBackgroundColor = UIColor.white.withAlphaComponent(0.18)
            configuration.cornerStyle = .large
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 28, bottom: 12, trailing: 28)
            let retryButton = UIButton(configuration: configuration)
            retryButton.translatesAutoresizingMaskIntoConstraints = false
            retryButton.addTarget(self, action: #selector(self.retryButtonTapped), for: .touchUpInside)
            container.addSubview(retryButton)

            self.view.addSubview(container)
            NSLayoutConstraint.activate([
                container.topAnchor.constraint(equalTo: self.view.topAnchor),
                container.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
                container.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                container.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),

                label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                label.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 32),
                label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -32),

                retryButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                retryButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 24)
            ])

            self.errorView = container
            self.errorMessageLabel = label
        }
    }

    private func hideErrorView() {
        errorView?.isHidden = true
    }

    @objc private func retryButtonTapped() {
        didAutoRetryAfterFailure = false
        hasFinishedInitialLoad = false
        hasLoadedMainContent = false
        loadingOverlay?.isHidden = false
        loadingOverlay?.alpha = 1
        loadingIndicator?.startAnimating()
        hideErrorView()
        loadDestination()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }

    override var shouldAutorotate: Bool {
        return true
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        OrientationController.shared.unlockAllOrientations()
        setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        OrientationController.shared.unlockAllOrientations()
        setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}

enum SafariAgent {
    static var current: String {
        let version = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
        return "Mozilla/5.0 (iPhone; CPU iPhone OS \(version) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    }
}

final class ContentNavigationCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDocumentPickerDelegate {
    weak var controller: ContentPortalController?
    var lastNavigatedAddress: URL?
    var pendingFileCompletion: (([URL]?) -> Void)?

    init(controller: ContentPortalController) {
        self.controller = controller
    }

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        switch type {
        case .microphone:
            controller?.requestMicrophoneAccessIfNeeded { granted in
                decisionHandler(granted ? .grant : .deny)
            }
        case .camera:
            controller?.requestCameraAccessIfNeeded { granted in
                decisionHandler(granted ? .grant : .deny)
            }
        case .cameraAndMicrophone:
            controller?.requestCameraAccessIfNeeded { cameraGranted in
                guard cameraGranted else {
                    decisionHandler(.deny)
                    return
                }
                self.controller?.requestMicrophoneAccessIfNeeded { micGranted in
                    decisionHandler(micGranted ? .grant : .deny)
                }
            }
        @unknown default:
            controller?.requestCameraAccessIfNeeded { granted in
                decisionHandler(granted ? .grant : .deny)
            }
        }
    }

    func webView(_ webView: WKWebView, requestDeviceOrientationAndMotionPermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }

    @available(iOS 18.4, *)
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        controller?.presentAttachmentPicker(allowsMultiple: parameters.allowsMultipleSelection, completion: completionHandler)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        if let mediaAddress = info[.mediaURL] as? URL {
            pendingFileCompletion?([mediaAddress])
            pendingFileCompletion = nil
            return
        }
        let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
        guard let image, let data = image.jpegData(compressionQuality: 0.9) else {
            pendingFileCompletion?(nil)
            pendingFileCompletion = nil
            return
        }
        let directory = FileManager.default.temporaryDirectory
        let fileAddress = directory.appendingPathComponent("upload-\(UUID().uuidString).jpg")
        do {
            try data.write(to: fileAddress, options: .atomic)
            pendingFileCompletion?([fileAddress])
        } catch {
            pendingFileCompletion?(nil)
        }
        pendingFileCompletion = nil
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        pendingFileCompletion?(nil)
        pendingFileCompletion = nil
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        pendingFileCompletion?(urls)
        pendingFileCompletion = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        pendingFileCompletion?(nil)
        pendingFileCompletion = nil
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return nil
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if scrollView.zoomScale != 1.0 {
            scrollView.zoomScale = 1.0
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard isTargetFrameNil(for: navigationAction),
              let address = safeRequestAddress(from: navigationAction) else {
            if isTargetFrameNil(for: navigationAction) {
                print("[Portal] createWebViewWith: targetFrame=nil but request address could not be resolved")
            }
            return nil
        }
        lastNavigatedAddress = address

        if webView.backForwardList.backList.isEmpty {
            replaceCurrentHistoryEntry(in: webView, with: address)
        } else {
            webView.load(noCacheRequest(for: address))
        }
        return nil
    }

    private func noCacheRequest(for address: URL) -> URLRequest {
        return NetworkTransport.request(address: address)
    }

    private func replaceCurrentHistoryEntry(in webView: WKWebView, with address: URL) {
        guard let encoded = try? JSONEncoder().encode(address.absoluteString),
              let literal = String(data: encoded, encoding: .utf8) else {
            webView.load(noCacheRequest(for: address))
            return
        }
        webView.evaluateJavaScript("location.replace(\(literal));") { [weak self] _, error in
            if error != nil {
                self?.controller?.reload(address: address)
            }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.isForMainFrame,
           let httpResponse = navigationResponse.response as? HTTPURLResponse {
            let status = httpResponse.statusCode
            let addressText = httpResponse.url?.absoluteString ?? "?"
            if status >= 400 {
                print("[Portal] Main-frame HTTP \(status) for \(addressText) — server refused the request (not an app error)")
            } else {
                print("[Portal] Main-frame HTTP \(status) for \(addressText)")
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        if let address = webView.url {
            lastNavigatedAddress = address
            print("[Portal] Server redirect to \(address.absoluteString)")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        controller?.markMainContentLoaded()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        print("[Portal] didFail navigation: \(nsError.localizedDescription) (\(nsError.domain) \(nsError.code))")
        if isCancellation(nsError) {
            controller?.finishInitialLoading()
            return
        }
        controller?.handleMainFrameLoadFailure(nsError)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        print("[Portal] didFailProvisionalNavigation: \(nsError.localizedDescription) (\(nsError.domain) \(nsError.code))")
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorHTTPTooManyRedirects {
            let failingAddress = (nsError.userInfo[NSURLErrorFailingURLErrorKey] as? URL) ?? lastNavigatedAddress
            if let address = failingAddress {
                webView.load(noCacheRequest(for: address))
                return
            }
        }
        if isCancellation(nsError) {
            controller?.finishInitialLoading()
            return
        }
        controller?.handleMainFrameLoadFailure(nsError)
    }

    private func isCancellation(_ error: NSError) -> Bool {
        if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            return true
        }
        if error.domain == "WebKitErrorDomain" && (error.code == 102 || error.code == 101) {
            return true
        }
        return false
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        controller?.finishInitialLoading()
        if let address = lastNavigatedAddress {
            webView.load(noCacheRequest(for: address))
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let address = safeRequestAddress(from: navigationAction) else {
            decisionHandler(.allow)
            return
        }

        let scheme = address.scheme?.lowercased()

        let inAppSchemes: Set<String> = ["http", "https", "about", "blob", "data", "file"]
        let isInApp = scheme.map { inAppSchemes.contains($0) } ?? false

        if isInApp {
            lastNavigatedAddress = address
            decisionHandler(.allow)
            return
        }

        decisionHandler(.cancel)
        openDeepLinkExternally(address)
    }

    private func safeRequestAddress(from navigationAction: WKNavigationAction) -> URL? {
        if #available(iOS 18.0, *) {
            return navigationAction.request.url
        }

        let obj = navigationAction as NSObject

        if let request = obj.value(forKey: "request") as? NSURLRequest {
            return request.url
        }

        if let resolved = obj.value(forKeyPath: "request.URL") as? URL {
            return resolved
        }
        if let nsAddress = obj.value(forKeyPath: "request.URL") as? NSURL {
            return nsAddress as URL
        }
        if let absolute = obj.value(forKeyPath: "request.URL.absoluteString") as? String,
           let resolved = URL(string: absolute) {
            return resolved
        }
        if let mainDoc = obj.value(forKeyPath: "request.mainDocumentURL") as? URL {
            return mainDoc
        }
        if let mainDocNS = obj.value(forKeyPath: "request.mainDocumentURL") as? NSURL {
            return mainDocNS as URL
        }

        let selector = NSSelectorFromString("request")
        if obj.responds(to: selector),
           let unmanaged = obj.perform(selector),
           let request = unmanaged.takeUnretainedValue() as? NSURLRequest {
            return request.url
        }

        print("[Portal] Legacy request address could not be resolved")
        return nil
    }

    private func isTargetFrameNil(for navigationAction: WKNavigationAction) -> Bool {
        if #available(iOS 18.0, *) {
            return navigationAction.targetFrame == nil
        }

        let obj = navigationAction as NSObject
        let selector = NSSelectorFromString("targetFrame")
        guard obj.responds(to: selector) else {
            return false
        }
        return obj.perform(selector) == nil
    }

    private func openDeepLinkExternally(_ address: URL) {
        UIApplication.shared.open(address, options: [:]) { [weak self] success in
            if success { return }
            print("[Portal] Unable to open deep link externally: \(address.absoluteString)")

            guard let fallback = self?.strippedSafariSchemeAddress(from: address) else { return }
            print("[Portal] Retrying with stripped scheme: \(fallback.absoluteString)")
            UIApplication.shared.open(fallback, options: [:]) { fallbackSuccess in
                if !fallbackSuccess {
                    print("[Portal] Fallback open also failed: \(fallback.absoluteString)")
                }
            }
        }
    }

    private func strippedSafariSchemeAddress(from address: URL) -> URL? {
        guard let scheme = address.scheme?.lowercased(), scheme.hasPrefix("x-safari-") else {
            return nil
        }
        let strippedScheme = String(scheme.dropFirst("x-safari-".count))
        guard strippedScheme == "http" || strippedScheme == "https" else { return nil }

        var components = URLComponents(url: address, resolvingAgainstBaseURL: false)
        components?.scheme = strippedScheme
        return components?.url
    }
}
