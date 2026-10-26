import XCTest
@testable import AllSportsScoreboard

@MainActor
final class TimeoutTests: XCTestCase {
    private func session(_ sport: SportKind, _ configure: (inout GameConfig) -> Void = { _ in }) -> GameSession {
        var config = SportCatalog.defaultConfig(for: sport)
        configure(&config)
        return GameSession(state: GameState(config: config), environment: .silent)
    }

    private func timeouts(_ s: GameSession, _ side: TeamSide = .a) -> Int {
        s.state.counter("timeouts", side)
    }

    private func useTimeout(_ s: GameSession, _ side: TeamSide = .a) {
        let spec = s.rules.counters.first { $0.id == "timeouts" }!
        s.adjustCounter(spec, side: side, by: spec.tapDelta)
    }

    func testEachSportStartsWithItsTimeouts() {
        XCTAssertEqual(timeouts(session(.basketball)), 5)
        XCTAssertEqual(timeouts(session(.football)), 3)
        XCTAssertEqual(timeouts(session(.hockey)), 1)
        XCTAssertEqual(timeouts(session(.volleyball)), 2)
        XCTAssertEqual(timeouts(session(.tableTennis)), 1)
        XCTAssertEqual(timeouts(session(.pickleball)), 2)
        XCTAssertEqual(timeouts(session(.pickleball) { $0.pointsToWin = 21 }), 3)
        for sport in [SportKind.soccer, .tennis, .badminton, .baseball, .boxing, .wrestling] {
            XCTAssertFalse(session(sport).rules.counters.contains { $0.id == "timeouts" }, "\(sport) has no team timeouts")
        }
    }

    func testBasketballTimeoutsCarryOverAndOvertimeAddsOne() {
        let s = session(.basketball)
        useTimeout(s); useTimeout(s); useTimeout(s)
        XCTAssertEqual(timeouts(s), 2)
        s.setPeriod(3, resetClock: true, playFeedback: false)
        XCTAssertEqual(timeouts(s), 2, "High school timeouts are per game")
        s.setPeriod(5, resetClock: true, playFeedback: false)
        XCTAssertEqual(timeouts(s), 3, "One more in overtime, unused ones carry over")
        XCTAssertEqual(timeouts(s, .b), 6)
    }

    func testFootballGetsThreeEachHalfAndOneInOvertime() {
        let s = session(.football)
        useTimeout(s); useTimeout(s)
        s.setPeriod(3, resetClock: true, playFeedback: false)
        XCTAssertEqual(timeouts(s), 3)
        s.setPeriod(5, resetClock: true, playFeedback: false)
        XCTAssertEqual(timeouts(s), 1)
    }

    func testVolleyballTimeoutsComeBackEachSet() {
        let s = session(.volleyball)
        useTimeout(s); useTimeout(s)
        XCTAssertEqual(timeouts(s), 0)
        for _ in 0..<25 { s.addPoints(1, to: .b) }
        XCTAssertEqual(s.state.period, 2)
        XCTAssertEqual(timeouts(s), 2)
        s.undo()
        XCTAssertEqual(timeouts(s), 0, "Undoing the set point takes the new set's timeouts back too")
    }

    func testOldSavedGamesGetTheNewTally() {
        var state = GameState(config: SportCatalog.defaultConfig(for: .basketball))
        state.counters.removeValue(forKey: "timeouts")
        let s = GameSession(state: state, environment: .silent)
        XCTAssertEqual(timeouts(s), 5)
    }
}
