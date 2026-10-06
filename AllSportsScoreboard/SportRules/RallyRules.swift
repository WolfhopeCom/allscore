import Foundation

/// Volleyball: rally scoring to 25 (deciding set to 15), win by 2, winner serves.
struct VolleyballRules: SportRules {
    let kind = SportKind.volleyball
    let name = "Volleyball"
    let symbolName = "volleyball.fill"
    let summary = "Sets · Rally scoring · Serve"

    private let pointsToWin: Int

    init(config: GameConfig? = nil) {
        pointsToWin = config?.pointsToWin ?? 25
    }

    var defaults: SportDefaults {
        SportDefaults(
            teamA: TeamConfig(name: "Home", color: .gold),
            teamB: TeamConfig(name: "Away", color: .blue),
            periodLength: 10 * 60,
            periodCount: 5,
            overtimeLength: 5 * 60,
            clockEnabled: false,
            pointsToWin: 25
        )
    }

    let periodName = "Set"
    let periodCountOptions = [3, 5]
    let allowsOvertime = false
    let warningThreshold: TimeInterval? = nil

    let model = ScoringModel.rally
    var rallyFormat: RallyFormat? {
        RallyFormat(
            pointsToWin: pointsToWin,
            decidingSetPoints: min(15, pointsToWin),
            winBy: 2,
            cap: nil,
            serve: .winnerServes,
            nextSetServer: .alternate
        )
    }

    let scoringActions = [ScoreAction(points: 1, caption: "Point")]
    let tracksPossession = true
    let possessionName = "Serve"

    func periodLabel(_ period: Int, regulation: Int) -> String { "SET \(period)" }
    func periodTitle(_ period: Int, regulation: Int) -> String { "Set \(period)" }
}

/// Table tennis: games to 11, win by 2, serve changes every 2 points (every point at 10-10).
struct TableTennisRules: SportRules {
    let kind = SportKind.tableTennis
    let name = "Table Tennis"
    let symbolName = "figure.table.tennis"
    let summary = "Games to 11 · Serve rotation"

    private let pointsToWin: Int

    init(config: GameConfig? = nil) {
        pointsToWin = config?.pointsToWin ?? 11
    }

    var defaults: SportDefaults {
        SportDefaults(
            teamA: TeamConfig(name: "Player 1", color: .red),
            teamB: TeamConfig(name: "Player 2", color: .blue),
            periodLength: 10 * 60,
            periodCount: 5,
            overtimeLength: 5 * 60,
            clockEnabled: false,
            pointsToWin: 11
        )
    }

    let periodName = "Game"
    let periodCountOptions = [3, 5, 7]
    let allowsOvertime = false
    let warningThreshold: TimeInterval? = nil

    let model = ScoringModel.rally
    var rallyFormat: RallyFormat? {
        RallyFormat(
            pointsToWin: pointsToWin,
            decidingSetPoints: pointsToWin,
            winBy: 2,
            cap: nil,
            serve: .alternating(every: 2),
            nextSetServer: .alternate
        )
    }

    let scoringActions = [ScoreAction(points: 1, caption: "Point")]
    let tracksPossession = true
    let possessionName = "Serve"

    func periodLabel(_ period: Int, regulation: Int) -> String { "GAME \(period)" }
    func periodTitle(_ period: Int, regulation: Int) -> String { "Game \(period)" }
}

/// Badminton: games to 21, win by 2, capped at 30, winner serves.
struct BadmintonRules: SportRules {
    let kind = SportKind.badminton
    let name = "Badminton"
    let symbolName = "figure.badminton"
    let summary = "Games to 21 · Rally scoring"

    private let pointsToWin: Int

    init(config: GameConfig? = nil) {
        pointsToWin = config?.pointsToWin ?? 21
    }

    var defaults: SportDefaults {
        SportDefaults(
            teamA: TeamConfig(name: "Player 1", color: .green),
            teamB: TeamConfig(name: "Player 2", color: .purple),
            periodLength: 10 * 60,
            periodCount: 3,
            overtimeLength: 5 * 60,
            clockEnabled: false,
            pointsToWin: 21
        )
    }

