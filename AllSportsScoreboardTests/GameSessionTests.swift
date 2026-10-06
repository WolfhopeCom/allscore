import XCTest
@testable import AllSportsScoreboard

@MainActor
final class GameSessionTests: XCTestCase {
    private func makeSession(
        _ sport: SportKind = .basketball,
        configure: (inout GameConfig) -> Void = { _ in }
    ) -> GameSession {
        var config = SportCatalog.defaultConfig(for: sport)
        configure(&config)
        return GameSession(state: GameState(config: config), environment: .silent)
    }

    private func counter(_ id: String, in session: GameSession) -> TeamCounterSpec {
        session.rules.counters.first { $0.id == id }!
    }

    // MARK: Scoring

    func testScoringAndUndo() {
        let session = makeSession()
        session.addPoints(3, to: .a)
        session.addPoints(2, to: .b)
        XCTAssertEqual(session.score(.a), 3)
        XCTAssertEqual(session.score(.b), 2)
        XCTAssertEqual(session.phase, .live)

        session.undo()
        XCTAssertEqual(session.score(.b), 0)
        XCTAssertEqual(session.score(.a), 3)
        session.undo()
        XCTAssertEqual(session.score(.a), 0)
        XCTAssertFalse(session.canUndo)
    }

    func testTapUsesSportDefault() {
        let basketball = makeSession(.basketball)
        basketball.addTapPoints(to: .a)
        XCTAssertEqual(basketball.score(.a), 2)

        let custom = makeSession(.custom) { $0.customIncrement = 5 }
        custom.addTapPoints(to: .b)
        XCTAssertEqual(custom.score(.b), 5)
    }

    func testSubtractNeverGoesBelowZero() {
        let session = makeSession(.soccer)
        session.subtractPoints(from: .a)
        XCTAssertEqual(session.score(.a), 0)
        session.addPoints(1, to: .a)
        session.subtractPoints(from: .a)
        session.subtractPoints(from: .a)
        XCTAssertEqual(session.score(.a), 0)
    }

    func testSwapSidesMovesEverything() {
        let session = makeSession()
        session.updateTeams(TeamConfig(name: "Lakers", color: .purple), TeamConfig(name: "Celtics", color: .green))
        session.addPoints(3, to: .a)
        session.adjustCounter(counter("fouls", in: session), side: .a, by: 1)
        session.setPossession(.a)

        session.swapSides()
        XCTAssertEqual(session.teamName(.b), "Lakers")
        XCTAssertEqual(session.score(.b), 3)
        XCTAssertEqual(session.score(.a), 0)
        XCTAssertEqual(session.counter(counter("fouls", in: session), .b), 1)
        XCTAssertEqual(session.state.possession, .b)
    }

    // MARK: Counters

    func testFoulsResetEveryQuarter() {
        let session = makeSession(.basketball)
        let fouls = counter("fouls", in: session)
        session.adjustCounter(fouls, side: .a, by: 1)
        session.adjustCounter(fouls, side: .a, by: 1)
        XCTAssertEqual(session.counter(fouls, .a), 2)
        session.advancePeriod()
        XCTAssertEqual(session.counter(fouls, .a), 0)
    }

    func testTimeoutsResetAtHalftimeAndOvertime() {
        let session = makeSession(.football)
        let timeouts = counter("timeouts", in: session)
        session.adjustCounter(timeouts, side: .a, by: -1)
        session.adjustCounter(timeouts, side: .a, by: -1)
        XCTAssertEqual(session.counter(timeouts, .a), 1)

        session.advancePeriod() // Q2: no reset
        XCTAssertEqual(session.counter(timeouts, .a), 1)

        session.advancePeriod() // Q3: second half
        XCTAssertEqual(session.counter(timeouts, .a), 3)

        session.adjustCounter(timeouts, side: .a, by: -1)
        session.advancePeriod() // Q4
        XCTAssertEqual(session.counter(timeouts, .a), 2)
        session.advancePeriod() // OT
        XCTAssertEqual(session.counter(timeouts, .a), 3)
    }

    func testCountersRespectTheirRange() {
        let session = makeSession(.football)
        let timeouts = counter("timeouts", in: session)
        session.adjustCounter(timeouts, side: .b, by: 1)
        XCTAssertEqual(session.counter(timeouts, .b), 3)
    }

