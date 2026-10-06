import XCTest
@testable import AllSportsScoreboard

@MainActor
final class MatchSportsTests: XCTestCase {
    private func makeSession(
        _ sport: SportKind,
        configure: (inout GameConfig) -> Void = { _ in }
    ) -> GameSession {
        var config = SportCatalog.defaultConfig(for: sport)
        configure(&config)
        return GameSession(state: GameState(config: config), environment: .silent)
    }

    private func points(_ session: GameSession, _ side: TeamSide, _ count: Int) {
        for _ in 0..<count { session.addTapPoints(to: side) }
    }

    // MARK: Volleyball

    func testVolleyballSetNeedsTwoPointLead() {
        let session = makeSession(.volleyball)
        points(session, .a, 24)
        points(session, .b, 24)
        session.addTapPoints(to: .a)
        XCTAssertEqual(session.scoreText(.a), "25", "25-24 is not a set")
        XCTAssertEqual(session.score(.a), 0)
        session.addTapPoints(to: .a)
        XCTAssertEqual(session.score(.a), 1, "26-24 wins the set")
        XCTAssertEqual(session.period, 2)
        XCTAssertEqual(session.scoreText(.a), "0")
        XCTAssertEqual(session.completedSetLines, ["26–24"])
    }

    func testVolleyballMatchAndDecidingSetTo15() {
        let session = makeSession(.volleyball)
        for _ in 0..<2 { points(session, .a, 25) }
        for _ in 0..<2 { points(session, .b, 25) }
        XCTAssertEqual(session.period, 5)
        points(session, .b, 14)
        XCTAssertEqual(session.phase, .live)
        session.addTapPoints(to: .b)
        XCTAssertEqual(session.phase, .final)
        XCTAssertEqual(session.state.winner, .b)
        XCTAssertEqual(session.resultSummary, "25–0, 25–0, 0–25, 0–25, 0–15")
    }

    func testVolleyballWinnerServes() {
        let session = makeSession(.volleyball)
        session.addTapPoints(to: .b)
        XCTAssertEqual(session.state.possession, .b)
        session.addTapPoints(to: .a)
        XCTAssertEqual(session.state.possession, .a)
    }

    func testUndoAcrossSetBoundary() {
        let session = makeSession(.volleyball)
        points(session, .a, 25)
        XCTAssertEqual(session.period, 2)
        session.undo()
        XCTAssertEqual(session.period, 1)
        XCTAssertEqual(session.score(.a), 0)
        XCTAssertEqual(session.scoreText(.a), "24")
    }

    // MARK: Table tennis

    func testTableTennisServeRotation() {
        let session = makeSession(.tableTennis)
        XCTAssertEqual(session.state.possession, .a)
        session.addTapPoints(to: .b)
        XCTAssertEqual(session.state.possession, .a, "Two serves each")
        session.addTapPoints(to: .b)
        XCTAssertEqual(session.state.possession, .b)
        // Reach 10-10: serve then changes every point.
        points(session, .a, 10)
        points(session, .b, 8)
        XCTAssertEqual(session.scoreText(.a), "10")
        XCTAssertEqual(session.scoreText(.b), "10")
        let atDeuce = session.state.possession
        session.addTapPoints(to: .a)
        XCTAssertNotEqual(session.state.possession, atDeuce)
        session.addTapPoints(to: .b)
        XCTAssertEqual(session.state.possession, atDeuce)
    }

    func testManualServerChangeSticks() {
        let session = makeSession(.tableTennis)
        session.setPossession(.b)
        session.addTapPoints(to: .a)
        XCTAssertEqual(session.state.possession, .b, "The chosen server keeps serving")
    }

    // MARK: Badminton

    func testBadmintonCapAt30() {
        let session = makeSession(.badminton)
        for _ in 0..<29 {
            session.addTapPoints(to: .a)
            session.addTapPoints(to: .b)
        }
        XCTAssertEqual(session.scoreText(.a), "29")
        session.addTapPoints(to: .b)
        XCTAssertEqual(session.score(.b), 1, "30-29 wins at the cap")
    }

    // MARK: Pickleball

