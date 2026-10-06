import Foundation
import Observation

enum AppAppearance: String, CaseIterable, Identifiable {
    case arena
    case blackout
    case daylight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .arena: return "Arena"
        case .blackout: return "Blackout"
        case .daylight: return "Daylight"
        }
    }

    var detail: String {
        switch self {
        case .arena: return "Dark, with subtle glow"
        case .blackout: return "Pure black, ideal for OLED"
        case .daylight: return "High contrast for bright sun"
        }
    }
}

/// User preferences, stored locally in UserDefaults. Nothing leaves the device.
@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    @ObservationIgnored private let store: UserDefaults

    var soundEnabled: Bool {
        didSet { store.set(soundEnabled, forKey: Key.soundEnabled) }
    }
    var volume: Double {
        didSet { store.set(volume, forKey: Key.volume) }
    }
    var playInSilentMode: Bool {
        didSet { store.set(playInSilentMode, forKey: Key.playInSilentMode) }
    }
    var hapticsEnabled: Bool {
        didSet { store.set(hapticsEnabled, forKey: Key.hapticsEnabled) }
    }
    var buzzerStyle: BuzzerStyle {
        didSet { store.set(buzzerStyle.rawValue, forKey: Key.buzzerStyle) }
    }
    var defaultSport: SportKind {
        didSet { store.set(defaultSport.rawValue, forKey: Key.defaultSport) }
    }
    var keepScreenAwake: Bool {
        didSet { store.set(keepScreenAwake, forKey: Key.keepScreenAwake) }
    }
    var appearance: AppAppearance {
        didSet { store.set(appearance.rawValue, forKey: Key.appearance) }
    }

    init(store: UserDefaults = .standard) {
        self.store = store
        soundEnabled = store.object(forKey: Key.soundEnabled) as? Bool ?? true
        volume = store.object(forKey: Key.volume) as? Double ?? 0.9
        playInSilentMode = store.object(forKey: Key.playInSilentMode) as? Bool ?? true
        hapticsEnabled = store.object(forKey: Key.hapticsEnabled) as? Bool ?? true
        buzzerStyle = store.string(forKey: Key.buzzerStyle).flatMap(BuzzerStyle.init(rawValue:)) ?? .arena
        defaultSport = store.string(forKey: Key.defaultSport).flatMap(SportKind.init(rawValue:)) ?? .basketball
        keepScreenAwake = store.object(forKey: Key.keepScreenAwake) as? Bool ?? true
        appearance = store.string(forKey: Key.appearance).flatMap(AppAppearance.init(rawValue:)) ?? .arena
    }

    /// The setup last used for a sport (team names, period length, …), or factory defaults.
    func gameDefaults(for sport: SportKind) -> GameConfig {
        guard let data = store.data(forKey: Key.gameDefaults(sport)),
              let config = try? JSONDecoder().decode(GameConfig.self, from: data),
              config.sport == sport
        else { return SportCatalog.defaultConfig(for: sport) }
        return config
    }

    func saveGameDefaults(_ config: GameConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        store.set(data, forKey: Key.gameDefaults(config.sport))
    }

    /// The last Bucket Golf setup (players, holes), or the standard one.
    func playerGameDefaults() -> PlayerGameConfig {
        guard let data = store.data(forKey: Key.playerDefaults),
              let config = try? JSONDecoder().decode(PlayerGameConfig.self, from: data)
        else { return .standard }
        return config.sanitized()
    }

    func savePlayerGameDefaults(_ config: PlayerGameConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        store.set(data, forKey: Key.playerDefaults)
    }

    private enum Key {
        static let soundEnabled = "settings.soundEnabled"
        static let volume = "settings.volume"
        static let playInSilentMode = "settings.playInSilentMode"
        static let hapticsEnabled = "settings.hapticsEnabled"
        static let buzzerStyle = "settings.buzzerStyle"
        static let defaultSport = "settings.defaultSport"
        static let keepScreenAwake = "settings.keepScreenAwake"
        static let appearance = "settings.appearance"
        static let playerDefaults = "settings.playerGameDefaults"

        static func gameDefaults(_ sport: SportKind) -> String {
            "settings.gameDefaults.\(sport.rawValue)"
        }
    }
}
