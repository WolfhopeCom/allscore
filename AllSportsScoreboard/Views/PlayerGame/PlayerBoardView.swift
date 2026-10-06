import SwiftUI

/// BucketGolf: the player who's up fills most of the screen with four big shot buttons
/// (miss, hazard, hit bucket, in the bucket) so the phone can sit beside the bucket.
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
            ZStack {
                theme.background.ignoresSafeArea()
                VStack(spacing: 12) {
                    topBar
                    if landscape {
                        HStack(spacing: 12) {
                            CurrentPlayerPanel(session: session, compact: false)
                            StandingsPanel(session: session)
                                .frame(width: max(260, geometry.size.width * 0.36))
                        }
                    } else {
                        VStack(spacing: 12) {
                            CurrentPlayerPanel(session: session, compact: true)
                            StandingsPanel(session: session)
                                .frame(height: min(geometry.size.height * 0.32, CGFloat(60 + 44 * session.state.playerCount)))
                        }
                    }
                    controls
                }
                .padding(.horizontal, landscape ? 12 : 14)
                .padding(.top, 4)
                .padding(.bottom, 8)

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

    private var topBar: some View {
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
            StatusPill(text: session.statusText, tone: session.statusTone)
                .frame(maxWidth: 240)
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            BarIconButton(symbol: "arrow.uturn.backward", label: "Undo last shot", isEnabled: session.canUndo) {
                session.undo()
            }
            Button {
                session.advance()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: session.primarySymbol)
                        .font(.system(size: 18, weight: .bold))
                    Text(session.primaryTitle.uppercased())
                        .font(.boardLabel(17))
                        .tracking(1.2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .foregroundStyle(theme.onClock)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.clock))
                .shadow(color: theme.clock.opacity((session.primaryIsReady ? 0.6 : 0.3) * theme.glow), radius: session.primaryIsReady ? 20 : 12)
                .scaleEffect(session.primaryIsReady ? 1.02 : 1)
                .animation(.spring(duration: 0.35, bounce: 0.4), value: session.primaryIsReady)
            }
            .buttonStyle(PressableStyle(scale: 0.97))
            .accessibilityLabel(session.primaryTitle)
        }
        .frame(height: 58)
    }

    private func leave() {
        ScreenAwake.set(false)
        onExit()
    }
}

/// The player who's up: this hole's strokes, the shot trail, total, and the four shot buttons.
private struct CurrentPlayerPanel: View {
    let session: PlayerGameSession
    let compact: Bool

    @Environment(\.theme) private var theme

    private struct Pulse {
        var scale: Double = 1
    }

    var body: some View {
        let state = session.state
        let index = state.current
        let card = session.currentCard
        let color = theme.color(session.config.color(index))
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        VStack(spacing: compact ? 8 : 12) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 4, height: 28)
                VStack(alignment: .leading, spacing: 0) {
                    Text(card.isFinished ? "HOLE DONE" : "UP NOW")
                        .font(.boardLabel(10))
                        .tracking(2)
                        .foregroundStyle(card.isFinished ? theme.clock : theme.secondaryText)
                    Text(session.currentName.uppercased())
                        .font(.boardLabel(compact ? 22 : 26))
                        .tracking(1.4)
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 0) {
                    Text("TOTAL")
                        .font(.boardLabel(10))
                        .tracking(2)
                        .foregroundStyle(theme.secondaryText)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(session.totalText(index))
                            .font(.score(compact ? 26 : 30))
                            .foregroundStyle(theme.primaryText)
                            .contentTransition(.numericText())
                        Text(session.parText(index))
                            .font(.system(size: 15, weight: .bold).monospacedDigit())
                            .foregroundStyle(theme.clock)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Total \(session.totalText(index)), \(session.parText(index)) to par")
            }

