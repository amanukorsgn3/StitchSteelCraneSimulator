import UIKit
import Network

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var orientationLock: UIInterfaceOrientationMask = .portrait

    private var launchInternetMonitor: NWPathMonitor?
    private var mainNavigationController: UINavigationController?
    private weak var rootPortal: ContentPortalController?
    private var isLaunchLoaderActive = true
    private var launchLoaderFinishWorkItem: DispatchWorkItem?
    private var launchLoaderDuration: TimeInterval { AppConstants.launchLoaderDuration }
    private let launchStartTime: CFTimeInterval = CACurrentMediaTime()
    private var didReceiveConfigResponse = false
    private var expectsPortalDestination = false
    private var didBindWindow = false
    private let bridgeService = BridgeService()

    private func logTiming(_ event: String) {
        let elapsed = CACurrentMediaTime() - launchStartTime
        print(String(format: "[Timing] %+6.3fs  %@", elapsed, event))
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        logTiming("didFinishLaunchingWithOptions begin")
        URLCache.shared = URLCache(memoryCapacity: 0, diskCapacity: 0, directory: nil)
        URLCache.shared.removeAllCachedResponses()
        LaunchState.shared.resetPersistentStateOnFreshInstallIfNeeded()
        performLaunchInternetCheck()
        observeLaunchState()

        if LaunchState.shared.isPermanentNativeFlow() {
            print("[Config] Permanent native flow is active.")
            didReceiveConfigResponse = true
            DispatchQueue.main.async { [weak self] in
                self?.updateLaunchPresentation()
            }
            return true
        }

        continueLaunchFlow()
        return true
    }

    func attach(window: UIWindow) {
        self.window = window
        if !didBindWindow {
            didBindWindow = true
            setupWindow()
        }
        updateLaunchPresentation()
    }

    private func setupWindow() {
        let menuVC = MenuViewController()
        let navigationController = UINavigationController(rootViewController: menuVC)
        navigationController.isNavigationBarHidden = true
        mainNavigationController = navigationController

        window?.rootViewController = LaunchLoaderViewController()
        window?.makeKeyAndVisible()

        scheduleLaunchLoaderFinish()
    }

    private func scheduleLaunchLoaderFinish() {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.logTiming("Launch loader SAFETY timeout reached (didReceiveConfigResponse=\(self.didReceiveConfigResponse))")

            if !self.didReceiveConfigResponse
                && LaunchState.shared.portalDestination == nil
                && !self.expectsPortalDestination
                && LaunchState.shared.pendingDestination == nil {
                self.logTiming("No server response within timeout — treating as no internet")
                LaunchState.shared.showNoInternetMessage()
            }

            self.updateLaunchPresentation()
        }
        launchLoaderFinishWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + launchLoaderDuration, execute: workItem)
    }

    private func cancelLoaderSafetyTimeout() {
        launchLoaderFinishWorkItem?.cancel()
        launchLoaderFinishWorkItem = nil
    }

    private func updateLaunchPresentation() {
        guard let window = window, let navigationController = mainNavigationController else { return }
        let state = LaunchState.shared

        if isLaunchLoaderActive {
            if state.noInternetMessage != nil {
                logTiming("Launch decision: no internet — showing plaque only (native stays hidden)")
                isLaunchLoaderActive = false
                cancelLoaderSafetyTimeout()
                showNoInternetScreen()
                return
            }

            if let destination = state.portalDestination {
                logTiming("Launch decision: portal — switching presentation")
                isLaunchLoaderActive = false
                expectsPortalDestination = false
                cancelLoaderSafetyTimeout()
                OrientationController.shared.unlockAllOrientations()
                switchRootToPortal(window: window, destination: destination)
                return
            }

            if expectsPortalDestination || state.pendingDestination != nil {
                logTiming("Launch: portal decision pending — keeping loader")
                return
            }

            if didReceiveConfigResponse {
                logTiming("Launch decision: native experience")
                isLaunchLoaderActive = false
                cancelLoaderSafetyTimeout()
                switchRootToNative(window: window, navigationController: navigationController)
                return
            }

            return
        }

        if let destination = state.portalDestination {
            OrientationController.shared.unlockAllOrientations()
            presentPortalDestination(destination)
        } else if state.noInternetMessage != nil {
            showNoInternetScreen()
        } else {
            ContentPresenter.shared.dismiss()
            OrientationController.shared.lockToPortrait()
        }
    }

    private func switchRootToPortal(window: UIWindow, destination: String) {
        OrientationController.shared.unlockAllOrientations()

        if let existing = rootPortal {
            if existing.destination != destination, let address = URL(string: destination) {
                existing.destination = destination
                existing.reload(address: address)
            }
            if window.rootViewController !== existing {
                existing.presentingViewController?.dismiss(animated: false)
                UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve, animations: {
                    window.rootViewController = existing
                })
            }
            return
        }

        let portal = ContentPortalController()
        portal.destination = destination
        rootPortal = portal

        UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve, animations: {
            window.rootViewController = portal
        }, completion: { _ in
            OrientationController.shared.unlockAllOrientations()
            portal.setNeedsUpdateOfSupportedInterfaceOrientations()
        })
    }

    private func switchRootToNative(window: UIWindow, navigationController: UINavigationController) {
        UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve, animations: {
            window.rootViewController = navigationController
        })
    }

    private func presentPortalDestination(_ destination: String) {
        guard let window = window else { return }

        if let portal = window.rootViewController as? ContentPortalController {
            rootPortal = portal
            ContentPresenter.shared.present(destination: destination)
            return
        }

        if window.rootViewController?.presentedViewController != nil {
            window.rootViewController?.dismiss(animated: false) { [weak self] in
                guard let self = self, let window = self.window else { return }
                self.switchRootToPortal(window: window, destination: destination)
            }
        } else {
            switchRootToPortal(window: window, destination: destination)
        }
    }

    private func showNoInternetScreen() {
        guard let window = window else { return }
        if window.rootViewController is NoInternetViewController { return }

        if window.rootViewController?.presentedViewController != nil {
            window.rootViewController?.dismiss(animated: false)
        }

        let noInternetVC = NoInternetViewController()
        UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve, animations: {
            window.rootViewController = noInternetVC
        })
    }

    private func observeLaunchState() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLaunchStateChange),
            name: LaunchState.didChangeNotification,
            object: nil
        )
    }

    @objc private func handleLaunchStateChange() {
        updateLaunchPresentation()
    }

    private func performLaunchInternetCheck() {
        let monitor = NWPathMonitor()
        launchInternetMonitor = monitor
        var didDeliverInitialPath = false

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            guard !didDeliverInitialPath else { return }
            didDeliverInitialPath = true

            self.logTiming("Internet check: path.status=\(path.status)")

            self.launchInternetMonitor?.cancel()
            self.launchInternetMonitor = nil

            guard path.status != .satisfied else { return }

            DispatchQueue.main.async {
                LaunchState.shared.showNoInternetMessage()
                self.updateLaunchPresentation()
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.stitchsteel.launchInternetCheck"))
    }

    private func continueLaunchFlow() {
        logTiming("continueLaunchFlow")
        if LaunchState.shared.portalDestination != nil {
            print("[Config] Portal destination already opened. Skipping launch flow.")
            return
        }

        if LaunchState.shared.activateStoredDestinationIfValid() {
            OrientationController.shared.unlockAllOrientations()
            print("[Config] Stored portal destination is valid. Portal flow will open.")
            return
        }

        sendBridgeRequest()
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if LaunchState.shared.portalDestination != nil || isPortalPresented(in: window) {
            return UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
        }
        if isRotatableLaunchScreenVisible(in: window) {
            return UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
        }
        return orientationLock
    }

    private func isRotatableLaunchScreenVisible(in window: UIWindow?) -> Bool {
        guard var top = window?.rootViewController ?? self.window?.rootViewController else { return false }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top is LaunchLoaderViewController || top is NoInternetViewController
    }

    private func sendBridgeRequest() {
        logTiming("Config GET sent")
        bridgeService.resolve { [weak self] resolution in
            guard let self else { return }
            self.logTiming("Config GET response received")
            let expectsPortal = self.handleBridgeResolution(resolution)
            self.didReceiveConfigResponse = true
            self.expectsPortalDestination = expectsPortal
            self.updateLaunchPresentation()
        }
    }

    @discardableResult
    private func handleBridgeResolution(_ resolution: BridgeResolution) -> Bool {
        guard !LaunchState.shared.isPermanentNativeFlow() else {
            print("[Config] Permanent native flow is active. Ignoring portal destination from server response.")
            return false
        }

        switch resolution {
        case .offline:
            print("[Config] Bridge request failed offline.")
            LaunchState.shared.showNoInternetMessage()
            return false
        case .none:
            print("[Config] Server response had no session. Native flow will remain active.")
            LaunchState.shared.recordFirstServerDecision(hasValidLink: false)
            if LaunchState.shared.isPermanentNativeFlow() {
                print("[Config] First server response had no valid link. Permanent native flow was saved.")
            }
            return false
        case .session(let token, let address):
            LaunchState.shared.recordFirstServerDecision(hasValidLink: true)
            if LaunchState.shared.isPermanentNativeFlow() {
                print("[Config] First server response had no valid link. Permanent native flow was saved.")
                return false
            }
            print("[Config] Server returned a session. Portal flow will open.")
            OrientationController.shared.unlockAllOrientations()
            LaunchState.shared.saveSession(token: token, address: address)
            return true
        }
    }

    private func isPortalPresented(in window: UIWindow?) -> Bool {
        if let root = window?.rootViewController {
            return containsPortalController(in: root)
        }

        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            for sceneWindow in scene.windows where containsPortalController(in: sceneWindow.rootViewController) {
                return true
            }
        }
        return false
    }

    private func containsPortalController(in root: UIViewController?) -> Bool {
        guard var top = root else { return false }
        if top is ContentPortalController {
            return true
        }
        while let presented = top.presentedViewController {
            if presented is ContentPortalController {
                return true
            }
            top = presented
        }
        return false
    }
}
