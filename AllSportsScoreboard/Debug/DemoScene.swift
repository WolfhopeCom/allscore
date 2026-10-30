#if DEBUG
import SwiftUI
import UIKit

/// Real game states for App Store screenshots, opened with a launch argument such as
/// `-screenshot basketball`. Debug builds only; never part of the App Store build.
enum DemoScene: String, CaseIterable {
    case home, basketball, fullScreen, pickleball, bucketGolf, final, soccer, settings, cornhole, lacrosse, darts, dartsPortrait

    static var current: DemoScene? {
        UserDefaults.standard.string(forKey: "screenshot").flatMap(DemoScene.init(rawValue:))
    }

    /// The scoreboard is designed landscape-first. The sports grid and Settings are long
    /// lists, so they're shot in portrait.
    var isLandscape: Bool { self != .settings && self != .home && self != .dartsPortrait }

    func applyOrientation() {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: isLandscape ? .landscapeRight : .portrait))
    }

    static func basketball(period: Int = 3, scores: [Int] = [48, 45], remaining: TimeInterval = 58.4) -> GameState {
        var config = SportCatalog.defaultConfig(for: .basketball)
        config.teamA = TeamConfig(name: "Lions", color: .gold)
        config.teamB = TeamConfig(name: "Hawks", color: .blue)
        var state = GameState(config: config)
        state.phase = .live
        state.period = period
        state.scores = scores
        state.counters["fouls"] = [3, 5]
        state.possession = .b
        let now = Date()
        state.clock.adjust(by: remaining - state.clock.remaining(at: now), at: now)
        state.clock.start(at: now)
        return state
    }

    static func soccer() -> GameState {
        var config = SportCatalog.defaultConfig(for: .soccer)
        config.teamA = TeamConfig(name: "Rovers", color: .green)
        config.teamB = TeamConfig(name: "Comets", color: .red)
        var state = GameState(config: config)
        state.phase = .live
        state.period = 2
        state.scores = [2, 1]
        let now = Date()
        state.clock.adjust(by: 31 * 60 + 18, at: now)
        state.clock.start(at: now)
        return state
    }

    static func cornhole() -> GameState {
        var config = SportCatalog.defaultConfig(for: .cornhole)
        config.teamA = TeamConfig(name: "Bag Boys", color: .blue)
        config.teamB = TeamConfig(name: "Hole Hunters", color: .red)
        var state = GameState(config: config)
        state.phase = .live
        state.period = 6
        state.scores = [14, 9]
        state.match.points = [7, 4]
        state.match.cards = [
            RoundCard(round: 1, points: [5, 2]), RoundCard(round: 2, points: [3, 6]),
            RoundCard(round: 3, points: [9, 4]), RoundCard(round: 4, points: [4, 4]),
            RoundCard(round: 5, points: [7, 1])
        ]
        return state
    }

    static func darts() -> GameState {
        var config = SportCatalog.defaultConfig(for: .darts)
        config.teamA = TeamConfig(name: "Mike", color: .red)
        config.teamB = TeamConfig(name: "Jess", color: .green)
        var state = GameState(config: config)
        state.phase = .live
        // 20, 19, 18, 17, 16, 15, Bull
        state.match.marks = [[3, 3, 3, 1, 0, 2, 1], [3, 2, 3, 3, 3, 0, 0]]
        state.scores = [3, 4]
        return state
    }

    static func lacrosse() -> GameState {
        var config = SportCatalog.defaultConfig(for: .lacrosse)
        config.teamA = TeamConfig(name: "Wolves", color: .blue)
        config.teamB = TeamConfig(name: "Falcons", color: .orange)
        var state = GameState(config: config)
        state.phase = .live
        state.period = 2
        state.scores = [5, 4]
        state.counters["timeouts"] = [1, 2]
        state.possession = .a
        let now = Date()
        state.clock.adjust(by: 4 * 60 + 37 - state.clock.remaining(at: now), at: now)
        state.clock.start(at: now)
        return state
    }

    static func pickleball() -> GameState {
        var config = SportCatalog.defaultConfig(for: .pickleball)
        config.teamA = TeamConfig(name: "Dink Squad", color: .teal)
        config.teamB = TeamConfig(name: "Net Gains", color: .orange)
        config.doubles = true
        config.rallyScoring = false
        var state = GameState(config: config)
        state.phase = .live
        state.period = 2
        state.scores = [1, 0]
        state.match.sets = [SetScore(scores: [11, 7], tiebreak: nil)]
        state.match.points = [4, 2]
        state.match.serverNumber = 1
        state.possession = .a
        return state
    }

    /// A 9-hole round, two holes played and the third under way.
    @MainActor
    static func bucketGolf() -> PlayerGameSession {
        var config = PlayerGameConfig.standard
        config.players = [
            PlayerConfig(name: "Sam", color: .gold),
            PlayerConfig(name: "Jordan", color: .blue),
            PlayerConfig(name: "Riley", color: .green),
            PlayerConfig(name: "Casey", color: .red)
        ]
        config.holes = 9
        let session = PlayerGameSession(state: PlayerGameState(config: config))
        // (swings, in the bucket, hazards) per player for the first two holes.
        let holes: [[(Int, Bool, Int)]] = [
            [(2, false, 0), (3, false, 0), (3, true, 0), (2, false, 1)],
            [(3, false, 0), (2, false, 0), (3, false, 0), (4, false, 0)]
        ]
        func enter(_ player: Int, _ score: (Int, Bool, Int)) {
            session.adjustSwings(player, by: score.0)
            if score.1 { session.toggleBucket(player) }
            if score.2 > 0 { session.adjustHazards(player, by: score.2) }
        }
        for hole in holes {
            for (player, score) in hole.enumerated() { enter(player, score) }
            session.nextHole()
        }
        // Hole 3 under way: two players have scores in.
        enter(0, (2, true, 0))
        enter(1, (3, false, 1))
        return session
    }
}
#endif
