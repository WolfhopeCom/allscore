import Foundation

/// Baseball / softball: runs, innings (top & bottom), outs, balls and strikes, hits and errors.
/// The visiting team is listed first and bats in the top of each inning.
struct BaseballRules: SportRules {
    let kind = SportKind.baseball
    let name = "Baseball"
    let symbolName = "baseball.fill"
    let summary = "Innings · Count · Outs"

    var defaults: SportDefaults {
        SportDefaults(
            teamA: TeamConfig(name: "Away", color: .blue),
            teamB: TeamConfig(name: "Home", color: .red),
            periodLength: 10 * 60,
            periodCount: 9,
            overtimeLength: 5 * 60,
            clockEnabled: false
        )
    }

    let periodName = "Inning"
    let overtimeName = "Extra Innings"
    let periodCountOptions = [3, 4, 5, 6, 7, 9]
    let warningThreshold: TimeInterval? = nil

    let model = ScoringModel.baseball
    let allowsSwapSides = false

    let scoringActions = [ScoreAction(points: 1, caption: "Run")]

    let counters = [
        TeamCounterSpec(
            id: "hits", title: "Hits", shortTitle: "H", initialValue: 0, range: 0...99,
            tapDelta: 1, reset: .never, style: .number, highlightAt: nil, highlightLabel: nil
        ),
        TeamCounterSpec(
            id: "errors", title: "Errors", shortTitle: "E", initialValue: 0, range: 0...99,
            tapDelta: 1, reset: .never, style: .number, highlightAt: nil, highlightLabel: nil
        )
    ]

    let tracksPossession = true
    let possessionName = "At Bat"
    let showsPossessionControl = false

    func periodLabel(_ period: Int, regulation: Int) -> String { "\(period)" }
    func periodTitle(_ period: Int, regulation: Int) -> String { "\(Ordinal.string(period)) Inning" }
}

/// Boxing / MMA: timed rounds, rest between rounds, 10-point-must scorecards, stoppages.
struct BoxingRules: SportRules {
    let kind = SportKind.boxing
    let name = "Boxing / MMA"
    let symbolName = "figure.boxing"
    let summary = "Rounds · Rest timer · Scorecards"

    var defaults: SportDefaults {
        SportDefaults(
            teamA: TeamConfig(name: "Red Corner", color: .red),
            teamB: TeamConfig(name: "Blue Corner", color: .blue),
            periodLength: 3 * 60,
            periodCount: 3,
            overtimeLength: 60,
            clockEnabled: true,
            restLength: 60
        )
    }

    let periodName = "Round"
    var periodCountOptions: [Int] { Array(1...12) }
    let allowsOvertime = false
    let clockDirection = ClockDirection.countDown
    let warningThreshold: TimeInterval? = 10

    let model = ScoringModel.combat
    let allowsSubtract = false
    let stoppageMethods = ["KO/TKO"]
    let scoreCaption: String? = "Scorecard"

    let scoringActions = [
        ScoreAction(points: 1, caption: "Round", label: "10-9"),
        ScoreAction(points: 2, caption: "Round", label: "10-8")
    ]

    func periodTitle(_ period: Int, regulation: Int) -> String { "Round \(period)" }

    func breakTitle(after period: Int, regulation: Int) -> String {
        "End of Round \(period)"
    }
}
