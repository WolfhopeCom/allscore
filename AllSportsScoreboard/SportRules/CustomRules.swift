import Foundation

/// A user-defined scoreboard: its own title, points per tap, period name, clock on or off,
/// and counting direction. Built from the game's config.
struct CustomRules: SportRules {
    let kind = SportKind.custom
    let symbolName = "slider.horizontal.3"
    let summary = "Your scoring, timer & periods"

    let name: String
    let periodName: String
    let clockDirection: ClockDirection
    private let increment: Int

    init(config: GameConfig) {
        let title = config.customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let period = config.customPeriodName.trimmingCharacters(in: .whitespacesAndNewlines)
        name = title.isEmpty ? "Custom" : title
        periodName = period.isEmpty ? "Period" : period
        clockDirection = config.customClockDirection
        increment = max(1, config.customIncrement)
    }

    static var standardDefaults: SportDefaults {
        SportDefaults(
            teamA: TeamConfig(name: "Team A", color: .teal),
            teamB: TeamConfig(name: "Team B", color: .purple),
            periodLength: 10 * 60,
            periodCount: 2,
            overtimeLength: 5 * 60
        )
    }

    var defaults: SportDefaults { Self.standardDefaults }
    var periodCountOptions: [Int] { Array(1...9) }
    let allowsOvertime = false

    var warningThreshold: TimeInterval? { clockDirection == .countDown ? 10 : nil }

    var scoringActions: [ScoreAction] {
        if increment == 1 {
            return [ScoreAction(points: 1, caption: "Point")]
        }
        return [
            ScoreAction(points: increment, caption: "Score"),
            ScoreAction(points: 1, caption: "Point")
        ]
    }

    var tapPoints: Int { increment }
    var subtractPoints: Int { 1 }

    func periodLabel(_ period: Int, regulation: Int) -> String {
        "\(periodName.uppercased()) \(period)"
    }

    func periodTitle(_ period: Int, regulation: Int) -> String {
        "\(periodName) \(period)"
    }
}
