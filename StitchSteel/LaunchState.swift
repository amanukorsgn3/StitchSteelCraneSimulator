import Foundation
import Combine

final class LaunchState: ObservableObject {
    static let shared = LaunchState()

    static let didChangeNotification = NSNotification.Name("LaunchStateDidChange")

    @Published var portalDestination: String? {
        didSet { notifyChange() }
    }
    @Published var noInternetMessage: String? {
        didSet { notifyChange() }
    }

    private func notifyChange() {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: LaunchState.didChangeNotification, object: nil)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: LaunchState.didChangeNotification, object: nil)
            }
        }
    }

    private let destinationKey = "saved_portal_destination"
    private let tokenKey = "saved_access_token"
    private let expiresKey = "saved_portal_destination_expires"
    private let payloadKey = "saved_config_payload"
    private let permanentNativeKey = "permanent_native_flow"
    private let installMarkerKey = "app_install_initialized"
    private let firstServerDecisionRecordedKey = "first_server_decision_recorded"
    private let firstServerDecisionHasLinkKey = "first_server_decision_has_link"

    private(set) var pendingDestination: String?

    private init() {}

    func resetPersistentStateOnFreshInstallIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: installMarkerKey) else { return }

        defaults.set(true, forKey: installMarkerKey)

        defaults.removeObject(forKey: destinationKey)
        defaults.removeObject(forKey: tokenKey)
        defaults.removeObject(forKey: expiresKey)
        defaults.removeObject(forKey: payloadKey)
        defaults.removeObject(forKey: permanentNativeKey)
        defaults.removeObject(forKey: firstServerDecisionRecordedKey)
        defaults.removeObject(forKey: firstServerDecisionHasLinkKey)

        pendingDestination = nil
        portalDestination = nil
        noInternetMessage = nil
    }

    func activateStoredDestinationIfValid() -> Bool {
        if isPermanentNativeFlow() {
            clearStoredDestination()
            portalDestination = nil
            return false
        }

        guard let token = UserDefaults.standard.string(forKey: tokenKey), !token.isEmpty,
              let destination = UserDefaults.standard.string(forKey: destinationKey), !destination.isEmpty else {
            clearStoredDestination()
            portalDestination = nil
            return false
        }

        portalDestination = destination
        return true
    }

    func saveSession(token: String, address: String) {
        guard !isPermanentNativeFlow() else { return }
        UserDefaults.standard.set(address, forKey: destinationKey)
        UserDefaults.standard.set(token, forKey: tokenKey)
        prepareToOpenPortal(address)
    }

    func hasStoredDestination() -> Bool {
        guard !isPermanentNativeFlow() else { return false }
        guard let token = UserDefaults.standard.string(forKey: tokenKey), !token.isEmpty,
              let destination = UserDefaults.standard.string(forKey: destinationKey), !destination.isEmpty else {
            return false
        }
        return true
    }

    func clearStoredDestination() {
        UserDefaults.standard.removeObject(forKey: destinationKey)
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: expiresKey)
        UserDefaults.standard.removeObject(forKey: payloadKey)
    }

    func isPermanentNativeFlow() -> Bool {
        UserDefaults.standard.bool(forKey: permanentNativeKey)
    }

    func lockPermanentNativeFlow() {
        UserDefaults.standard.set(true, forKey: permanentNativeKey)
        clearStoredDestination()
        portalDestination = nil
    }

    func recordFirstServerDecision(hasValidLink: Bool) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: firstServerDecisionRecordedKey) else { return }

        defaults.set(true, forKey: firstServerDecisionRecordedKey)
        defaults.set(hasValidLink, forKey: firstServerDecisionHasLinkKey)

        if !hasValidLink {
            lockPermanentNativeFlow()
        }
    }

    func showNoInternetMessage() {
        noInternetMessage = "No internet connection. Please turn on the internet and open the app again."
    }

    func prepareToOpenPortal(_ destination: String) {
        pendingDestination = nil
        portalDestination = destination
    }
}
