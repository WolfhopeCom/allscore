import Foundation

enum GamePhase: String, Codable {
    case pregame
    case live
    case periodBreak
    case final
}

/// One finished set or game: points (rally sports) or games (tennis) per side.
struct SetScore: Codable, Equatable {
    var scores: [Int]
    /// Tennis tiebreak points, when the set went to one.
    var tiebreak: [Int]?
}

/// A judge's score for one round of boxing / MMA (10-point must system).
struct RoundCard: Codable, Equatable {
    var round: Int
    var points: [Int]
}

/// Extra state used by the set-, inning- and round-based sports. Points-based sports
/// leave it at its defaults.
struct MatchState: Codable, Equatable {
    // Rally sports & tennis
    /// Rally: points in the current set. Tennis: points in the current game (0…4+).
    var points: [Int] = [0, 0]
    /// Tennis: games in the current set.
    var games: [Int] = [0, 0]
    var sets: [SetScore] = []
    var setFirstServer: TeamSide = .a
    /// Pickleball doubles: 1 or 2. Games start at "0-0-2".
    var serverNumber = 1
    var inTiebreak = false
    var tiebreakFirstServer: TeamSide = .a

    // Baseball
    var isBottom = false
    var outs = 0
    var balls = 0
    var strikes = 0
    /// Runs per inning, per team.
    var lineScore: [[Int]] = [[], []]

    // Boxing / MMA
    var cards: [RoundCard] = []
    var resting = false
    var restCued = false

    mutating func reverseSides() {
        points.reverse()
        games.reverse()
        for index in sets.indices {
            sets[index].scores.reverse()
            sets[index].tiebreak?.reverse()
        }
        setFirstServer = setFirstServer.opponent
        tiebreakFirstServer = tiebreakFirstServer.opponent
        lineScore.reverse()
        for index in cards.indices {
            cards[index].points.reverse()
        }
    }
}

/// What an undo step restores. The clock is deliberately excluded: undoing a basket
/// should never rewind time.
struct ScoreSnapshot: Codable, Equatable {
    var scores: [Int]
    var counters: [String: [Int]]
    var possession: TeamSide?
    var match: MatchState?
    var period: Int?
    var phase: GamePhase?
}

/// The complete, codable state of one game. Saved after every change so a game survives
/// the app being closed or killed.
struct GameState: Codable, Equatable {
    var id = UUID()
    var config: GameConfig
    /// Points-based sports: the score. Set-based sports: sets won.
    var scores: [Int] = [0, 0]
    /// Counter ID → [team A value, team B value].
    var counters: [String: [Int]] = [:]
    /// Possession, serve, or batting side, depending on the sport.
    var possession: TeamSide?
    var period = 1
    var phase: GamePhase = .pregame
    var clock: GameClock
    var createdAt = Date()
    var undoStack: [ScoreSnapshot] = []
    /// Period whose time cue (countdown warning / count-up regulation reached) already played.
    var cuedPeriod: Int?
    var match = MatchState()
    /// Set when a game ends by stoppage (KO/TKO) rather than on the scoreboard.
    var declaredWinner: TeamSide?
    var resultNote: String?

    init(config rawConfig: GameConfig) {
        let config = rawConfig.sanitized()
        let rules = SportCatalog.rules(for: config)
        self.config = config
        self.clock = GameClock(
            direction: rules.clockDirection,
            length: config.clockEnabled ? config.periodLength : 0,
            runsPastLength: rules.clockRunsPastLength
        )
        var counters: [String: [Int]] = [:]
        for spec in rules.counters {
            counters[spec.id] = [spec.initialValue, spec.initialValue]
        }
        self.counters = counters
        switch rules.model {
        case .rally, .tennis:
            possession = .a
            if let format = rules.rallyFormat, format.sideOut, format.doubles {
                match.serverNumber = 2
            }
        case .baseball:
            possession = .a
            match.lineScore = [[0], [0]]
        case .points, .combat:
            possession = nil
        }
    }

    func score(_ side: TeamSide) -> Int { scores[side.rawValue] }

    func counter(_ id: String, _ side: TeamSide) -> Int {
        counters[id]?[side.rawValue] ?? 0
    }

    var isTied: Bool { scores[0] == scores[1] }

    var leader: TeamSide? {
        if isTied { return nil }
        return scores[0] > scores[1] ? .a : .b
    }

    /// The winner shown on the final screen and in history.
    var winner: TeamSide? { declaredWinner ?? leader }

    var hasAnyScore: Bool {
        scores.contains { $0 > 0 } || match.points.contains { $0 > 0 } || !match.cards.isEmpty
    }

    mutating func pushUndo(limit: Int) {
        undoStack.append(ScoreSnapshot(
            scores: scores,
            counters: counters,
            possession: possession,
            match: match,
            period: period,
            phase: phase
        ))
        if undoStack.count > limit {
            undoStack.removeFirst(undoStack.count - limit)
        }
    }

    /// - Parameter flow: also restore period and phase (set-, inning- and point-based
    ///   transitions happen as a result of scoring in those sports).
    mutating func restore(_ snapshot: ScoreSnapshot, flow: Bool, keepCounters: Bool) {
        scores = snapshot.scores
        if !keepCounters { counters = snapshot.counters }
        possession = snapshot.possession
        if let snapshotMatch = snapshot.match {
            let resting = match.resting
            let restCued = match.restCued
            match = snapshotMatch
            match.resting = resting
            match.restCued = restCued
        }
        if flow {
            if let snapshotPeriod = snapshot.period { period = snapshotPeriod }
            if let snapshotPhase = snapshot.phase { phase = snapshotPhase }
        }
    }

