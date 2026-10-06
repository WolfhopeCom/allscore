import Foundation

enum ClockDirection: String, Codable, CaseIterable, Identifiable {
    case countDown
    case countUp

    var id: String { rawValue }
    var displayName: String { self == .countDown ? "Count Down" : "Count Up" }
}

/// One scoring button, e.g. "+3 Three", "Point", or "10-9 Round".
struct ScoreAction: Identifiable, Hashable {
    let points: Int
    let caption: String
    let label: String?

    init(points: Int, caption: String, label: String? = nil) {
        self.points = points
        self.caption = caption
        self.label = label
    }

    var id: String { "\(points)-\(caption)" }
    var title: String { label ?? "+\(points)" }
}

/// How a sport turns "a team scored" into a scoreboard.
enum ScoringModel {
    /// Running point totals over timed periods (basketball, soccer, custom…).
    case points
    /// Points win sets; sets win the match (volleyball, table tennis, badminton).
    case rally
    /// 15-30-40 games, sets, tiebreaks.
    case tennis
    /// Runs, innings, outs and the count.
    case baseball
    /// Timed rounds with optional 10-point-must scorecards.
    case combat

    /// Scoring can move these sports to a new set / half-inning, so undo must restore it.
    var undoRestoresFlow: Bool {
        switch self {
        case .rally, .tennis, .baseball: return true
        case .points, .combat: return false
        }
    }
}

struct RallyFormat {
    enum Serve {
        /// Whoever wins the rally serves next (volleyball, badminton).
        case winnerServes
        /// Serve changes every `every` points, then every point at deuce (table tennis).
        case alternating(every: Int)
    }

    enum NextSetServer {
        case alternate
        case previousWinner
    }

    let pointsToWin: Int
    let decidingSetPoints: Int
    let winBy: Int
    /// Hard cap (badminton: first to 30 wins at 29-29).
    let cap: Int?
    let serve: Serve
    let nextSetServer: NextSetServer
    /// Only the serving side can score; losing a rally passes the serve (pickleball).
    var sideOut = false
    /// Side-out doubles: each team gets a first and second server.
    var doubles = false
}

/// A per-team tally shown under the team name: fouls, timeouts, and so on.
struct TeamCounterSpec: Identifiable, Hashable {
    enum Reset: Hashable {
        case never
        case everyPeriod
        /// At the start of the second half and of every overtime period.
        case everyHalf
    }

    enum Style: Hashable {
        case number
        case dots
    }

    let id: String
    let title: String
    let shortTitle: String
    let initialValue: Int
    let range: ClosedRange<Int>
    /// What a tap does: +1 records a foul, −1 uses a timeout.
    let tapDelta: Int
    let reset: Reset
    let style: Style
    /// When the value reaches this, show `highlightLabel` (e.g. 5 fouls → BONUS).
    let highlightAt: Int?
    let highlightLabel: String?
}

struct SportDefaults {
    var teamA: TeamConfig
    var teamB: TeamConfig
    var periodLength: TimeInterval
    var periodCount: Int
    var overtimeLength: TimeInterval
    var clockEnabled: Bool = true
    var pointsToWin: Int = 0
    var restLength: TimeInterval = 60
    var doubles = true
    var rallyScoring = false
}

/// Everything that makes one sport different from another. The scoreboard engine and the
/// UI only ever talk to this protocol, so adding a sport means adding one small type.
protocol SportRules {
    var kind: SportKind { get }
    var name: String { get }
    var symbolName: String { get }
    var summary: String { get }
    var defaults: SportDefaults { get }

    // Periods
    var periodName: String { get }
    var periodNamePlural: String { get }
    var periodCountOptions: [Int] { get }
    var allowsOvertime: Bool { get }
    var overtimeName: String { get }
    func periodLabel(_ period: Int, regulation: Int) -> String
    func periodTitle(_ period: Int, regulation: Int) -> String
    func breakTitle(after period: Int, regulation: Int) -> String

    // Clock
    var clockDirection: ClockDirection { get }
    var clockRunsPastLength: Bool { get }
    /// Count-up match clocks that carry on between periods (soccer's 2nd half starts at 45:00).
    var continuousMatchClock: Bool { get }
    var showsTenths: Bool { get }
    var warningThreshold: TimeInterval? { get }

    // Scoring
    var scoringActions: [ScoreAction] { get }
    var tapPoints: Int { get }
    var subtractPoints: Int { get }
    var counters: [TeamCounterSpec] { get }
    var tracksPossession: Bool { get }
    var possessionName: String { get }

    // Match-style sports
    var model: ScoringModel { get }
    var rallyFormat: RallyFormat? { get }
    var allowsSubtract: Bool { get }
    var allowsSwapSides: Bool { get }
    /// Small label above the big number ("SCORECARD"), when the number needs explaining.
    var scoreCaption: String? { get }
    /// Possession arrows in the center panel (hidden when the engine sets it, e.g. baseball).
    var showsPossessionControl: Bool { get }

    /// Ways to win before the final buzzer, offered in the period menu ("KO/TKO", "Fall").
    var stoppageMethods: [String] { get }
    /// A lead this large ends the match on the spot (wrestling technical fall).
    var mercyMargin: Int? { get }
    /// The first score in overtime wins (wrestling sudden victory).
    var suddenVictoryOvertime: Bool { get }
}

extension SportRules {
    var periodNamePlural: String { periodName + "s" }
    var periodCountOptions: [Int] { [defaults.periodCount] }
    var allowsOvertime: Bool { true }
    var overtimeName: String { "Overtime" }

    /// Sports without a game clock (volleyball, tennis, baseball…) never read this.
    var clockDirection: ClockDirection { .countDown }
    var clockRunsPastLength: Bool { false }
    var continuousMatchClock: Bool { false }
    var showsTenths: Bool { false }
    var warningThreshold: TimeInterval? { 10 }

    var tapPoints: Int { scoringActions.first?.points ?? 1 }
    var subtractPoints: Int { 1 }
    var counters: [TeamCounterSpec] { [] }
    var tracksPossession: Bool { false }
    var possessionName: String { "Poss" }

    var model: ScoringModel { .points }
    var rallyFormat: RallyFormat? { nil }
    var allowsSubtract: Bool { true }
    var allowsSwapSides: Bool { true }
    var scoreCaption: String? { nil }
    var showsPossessionControl: Bool { tracksPossession }
    var stoppageMethods: [String] { [] }
    var mercyMargin: Int? { nil }
    var suddenVictoryOvertime: Bool { false }

    /// Compact scoreboard label: "Q3", "OT", "2OT".
    func periodLabel(_ period: Int, regulation: Int) -> String {
        if period <= regulation {
            return "\(periodName.prefix(1).uppercased())\(period)"
        }
        let overtime = period - regulation
        return overtime == 1 ? "OT" : "\(overtime)OT"
    }

    /// Spoken / button title: "3rd Quarter", "Overtime", "2nd Overtime".
    func periodTitle(_ period: Int, regulation: Int) -> String {
        if period <= regulation {
            return "\(Ordinal.string(period)) \(periodName)"
        }
        let overtime = period - regulation
        return overtime == 1 ? overtimeName : "\(Ordinal.string(overtime)) \(overtimeName)"
    }

    func breakTitle(after period: Int, regulation: Int) -> String {
        if regulation > 1, regulation % 2 == 0, period == regulation / 2 { return "Halftime" }
        if period == regulation { return "End of Regulation" }
        return "End of \(periodLabel(period, regulation: regulation))"
    }
}
