import SwiftUI

/// Center of the board: clock, period, possession, and (in full screen) the few
/// controls that remain.
struct ClockPanel: View {
    enum Layout {
        /// Landscape: a column between the two teams.
        case column
        /// Portrait: a row between the two teams.
        case row
    }

    let session: GameSession
    let layout: Layout
    let isFullScreen: Bool
    let onAdjust: () -> Void
    let onExitFullScreen: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        let rules = session.rules
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        Group {
            switch layout {
            case .column:
                VStack(spacing: 14) {
                    Spacer(minLength: 0)
                    if session.clockEnabled {
                        ClockFace(session: session, size: isFullScreen ? 96 : 74, onAdjust: onAdjust)
                    }
                    if session.showsPeriod {
                        PeriodBadge(session: session, size: isFullScreen ? 40 : 32)
                    }
                    if !session.clockEnabled && !session.showsPeriod {
                        titleBadge(rules.name)
                    }
                    MatchInfoView(session: session, compact: false)
                    if rules.showsPossessionControl {
                        PossessionControl(session: session, vertical: false)
                    }
                    Spacer(minLength: 0)
                    if isFullScreen {
                        FullScreenMiniControls(session: session, onExitFullScreen: onExitFullScreen)
                    }
                }

            case .row:
                HStack(spacing: 14) {
                    if session.clockEnabled {
                        ClockFace(session: session, size: isFullScreen ? 84 : 58, onAdjust: onAdjust)
                            .frame(maxWidth: .infinity)
                    }
                    VStack(spacing: 8) {
                        if session.showsPeriod {
                            PeriodBadge(session: session, size: isFullScreen ? 34 : 26)
                        } else if !session.clockEnabled {
                            titleBadge(rules.name)
                        }
                        MatchInfoView(session: session, compact: true)
                        if rules.showsPossessionControl {
                            PossessionControl(session: session, vertical: true)
                        }
                        if isFullScreen {
                            FullScreenMiniControls(session: session, onExitFullScreen: onExitFullScreen)
                        }
                    }
                    .frame(maxWidth: session.clockEnabled ? 190 : .infinity)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(shape.fill(theme.panel))
        .overlay(shape.strokeBorder(theme.panelStroke))
    }

    private func titleBadge(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.boardLabel(15))
            .tracking(2)
            .foregroundStyle(theme.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

/// The game clock. Tap to start/stop, long-press to adjust.
struct ClockFace: View {
    let session: GameSession
    let size: CGFloat
    let onAdjust: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        let reading = session.clockReading(at: session.now)
        let color = reading.isWarning ? theme.alert : theme.clock

        VStack(spacing: 2) {
            Text(reading.text)
                .font(.clockFace(size))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .shadow(color: color.opacity(0.45 * theme.glow), radius: size * 0.16)

            if let stoppage = reading.stoppage {
                Text(stoppage)
                    .font(.clockFace(size * 0.34))
                    .foregroundStyle(theme.alert)
                    .accessibilityHidden(true)
            } else if let caption = reading.caption {
                Text(caption)
                    .font(.boardLabel(11))
                    .tracking(2.5)
                    .foregroundStyle(theme.secondaryText)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: toggle)
        .onLongPressGesture(perform: adjust)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Game clock")
        .accessibilityValue("\(reading.spoken), \(session.isClockRunning ? "running" : "stopped")")
        .accessibilityHint("Double-tap to start or stop the clock.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { toggle() }
        .accessibilityAction(named: "Adjust clock") { adjust() }
    }

    private func toggle() {
        if session.isClockRunning {
            session.pauseClock()
        } else if session.canStartClock {
            session.startClock()
        }
    }

    private func adjust() {
        Feedback.shared.play(.tap)
        onAdjust()
    }
}

struct PeriodBadge: View {
    let session: GameSession
    let size: CGFloat

    @Environment(\.theme) private var theme

    var body: some View {
        let rules = session.rules
        let caption = (session.isOvertime ? rules.overtimeName : rules.periodName).uppercased()
        let label = session.periodLabel
        let showsCaption = !label.uppercased().contains(caption) && label.count <= 4

        VStack(spacing: 2) {
            if showsCaption {
                Text(caption)
                    .font(.boardLabel(10))
                    .tracking(2)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Text(label)
                .font(.system(size: showsCaption ? size : size * 0.62, weight: .bold).monospacedDigit())
                .foregroundStyle(theme.primaryText)
                .contentTransition(.numericText(value: Double(session.period)))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .animation(.snappy(duration: 0.35), value: session.period)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(session.periodTitle)
    }
}

/// Possession arrows. Filled vs outlined shape shows who has it, not just color.
struct PossessionControl: View {
    let session: GameSession
    /// Portrait: team A is on top, so arrows point up/down.
    let vertical: Bool

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 2) {
            arrow(for: .a)
            Text(session.rules.possessionName.uppercased())
                .font(.boardLabel(10))
                .tracking(1.5)
                .foregroundStyle(theme.secondaryText)
                .frame(minWidth: 34)
                .accessibilityHidden(true)
            arrow(for: .b)
        }
    }

    private func arrow(for side: TeamSide) -> some View {
        let active = session.state.possession == side
        let direction: String
        if vertical {
            direction = side == .a ? "up" : "down"
        } else {
            direction = side == .a ? "left" : "right"
        }
        return Button {
            session.setPossession(side)
        } label: {
            Image(systemName: "arrowtriangle.\(direction)\(active ? ".fill" : "")")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(active ? theme.clock : theme.tertiaryText)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.85))
        .accessibilityLabel("Possession to \(session.teamName(side))")
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

/// What stays on screen in Full Screen mode: the clock button, undo, and the way out.
struct FullScreenMiniControls: View {
    let session: GameSession
    let onExitFullScreen: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 8) {
            if session.primaryAction.isVisible {
                PrimaryActionButton(action: session.primaryAction, compact: true) {
                    session.performPrimary()
                }
            }
            HStack(spacing: 8) {
                miniButton("arrow.down.right.and.arrow.up.left", label: "Exit Full Screen", action: onExitFullScreen)
                miniButton("arrow.uturn.backward", label: "Undo", enabled: session.canUndo) { session.undo() }
            }
        }
        .opacity(0.9)
    }

    private func miniButton(_ symbol: String, label: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.secondaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.control))
        }
        .buttonStyle(PressableStyle(scale: 0.92))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label)
    }
}

