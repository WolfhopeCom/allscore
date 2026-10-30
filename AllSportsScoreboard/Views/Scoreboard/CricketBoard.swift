import SwiftUI

/// The darts cricket chalkboard: players' columns either side of the numbers (2–4 players).
/// Tap a player's box on a number for every hit, in any order: / then X then circled X.
/// Three hits close a number; the first to close all seven wins.
struct CricketBoard: View {
    let session: GameSession
    let landscape: Bool

    @Environment(\.theme) private var theme

    private var count: Int { session.cricketPlayerCount }
    private var leftPlayers: [Int] { Array(0..<((count + 1) / 2)) }
    private var rightPlayers: [Int] { Array(((count + 1) / 2)..<count) }

    var body: some View {
        GeometryReader { geometry in
            let numberWidth = min(110, max(64, geometry.size.width * (landscape ? 0.13 : 0.2)))
            let headerHeight = min(landscape ? 70 : 92, geometry.size.height * 0.17)
            let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

            VStack(spacing: 1) {
                HStack(spacing: 1) {
                    ForEach(leftPlayers, id: \.self) { header($0) }
                    Rectangle().fill(theme.background).frame(width: numberWidth)
                    ForEach(rightPlayers, id: \.self) { header($0) }
                }
                .frame(height: headerHeight)

                ForEach(Cricket.targets.indices, id: \.self) { index in
                    HStack(spacing: 1) {
                        ForEach(leftPlayers, id: \.self) { markCell($0, index) }
                        numberCell(index).frame(width: numberWidth)
                        ForEach(rightPlayers, id: \.self) { markCell($0, index) }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .background(theme.panelStroke)
            .clipShape(shape)
            .overlay(shape.strokeBorder(theme.panelStroke))
        }
    }

    // MARK: - Players

    private func header(_ player: Int) -> some View {
        let closed = session.closedCount(player)
        let isWinner = session.cricketWinner == player
        let color = theme.color(session.cricketColor(player))

        return VStack(spacing: 2) {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(width: 3, height: 13)
                Text(session.cricketName(player))
                    .font(.system(size: landscape ? 15 : 16, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if isWinner {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.clock)
                }
            }
            .foregroundStyle(theme.primaryText)
            Text("\(closed)")
                .font(.score(landscape ? 30 : 36))
                .foregroundStyle(theme.primaryText)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.3), value: closed)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isWinner ? theme.clock.opacity(0.18) : theme.panel)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(session.cricketName(player)), \(closed) of 7 closed\(isWinner ? ", winner" : "")")
    }

    // MARK: - Numbers

    private func numberCell(_ index: Int) -> some View {
        let dead = session.isDead(index)
        return Text(index == Cricket.bullIndex ? "Bull" : Cricket.label(index))
            .font(index == Cricket.bullIndex ? .system(size: landscape ? 17 : 19, weight: .bold) : .score(landscape ? 24 : 28))
            .foregroundStyle(dead ? theme.tertiaryText : theme.primaryText)
            .strikethrough(dead, color: theme.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.background)
            .accessibilityLabel(index == Cricket.bullIndex ? "Bull" : Cricket.label(index))
            .accessibilityValue(dead ? "closed by everyone" : "")
    }

    private func markCell(_ player: Int, _ index: Int) -> some View {
        let marks = session.cricketMarks(player, index)
        let isClosed = marks >= Cricket.marksToClose
        let playable = session.phase != .final && !isClosed

        return Button {
            session.addMark(player, at: index)
        } label: {
            MarkGlyph(marks: marks)
                .stroke(theme.primaryText, style: StrokeStyle(lineWidth: landscape ? 3.5 : 4, lineCap: .round))
                .aspectRatio(1, contentMode: .fit)
                .padding(landscape ? 4 : 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(session.isDead(index) ? theme.panel.opacity(0.6) : theme.panel)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.96))
        .disabled(!playable)
        .accessibilityLabel("\(session.cricketName(player)), \(Cricket.label(index))")
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
