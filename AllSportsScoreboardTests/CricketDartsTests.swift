import XCTest
@testable import AllSportsScoreboard

@MainActor
final class CricketDartsTests: XCTestCase {
    private let twenty = 0, bull = Cricket.bullIndex

    private func makeSession() -> GameSession {
        GameSession(state: GameState(config: SportCatalog.defaultConfig(for: .darts)), environment: .silent)
    }

    func testThreeHitsCloseANumberAndCountAsTheScore() {
        let s = makeSession()
        s.addMark(.a, at: twenty)
        s.addMark(.a, at: twenty)
        XCTAssertEqual(s.score(.a), 0)
        s.addMark(.a, at: twenty)
        XCTAssertEqual(s.cricketMarks(.a, twenty), 3)
        XCTAssertEqual(s.score(.a), 1, "One number closed")
    }

    func testAClosedNumberTakesNoMoreHits() {
        let s = makeSession()
        for _ in 0..<5 { s.addMark(.b, at: bull) }
        XCTAssertEqual(s.cricketMarks(.b, bull), 3)
    }

    func testEitherTeamCanBeTappedAnyTime() {
        let s = makeSession()
        s.addMark(.b, at: twenty)
        s.addMark(.b, at: twenty)
        s.addMark(.a, at: twenty)
        s.addMark(.b, at: twenty)
        XCTAssertEqual(s.cricketMarks(.a, twenty), 1)
        XCTAssertEqual(s.cricketMarks(.b, twenty), 3)
        XCTAssertEqual(s.primaryAction, .none, "No turns, so no Next button")
    }

    func testClosingAllSevenWins() {
        let s = makeSession()
        for index in Cricket.targets.indices {
            for _ in 0..<3 { s.addMark(.b, at: index) }
        }
        XCTAssertEqual(s.phase, .final)
        XCTAssertEqual(s.state.winner, .b)
        XCTAssertEqual(s.score(.b), 7)
        XCTAssertEqual(s.resultSummary, "Cricket · numbers closed 0–7")
    }

    func testUndoTakesBackAHit() {
        let s = makeSession()
        for _ in 0..<3 { s.addMark(.a, at: twenty) }
        s.undo()
        XCTAssertEqual(s.cricketMarks(.a, twenty), 2)
        XCTAssertEqual(s.score(.a), 0)
    }

    func testSavedGamesKeepTheBoard() throws {
        let s = makeSession()
        s.addMark(.a, at: twenty)
        let data = try JSONEncoder().encode(s.state)
        let restored = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(restored.match.marks[0][twenty], 1)
    }
}
