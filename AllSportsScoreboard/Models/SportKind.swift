import Foundation

/// Every sport the app knows about. Raw values are persisted (history, saved games,
/// defaults), so never rename an existing case.
enum SportKind: String, Codable, CaseIterable, Identifiable {
    case basketball
    case football
    case soccer
    case hockey
    case baseball
    case volleyball
    case tennis
    case tableTennis
    case badminton
    case pickleball
    case boxing
    case wrestling
    case bucketGolf
    case custom

    var id: String { rawValue }
}

/// The two sides of a scoreboard. Index 0 is the left / top team.
enum TeamSide: Int, Codable, CaseIterable, Identifiable {
    case a = 0
    case b = 1

    var id: Int { rawValue }
    var opponent: TeamSide { self == .a ? .b : .a }
}

/// Team accent colors. Actual color values live in `Theme` so they can adapt to appearance.
enum TeamColor: String, Codable, CaseIterable, Identifiable {
    case red, orange, gold, green, teal, blue, purple, silver

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}
