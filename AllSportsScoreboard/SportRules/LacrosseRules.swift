import Foundation

/// Lacrosse (field, high school style): four timed quarters, goals worth one, two timeouts
/// per half, and sudden-victory overtime where the first goal wins.
struct LacrosseRules: SportRules {
    let kind = SportKind.lacrosse
    let name = "Lacrosse"
    let symbolName = "figure.lacrosse"
    let summary = "Quarters · Timeouts · Sudden victory"

    let usesHalves: Bool

    init(periodCount: Int = 4) {
        usesHalves = periodCount == 2
    }

    var defaults: SportDefaults {
        SportDefaults(
            teamA: TeamConfig(name: "Home", color: .blue),
            teamB: TeamConfig(name: "Away", color: .orange),
            periodLength: 12 * 60,
            periodCount: 4,
            overtimeLength: 4 * 60
        )
    }

    var periodName: String { usesHalves ? "Half" : "Quarter" }
    var periodNamePlural: String { usesHalves ? "Halves" : "Quarters" }
    let periodCountOptions = [2, 4]
    let clockDirection = ClockDirection.countDown
    let showsTenths = true
    let warningThreshold: TimeInterval? = 10
    let overtimeName = "Sudden Victory"

    let scoringActions = [ScoreAction(points: 1, caption: "Goal")]

    let counters = [
        TeamCounterSpec(
            id: "timeouts",
            title: "Timeouts",
            shortTitle: "TOL",
            initialValue: 2,
            range: 0...2,
            tapDelta: -1,
            reset: .everyHalf,
            style: .dots,
            highlightAt: nil,
            highlightLabel: nil
        )
    ]

    let tracksPossession = true
    let possessionName = "Ball"
    let suddenVictoryOvertime = true

    func periodLabel(_ period: Int, regulation: Int) -> String {
        if period <= regulation { return "\(usesHalves ? "H" : "Q")\(period)" }
        let overtime = period - regulation
        return overtime == 1 ? "SV" : "SV\(overtime)"
    }
}
