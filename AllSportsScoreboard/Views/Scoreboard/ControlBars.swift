import SwiftUI

struct ScoreboardTopBar: View {
    let session: GameSession
    let showsSportName: Bool
    let onExit: () -> Void
    let onEditTeams: () -> Void
    let onAdjustClock: () -> Void
    let onEnterFullScreen: () -> Void
    let onSwapSides: () -> Void
    let onEndGame: () -> Void
    let onReset: () -> Void

    @Environment(\.theme) private var theme
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let rules = session.rules

        HStack(spacing: 8) {
            Button(action: onExit) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle(scale: 0.9))
            .accessibilityLabel("Home")

            HStack(spacing: 6) {
                Image(systemName: rules.symbolName)
                    .font(.system(size: 14, weight: .semibold))
                if showsSportName {
                    Text(rules.name.uppercased())
                        .font(.boardLabel(12))
                        .tracking(1.6)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(theme.secondaryText)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(rules.name)

            Spacer(minLength: 8)

            Menu {
                Section {
                    Button("Edit Teams", systemImage: "pencil", action: onEditTeams)
                    if session.canSwapSides {
                        Button("Swap Sides", systemImage: "arrow.left.arrow.right", action: onSwapSides)
                    }
                    if session.clockEnabled || (session.showsPeriod && session.model == .points) {
                        Button(session.clockEnabled ? "Clock & Period" : "Period", systemImage: "timer", action: onAdjustClock)
                    }
                }
                Section {
                    Button("Full Screen", systemImage: "arrow.up.left.and.arrow.down.right", action: onEnterFullScreen)
                    let soundTitle: String = settings.soundEnabled ? "Mute Sounds" : "Turn Sounds On"
                    Button(soundTitle, systemImage: settings.soundEnabled ? "speaker.slash" : "speaker.wave.2") {
                        settings.soundEnabled.toggle()
                    }
                }
                Section {
                    if session.phase != .final {
                        Button("End Game", systemImage: "flag.checkered", action: onEndGame)
                    }
                    Button("Reset Game", systemImage: "arrow.counterclockwise", role: .destructive, action: onReset)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(theme.primaryText)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(theme.control))
                    .contentShape(Circle())
            }
            .accessibilityLabel("Game menu")
        }
        .frame(height: 44)
        .overlay {
            StatusPill(text: session.statusText, tone: session.statusTone)
                .frame(maxWidth: showsSportName ? 320 : 190)
        }
    }
}

struct ControlBar: View {
    let session: GameSession
    /// Portrait: fewer buttons so the primary button keeps its width.
    let compact: Bool
    let onAdjustClock: () -> Void
    let onEnterFullScreen: () -> Void
    let onEndGame: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            BarIconButton(symbol: "arrow.uturn.backward", label: "Undo", isEnabled: session.canUndo) {
                session.undo()
            }
            PeriodMenu(session: session, onEndGame: onEndGame)

            Spacer(minLength: 0)
            if session.primaryAction.isVisible {
                PrimaryActionButton(action: session.primaryAction) {
                    session.performPrimary()
                }
                .transition(.opacity)
            }
            Spacer(minLength: 0)

            if session.clockEnabled {
                BarIconButton(symbol: "timer", label: "Clock & Period") {
                    Feedback.shared.play(.tap)
                    onAdjustClock()
                }
            }
            if !compact {
                BarIconButton(symbol: "arrow.up.left.and.arrow.down.right", label: "Full Screen", action: onEnterFullScreen)
            }
        }
        .frame(height: 56)
    }
}

/// Period actions: end the current one, jump forward or back, end the game.
struct PeriodMenu: View {
    let session: GameSession
    let onEndGame: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Menu {
            if session.phase == .final {
                Button("Back to Game", systemImage: "arrow.uturn.backward") {
                    session.reopen()
                }
            } else {
                switch session.model {
                case .points, .combat:
                    timedPeriodItems
                case .rally, .tennis:
                    Button("Change Server", systemImage: "arrow.left.arrow.right") {
                        session.setPossession((session.state.possession ?? .a).opponent)
                    }
                case .baseball:
                    Button("End \(session.periodTitle)", systemImage: "forward.end") {
                        session.endHalfInning()
                    }
                }
                if session.model == .combat {
                    Divider()
                    Button("Score Round Even (10-10)", systemImage: "equal") {
                        session.scoreRound(winner: nil, margin: 0)
                    }
                }
                if !session.rules.stoppageMethods.isEmpty {
                    Divider()
                    ForEach(session.rules.stoppageMethods, id: \.self) { method in
                        ForEach(TeamSide.allCases) { side in
                            Button("\(session.teamName(side)) Wins by \(method)", systemImage: "trophy") {
                                session.declareWinner(side, method: method)
                            }
                        }
                    }
                }
                Divider()
                Button(endGameTitle, systemImage: "flag.checkered", role: .destructive, action: onEndGame)
            }
        } label: {
            VStack(spacing: 2) {
                Text(session.showsPeriod ? session.periodLabel : "GAME")
                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Image(systemName: "chevron.up")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.secondaryText)
            }
            .foregroundStyle(theme.primaryText)
            .padding(.horizontal, 4)
            .frame(width: 54, height: 54)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(theme.control))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(theme.controlStroke))
        }
        .accessibilityLabel("Period options. Current: \(session.periodTitle)")
    }
}

private extension PeriodMenu {
    @ViewBuilder
    var timedPeriodItems: some View {
        if session.phase == .live, session.regulationPeriods > 1 || session.isOvertime {
            Button("End \(session.periodTitle)", systemImage: "forward.end") {
                session.endPeriod()
            }
        }
        if session.regulationPeriods > 1 || session.isOvertime || session.rules.allowsOvertime {
            if session.state.period < session.regulationPeriods + 9 {
                Button("Go to \(session.nextPeriodTitle)", systemImage: "chevron.right.2") {
                    session.advancePeriod()
                }
            }
        }
        if session.period > 1 {
            let previous = session.rules.periodTitle(session.period - 1, regulation: session.regulationPeriods)
            Button("Back to \(previous)", systemImage: "chevron.left.2") {
                session.setPeriod(session.period - 1, resetClock: false)
            }
        }
    }

    var endGameTitle: String {
        switch session.model {
        case .rally, .tennis: return "End Match"
        case .combat: return "End Fight (Decision)"
        case .points, .baseball: return "End Game"
        }
    }
}
