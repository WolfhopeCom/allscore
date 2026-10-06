import Foundation

/// What happened on one swing in BucketGolf.
enum ShotKind: String, Codable, CaseIterable {
    /// The ball didn't touch the bucket (hitting only the flagstick counts as a miss).
    case miss
    /// Ball into a hazard (water, bushes): the swing plus a 1-stroke penalty. Play continues
    /// after a drop no closer to the bucket.
    case hazard
    /// The ball hit the outside of the bucket: the hole is complete.
    case contact
    /// The ball was chipped into the bucket: the hole is complete with a 1-stroke bonus.
    case bucketIn

    var finishesHole: Bool { self == .contact || self == .bucketIn }

    /// Strokes this shot adds to the hole score.
    var strokes: Int {
        switch self {
        case .miss, .contact: return 1
        case .hazard: return 2
        case .bucketIn: return 0   // the swing (+1) and the bucket-in bonus (−1)
        }
    }

    var shortName: String {
        switch self {
        case .miss: return "Miss"
        case .hazard: return "Hazard"
        case .contact: return "Bucket"
        case .bucketIn: return "In"
        }
    }
}

/// One player's shots on one hole.
struct HoleCard: Codable, Equatable {
    var shots: [ShotKind] = []

    var isFinished: Bool { shots.last?.finishesHole ?? false }
    var swings: Int { shots.count }
    var penalties: Int { shots.filter { $0 == .hazard }.count }
    var bonus: Int { shots.contains(.bucketIn) ? 1 : 0 }
    /// Every swing is a stroke, hazards add a penalty stroke, a bucket-in takes one off.
    var strokes: Int { swings + penalties - bonus }
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

    /// The next player in tee order who hasn't finished this hole, after `player`.
    func nextUnfinished(after player: Int) -> Int? {
        guard let start = teeOrder.firstIndex(of: player) else { return teeOrder.first { !card($0).isFinished } }
        for step in 1...max(1, teeOrder.count) {
            let candidate = teeOrder[(start + step) % teeOrder.count]
            if !card(candidate).isFinished { return candidate }
        }
        return nil
    }

    /// Lowest total first; ties keep setup order.
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

/// Golf's names for a hole score against par.
enum GolfTerm {
    static func name(strokes: Int, par: Int = PlayerGameConfig.par) -> String {
        switch strokes - par {
        case ...(-3): return "Albatross"
        case -2: return "Eagle"
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
