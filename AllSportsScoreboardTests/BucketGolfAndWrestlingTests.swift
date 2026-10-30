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

    // Scored like the official scorecard: swings, In the Bucket (−1), Hazard (+1).

    func testThreeSwingsIsPar() {
        let session = makeSession()
        session.adjustSwings(0, by: 3)
        let card = session.holeScore(0)
        XCTAssertTrue(card.isFinished)
        XCTAssertEqual(card.strokes, 3)
        XCTAssertEqual(session.holeTerm(0), "Par")
        XCTAssertEqual(session.parText(0), "E")
    }

    func testInTheBucketTakesOneOff() {
        let session = makeSession()
        session.adjustSwings(0, by: 3)
        session.toggleBucket(0)
        XCTAssertEqual(session.holeScore(0).strokes, 2)
        XCTAssertEqual(session.holeTerm(0), "Birdie")
        XCTAssertEqual(session.parText(0), "−1")
        session.toggleBucket(0)
        XCTAssertEqual(session.holeScore(0).strokes, 3)
    }

    func testBucketWithNoSwingsCountsTheSwing() {
        let session = makeSession()
        session.toggleBucket(0)
        XCTAssertEqual(session.holeScore(0).swings, 1)
        XCTAssertEqual(session.holeScore(0).strokes, 0)
        XCTAssertEqual(session.holeTerm(0), "Hole in Zero")
    }

    func testHazardsAddAStrokeEach() {
        let session = makeSession()
        session.adjustSwings(0, by: 2)
        session.adjustHazards(0, by: 2)
        XCTAssertEqual(session.holeScore(0).strokes, 4)
        session.adjustHazards(0, by: -1)
        XCTAssertEqual(session.holeScore(0).strokes, 3)
    }

    func testZeroSwingsClearsTheHole() {
        let session = makeSession()
        session.adjustSwings(0, by: 2)
        session.toggleBucket(0)
        session.adjustHazards(0, by: 1)
        session.adjustSwings(0, by: -2)
        let card = session.holeScore(0)
        XCTAssertFalse(card.isFinished)
        XCTAssertFalse(card.inBucket)
        XCTAssertEqual(card.hazards, 0)
        XCTAssertNil(session.holeTerm(0))
        XCTAssertEqual(session.holeScore(0).swings, 0)
    }

    func testSwingsStayInRange() {
        let session = makeSession()
        session.adjustSwings(0, by: -1)
        XCTAssertEqual(session.holeScore(0).swings, 0)
        for _ in 0..<40 { session.adjustSwings(0, by: 1) }
        XCTAssertEqual(session.holeScore(0).swings, PlayerGameSession.maxSwings)
    }

    func testAnyPlayerCanBeScoredInAnyOrder() {
        let session = makeSession(players: 3)
        session.adjustSwings(2, by: 4)
        session.adjustSwings(0, by: 1)
        XCTAssertEqual(session.holeScore(2).strokes, 4)
        XCTAssertEqual(session.holeScore(0).strokes, 1)
        XCTAssertFalse(session.holeScore(1).isFinished)
    }

    func testPrevAndNextMoveBetweenHoles() {
        let session = makeSession(holes: 3)
        XCTAssertEqual(session.nextTitle, "Next Hole")
        session.previousHole()
        XCTAssertEqual(session.hole, 1, "Already on the first hole")
        session.adjustSwings(0, by: 3)
        session.nextHole()
        XCTAssertEqual(session.hole, 2)
        XCTAssertFalse(session.holeScore(0).isFinished, "A new hole starts blank")
        session.previousHole()
        XCTAssertEqual(session.holeScore(0).strokes, 3, "Earlier holes keep their scores")
        session.nextHole(); session.nextHole()
        XCTAssertEqual(session.hole, 3)
        XCTAssertEqual(session.nextTitle, "Finish Round")
    }

    func testLowestTotalWinsAfterTheCourse() {
        let session = makeSession(players: 2, holes: 3)
        for _ in 0..<3 {
            session.adjustSwings(0, by: 3)                 // par
            session.adjustSwings(1, by: 3)
            session.toggleBucket(1)                        // birdie
            session.nextHole()
        }
        XCTAssertEqual(session.phase, .final)
        XCTAssertEqual(session.state.total(0), 9)
        XCTAssertEqual(session.state.total(1), 6)
        XCTAssertEqual(session.winnerNames, ["Player 2"], "Lowest total wins")
        XCTAssertEqual(session.parText(1), "−3")
    }

    func testUndoRemovesTheLastChange() {
        let session = makeSession()
        session.adjustSwings(0, by: 2)
        session.adjustHazards(0, by: 1)
        session.undo()
        XCTAssertEqual(session.holeScore(0).hazards, 0)
        XCTAssertEqual(session.holeScore(0).swings, 2)
    }

    func testOldShotListsStillLoad() throws {
        let json = #"{"shots":["miss","hazard","bucketIn"]}"#.data(using: .utf8)!
        let card = try JSONDecoder().decode(HoleCard.self, from: json)
        XCTAssertEqual(card.swings, 3)
        XCTAssertEqual(card.hazards, 1)
        XCTAssertTrue(card.inBucket)
        XCTAssertEqual(card.strokes, 3)
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
