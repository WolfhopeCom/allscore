import Foundation

/// One player's card on one hole, entered like the official BucketGolf scorecard: swings,
/// whether the last one went in the bucket, and hazards.
struct HoleCard: Codable, Equatable {
    /// Every swing is a stroke.
    var swings = 0
    /// A chip into the bucket takes one stroke off.
    var inBucket = false
    /// Each hazard (water, bushes) adds a penalty stroke.
    var hazards = 0

    init(swings: Int = 0, inBucket: Bool = false, hazards: Int = 0) {
        self.swings = swings
        self.inBucket = inBucket
        self.hazards = hazards
    }

    /// A hole counts once at least one swing is entered.
    var isFinished: Bool { swings > 0 }
    /// The hole score: swings + hazards − 1 for in the bucket.
    var strokes: Int { isFinished ? max(0, swings + hazards - (inBucket ? 1 : 0)) : 0 }

    private enum CodingKeys: String, CodingKey {
        case swings, inBucket, hazards, shots
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        swings = try c.decodeIfPresent(Int.self, forKey: .swings) ?? 0
        inBucket = try c.decodeIfPresent(Bool.self, forKey: .inBucket) ?? false
        hazards = try c.decodeIfPresent(Int.self, forKey: .hazards) ?? 0
        // Rounds saved by version 1.0/1.1 stored each shot (miss, hazard, contact, bucketIn).
        if let shots = try c.decodeIfPresent([String].self, forKey: .shots), !shots.isEmpty, swings == 0 {
            swings = shots.count
            hazards = shots.filter { $0 == "hazard" }.count
            inBucket = shots.contains("bucketIn")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(swings, forKey: .swings)
        try c.encode(inBucket, forKey: .inBucket)
        try c.encode(hazards, forKey: .hazards)
    }
}

struct PlayerConfig: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var color: TeamColor
}

/// Setup for a BucketGolf round: stroke play, par 3 on every hole.
struct PlayerGameConfig: Codable, Equatable {
    static let maxPlayers = 8
    static let par = 3
    static let holeOptions = [3, 6, 9, 18]

    var players: [PlayerConfig]
    var holes: Int

    static var standard: PlayerGameConfig {
        PlayerGameConfig(
            players: [
                PlayerConfig(name: "Player 1", color: .gold),
                PlayerConfig(name: "Player 2", color: .teal),
                PlayerConfig(name: "Player 3", color: .red),
                PlayerConfig(name: "Player 4", color: .purple)
            ],
            holes: 9
        )
    }

    var coursePar: Int { holes * Self.par }

    func playerName(_ index: Int) -> String {
        guard players.indices.contains(index) else { return "Player \(index + 1)" }
        let trimmed = players[index].name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Player \(index + 1)" : trimmed
    }

    func color(_ index: Int) -> TeamColor {
        players.indices.contains(index) ? players[index].color : .silver
    }

    func sanitized() -> PlayerGameConfig {
        var copy = self
        if copy.players.isEmpty { copy.players = [PlayerConfig(name: "Player 1", color: .gold)] }
        if copy.players.count > Self.maxPlayers { copy.players = Array(copy.players.prefix(Self.maxPlayers)) }
        if !Self.holeOptions.contains(copy.holes) {
            copy.holes = Self.holeOptions.min { abs($0 - copy.holes) < abs($1 - copy.holes) } ?? 9
        }
        return copy
    }
}

struct PlayerSnapshot: Codable, Equatable {
    var hole: Int
    var current: Int
    var cards: [[HoleCard]]
    var teeOrder: [Int]
    var phase: GamePhase
}

/// The complete, codable state of a BucketGolf round.
struct PlayerGameState: Codable, Equatable {
    var id = UUID()
    var config: PlayerGameConfig
    /// 1-based hole number being played.
    var hole = 1
    /// The player whose shots are being recorded.
    var current = 0
    /// [player][hole − 1]
    var cards: [[HoleCard]]
    /// Order players tee off on this hole: setup order on hole 1, then best score on the
    /// previous hole first ("honors").
    var teeOrder: [Int]
    var phase: GamePhase = .pregame
    var createdAt = Date()
    var undoStack: [PlayerSnapshot] = []

    init(config rawConfig: PlayerGameConfig) {
        let config = rawConfig.sanitized()
        self.config = config
        self.cards = Array(repeating: Array(repeating: HoleCard(), count: config.holes), count: config.players.count)
        self.teeOrder = Array(0..<config.players.count)
    }

    var playerCount: Int { config.players.count }

