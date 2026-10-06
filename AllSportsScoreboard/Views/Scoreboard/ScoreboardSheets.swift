import SwiftUI

/// Rename teams and change their colors mid-game.
struct TeamsEditSheet: View {
    let session: GameSession

    @State private var teamA: TeamConfig
    @State private var teamB: TeamConfig
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    init(session: GameSession) {
        self.session = session
        _teamA = State(initialValue: session.config.teamA)
        _teamB = State(initialValue: session.config.teamB)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TeamEditorRow(team: $teamA, placeholder: "Home")
                    TeamEditorRow(team: $teamB, placeholder: "Away")
                }
                .listRowBackground(theme.panel)
            }
            .scrollContentBackground(.hidden)
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Teams")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        session.updateTeams(teamA, teamB)
                        Feedback.shared.play(.tap)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Fix the clock to match the real game, and correct the period.
struct ClockAdjustSheet: View {
    let session: GameSession

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    private struct ClockStep: Identifiable {
        let delta: TimeInterval
        let label: String
        var id: TimeInterval { delta }
    }

    private static let adjustments = [
        ClockStep(delta: -60, label: "−1:00"), ClockStep(delta: -10, label: "−0:10"), ClockStep(delta: -1, label: "−0:01"),
        ClockStep(delta: 1, label: "+0:01"), ClockStep(delta: 10, label: "+0:10"), ClockStep(delta: 60, label: "+1:00")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    if session.clockEnabled {
                        SheetClock(session: session)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                            ForEach(Self.adjustments) { step in
                                Button {
                                    session.adjustClock(by: step.delta)
                                } label: {
                                    Text(step.label)
                                        .font(.clockFace(18))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                }
                                .buttonStyle(ScoreButtonStyle(tint: theme.clock, prominent: step.delta > 0))
                                .accessibilityLabel(accessibilityLabel(for: step.delta))
                            }
                        }

                        HStack(spacing: 10) {
                            Button {
                                if session.isClockRunning {
                                    session.pauseClock()
                                } else {
                                    session.startClock()
                                }
                            } label: {
                                Label(session.isClockRunning ? "Pause" : "Start", systemImage: session.isClockRunning ? "pause.fill" : "play.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 46)
                            }
                            .buttonStyle(ScoreButtonStyle(tint: theme.clock))
                            .disabled(!session.isClockRunning && !session.canStartClock)

                            Button {
                                session.resetClock()
                            } label: {
                                Label("Reset Clock", systemImage: "arrow.counterclockwise")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 46)
                            }
                            .buttonStyle(ScoreButtonStyle(tint: theme.clock, prominent: false))
                            .disabled(session.phase == .final)
                        }
                    }

                    if (session.showsPeriod || session.regulationPeriods > 1) && !session.model.undoRestoresFlow && !(session.model == .combat && session.state.match.resting) {
                        periodStepper
                    }
                }
                .padding(20)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle(session.clockEnabled ? "Clock & Period" : "Period")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var periodStepper: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("PERIOD")
                    .font(.boardLabel(11))
                    .tracking(2)
                    .foregroundStyle(theme.secondaryText)
                Text(session.periodTitle)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
            }
            Spacer()
            Stepper(
                "Period",
                value: Binding(
                    get: { session.period },
                    set: { session.setPeriod($0, resetClock: false) }
                ),
                in: 1...(session.regulationPeriods + 9)
            )
            .labelsHidden()
            .disabled(session.phase == .final)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.panel))
    }

    private func accessibilityLabel(for delta: TimeInterval) -> String {
        let amount = Int(abs(delta))
        let unit = amount >= 60 ? "\(amount / 60) minute" : "\(amount) second\(amount == 1 ? "" : "s")"
        return delta > 0 ? "Add \(unit)" : "Subtract \(unit)"
    }
}

private struct SheetClock: View {
    let session: GameSession
    @Environment(\.theme) private var theme

    var body: some View {
        let reading = session.clockReading(at: session.now)
        VStack(spacing: 4) {
            Text(reading.text)
                .font(.clockFace(64))
                .foregroundStyle(reading.isWarning ? theme.alert : theme.clock)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if let stoppage = reading.stoppage {
                Text(stoppage)
                    .font(.clockFace(20))
                    .foregroundStyle(theme.alert)
            }
            Text(session.isClockRunning ? "RUNNING" : "STOPPED")
                .font(.boardLabel(11))
                .tracking(2)
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(theme.panel))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Game clock")
        .accessibilityValue(reading.spoken)
    }
}
