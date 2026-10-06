import Foundation

/// The reference sport: quarters (or halves), tenths under a minute, team fouls with a
/// bonus marker, and a possession arrow.
struct BasketballRules: SportRules {
    let kind = SportKind.basketball
    let name = "Basketball"
    let symbolName = "basketball.fill"
    let summary = "Quarters · Fouls · Possession"

    let usesHalves: Bool

    init(periodCount: Int = 4) {
        usesHalves = periodCount == 2
    }

    var defaults: SportDefaults {
        SportDefaults(
            teamA: TeamConfig(name: "Home", color: .orange),
            teamB: TeamConfig(name: "Away", color: .blue),
            periodLength: 12 * 60,
            periodCount: 4,
            overtimeLength: 5 * 60
        )
    }

    var periodName: String { usesHalves ? "Half" : "Quarter" }
    var periodNamePlural: String { usesHalves ? "Halves" : "Quarters" }
    let periodCountOptions = [2, 4]

    let clockDirection = ClockDirection.countDown
    let showsTenths = true
    let warningThreshold: TimeInterval? = 10

    let scoringActions = [
        ScoreAction(points: 1, caption: "Free Throw"),
        ScoreAction(points: 2, caption: "Field Goal"),
        ScoreAction(points: 3, caption: "Three")
    ]
    let tapPoints = 2

    let counters = [
        TeamCounterSpec(
            id: "fouls",
            title: "Team Fouls",
            shortTitle: "FOULS",
            initialValue: 0,
            range: 0...20,
            tapDelta: 1,
            reset: .everyPeriod,
            style: .number,
            highlightAt: 5,
            highlightLabel: "BONUS"
        )
    ]

    let tracksPossession = true
}
