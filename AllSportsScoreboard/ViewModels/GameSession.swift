import Foundation
import Observation

/// A short-lived "+3" / "SET" / "WALK" badge shown next to a score after it changes.
struct ScoreFlash: Equatable, Identifiable {
    let id = UUID()
    let side: TeamSide
    let text: String
    let isPositive: Bool
}

/// What a scoreboard clock face should show at a given instant.
struct ClockReading: Equatable {
    var text: String
    var stoppage: String?
    var caption: String?
    var isWarning: Bool
    var spoken: String
}

enum StatusTone {
    case idle, live, paused, intermission, final
}

/// The big context-sensitive button in the control bar.
enum PrimaryAction: Equatable {
    case startGame(String)
    case startClock
    case pauseClock
    case resumeClock
    case startPeriod(String)
    case endPeriod(String)
    case endHalfInning(String)
    case endGame
    case newGame
    /// Nothing sensible to put here (e.g. mid-set in volleyball): the button is hidden.
    case none

    var title: String {
        switch self {
        case .startGame(let title): return title
        case .startClock: return "Start"
        case .pauseClock: return "Pause"
        case .resumeClock: return "Resume"
        case .startPeriod(let name): return "Start \(name)"
        case .endPeriod(let name): return "End \(name)"
        case .endHalfInning(let name): return "End \(name)"
        case .endGame: return "End Game"
        case .newGame: return "New Game"
        case .none: return ""
        }
    }

    var symbolName: String {
        switch self {
        case .startGame, .startClock, .resumeClock, .startPeriod: return "play.fill"
        case .pauseClock: return "pause.fill"
        case .endPeriod, .endHalfInning: return "forward.end.fill"
        case .endGame: return "flag.checkered"
        case .newGame: return "arrow.counterclockwise"
        case .none: return ""
        }
    }

    var isProminent: Bool { self != .pauseClock }
    var isVisible: Bool { self != .none }
}

/// A badge shown under a team name that isn't tappable (sets won, games in the set).
struct TeamBadge: Identifiable, Equatable {
    let title: String
    let value: String
    var id: String { title }
}

/// Side effects the session triggers, injected so the engine is fully unit-testable.
struct SessionEnvironment {
    var feedback: @MainActor (FeedbackEvent) -> Void
    var persist: @MainActor (GameState) -> Void
    var recordResult: @MainActor (GameState, String?) -> Void

    static var live: SessionEnvironment {
        SessionEnvironment(
            feedback: { Feedback.shared.play($0) },
            persist: { SessionStore.save($0) },
            recordResult: { HistoryStore.shared.record($0, summary: $1) }
        )
    }

    static var silent: SessionEnvironment {
        SessionEnvironment(feedback: { _ in }, persist: { _ in }, recordResult: { _, _ in })
    }
}

/// The scoreboard engine. Owns one game's state and every rule about how it changes.
/// Views read from it and call its intent methods; nothing else mutates a game.
///
/// Match-style sports (sets, innings, rounds) live in `GameSession+Match.swift`.
@Observable
@MainActor
final class GameSession: Identifiable {
    let id = UUID()

    private(set) var state: GameState {
        didSet { environment.persist(state) }
    }

    /// Refreshed ~20×/s while the clock runs. Only clock views read it.
    private(set) var now = Date()
    private(set) var flash: ScoreFlash?
    /// Incremented on every score change per side; drives the score pulse animation.
    private(set) var scoreBumps: [Int] = [0, 0]

    @ObservationIgnored let environment: SessionEnvironment
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored let undoLimit = 60
    /// Largest score the board will show; protects layout from runaway taps.
    @ObservationIgnored let maxScore = 999

    init(state: GameState, environment: SessionEnvironment = .live) {
        self.state = state
        self.environment = environment
        // A restored game's clock may have kept running (or expired) while the app was closed.
        tick(at: Date(), silent: true)
        updateTicking()
    }

    // MARK: - Reading

    var config: GameConfig { state.config }
    var rules: any SportRules { SportCatalog.rules(for: state.config) }
    var model: ScoringModel { rules.model }
    var phase: GamePhase { state.phase }
    var period: Int { state.period }
    var clockEnabled: Bool { state.config.clockEnabled }
    var isClockRunning: Bool { state.clock.isRunning }
    var regulationPeriods: Int { max(1, state.config.periodCount) }
    var isOvertime: Bool { state.period > regulationPeriods }
    var showsPeriod: Bool { regulationPeriods > 1 || isOvertime || model == .baseball }
    var canUndo: Bool { !state.undoStack.isEmpty && state.phase != .final }
    var canSwapSides: Bool { rules.allowsSwapSides }

