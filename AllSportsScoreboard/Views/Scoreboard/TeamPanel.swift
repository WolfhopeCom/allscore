import SwiftUI

/// One team: name, counters, the huge score, and its scoring buttons.
///
/// Gestures on the score: tap adds the sport's default points, swipe up adds,
/// swipe down subtracts. Every one of these also has a visible button.
struct TeamPanel: View {
    let session: GameSession
    let side: TeamSide
    let showsControls: Bool
    let compact: Bool
    let onEditTeams: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        let rules = session.rules
        let teamColor = theme.color(session.config[team: side].color)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        VStack(spacing: compact ? 6 : 10) {
            header(rules: rules, color: teamColor)
            scoreArea(rules: rules, color: teamColor)
            if showsControls {
                ScoreButtonRow(
                    actions: rules.scoringActions,
                    subtract: rules.allowsSubtract ? rules.subtractPoints : nil,
                    tint: teamColor,
                    compact: compact,
                    onAdd: { session.addPoints($0, to: side) },
                    onSubtract: { session.subtractPoints(from: side) }
                )
                .frame(height: compact ? 50 : 54)
                .transition(.opacity)
            }
        }
        .padding(compact ? 12 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack(alignment: .top) {
                shape.fill(theme.panel)
                LinearGradient(
                    colors: [teamColor.opacity(0.13 * theme.glow), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
                Rectangle()
                    .fill(teamColor)
                    .frame(height: 3)
            }
            .clipShape(shape)
        )
        .overlay(shape.strokeBorder(theme.panelStroke))
    }

    // MARK: - Header

    private func header(rules: any SportRules, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(session.teamName(side).uppercased())
                .font(.boardLabel(compact ? 17 : 20))
                .tracking(1.6)
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .onLongPressGesture { onEditTeams() }
                .accessibilityAddTraits(.isHeader)
                .accessibilityAction(named: "Edit teams") { onEditTeams() }

            if rules.tracksPossession && session.state.possession == side {
                Text(rules.possessionName.uppercased())
                    .font(.boardLabel(10))
                    .tracking(1)
                    .foregroundStyle(theme.onClock)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(theme.clock))
                    .fixedSize()
                    .layoutPriority(1)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("Has possession")
            }

            Spacer(minLength: 6)

            ForEach(session.badges(for: side)) { badge in
                HStack(spacing: 5) {
                    Text(badge.title)
                        .font(.boardLabel(10))
                        .tracking(1)
                        .foregroundStyle(theme.secondaryText)
                    Text(badge.value)
                        .font(.system(size: 16, weight: .bold).monospacedDigit())
                        .foregroundStyle(theme.primaryText)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .overlay(Capsule().strokeBorder(theme.controlStroke))
                .fixedSize()
                .layoutPriority(1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(badge.title.capitalized): \(badge.value)")
            }

            ForEach(rules.counters) { spec in
                CounterChip(
                    spec: spec,
                    value: session.counter(spec, side),
                    onTap: { session.adjustCounter(spec, side: side, by: spec.tapDelta) },
                    onReverse: { session.adjustCounter(spec, side: side, by: -spec.tapDelta) },
                    onReset: { session.resetCounter(spec, side: side) }
                )
                // Chips keep their full width; the team name scales down instead.
                .fixedSize()
                .layoutPriority(1)
            }
        }
        .frame(height: 30)
        .animation(.snappy(duration: 0.25), value: session.state.possession)
    }

    // MARK: - Score

    private func scoreArea(rules: any SportRules, color: Color) -> some View {
        let text = session.scoreText(side)
        let caption = session.scoreCaption
        return GeometryReader { geometry in
            ScoreNumber(
                text: text,
                color: color,
                bump: session.scoreBumps[side.rawValue],
                fontSize: Self.fontSize(for: geometry.size, text: text)
            )
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .overlay(alignment: .topLeading) {
            if let caption {
                Text(caption.uppercased())
                    .font(.boardLabel(10))
                    .tracking(1.8)
                    .foregroundStyle(theme.tertiaryText)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { session.addTapPoints(to: side) }
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    let dy = value.translation.height
                    guard abs(dy) > 40, abs(dy) > abs(value.translation.width) else { return }
                    if dy > 0 {
                        session.subtractPoints(from: side)
                    } else {
                        session.addTapPoints(to: side)
                    }
                }
        )
        .overlay(alignment: .topTrailing) { flashBadge(color: color) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(session.teamName(side)) score")
        .accessibilityValue(text)
        .accessibilityHint(accessibilityHint(rules: rules))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { session.addTapPoints(to: side) }
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: session.addTapPoints(to: side)
            case .decrement: session.subtractPoints(from: side)
            @unknown default: break
            }
        }
    }

    static func fontSize(for size: CGSize, text: String) -> CGFloat {
        let characters = CGFloat(max(2, text.count))
        return max(24, min(size.height * 0.86, size.width / (characters * 0.64)))
    }

    private func accessibilityHint(rules: any SportRules) -> String {
        switch rules.model {
        case .rally, .tennis: return "Double-tap to give this side the point."
        case .combat: return "Double-tap to score the round 10-9 for this fighter."
        case .baseball: return "Double-tap to add a run. Swipe down to remove one."
        case .points: return "Double-tap to add \(rules.tapPoints). Swipe up or down to adjust."
        }
    }

    private func flashBadge(color: Color) -> some View {
        ZStack {
            if let flash = session.flash, flash.side == side {
                Text(flash.text)
                    .font(.system(size: compact ? 22 : 28, weight: .heavy).monospacedDigit())
                    .foregroundStyle(flash.isPositive ? color : theme.secondaryText)
                    .padding(.top, 2)
                    .padding(.trailing, 4)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.6).combined(with: .opacity),
                            removal: .opacity.combined(with: .offset(y: -12))
                        )
                    )
                    .id(flash.id)
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.35), value: session.flash)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The big number. Rolls digits on change and gives a quick pulse + glow.
struct ScoreNumber: View {
    let text: String
    let color: Color
    let bump: Int
    let fontSize: CGFloat

