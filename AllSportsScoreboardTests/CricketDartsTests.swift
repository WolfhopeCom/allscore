import XCTest
@testable import AllSportsScoreboard

@MainActor
final class CricketDartsTests: XCTestCase {
    private let twenty = 0, nineteen = 1, fifteen = 5, bull = Cricket.bullIndex

    private func makeSession() -> GameSession {
        GameSession(state: GameState(config: SportCatalog.defaultConfig(for: .darts)), environment: .silent)
    }

    func testThreeMarksCloseANumber() {
        let s = makeSession()
        s.throwDart(at: twenty, multiplier: 1)
        s.throwDart(at: twenty, multiplier: 2)
        XCTAssertEqual(s.cricketMarks(.a, twenty), 3)
        XCTAssertEqual(s.score(.a), 0, "Closing hits don't score")
    }

    func testExtraMarksScoreWhileOpponentIsOpen() {
        let s = makeSession()
        s.throwDart(at: twenty, multiplier: 2)       // 2 marks
        s.throwDart(at: twenty, multiplier: 3)       // closes with 1, 2 extra = 40
        XCTAssertEqual(s.score(.a), 40)
    }

    func testNoPointsOnANumberTheOpponentClosed() {
        let s = makeSession()
        s.endCricketTurn()                            // Player 2 throws
        s.throwDart(at: nineteen, multiplier: 3)
        s.endCricketTurn()                            // back to Player 1
        s.throwDart(at: nineteen, multiplier: 3)
        s.throwDart(at: nineteen, multiplier: 3)
        XCTAssertEqual(s.score(.a), 0)
        XCTAssertTrue(s.isDead(nineteen))
    }

    func testBullIsWorth25AndHasNoTriple() {
        let s = makeSession()
        s.throwDart(at: bull, multiplier: 2)
        s.throwDart(at: bull, multiplier: 2)          // closes, 1 extra mark = 25
        XCTAssertEqual(s.score(.a), 25)
        s.endCricketTurn(); s.endCricketTurn()
        s.throwDart(at: bull, multiplier: 3)
        XCTAssertEqual(s.state.match.dartsThrown, 0, "A triple bull isn't a dart")
    }

    func testThreeDartsPassTheTurnAndRoundsCount() {
        let s = makeSession()
        XCTAssertEqual(s.cricketThrower, .a)
        s.throwMiss(); s.throwMiss(); s.throwMiss()
        XCTAssertEqual(s.cricketThrower, .b)
        XCTAssertEqual(s.state.period, 1)
        s.throwDart(at: fifteen, multiplier: 1); s.throwMiss(); s.throwMiss()
        XCTAssertEqual(s.cricketThrower, .a)
        XCTAssertEqual(s.state.period, 2)
        XCTAssertEqual(s.primaryAction, .nextPlayer("Player 2"))
    }

    func testClosingEverythingWithTheLeadWins() {
        let s = makeSession()
        for target in 0..<6 {
            s.throwDart(at: target, multiplier: 3)
            if s.cricketThrower == .b { s.endCricketTurn() }
        }
        XCTAssertNotEqual(s.phase, .final)
        s.throwDart(at: bull, multiplier: 2)
        s.throwDart(at: bull, multiplier: 1)
        XCTAssertEqual(s.phase, .final)
        XCTAssertEqual(s.state.winner, .a)
    }

    func testClosingEverythingWhileBehindDoesNotWin() {
        var state = GameState(config: SportCatalog.defaultConfig(for: .darts))
        state.match.marks = [[3, 3, 3, 3, 3, 3, 2], [0, 0, 0, 0, 0, 0, 0]]
        state.scores = [0, 60]
        state.phase = .live
        let s = GameSession(state: state, environment: .silent)
        s.throwDart(at: bull, multiplier: 1)
        XCTAssertNotEqual(s.phase, .final, "Must catch up on points first")
        s.throwDart(at: twenty, multiplier: 3)        // +60 ties it
        XCTAssertEqual(s.phase, .final)
        XCTAssertEqual(s.state.winner, .a)
    }

    func testUndoTakesBackADartAndTheTurn() {
        let s = makeSession()
        s.throwMiss(); s.throwMiss(); s.throwDart(at: twenty, multiplier: 3)
        XCTAssertEqual(s.cricketThrower, .b)
        s.undo()
        XCTAssertEqual(s.cricketThrower, .a)
        XCTAssertEqual(s.cricketMarks(.a, twenty), 0)
        XCTAssertEqual(s.state.match.dartsThrown, 2)
    }

    func testSavedGamesKeepTheBoard() throws {
        let s = makeSession()
        s.throwDart(at: twenty, multiplier: 2)
        let data = try JSONEncoder().encode(s.state)
        let restored = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(restored.match.marks[0][twenty], 2)
        XCTAssertEqual(restored.match.dartsThrown, 1)
    }
}
