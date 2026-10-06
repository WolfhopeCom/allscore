import Foundation

/// Keeps the in-progress game on disk so it survives the app being closed or killed.
enum SessionStore {
    private static let key = "activeGame.v1"

    static func save(_ state: GameState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: key)
        UserDefaults.standard.set(Date(), forKey: key + ".savedAt")
    }

    static var savedAt: Date? { UserDefaults.standard.object(forKey: key + ".savedAt") as? Date }

    static func load() -> GameState? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(GameState.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: key + ".savedAt")
    }
}
