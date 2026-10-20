import SwiftUI
import UIKit

/// Home-screen quick actions (long-press the app icon).
enum QuickAction: String {
    case quickStart
    case resume
    case bucketGolf
    case cornhole

    init?(_ item: UIApplicationShortcutItem) {
        self.init(rawValue: item.type)
    }

    /// Shown only while a game is in progress.
    static var resumeItem: UIApplicationShortcutItem {
        UIApplicationShortcutItem(
            type: QuickAction.resume.rawValue,
            localizedTitle: "Resume Game",
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(systemImageName: "arrow.uturn.forward"),
            userInfo: nil
        )
    }
}

/// Hands a quick action from UIKit to SwiftUI. RootView performs it.
@Observable
@MainActor
final class QuickActionRouter {
    static let shared = QuickActionRouter()
    var pending: QuickAction?
}

/// SwiftUI apps receive quick actions through a scene delegate.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let item = options.shortcutItem, let action = QuickAction(item) {
            Task { @MainActor in QuickActionRouter.shared.pending = action }
        }
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = QuickActionSceneDelegate.self
        return configuration
    }
}

final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        guard let action = QuickAction(shortcutItem) else {
            completionHandler(false)
            return
        }
        Task { @MainActor in QuickActionRouter.shared.pending = action }
        completionHandler(true)
    }
}
