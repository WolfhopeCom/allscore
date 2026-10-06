import Foundation

/// Every ad and purchase identifier, plus the ad pacing rules, in one place.
enum AdConfig {
    /// The one-time Remove Ads purchase (non-consumable). Must match App Store Connect exactly.
    static let removeAdsProductID = "allsportsscoreboard.removeads"

    // Google's public test ad units. They always fill and never pay out, so they're safe while
    // developing. Before release, replace the two Release values with the ad unit IDs from your
    // AdMob account, and set ADMOB_APP_ID in the target's build settings to your AdMob app ID.
    #if DEBUG
    static let bannerUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let interstitialUnitID = "ca-app-pub-3940256099942544/4411468910"
    #else
    static let bannerUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let interstitialUnitID = "ca-app-pub-3940256099942544/4411468910"
    #endif

    /// True while the Release build still points at Google's test ad units.
    static var usesTestAdUnits: Bool {
        bannerUnitID.hasPrefix("ca-app-pub-3940256099942544") || interstitialUnitID.hasPrefix("ca-app-pub-3940256099942544")
    }
}

/// When a full-screen ad may follow a finished game. Pure so it can be unit tested.
struct InterstitialPacing {
    /// At most one full-screen ad in this many seconds.
    static let minimumInterval: TimeInterval = 10 * 60
    /// New players get this many finished games before they ever see one.
    static let freeGames = 2

    static func shouldShow(now: Date, lastShown: Date?, finishedGames: Int) -> Bool {
        guard finishedGames > freeGames else { return false }
        guard let lastShown else { return true }
        // A clock set backwards shouldn't lock ads out (or let them through) forever.
        let elapsed = now.timeIntervalSince(lastShown)
        return elapsed >= minimumInterval || elapsed < 0
    }
}
