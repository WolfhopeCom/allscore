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