    var isInProgress: Bool {
        switch state.phase {
        case .live, .periodBreak: return true
        case .pregame: return state.hasAnyScore
        case .final: return false
        }
    }

    func score(_ side: TeamSide) -> Int { state.score(side) }
    func teamName(_ side: TeamSide) -> String { state.config.teamName(side) }
    func counter(_ spec: TeamCounterSpec, _ side: TeamSide) -> Int { state.counter(spec.id, side) }

    var periodLabel: String {
        if model == .baseball { return "\(state.match.isBottom ? "▼" : "▲")\(state.period)" }
        return rules.periodLabel(state.period, regulation: regulationPeriods)
    }

    var periodTitle: String {
        if model == .baseball { return "\(state.match.isBottom ? "Bottom" : "Top") of the \(Ordinal.string(state.period))" }
        return rules.periodTitle(state.period, regulation: regulationPeriods)
    }

    var nextPeriodTitle: String { rules.periodTitle(state.period + 1, regulation: regulationPeriods) }

    var statusText: String {
        switch state.phase {
        case .pregame:
            return "Pre-Game"
        case .live:
            if model == .baseball { return periodTitle }
            if !clockEnabled { return "Live" }
            return state.clock.isRunning ? "Live" : "Paused"
        case .periodBreak:
            if model == .combat && state.match.resting { return "Rest" }
            return rules.breakTitle(after: state.period, regulation: regulationPeriods)
        case .final:
            if model == .baseball && isOvertime { return "Final / \(state.period)" }
            if model == .points && isOvertime { return "Final / \(periodLabel)" }
            return "Final"
        }
    }

    var statusTone: StatusTone {
        switch state.phase {
        case .pregame: return .idle
        case .live: return clockEnabled && !state.clock.isRunning ? .paused : .live
        case .periodBreak: return .intermission
        case .final: return .final
        }
    }

    var primaryAction: PrimaryAction {
        if state.phase == .final { return .newGame }

        switch model {
        case .rally, .tennis:
            return state.phase == .pregame ? .startGame("Start Match") : .none
        case .baseball:
            return state.phase == .pregame ? .startGame("Play Ball") : .endHalfInning(periodTitle.replacingOccurrences(of: " of the ", with: " "))
        case .points, .combat:
            break
        }

        switch state.phase {
        case .final:
            return .newGame
        case .periodBreak:
            if model == .points {
                // Time put back on the clock after the buzzer: resume the same period.
                if clockEnabled, state.clock.direction == .countDown, !state.clock.isExpired(at: Date()) {
                    return .resumeClock
                }
                // A late score broke the tie at the end of regulation.
                if state.period >= regulationPeriods, !state.isTied {
                    return .endGame
                }
            }
            return .startPeriod(nextPeriodTitle)
        case .pregame:
            return clockEnabled ? .startClock : .startGame("Start Game")
        case .live:
            if clockEnabled {
                return state.clock.isRunning ? .pauseClock : .resumeClock
            }
            if state.period >= regulationPeriods { return .endGame }
            return .endPeriod(periodTitle)
        }
    }

    func clockReading(at date: Date) -> ClockReading {
        let clock = state.clock
        let rules = self.rules
        let resting = model == .combat && state.match.resting && state.phase == .periodBreak
        let paused = state.phase == .live && !clock.isRunning
        let caption: String? = resting ? "REST" : (paused ? "PAUSED" : nil)

        switch clock.direction {
        case .countDown:
            let remaining = clock.remaining(at: date)
            let tenths = rules.showsTenths && remaining < 60 && !resting
            let threshold = resting ? 10 : rules.warningThreshold
            let warning = clock.hasLimit && (threshold.map { remaining <= $0 } ?? false)
            return ClockReading(
                text: TimeFormat.clock(remaining, roundingUp: true, showTenths: tenths),
                stoppage: nil,
                caption: caption,
                isWarning: warning,
                spoken: "\(TimeFormat.spoken(remaining)) \(resting ? "of rest " : "")remaining"
            )

        case .countUp:
            let elapsed = clock.elapsed(at: date)
            let offset = rules.continuousMatchClock ? matchClockOffset : 0
            if clock.hasLimit, clock.runsPastLength, elapsed > clock.length {
                let extra = elapsed - clock.length
                return ClockReading(
                    text: TimeFormat.clock(offset + clock.length, roundingUp: false, showTenths: false),
                    stoppage: "+" + TimeFormat.clock(extra, roundingUp: false, showTenths: false),
                    caption: nil,
                    isWarning: false,
                    spoken: "\(TimeFormat.spoken(offset + clock.length)) plus \(TimeFormat.spoken(extra)) added time"
                )
            }
            return ClockReading(
                text: TimeFormat.clock(offset + elapsed, roundingUp: false, showTenths: false),
                stoppage: nil,
                caption: caption,
                isWarning: false,
                spoken: "\(TimeFormat.spoken(offset + elapsed)) elapsed"
            )
        }
    }

