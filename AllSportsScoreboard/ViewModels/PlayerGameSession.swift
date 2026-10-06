import Foundation
import Observation

struct PlayerSessionEnvironment {
    var feedback: @MainActor (FeedbackEvent) -> Void
    var persist: @MainActor (PlayerGameState) -> Void
    var recordResult: @MainActor (PlayerGameState, String) -> Void

    static var live: PlayerSessionEnvironment {
        PlayerSessionEnvironment(
            feedback: { Feedback.shared.play($0) },
            persist: { PlayerSessionStore.save($0) },
            recordResult: { HistoryStore.shared.record(playerGame: $0, summary: $1) }
        )
    }

    static var silent: PlayerSessionEnvironment {
        PlayerSessionEnvironment(feedback: { _ in }, persist: { _ in }, recordResult: { _, _ in })
    }
}

/// Engine for BucketGolf stroke play. Every swing is recorded for the player who's up;
/// touching the bucket ends their hole, a chip into the bucket takes a stroke off, a hazard
/// adds a penalty stroke. Lowest total after the course wins.
@Observable
@MainActor
final class PlayerGameSession: Identifiable {
    let id = UUID()

    private(set) var state: PlayerGameState {
        didSet { environment.persist(state) }
    }

    private(set) var flash: ScoreFlash?
    private(set) var bump = 0

    @ObservationIgnored private let environment: PlayerSessionEnvironment
    @ObservationIgnored private let undoLimit = 200

    init(state: PlayerGameState, environment: PlayerSessionEnvironment = .live) {
        self.state = state
        self.environment = environment
    }

    // MARK: - Reading

    var config: PlayerGameConfig { state.config }
    var phase: GamePhase { state.phase }
    var current: Int { state.current }
    var hole: Int { state.hole }
    var currentName: String { config.playerName(state.current) }
    var currentCard: HoleCard { state.card(state.current) }
    var canUndo: Bool { !state.undoStack.isEmpty && state.phase != .final }
    var isLastHole: Bool { state.hole >= config.holes }
    var isHoleComplete: Bool { state.isHoleComplete }

    var isInProgress: Bool {
        state.phase == .live || (state.phase == .pregame && state.cards.joined().contains { !$0.shots.isEmpty })
    }

    var statusText: String {
        switch state.phase {
        case .pregame: return "Ready · \(config.holes) Holes"
        case .live, .periodBreak: return "Hole \(state.hole) of \(config.holes) · Par 3"
        case .final: return "Final"
        }
    }

    var statusTone: StatusTone {
        switch state.phase {
        case .pregame: return .idle
        case .live, .periodBreak: return isHoleComplete ? .intermission : .live
        case .final: return .final
        }
    }

    /// The big button: next player on this hole, then the next hole, then finish.
    var primaryTitle: String {
        if state.phase == .final { return "New Game" }
        if isHoleComplete { return isLastHole ? "Finish Game" : "Next Hole: \(state.hole + 1)" }
        if let next = state.nextUnfinished(after: state.current), next != state.current {
            return "Next: \(config.playerName(next))"
        }
        return "Up: \(currentName)"
    }

    var primarySymbol: String {
        if state.phase == .final { return "arrow.counterclockwise" }
        if isHoleComplete { return isLastHole ? "flag.checkered" : "flag.fill" }
        return "forward.fill"
    }

    var primaryIsReady: Bool { isHoleComplete || currentCard.isFinished }

    /// Total against par, e.g. "+2", "E", "−1".
    func parText(_ player: Int) -> String { GolfTerm.relative(state.relativeToPar(player)) }

    /// Running total including the hole in progress.
    func totalText(_ player: Int) -> String { "\(state.total(player))" }

    var winnerNames: [String] { state.leaders.map { config.playerName($0) } }

    var standingsSummary: String {
        state.standings.map { "\(config.playerName($0)) \(state.total($0)) (\(parText($0)))" }.joined(separator: " · ")
    }

    // MARK: - Recording shots

