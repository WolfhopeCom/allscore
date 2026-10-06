import UIKit

/// Things that happen in a game which deserve a sound and/or a haptic.
enum FeedbackEvent: Equatable {
    case tap
    case score(Int)
    case scoreRemoved
    case undo
    case denied
    case possession
    case timerStart
    case timerPause
    case warning
    case periodEnd
    case periodChange
    case gameEnd
    case reset
}

/// Single place that turns game events into sound + haptics, honoring user settings.
@MainActor
final class Feedback {
    static let shared = Feedback()

    private let settings: AppSettings
    private let sound: SoundEngine

    private init() {
        settings = AppSettings.shared
        sound = SoundEngine.shared
    }

    func play(_ event: FeedbackEvent) {
        if settings.soundEnabled, let effect = soundEffect(for: event) {
            playSound(effect)
        }
        if settings.hapticsEnabled {
            haptic(for: event)
        }
    }

    /// Plays a buzzer even when sound effects are off, so it can be auditioned in Settings.
    func previewBuzzer(_ style: BuzzerStyle) {
        playSound(.buzzer(style, .long))
        if settings.hapticsEnabled { Haptics.impact(.medium) }
    }

    func prewarmSounds() {
        if settings.hapticsEnabled { Haptics.warmUp() }
        let style = settings.buzzerStyle
        sound.prewarm([
            .tap, .score, .bigScore, .scoreRemoved, .denied, .timerStart, .timerPause,
            .warning, .periodChange, .reset, .buzzer(style, .short), .gameEnd(style)
        ])
    }

    private func playSound(_ effect: SoundEffect) {
        sound.configureSession(ignoresSilentSwitch: settings.playInSilentMode)
        sound.setVolume(settings.volume)
        sound.play(effect)
    }

    private func soundEffect(for event: FeedbackEvent) -> SoundEffect? {
        switch event {
        case .tap, .possession: return .tap
        case .score(let points): return points >= 3 ? .bigScore : .score
        case .scoreRemoved, .undo: return .scoreRemoved
        case .denied: return .denied
        case .timerStart: return .timerStart
        case .timerPause: return .timerPause
        case .warning: return .warning
        case .periodEnd: return .buzzer(settings.buzzerStyle, .short)
        case .periodChange: return .periodChange
        case .gameEnd: return .gameEnd(settings.buzzerStyle)
        case .reset: return .reset
        }
    }

    private func haptic(for event: FeedbackEvent) {
        switch event {
        case .tap, .possession:
            Haptics.selection()
        case .score(let points):
            Haptics.impact(points >= 3 ? .medium : .light)
        case .scoreRemoved, .undo:
            Haptics.impact(.light)
        case .denied:
            Haptics.impact(.rigid)
        case .timerStart, .timerPause, .periodChange:
            Haptics.impact(.medium)
        case .warning:
            Haptics.notify(.warning)
        case .periodEnd:
            Haptics.impact(.heavy)
        case .gameEnd:
            Haptics.notify(.success)
        case .reset:
            Haptics.notify(.warning)
        }
    }
}

@MainActor
enum Haptics {
    enum Impact {
        case light, medium, heavy, rigid
    }

    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    // Each generator is re-prepared after firing so the next tap has no Taptic Engine lag.

    static func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    static func impact(_ impact: Impact) {
        let generator: UIImpactFeedbackGenerator
        switch impact {
        case .light: generator = lightGenerator
        case .medium: generator = mediumGenerator
        case .heavy: generator = heavyGenerator
        case .rigid: generator = rigidGenerator
        }
        generator.impactOccurred()
        generator.prepare()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.notificationOccurred(type)
        notificationGenerator.prepare()
    }

    static func warmUp() {
        selectionGenerator.prepare()
        lightGenerator.prepare()
        mediumGenerator.prepare()
    }
}

@MainActor
enum ScreenAwake {
    /// Prevents auto-lock while a scoreboard is on screen.
    static func set(_ awake: Bool) {
        UIApplication.shared.isIdleTimerDisabled = awake
    }
}