    func card(_ player: Int, hole: Int? = nil) -> HoleCard {
        let h = (hole ?? self.hole) - 1
        guard cards.indices.contains(player), cards[player].indices.contains(h) else { return HoleCard() }
        return cards[player][h]
    }

    /// Running total: every stroke so far, including the hole in progress.
    func total(_ player: Int) -> Int {
        guard cards.indices.contains(player) else { return 0 }
        return cards[player].reduce(0) { $0 + $1.strokes }
    }

    /// Holes this player has finished.
    func holesFinished(_ player: Int) -> Int {
        guard cards.indices.contains(player) else { return 0 }
        return cards[player].filter(\.isFinished).count
    }

    /// Strokes against par over finished holes (in-progress strokes aren't judged yet).
    func relativeToPar(_ player: Int) -> Int {
        guard cards.indices.contains(player) else { return 0 }
        return cards[player].filter(\.isFinished).reduce(0) { $0 + $1.strokes - PlayerGameConfig.par }
    }

    var isHoleComplete: Bool {
        (0..<playerCount).allSatisfy { card($0).isFinished }
    }

    /// Best first. Mid-round, players can have finished different numbers of holes, so like a
    /// golf leaderboard this ranks by score to par on finished holes; once everyone has played
    /// every hole that is the same as lowest total.
    var standings: [Int] {
        Array(0..<playerCount).sorted { a, b in
            if relativeToPar(a) != relativeToPar(b) { return relativeToPar(a) < relativeToPar(b) }
            if holesFinished(a) != holesFinished(b) { return holesFinished(a) > holesFinished(b) }
            return a < b
        }
    }

    var leaders: [Int] {
        guard let first = standings.first else { return [] }
        return standings.filter { relativeToPar($0) == relativeToPar(first) }
    }

    var snapshot: PlayerSnapshot {
        PlayerSnapshot(hole: hole, current: current, cards: cards, teeOrder: teeOrder, phase: phase)
    }

    mutating func restore(_ s: PlayerSnapshot) {
        hole = s.hole
        current = s.current
        cards = s.cards
        teeOrder = s.teeOrder
        phase = s.phase
    }
}

extension PlayerGameState {
    private enum CodingKeys: String, CodingKey {
        case id, config, hole, current, cards, teeOrder, phase, createdAt, undoStack
    }

    /// Undo steps written to disk. Each holds a whole scorecard, so saving all of them
    /// would make every shot slower as the round goes on.
    static let savedUndoSteps = 25

    /// Tolerant decoding: anything missing or added in a later version falls back to a
    /// sensible value, so an update never drops a round in progress.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let config = try c.decode(PlayerGameConfig.self, forKey: .config)
        self.init(config: config)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        if let saved = try c.decodeIfPresent([[HoleCard]].self, forKey: .cards),
           saved.count == self.config.players.count,
           saved.allSatisfy({ $0.count == self.config.holes }) {
            cards = saved
        }
        hole = min(max(try c.decodeIfPresent(Int.self, forKey: .hole) ?? 1, 1), self.config.holes)
        current = min(max(try c.decodeIfPresent(Int.self, forKey: .current) ?? 0, 0), playerCount - 1)
        if let order = try c.decodeIfPresent([Int].self, forKey: .teeOrder), order.sorted() == Array(0..<playerCount) {
            teeOrder = order
        }
        phase = try c.decodeIfPresent(GamePhase.self, forKey: .phase) ?? .pregame
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        undoStack = (try? c.decodeIfPresent([PlayerSnapshot].self, forKey: .undoStack)) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(config, forKey: .config)
        try c.encode(hole, forKey: .hole)
        try c.encode(current, forKey: .current)
        try c.encode(cards, forKey: .cards)
        try c.encode(teeOrder, forKey: .teeOrder)
        try c.encode(phase, forKey: .phase)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(Array(undoStack.suffix(Self.savedUndoSteps)), forKey: .undoStack)
    }
}

/// Golf's names for a hole score against par.
enum GolfTerm {
    static func name(strokes: Int, par: Int = PlayerGameConfig.par) -> String {
        switch strokes - par {
        case ...(-3): return "Hole in Zero"
        case -2: return "Hole in One"
        case -1: return "Birdie"
        case 0: return "Par"
        case 1: return "Bogey"
        case 2: return "Double Bogey"
        case 3: return "Triple Bogey"
        default: return "+\(strokes - par)"
        }
    }

    static func relative(_ value: Int) -> String {
        if value == 0 { return "E" }
        return value > 0 ? "+\(value)" : "−\(-value)"
    }
}
