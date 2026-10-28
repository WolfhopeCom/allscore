import SwiftUI

/// The darts cricket scoreboard: each player's marks on either side of the numbers, like a
/// chalkboard at the bar. Tap a number in the thrower's column for each dart; pick Double
/// or Triple first for those rings. Three darts and the turn passes automatically.
struct CricketBoard: View {
    let session: GameSession
    let landscape: Bool

    @Environment(\.theme) private var theme
    /// The ring for the next dart. Goes back to single after each throw.
    @State private var multiplier = 1

    var body: some View {
        if landscape {
            HStack(spacing: 12) {
                playerPanel(.a, showsInput: true)
                    .frame(maxWidth: .infinity)
                targetGrid
                    .frame(maxWidth: .infinity)
                    .layoutPriority(1)
                playerPanel(.b, showsInput: true)
                    .frame(maxWidth: .infinity)
            }
        } else {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    playerPanel(.a, showsInput: false)
                    playerPanel(.b, showsInput: false)
                }
                .frame(height: 132)
                targetGrid
                inputBar(enabled: session.phase != .final)
                    .frame(height: 52)
            }
        }
    }

    // MARK: - Players

    private func playerPanel(_ side: TeamSide, showsInput: Bool) -> some View {
        let isUp = session.cricketThrower == side && session.phase != .final
        let color = theme.color(session.config[team: side].color)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        return VStack(spacing: 8) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(width: 3, height: 16)
                Text(session.teamName(side).uppercased())
                    .font(.boardLabel(landscape ? 17 : 15))
                    .tracking(1.4)
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
            }

            Text(session.scoreText(side))
                .font(.score(landscape ? 64 : 48))
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .shadow(color: color.opacity(0.3 * theme.glow), radius: 14)
                .accessibilityLabel("\(session.teamName(side)), \(session.scoreText(side)) points")

            dartsLeft(isUp: isUp)

            if showsInput {
                Spacer(minLength: 0)
                inputGrid(enabled: isUp)
            }
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(shape.fill(theme.panel))
        .overlay(shape.strokeBorder(isUp ? theme.clock.opacity(0.7) : theme.panelStroke, lineWidth: isUp ? 2 : 1))
        .animation(.snappy(duration: 0.25), value: isUp)
    }

    /// Three dots for the darts still to throw this turn, shown only for the thrower.
    private func dartsLeft(isUp: Bool) -> some View {
        HStack(spacing: 6) {
            if isUp {
                ForEach(0..<3, id: \.self) { dart in
                    Circle()
                        .fill(dart < session.dartsLeftThisTurn ? theme.clock : theme.tertiaryText.opacity(0.35))
                        .frame(width: 9, height: 9)
                }
                Text("UP")
                    .font(.boardLabel(11))
                    .tracking(1.4)
                    .foregroundStyle(theme.clock)
            } else {
                Text(" ").font(.boardLabel(11))
            }
        }
        .frame(height: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isUp ? "Throwing, \(session.dartsLeftThisTurn) darts left" : "")
    }

    // MARK: - Ring and miss

    private func inputGrid(enabled: Bool) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ringButton("Double", value: 2, enabled: enabled)
                ringButton("Triple", value: 3, enabled: enabled)
            }
            missButton(enabled: enabled)
        }
    }

    private func inputBar(enabled: Bool) -> some View {
        HStack(spacing: 8) {
            ringButton("Double", value: 2, enabled: enabled)
            ringButton("Triple", value: 3, enabled: enabled)
            missButton(enabled: enabled)
        }
    }

    private func ringButton(_ title: String, value: Int, enabled: Bool) -> some View {
        let isOn = multiplier == value
        return Button {
            multiplier = isOn ? 1 : value
            Feedback.shared.play(.tap)
        } label: {
            Text(title.uppercased())
                .font(.boardLabel(13))
                .tracking(1.2)
                .foregroundStyle(isOn ? theme.onClock : theme.primaryText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(isOn ? theme.clock : theme.control))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(theme.controlStroke))
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityHint("Applies to the next dart")
    }

    private func missButton(enabled: Bool) -> some View {
        Button {
            multiplier = 1
            session.throwMiss()
        } label: {
            Text("MISS")
                .font(.boardLabel(13))
                .tracking(1.2)
                .foregroundStyle(theme.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(theme.control))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(theme.controlStroke))
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityHint("Records a dart that missed the cricket numbers")
    }

    // MARK: - Numbers

    private var targetGrid: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return VStack(spacing: 4) {
            ForEach(Cricket.targets.indices, id: \.self) { index in
                HStack(spacing: 6) {
                    markCell(.a, index)
                    targetLabel(index)
                    markCell(.b, index)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(8)
        .background(shape.fill(theme.panel))
        .overlay(shape.strokeBorder(theme.panelStroke))
    }

    private func targetLabel(_ index: Int) -> some View {
        let dead = session.isDead(index)
        return Text(Cricket.label(index))
            .font(index == Cricket.bullIndex ? .boardLabel(15) : .score(26))
            .foregroundStyle(dead ? theme.tertiaryText : theme.clock)
            .strikethrough(dead, color: theme.tertiaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: 64)
            .accessibilityLabel(index == Cricket.bullIndex ? "Bull" : Cricket.label(index))
            .accessibilityValue(dead ? "closed by both" : "")
    }

    private func markCell(_ side: TeamSide, _ index: Int) -> some View {
        let marks = session.cricketMarks(side, index)
        let isUp = session.cricketThrower == side && session.phase != .final
        let tripleBull = index == Cricket.bullIndex && multiplier == 3
        let enabled = isUp && !tripleBull
        let color = theme.color(session.config[team: side].color)

        return Button {
            session.throwDart(at: index, multiplier: multiplier)
            multiplier = 1
        } label: {
            MarkGlyph(marks: marks)
                .stroke(marks >= Cricket.marksToClose ? color : theme.primaryText, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .aspectRatio(1, contentMode: .fit)
                .padding(5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isUp ? theme.control : theme.control.opacity(0.4))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isUp ? theme.controlStroke : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.94))
        .disabled(!enabled)
        .accessibilityLabel("\(session.teamName(side)), \(Cricket.label(index))")
        .accessibilityValue(marks >= Cricket.marksToClose ? "closed" : "\(marks) of 3 marks")
        .accessibilityHint(isUp ? "Records a \(multiplier == 3 ? "triple" : multiplier == 2 ? "double" : "single") on \(Cricket.label(index))" : "")
    }
}

/// Classic chalkboard marks: one = slash, two = X, three = X in a circle.
struct MarkGlyph: Shape {
    let marks: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = rect.width * 0.2
        let box = rect.insetBy(dx: inset, dy: inset)
        if marks >= 1 {
            path.move(to: CGPoint(x: box.minX, y: box.maxY))
            path.addLine(to: CGPoint(x: box.maxX, y: box.minY))
        }
        if marks >= 2 {
            path.move(to: CGPoint(x: box.minX, y: box.minY))
            path.addLine(to: CGPoint(x: box.maxX, y: box.maxY))
        }
        if marks >= 3 {
            path.addEllipse(in: rect.insetBy(dx: rect.width * 0.06, dy: rect.height * 0.06))
        }
        return path
    }
}
