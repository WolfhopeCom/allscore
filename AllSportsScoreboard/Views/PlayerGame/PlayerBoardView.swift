import SwiftUI

/// BucketGolf, scored like the official scorecard: one card per player for the hole being
/// played, with Strokes, In the Bucket (−1) and Hazard (+1). Prev and Next move between holes.
struct PlayerBoardView: View {
    let session: PlayerGameSession
    let onExit: () -> Void

    @Environment(\.theme) private var theme
    @Environment(AppSettings.self) private var settings
    @State private var showPlayersSheet = false
    @State private var confirmReset = false
    @State private var confirmEnd = false

    var body: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            // Two cards across when sideways or on a wide screen (iPad).
            let twoUp = landscape || geometry.size.width >= 700
            ZStack {
                theme.background.ignoresSafeArea()
                VStack(spacing: 10) {
                    topBar(showsHole: landscape)
                    if !landscape {
                        holeHeader
                    }
                    LeaderboardStrip(session: session)
                    ScrollView {
                        LazyVGrid(columns: columns(twoUp: twoUp), spacing: 12) {
                            ForEach(0..<session.state.playerCount, id: \.self) { player in
                                PlayerHoleCard(session: session, player: player)
                            }
                        }
                        .padding(.bottom, 4)
                    }
                    .scrollIndicators(.hidden)
                    bottomBar
                }
                .padding(.horizontal, landscape ? 12 : 14)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .id(landscape)
                .transition(.identity)

                if session.phase == .final {
                    PlayerFinalOverlay(session: session, onHome: leave)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: session.phase == .final)
        .onAppear {
            ScreenAwake.set(settings.keepScreenAwake)
            Task { @MainActor in Feedback.shared.prewarmSounds() }
        }
        .onDisappear { ScreenAwake.set(false) }
        .onChange(of: session.phase) { ScreenAwake.set(settings.keepScreenAwake && session.phase != .final) }
        .sheet(isPresented: $showPlayersSheet) { PlayersEditSheet(session: session) }
        .confirmationDialog("Reset this round?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset Scores", role: .destructive) { session.resetGame() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every scorecard is cleared and play starts again on hole 1.")
        }
        .confirmationDialog("End the round now?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End Round", role: .destructive) { session.endGame() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Current totals become final and are saved to History.")
        }
    }

    private func columns(twoUp: Bool) -> [GridItem] {
        twoUp
            ? [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
            : [GridItem(.flexible())]
    }

    /// "Hole 3 of 9" and "Par 3", big, as on a printed scorecard.
    private var holeHeader: some View {
        VStack(spacing: 2) {
            Text("Hole \(session.hole) of \(session.config.holes)")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(theme.primaryText)
                .contentTransition(.numericText())
            Text("Par \(PlayerGameConfig.par) · Stroke Play")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.clock)
        }
        .frame(maxWidth: .infinity)
        .animation(.snappy(duration: 0.25), value: session.hole)
        .accessibilityElement(children: .combine)
    }

    private func topBar(showsHole: Bool) -> some View {
        HStack(spacing: 8) {
            Button(action: leave) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle(scale: 0.9))
            .accessibilityLabel("Home")

            HStack(spacing: 6) {
                Image(systemName: "figure.golf")
                    .font(.system(size: 14, weight: .semibold))
                Text("BUCKET GOLF")
                    .font(.boardLabel(12))
                    .tracking(1.6)
            }
            .foregroundStyle(theme.secondaryText)

            Spacer(minLength: 8)

            Menu {
                let soundTitle: String = settings.soundEnabled ? "Mute Sounds" : "Turn Sounds On"
                Button("Edit Players", systemImage: "pencil") { showPlayersSheet = true }
                Button(soundTitle, systemImage: settings.soundEnabled ? "speaker.slash" : "speaker.wave.2") {
                    settings.soundEnabled.toggle()
                }
                Divider()
                if session.phase != .final {
                    Button("End Round", systemImage: "flag.checkered") { confirmEnd = true }
                }
                Button("Reset Round", systemImage: "arrow.counterclockwise", role: .destructive) { confirmReset = true }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(theme.primaryText)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(theme.control))
            }
            .accessibilityLabel("Game menu")
        }
        .frame(height: 44)
        .overlay {
            if showsHole {
                StatusPill(text: session.statusText, tone: session.statusTone)
                    .frame(maxWidth: 260)
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            BarIconButton(symbol: "arrow.uturn.backward", label: "Undo", isEnabled: session.canUndo) {
                session.undo()
            }
            Button {
                session.previousHole()
            } label: {
                Label("Prev", systemImage: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .frame(width: 104, height: 58)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.control))
            }
            .buttonStyle(PressableStyle(scale: 0.97))
            .disabled(session.hole <= 1)
            .opacity(session.hole <= 1 ? 0.4 : 1)
            .accessibilityLabel("Previous hole")

            Button {
                session.nextHole()
            } label: {
                HStack(spacing: 8) {
                    Text(session.nextTitle.uppercased())
                        .font(.boardLabel(17))
                        .tracking(1.2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Image(systemName: session.isLastHole ? "flag.checkered" : "chevron.right")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundStyle(theme.onClock)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.clock))
                .shadow(color: theme.clock.opacity(0.4 * theme.glow), radius: 14)
            }
            .buttonStyle(PressableStyle(scale: 0.97))
            .accessibilityLabel(session.nextTitle)
        }
        .frame(height: 58)
    }

    private func leave() {
        ScreenAwake.set(false)
        onExit()
    }
}

