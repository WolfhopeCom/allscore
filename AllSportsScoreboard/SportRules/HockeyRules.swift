import Foundation

struct HockeyRules: SportRules {
    let kind = SportKind.hockey
    let name = "Hockey"
    let symbolName = "hockey.puck.fill"
    let summary = "Periods · Overtime"

    var defaults: SportDefaults {
        SportDefaults(
            teamA: TeamConfig(name: "Home", color: .blue),
            teamB: TeamConfig(name: "Away", color: .red),
            periodLength: 20 * 60,
            periodCount: 3,
            overtimeLength: 5 * 60
        )
    }

    let periodName = "Period"
    let clockDirection = ClockDirection.countDown
    let showsTenths = true
    let warningThreshold: TimeInterval? = 10

    let scoringActions = [ScoreAction(points: 1, caption: "Goal")]

    func periodLabel(_ period: Int, regulation: Int) -> String {
        if period <= regulation {
            return Ordinal.string(period).uppercased()
        }
        let overtime = period - regulation
        return overtime == 1 ? "OT" : "\(overtime)OT"
    }
}
