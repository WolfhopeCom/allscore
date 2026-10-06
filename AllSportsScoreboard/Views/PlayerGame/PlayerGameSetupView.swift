import SwiftUI

/// BucketGolf setup: players in tee order and the number of holes. Every hole is par 3.
struct PlayerGameSetupView: View {
    let onStart: (PlayerGameConfig) -> Void

    @State private var config: PlayerGameConfig
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    init(initialConfig: PlayerGameConfig, onStart: @escaping (PlayerGameConfig) -> Void) {
        _config = State(initialValue: initialConfig)
        self.onStart = onStart
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach($config.players) { $player in
                        PlayerEditorRow(player: $player)
                    }
                    .onDelete { offsets in
                        if config.players.count - offsets.count >= 1 { config.players.remove(atOffsets: offsets) }
                    }
                    .onMove { config.players.move(fromOffsets: $0, toOffset: $1) }

                    if config.players.count < PlayerGameConfig.maxPlayers {
                        Button {
                            addPlayer()
                        } label: {
                            Label("Add Player", systemImage: "plus.circle.fill")
                        }
                    }
                } header: {
                    Text("Players · \(config.players.count)")
                } footer: {
                    Text("This is the tee order for hole 1. After that, the best score on the last hole tees off first. Swipe a player to remove them.")
                }
                .listRowBackground(theme.panel)

                Section {
                    Picker("Holes", selection: $config.holes) {
                        ForEach(PlayerGameConfig.holeOptions, id: \.self) { holes in
                            Text("\(holes)").tag(holes)
                        }
                    }
                    .pickerStyle(.segmented)
                    LabeledContent("Course par", value: "\(config.coursePar) (par 3 every hole)")
                } header: {
                    Text("Course")
                }
                .listRowBackground(theme.panel)

                Section {
                    ruleRow("Miss", "Every swing is 1 stroke. Hitting only the flagstick is a miss.")
                    ruleRow("Hit Bucket", "Any contact with the outside of the bucket completes the hole.")
                    ruleRow("In the Bucket", "Chip it in and the hole score gets a 1-stroke bonus: 3 swings = 2.")
                    ruleRow("Hazard", "Water or bushes: the swing plus 1 penalty stroke. Drop no closer to the bucket.")
                } header: {
                    Text("Scoring")
                } footer: {
                    Text("One club for the whole round. Lowest total wins. Holes of about 10 to 40 yards work well.")
                }
                .listRowBackground(theme.panel)
            }
            .scrollContentBackground(.hidden)
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Bucket Golf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { EditButton() }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onStart(config.sanitized())
                } label: {
                    Label("Tee Off", systemImage: "play.fill")
                        .font(.boardLabel(17))
                        .tracking(1)
                        .foregroundStyle(theme.onClock)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.clock))
                }
                .buttonStyle(PressableStyle(scale: 0.98))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(theme.background.opacity(0.94).ignoresSafeArea())
            }
        }
    }

    private func ruleRow(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.primaryText)
            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func addPlayer() {
        let used = Set(config.players.map(\.color))
        let color = TeamColor.allCases.first { !used.contains($0) } ?? .silver
        config.players.append(PlayerConfig(name: "Player \(config.players.count + 1)", color: color))
    }
}
