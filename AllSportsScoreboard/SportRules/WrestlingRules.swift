import Foundation

/// Wrestling (folkstyle): three timed periods, takedown 3, escape 1, reversal 2, near fall
/// 2-4, technical fall at a 15-point lead, win by fall, and sudden-victory overtime.
struct WrestlingRules: SportRules {
    let kind = SportKind.wrestling
    let name = "Wrestling"
    let symbolName = "figure.wrestling"
    let summary = "Periods · Tech fall · Fall"

    var defaults: SportDefaults {
        SportDefaults(
            teamA: TeamConfig(name: "Red", color: .red),
            teamB: TeamConfig(name: "Green", color: .green),
            periodLength: 2 * 60,
            periodCount: 3,
            overtimeLength: 60
        )
    }

    let periodName = "Period"
    let clockDirection = ClockDirection.countDown
    let showsTenths = true
    let warningThreshold: TimeInterval? = 10
    let overtimeName = "Sudden Victory"

    let scoringActions = [
        ScoreAction(points: 1, caption: "Escape · Pen"),
        ScoreAction(points: 2, caption: "Reversal · NF2"),
        ScoreAction(points: 3, caption: "Takedown · NF3"),
        ScoreAction(points: 4, caption: "Near Fall 4")
    ]
    let tapPoints = 3

    let stoppageMethods = ["Fall"]
    let mercyMargin: Int? = 15
    let suddenVictoryOvertime = true

    func periodLabel(_ period: Int, regulation: Int) -> String {
        if period <= regulation { return "P\(period)" }
        let overtime = period - regulation
        return overtime == 1 ? "SV" : "SV\(overtime)"
    }
}
