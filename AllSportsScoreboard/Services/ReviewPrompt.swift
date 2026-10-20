import Foundation

/// Decides when to ask for an App Store rating: only right after someone leaves a game they
/// finished (a good moment, never mid-play), on their 3rd, 10th and 30th finished games,
/// and at most once per app version. iOS itself also limits how often the prompt appears.
enum ReviewPrompt {
    static let milestones: Set<Int> = [3, 10, 30]

    private enum Key {
        static let finishedGames = "review.finishedGames"
        static let lastGame = "review.lastGame"
        static let askedVersion = "review.askedVersion"
    }

    /// Counts a finished game (once, even if it's left more than once) and returns true when
    /// this is the moment to ask.
    static func recordFinishedGame(
        id: UUID,
        version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard defaults.string(forKey: Key.lastGame) != id.uuidString else { return false }
        defaults.set(id.uuidString, forKey: Key.lastGame)
        let count = defaults.integer(forKey: Key.finishedGames) + 1
        defaults.set(count, forKey: Key.finishedGames)
        guard milestones.contains(count), defaults.string(forKey: Key.askedVersion) != version else { return false }
        defaults.set(version, forKey: Key.askedVersion)
        return true
    }
}