    /// Where a continuous match clock starts for the current period (45:00 for a 2nd half).
    private var matchClockOffset: TimeInterval {
        let regulation = regulationPeriods
        let current = state.period
        if current <= regulation {
            return Double(current - 1) * config.periodLength
        }
        return Double(regulation) * config.periodLength
            + Double(current - regulation - 1) * config.overtimeLength
    }

    // MARK: - Scoring

    /// The number shown big on a team's panel.
    func scoreText(_ side: TeamSide) -> String {
        switch model {
        case .rally: return "\(state.match.points[side.rawValue])"
        case .tennis: return tennisPointText(side)
        case .points, .baseball, .combat: return "\(state.score(side))"
        }
    }

    func addPoints(_ points: Int, to side: TeamSide) {
        guard state.phase != .final, points > 0 else { return }
        switch model {
        case .rally: rallyPoint(for: side)
        case .tennis: tennisPoint(for: side)
        case .combat: scoreRound(winner: side, margin: points)
        case .points, .baseball: addRegularPoints(points, to: side)
        }
    }

    func addTapPoints(to side: TeamSide) {
        addPoints(rules.tapPoints, to: side)
    }

    private func addRegularPoints(_ points: Int, to side: TeamSide) {
        let current = state.score(side)
        guard current < maxScore else {
            environment.feedback(.denied)
            return
        }
        let amount = min(points, maxScore - current)
        let limit = undoLimit
        let isBaseball = model == .baseball
        let regulation = regulationPeriods
        let mercy = rules.mercyMargin
        let suddenVictory = rules.suddenVictoryOvertime
        var walkOff = false
        var endsMatch = false
        update { s in
            s.pushUndo(limit: limit)
            s.scores[side.rawValue] += amount
            if s.phase == .pregame { s.phase = .live }
            if isBaseball {
                Self.addToLineScore(&s, side: side, runs: amount)
                // Home team takes the lead in the bottom of the last inning (or later): game over.
                if s.match.isBottom, side == .b, s.period >= regulation, s.scores[1] > s.scores[0] {
                    walkOff = true
                    s.phase = .final
                }
            }
            if let mercy, abs(s.scores[0] - s.scores[1]) >= mercy {
                endsMatch = true
                s.declaredWinner = side
                s.resultNote = "Tech Fall"
            } else if suddenVictory, s.period > regulation, s.scores[0] != s.scores[1] {
                endsMatch = true
                s.declaredWinner = side
                s.resultNote = "Sudden Victory"
            }
            if endsMatch {
                s.clock.pause(at: Date())
                s.phase = .final
            }
        }
        scoreBumps[side.rawValue] += 1
        showFlash(side: side, text: "+\(amount)", isPositive: true)
        if walkOff || endsMatch {
            updateTicking()
            completeGame(playSound: true)
        } else {
            environment.feedback(.score(amount))
        }
    }

    func subtractPoints(from side: TeamSide) {
        guard state.phase != .final, rules.allowsSubtract else {
            environment.feedback(.denied)
            return
        }
        let current = model == .rally ? state.match.points[side.rawValue] : state.score(side)
        guard current > 0 else {
            environment.feedback(.denied)
            return
        }
        let amount = min(current, rules.subtractPoints)
        let limit = undoLimit
        let currentModel = model
        update { s in
            s.pushUndo(limit: limit)
            if currentModel == .rally {
                s.match.points[side.rawValue] -= amount
            } else {
                s.scores[side.rawValue] -= amount
                if currentModel == .baseball { Self.addToLineScore(&s, side: side, runs: -amount) }
            }
        }
        scoreBumps[side.rawValue] += 1
        showFlash(side: side, text: "−\(amount)", isPositive: false)
        environment.feedback(.scoreRemoved)
    }

