import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.theme) private var theme

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Toggle("Sound Effects", isOn: $settings.soundEnabled)
                if settings.soundEnabled {
                    Slider(value: $settings.volume, in: 0...1) {
                        Text("Volume")
                    } minimumValueLabel: {
                        Image(systemName: "speaker.fill")
                    } maximumValueLabel: {
                        Image(systemName: "speaker.wave.3.fill")
                    } onEditingChanged: { editing in
                        if !editing { Feedback.shared.play(.score(2)) }
                    }
                    .accessibilityLabel("Volume")
                    Toggle("Play in Silent Mode", isOn: $settings.playInSilentMode)
                }
                Toggle("Haptic Feedback", isOn: $settings.hapticsEnabled)
            } header: {
                Text("Sound & Haptics")
            } footer: {
                Text("Play in Silent Mode lets sounds play with your ringer switched off, which is what you want courtside.")
            }
            .listRowBackground(theme.panel)

            Section {
                ForEach(BuzzerStyle.allCases) { style in
                    BuzzerRow(style: style, isSelected: settings.buzzerStyle == style) {
                        settings.buzzerStyle = style
                        Feedback.shared.previewBuzzer(style)
                    }
                }
            } header: {
                Text("Buzzer")
            } footer: {
                Text("Plays at the end of each period and the end of the game. Tap to hear it.")
            }
            .listRowBackground(theme.panel)

            Section {
                ForEach(AppAppearance.allCases) { appearance in
                    ThemeRow(appearance: appearance)
                }
            } header: {
                Text("Appearance")
            } footer: {
                Text(PurchaseStore.shared.adsRemoved
                     ? "Bonus themes are included with Remove Ads."
                     : "Unlock a bonus theme for good by watching one short video. Remove Ads includes them all.")
            }
            .listRowBackground(theme.panel)
            .onAppear {
                if settings.hasLockedAppearances { AdManager.shared.prepareRewarded() }
            }

            Section {
                Toggle("Keep Screen Awake", isOn: $settings.keepScreenAwake)
            } header: {
                Text("Scoreboard")
            } footer: {
                Text("The screen stays on while a scoreboard is open, then returns to normal.")
            }
            .listRowBackground(theme.panel)

            AdsSection()

            Section {
                Picker("Default Sport", selection: $settings.defaultSport) {
                    ForEach(SportCatalog.all) { sport in
                        Text(SportCatalog.rules(for: sport).name).tag(sport)
                    }
                }
                ForEach(SportCatalog.all.filter { !SportCatalog.isPlayerGame($0) }) { sport in
                    let rules = SportCatalog.rules(for: sport)
                    NavigationLink {
                        SportDefaultsView(initialConfig: settings.gameDefaults(for: sport))
                    } label: {
                        Label(rules.name, systemImage: rules.symbolName)
                    }
                }
            } header: {
                Text("Game Defaults")
            } footer: {
                Text("Quick Start uses the default sport. Team names, clock and period settings you choose here are filled in for every new game. Bucket Golf remembers your last players and number of holes.")
            }
            .listRowBackground(theme.panel)

            Section {
                NavigationLink("About", destination: AboutView())
                NavigationLink("Privacy", destination: PrivacyView())
                LabeledContent("Version", value: AppInfo.versionString)
            }
            .listRowBackground(theme.panel)
        }
        .scrollContentBackground(.hidden)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Remove Ads purchase, restore, and (where the law requires it) ad privacy choices.
private struct AdsSection: View {
    @Environment(\.theme) private var theme

