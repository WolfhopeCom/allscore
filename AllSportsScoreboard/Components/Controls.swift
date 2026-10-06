import SwiftUI

/// Gentle press-down feedback for custom buttons.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// The square-ish scoring buttons under each score.
struct ScoreButtonStyle: ButtonStyle {
    let tint: Color
    var prominent = true
    @Environment(\.theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        configuration.label
            .foregroundStyle(prominent ? tint : theme.secondaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(shape.fill(configuration.isPressed ? tint.opacity(0.22) : theme.control))
            .overlay(shape.strokeBorder(prominent ? tint.opacity(0.4) : theme.controlStroke, lineWidth: 1))
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Icon button in the bottom control bar.
struct BarIconButton: View {
    let symbol: String
    let label: String
    var isEnabled = true
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(theme.primaryText)
                .frame(width: 54, height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(theme.control)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(theme.controlStroke)
                )
        }
        .buttonStyle(PressableStyle(scale: 0.92))
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .accessibilityLabel(label)
    }
}

/// The big context-sensitive Start / Pause / Next Period button.
struct PrimaryActionButton: View {
    let action: PrimaryAction
    var compact = false
    let perform: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: perform) {
            HStack(spacing: 10) {
                Image(systemName: action.symbolName)
                    .font(.system(size: compact ? 16 : 18, weight: .bold))
                Text(action.title.uppercased())
                    .font(.boardLabel(compact ? 15 : 17))
                    .tracking(1.2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(action.isProminent ? theme.onClock : theme.clock)
            .padding(.horizontal, 20)
            .frame(maxWidth: compact ? 260 : 340)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(action.isProminent ? theme.clock : theme.control)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(action.isProminent ? Color.clear : theme.clock.opacity(0.55), lineWidth: 1.5)
            )
            .shadow(color: theme.clock.opacity(action.isProminent ? 0.35 * theme.glow : 0), radius: 14)
        }
        .buttonStyle(PressableStyle(scale: 0.96))
        .animation(.snappy(duration: 0.2), value: action)
        .accessibilityLabel(action.title)
    }
}

/// "● LIVE" style status indicator. Text always carries the meaning; the dot is extra.
struct StatusPill: View {
    let text: String
    let tone: StatusTone
    @Environment(\.theme) private var theme
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .opacity(tone == .live && pulsing ? 0.3 : 1)
            Text(text.uppercased())
                .font(.boardLabel(13))
                .tracking(1.4)
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(Capsule().fill(theme.control))
        .overlay(Capsule().strokeBorder(theme.controlStroke))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Game status: \(text)")
    }

    private var dotColor: Color {
        switch tone {
        case .idle: return theme.tertiaryText
        case .live: return theme.live
        case .paused: return theme.clock
        case .intermission: return theme.secondaryText
        case .final: return theme.alert
        }
    }
}

/// A row of team color swatches. The selected one also gets a ring and a checkmark.
struct ColorSwatchRow: View {
    @Binding var selection: TeamColor
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TeamColor.allCases) { color in
                Button {
                    selection = color
                    Feedback.shared.play(.tap)
                } label: {
                    ZStack {
                        if selection == color {
                            Circle()
                                .strokeBorder(theme.primaryText, lineWidth: 2)
                                .frame(width: 36, height: 36)
                        }
                        Circle()
                            .fill(theme.color(color))
                            .frame(width: 26, height: 26)
                        if selection == color {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(Color.black.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color.displayName)
                .accessibilityAddTraits(selection == color ? .isSelected : [])
            }
        }
    }
}

/// Team name field plus color swatches, used in setup and in the edit-teams sheet.
struct TeamEditorRow: View {
    @Binding var team: TeamConfig
    let placeholder: String
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.color(team.color))
                    .frame(width: 4, height: 24)
                TextField(placeholder, text: $team.name)
                    .font(.system(size: 19, weight: .semibold))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onChange(of: team.name) { _, newValue in
                        if newValue.count > 24 { team.name = String(newValue.prefix(24)) }
                    }
            }
            ColorSwatchRow(selection: $team.color)
        }
        .padding(.vertical, 4)
    }
}