    /// Teams switch ends: names, colors, scores, counters and possession all move together.
    mutating func swapSides() {
        let a = config.teamA
        config.teamA = config.teamB
        config.teamB = a
        scores.reverse()
        for key in Array(counters.keys) {
            counters[key]?.reverse()
        }
        possession = possession?.opponent
        declaredWinner = declaredWinner?.opponent
        match.reverseSides()
        for index in undoStack.indices {
            undoStack[index].scores.reverse()
            for key in Array(undoStack[index].counters.keys) {
                undoStack[index].counters[key]?.reverse()
            }
            undoStack[index].possession = undoStack[index].possession?.opponent
            undoStack[index].match?.reverseSides()
        }
    }
}

extension GameState {
    private enum CodingKeys: String, CodingKey {
        case id, config, scores, counters, possession, period, phase, clock, createdAt
        case undoStack, cuedPeriod, match, declaredWinner, resultNote
    }

    /// Tolerant decoding so a game in progress survives an app update that adds fields.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        config = try c.decode(GameConfig.self, forKey: .config)
        clock = try c.decode(GameClock.self, forKey: .clock)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        scores = try c.decodeIfPresent([Int].self, forKey: .scores) ?? [0, 0]
        if scores.count != 2 { scores = [0, 0] }
        counters = try c.decodeIfPresent([String: [Int]].self, forKey: .counters) ?? [:]
        possession = try c.decodeIfPresent(TeamSide.self, forKey: .possession)
        period = try max(1, c.decodeIfPresent(Int.self, forKey: .period) ?? 1)
        phase = try c.decodeIfPresent(GamePhase.self, forKey: .phase) ?? .pregame
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        undoStack = try c.decodeIfPresent([ScoreSnapshot].self, forKey: .undoStack) ?? []
        cuedPeriod = try c.decodeIfPresent(Int.self, forKey: .cuedPeriod)
        match = try c.decodeIfPresent(MatchState.self, forKey: .match) ?? MatchState()
        declaredWinner = try c.decodeIfPresent(TeamSide.self, forKey: .declaredWinner)
        resultNote = try c.decodeIfPresent(String.self, forKey: .resultNote)

        // Make sure every counter this sport uses exists with two values.
        for spec in SportCatalog.rules(for: config).counters where counters[spec.id]?.count != 2 {
            counters[spec.id] = [spec.initialValue, spec.initialValue]
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(config, forKey: .config)
        try c.encode(scores, forKey: .scores)
        try c.encode(counters, forKey: .counters)
        try c.encodeIfPresent(possession, forKey: .possession)
        try c.encode(period, forKey: .period)
        try c.encode(phase, forKey: .phase)
        try c.encode(clock, forKey: .clock)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(undoStack, forKey: .undoStack)
        try c.encodeIfPresent(cuedPeriod, forKey: .cuedPeriod)
        try c.encode(match, forKey: .match)
        try c.encodeIfPresent(declaredWinner, forKey: .declaredWinner)
        try c.encodeIfPresent(resultNote, forKey: .resultNote)
    }
}

extension MatchState {
    private enum CodingKeys: String, CodingKey {
        case points, games, sets, setFirstServer, serverNumber, inTiebreak, tiebreakFirstServer
        case isBottom, outs, balls, strikes, lineScore, cards, resting, restCued
    }

    /// Tolerant decoding: fields added later fall back to their defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        points = try c.decodeIfPresent([Int].self, forKey: .points) ?? points
        games = try c.decodeIfPresent([Int].self, forKey: .games) ?? games
        sets = try c.decodeIfPresent([SetScore].self, forKey: .sets) ?? sets
        setFirstServer = try c.decodeIfPresent(TeamSide.self, forKey: .setFirstServer) ?? setFirstServer
        serverNumber = try c.decodeIfPresent(Int.self, forKey: .serverNumber) ?? serverNumber
        inTiebreak = try c.decodeIfPresent(Bool.self, forKey: .inTiebreak) ?? inTiebreak
        tiebreakFirstServer = try c.decodeIfPresent(TeamSide.self, forKey: .tiebreakFirstServer) ?? tiebreakFirstServer
        isBottom = try c.decodeIfPresent(Bool.self, forKey: .isBottom) ?? isBottom
        outs = try c.decodeIfPresent(Int.self, forKey: .outs) ?? outs
        balls = try c.decodeIfPresent(Int.self, forKey: .balls) ?? balls
        strikes = try c.decodeIfPresent(Int.self, forKey: .strikes) ?? strikes
        lineScore = try c.decodeIfPresent([[Int]].self, forKey: .lineScore) ?? lineScore
        cards = try c.decodeIfPresent([RoundCard].self, forKey: .cards) ?? cards
        resting = try c.decodeIfPresent(Bool.self, forKey: .resting) ?? resting
        restCued = try c.decodeIfPresent(Bool.self, forKey: .restCued) ?? restCued
        if points.count != 2 { points = [0, 0] }
        if games.count != 2 { games = [0, 0] }
        if lineScore.count != 2 { lineScore = [[], []] }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(points, forKey: .points)
        try c.encode(games, forKey: .games)
        try c.encode(sets, forKey: .sets)
        try c.encode(setFirstServer, forKey: .setFirstServer)
        try c.encode(serverNumber, forKey: .serverNumber)
        try c.encode(inTiebreak, forKey: .inTiebreak)
        try c.encode(tiebreakFirstServer, forKey: .tiebreakFirstServer)
        try c.encode(isBottom, forKey: .isBottom)
        try c.encode(outs, forKey: .outs)
        try c.encode(balls, forKey: .balls)
        try c.encode(strikes, forKey: .strikes)
        try c.encode(lineScore, forKey: .lineScore)
        try c.encode(cards, forKey: .cards)
        try c.encode(resting, forKey: .resting)
        try c.encode(restCued, forKey: .restCued)
    }
}