/// Sport-specific center content: set scores, tennis calls, the baseball count, scorecards.
struct MatchInfoView: View {
    let session: GameSession
    let compact: Bool

    @Environment(\.theme) private var theme

    var body: some View {
        switch session.model {
        case .rally:
            setSummary(main: "\(session.score(.a))–\(session.score(.b))", caption: session.rules.periodNamePlural.uppercased(), call: session.matchCall)
        case .tennis:
            setSummary(
                main: "\(session.state.match.games[0])–\(session.state.match.games[1])",
                caption: "GAMES",
                call: session.matchCall
            )
        case .baseball:
            BaseballCountView(session: session, compact: compact)
        case .combat:
            if !session.completedSetLines.isEmpty {
                Text(session.completedSetLines.suffix(compact ? 2 : 4).joined(separator: "  "))
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(compact ? 1 : 2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
            }
        case .points:
            EmptyView()
        }
    }

    private func setSummary(main: String, caption: String, call: String?) -> some View {
        VStack(spacing: 4) {
            Text(caption)
                .font(.boardLabel(10))
                .tracking(2)
                .foregroundStyle(theme.secondaryText)
            Text(main)
                .font(.system(size: compact ? 24 : 34, weight: .bold).monospacedDigit())
                .foregroundStyle(theme.primaryText)
                .contentTransition(.numericText())
            if let call {
                Text(call)
                    .font(.boardLabel(11))
                    .tracking(1.6)
                    .foregroundStyle(theme.clock)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            if !session.completedSetLines.isEmpty {
                Text(session.completedSetLines.joined(separator: "  "))
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(theme.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .animation(.snappy(duration: 0.25), value: main)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(caption.capitalized) \(main.replacingOccurrences(of: "–", with: " to ")). \(call ?? "")")
    }
}

/// Balls, strikes and outs, with the buttons to record them.
struct BaseballCountView: View {
    let session: GameSession
    let compact: Bool

    @Environment(\.theme) private var theme

    var body: some View {
        let match = session.state.match
        VStack(spacing: compact ? 6 : 10) {
            HStack(spacing: compact ? 10 : 14) {
                countDots("B", value: match.balls, of: 3, color: theme.live)
                countDots("S", value: match.strikes, of: 2, color: theme.clock)
                countDots("O", value: match.outs, of: 2, color: theme.alert)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Count: \(match.balls) balls, \(match.strikes) strikes, \(match.outs) outs")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: compact ? 4 : 2), spacing: 6) {
                pitchButton("Ball", .ball)
                pitchButton("Strike", .strike)
                pitchButton("Foul", .foul)
                pitchButton("Out", .out)
            }
        }
        .disabled(session.phase == .final)
    }

    private func countDots(_ label: String, value: Int, of total: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.boardLabel(11))
                .foregroundStyle(theme.secondaryText)
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < value ? color : theme.tertiaryText.opacity(0.3))
                    .frame(width: 9, height: 9)
            }
        }
    }

    private func pitchButton(_ title: String, _ call: GameSession.PitchCall) -> some View {
        Button {
            session.recordPitch(call)
        } label: {
            Text(title.uppercased())
                .font(.boardLabel(12))
                .tracking(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: compact ? 34 : 38)
        }
        .buttonStyle(ScoreButtonStyle(tint: theme.clock, prominent: call == .out))
        .accessibilityLabel(title)
    }
}
