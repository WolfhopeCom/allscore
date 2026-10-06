import SwiftUI

/// A game waiting to start, of either kind.
private enum PendingGame {
    case standard(GameConfig)
    case players(PlayerGameConfig)
}

/// Owns the one active game and moves between Home, Setup and the Scoreboard.
/// Two-sided sports run on `GameSession`; Bucket Golf runs on `PlayerGameSession`.
struct RootView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase

    @State private var session: GameSession?
    @State private var playerSession: PlayerGameSession?
    @State private var isScoreboardPresented = false
    @State private var isPlayerBoardPresented = false
    @State private var setupSport: SportKind?
    @State private var showPlayerSetup = false
    @State private var pending: PendingGame?
    @State private var replacement: PendingGame?

    var body: some View {
        NavigationStack {
            HomeView(
                session: session,
                playerSession: playerSession,
                onSelectSport: { sport in
                    Feedback.shared.play(.tap)
                    if SportCatalog.isPlayerGame(sport) {
                        showPlayerSetup = true
                    } else {
                        setupSport = sport
                    }
                },
                onQuickStart: {
                    if SportCatalog.isPlayerGame(settings.defaultSport) {
                        requestStart(.players(settings.playerGameDefaults()))
                    } else {
                        requestStart(.standard(settings.gameDefaults(for: settings.defaultSport)))
                    }
                },
                onResume: {
                    Feedback.shared.play(.tap)
                    if playerSession != nil { isPlayerBoardPresented = true } else { isScoreboardPresented = true }
                }
            )
        }
        .sheet(item: $setupSport, onDismiss: launchPendingGame) { sport in
            GameSetupView(initialConfig: settings.gameDefaults(for: sport)) { config in
                settings.saveGameDefaults(config)
                pending = .standard(config)
                setupSport = nil
            }
        }
        .sheet(isPresented: $showPlayerSetup, onDismiss: launchPendingGame) {
            PlayerGameSetupView(initialConfig: settings.playerGameDefaults()) { config in
                settings.savePlayerGameDefaults(config)
                pending = .players(config)
                showPlayerSetup = false
            }
        }
        .fullScreenCover(isPresented: $isScoreboardPresented) {
            if let session {
                ScoreboardView(session: session) { isScoreboardPresented = false }
            }
        }
        .fullScreenCover(isPresented: $isPlayerBoardPresented) {
            if let playerSession {
                PlayerBoardView(session: playerSession) { isPlayerBoardPresented = false }
            }
        }
        .confirmationDialog(
            "Replace the current game?",
            isPresented: Binding(
                get: { replacement != nil },
                set: { if !$0 { replacement = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Start New Game", role: .destructive) {
                if let game = replacement {
                    replacement = nil
                    start(game)
                }
            }
            Button("Cancel", role: .cancel) {
                replacement = nil
            }
        } message: {
            Text("Your current game hasn't finished. Starting a new one will discard it.")
        }
        .onAppear(perform: restoreSavedGame)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { session?.handleBecameActive() }
        }
    }

    /// Resumes whichever kind of game was saved most recently.
    private func restoreSavedGame() {
        guard session == nil, playerSession == nil else { return }
        let standardDate = SessionStore.savedAt ?? .distantPast
        let playerDate = PlayerSessionStore.savedAt ?? .distantPast
        if playerDate > standardDate, let saved = PlayerSessionStore.load() {
            playerSession = PlayerGameSession(state: saved)
        } else if let saved = SessionStore.load() {
            session = GameSession(state: saved)
        }
        if session != nil || playerSession != nil { Feedback.shared.prewarmSounds() }
    }

    private func launchPendingGame() {
        guard let game = pending else { return }
        pending = nil
        requestStart(game)
    }

    private func requestStart(_ game: PendingGame) {
        let busy = (session?.isInProgress ?? false) || (playerSession?.isInProgress ?? false)
        if busy {
            replacement = game
        } else {
            start(game)
        }
    }

    private func start(_ game: PendingGame) {
        session?.shutdown()
        session = nil
        playerSession = nil
        switch game {
        case .standard(let config):
            PlayerSessionStore.clear()
            session = GameSession(state: GameState(config: config))
            Feedback.shared.play(.tap)
            isScoreboardPresented = true
        case .players(let config):
            SessionStore.clear()
            playerSession = PlayerGameSession(state: PlayerGameState(config: config))
            Feedback.shared.play(.tap)
            isPlayerBoardPresented = true
        }
    }
}