    func adjustCounter(_ spec: TeamCounterSpec, side: TeamSide, by delta: Int) {
        guard state.phase != .final else { return }
        let current = state.counter(spec.id, side)
        let next = min(max(current + delta, spec.range.lowerBound), spec.range.upperBound)
        guard next != current else {
            environment.feedback(.denied)
            return
        }
        let limit = undoLimit
        update { s in
            s.pushUndo(limit: limit)
            var values = s.counters[spec.id] ?? [spec.initialValue, spec.initialValue]
            values[side.rawValue] = next
            s.counters[spec.id] = values
        }
        environment.feedback(.tap)
    }

    func resetCounter(_ spec: TeamCounterSpec, side: TeamSide) {
        let delta = spec.initialValue - state.counter(spec.id, side)
        if delta != 0 { adjustCounter(spec, side: side, by: delta) }
    }

    func setPossession(_ side: TeamSide) {
        guard state.phase != .final, state.possession != side else { return }
        let format = rules.rallyFormat
        let target = state.period >= regulationPeriods && regulationPeriods > 1
            ? (format?.decidingSetPoints ?? 0) : (format?.pointsToWin ?? 0)
        let currentModel = model
        update { s in
            s.possession = side
            switch currentModel {
            case .rally:
                if let format, format.sideOut {
                    // A manual serve change starts that side's turn with its first server
                    // (second server at 0-0, per the start-of-game rule).
                    s.match.serverNumber = format.doubles && s.match.points == [0, 0] && s.match.sets.isEmpty ? 2 : 1
                }
                // Re-anchor the rotation so the next point keeps the server the user chose.
                if let format, case .alternating = format.serve,
                   Self.rallyServer(format: format, match: s.match, target: target, scorer: side) != side {
                    s.match.setFirstServer = s.match.setFirstServer.opponent
                } else if s.match.points == [0, 0] {
                    s.match.setFirstServer = side
                }
            case .tennis:
                if s.match.inTiebreak && s.match.points == [0, 0] { s.match.tiebreakFirstServer = side }
            case .points, .baseball, .combat:
                break
            }
        }
        environment.feedback(.possession)
    }

    func undo() {
        guard canUndo, let snapshot = state.undoStack.last else { return }
        let before = (0...1).map { scoreText(TeamSide(rawValue: $0)!) }
        let flow = model.undoRestoresFlow
        // Undoing a score from an earlier period must not bring back that period's fouls.
        let keepCounters = model == .points && snapshot.period != nil && snapshot.period != state.period
        update { s in
            s.undoStack.removeLast()
            s.restore(snapshot, flow: flow, keepCounters: keepCounters)
        }
        for side in TeamSide.allCases where before[side.rawValue] != scoreText(side) {
            scoreBumps[side.rawValue] += 1
        }
        environment.feedback(.undo)
    }

    // MARK: - Clock

    func performPrimary() {
        switch primaryAction {
        case .startGame: startGame()
        case .startClock, .resumeClock: startClock()
        case .pauseClock: pauseClock()
        case .startPeriod: advancePeriod(startingClock: true)
        case .endPeriod: endPeriod()
        case .endHalfInning: endHalfInning()
        case .endGame: endGame()
        case .newGame: rematch()
        case .none: break
        }
    }

    func startGame() {
        guard state.phase == .pregame else { return }
        update { $0.phase = .live }
        environment.feedback(.timerStart)
    }

    /// Whether the clock can be started from where the game is now.
    var canStartClock: Bool {
        guard clockEnabled, !state.clock.isRunning else { return false }
        switch state.phase {
        case .pregame, .live: return true
        case .periodBreak:
            guard state.clock.direction == .countDown, !state.clock.isExpired(at: Date()) else { return false }
            // Points sports: time was put back after the buzzer. Combat: a paused rest timer.
            return model == .points || (model == .combat && state.match.resting)
        case .final: return false
        }
    }

    func startClock() {
        guard canStartClock else { return }
        let date = Date()
        if state.clock.direction == .countDown && state.clock.isExpired(at: date) {
            finishPeriod(at: date, playSound: true, expired: true)
            return
        }
        let resumesRest = state.phase == .periodBreak && model == .combat
        update { s in
            s.clock.start(at: date)
            if !resumesRest { s.phase = .live }
        }
        now = date
        environment.feedback(.timerStart)
        updateTicking()
    }

