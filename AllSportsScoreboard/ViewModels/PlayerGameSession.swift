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

/// Engine for BucketGolf stroke play, scored like the official scorecard: for each player on
/// each hole enter swings, In the Bucket (−1) and hazards (+1 each). Move between holes
/// freely; lowest total after the course wins.
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
    @ObservationIgnored private let undoLimit = 60

    init(state: PlayerGameState, environment: PlayerSessionEnvironment = .live) {
        self.state = state
        self.environment = environment
    }

    // MARK: - Reading

    var config: PlayerGameConfig { state.config }
    var phase: GamePhase { state.phase }
    var hole: Int { state.hole }
    var canUndo: Bool { !state.undoStack.isEmpty && state.phase != .final }
    var isLastHole: Bool { state.hole >= config.holes }
    var isHoleComplete: Bool { state.isHoleComplete }

    var isInProgress: Bool {
        state.phase == .live || (state.phase == .pregame && state.cards.joined().contains { $0.isFinished })
    }

    var statusText: String {
        switch state.phase {
        case .pregame, .live, .periodBreak: return "Hole \(state.hole) of \(config.holes) · Par 3"
        case .final: return "Final"
        }
    }

    var statusTone: StatusTone {
        switch state.phase {
        case .pregame: return .idle
        case .live, .periodBreak: return .live
        case .final: return .final
        }
    }

    /// The bottom button: next hole, or finish on the last one.
    var nextTitle: String { isLastHole ? "Finish Round" : "Next Hole" }

    /// This hole's score for a player, and its golf name ("Birdie", "Hole in One").
    func holeScore(_ player: Int) -> HoleCard { state.card(player) }

    func holeTerm(_ player: Int) -> String? {
        let card = state.card(player)
        return card.isFinished ? GolfTerm.name(strokes: card.strokes) : nil
    }

    /// Total against par, e.g. "+2", "E", "−1".
    func parText(_ player: Int) -> String { GolfTerm.relative(state.relativeToPar(player)) }

    /// Running total including the hole in progress.
    func totalText(_ player: Int) -> String { "\(state.total(player))" }

    var winnerNames: [String] { state.leaders.map { config.playerName($0) } }

    /// The final leaderboard as a short message for sharing.
    var shareText: String {
        var lines = ["Bucket Golf · \(config.holes) holes · par \(config.coursePar)"]
        for (place, player) in state.standings.enumerated() {
            lines.append("\(place + 1). \(config.playerName(player)) \(state.total(player)) (\(parText(player)))")
        }
        lines.append("")
        lines.append("Kept with All-Sports Scoreboard: \(ShareResultButton.siteURL)")
        return lines.joined(separator: "\n")
    }

    var standingsSummary: String {
        state.standings.map { "\(config.playerName($0)) \(state.total($0)) (\(parText($0)))" }.joined(separator: " · ")
    }

    // MARK: - Scoring the current hole

    static let maxSwings = 15
    static let maxHazards = 9

    /// Swings for a player on this hole (the stepper).
    func adjustSwings(_ player: Int, by delta: Int) {
        guard state.phase != .final, state.cards.indices.contains(player) else { return }
        let current = state.card(player)
        let next = min(max(current.swings + delta, 0), Self.maxSwings)
        guard next != current.swings else {
            environment.feedback(.denied)
            return
        }
        edit(player) { card in
            card.swings = next
            // No swings means no hole yet: clear the extras too.
            if next == 0 {
                card.inBucket = false
                card.hazards = 0
            }
        }
        environment.feedback(.tap)
    }

    /// In the Bucket (−1). Turning it on with no swings entered counts the swing that went in.
    func toggleBucket(_ player: Int) {
        guard state.phase != .final, state.cards.indices.contains(player) else { return }
        let turningOn = !state.card(player).inBucket
        edit(player) { card in
            card.inBucket = turningOn
            if turningOn { card.swings = max(card.swings, 1) }
        }
        if turningOn {
            showFlash("IN THE BUCKET −1", positive: true)
            environment.feedback(.score(3))
        } else {
            environment.feedback(.tap)
        }
    }

    /// Hazards (+1 each). A hazard means at least one swing was taken.
    func adjustHazards(_ player: Int, by delta: Int) {
        guard state.phase != .final, state.cards.indices.contains(player) else { return }
        let current = state.card(player)
        let next = min(max(current.hazards + delta, 0), Self.maxHazards)
        guard next != current.hazards else {
            environment.feedback(.denied)
            return
        }
        edit(player) { card in
            card.hazards = next
            if next > 0 { card.swings = max(card.swings, 1) }
        }
        environment.feedback(.tap)
    }

    func previousHole() {
        guard state.phase != .final, state.hole > 1 else { return }
        update { $0.hole -= 1 }
        environment.feedback(.periodChange)
    }

    /// Next hole, or finish the round on the last one.
    func nextHole() {
        guard state.phase != .final else { return }
        if isLastHole {
            finishRound()
            return
        }
        update { s in
            s.hole += 1
            if s.phase == .pregame { s.phase = .live }
        }
        environment.feedback(.periodChange)
    }

    func finishRound() {
        guard state.phase != .final else { return }
        update { $0.phase = .final }
        environment.feedback(.gameEnd)
        environment.recordResult(state, standingsSummary)
    }

    private func edit(_ player: Int, _ change: (inout HoleCard) -> Void) {
        let limit = undoLimit
        update { s in
            Self.pushUndo(&s, limit: limit)
            if s.phase == .pregame { s.phase = .live }
            change(&s.cards[player][s.hole - 1])
        }
        bump += 1
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

    func endGame() { finishRound() }

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
