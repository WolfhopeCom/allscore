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
            } header: {
                Text("Sound")
            } footer: {
                Text("When Play in Silent Mode is on, sounds play even with your ringer switched off, which is what you want courtside.")
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
                Toggle("Haptic Feedback", isOn: $settings.hapticsEnabled)
            } header: {
                Text("Haptics")
            }
            .listRowBackground(theme.panel)

            Section {
                Toggle("Keep Screen Awake", isOn: $settings.keepScreenAwake)
                Picker("Appearance", selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.displayName).tag(appearance)
                    }
                }
            } header: {
                Text("Scoreboard")
            } footer: {
                Text(settings.appearance.detail + ". The screen stays on while a scoreboard is open, then returns to normal.")
            }
            .listRowBackground(theme.panel)

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
