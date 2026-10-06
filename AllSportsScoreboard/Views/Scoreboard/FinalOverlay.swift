import SwiftUI

/// Shown when a game ends: winner, final score, and what to do next.
struct FinalOverlay: View {
    let session: GameSession
    let onHome: () -> Void

    @Environment(\.theme) private var theme
    @State private var appeared = false

    var body: some View {
        let leader = session.state.winner

        ZStack {
            theme.background.opacity(theme.appearance == .daylight ? 0.82 : 0.78)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text(session.statusText.uppercased())
                    .font(.boardLabel(14))
                    .tracking(6)
                    .foregroundStyle(theme.clock)

                Group {
                    if let leader {
                        Text("\(session.teamName(leader)) wins")
                    } else {
                        Text("It's a tie")
                    }
                }
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

                HStack(alignment: .top, spacing: 28) {
                    finalScore(.a, isWinner: leader == .a)
                    Text("–")
                        .font(.score(48))
                        .foregroundStyle(theme.tertiaryText)
                        .padding(.top, 18)
                    finalScore(.b, isWinner: leader == .b)
                }

                if let summary = session.resultSummary {
                    Text(summary)
                        .font(.system(size: 14, weight: .semibold).monospacedDigit())
                        .foregroundStyle(theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }

                HStack(spacing: 10) {
                    overlayButton("Back to Game", symbol: "arrow.uturn.backward", prominent: false) {
                        session.reopen()
                    }
                    overlayButton("Rematch", symbol: "arrow.counterclockwise", prominent: true) {
                        session.rematch()
                    }
                    overlayButton("Home", symbol: "house", prominent: false, action: onHome)
                }
                .padding(.top, 6)
            }
            .padding(28)
            .frame(maxWidth: 560)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(theme.panel)
                    .shadow(color: theme.clock.opacity(0.25 * theme.glow), radius: 40)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(theme.clock.opacity(0.35))
            )
            .padding(20)
            .scaleEffect(appeared ? 1 : 0.92)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.55, bounce: 0.3)) {
                appeared = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private func finalScore(_ side: TeamSide, isWinner: Bool) -> some View {
        VStack(spacing: 6) {
            Text("\(session.score(side))")
                .font(.score(72))
                .foregroundStyle(isWinner || session.state.winner == nil ? theme.primaryText : theme.secondaryText)
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(theme.color(session.config[team: side].color))
                    .frame(width: 3, height: 14)
                Text(session.teamName(side).uppercased())
                    .font(.boardLabel(13))
                    .tracking(1.4)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                if isWinner {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.clock)
                        .accessibilityLabel("Winner")
                }
            }
        }
        .frame(minWidth: 110)
        .accessibilityElement(children: .combine)
    }

    private func overlayButton(_ title: String, symbol: String, prominent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 15, weight: .semibold))
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(prominent ? theme.onClock : theme.primaryText)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(prominent ? theme.clock : theme.control)
                )
        }
        .buttonStyle(PressableStyle())
    }
}
