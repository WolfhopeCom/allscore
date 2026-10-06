import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \GameRecord.finishedAt, order: .reverse) private var records: [GameRecord]
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @State private var confirmClear = false

    var body: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView(
                    "No Games Yet",
                    systemImage: "list.number",
                    description: Text("Finished games are saved here automatically, right on this device.")
                )
            } else {
                List {
                    ForEach(records) { record in
                        HistoryRow(record: record)
                            .listRowBackground(theme.panel)
                    }
                    .onDelete(perform: delete)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear") { confirmClear = true }
                    .disabled(records.isEmpty)
            }
        }
        .confirmationDialog("Delete all saved games?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Delete All Games", role: .destructive, action: clearAll)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            context.delete(records[index])
        }
        try? context.save()
    }

    private func clearAll() {
        for record in records {
            context.delete(record)
        }
        try? context.save()
        Feedback.shared.play(.reset)
    }
}

private struct HistoryRow: View {
    let record: GameRecord
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: SportCatalog.rules(for: record.sport ?? .custom).symbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(theme.clock)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 6) {
                teamLine(name: record.teamAName, score: record.scoreA, color: record.teamAColor, isWinner: record.winner == .a)
                teamLine(name: record.teamBName, score: record.scoreB, color: record.teamBColor, isWinner: record.winner == .b)
                Text(caption)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var caption: String {
        var parts = [record.title]
        if record.wentToOvertime { parts.append(record.finalPeriodLabel) }
        if !record.summary.isEmpty { parts.append(record.summary) }
        parts.append(record.finishedAt.formatted(date: .abbreviated, time: .shortened))
        return parts.joined(separator: " · ")
    }

    private var accessibilitySummary: String {
        let result: String
        switch record.winner {
        case .a: result = "\(record.teamAName) won"
        case .b: result = "\(record.teamBName) won"
        case nil: result = "Tied"
        }
        return "\(record.title). \(record.teamAName) \(record.scoreA), \(record.teamBName) \(record.scoreB). \(result). \(record.finishedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    private func teamLine(name: String, score: Int, color: TeamColor, isWinner: Bool) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(theme.color(color))
                .frame(width: 3, height: 16)
            Text(name)
                .font(.system(size: 17, weight: isWinner ? .bold : .regular))
                .foregroundStyle(isWinner ? theme.primaryText : theme.secondaryText)
                .lineLimit(1)
            Spacer()
            if isWinner {
                Image(systemName: "arrowtriangle.left.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.clock)
            }
            Text("\(score)")
                .font(.score(20))
                .foregroundStyle(isWinner ? theme.primaryText : theme.secondaryText)
        }
    }
}
