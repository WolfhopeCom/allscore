import Foundation

/// Cornhole with cancellation scoring: during an inning each team taps +1 for a bag on the
/// board and +3 for a bag in the hole. "End Inning" cancels the two tallies against each
/// other and only the difference counts, for the team that threw better. First team to
/// reach the target (21 by default) at the end of an inning wins.
struct CornholeRules: SportRules {
    let kind = SportKind.cornhole
    let name = "Cornhole"
    let symbolName = "circle.square.fill"
    let summary = "Cancellation scoring · To 21"

    /// Four bags a side, three points each at most.
    static let maxInningPoints = 12

    var defaults: SportDefaults {
        SportDefaults(
            teamA: TeamConfig(name: "Blue", color: .blue),
            teamB: TeamConfig(name: "Red", color: .red),
            periodLength: 10 * 60,
            periodCount: 1,
            overtimeLength: 5 * 60,
            clockEnabled: false,
            pointsToWin: 21
        )
    }

    let periodName = "Inning"
    let allowsOvertime = false
    let model = ScoringModel.cancellation

    let scoringActions = [
        ScoreAction(points: 1, caption: "On the Board"),
        ScoreAction(points: 3, caption: "In the Hole")
    ]
    let tapPoints = 1

    func periodLabel(_ period: Int, regulation: Int) -> String { "INN \(period)" }
    func periodTitle(_ period: Int, regulation: Int) -> String { "\(Ordinal.string(period)) Inning" }
    func breakTitle(after period: Int, regulation: Int) -> String { "End of Inning \(period)" }
}
