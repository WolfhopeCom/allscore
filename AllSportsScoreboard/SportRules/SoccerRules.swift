import Foundation

/// Soccer uses a count-up match clock that runs into stoppage time and continues across
/// halves (the second half starts at 45:00), with extra time as the overtime periods.
struct SoccerRules: SportRules {
    let kind = SportKind.soccer
    let name = "Soccer"
    let symbolName = "soccerball"
    let summary = "Halves · Stoppage · Extra time"

    var defaults: SportDefaults {
        SportDefaults(
            teamA: TeamConfig(name: "Home", color: .green),
            teamB: TeamConfig(name: "Away", color: .silver),
            periodLength: 45 * 60,
            periodCount: 2,
            overtimeLength: 15 * 60
        )
    }

    let periodName = "Half"
    let periodNamePlural = "Halves"
    let overtimeName = "Extra Time"

    let clockDirection = ClockDirection.countUp
    let clockRunsPastLength = true
    let continuousMatchClock = true
    let warningThreshold: TimeInterval? = nil

    let scoringActions = [ScoreAction(points: 1, caption: "Goal")]

    func periodLabel(_ period: Int, regulation: Int) -> String {
        if period <= regulation {
            return "\(Ordinal.string(period).uppercased()) HALF"
        }
        return "ET \(period - regulation)"
    }

    func periodTitle(_ period: Int, regulation: Int) -> String {
        if period <= regulation {
            return "\(Ordinal.string(period)) Half"
        }
        return "Extra Time \(period - regulation)"
    }

    func breakTitle(after period: Int, regulation: Int) -> String {
        if regulation > 1, period == regulation / 2, regulation % 2 == 0 { return "Halftime" }
        if period == regulation { return "Full Time" }
        if period > regulation { return "Extra Time Break" }
        return "End of \(periodTitle(period, regulation: regulation))"
    }
}