    func record(_ shot: ShotKind) {
        guard state.phase != .final else { return }
        guard !currentCard.isFinished else {
            environment.feedback(.denied)
            return
        }
        let limit = undoLimit
        let player = state.current
        var finished = false
        update { s in
            Self.pushUndo(&s, limit: limit)
            if s.phase == .pregame { s.phase = .live }
            s.cards[player][s.hole - 1].shots.append(shot)
            if shot.finishesHole {
                finished = true
                // Hand the turn to the next player still playing this hole.
                if let next = s.nextUnfinished(after: player) { s.current = next }
            }
        }
        bump += 1

        let card = state.card(player)
        switch shot {
        case .miss:
            showFlash("+1", positive: false)
            environment.feedback(.tap)
        case .hazard:
            showFlash("+1 PENALTY", positive: false)
            environment.feedback(.warning)
        case .contact:
            showFlash(GolfTerm.name(strokes: card.strokes).uppercased(), positive: true)
            environment.feedback(.score(1))
        case .bucketIn:
            showFlash("IN! −1", positive: true)
            environment.feedback(.score(3))
        }
        if finished && state.isHoleComplete {
            environment.feedback(.periodEnd)
        }
    }

    /// Big button: next player on this hole, or the next hole once everyone is done.
    func advance() {
        switch state.phase {
        case .final:
            rematch()
        default:
            if isHoleComplete {
                nextHole()
            } else if let next = state.nextUnfinished(after: state.current), next != state.current {
                select(player: next)
            }
        }
    }

    func nextHole() {
        guard state.phase != .final, isHoleComplete else { return }
        let limit = undoLimit
        var gameOver = false
        update { s in
            Self.pushUndo(&s, limit: limit)
            if s.hole >= s.config.holes {
                s.phase = .final
                gameOver = true
            } else {
                // Honors: best score on the hole just played tees off first; ties keep the order.
                let played = s.hole
                let before = s
                let honors = before.teeOrder.enumerated().sorted { lhs, rhs in
                    let a = before.card(lhs.element, hole: played).strokes
                    let b = before.card(rhs.element, hole: played).strokes
                    return a != b ? a < b : lhs.offset < rhs.offset
                }
                s.teeOrder = honors.map { $0.element }
                s.hole += 1
                s.current = s.teeOrder.first ?? 0
                s.phase = .live
            }
        }
        if gameOver {
            environment.recordResult(state, standingsSummary)
            environment.feedback(.gameEnd)
        } else {
            environment.feedback(.periodChange)
        }
    }

    /// Records shots for a different player (after the tee shots, farthest from the bucket plays).
    func select(player index: Int) {
        guard state.phase != .final, index != state.current, (0..<state.playerCount).contains(index) else { return }
        update { $0.current = index }
        environment.feedback(.possession)
    }

    func undo() {
        guard canUndo, let snapshot = state.undoStack.last else { return }
        update { s in
            s.undoStack.removeLast()
            s.restore(snapshot)
        }
        bump += 1
        environment.feedback(.undo)
    }

    func endGame() {
        guard state.phase != .final else { return }
        update { $0.phase = .final }
        environment.recordResult(state, standingsSummary)
        environment.feedback(.gameEnd)
    }

    func reopen() {
        guard state.phase == .final else { return }
        update { $0.phase = .live }
        environment.feedback(.tap)
    }

    func rematch() {
        state = PlayerGameState(config: config)
        flash = nil
        environment.feedback(.periodChange)
    }

    func resetGame() {
        state = PlayerGameState(config: config)
        flash = nil
        environment.feedback(.reset)
    }

    func updatePlayers(_ players: [PlayerConfig]) {
        guard players.count == state.playerCount else { return }
        update { $0.config.players = players }
    }

    // MARK: - Private

    nonisolated private static func pushUndo(_ s: inout PlayerGameState, limit: Int) {
        s.undoStack.append(s.snapshot)
        if s.undoStack.count > limit { s.undoStack.removeFirst(s.undoStack.count - limit) }
    }

    private func update(_ body: (inout PlayerGameState) -> Void) {
        var copy = state
        body(&copy)
        state = copy
    }

    private func showFlash(_ text: String, positive: Bool) {
        let newFlash = ScoreFlash(side: .a, text: text, isPositive: positive)
        flash = newFlash
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            if self?.flash?.id == newFlash.id { self?.flash = nil }
        }
    }
}

/// Keeps the in-progress BucketGolf round on disk.
enum PlayerSessionStore {
    private static let key = "activePlayerGame.v2"

    static func save(_ state: PlayerGameState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: key)
        UserDefaults.standard.set(Date(), forKey: key + ".savedAt")
    }

    static func load() -> PlayerGameState? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PlayerGameState.self, from: data)
    }

    static var savedAt: Date? { UserDefaults.standard.object(forKey: key + ".savedAt") as? Date }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: key + ".savedAt")
    }
}