    // MARK: Clock & game flow

    func testExpiryInLastPeriodEndsGameWhenNotTied() {
        let session = makeSession(.basketball)
        session.setPeriod(4, resetClock: true)
        session.addPoints(2, to: .a)
        session.startClock()
        session.tick(at: Date().addingTimeInterval(13 * 60), silent: true)
        XCTAssertEqual(session.phase, .final)
        XCTAssertEqual(session.primaryAction, .newGame)
    }

    func testExpiryWhenTiedGoesToOvertime() {
        let session = makeSession(.basketball)
        session.setPeriod(4, resetClock: true)
        session.startClock()
        session.tick(at: Date().addingTimeInterval(13 * 60), silent: true)
        XCTAssertEqual(session.phase, .periodBreak)
        XCTAssertEqual(session.statusText, "End of Regulation")

        session.performPrimary()
        XCTAssertEqual(session.period, 5)
        XCTAssertEqual(session.periodLabel, "OT")
        XCTAssertTrue(session.isClockRunning)
        XCTAssertEqual(session.state.clock.length, 5 * 60)
    }

    func testExpiryMidGameIsABreak() {
        let session = makeSession(.hockey)
        session.startClock()
        session.tick(at: Date().addingTimeInterval(21 * 60), silent: true)
        XCTAssertEqual(session.phase, .periodBreak)
        XCTAssertEqual(session.primaryAction, .startPeriod("2nd Period"))
    }

    func testHalftimeLabel() {
        let session = makeSession(.basketball)
        session.setPeriod(2, resetClock: true)
        session.startClock()
        session.tick(at: Date().addingTimeInterval(13 * 60), silent: true)
        XCTAssertEqual(session.statusText, "Halftime")
    }

    func testSoccerClockRunsIntoStoppageAndContinuesAcrossHalves() {
        let session = makeSession(.soccer)
        session.startClock()
        let later = Date().addingTimeInterval(46 * 60)
        session.tick(at: later, silent: true)
        XCTAssertEqual(session.phase, .live)

        let reading = session.clockReading(at: later)
        XCTAssertEqual(reading.text, "45:00")
        XCTAssertNotNil(reading.stoppage)

        session.endPeriod()
        XCTAssertEqual(session.statusText, "Halftime")
        session.performPrimary()
        XCTAssertEqual(session.period, 2)
        XCTAssertEqual(session.clockReading(at: Date()).text, "45:00")
    }

    func testEndGameAndReopen() {
        let session = makeSession()
        session.addPoints(2, to: .b)
        session.endGame()
        XCTAssertEqual(session.phase, .final)
        XCTAssertEqual(session.state.leader, .b)

        session.addPoints(2, to: .a)
        XCTAssertEqual(session.score(.a), 0, "Final games can't be scored")

        session.reopen()
        XCTAssertEqual(session.phase, .live)
        session.addPoints(2, to: .a)
        XCTAssertEqual(session.score(.a), 2)
    }

    func testCustomGameWithoutClock() {
        let session = makeSession(.custom) { config in
            config.clockEnabled = false
            config.periodCount = 1
        }
        XCTAssertEqual(session.primaryAction, .startGame("Start Game"))
        session.performPrimary()
        XCTAssertEqual(session.phase, .live)
        session.addPoints(1, to: .a)
        XCTAssertEqual(session.primaryAction, .endGame)
        session.performPrimary()
        XCTAssertEqual(session.phase, .final)
    }

    func testResetStartsFresh() {
        let session = makeSession()
        session.addPoints(3, to: .a)
        session.advancePeriod()
        session.resetGame()
        XCTAssertEqual(session.score(.a), 0)
        XCTAssertEqual(session.period, 1)
        XCTAssertEqual(session.phase, .pregame)
        XCTAssertFalse(session.canUndo)
    }

    func testStateRoundTripsThroughJSON() throws {
        let session = makeSession(.football)
        session.addPoints(6, to: .a)
        session.startClock()
        let data = try JSONEncoder().encode(session.state)
        let restored = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(restored, session.state)
    }
}
