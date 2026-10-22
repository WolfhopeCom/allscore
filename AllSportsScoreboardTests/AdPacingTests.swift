import XCTest
@testable import AllSportsScoreboard

final class AdPacingTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testNewPlayersGetFreeGamesFirst() {
        for games in 0...InterstitialPacing.freeGames {
            XCTAssertFalse(InterstitialPacing.shouldShow(now: now, lastShown: nil, finishedGames: games))
        }
        XCTAssertTrue(InterstitialPacing.shouldShow(now: now, lastShown: nil, finishedGames: InterstitialPacing.freeGames + 1))
    }

    func testAtMostOnceEveryTenMinutes() {
        let games = InterstitialPacing.freeGames + 5
        XCTAssertFalse(InterstitialPacing.shouldShow(now: now, lastShown: now.addingTimeInterval(-60), finishedGames: games))
        XCTAssertFalse(InterstitialPacing.shouldShow(now: now, lastShown: now.addingTimeInterval(-599), finishedGames: games))
        XCTAssertTrue(InterstitialPacing.shouldShow(now: now, lastShown: now.addingTimeInterval(-600), finishedGames: games))
    }

    func testClockSetBackwardsDoesNotLockAdsOut() {
        let games = InterstitialPacing.freeGames + 1
        XCTAssertTrue(InterstitialPacing.shouldShow(now: now, lastShown: now.addingTimeInterval(3600), finishedGames: games))
    }

    func testRemoveAdsOwnershipIsRememberedAcrossLaunches() async {
        let defaults = UserDefaults(suiteName: "AdPacingTests")!
        defaults.removePersistentDomain(forName: "AdPacingTests")
        defaults.set(true, forKey: "purchases.adsRemoved")
        let store = await PurchaseStore(defaults: defaults)
        let removed = await store.adsRemoved
        XCTAssertTrue(removed)
    }
}

final class ReviewPromptTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let name = "ReviewPromptTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testAsksAfterTheFirstFinishedGameThenAtTen() {
        let defaults = freshDefaults()
        let asks = (1...12).map { _ in ReviewPrompt.recordFinishedGame(id: UUID(), version: "1.1", defaults: defaults) }
        // Once per version: the first finished game asks, the 10th doesn't ask again in the same version.
        XCTAssertEqual(asks.enumerated().filter(\.element).map { $0.offset + 1 }, [1])
    }

    func testSameGameIsOnlyCountedOnce() {
        let defaults = freshDefaults()
        let game = UUID()
        XCTAssertTrue(ReviewPrompt.recordFinishedGame(id: game, version: "1.1", defaults: defaults))
        for _ in 0..<5 { XCTAssertFalse(ReviewPrompt.recordFinishedGame(id: game, version: "1.1", defaults: defaults)) }
    }

    func testAsksAgainInANewVersion() {
        let defaults = freshDefaults()
        for game in 1...9 { _ = ReviewPrompt.recordFinishedGame(id: UUID(), version: game < 5 ? "1.1" : "1.2", defaults: defaults) }
        XCTAssertTrue(ReviewPrompt.recordFinishedGame(id: UUID(), version: "1.2", defaults: defaults))
    }
}

final class LacrosseTests: XCTestCase {
    @MainActor
    func testFirstGoalInOvertimeWins() {
        var config = SportCatalog.defaultConfig(for: .lacrosse)
        config.periodCount = 4
        var state = GameState(config: config)
        state.phase = .live
        state.period = 5
        state.scores = [7, 7]
        let session = GameSession(state: state, environment: .silent)
        session.addPoints(1, to: .b)
        XCTAssertEqual(session.state.phase, .final)
        XCTAssertEqual(session.state.declaredWinner, .b)
    }

    func testHalvesAndQuartersAreLabelled() {
        XCTAssertEqual(LacrosseRules(periodCount: 4).periodLabel(3, regulation: 4), "Q3")
        XCTAssertEqual(LacrosseRules(periodCount: 2).periodLabel(2, regulation: 2), "H2")
        XCTAssertEqual(LacrosseRules(periodCount: 4).periodLabel(5, regulation: 4), "SV")
        XCTAssertEqual(LacrosseRules(periodCount: 2).periodName, "Half")
    }
}