    func pauseClock() {
        guard state.clock.isRunning else { return }
        let date = Date()
        update { $0.clock.pause(at: date) }
        now = date
        environment.feedback(.timerPause)
        updateTicking()
    }

    func adjustClock(by delta: TimeInterval) {
        guard clockEnabled, state.phase != .final else { return }
        let date = Date()
        let threshold = rules.warningThreshold
        update { s in
            s.clock.adjust(by: delta, at: date)
            // Re-arm the time cue if the correction moved us back before it.
            switch s.clock.direction {
            case .countDown:
                if let threshold, s.clock.remaining(at: date) > threshold { s.cuedPeriod = nil }
                if s.clock.remaining(at: date) > 10 { s.match.restCued = false }
            case .countUp:
                if !s.clock.isExpired(at: date) { s.cuedPeriod = nil }
            }
        }
        now = date
        environment.feedback(.tap)
    }

    func resetClock() {
        guard clockEnabled, state.phase != .final else { return }
        update { s in
            s.clock.reset()
            s.cuedPeriod = nil
        }
        now = Date()
        updateTicking()
        environment.feedback(.tap)
    }

    /// Called on every display tick, and when the app returns to the foreground.
    func tick(at date: Date = Date(), silent: Bool = false) {
        now = date
        let clock = state.clock
        guard clock.isRunning, clock.hasLimit else { return }

        // Rest between rounds (boxing / MMA).
        if state.phase == .periodBreak {
            guard state.match.resting else { return }
            if clock.isExpired(at: date) {
                let lateness = clock.expiryDate.map { date.timeIntervalSince($0) } ?? 0
                update { s in
                    s.clock.stopAtLength()
                    s.match.resting = false
                }
                updateTicking()
                if !silent && lateness < 2 { environment.feedback(.periodEnd) }
            } else if clock.remaining(at: date) <= 10, !state.match.restCued {
                update { $0.match.restCued = true }
                if !silent { environment.feedback(.warning) }
            }
            return
        }

        switch clock.direction {
        case .countDown:
            if clock.isExpired(at: date) {
                // If time ran out while the app was suspended, don't blast a stale buzzer.
                let lateness = clock.expiryDate.map { date.timeIntervalSince($0) } ?? 0
                finishPeriod(at: date, playSound: !silent && lateness < 2, expired: true)
                return
            }
            if let threshold = rules.warningThreshold,
               clock.remaining(at: date) <= threshold,
               state.cuedPeriod != state.period {
                update { $0.cuedPeriod = $0.period }
                if !silent { environment.feedback(.warning) }
            }

        case .countUp:
            guard clock.isExpired(at: date) else { return }
            if clock.runsPastLength {
                // Regulation time reached: cue once, keep running into stoppage time.
                if state.cuedPeriod != state.period {
                    update { $0.cuedPeriod = $0.period }
                    if !silent { environment.feedback(.warning) }
                }
            } else {
                let lateness = clock.expiryDate.map { date.timeIntervalSince($0) } ?? 0
                finishPeriod(at: date, playSound: !silent && lateness < 2, expired: true)
            }
        }
    }

    func handleBecameActive() {
        tick(at: Date())
    }

    // MARK: - Periods & game flow

    func endPeriod() {
        finishPeriod(at: Date(), playSound: true, expired: false)
    }

    func advancePeriod(startingClock: Bool = false) {
        guard state.phase != .final else { return }
        setPeriod(state.period + 1, resetClock: true, playFeedback: !startingClock)
        if !clockEnabled {
            update { $0.phase = .live }
            if startingClock { environment.feedback(.periodChange) }
        } else if startingClock {
            startClock()
        }
    }

    /// Jumps to a period. Moving forward resets per-period counters (fouls, timeouts).
    func setPeriod(_ newPeriod: Int, resetClock: Bool, playFeedback: Bool = true) {
        let target = max(1, min(newPeriod, regulationPeriods + 9))
        guard target != state.period, state.phase != .final else { return }
        let rules = self.rules
        let config = self.config
        let date = Date()
        update { s in
            let old = s.period
            s.period = target
            if resetClock || s.match.resting {
                let length = config.clockEnabled
                    ? (target > config.periodCount ? config.overtimeLength : config.periodLength)
                    : 0
                s.clock = GameClock(direction: rules.clockDirection, length: length, runsPastLength: rules.clockRunsPastLength)
                s.cuedPeriod = nil
            } else if s.clock.isRunning {
                s.clock.pause(at: date)
            }
            s.match.resting = false
            s.match.restCued = false
            if target > old {
                for spec in rules.counters where Self.shouldReset(spec, from: old, to: target, regulation: config.periodCount) {
                    s.counters[spec.id] = [spec.initialValue, spec.initialValue]
                }
            }
            if s.phase == .periodBreak || s.phase == .pregame { s.phase = .live }
        }
        now = date
        updateTicking()
        if playFeedback { environment.feedback(.periodChange) }
    }

