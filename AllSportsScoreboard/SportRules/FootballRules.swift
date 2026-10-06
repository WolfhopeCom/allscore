import Foundation

struct FootballRules: SportRules {
    let kind = SportKind.football
    let name = "Football"
    let symbolName = "football.fill"
    let summary = "Quarters · Timeouts · Possession"

    var defaults: SportDefaults {
        SportDefaults(
            teamA: TeamConfig(name: "Home", color: .red),
            teamB: TeamConfig(name: "Away", color: .silver),
            periodLength: 12 * 60,
            periodCount: 4,
            overtimeLength: 10 * 60
        )
    }

    let periodName = "Quarter"
    let clockDirection = ClockDirection.countDown
    let warningThreshold: TimeInterval? = 10

    let scoringActions = [
        ScoreAction(points: 6, caption: "Touchdown"),
        ScoreAction(points: 3, caption: "Field Goal"),
        ScoreAction(points: 2, caption: "Safety / 2-Pt"),
        ScoreAction(points: 1, caption: "Extra Point")
    ]
    let tapPoints = 6

    let counters = [
        TeamCounterSpec(
            id: "timeouts",
            title: "Timeouts",
            shortTitle: "TOL",
            initialValue: 3,
            range: 0...3,
            tapDelta: -1,
            reset: .everyHalf,
            style: .dots,
            highlightAt: nil,
            highlightLabel: nil
        )
    ]

    let tracksPossession = true
    let possessionName = "Ball"
}
