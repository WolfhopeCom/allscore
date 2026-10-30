import Foundation

/// Darts cricket, kept simple: 2–4 players each close 20, 19, 18, 17, 16, 15 and the bull
/// by marking each three times. No points and no turn order: tap any player's column for
/// every hit. The first to close all seven wins.
struct CricketDartsRules: SportRules {
    let kind = SportKind.darts
    let name = "Darts"
    let symbolName = "target"
    let summary = "Cricket · Close 15–20 & Bull"

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

    let periodName = "Game"
    let allowsOvertime = false
    let model = ScoringModel.cricket
    let allowsSubtract = false
    let scoringActions: [ScoreAction] = []
    let warningThreshold: TimeInterval? = nil
    let scoreCaption: String? = "Closed"
    let allowsSwapSides = false
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
    var cricketPlayerCount: Int { state.match.marks.count }
    func cricketName(_ player: Int) -> String { config.playerName(player) }
    func cricketColor(_ player: Int) -> TeamColor { config.playerColor(player) }
    var cricketWinner: Int? { state.match.cricketWinner }

    func cricketMarks(_ player: Int, _ index: Int) -> Int {
        let marks = state.match.marks
        guard marks.indices.contains(player), marks[player].indices.contains(index) else { return 0 }
        return marks[player][index]
    }

    /// Every player has closed it.
    func isDead(_ index: Int) -> Bool {
        state.match.marks.allSatisfy { $0[index] >= Cricket.marksToClose }
    }

    /// How many of the seven numbers a player has closed (shown as their score).
    func closedCount(_ player: Int) -> Int {
        guard state.match.marks.indices.contains(player) else { return 0 }
        return state.match.marks[player].filter { $0 >= Cricket.marksToClose }.count
    }

    /// One hit for a player on a number. Three hits close it; closing all seven wins.
    func addMark(_ player: Int, at index: Int) {
        guard model == .cricket, state.phase != .final,
              state.match.marks.indices.contains(player),
              Cricket.targets.indices.contains(index),
              cricketMarks(player, index) < Cricket.marksToClose
        else {
            environment.feedback(.denied)
            return
        }
        let limit = undoLimit
        var closedNumber = false
        var won = false
        update { s in
            s.pushUndo(limit: limit)
            if s.phase == .pregame { s.phase = .live }
            s.match.marks[player][index] += 1
            if s.match.marks[player][index] >= Cricket.marksToClose {
                closedNumber = true
                if player < 2 {
                    s.scores[player] = s.match.marks[player].filter { $0 >= Cricket.marksToClose }.count
                }
                if Cricket.closedAll(s.match.marks[player]) {
                    won = true
                    s.match.cricketWinner = player
                    s.declaredWinner = player < 2 ? TeamSide(rawValue: player) : nil
                    s.phase = .final
                }
            }
        }
        if closedNumber, player < 2, let side = TeamSide(rawValue: player) { bumpScore(side) }
        if won {
            completeGame(playSound: true)
        } else {
            environment.feedback(closedNumber ? .score(3) : .tap)
        }
    }

    /// Everyone's closed count, best first, for the final card and sharing.
    var cricketStandings: [Int] {
        (0..<cricketPlayerCount).sorted { a, b in
            if a == cricketWinner { return true }
            if b == cricketWinner { return false }
            let ca = closedCount(a), cb = closedCount(b)
            return ca != cb ? ca > cb : a < b
        }
    }
}
