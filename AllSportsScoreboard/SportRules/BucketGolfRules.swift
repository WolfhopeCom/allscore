import Foundation

/// Describes BucketGolf on the home screen: stroke play, par 3 every hole, 1–8 players. The
/// round itself runs on `PlayerGameSession`, not the two-sided scoreboard.
struct BucketGolfRules: SportRules {
    let kind = SportKind.bucketGolf
    let name = "Bucket Golf"
    let symbolName = "figure.golf"
    let summary = "Stroke play · Par 3 · 1–8 players"

    var defaults: SportDefaults {
        SportDefaults(
            teamA: TeamConfig(name: "Player 1", color: .gold),
            teamB: TeamConfig(name: "Player 2", color: .teal),
            periodLength: 10 * 60,
            periodCount: 5,
            overtimeLength: 5 * 60,
            clockEnabled: false
        )
    }

    let periodName = "Round"
    let allowsOvertime = false
    let warningThreshold: TimeInterval? = nil
    let scoringActions = [ScoreAction(points: 1, caption: "Point")]
}