    func testPickleballSideOutDoubles() {
        let session = makeSession(.pickleball)
        XCTAssertEqual(session.pickleballCall, "0–0–2", "Games start at 0-0-2")
        session.addTapPoints(to: .b)               // receiver wins: side out
        XCTAssertEqual(session.state.possession, .b)
        XCTAssertEqual(session.pickleballCall, "0–0–1")
        XCTAssertEqual(session.scoreText(.b), "0", "Receivers can't score")
        session.addTapPoints(to: .b)               // server scores
        XCTAssertEqual(session.scoreText(.b), "1")
        XCTAssertEqual(session.pickleballCall, "1–0–1")
        session.addTapPoints(to: .a)               // fault: to server 2
        XCTAssertEqual(session.state.possession, .b)
        XCTAssertEqual(session.pickleballCall, "1–0–2")
        session.addTapPoints(to: .a)               // fault: side out
        XCTAssertEqual(session.state.possession, .a)
        XCTAssertEqual(session.pickleballCall, "0–1–1")
        session.undo()
        XCTAssertEqual(session.pickleballCall, "1–0–2", "Undo restores the server")
    }

    func testPickleballGameTo11WinBy2() {
        let session = makeSession(.pickleball)
        session.addTapPoints(to: .b) // side out to B (0-0-2 start)
        points(session, .b, 10)
        XCTAssertEqual(session.scoreText(.b), "10")
        session.addTapPoints(to: .b)
        XCTAssertEqual(session.phase, .final, "Single game to 11")
        XCTAssertEqual(session.state.winner, .b)
    }

    func testPickleballSinglesAndRallyScoring() {
        let singles = makeSession(.pickleball) { $0.doubles = false }
        XCTAssertEqual(singles.pickleballCall, "0–0")
        singles.addTapPoints(to: .b)
        XCTAssertEqual(singles.state.possession, .b, "Singles: one fault is a side out")

        let rally = makeSession(.pickleball) { $0.rallyScoring = true }
        rally.addTapPoints(to: .b)
        XCTAssertEqual(rally.scoreText(.b), "1", "Rally scoring: every rally scores")
        XCTAssertNil(rally.pickleballCall)
    }

    // MARK: Tennis

    func testTennisPointsAndDeuce() {
        let session = makeSession(.tennis)
        session.addTapPoints(to: .a)
        XCTAssertEqual(session.scoreText(.a), "15")
        points(session, .a, 2)
        points(session, .b, 3)
        XCTAssertEqual(session.tennisCall, "DEUCE")
        session.addTapPoints(to: .a)
        XCTAssertEqual(session.scoreText(.a), "AD")
        XCTAssertEqual(session.scoreText(.b), "40")
        session.addTapPoints(to: .b)
        XCTAssertEqual(session.tennisCall, "DEUCE")
        points(session, .b, 2)
        XCTAssertEqual(session.state.match.games, [0, 1])
        XCTAssertEqual(session.state.possession, .b, "Serve changes every game")
    }

    func testTennisTiebreakAndMatch() {
        let session = makeSession(.tennis) { $0.periodCount = 1 }
        for _ in 0..<6 {
            points(session, .a, 4)
            points(session, .b, 4)
        }
        XCTAssertTrue(session.state.match.inTiebreak)
        points(session, .a, 6)
        points(session, .b, 6)
        XCTAssertEqual(session.phase, .live)
        points(session, .a, 2)
        XCTAssertEqual(session.phase, .final)
        XCTAssertEqual(session.resultSummary, "7–6 (8–6)")
    }

    func testTennisCannotSubtract() {
        let session = makeSession(.tennis)
        session.addTapPoints(to: .a)
        session.subtractPoints(from: .a)
        XCTAssertEqual(session.scoreText(.a), "15")
    }

    // MARK: Baseball

    func testBaseballCountAndHalfInnings() {
        let session = makeSession(.baseball)
        session.recordPitch(.strike)
        session.recordPitch(.foul)
        session.recordPitch(.foul)
        XCTAssertEqual(session.state.match.strikes, 2, "Fouls don't make a third strike")
        session.recordPitch(.strike)
        XCTAssertEqual(session.state.match.outs, 1)
        for _ in 0..<4 { session.recordPitch(.ball) }
        XCTAssertEqual(session.state.match.balls, 0, "Ball four is a walk")
        session.recordPitch(.out)
        session.recordPitch(.out)
        XCTAssertTrue(session.state.match.isBottom)
        XCTAssertEqual(session.battingSide, .b)
        XCTAssertEqual(session.periodLabel, "▼1")
        session.endHalfInning()
        XCTAssertEqual(session.period, 2)
        XCTAssertEqual(session.periodLabel, "▲2")
    }