            GeometryReader { geometry in
                let text = "\(card.strokes)"
                VStack(spacing: 4) {
                    Text("HOLE \(state.hole) · PAR \(PlayerGameConfig.par)")
                        .font(.boardLabel(11))
                        .tracking(2)
                        .foregroundStyle(theme.secondaryText)
                    Text(text)
                        .font(.score(min(geometry.size.height * 0.62, geometry.size.width / (CGFloat(max(2, text.count)) * 0.64))))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.28), value: text)
                        .keyframeAnimator(initialValue: Pulse(), trigger: session.bump) { content, pulse in
                            content.scaleEffect(pulse.scale)
                        } keyframes: { _ in
                            KeyframeTrack(\.scale) {
                                SpringKeyframe(1.08, duration: 0.11, spring: .snappy)
                                SpringKeyframe(1.0, duration: 0.4, spring: .bouncy)
                            }
                        }
                    Text(trail(card))
                        .font(.system(size: compact ? 12 : 13, weight: .semibold))
                        .foregroundStyle(card.isFinished ? theme.clock : theme.tertiaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .overlay(alignment: .topTrailing) {
                if let flash = session.flash {
                    Text(flash.text)
                        .font(.system(size: compact ? 20 : 24, weight: .heavy).monospacedDigit())
                        .foregroundStyle(flash.isPositive ? color : theme.secondaryText)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                        .id(flash.id)
                }
            }
            .animation(.spring(duration: 0.3, bounce: 0.35), value: session.flash)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(session.currentName), hole \(state.hole), par 3")
            .accessibilityValue("\(card.strokes) strokes. \(trail(card))")

            shotButtons(color: color, disabled: card.isFinished || session.phase == .final)

            Text("Flagstick only, with no bucket contact? Tap Miss.")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(theme.tertiaryText)
                .frame(maxWidth: .infinity)
        }
        .padding(compact ? 12 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack(alignment: .top) {
                shape.fill(theme.panel)
                LinearGradient(colors: [color.opacity(0.14 * theme.glow), .clear], startPoint: .top, endPoint: .center)
                Rectangle().fill(color).frame(height: 3)
            }
            .clipShape(shape)
        )
        .overlay(shape.strokeBorder(theme.panelStroke))
        .animation(.snappy(duration: 0.3), value: index)
    }

    /// "Miss · Hazard · In the bucket — Birdie"
    private func trail(_ card: HoleCard) -> String {
        if card.shots.isEmpty { return "On the tee" }
        let shots = card.shots.map(\.shortName).joined(separator: " · ")
        if card.isFinished { return "\(shots) — \(GolfTerm.name(strokes: card.strokes))" }
        return shots
    }

    private func shotButtons(color: Color, disabled: Bool) -> some View {
        let height: CGFloat = compact ? 58 : 66
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            shotButton("MISS", detail: "+1 stroke", shot: .miss, tint: color, prominent: false, height: height)
            shotButton("HAZARD", detail: "+1 penalty stroke", shot: .hazard, tint: color, prominent: false, height: height)
            shotButton("HIT BUCKET", detail: "Hole complete", shot: .contact, tint: color, prominent: true, height: height)
            shotButton("IN THE BUCKET", detail: "−1 stroke bonus", shot: .bucketIn, tint: theme.clock, prominent: true, height: height)
        }
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }

    private func shotButton(_ title: String, detail: String, shot: ShotKind, tint: Color, prominent: Bool, height: CGFloat) -> some View {
        Button {
            session.record(shot)
        } label: {
            VStack(spacing: 2) {
                Text(title)
                    .font(.boardLabel(compact ? 15 : 17))
                    .tracking(0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(detail.uppercased())
                    .font(.boardLabel(9.5))
                    .tracking(0.5)
                    .opacity(0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .frame(height: height)
        }
        .buttonStyle(ScoreButtonStyle(tint: tint, prominent: prominent))
        .accessibilityLabel("\(title.capitalized), \(detail)")
    }
}

/// Everyone's scorecard so far. Tap a row to record that player's shots.
private struct StandingsPanel: View {
    let session: PlayerGameSession
    @Environment(\.theme) private var theme

    var body: some View {
        let state = session.state
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let leaders = Set(state.leaders)
        let anyShots = state.cards.joined().contains { !$0.shots.isEmpty }

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("LEADERBOARD")
                    .font(.boardLabel(11))
                    .tracking(2)
                    .foregroundStyle(theme.secondaryText)
                Spacer()
                Text("LOW SCORE WINS · PAR \(session.config.coursePar)")
                    .font(.boardLabel(9.5))
                    .tracking(1)
                    .foregroundStyle(theme.tertiaryText)
            }
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array(state.standings.enumerated()), id: \.element) { rank, index in
                        row(rank: rank, index: index, isLeader: anyShots && leaders.contains(index))
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(12)
        .background(shape.fill(theme.panel))
        .overlay(shape.strokeBorder(theme.panelStroke))
        .animation(.snappy(duration: 0.35), value: state.standings)
    }

    private func row(rank: Int, index: Int, isLeader: Bool) -> some View {
        let state = session.state
        let isUp = index == state.current && state.phase != .final
        let card = state.card(index)
        let holeText = card.shots.isEmpty ? "–" : "\(card.strokes)\(card.isFinished ? " ✓" : "")"
        return Button {
            session.select(player: index)
        } label: {
            HStack(spacing: 10) {
                Text("\(rank + 1)")
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(theme.tertiaryText)
                    .frame(width: 16)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(theme.color(session.config.color(index)))
                    .frame(width: 3, height: 20)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Text(session.config.playerName(index))
                            .font(.system(size: 16, weight: isUp ? .bold : .medium))
                            .foregroundStyle(theme.primaryText)
                            .lineLimit(1)
                        if isLeader {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(theme.clock)
                                .accessibilityLabel("Leading")
                        }
                    }
                    Text("THRU \(state.holesFinished(index)) · HOLE \(holeText)")
                        .font(.boardLabel(9.5))
                        .tracking(0.6)
                        .foregroundStyle(theme.tertiaryText)
                }
                Spacer(minLength: 4)
                Text(session.parText(index))
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundStyle(theme.secondaryText)
                    .frame(minWidth: 26, alignment: .trailing)
                Text(session.totalText(index))
                    .font(.system(size: 20, weight: .bold).monospacedDigit())
                    .foregroundStyle(theme.primaryText)
                    .contentTransition(.numericText())
                    .frame(minWidth: 28, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isUp ? theme.clock.opacity(0.14) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isUp ? theme.clock.opacity(0.5) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(session.config.playerName(index)), total \(session.totalText(index)), \(session.parText(index)) to par, thru \(state.holesFinished(index))\(isUp ? ", up now" : "")")
        .accessibilityHint("Record this player's shots")
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
