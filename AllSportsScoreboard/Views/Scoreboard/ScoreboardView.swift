import SwiftUI

/// The main event. Landscape is the primary layout (teams left and right of the clock);
/// portrait stacks the teams top and bottom.
struct ScoreboardView: View {
    let session: GameSession
    let onExit: () -> Void

    @Environment(\.theme) private var theme
    @Environment(AppSettings.self) private var settings

    @State private var isFullScreen = false
    @State private var showTeamsSheet = false
    @State private var showClockSheet = false
    @State private var confirmReset = false
    @State private var confirmEndGame = false

    var body: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            ZStack {
                theme.background.ignoresSafeArea()

                VStack(spacing: landscape ? 10 : 12) {
                    if !isFullScreen {
                        ScoreboardTopBar(
                            session: session,
                            showsSportName: landscape,
                            onExit: leaveScoreboard,
                            onEditTeams: { showTeamsSheet = true },
                            onAdjustClock: { showClockSheet = true },
                            onEnterFullScreen: { setFullScreen(true) },
                            onSwapSides: { session.swapSides() },
                            onEndGame: { confirmEndGame = true },
                            onReset: { confirmReset = true }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    board(landscape: landscape, size: geometry.size)

                    if !isFullScreen {
                        ControlBar(
                            session: session,
                            compact: !landscape,
                            onAdjustClock: { showClockSheet = true },
                            onEnterFullScreen: { setFullScreen(true) },
                            onEndGame: { confirmEndGame = true }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, landscape ? 12 : 14)
                .padding(.top, isFullScreen ? 10 : 4)
                .padding(.bottom, isFullScreen ? 10 : 8)

                if session.phase == .final {
                    FinalOverlay(session: session, onHome: leaveScoreboard)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
        }
        .animation(.snappy(duration: 0.3), value: isFullScreen)
        .animation(.easeInOut(duration: 0.35), value: session.phase == .final)
        .statusBarHidden(isFullScreen)
        .persistentSystemOverlays(isFullScreen ? .hidden : .automatic)
        .onAppear {
            updateScreenAwake()
            // Render sounds right after the first frame so the presentation never hitches.
            Task { @MainActor in Feedback.shared.prewarmSounds() }
        }
        .onDisappear { ScreenAwake.set(false) }
        .onChange(of: session.phase) { updateScreenAwake() }
        .onChange(of: settings.keepScreenAwake) { updateScreenAwake() }
        .sheet(isPresented: $showTeamsSheet) {
            TeamsEditSheet(session: session)
        }
        .sheet(isPresented: $showClockSheet) {
            ClockAdjustSheet(session: session)
        }
        .confirmationDialog("Reset this game?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset Scores & Clock", role: .destructive) { session.resetGame() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Scores, clock and period go back to the start. This can't be undone.")
        }
        .confirmationDialog("End the game now?", isPresented: $confirmEndGame, titleVisibility: .visible) {
            Button("End Game", role: .destructive) { session.endGame() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The current score becomes final and is saved to History.")
        }
    }

    @ViewBuilder
    private func board(landscape: Bool, size: CGSize) -> some View {
        if landscape {
            HStack(spacing: 12) {
                teamPanel(.a, compact: false)
                ClockPanel(
                    session: session,
                    layout: .column,
                    isFullScreen: isFullScreen,
                    onAdjust: { showClockSheet = true },
                    onExitFullScreen: { setFullScreen(false) }
                )
                .frame(width: max(session.model == .baseball ? 200 : 176, size.width * 0.25))
                teamPanel(.b, compact: false)
            }
        } else {
            VStack(spacing: 12) {
                teamPanel(.a, compact: true)
                ClockPanel(
                    session: session,
                    layout: .row,
                    isFullScreen: isFullScreen,
                    onAdjust: { showClockSheet = true },
                    onExitFullScreen: { setFullScreen(false) }
                )
                .frame(height: centerRowHeight)
                teamPanel(.b, compact: true)
            }
        }
    }

    private func teamPanel(_ side: TeamSide, compact: Bool) -> some View {
        TeamPanel(
            session: session,
            side: side,
            showsControls: !isFullScreen,
            compact: compact,
            onEditTeams: { showTeamsSheet = true }
        )
    }

    /// Portrait height of the center row, sized to what that sport puts there.
    private var centerRowHeight: CGFloat {
        let extra: CGFloat = isFullScreen ? 110 : 0
        switch session.model {
        case .baseball: return 150 + extra
        case .rally, .tennis: return 132 + extra
        case .combat: return 132 + extra
        case .points:
            if session.clockEnabled {
                return (session.rules.tracksPossession ? 132 : 124) + extra
            }
            return 76 + extra
        }
    }

    private func setFullScreen(_ value: Bool) {
        Feedback.shared.play(.tap)
        isFullScreen = value
    }

    private func leaveScoreboard() {
        ScreenAwake.set(false)
        onExit()
    }

    private func updateScreenAwake() {
        ScreenAwake.set(settings.keepScreenAwake && session.phase != .final)
    }
}