    let periodName = "Game"
    let periodCountOptions = [1, 3]
    let allowsOvertime = false
    let warningThreshold: TimeInterval? = nil

    let model = ScoringModel.rally
    var rallyFormat: RallyFormat? {
        RallyFormat(
            pointsToWin: pointsToWin,
            decidingSetPoints: pointsToWin,
            winBy: 2,
            cap: pointsToWin + 9,
            serve: .winnerServes,
            nextSetServer: .previousWinner
        )
    }

    let scoringActions = [ScoreAction(points: 1, caption: "Point")]
    let tracksPossession = true
    let possessionName = "Serve"

    func periodLabel(_ period: Int, regulation: Int) -> String { "GAME \(period)" }
    func periodTitle(_ period: Int, regulation: Int) -> String { "Game \(period)" }
}

/// Tennis: 0-15-30-40, deuce and advantage, sets to 6 with a tiebreak at 6-6.
struct TennisRules: SportRules {
    let kind = SportKind.tennis
    let name = "Tennis"
    let symbolName = "tennis.racket"
    let summary = "15-30-40 · Sets · Tiebreaks"

    var defaults: SportDefaults {
        SportDefaults(
            teamA: TeamConfig(name: "Player 1", color: .gold),
            teamB: TeamConfig(name: "Player 2", color: .teal),
            periodLength: 10 * 60,
            periodCount: 3,
            overtimeLength: 5 * 60,
            clockEnabled: false
        )
    }

    let periodName = "Set"
    let periodCountOptions = [1, 3, 5]
    let allowsOvertime = false
    let warningThreshold: TimeInterval? = nil

    let model = ScoringModel.tennis
    let allowsSubtract = false

    let scoringActions = [ScoreAction(points: 1, caption: "Point", label: "Point")]
    let tracksPossession = true
    let possessionName = "Serve"

    func periodLabel(_ period: Int, regulation: Int) -> String { "SET \(period)" }
    func periodTitle(_ period: Int, regulation: Int) -> String { "Set \(period)" }
}

/// Pickleball: games to 11, win by 2. Traditional side-out scoring (only the serving team
/// scores, doubles has server 1 and 2, games start at 0-0-2) or optional rally scoring.
struct PickleballRules: SportRules {
    let kind = SportKind.pickleball
    let name = "Pickleball"
    let symbolName = "figure.pickleball"
    let summary = "Side-out scoring · 0-0-2"

    private let pointsToWin: Int
    private let sideOut: Bool
    private let doubles: Bool

    init(config: GameConfig? = nil) {
        pointsToWin = config?.pointsToWin ?? 11
        sideOut = !(config?.rallyScoring ?? false)
        doubles = config?.doubles ?? true
    }

    var defaults: SportDefaults {
        SportDefaults(
            teamA: TeamConfig(name: "Team A", color: .teal),
            teamB: TeamConfig(name: "Team B", color: .orange),
            periodLength: 10 * 60,
            periodCount: 1,
            overtimeLength: 5 * 60,
            clockEnabled: false,
            pointsToWin: 11
        )
    }

    let periodName = "Game"
    let periodCountOptions = [1, 3, 5]
    let allowsOvertime = false
    let warningThreshold: TimeInterval? = nil

    let model = ScoringModel.rally
    var rallyFormat: RallyFormat? {
        RallyFormat(
            pointsToWin: pointsToWin,
            decidingSetPoints: pointsToWin,
            winBy: 2,
            cap: nil,
            serve: .winnerServes,
            nextSetServer: .alternate,
            sideOut: sideOut,
            doubles: doubles
        )
    }

    var scoringActions: [ScoreAction] {
        sideOut
            ? [ScoreAction(points: 1, caption: "Rally", label: "Won Rally")]
            : [ScoreAction(points: 1, caption: "Point")]
    }

    let tracksPossession = true
    let possessionName = "Serve"

    func periodLabel(_ period: Int, regulation: Int) -> String { "GAME \(period)" }
    func periodTitle(_ period: Int, regulation: Int) -> String { "Game \(period)" }
}