/// Everyone's running total, best first.
private struct LeaderboardStrip: View {
    let session: PlayerGameSession
    @Environment(\.theme) private var theme

    var body: some View {
        let state = session.state
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Text("LEADERBOARD")
                    .font(.boardLabel(11))
                    .tracking(1.8)
                    .foregroundStyle(theme.clock)
                    .padding(.trailing, 4)
                ForEach(Array(state.standings.enumerated()), id: \.element) { rank, player in
                    HStack(spacing: 6) {
                        Text("\(rank + 1)")
                            .font(.system(size: 13, weight: .semibold).monospacedDigit())
                            .foregroundStyle(theme.tertiaryText)
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(theme.color(session.config.color(player)))
                            .frame(width: 3, height: 14)
                        Text(session.config.playerName(player))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(theme.primaryText)
                            .lineLimit(1)
                        Text(session.totalText(player))
                            .font(.system(size: 17, weight: .bold).monospacedDigit())
                            .foregroundStyle(theme.primaryText)
                            .contentTransition(.numericText())
                        Text(session.parText(player))
                            .font(.system(size: 13, weight: .semibold).monospacedDigit())
                            .foregroundStyle(theme.secondaryText)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(Capsule().fill(theme.panel))
                    .overlay(Capsule().strokeBorder(theme.panelStroke))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(rank + 1). \(session.config.playerName(player)), \(session.totalText(player)), \(session.parText(player)) to par")
                }
            }
        }
        .scrollIndicators(.hidden)
        .frame(height: 34)
        .animation(.snappy(duration: 0.3), value: state.standings)
    }
}

/// One player's card for the current hole: score, Strokes, In the Bucket, Hazard.
private struct PlayerHoleCard: View {
    let session: PlayerGameSession
    let player: Int
    @Environment(\.theme) private var theme

    var body: some View {
        let card = session.holeScore(player)
        let color = theme.color(session.config.color(player))
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let disabled = session.phase == .final

        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 4, height: 24)
                Text(session.config.playerName(player))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 8)
                scoreBox(card)
            }

            row(symbol: "figure.golf", title: "Strokes") {
                stepper(value: card.swings, label: "Strokes", disabled: disabled,
                        minus: { session.adjustSwings(player, by: -1) },
                        plus: { session.adjustSwings(player, by: 1) })
            }
            row(symbol: "flag", title: "In the Bucket (−1)") {
                Toggle("In the Bucket", isOn: Binding(
                    get: { card.inBucket },
                    set: { if $0 != card.inBucket { session.toggleBucket(player) } }
                ))
                .labelsHidden()
                .tint(theme.clock)
                .disabled(disabled)
            }
            row(symbol: "exclamationmark.triangle", title: "Hazard (+1)") {
                stepper(value: card.hazards, label: "Hazards", disabled: disabled,
                        minus: { session.adjustHazards(player, by: -1) },
                        plus: { session.adjustHazards(player, by: 1) })
            }
        }
        .padding(16)
        .background(shape.fill(theme.panel))
        .overlay(shape.strokeBorder(theme.panelStroke))
    }

    private func scoreBox(_ card: HoleCard) -> some View {
        VStack(spacing: 0) {
            Text("SCORE")
                .font(.boardLabel(10))
                .tracking(1.6)
                .foregroundStyle(theme.secondaryText)
            Text(card.isFinished ? "\(card.strokes)" : "–")
                .font(.score(30))
                .foregroundStyle(theme.primaryText)
                .contentTransition(.numericText())
            if let term = session.holeTerm(player) {
                Text(term.uppercased())
                    .font(.boardLabel(9))
                    .tracking(1)
                    .foregroundStyle(theme.clock)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(width: 92, height: 72)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.control))
        .animation(.snappy(duration: 0.2), value: card)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.isFinished ? "Hole score \(card.strokes)\(session.holeTerm(player).map { ", \($0)" } ?? "")" : "No score yet")
    }

    private func row<Control: View>(symbol: String, title: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(theme.secondaryText)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 17))
                .foregroundStyle(theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            control()
        }
        .frame(minHeight: 48)
    }

    private func stepper(value: Int, label: String, disabled: Bool, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack(spacing: 0) {
            Button(action: minus) {
                Image(systemName: "minus")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Fewer \(label.lowercased())")
            Text("\(value)")
                .font(.system(size: 22, weight: .bold).monospacedDigit())
                .frame(minWidth: 36)
                .contentTransition(.numericText())
                .accessibilityLabel("\(label): \(value)")
            Button(action: plus) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("More \(label.lowercased())")
        }
        .foregroundStyle(theme.primaryText)
        .buttonStyle(PressableStyle(scale: 0.9))
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.control))
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
        .animation(.snappy(duration: 0.2), value: value)
    }
}

