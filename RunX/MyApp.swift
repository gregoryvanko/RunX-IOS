import SwiftUI
import UIKit

// Point d'entrée UIKit : la fenêtre est créée par SceneDelegate (déclaré dans RunX-Info.plist)
// afin que le contrôleur racine puisse imposer un style de barre d'état clair (texte blanc sur le bandeau sombre).
@main final class AppDelegate: UIResponder, UIApplicationDelegate {}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = LightStatusBarHostingController(rootView: ContentView())
        window.makeKeyAndVisible()
        self.window = window
    }
}

// L'application reste en apparence claire, mais l'heure et la batterie s'affichent en blanc
// sur StatusBarBand. Remplace UIStatusBarStyle / -[UIApplication statusBarStyle], sans effet depuis iOS 27.
final class LightStatusBarHostingController<Content: View>: UIHostingController<Content> {
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}
