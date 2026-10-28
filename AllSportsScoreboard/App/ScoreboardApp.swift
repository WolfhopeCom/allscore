import SwiftUI
import SwiftData

@main
struct ScoreboardApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            // A bonus theme stops applying if its unlock goes away (e.g. a refunded Remove Ads).
            let theme = Theme.make(settings.canUse(settings.appearance) ? settings.appearance : .arena)
            RootView()
                .environment(settings)
                .environment(\.theme, theme)
                .preferredColorScheme(theme.colorScheme)
                .tint(theme.clock)
        }
        .modelContainer(HistoryStore.shared.container)
    }
}