private struct PlayerFinalOverlay: View {
    let session: PlayerGameSession
    let onHome: () -> Void

    @Environment(\.theme) private var theme
    @State private var appeared = false

    var body: some View {
        let state = session.state
        let winners = session.winnerNames

        ZStack {
            theme.background.opacity(0.8).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("FINAL · \(session.config.holes) HOLES")
                    .font(.boardLabel(14))
                    .tracking(5)
                    .foregroundStyle(theme.clock)
                Text(winners.count == 1 ? "\(winners[0]) wins" : "Tie: \(winners.joined(separator: " & "))")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)

                VStack(spacing: 6) {
                    ForEach(Array(state.standings.prefix(8).enumerated()), id: \.element) { rank, index in
                        HStack(spacing: 10) {
                            Text("\(rank + 1)")
                                .font(.system(size: 14, weight: .bold).monospacedDigit())
                                .foregroundStyle(theme.tertiaryText)
                                .frame(width: 18)
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(theme.color(session.config.color(index)))
                                .frame(width: 3, height: 18)
                            Text(session.config.playerName(index))
                                .font(.system(size: 17, weight: rank == 0 ? .bold : .medium))
                                .foregroundStyle(theme.primaryText)
                                .lineLimit(1)
                            Spacer()
                            Text(session.parText(index))
                                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                                .foregroundStyle(theme.secondaryText)
                            Text(session.totalText(index))
                                .font(.score(24))
                                .foregroundStyle(theme.primaryText)
                        }
                    }
                }
                .frame(maxWidth: 360)

                HStack(spacing: 10) {
                    button("Back to Round", symbol: "arrow.uturn.backward", prominent: false) { session.reopen() }
                    button("Rematch", symbol: "arrow.counterclockwise", prominent: true) { session.rematch() }
                    button("Home", symbol: "house", prominent: false, action: onHome)
                }
            }
            .padding(28)
            .frame(maxWidth: 560)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(theme.panel)
                    .shadow(color: theme.clock.opacity(0.25 * theme.glow), radius: 40)
            )
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(theme.clock.opacity(0.35)))
            .overlay(alignment: .topTrailing) {
                ShareResultButton(text: session.shareText)
                    .padding(12)
            }
            .padding(20)
            .scaleEffect(appeared ? 1 : 0.92)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.55, bounce: 0.3)) { appeared = true }
        }
        .accessibilityAddTraits(.isModal)
    }

    private func button(_ title: String, symbol: String, prominent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(prominent ? theme.onClock : theme.primaryText)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(prominent ? theme.clock : theme.control))
        }
        .buttonStyle(PressableStyle())
    }
}

/// Rename players and change colors mid-round.
private struct PlayersEditSheet: View {
    let session: PlayerGameSession
    @State private var players: [PlayerConfig]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    init(session: PlayerGameSession) {
        self.session = session
        _players = State(initialValue: session.config.players)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach($players) { $player in
                        PlayerEditorRow(player: $player)
                    }
                }
                .listRowBackground(theme.panel)
            }
            .scrollContentBackground(.hidden)
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Players")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        session.updatePlayers(players)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Name field plus color swatches for one player.
struct PlayerEditorRow: View {
    @Binding var player: PlayerConfig
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.color(player.color))
                    .frame(width: 4, height: 24)
                TextField("Player name", text: $player.name)
                    .font(.system(size: 18, weight: .semibold))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onChange(of: player.name) { _, newValue in
                        if newValue.count > 20 { player.name = String(newValue.prefix(20)) }
                    }
            }
            ColorSwatchRow(selection: $player.color)
        }
        .padding(.vertical, 2)
    }
}
