import XCTest
@testable import AllSportsScoreboard

/// Bugs found in the QA pass. Each test failed before its fix.
@MainActor
final class QARegressionTests: XCTestCase {
    private func makeSession(
        _ sport: SportKind = .basketball,
        configure: (inout GameConfig) -> Void = { _ in }
    ) -> GameSession {
        var config = SportCatalog.defaultConfig(for: sport)
        configure(&config)
        return GameSession(state: GameState(config: config), environment: .silent)
    }

    /// Undoing a basket scored in Q1 after moving to Q2 used to bring back Q1's fouls.
    func testUndoAfterPeriodChangeKeepsNewPeriodFouls() {
        let session = makeSession()
        let fouls = session.rules.counters[0]
        session.adjustCounter(fouls, side: .a, by: 1)
        session.addPoints(2, to: .a)
        session.advancePeriod()
        session.undo()
        XCTAssertEqual(session.score(.a), 0)
        XCTAssertEqual(session.counter(fouls, .a), 0, "Q2 fouls stay at 0")
    }

    /// After the buzzer, putting time back on the clock had no way to resume the period.
    func testTimeAddedAfterBuzzerResumesSamePeriod() {
        let session = makeSession()
        session.startClock()
        session.tick(at: Date().addingTimeInterval(13 * 60), silent: true)
        XCTAssertEqual(session.phase, .periodBreak)
        session.adjustClock(by: 2)
        XCTAssertEqual(session.primaryAction, .resumeClock)
        session.performPrimary()
        XCTAssertEqual(session.phase, .live)
        XCTAssertEqual(session.period, 1)
        XCTAssertTrue(session.isClockRunning)
    }

    /// A late basket that breaks a tie at the end of regulation still offered overtime.
    func testLateScoreAtEndOfRegulationOffersEndGame() {
        let session = makeSession()
        session.setPeriod(4, resetClock: true)
        session.startClock()
        session.tick(at: Date().addingTimeInterval(13 * 60), silent: true)
        XCTAssertEqual(session.primaryAction, .startPeriod("Overtime"))
        session.addPoints(2, to: .a)
        XCTAssertEqual(session.primaryAction, .endGame)
    }

    /// Ending a countdown period by hand left time on the clock, which looked resumable.
    func testManualEndPeriodRunsOutTheClock() {
        let session = makeSession()
        session.startClock()
        session.endPeriod()
        XCTAssertEqual(session.state.clock.remaining(at: Date()), 0)
        XCTAssertEqual(session.primaryAction, .startPeriod("2nd Quarter"))
    }

    /// Runaway tapping could push the score past what the layout can show.
    func testScoreIsCapped() {
        let session = makeSession(.custom) { $0.customIncrement = 100 }
        for _ in 0..<15 { session.addTapPoints(to: .a) }
        XCTAssertEqual(session.score(.a), 999)
    }

    /// Tapping the side that already has possession re-saved state and replayed feedback.
    func testRepeatedPossessionTapIsIgnored() {
        var feedbackCount = 0
        var environment = SessionEnvironment.silent
        environment.feedback = { _ in feedbackCount += 1 }
        let session = GameSession(state: GameState(config: SportCatalog.defaultConfig(for: .basketball)), environment: environment)
        session.setPossession(.a)
        session.setPossession(.a)
        XCTAssertEqual(feedbackCount, 1)
    }

    /// Swapping sides in baseball would put the home team in the top of the inning.
    func testBaseballCannotSwapSides() {
        let session = makeSession(.baseball)
        session.addPoints(1, to: .a)
        session.swapSides()
        XCTAssertEqual(session.teamName(.a), "Away")
        XCTAssertEqual(session.score(.a), 1)
    }

    /// A paused rest timer could not be restarted without skipping straight to the next round.
    func testPausedRestTimerResumes() {
        let session = makeSession(.boxing)
        session.startClock()
        session.tick(at: Date().addingTimeInterval(3 * 60 + 1), silent: true)
        session.pauseClock()
        XCTAssertTrue(session.canStartClock)
        session.startClock()
        XCTAssertEqual(session.phase, .periodBreak, "Still resting, not round 2")
        XCTAssertTrue(session.isClockRunning)
    }

    // MARK: Persistence

    /// A game saved by an earlier version (no match state, no new config fields) must load.
    func testDecodesGameSavedByEarlierVersion() throws {
        let legacy = """
        {"id":"7C9E6679-7425-40DE-944B-E07FC1F90AE7","config":{"sport":"basketball",
        "teamA":{"name":"Lions","color":"orange"},"teamB":{"name":"Hawks","color":"blue"},
        "periodLength":720,"periodCount":4,"overtimeLength":300,"clockEnabled":true,
        "customTitle":"Custom","customPeriodName":"Period","customIncrement":1,"customClockDirection":"countDown"},
        "scores":[48,45],"counters":{"fouls":[3,5]},"period":3,"phase":"live",
        "clock":{"direction":"countDown","length":720,"runsPastLength":false,"banked":433},
        "createdAt":800000000,"undoStack":[]}
        """
        let state = try JSONDecoder().decode(GameState.self, from: Data(legacy.utf8))
        XCTAssertEqual(state.scores, [48, 45])
        XCTAssertEqual(state.period, 3)
        XCTAssertEqual(state.config.teamA.name, "Lions")
        XCTAssertEqual(state.match, MatchState())
        XCTAssertEqual(state.clock.remaining(at: Date()), 287, accuracy: 0.001)
    }

    func testEveryMatchStateRoundTrips() throws {
        for sport in SportCatalog.all {
            let session = makeSession(sport)
            session.addTapPoints(to: .a)
            session.addTapPoints(to: .b)
            let data = try JSONEncoder().encode(session.state)
            let restored = try JSONDecoder().decode(GameState.self, from: data)
            XCTAssertEqual(restored, session.state, "\(sport) state must survive a relaunch")
        }
    }

    func testDamagedConfigIsSanitized() {
        var config = SportCatalog.defaultConfig(for: .custom)
        config.periodCount = 0
        config.customIncrement = -4
        let state = GameState(config: config)
        XCTAssertEqual(state.config.periodCount, 1)
        XCTAssertEqual(state.config.customIncrement, 1)
    }

    /// Every sport must start, score and finish without trapping.
    func testEverySportCanBePlayedToTheEnd() {
        for sport in SportCatalog.all {
            let session = makeSession(sport)
            session.performPrimary()
            for _ in 0..<5 { session.addTapPoints(to: .a) }
            session.undo()
            session.endGame()
            XCTAssertEqual(session.phase, .final, "\(sport)")
            XCTAssertEqual(session.primaryAction, .newGame, "\(sport)")
            session.rematch()
            XCTAssertEqual(session.phase, .pregame, "\(sport)")
        }
    }
}
