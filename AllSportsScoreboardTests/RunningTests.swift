import XCTest
@testable import AllSportsScoreboard

@MainActor
final class RunningTests: XCTestCase {
    func testReopeningAfterTheBuzzerDoesNotEndTheGameAgain() {
        var config = SportCatalog.defaultConfig(for: .basketball)
        config.periodCount = 1
        config.periodLength = 60
        let session = GameSession(state: GameState(config: config), environment: .silent)
        session.addPoints(2, to: .a)
        session.startClock()
        session.tick(at: Date().addingTimeInterval(120), silent: true)
        XCTAssertEqual(session.phase, .final)

        session.reopen()
        XCTAssertEqual(session.phase, .periodBreak, "Time is up, so back to the break, not a 0:00 live period")
        XCTAssertEqual(session.primaryAction, .endGame)
    }

    func testGolfSavesOnlyRecentUndoSteps() throws {
        var config = PlayerGameConfig.standard
        config.holes = 18
        let session = PlayerGameSession(state: PlayerGameState(config: config), environment: .silent)
        for _ in 0..<25 { session.adjustSwings(0, by: 1); session.adjustSwings(0, by: -1) }
        XCTAssertGreaterThan(session.state.undoStack.count, PlayerGameState.savedUndoSteps)

        let data = try JSONEncoder().encode(session.state)
        let restored = try JSONDecoder().decode(PlayerGameState.self, from: data)
        XCTAssertEqual(restored.undoStack.count, PlayerGameState.savedUndoSteps)
        XCTAssertEqual(restored.cards, session.state.cards)
        XCTAssertEqual(restored.hole, session.state.hole)
    }

    func testGolfRoundSurvivesMissingFields() throws {
        let state = PlayerGameState(config: .standard)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as! [String: Any]
        json.removeValue(forKey: "undoStack")
        json.removeValue(forKey: "teeOrder")
        json["unknownFutureField"] = 42
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(PlayerGameState.self, from: data)
        XCTAssertEqual(restored.id, state.id)
        XCTAssertEqual(restored.teeOrder, Array(0..<state.playerCount))
        XCTAssertTrue(restored.undoStack.isEmpty)
    }
}
