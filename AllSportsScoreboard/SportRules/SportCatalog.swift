import Foundation

/// Maps a sport (and its config) to its rules, and builds factory-default configs.
enum SportCatalog {
    /// Sports shown on the home screen, in order.
    static let all: [SportKind] = [
        .basketball, .football, .soccer, .hockey, .baseball, .volleyball,
        .tennis, .tableTennis, .badminton, .pickleball, .boxing, .wrestling, .bucketGolf, .custom
    ]

    static func rules(for config: GameConfig) -> any SportRules {
        switch config.sport {
        case .basketball: return BasketballRules(periodCount: config.periodCount)
        case .football: return FootballRules()
        case .soccer: return SoccerRules()
        case .hockey: return HockeyRules()
        case .baseball: return BaseballRules()
        case .volleyball: return VolleyballRules(config: config)
        case .tennis: return TennisRules()
        case .tableTennis: return TableTennisRules(config: config)
        case .badminton: return BadmintonRules(config: config)
        case .pickleball: return PickleballRules(config: config)
        case .boxing: return BoxingRules()
        case .wrestling: return WrestlingRules()
        case .bucketGolf: return BucketGolfRules()
        case .custom: return CustomRules(config: config)
        }
    }

    /// Sports with their own multi-player screen instead of the two-sided scoreboard.
    static func isPlayerGame(_ sport: SportKind) -> Bool { sport == .bucketGolf }

    static func rules(for sport: SportKind) -> any SportRules {
        rules(for: defaultConfig(for: sport))
    }

    static func defaultConfig(for sport: SportKind) -> GameConfig {
        let defaults: SportDefaults
        switch sport {
        case .basketball: defaults = BasketballRules().defaults
        case .football: defaults = FootballRules().defaults
        case .soccer: defaults = SoccerRules().defaults
        case .hockey: defaults = HockeyRules().defaults
        case .baseball: defaults = BaseballRules().defaults
        case .volleyball: defaults = VolleyballRules().defaults
        case .tennis: defaults = TennisRules().defaults
        case .tableTennis: defaults = TableTennisRules().defaults
        case .badminton: defaults = BadmintonRules().defaults
        case .pickleball: defaults = PickleballRules().defaults
        case .boxing: defaults = BoxingRules().defaults
        case .wrestling: defaults = WrestlingRules().defaults
        case .bucketGolf: defaults = BucketGolfRules().defaults
        case .custom: defaults = CustomRules.standardDefaults
        }
        return GameConfig(
            sport: sport,
            teamA: defaults.teamA,
            teamB: defaults.teamB,
            periodLength: defaults.periodLength,
            periodCount: defaults.periodCount,
            overtimeLength: defaults.overtimeLength,
            clockEnabled: defaults.clockEnabled,
            customTitle: "Custom",
            customPeriodName: "Period",
            customIncrement: 1,
            customClockDirection: .countDown,
            pointsToWin: defaults.pointsToWin,
            restLength: defaults.restLength,
            doubles: defaults.doubles,
            rallyScoring: defaults.rallyScoring
        )
    }
}
