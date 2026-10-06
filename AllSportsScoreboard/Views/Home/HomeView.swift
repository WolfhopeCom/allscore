import SwiftUI

struct HomeView: View {
    let session: GameSession?
    let playerSession: PlayerGameSession?
    let onSelectSport: (SportKind) -> Void
    let onQuickStart: () -> Void
    let onResume: () -> Void

    @Environment(\.theme) private var theme
    @Environment(AppSettings.self) private var settings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header

                if let playerSession {
                    PlayerResumeCard(session: playerSession, action: onResume)
                } else if let session {
                    ResumeCard(session: session, action: onResume)
                }

                QuickStartButton(
                    sport: settings.defaultSport,
                    detail: quickStartDetail,
                    action: onQuickStart
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("CHOOSE A SPORT")
                        .font(.boardLabel(12))
                        .tracking(2)
                        .foregroundStyle(theme.secondaryText)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        ForEach(SportCatalog.all) { sport in
                            SportTile(rules: SportCatalog.rules(for: sport)) {
                                onSelectSport(sport)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    HistoryView()
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .accessibilityLabel("History")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
    }

    private var quickStartDetail: String {
        let sport = settings.defaultSport
        if SportCatalog.isPlayerGame(sport) {
            let config = settings.playerGameDefaults()
            return "Bucket Golf · \(config.players.count) player\(config.players.count == 1 ? "" : "s")"
        }
        let config = settings.gameDefaults(for: sport)
        return "\(SportCatalog.rules(for: config).name) · \(config.teamName(.a)) vs \(config.teamName(.b))"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("ALL-SPORTS")
                .font(.boardLabel(13))
                .tracking(3.5)
                .foregroundStyle(theme.clock)
            Text("Scoreboard")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(theme.primaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct QuickStartButton: View {
    let sport: SportKind
    let detail: String
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: SportCatalog.rules(for: sport).symbolName)
                    .font(.system(size: 26, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("QUICK START")
                        .font(.boardLabel(12))
                        .tracking(2)
                        .opacity(0.75)
                    Text(detail)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 8)
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundStyle(theme.onClock)
            .padding(.horizontal, 18)
            .frame(height: 72)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.clock))
            .shadow(color: theme.clock.opacity(0.3 * theme.glow), radius: 18, y: 4)
        }
        .buttonStyle(PressableStyle(scale: 0.98))
        .accessibilityLabel("Quick start: \(detail)")
    }
}

private struct SportTile: View {
    let rules: any SportRules
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: rules.symbolName)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(theme.clock)
                    .frame(height: 30)
                Spacer(minLength: 12)
                Text(rules.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                Text(rules.summary)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(theme.panel))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(theme.panelStroke))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(rules.name). \(rules.summary)")
        .accessibilityHint("Sets up a new game")
    }
}

private struct ResumeCard: View {
    let session: GameSession
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    StatusPill(text: session.statusText, tone: session.statusTone)
                    Text(session.rules.name.uppercased())
                        .font(.boardLabel(12))
                        .tracking(1.5)
                        .foregroundStyle(theme.secondaryText)
                    Spacer()
                    if session.clockEnabled {
                        ResumeClock(session: session)
                    }
                }
                VStack(spacing: 6) {
                    teamRow(.a)
                    teamRow(.b)
                }
                HStack {
                    Text(session.phase == .final ? "View Final" : "Resume Game")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(theme.clock)
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.panel))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(theme.clock.opacity(0.35)))
        }
        .buttonStyle(PressableStyle(scale: 0.98))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current game. \(session.teamName(.a)) \(session.score(.a)), \(session.teamName(.b)) \(session.score(.b)). \(session.statusText).")
        .accessibilityHint("Opens the scoreboard")
        .accessibilityAddTraits(.isButton)
    }

    private func teamRow(_ side: TeamSide) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(theme.color(session.config[team: side].color))
                .frame(width: 4, height: 22)
            Text(session.teamName(side))
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)
            Spacer()
            Text("\(session.score(side))")
                .font(.score(30))
                .foregroundStyle(theme.primaryText)
        }
    }
}

private struct PlayerResumeCard: View {
    let session: PlayerGameSession
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        let state = session.state
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    StatusPill(text: session.statusText, tone: session.statusTone)
                    Text("BUCKET GOLF")
                        .font(.boardLabel(12))
                        .tracking(1.5)
                        .foregroundStyle(theme.secondaryText)
                    Spacer()
                }
                VStack(spacing: 6) {
                    ForEach(Array(state.standings.prefix(3)), id: \.self) { index in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(theme.color(session.config.color(index)))
                                .frame(width: 4, height: 22)
                            Text(session.config.playerName(index))
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(theme.primaryText)
                                .lineLimit(1)
                            Spacer()
                            Text("\(state.total(index))")
                                .font(.score(30))
                                .foregroundStyle(theme.primaryText)
                        }
                    }
                }
                HStack {
                    Text(session.phase == .final ? "View Final" : "Resume Game · \(session.currentName) is up")
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(theme.clock)
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.panel))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(theme.clock.opacity(0.35)))
        }
        .buttonStyle(PressableStyle(scale: 0.98))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current Bucket Golf game. \(session.statusText). \(session.currentName) is up.")
        .accessibilityAddTraits(.isButton)
    }
}

/// Separate view so only the clock text re-renders on each tick.
private struct ResumeClock: View {
    let session: GameSession
    @Environment(\.theme) private var theme

    var body: some View {
        Text(session.clockReading(at: session.now).text)
            .font(.clockFace(22))
            .foregroundStyle(theme.clock)
    }
}
