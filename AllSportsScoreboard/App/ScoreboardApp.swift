import SwiftUI
import SwiftData

@main
struct ScoreboardApp: App {
    @State private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            let theme = Theme.make(settings.appearance)
            RootView()
                .environment(settings)
                .environment(\.theme, theme)
                .preferredColorScheme(theme.colorScheme)
                .tint(theme.clock)
        }
        .modelContainer(HistoryStore.shared.container)
    }
}