    var body: some View {
        let store = PurchaseStore.shared
        Section {
            if store.adsRemoved {
                Label("Ads removed. Thank you!", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(theme.primaryText)
            } else {
                RemoveAdsButton()
                Button("Restore Purchases") {
                    Task { await store.restore() }
                }
                .disabled(store.status == .working)
            }
            if AdManager.shared.privacyOptionsRequired && !store.adsRemoved {
                Button("Ad Privacy Choices") {
                    AdManager.shared.presentPrivacyOptions()
                }
            }
        } header: {
            Text("Ads")
        } footer: {
            Text(store.adsRemoved
                 ? "Your purchase works on every device signed in to the same Apple Account."
                 : "A one-time purchase removes every ad for good, on all your devices. Ads never appear on the scoreboard during a game.")
        }
        .listRowBackground(theme.panel)
    }
}

/// One theme: a swatch preview, its name, and either a checkmark, or (for a locked bonus
/// theme) an explicit "Watch video" button. Videos only ever play when that button is tapped.
private struct ThemeRow: View {
    let appearance: AppAppearance
    @Environment(AppSettings.self) private var settings
    @Environment(\.theme) private var theme
    @State private var showsUnavailable = false

    var body: some View {
        Group {
            if settings.canUse(appearance) {
                let isSelected = settings.appearance == appearance
                Button(action: select) {
                    HStack(spacing: 14) {
                        swatch(isSelected: isSelected)
                        titles
                        Spacer(minLength: 8)
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(isSelected ? theme.clock : theme.tertiaryText)
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(appearance.displayName). \(appearance.detail)")
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            } else {
                HStack(spacing: 14) {
                    swatch(isSelected: false)
                    titles
                    Spacer(minLength: 8)
                    Button(action: unlock) {
                        Label("Watch Video", systemImage: "play.rectangle.fill")
                            .font(.caption.weight(.semibold))
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)
                    .tint(theme.clock)
                    .accessibilityLabel("Unlock \(appearance.displayName) by watching a short video")
                }
            }
        }
        .alert("Video Not Available", isPresented: $showsUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("There isn't a video ready right now. Check your connection and try again in a moment.")
        }
    }

    private func swatch(isSelected: Bool) -> some View {
        let preview = Theme.make(appearance)
        return ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(preview.background)
            Circle()
                .fill(preview.clock)
                .frame(width: 12, height: 12)
        }
        .frame(width: 38, height: 30)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isSelected ? theme.clock : theme.controlStroke, lineWidth: isSelected ? 2 : 1)
        )
        .accessibilityHidden(true)
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(appearance.displayName)
                .foregroundStyle(theme.primaryText)
            Text(appearance.detail)
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
        }
    }

    private func select() {
        settings.appearance = appearance
        Feedback.shared.play(.tap)
    }

    private func unlock() {
        // Captured now: the reward arrives after the video, outside of any view update.
        let store = settings
        let earned = appearance
        let started = AdManager.shared.presentRewarded {
            store.unlock(earned)
            store.appearance = earned
            // Have the next video ready only if there's another theme to unlock.
            if store.hasLockedAppearances { AdManager.shared.prepareRewarded() }
        }
        if !started { showsUnavailable = true }
    }
}

private struct BuzzerRow: View {
    let style: BuzzerStyle
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? theme.clock : theme.tertiaryText)
                VStack(alignment: .leading, spacing: 2) {
                    Text(style.displayName)
                        .foregroundStyle(theme.primaryText)
                    Text(style.detail)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
                Spacer()
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(theme.secondaryText)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style.displayName)
        .accessibilityHint("Selects and plays this buzzer")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Edit the setup that new games of one sport start with.
struct SportDefaultsView: View {
    @State private var config: GameConfig
    @Environment(AppSettings.self) private var settings
    @Environment(\.theme) private var theme

    init(initialConfig: GameConfig) {
        _config = State(initialValue: initialConfig)
    }

    var body: some View {
        Form {
            Section {
                TeamEditorRow(team: $config.teamA, placeholder: "Home")
                TeamEditorRow(team: $config.teamB, placeholder: "Away")
            } header: {
                Text("Teams")
            }
            .listRowBackground(theme.panel)

            GameRulesSection(config: $config)

            Section {
                Button("Restore Factory Defaults", role: .destructive) {
                    config = SportCatalog.defaultConfig(for: config.sport)
                    Feedback.shared.play(.reset)
                }
            }
            .listRowBackground(theme.panel)
        }
        .scrollContentBackground(.hidden)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(SportCatalog.rules(for: config).name)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: config) { _, newValue in
            settings.saveGameDefaults(newValue)
        }
    }
}

enum AppInfo {
    static var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}