    func testHomeTeamSkipsBottomOfNinthWhenAhead() {
        let session = makeSession(.baseball)
        session.setPeriod(9, resetClock: true)
        session.addPoints(1, to: .b)
        session.endHalfInning()
        XCTAssertEqual(session.phase, .final)
        XCTAssertEqual(session.state.winner, .b)
    }

    func testWalkOff() {
        let session = makeSession(.baseball)
        session.setPeriod(9, resetClock: true)
        session.addPoints(1, to: .a)
        session.endHalfInning()
        session.addPoints(1, to: .b)
        XCTAssertEqual(session.phase, .live)
        session.addPoints(1, to: .b)
        XCTAssertEqual(session.phase, .final)
    }

    func testExtraInningsWhenTied() {
        let session = makeSession(.baseball)
        session.setPeriod(9, resetClock: true)
        session.endHalfInning()
        session.endHalfInning()
        XCTAssertEqual(session.period, 10)
        XCTAssertEqual(session.phase, .live)
    }

    func testLineScoreTracksRunsPerInning() {
        let session = makeSession(.baseball)
        session.addPoints(2, to: .a)
        session.endHalfInning()
        session.endHalfInning()
        session.addPoints(1, to: .a)
        XCTAssertEqual(session.state.match.lineScore[0], [2, 1])
        session.subtractPoints(from: .a)
        XCTAssertEqual(session.state.match.lineScore[0], [2, 0])
    }

    // MARK: Boxing / MMA

    func testScorecardsAndDecision() {
        let session = makeSession(.boxing)
        session.addPoints(1, to: .a)              // R1 10-9 red
        XCTAssertEqual(session.score(.a), 10)
        XCTAssertEqual(session.score(.b), 9)
        session.addPoints(2, to: .a)              // re-score R1 10-8
        XCTAssertEqual(session.score(.b), 8, "Re-scoring a round replaces it")
        session.advancePeriod()
        session.scoreRound(winner: nil, margin: 0) // R2 even
        XCTAssertEqual(session.score(.a), 20)
        XCTAssertEqual(session.score(.b), 18)
    }

    func testRestTimerStartsBetweenRounds() {
        let session = makeSession(.boxing)
        session.startClock()
        session.tick(at: Date().addingTimeInterval(3 * 60 + 1), silent: true)
        XCTAssertEqual(session.phase, .periodBreak)
        XCTAssertTrue(session.state.match.resting)
        XCTAssertTrue(session.isClockRunning)
        XCTAssertEqual(session.statusText, "Rest")
        session.tick(at: Date().addingTimeInterval(3 * 60 + 62), silent: true)
        XCTAssertFalse(session.state.match.resting)
        XCTAssertEqual(session.primaryAction, .startPeriod("Round 2"))
        session.performPrimary()
        XCTAssertEqual(session.period, 2)
        XCTAssertTrue(session.isClockRunning)
        XCTAssertEqual(session.state.clock.length, 3 * 60)
    }

    func testStartingNextRoundDuringRestCancelsRest() {
        let session = makeSession(.boxing)
        session.startClock()
        session.tick(at: Date().addingTimeInterval(3 * 60 + 1), silent: true)
        session.performPrimary()
        XCTAssertFalse(session.state.match.resting)
        XCTAssertEqual(session.phase, .live)
        XCTAssertEqual(session.state.clock.length, 3 * 60)
    }

    func testKnockout() {
        let session = makeSession(.boxing)
        session.addPoints(1, to: .a)
        session.declareWinner(.b, method: "KO/TKO")
        XCTAssertEqual(session.phase, .final)
        XCTAssertEqual(session.state.winner, .b, "Stoppage beats the scorecards")
        XCTAssertEqual(session.resultSummary, "KO/TKO · Round 1")
        session.reopen()
        XCTAssertNil(session.state.declaredWinner)
    }

    func testFinalRoundEndsFight() {
        let session = makeSession(.boxing) { $0.periodCount = 1 }
        session.startClock()
        session.tick(at: Date().addingTimeInterval(3 * 60 + 1), silent: true)
        XCTAssertEqual(session.phase, .final)
    }
}
