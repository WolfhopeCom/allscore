import SwiftUI

/// The darts cricket scoreboard: each team's marks on either side of the numbers, like a
/// chalkboard at the bar. Tap a number in a team's column for every hit, in any order.
/// Three hits close a number; the first team to close all seven wins.
struct CricketBoard: View {
    let session: GameSession
    let landscape: Bool

    @Environment(\.theme) private var theme

    var body: some View {
        if landscape {
            // Fixed-width team panels so names and counts always fit; the numbers get the rest.
            GeometryReader { geometry in
                let panelWidth = min(240, max(150, geometry.size.width * 0.22))
                HStack(spacing: 12) {
                    teamPanel(.a)
                        .frame(width: panelWidth)
                    targetGrid
                        .frame(maxWidth: .infinity)
                    teamPanel(.b)
                        .frame(width: panelWidth)
                }
            }
        } else {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    teamPanel(.a)
                    teamPanel(.b)
                }
                .frame(height: 140)
                targetGrid
            }
        }
    }

    // MARK: - Teams

    private func teamPanel(_ side: TeamSide) -> some View {
        let color = theme.color(session.config[team: side].color)
        let closed = session.closedCount(side)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        return VStack(spacing: 6) {
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

            Spacer(minLength: 0)

            Text("\(closed)")
                .font(.score(landscape ? 72 : 56))
                .foregroundStyle(theme.primaryText)
                .contentTransition(.numericText())
                .shadow(color: color.opacity(0.3 * theme.glow), radius: 14)
                .animation(.snappy(duration: 0.3), value: closed)

            Text("OF 7 CLOSED")
                .font(.boardLabel(11))
                .tracking(1.6)
                .foregroundStyle(theme.secondaryText)

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(shape.fill(theme.panel))
        .overlay(shape.strokeBorder(theme.panelStroke))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(session.teamName(side)), \(closed) of 7 numbers closed")
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
            .accessibilityValue(dead ? "closed by both teams" : "")
    }

    private func markCell(_ side: TeamSide, _ index: Int) -> some View {
        let marks = session.cricketMarks(side, index)
        let isClosed = marks >= Cricket.marksToClose
        let playable = session.phase != .final && !isClosed
        let color = theme.color(session.config[team: side].color)

        return Button {
            session.addMark(side, at: index)
        } label: {
            MarkGlyph(marks: marks)
                .stroke(isClosed ? color : theme.primaryText, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .aspectRatio(1, contentMode: .fit)
                .padding(5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(playable ? theme.control : theme.control.opacity(0.4))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(playable ? theme.controlStroke : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.94))
        .disabled(!playable)
        .accessibilityLabel("\(session.teamName(side)), \(Cricket.label(index))")
        .accessibilityValue(isClosed ? "closed" : "\(marks) of 3 hits")
        .accessibilityHint(playable ? "Adds a hit" : "")
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
