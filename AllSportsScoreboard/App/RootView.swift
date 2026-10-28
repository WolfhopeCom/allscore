import SwiftUI
import StoreKit

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
    @Environment(\.requestReview) private var requestReview

    @State private var session: GameSession?
    @State private var playerSession: PlayerGameSession?
    @State private var isScoreboardPresented = false
    @State private var isPlayerBoardPresented = false
    @State private var setupSport: SportKind?
    @State private var showPlayerSetup = false
    @State private var pending: PendingGame?
    @State private var replacement: PendingGame?
    @State private var opensFullScreen = false
    /// A quick action closed the game; don't follow it with an ad or rating prompt.
    @State private var skipNextLeftGame = false
    @State private var showsSettingsAsRoot = false

    var body: some View {
        NavigationStack {
            if showsSettingsAsRoot {
                SettingsView()
            } else {
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
                onQuickStart: quickStart,
                onResume: {
                    Feedback.shared.play(.tap)
                    if playerSession != nil { isPlayerBoardPresented = true } else { isScoreboardPresented = true }
                }
            )
            }
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
        .fullScreenCover(isPresented: $isScoreboardPresented, onDismiss: leftGame) {
            if let session {
                ScoreboardView(session: session, onExit: { isScoreboardPresented = false }, startsFullScreen: opensFullScreen)
            }
        }
        .fullScreenCover(isPresented: $isPlayerBoardPresented, onDismiss: leftGame) {
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
        .modifier(PurchaseStatusAlert())
        .onAppear {
            #if DEBUG
            if let scene = DemoScene.current {
                openDemo(scene)
                return
            }
            #endif
            restoreSavedGame()
            PurchaseStore.shared.start()
            AdManager.shared.start()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { session?.handleBecameActive() }
            if phase == .background { updateResumeShortcut() }
        }
        .onChange(of: QuickActionRouter.shared.pending) { _, action in
            if let action { perform(action) }
        }
        .task {
            // A quick action that launched the app arrives before the first frame.
            if let action = QuickActionRouter.shared.pending { perform(action) }
        }
    }

    private func quickStart() {
        if SportCatalog.isPlayerGame(settings.defaultSport) {
            requestStart(.players(settings.playerGameDefaults()))
        } else {
            requestStart(.standard(settings.gameDefaults(for: settings.defaultSport)))
        }
    }

    /// Runs a home-screen quick action, closing whatever is open first.
    private func perform(_ action: QuickAction) {
        QuickActionRouter.shared.pending = nil
        let wasShowingSomething = isScoreboardPresented || isPlayerBoardPresented || setupSport != nil || showPlayerSetup
        if isScoreboardPresented || isPlayerBoardPresented { skipNextLeftGame = true }
        isScoreboardPresented = false
        isPlayerBoardPresented = false
        setupSport = nil
        showPlayerSetup = false
        Task { @MainActor in
            if wasShowingSomething { try? await Task.sleep(for: .milliseconds(500)) }
            switch action {
            case .quickStart:
                quickStart()
            case .resume:
                if playerSession != nil {
                    isPlayerBoardPresented = true
                } else if session != nil {
                    isScoreboardPresented = true
                }
            case .bucketGolf:
                showPlayerSetup = true
            case .cornhole:
                setupSport = .cornhole
            }
        }
    }

    /// Adds "Resume Game" to the icon's quick actions while a game is in progress.
    private func updateResumeShortcut() {
        let inProgress = (session?.isInProgress ?? false) || (playerSession?.isInProgress ?? false)
        UIApplication.shared.shortcutItems = inProgress ? [QuickAction.resumeItem] : []
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

    #if DEBUG
    private func openDemo(_ scene: DemoScene) {
        scene.applyOrientation()
        switch scene {
        case .settings:
            showsSettingsAsRoot = true
        case .home:
            break
        case .basketball:
            session = GameSession(state: DemoScene.basketball())
            isScoreboardPresented = true
        case .fullScreen:
            session = GameSession(state: DemoScene.basketball(period: 4, scores: [71, 70], remaining: 24.4))
            opensFullScreen = true
            isScoreboardPresented = true
        case .pickleball:
            session = GameSession(state: DemoScene.pickleball())
            isScoreboardPresented = true
        case .cornhole:
            session = GameSession(state: DemoScene.cornhole())
            isScoreboardPresented = true
        case .lacrosse:
            session = GameSession(state: DemoScene.lacrosse())
            isScoreboardPresented = true
        case .darts, .dartsPortrait:
            session = GameSession(state: DemoScene.darts())
            isScoreboardPresented = true
        case .soccer:
            settings.appearance = .daylight
            session = GameSession(state: DemoScene.soccer())
            isScoreboardPresented = true
        case .final:
            let game = GameSession(state: DemoScene.basketball(period: 4, scores: [92, 88], remaining: 30))
            session = game
            isScoreboardPresented = true
            // End it once the scoreboard is on screen, the way a real game finishes.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                game.endGame()
            }
        case .bucketGolf:
            playerSession = DemoScene.bucketGolf()
            isPlayerBoardPresented = true
        }
    }
    #endif

    /// Leaving a finished game is the one moment a full-screen ad may appear (free version only).
    /// It's also the best moment to ask for a rating, and the two never happen together.
    private func leftGame() {
        if skipNextLeftGame {
            skipNextLeftGame = false
            return
        }
        defer {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                AdManager.shared.resumePendingConsent()
            }
        }
        let finishedID: UUID?
        if let session, session.state.phase == .final {
            finishedID = session.state.id
        } else if let playerSession, playerSession.state.phase == .final {
            finishedID = playerSession.state.id
        } else {
            finishedID = nil
        }
        guard let finishedID else { return }
        #if DEBUG
        if DemoScene.current != nil { return }
        #endif
        if ReviewPrompt.recordFinishedGame(id: finishedID) {
            Task { @MainActor in
                // Let the scoreboard finish sliding away first.
                try? await Task.sleep(for: .milliseconds(600))
                requestReview()
            }
        } else {
            AdManager.shared.gameDidFinish(id: finishedID)
        }
    }

    private func launchPendingGame() {
        guard let game = pending else {
            // Setup was cancelled: a consent form held back while it was open can show now.
            AdManager.shared.resumePendingConsent()
            return
        }
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
            let state = GameState(config: config)
            SessionStore.save(state)
            session = GameSession(state: state)
            Feedback.shared.play(.tap)
            isScoreboardPresented = true
        case .players(let config):
            SessionStore.clear()
            let state = PlayerGameState(config: config)
            PlayerSessionStore.save(state)
            playerSession = PlayerGameSession(state: state)
            Feedback.shared.play(.tap)
            isPlayerBoardPresented = true
        }
    }
}
