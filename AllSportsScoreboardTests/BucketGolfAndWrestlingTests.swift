import XCTest
@testable import AllSportsScoreboard

@MainActor
final class BucketGolfTests: XCTestCase {
    private func makeSession(players: Int = 2, holes: Int = 3) -> PlayerGameSession {
        var config = PlayerGameConfig.standard
        config.players = Array(config.players.prefix(players))
        config.holes = holes
        return PlayerGameSession(state: PlayerGameState(config: config), environment: .silent)
    }

    // The two worked examples from the rules.

    func testThreeShotsEndingOnTheBucketIsPar() {
        let session = makeSession()
        session.record(.miss)
        session.record(.miss)
        session.record(.contact)
        let card = session.state.card(0)
        XCTAssertTrue(card.isFinished)
        XCTAssertEqual(card.strokes, 3)
        XCTAssertEqual(GolfTerm.name(strokes: card.strokes), "Par")
        XCTAssertEqual(session.parText(0), "E")
    }

    func testThreeShotsEndingInTheBucketIsOneUnder() {
        let session = makeSession()
        session.record(.miss)
        session.record(.miss)
        session.record(.bucketIn)
        XCTAssertEqual(session.state.card(0).strokes, 2)
        XCTAssertEqual(session.parText(0), "−1")
        XCTAssertEqual(GolfTerm.name(strokes: 2), "Birdie")
    }

    func testHazardAddsAPenaltyAndPlayContinues() {
        let session = makeSession()
        session.record(.hazard)
        XCTAssertFalse(session.currentCard.isFinished, "Drop and keep playing")
        XCTAssertEqual(session.currentCard.strokes, 2, "The swing plus one penalty stroke")
        session.record(.contact)
        XCTAssertEqual(session.state.card(0).strokes, 3)
    }

    func testMissesKeepTheHoleOpen() {
        let session = makeSession()
        for _ in 0..<5 { session.record(.miss) }
        XCTAssertFalse(session.currentCard.isFinished)
        XCTAssertEqual(session.currentCard.strokes, 5)
        XCTAssertEqual(session.state.total(0), 5, "Running total includes the hole in progress")
    }

    func testNoShotsAfterTheHoleIsComplete() {
        let session = makeSession(players: 1)
        session.record(.contact)
        session.record(.miss)
        XCTAssertEqual(session.state.card(0).strokes, 1)
    }

    func testFinishingHandsTheTurnToTheNextPlayer() {
        let session = makeSession(players: 3)
        session.record(.contact)
        XCTAssertEqual(session.current, 1)
        XCTAssertEqual(session.primaryTitle, "Next: Player 3")
    }

    func testHonorsBestScoreTeesOffNextHole() {
        let session = makeSession(players: 3)
        session.record(.miss); session.record(.miss); session.record(.contact)   // P1: 3
        session.record(.contact)                                                 // P2: 1
        session.record(.miss); session.record(.contact)                          // P3: 2
        XCTAssertTrue(session.isHoleComplete)
        XCTAssertEqual(session.primaryTitle, "Next Hole: 2")
        session.advance()
        XCTAssertEqual(session.hole, 2)
        XCTAssertEqual(session.state.teeOrder, [1, 2, 0])
        XCTAssertEqual(session.current, 1, "Lowest score on the last hole tees off first")
    }

    func testLowestTotalWinsAfterTheCourse() {
        let session = makeSession(players: 2, holes: 3)
        // On each hole whoever tees off first makes par (3) and the other chips in (2).
        // Honors alternate, so Player 1 shoots 3-2-3 = 8 and Player 2 shoots 2-3-2 = 7.
        for _ in 0..<3 {
            session.record(.miss); session.record(.miss); session.record(.contact)
            session.record(.miss); session.record(.miss); session.record(.bucketIn)
            session.advance()
        }
        XCTAssertEqual(session.phase, .final)
        XCTAssertEqual(session.state.total(0), 8)
        XCTAssertEqual(session.state.total(1), 7)
        XCTAssertEqual(session.winnerNames, ["Player 2"], "Lowest total wins")
        XCTAssertEqual(session.parText(1), "−2")
    }

    func testUndoRemovesTheLastShot() {
        let session = makeSession()
        session.record(.miss)
        session.record(.contact)
        XCTAssertEqual(session.current, 1)
        session.undo()
        XCTAssertEqual(session.current, 0)
        XCTAssertEqual(session.currentCard.shots, [.miss])
    }

    func testSelectingAPlayerForFarthestFromTheBucket() {
        let session = makeSession(players: 3)
        session.record(.miss)
        session.select(player: 2)
        session.record(.miss)
        XCTAssertEqual(session.state.card(2).strokes, 1)
        XCTAssertEqual(session.state.card(0).strokes, 1)
    }

    func testHoleOptionsAndSanitizing() {
        var config = PlayerGameConfig.standard
        config.players = []
        config.holes = 7
        let state = PlayerGameState(config: config)
        XCTAssertEqual(state.playerCount, 1)
        XCTAssertTrue(PlayerGameConfig.holeOptions.contains(state.config.holes))
        XCTAssertEqual(PlayerGameConfig.holeOptions, [3, 6, 9, 18])
    }

    func testStateRoundTripsThroughJSON() throws {
        let session = makeSession()
        session.record(.hazard)
        session.record(.bucketIn)
        let data = try JSONEncoder().encode(session.state)
        let restored = try JSONDecoder().decode(PlayerGameState.self, from: data)
        XCTAssertEqual(restored, session.state)
    }
}

@MainActor
final class WrestlingTests: XCTestCase {
    private func makeSession() -> GameSession {
        GameSession(state: GameState(config: SportCatalog.defaultConfig(for: .wrestling)), environment: .silent)
    }

    func testTechFallAtFifteen() {
        let session = makeSession()
        for _ in 0..<4 { session.addPoints(3, to: .a) }
        XCTAssertEqual(session.phase, .live)
        session.addPoints(3, to: .a)
        XCTAssertEqual(session.phase, .final)
        XCTAssertEqual(session.resultSummary, "Tech Fall")
        XCTAssertEqual(session.state.winner, .a)
    }

    func testWinByFall() {
        let session = makeSession()
        session.addPoints(3, to: .a)
        session.declareWinner(.b, method: "Fall")
        XCTAssertEqual(session.state.winner, .b)
        XCTAssertEqual(session.resultSummary, "Fall · 1st Period")
    }

    func testSuddenVictoryInOvertime() {
        let session = makeSession()
        session.setPeriod(3, resetClock: true)
        session.startClock()
        session.tick(at: Date().addingTimeInterval(121), silent: true)
        XCTAssertEqual(session.phase, .periodBreak, "Tied after regulation")
        session.performPrimary()
        XCTAssertEqual(session.periodLabel, "SV")
        session.addPoints(3, to: .b)
        XCTAssertEqual(session.phase, .final)
        XCTAssertEqual(session.resultSummary, "Sudden Victory")
    }
}
