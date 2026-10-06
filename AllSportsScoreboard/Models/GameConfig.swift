import Foundation

struct TeamConfig: Codable, Equatable {
    var name: String
    var color: TeamColor
}

/// Everything chosen before a game starts. Saved per sport as the user's defaults,
/// and embedded in every game so a game always knows its own rules.
struct GameConfig: Codable, Equatable {
    var sport: SportKind
    var teamA: TeamConfig
    var teamB: TeamConfig
    /// Length of one regulation period (or round), in seconds.
    var periodLength: TimeInterval
    /// Regulation periods. For set-based sports this is "best of".
    var periodCount: Int
    var overtimeLength: TimeInterval
    var clockEnabled: Bool

    // Custom scoreboards only.
    var customTitle: String
    var customPeriodName: String
    var customIncrement: Int
    var customClockDirection: ClockDirection

    /// Points needed to win a set or game (volleyball, table tennis, badminton).
    var pointsToWin: Int
    /// Rest between rounds (boxing / MMA), in seconds. 0 = no rest timer.
    var restLength: TimeInterval
    /// Pickleball: doubles uses server 1 / server 2.
    var doubles: Bool
    /// Pickleball: every rally scores, instead of traditional side-out scoring.
    var rallyScoring: Bool

    init(
        sport: SportKind,
        teamA: TeamConfig,
        teamB: TeamConfig,
        periodLength: TimeInterval,
        periodCount: Int,
        overtimeLength: TimeInterval,
        clockEnabled: Bool,
        customTitle: String,
        customPeriodName: String,
        customIncrement: Int,
        customClockDirection: ClockDirection,
        pointsToWin: Int,
        restLength: TimeInterval,
        doubles: Bool = true,
        rallyScoring: Bool = false
    ) {
        self.sport = sport
        self.teamA = teamA
        self.teamB = teamB
        self.periodLength = periodLength
        self.periodCount = periodCount
        self.overtimeLength = overtimeLength
        self.clockEnabled = clockEnabled
        self.customTitle = customTitle
        self.customPeriodName = customPeriodName
        self.customIncrement = customIncrement
        self.customClockDirection = customClockDirection
        self.pointsToWin = pointsToWin
        self.restLength = restLength
        self.doubles = doubles
        self.rallyScoring = rallyScoring
    }

    subscript(team side: TeamSide) -> TeamConfig {
        get { side == .a ? teamA : teamB }
        set {
            if side == .a { teamA = newValue } else { teamB = newValue }
        }
    }

    /// Display name with a sensible fallback when the field was left empty.
    func teamName(_ side: TeamSide) -> String {
        let trimmed = self[team: side].name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let fallback = SportCatalog.defaultConfig(for: sport)[team: side].name
        return fallback.isEmpty ? (side == .a ? "Home" : "Away") : fallback
    }

    /// Clamps values that could have come from an older or damaged save.
    func sanitized() -> GameConfig {
        var copy = self
        copy.periodLength = min(max(copy.periodLength, 15), 120 * 60)
        copy.periodCount = min(max(copy.periodCount, 1), 15)
        copy.overtimeLength = min(max(copy.overtimeLength, 15), 60 * 60)
        copy.customIncrement = min(max(copy.customIncrement, 1), 100)
        copy.pointsToWin = min(max(copy.pointsToWin, 1), 99)
        copy.restLength = min(max(copy.restLength, 0), 10 * 60)
        return copy
    }
}

extension GameConfig {
    private enum CodingKeys: String, CodingKey {
        case sport, teamA, teamB, periodLength, periodCount, overtimeLength, clockEnabled
        case customTitle, customPeriodName, customIncrement, customClockDirection
        case pointsToWin, restLength, doubles, rallyScoring
    }

    /// Tolerant decoding: fields added in later versions fall back to the sport's defaults,
    /// so saved games and preferences survive app updates.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let sport = try c.decode(SportKind.self, forKey: .sport)
        let base = SportCatalog.defaultConfig(for: sport)
        self.init(
            sport: sport,
            teamA: try c.decodeIfPresent(TeamConfig.self, forKey: .teamA) ?? base.teamA,
            teamB: try c.decodeIfPresent(TeamConfig.self, forKey: .teamB) ?? base.teamB,
            periodLength: try c.decodeIfPresent(TimeInterval.self, forKey: .periodLength) ?? base.periodLength,
            periodCount: try c.decodeIfPresent(Int.self, forKey: .periodCount) ?? base.periodCount,
            overtimeLength: try c.decodeIfPresent(TimeInterval.self, forKey: .overtimeLength) ?? base.overtimeLength,
            clockEnabled: try c.decodeIfPresent(Bool.self, forKey: .clockEnabled) ?? base.clockEnabled,
            customTitle: try c.decodeIfPresent(String.self, forKey: .customTitle) ?? base.customTitle,
            customPeriodName: try c.decodeIfPresent(String.self, forKey: .customPeriodName) ?? base.customPeriodName,
            customIncrement: try c.decodeIfPresent(Int.self, forKey: .customIncrement) ?? base.customIncrement,
            customClockDirection: try c.decodeIfPresent(ClockDirection.self, forKey: .customClockDirection) ?? base.customClockDirection,
            pointsToWin: try c.decodeIfPresent(Int.self, forKey: .pointsToWin) ?? base.pointsToWin,
            restLength: try c.decodeIfPresent(TimeInterval.self, forKey: .restLength) ?? base.restLength,
            doubles: try c.decodeIfPresent(Bool.self, forKey: .doubles) ?? base.doubles,
            rallyScoring: try c.decodeIfPresent(Bool.self, forKey: .rallyScoring) ?? base.rallyScoring
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(sport, forKey: .sport)
        try c.encode(teamA, forKey: .teamA)
        try c.encode(teamB, forKey: .teamB)
        try c.encode(periodLength, forKey: .periodLength)
        try c.encode(periodCount, forKey: .periodCount)
        try c.encode(overtimeLength, forKey: .overtimeLength)
        try c.encode(clockEnabled, forKey: .clockEnabled)
        try c.encode(customTitle, forKey: .customTitle)
        try c.encode(customPeriodName, forKey: .customPeriodName)
        try c.encode(customIncrement, forKey: .customIncrement)
        try c.encode(customClockDirection, forKey: .customClockDirection)
        try c.encode(pointsToWin, forKey: .pointsToWin)
        try c.encode(restLength, forKey: .restLength)
        try c.encode(doubles, forKey: .doubles)
        try c.encode(rallyScoring, forKey: .rallyScoring)
    }
}
