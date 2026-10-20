import XCTest
@testable import AllSportsScoreboard

@MainActor
final class CornholeTests: XCTestCase {
    private func makeSession(target: Int = 21) -> GameSession {
        var config = SportCatalog.defaultConfig(for: .cornhole)
        config.pointsToWin = target
        return GameSession(state: GameState(config: config), environment: .silent)
    }

    private func throwBags(_ session: GameSession, _ side: TeamSide, board: Int = 0, hole: Int = 0) {
        for _ in 0..<board { session.addPoints(1, to: side) }
        for _ in 0..<hole { session.addPoints(3, to: side) }
    }

    func testOnlyTheDifferenceCounts() {
        let session = makeSession()
        throwBags(session, .a, board: 1, hole: 2)   // 7
        throwBags(session, .b, board: 2, hole: 1)   // 5
        XCTAssertEqual(session.score(.a), 0, "Bags count only when the inning ends")
        XCTAssertEqual(session.inningResult?.side, .a)
        XCTAssertEqual(session.inningResult?.points, 2)
        session.performPrimary()
        XCTAssertEqual(session.score(.a), 2)
        XCTAssertEqual(session.score(.b), 0)
        XCTAssertEqual(session.state.period, 2)
        XCTAssertEqual(session.state.match.points, [0, 0])
    }

    func testEqualInningsCancelOut() {
        let session = makeSession()
        throwBags(session, .a, hole: 1)
        throwBags(session, .b, hole: 1)
        XCTAssertNil(session.inningResult)
        session.endInning()
        XCTAssertEqual([session.score(.a), session.score(.b)], [0, 0])
        XCTAssertEqual(session.state.period, 2)
    }

    func testReachingTheTargetWinsAtTheEndOfTheInning() {
        let session = makeSession(target: 11)
        throwBags(session, .b, hole: 4)            // 12
        session.endInning()
        XCTAssertEqual(session.state.phase, .final)
        XCTAssertEqual(session.state.declaredWinner, .b)
        XCTAssertEqual(session.score(.b), 12)
    }

    func testAnInningCannotExceedFourBagsInTheHole() {
        let session = makeSession()
        throwBags(session, .a, hole: 4)
        session.addPoints(1, to: .a)
        XCTAssertEqual(session.state.match.points[0], 12)
    }

    func testUndoBringsBackTheInning() {
        let session = makeSession()
        throwBags(session, .a, board: 3)
        session.endInning()
        XCTAssertEqual(session.score(.a), 3)
        session.undo()
        XCTAssertEqual(session.score(.a), 0)
        XCTAssertEqual(session.state.match.points, [3, 0])
        XCTAssertEqual(session.state.period, 1)
    }

    func testSubtractTakesBackABagFromThisInning() {
        let session = makeSession()
        throwBags(session, .a, hole: 1)
        session.subtractPoints(from: .a)
        XCTAssertEqual(session.state.match.points[0], 2)
        XCTAssertEqual(session.score(.a), 0)
    }

    func testPrimaryButtonEndsTheInning() {
        let session = makeSession()
        XCTAssertEqual(session.primaryAction, .startGame("Start Game"))
        throwBags(session, .a, board: 1)
        XCTAssertEqual(session.primaryAction, .endHalfInning("Inning"))
        XCTAssertEqual(session.primaryAction.title, "End Inning")
    }

    func testCornholeHistoryIsNotOvertime() {
        let session = makeSession(target: 11)
        throwBags(session, .a, board: 2)
        session.endInning()
        throwBags(session, .a, hole: 4)
        session.endInning()
        let record = GameRecord(state: session.state, summary: session.resultSummary)
        XCTAssertFalse(record.wentToOvertime)
        XCTAssertEqual(record.scoreA, 14)
    }
}

@MainActor
final class ShareTextTests: XCTestCase {
    func testFinishedGameShareTextNamesTheWinner() {
        var config = SportCatalog.defaultConfig(for: .basketball)
        config.teamA = TeamConfig(name: "Lions", color: .gold)
        config.teamB = TeamConfig(name: "Hawks", color: .blue)
        var state = GameState(config: config)
        state.scores = [92, 88]
        state.phase = .final
        let text = GameSession(state: state, environment: .silent).shareText
        XCTAssertTrue(text.contains("Lions 92 – 88 Hawks"))
        XCTAssertTrue(text.contains("Lions wins!"))
        XCTAssertTrue(text.contains("wolfhopecom.github.io"))
    }

    func testBucketGolfShareTextListsStandings() {
        var config = PlayerGameConfig.standard
        config.players = [PlayerConfig(name: "Sam", color: .gold), PlayerConfig(name: "Riley", color: .green)]
        config.holes = 3
        let session = PlayerGameSession(state: PlayerGameState(config: config), environment: .silent)
        XCTAssertTrue(session.shareText.hasPrefix("Bucket Golf · 3 holes · par 9"))
        XCTAssertTrue(session.shareText.contains("1. Sam"))
    }
}
