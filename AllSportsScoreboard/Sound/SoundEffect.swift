import Foundation

/// The buzzer/horn played at the end of a period and the end of a game.
enum BuzzerStyle: String, Codable, CaseIterable, Identifiable {
    case arena
    case classic
    case horn
    case shortHorn
    case whistle

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .arena: return "Arena Buzzer"
        case .classic: return "Classic Buzzer"
        case .horn: return "Electronic Horn"
        case .shortHorn: return "Short Horn"
        case .whistle: return "Referee Whistle"
        }
    }

    var detail: String {
        switch self {
        case .arena: return "Deep, loud, unmistakable"
        case .classic: return "Gym-style electric buzz"
        case .horn: return "Bright three-tone horn"
        case .shortHorn: return "Quick arena blast"
        case .whistle: return "Pea whistle trill"
        }
    }
}

enum BuzzerLength: Hashable {
    /// End of a period.
    case short
    /// End of the game.
    case long
}

/// Every sound the app can make. All are synthesized on-device; nothing is recorded.
enum SoundEffect: Hashable {
    case tap
    case score
    case bigScore
    case scoreRemoved
    case denied
    case timerStart
    case timerPause
    case warning
    case periodChange
    case reset
    case buzzer(BuzzerStyle, BuzzerLength)
    case gameEnd(BuzzerStyle)

    var isBuzzer: Bool {
        switch self {
        case .buzzer, .gameEnd: return true
        default: return false
        }
    }
}
