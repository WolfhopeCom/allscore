import SwiftUI

struct AboutView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ALL-SPORTS")
                        .font(.boardLabel(13))
                        .tracking(3.5)
                        .foregroundStyle(theme.clock)
                    Text("Scoreboard")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(theme.primaryText)
                    Text("Version \(AppInfo.versionString)")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                }

                InfoParagraph(
                    title: "Built for the sideline",
                    text: "A fast, readable scoreboard for pickup games, youth leagues, practices and game night. Pick a sport, enter the names, and you're keeping score in seconds."
                )
                InfoParagraph(
                    title: "A clock you can trust",
                    text: "The game clock is calculated from timestamps rather than counted tick by tick, so it never drifts, even if you switch apps or lock the screen. Games are saved continuously and resume exactly where you left off."
                )
                InfoParagraph(
                    title: "Original sound",
                    text: "Every buzzer, horn and chime is synthesized on your device. No recordings, nothing downloaded."
                )
                InfoParagraph(
                    title: "Works anywhere",
                    text: "No account, no internet connection, no ads. It works the same in a gym basement or in Airplane Mode."
                )
            }
            .padding(24)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Your data stays on your device.")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(theme.primaryText)

                InfoParagraph(
                    title: "What we collect",
                    text: "Nothing. All-Sports Scoreboard has no accounts, no analytics, no advertising, and no tracking. It never connects to the internet."
                )
                InfoParagraph(
                    title: "What's stored on this device",
                    text: "Your settings, your default team names, the game in progress, and your game history. These live only in the app's private storage on this device and are removed if you delete the app."
                )
                InfoParagraph(
                    title: "Deleting your history",
                    text: "Swipe a game in History to delete it, or use Clear to remove all games."
                )
            }
            .padding(24)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct InfoParagraph: View {
    let title: String
    let text: String
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(theme.primaryText)
            Text(text)
                .font(.body)
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