    nonisolated static func shouldReset(_ spec: TeamCounterSpec, from old: Int, to new: Int, regulation: Int) -> Bool {
        switch spec.reset {
        case .never:
            return false
        case .everyPeriod:
            return true
        case .everyHalf:
            let half = max(1, regulation / 2)
            return (old <= half && new > half) || new > regulation
        }
    }

    func endGame() {
        guard state.phase != .final else { return }
        let date = Date()
        update { s in
            s.clock.pause(at: date)
            s.match.resting = false
            s.phase = .final
        }
        now = date
        updateTicking()
        completeGame(playSound: true)
    }

    /// Leaves the final screen to correct something; the game can be finished again.
    func reopen() {
        guard state.phase == .final else { return }
        update { s in
            s.phase = .live
            s.declaredWinner = nil
            s.resultNote = nil
        }
        environment.feedback(.tap)
    }

    func resetGame() {
        replaceState(with: GameState(config: config))
        environment.feedback(.reset)
    }

    /// Same teams and settings, fresh game.
    func rematch() {
        replaceState(with: GameState(config: config))
        environment.feedback(.periodChange)
    }

    func updateTeams(_ teamA: TeamConfig, _ teamB: TeamConfig) {
        update { s in
            s.config.teamA = teamA
            s.config.teamB = teamB
        }
    }

    func swapSides() {
        guard canSwapSides else { return }
        update { $0.swapSides() }
        scoreBumps[0] += 1
        scoreBumps[1] += 1
        environment.feedback(.periodChange)
    }

    /// Stops background work before the session is discarded.
    func shutdown() {
        tickTask?.cancel()
        tickTask = nil
    }

    // MARK: - Shared helpers (also used by GameSession+Match)

    func finishPeriod(at date: Date, playSound: Bool, expired: Bool) {
        guard state.phase == .live || state.phase == .pregame else { return }
        let gameOver = state.period >= regulationPeriods && (!state.isTied || !rules.allowsOvertime)
        let startsRest = !gameOver && model == .combat && config.restLength > 0
        let restLength = config.restLength
        update { s in
            // Ending a countdown period by hand also runs its clock out, so the break
            // can't be mistaken for a "resume" state.
            if expired || s.clock.direction == .countDown {
                s.clock.stopAtLength()
            } else {
                s.clock.pause(at: date)
            }
            s.phase = gameOver ? .final : .periodBreak
            if startsRest {
                s.clock = GameClock(direction: .countDown, length: restLength)
                s.clock.start(at: date)
                s.match.resting = true
                s.match.restCued = false
            }
        }
        now = date
        updateTicking()
        if gameOver {
            completeGame(playSound: playSound)
        } else if playSound {
            environment.feedback(.periodEnd)
        }
    }

    func completeGame(playSound: Bool) {
        environment.recordResult(state, resultSummary)
        if playSound { environment.feedback(.gameEnd) }
    }

    private func replaceState(with newState: GameState) {
        shutdown()
        state = newState
        flash = nil
        now = Date()
    }

    /// Applies several changes as one state write (one save, one UI update).
    func update(_ body: (inout GameState) -> Void) {
        var copy = state
        body(&copy)
        state = copy
    }

    func bumpScore(_ side: TeamSide) {
        scoreBumps[side.rawValue] += 1
    }

    func showFlash(side: TeamSide, text: String, isPositive: Bool) {
        let newFlash = ScoreFlash(side: side, text: text, isPositive: isPositive)
        flash = newFlash
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 900_000_000)
            if self?.flash?.id == newFlash.id { self?.flash = nil }
        }
    }

    func updateTicking() {
        if state.clock.isRunning {
            guard tickTask == nil else { return }
            tickTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    guard self != nil else { return }
                    self?.tick()
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
            }
        } else {
            tickTask?.cancel()
            tickTask = nil
        }
    }
}
