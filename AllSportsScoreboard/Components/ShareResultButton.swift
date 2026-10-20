import SwiftUI

/// A small share button for the final screen: sends the result as text (Messages, a team
/// group chat, social posts), with a link to the app's website.
struct ShareResultButton: View {
    let text: String
    @Environment(\.theme) private var theme

    static let siteURL = "https://wolfhopecom.github.io"

    var body: some View {
        ShareLink(item: text) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.secondaryText)
                .frame(width: 40, height: 40)
                .background(Circle().fill(theme.control))
        }
        .accessibilityLabel("Share result")
    }
}
