import SwiftUI

/// Pick team names and colors, check the clock settings, start.
struct GameSetupView: View {
    let onStart: (GameConfig) -> Void

    @State private var config: GameConfig
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    init(initialConfig: GameConfig, onStart: @escaping (GameConfig) -> Void) {
        _config = State(initialValue: initialConfig)
        self.onStart = onStart
    }

    var body: some View {
        let rules = SportCatalog.rules(for: config)
        NavigationStack {
            Form {
                Section {
                    TeamEditorRow(team: $config.teamA, placeholder: "Home")
                    TeamEditorRow(team: $config.teamB, placeholder: "Away")
                } header: {
                    Text("Teams")
                }
                .listRowBackground(theme.panel)

                GameRulesSection(config: $config)
            }
            .scrollContentBackground(.hidden)
            .background(theme.background.ignoresSafeArea())
            .navigationTitle(rules.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onStart(config)
                } label: {
                    Label("Start Game", systemImage: "play.fill")
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
}

/// Clock, period, match and custom-scoring settings. Shared by game setup and
/// Settings › Game Defaults.
struct GameRulesSection: View {
    @Binding var config: GameConfig
    @Environment(\.theme) private var theme

    var body: some View {
        let rules = SportCatalog.rules(for: config)

        switch rules.model {
        case .points:
            pointsSections(rules: rules)

        case .rally:
            Section {
                bestOfPicker(rules: rules)
                Stepper(value: $config.pointsToWin, in: 5...50) {
                    LabeledContent("Points to win a \(rules.periodName.lowercased())", value: "\(config.pointsToWin)")
                }
                if config.sport == .pickleball {
                    Picker("Format", selection: $config.doubles) {
                        Text("Doubles").tag(true)
                        Text("Singles").tag(false)
                    }
                    .pickerStyle(.segmented)
                    Toggle("Rally Scoring", isOn: $config.rallyScoring)
                }
            } header: {
                Text("Match")
            } footer: {
                Text(rallyFooter(rules: rules))
            }
            .listRowBackground(theme.panel)

        case .tennis:
            Section {
                bestOfPicker(rules: rules)
            } header: {
                Text("Match")
            } footer: {
                Text("Advantage scoring. Sets go to 6, win by 2, with a tiebreak at 6–6.")
            }
            .listRowBackground(theme.panel)

        case .baseball:
            Section {
                Picker("Innings", selection: $config.periodCount) {
                    ForEach(rules.periodCountOptions, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
            } header: {
                Text("Game")
            } footer: {
                Text("The visiting team bats first. Tied games go to extra innings.")
            }
            .listRowBackground(theme.panel)

        case .combat:
            Section {
                Stepper(value: $config.periodCount, in: 1...12) {
                    LabeledContent("Rounds", value: "\(config.periodCount)")
                }
                Stepper(value: halfMinutes(\.periodLength), in: 1...20) {
                    LabeledContent("Round length", value: TimeFormat.clock(config.periodLength, roundingUp: false, showTenths: false))
                }
                Stepper(value: $config.restLength, in: 0...180, step: 15) {
                    LabeledContent("Rest between rounds", value: config.restLength == 0 ? "Off" : TimeFormat.clock(config.restLength, roundingUp: false, showTenths: false))
                }
            } header: {
                Text("Rounds")
            } footer: {
                Text("Boxing is often 3:00 rounds with 1:00 rest; MMA uses 5:00 rounds. Score each round 10-9 or 10-8, or end the fight by KO/TKO from the period menu.")
            }
            .listRowBackground(theme.panel)
        }
    }

    @ViewBuilder
    private func pointsSections(rules: any SportRules) -> some View {
        if config.sport == .custom {
            Section {
                LabeledContent("Title") {
                    TextField("Custom", text: $config.customTitle)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.words)
                }
                Stepper(value: $config.customIncrement, in: 1...100) {
                    LabeledContent("Points per tap", value: "\(config.customIncrement)")
                }
                LabeledContent("Period name") {
                    TextField("Period", text: $config.customPeriodName)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.words)
                }
            } header: {
                Text("Scoreboard")
            } footer: {
                Text("Name it for your game: cornhole, darts, pickleball, trivia night…")
            }
            .listRowBackground(theme.panel)
        }

        Section {
            if config.sport == .custom {
                Toggle("Game Clock", isOn: $config.clockEnabled)
                if config.clockEnabled {
                    Picker("Direction", selection: $config.customClockDirection) {
                        ForEach(ClockDirection.allCases) { direction in
                            Text(direction.displayName).tag(direction)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            if config.clockEnabled {
                Stepper(value: minutes(\.periodLength), in: 1...90) {
                    LabeledContent("\(rules.periodName) length", value: TimeFormat.shortDuration(config.periodLength))
                }
            }

            periodCountControl(rules: rules)

            if rules.allowsOvertime && config.clockEnabled {
                Stepper(value: minutes(\.overtimeLength), in: 1...30) {
                    LabeledContent("\(rules.overtimeName) length", value: TimeFormat.shortDuration(config.overtimeLength))
                }
            }
        } header: {
            Text(config.clockEnabled ? "Clock" : "Periods")
        }
        .listRowBackground(theme.panel)
    }

    @ViewBuilder
    private func periodCountControl(rules: any SportRules) -> some View {
        let options = rules.periodCountOptions
        if config.sport == .custom {
            Stepper(value: $config.periodCount, in: 1...9) {
                LabeledContent(rules.periodNamePlural, value: "\(config.periodCount)")
            }
        } else if options.count > 1 {
            Picker("Periods", selection: $config.periodCount) {
                ForEach(options, id: \.self) { count in
                    Text(SportCatalog.rules(for: configWith(periodCount: count)).periodNamePlural + " · \(count)")
                        .tag(count)
                }
            }
        } else {
            LabeledContent(rules.periodNamePlural, value: "\(config.periodCount)")
        }
    }

    private func bestOfPicker(rules: any SportRules) -> some View {
        Picker("Match length", selection: $config.periodCount) {
            ForEach(rules.periodCountOptions, id: \.self) { count in
                Text(count == 1 ? "1 \(rules.periodName)" : "Best of \(count)").tag(count)
            }
        }
    }

    private func rallyFooter(rules: any SportRules) -> String {
        switch config.sport {
        case .volleyball: return "Rally scoring, win by 2. The deciding set goes to 15."
        case .badminton: return "Rally scoring, win by 2, capped at \(config.pointsToWin + 9)."
        case .pickleball:
            if config.rallyScoring { return "Every rally scores, win by 2." }
            return config.doubles
                ? "Only the serving team scores. Tap the team that wins each rally; the app tracks side-outs, server 1 and 2, and calls the score (games start at 0-0-2)."
                : "Only the server scores. Tap the player who wins each rally; the app tracks side-outs and calls the score."
        default: return "Win by 2. Serve changes every two points, then every point at deuce."
        }
    }

    private func configWith(periodCount: Int) -> GameConfig {
        var copy = config
        copy.periodCount = periodCount
        return copy
    }

    private func minutes(_ keyPath: WritableKeyPath<GameConfig, TimeInterval>) -> Binding<Int> {
        Binding(
            get: { max(1, Int((config[keyPath: keyPath] / 60).rounded())) },
            set: { config[keyPath: keyPath] = TimeInterval($0 * 60) }
        )
    }

    /// Steps in 30-second increments (rounds of 2:30, 3:00, 5:00…).
    private func halfMinutes(_ keyPath: WritableKeyPath<GameConfig, TimeInterval>) -> Binding<Int> {
        Binding(
            get: { max(1, Int((config[keyPath: keyPath] / 30).rounded())) },
            set: { config[keyPath: keyPath] = TimeInterval($0 * 30) }
        )
    }
}
