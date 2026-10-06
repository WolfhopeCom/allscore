import Foundation
import SwiftData

/// A finished game, kept in local history.
@Model
final class GameRecord {
    @Attribute(.unique) var gameID: UUID
    var sportRaw: String
    var title: String
    var teamAName: String
    var teamBName: String
    var teamAColorRaw: String
    var teamBColorRaw: String
    var scoreA: Int
    var scoreB: Int
    var finalPeriodLabel: String
    var wentToOvertime: Bool
    var startedAt: Date
    var finishedAt: Date
    /// Set scores, hits & errors, or how a fight ended. Empty for points sports.
    var summary: String = ""
    /// Stoppage winner (0 or 1), or -1 when the score decides it.
    var declaredWinnerRaw: Int = -1

    init(state: GameState, summary: String?) {
        let rules = SportCatalog.rules(for: state.config)
        let regulation = max(1, state.config.periodCount)
        gameID = state.id
        sportRaw = state.config.sport.rawValue
        title = rules.name
        teamAName = state.config.teamName(.a)
        teamBName = state.config.teamName(.b)
        teamAColorRaw = state.config.teamA.color.rawValue
        teamBColorRaw = state.config.teamB.color.rawValue
        scoreA = state.score(.a)
        scoreB = state.score(.b)
        finalPeriodLabel = state.config.sport == .baseball
            ? "\(state.period) Innings"
            : rules.periodLabel(state.period, regulation: regulation)
        wentToOvertime = state.period > regulation
        startedAt = state.createdAt
        finishedAt = Date()
        self.summary = summary ?? ""
        declaredWinnerRaw = state.declaredWinner?.rawValue ?? -1
    }

    func update(from state: GameState, summary: String?) {
        let rules = SportCatalog.rules(for: state.config)
        let regulation = max(1, state.config.periodCount)
        title = rules.name
        teamAName = state.config.teamName(.a)
        teamBName = state.config.teamName(.b)
        teamAColorRaw = state.config.teamA.color.rawValue
        teamBColorRaw = state.config.teamB.color.rawValue
        scoreA = state.score(.a)
        scoreB = state.score(.b)
        finalPeriodLabel = state.config.sport == .baseball
            ? "\(state.period) Innings"
            : rules.periodLabel(state.period, regulation: regulation)
        wentToOvertime = state.period > regulation
        finishedAt = Date()
        self.summary = summary ?? ""
        declaredWinnerRaw = state.declaredWinner?.rawValue ?? -1
    }

    var sport: SportKind? { SportKind(rawValue: sportRaw) }
    var teamAColor: TeamColor { TeamColor(rawValue: teamAColorRaw) ?? .silver }
    var teamBColor: TeamColor { TeamColor(rawValue: teamBColorRaw) ?? .silver }

    var winner: TeamSide? {
        if let declared = TeamSide(rawValue: declaredWinnerRaw) { return declared }
        if scoreA == scoreB { return nil }
        return scoreA > scoreB ? .a : .b
    }
}

/// Owns the on-device SwiftData store for game history.
@MainActor
final class HistoryStore {
    static let shared = HistoryStore()

    let container: ModelContainer
    private let keepLimit = 250

    private init() {
        if let container = try? ModelContainer(for: GameRecord.self) {
            self.container = container
        } else {
            // Last resort so the app still launches; history just won't persist this session.
            let memoryOnly = ModelConfiguration(isStoredInMemoryOnly: true)
            self.container = try! ModelContainer(for: GameRecord.self, configurations: memoryOnly)
        }
    }

    /// Saves a finished game. Finishing the same game again (after "Back to Game")
    /// updates its record instead of creating a duplicate.
    func record(_ state: GameState, summary: String?) {
        let context = container.mainContext
        let gameID = state.id
        var descriptor = FetchDescriptor<GameRecord>(predicate: #Predicate { $0.gameID == gameID })
        descriptor.fetchLimit = 1

        if let existing = try? context.fetch(descriptor).first {
            existing.update(from: state, summary: summary)
        } else {
            context.insert(GameRecord(state: state, summary: summary))
        }
        try? context.save()
        trim(context)
    }

    /// Saves a finished BucketGolf round. The winner (lowest total) goes in the first slot and
    /// the runner-up in the second; everyone's totals and scores to par go in the summary.
    func record(playerGame state: PlayerGameState, summary: String) {
        let context = container.mainContext
        let gameID = state.id
        var descriptor = FetchDescriptor<GameRecord>(predicate: #Predicate { $0.gameID == gameID })
        descriptor.fetchLimit = 1
        let record: GameRecord
        if let existing = try? context.fetch(descriptor).first {
            record = existing
        } else {
            record = GameRecord(state: GameState(config: SportCatalog.defaultConfig(for: .bucketGolf)), summary: nil)
            record.gameID = gameID
            record.startedAt = state.createdAt
            context.insert(record)
        }
        let order = state.standings
        let first = order.first ?? 0
        let second = order.count > 1 ? order[1] : nil
        record.sportRaw = SportKind.bucketGolf.rawValue
        record.title = "Bucket Golf"
        record.teamAName = state.config.playerName(first)
        record.teamAColorRaw = state.config.color(first).rawValue
        record.scoreA = state.total(first)
        record.teamBName = second.map { state.config.playerName($0) } ?? "Solo"
        record.teamBColorRaw = second.map { state.config.color($0).rawValue } ?? TeamColor.silver.rawValue
        record.scoreB = second.map { state.total($0) } ?? 0
        record.finalPeriodLabel = "\(state.config.holes) holes"
        record.wentToOvertime = false
        record.finishedAt = Date()
        record.summary = summary
        let tied = second.map { state.total($0) == state.total(first) } ?? false
        record.declaredWinnerRaw = tied ? -1 : 0
        try? context.save()
        trim(context)
    }

    private func trim(_ context: ModelContext) {
        var descriptor = FetchDescriptor<GameRecord>(sortBy: [SortDescriptor(\.finishedAt, order: .reverse)])
        descriptor.fetchOffset = keepLimit
        guard let old = try? context.fetch(descriptor), !old.isEmpty else { return }
        for record in old {
            context.delete(record)
        }
        try? context.save()
    }
}
