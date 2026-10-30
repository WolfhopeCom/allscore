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
        s.addMark(0, at: twenty)
        s.addMark(0, at: twenty)
        XCTAssertEqual(s.score(.a), 0)
        s.addMark(0, at: twenty)
        XCTAssertEqual(s.cricketMarks(0, twenty), 3)
        XCTAssertEqual(s.score(.a), 1, "One number closed")
    }

    func testAClosedNumberTakesNoMoreHits() {
        let s = makeSession()
        for _ in 0..<5 { s.addMark(1, at: bull) }
        XCTAssertEqual(s.cricketMarks(1, bull), 3)
    }

    func testEitherTeamCanBeTappedAnyTime() {
        let s = makeSession()
        s.addMark(1, at: twenty)
        s.addMark(1, at: twenty)
        s.addMark(0, at: twenty)
        s.addMark(1, at: twenty)
        XCTAssertEqual(s.cricketMarks(0, twenty), 1)
        XCTAssertEqual(s.cricketMarks(1, twenty), 3)
        XCTAssertEqual(s.primaryAction, .none, "No turns, so no Next button")
    }

    func testClosingAllSevenWins() {
        let s = makeSession()
        for index in Cricket.targets.indices {
            for _ in 0..<3 { s.addMark(1, at: index) }
        }
        XCTAssertEqual(s.phase, .final)
        XCTAssertEqual(s.state.winner, .b)
        XCTAssertEqual(s.score(.b), 7)
        XCTAssertEqual(s.resultSummary, "Cricket · closed Player 2 7 · Player 1 0")
    }

    func testUndoTakesBackAHit() {
        let s = makeSession()
        for _ in 0..<3 { s.addMark(0, at: twenty) }
        s.undo()
        XCTAssertEqual(s.cricketMarks(0, twenty), 2)
        XCTAssertEqual(s.score(.a), 0)
    }

    func testSavedGamesKeepTheBoard() throws {
        let s = makeSession()
        s.addMark(0, at: twenty)
        let data = try JSONEncoder().encode(s.state)
        let restored = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(restored.match.marks[0][twenty], 1)
    }

    func testThreeAndFourPlayers() {
        var config = SportCatalog.defaultConfig(for: .darts)
        config.setPlayerCount(4)
        XCTAssertEqual(config.playerCount, 4)
        XCTAssertEqual(config.playerName(3), "Player 4")
        let s = GameSession(state: GameState(config: config), environment: .silent)
        XCTAssertEqual(s.cricketPlayerCount, 4)
        for index in Cricket.targets.indices {
            for _ in 0..<3 { s.addMark(2, at: index) }
        }
        XCTAssertEqual(s.phase, .final)
        XCTAssertEqual(s.cricketWinner, 2)
        XCTAssertEqual(s.cricketStandings.first, 2)
        XCTAssertTrue(s.shareText.contains("Player 3 wins"))
        config.setPlayerCount(9)
        XCTAssertEqual(config.playerCount, 4)
        config.setPlayerCount(2)
        XCTAssertTrue(config.extraPlayers.isEmpty)
    }

    func testANumberIsDeadOnlyWhenEveryoneClosedIt() {
        var config = SportCatalog.defaultConfig(for: .darts)
        config.setPlayerCount(3)
        let s = GameSession(state: GameState(config: config), environment: .silent)
        for player in 0..<2 { for _ in 0..<3 { s.addMark(player, at: twenty) } }
        XCTAssertFalse(s.isDead(twenty))
        for _ in 0..<3 { s.addMark(2, at: twenty) }
        XCTAssertTrue(s.isDead(twenty))
    }

    func testExtraPlayersSurviveSaving() throws {
        var config = SportCatalog.defaultConfig(for: .darts)
        config.setPlayerCount(3)
        let state = GameState(config: config)
        let restored = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(restored.config.playerCount, 3)
        XCTAssertEqual(restored.match.marks.count, 3)
    }
}