    @Environment(\.theme) private var theme

    private struct Pulse {
        var scale: Double = 1
        var glow: Double = 0
    }

    var body: some View {
        // Read outside the animator's closure, which isn't main-actor isolated.
        let glow = theme.glow
        return Text(text)
            .font(.score(fontSize))
            .foregroundStyle(theme.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .contentTransition(.numericText())
            .animation(.snappy(duration: 0.28), value: text)
            .keyframeAnimator(initialValue: Pulse(), trigger: bump) { content, pulse in
                content
                    .scaleEffect(pulse.scale)
                    .shadow(
                        color: color.opacity((0.28 + pulse.glow) * glow),
                        radius: fontSize * 0.12
                    )
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.09, duration: 0.11, spring: .snappy)
                    SpringKeyframe(1.0, duration: 0.42, spring: .bouncy)
                }
                KeyframeTrack(\.glow) {
                    LinearKeyframe(0.45, duration: 0.08)
                    LinearKeyframe(0, duration: 0.5)
                }
            }
    }
}

struct ScoreButtonRow: View {
    let actions: [ScoreAction]
    /// nil hides the subtract button (tennis, boxing).
    let subtract: Int?
    let tint: Color
    let compact: Bool
    let onAdd: (Int) -> Void
    let onSubtract: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if let subtract {
                Button(action: onSubtract) {
                    Text("−\(subtract)")
                        .font(.system(size: compact ? 18 : 20, weight: .bold).monospacedDigit())
                }
                .buttonStyle(ScoreButtonStyle(tint: tint, prominent: false))
                .frame(maxWidth: actions.count > 2 ? 62 : .infinity)
                .accessibilityLabel("Subtract \(subtract)")
            }

            ForEach(actions) { action in
                Button {
                    onAdd(action.points)
                } label: {
                    VStack(spacing: 1) {
                        Text(action.title)
                            .font(.system(size: compact ? 19 : 22, weight: .bold).monospacedDigit())
                        if actions.count > 1 && action.label == nil {
                            Text(action.caption.uppercased())
                                .font(.boardLabel(8.5))
                                .tracking(0.5)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .opacity(0.8)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .buttonStyle(ScoreButtonStyle(tint: tint))
                .accessibilityLabel(action.label == nil ? "Add \(action.points), \(action.caption)" : "\(action.title) \(action.caption)")
            }
        }
    }
}

/// Fouls, timeouts and similar tallies. Tap for the common action; long-press for the rest.
struct CounterChip: View {
    let spec: TeamCounterSpec
    let value: Int
    let onTap: () -> Void
    let onReverse: () -> Void
    let onReset: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                // Past the threshold (team fouls → BONUS) the label itself changes and the chip
                // lights up, so it stays as compact as the plain chip.
                Text(highlightLabel ?? spec.shortTitle)
                    .font(.boardLabel(10))
                    .tracking(1)
                    .foregroundStyle(highlightLabel == nil ? theme.secondaryText : theme.onClock)

                switch spec.style {
                case .number:
                    Text("\(value)")
                        .font(.system(size: 16, weight: .bold).monospacedDigit())
                        .foregroundStyle(highlightLabel == nil ? theme.primaryText : theme.onClock)
                        .contentTransition(.numericText(value: Double(value)))
                case .dots:
                    HStack(spacing: 3) {
                        ForEach(0..<spec.range.upperBound, id: \.self) { index in
                            Circle()
                                .fill(index < value ? theme.clock : theme.tertiaryText.opacity(0.35))
                                .frame(width: 7, height: 7)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Capsule().fill(highlightLabel == nil ? theme.control : theme.clock))
            .overlay(Capsule().strokeBorder(theme.controlStroke))
            .animation(.snappy(duration: 0.25), value: value)
        }
        .buttonStyle(PressableStyle(scale: 0.92))
        .contextMenu {
            let forward: String = spec.tapDelta > 0 ? "Add One" : "Use One"
            let backward: String = spec.tapDelta > 0 ? "Remove One" : "Give One Back"
            Button(forward, systemImage: "plus.circle", action: onTap)
            Button(backward, systemImage: "minus.circle", action: onReverse)
            Button("Reset", systemImage: "arrow.counterclockwise", action: onReset)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spec.title)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(spec.tapDelta > 0 ? "Double-tap to add one." : "Double-tap to use one.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onTap() }
        .accessibilityAdjustableAction { direction in
            let increasing = direction == .increment
            if increasing == (spec.tapDelta > 0) { onTap() } else { onReverse() }
        }
    }

    private var highlightLabel: String? {
        guard let threshold = spec.highlightAt, value >= threshold else { return nil }
        return spec.highlightLabel
    }

    private var accessibilityValue: String {
        if let threshold = spec.highlightAt, value >= threshold, let label = spec.highlightLabel {
            return "\(value), \(label.lowercased())"
        }
        return "\(value)"
    }
}
