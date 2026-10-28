import Foundation

/// Darts cricket, kept simple: each team closes 20, 19, 18, 17, 16, 15 and the bull by
/// marking each three times. No points and no turn order: tap either team's column for
/// every hit. The first team to close all seven wins.
struct CricketDartsRules: SportRules {
    let kind = SportKind.darts
    let name = "Darts"
    let symbolName = "target"
    let summary = "Cricket · Close 15–20 & Bull"

    var defaults: SportDefaults {
        SportDefaults(
            teamA: TeamConfig(name: "Team 1", color: .red),
            teamB: TeamConfig(name: "Team 2", color: .green),
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
    func cricketMarks(_ side: TeamSide, _ index: Int) -> Int {
        state.match.marks[side.rawValue][index]
    }

    /// Both teams have closed it.
    func isDead(_ index: Int) -> Bool {
        cricketMarks(.a, index) >= Cricket.marksToClose && cricketMarks(.b, index) >= Cricket.marksToClose
    }

    /// How many of the seven numbers a team has closed (shown as its score).
    func closedCount(_ side: TeamSide) -> Int {
        state.match.marks[side.rawValue].filter { $0 >= Cricket.marksToClose }.count
    }

    /// One hit for a team on a number. Three hits close it; closing all seven wins.
    func addMark(_ side: TeamSide, at index: Int) {
        guard model == .cricket, state.phase != .final,
              Cricket.targets.indices.contains(index),
              cricketMarks(side, index) < Cricket.marksToClose
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
            let row = side.rawValue
            s.match.marks[row][index] += 1
            if s.match.marks[row][index] >= Cricket.marksToClose {
                closedNumber = true
                s.scores[row] = s.match.marks[row].filter { $0 >= Cricket.marksToClose }.count
                if Cricket.closedAll(s.match.marks[row]) {
                    won = true
                    s.declaredWinner = side
                    s.phase = .final
                }
            }
        }
        if closedNumber { bumpScore(side) }
        if won {
            completeGame(playSound: true)
        } else {
            environment.feedback(closedNumber ? .score(3) : .tap)
        }
    }
}
