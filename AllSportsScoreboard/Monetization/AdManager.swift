import SwiftUI
import UIKit
import AppTrackingTransparency
import GoogleMobileAds
import UserMessagingPlatform

/// Runs ads for the free version: consent (Google's UMP, required in the EU/UK), the App
/// Tracking Transparency prompt, the Mobile Ads SDK, and the occasional post-game full-screen ad.
/// Ads only ever appear on menu screens, never on a live scoreboard.
@Observable
@MainActor
final class AdManager {
    static let shared = AdManager()

    /// The SDK is running and the user's consent choices allow ads to be requested.
    private(set) var isReady = false
    /// The user is in a region where they must be able to change their consent later.
    private(set) var privacyOptionsRequired = false

    /// Whether ad slots should be shown right now.
    var showsAds: Bool { isReady && !PurchaseStore.shared.adsRemoved }

    @ObservationIgnored private var hasStarted = false
    /// The consent form was due while a game was on screen; show it once the game is closed.
    @ObservationIgnored private var consentPending = false
    @ObservationIgnored private var interstitial: InterstitialAd?
    @ObservationIgnored private var isLoadingInterstitial = false
    @ObservationIgnored private let delegate = InterstitialDelegate()
    @ObservationIgnored private let defaults = UserDefaults.standard

    private enum Key {
        static let finishedGames = "ads.finishedGames"
        static let lastShown = "ads.lastInterstitial"
        static let lastCountedGame = "ads.lastCountedGame"
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private init() {
        delegate.onFinish = { [weak self] in
            self?.loadInterstitial()
        }
    }

    /// Call once the first screen is on screen. Owners of Remove Ads never see a consent or tracking prompt.
    func start() {
        guard !hasStarted, !Self.isRunningTests, !PurchaseStore.shared.adsRemoved else { return }
        hasStarted = true

        // Choices made on an earlier launch let ads start straight away.
        if ConsentInformation.shared.canRequestAds {
            startSDK()
        }

        ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters()) { [weak self] _ in
            Task { @MainActor in
                self?.presentConsentIfRequired()
            }
        }
    }

    private func presentConsentIfRequired() {
        guard let root = UIApplication.topViewController else {
            finishConsent()
            return
        }
        // Never put a form (or the tracking prompt that follows) over a scoreboard.
        guard root === UIApplication.rootViewController else {
            consentPending = true
            return
        }
        consentPending = false
        ConsentForm.loadAndPresentIfRequired(from: root) { [weak self] _ in
            Task { @MainActor in
                self?.finishConsent()
            }
        }
    }

    private func finishConsent() {
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        Task {
            await requestTrackingIfNeeded()
            startSDK()
        }
    }

    private func requestTrackingIfNeeded() async {
        guard !PurchaseStore.shared.adsRemoved,
              ATTrackingManager.trackingAuthorizationStatus == .notDetermined
        else { return }
        // The system ignores the request unless the app is fully active, so let launch settle.
        try? await Task.sleep(for: .seconds(1))
        guard UIApplication.shared.applicationState == .active else { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    private func startSDK() {
        guard ConsentInformation.shared.canRequestAds, !isReady else { return }
        let ads = MobileAds.shared
        // The scoreboard owns the audio session (buzzers play in silent mode); keep the SDK out of it.
        ads.audioVideoManager.isAudioSessionApplicationManaged = true
        // Scoreboards get used at youth games: keep ad content family friendly.
        ads.requestConfiguration.maxAdContentRating = .parentalGuidance
        ads.start { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isReady = true
                self.loadInterstitial()
            }
        }
    }

    /// Call when the menu screens are showing again (a game was just closed).
    func resumePendingConsent() {
        guard consentPending else { return }
        presentConsentIfRequired()
    }

    // MARK: Full-screen ad after a game

    /// Call when the user leaves a finished game. May show a full-screen ad, following `InterstitialPacing`.
    func gameDidFinish(id: UUID) {
        let gameKey = id.uuidString
        guard defaults.string(forKey: Key.lastCountedGame) != gameKey else { return }
        defaults.set(gameKey, forKey: Key.lastCountedGame)
        let finished = defaults.integer(forKey: Key.finishedGames) + 1
        defaults.set(finished, forKey: Key.finishedGames)

        guard showsAds else { return }
        let lastShown = defaults.object(forKey: Key.lastShown) as? Date
        guard InterstitialPacing.shouldShow(now: Date(), lastShown: lastShown, finishedGames: finished) else { return }
        // Only over the menu screens, and never while something else is already up.
        guard let ad = interstitial, let root = UIApplication.topViewController,
              root === UIApplication.rootViewController else {
            loadInterstitial()
            return
        }
        interstitial = nil
        defaults.set(Date(), forKey: Key.lastShown)
        ad.present(from: root)
    }

    private func loadInterstitial() {
        guard showsAds, interstitial == nil, !isLoadingInterstitial else { return }
        isLoadingInterstitial = true
        InterstitialAd.load(with: AdConfig.interstitialUnitID, request: GoogleMobileAds.Request()) { [weak self] ad, _ in
            Task { @MainActor in
                guard let self else { return }
                self.isLoadingInterstitial = false
                ad?.fullScreenContentDelegate = self.delegate
                self.interstitial = ad
            }
        }
    }

    /// Lets users in consent regions change their choices (Settings → Ad Privacy Choices).
    func presentPrivacyOptions() {
        guard let root = UIApplication.topViewController else { return }
        ConsentForm.presentPrivacyOptionsForm(from: root) { [weak self] _ in
            Task { @MainActor in
                self?.startSDK()
            }
        }
    }
}

/// Reloads the next full-screen ad once the current one is gone.
private final class InterstitialDelegate: NSObject, FullScreenContentDelegate {
    var onFinish: (@MainActor () -> Void)?

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in self.onFinish?() }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in self.onFinish?() }
    }
}

extension UIApplication {
    /// The key window's root view controller (the menu screens).
    @MainActor static var rootViewController: UIViewController? {
        let scenes = shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap(\.windows)
        return (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
    }

    /// The view controller currently on top, for presenting consent forms and ads.
    @MainActor static var topViewController: UIViewController? {
        var top = rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
