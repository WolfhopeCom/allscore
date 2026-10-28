import Foundation

/// Darts cricket (standard rules): each player closes 20, 19, 18, 17, 16, 15 and the bull
/// by hitting each three times (single = 1 mark, double = 2, triple = 3; outer bull = 1,
/// inner bull = 2). Hits on a number you've closed and your opponent hasn't score its value
/// (bull 25). First to close everything with an equal or higher score wins.
struct CricketDartsRules: SportRules {
    let kind = SportKind.darts
    let name = "Darts"
    let symbolName = "target"
    let summary = "Cricket · 15–20 & Bull"

    var defaults: SportDefaults {
        SportDefaults(
            teamA: TeamConfig(name: "Player 1", color: .red),
            teamB: TeamConfig(name: "Player 2", color: .green),
            periodLength: 10 * 60,
            periodCount: 1,
            overtimeLength: 5 * 60,
            clockEnabled: false
        )
    }

    let periodName = "Round"
    let allowsOvertime = false
    let model = ScoringModel.cricket
    let allowsSubtract = false
    let scoringActions: [ScoreAction] = []
    let warningThreshold: TimeInterval? = nil

    func periodLabel(_ period: Int, regulation: Int) -> String { "RD \(period)" }
    func periodTitle(_ period: Int, regulation: Int) -> String { "Round \(period)" }
    func breakTitle(after period: Int, regulation: Int) -> String { "End of Round \(period)" }
}

/// The cricket board's targets, top to bottom.
enum Cricket {
    static let targets = [20, 19, 18, 17, 16, 15, 25]
    static let bullIndex = 6
    static let marksToClose = 3

    static func label(_ index: Int) -> String {
        index == bullIndex ? "BULL" : "\(targets[index])"
    }

    /// The player owning these marks has closed every target.
    static func closedAll(_ marks: [Int]) -> Bool {
        marks.allSatisfy { $0 >= marksToClose }
    }
}

extension GameSession {
    /// Whose turn it is.
    var cricketThrower: TeamSide { state.possession ?? .a }

    var dartsLeftThisTurn: Int { max(0, 3 - state.match.dartsThrown) }

    func cricketMarks(_ side: TeamSide, _ index: Int) -> Int {
        state.match.marks[side.rawValue][index]
    }

    /// Both players have closed it, so nobody can score there any more.
    func isDead(_ index: Int) -> Bool {
        cricketMarks(.a, index) >= Cricket.marksToClose && cricketMarks(.b, index) >= Cricket.marksToClose
    }

    /// One dart for the player who's up. `multiplier` is 1 (single / outer bull),
    /// 2 (double / inner bull) or 3 (triple; there's no triple bull).
    func throwDart(at index: Int, multiplier: Int) {
        guard model == .cricket, state.phase != .final,
              Cricket.targets.indices.contains(index), (1...3).contains(multiplier),
              !(index == Cricket.bullIndex && multiplier == 3)
        else {
            environment.feedback(.denied)
            return
        }
        let side = cricketThrower
        let value = Cricket.targets[index]
        let cap = maxScore
        let limit = undoLimit
        var points = 0
        var closedNumber = false
        var won = false
        update { s in
            s.pushUndo(limit: limit)
            if s.phase == .pregame { s.phase = .live }
            let mine = side.rawValue
            let theirs = side.opponent.rawValue
            let before = s.match.marks[mine][index]
            let total = before + multiplier
            // Marks past the third score, but only while the opponent still has it open.
            let extra = max(0, total - max(before, Cricket.marksToClose))
            if s.match.marks[theirs][index] < Cricket.marksToClose {
                points = extra * value
            }
            closedNumber = before < Cricket.marksToClose && total >= Cricket.marksToClose
            s.match.marks[mine][index] = min(total, Cricket.marksToClose)
            s.scores[mine] = min(s.scores[mine] + points, cap)
            s.match.dartsThrown += 1
            if Cricket.closedAll(s.match.marks[mine]) && s.scores[mine] >= s.scores[theirs] {
                won = true
                s.declaredWinner = side
                s.phase = .final
            } else if s.match.dartsThrown >= 3 {
                Self.passTurn(&s)
            }
        }
        if points > 0 {
            bumpScore(side)
            showFlash(side: side, text: "+\(points)", isPositive: true)
        }
        if won {
            completeGame(playSound: true)
        } else if closedNumber {
            environment.feedback(.score(3))
        } else {
            environment.feedback(points > 0 ? .score(2) : .tap)
        }
    }

    /// A dart that missed every target still uses up a throw.
    func throwMiss() {
        guard model == .cricket, state.phase != .final else { return }
        let limit = undoLimit
        update { s in
            s.pushUndo(limit: limit)
            if s.phase == .pregame { s.phase = .live }
            s.match.dartsThrown += 1
            if s.match.dartsThrown >= 3 { Self.passTurn(&s) }
        }
        environment.feedback(.tap)
    }

    /// Ends the turn early (bounce-outs, a player done throwing).
    func endCricketTurn() {
        guard model == .cricket, state.phase != .final else { return }
        let limit = undoLimit
        update { s in
            s.pushUndo(limit: limit)
            if s.phase == .pregame { s.phase = .live }
            Self.passTurn(&s)
        }
        environment.feedback(.possession)
    }

    /// Hands the board over; a new round starts when it comes back to the first player.
    nonisolated static func passTurn(_ s: inout GameState) {
        s.match.dartsThrown = 0
        let next = (s.possession ?? .a).opponent
        s.possession = next
        if next == .a { s.period += 1 }
    }
}
