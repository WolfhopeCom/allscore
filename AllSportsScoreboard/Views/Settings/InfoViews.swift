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
                    text: "No account and no internet connection needed. Scoring works the same in a gym basement or in Airplane Mode. The free version shows ads on menu screens, never on the scoreboard during a game, and a one-time purchase removes them."
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
                Text("Your games stay on your device.")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(theme.primaryText)

                InfoParagraph(
                    title: "Your scores and settings",
                    text: "Your settings, team and player names, the game in progress, and your game history are stored only in the app's private storage on this device. We have no servers and no accounts, and we never see any of it. Deleting the app removes it all."
                )
                InfoParagraph(
                    title: "Ads in the free version",
                    text: "The free version shows ads from Google AdMob on menu screens. To show and measure ads, Google may collect your device's advertising identifier (only if you allow tracking), your IP address and approximate location, and how you interact with ads. Ads never appear on the scoreboard during a game."
                )
                InfoParagraph(
                    title: "Your choices",
                    text: "You can refuse tracking when asked, or change it later in iPhone Settings → Privacy & Security → Tracking. In regions that require it, Settings → Ad Privacy Choices lets you change your consent. Remove Ads turns off ads and their data collection entirely."
                )
                InfoParagraph(
                    title: "Purchases",
                    text: "Remove Ads is handled by Apple. We never see your payment details."
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
