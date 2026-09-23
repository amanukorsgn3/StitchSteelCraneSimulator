import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = self.window ?? UIWindow(windowScene: windowScene)
        self.window = window
        (UIApplication.shared.delegate as? AppDelegate)?.attach(window: window)
    }
}
