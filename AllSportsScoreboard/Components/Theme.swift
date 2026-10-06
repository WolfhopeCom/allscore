import SwiftUI

/// The app's palette. Dark "Arena" is the primary look; "Daylight" exists because a
/// phone propped up at an outdoor field needs dark text on a light background.
struct Theme {
    let appearance: AppAppearance
    let background: Color
    let panel: Color
    let panelStroke: Color
    let control: Color
    let controlStroke: Color
    let primaryText: Color
    let secondaryText: Color
    let tertiaryText: Color
    /// Scoreboard amber: the clock, and the app's accent color.
    let clock: Color
    /// Text drawn on top of `clock`.
    let onClock: Color
    let alert: Color
    let live: Color
    /// 0…1 strength of glow effects.
    let glow: Double

    var colorScheme: ColorScheme { appearance == .daylight ? .light : .dark }

    func color(_ team: TeamColor) -> Color { team.color(for: appearance) }

    static func make(_ appearance: AppAppearance) -> Theme {
        switch appearance {
        case .arena:
            return Theme(
                appearance: appearance,
                background: Color(hex: 0x07080B),
                panel: Color(hex: 0x101217),
                panelStroke: Color.white.opacity(0.07),
                control: Color(hex: 0x1A1D24),
                controlStroke: Color.white.opacity(0.09),
                primaryText: Color(hex: 0xF5F6F8),
                secondaryText: Color(hex: 0x9AA0AB),
                tertiaryText: Color(hex: 0x5C626D),
                clock: Color(hex: 0xFFB224),
                onClock: Color(hex: 0x120C00),
                alert: Color(hex: 0xFF453A),
                live: Color(hex: 0x34C759),
                glow: 1
            )
        case .blackout:
            return Theme(
                appearance: appearance,
                background: .black,
                panel: Color(hex: 0x070707),
                panelStroke: Color.white.opacity(0.06),
                control: Color(hex: 0x141414),
                controlStroke: Color.white.opacity(0.08),
                primaryText: .white,
                secondaryText: Color(hex: 0x8E8E93),
                tertiaryText: Color(hex: 0x48484A),
                clock: Color(hex: 0xFFB224),
                onClock: Color(hex: 0x120C00),
                alert: Color(hex: 0xFF3B30),
                live: Color(hex: 0x30D158),
                glow: 0.55
            )
        case .daylight:
            return Theme(
                appearance: appearance,
                background: Color(hex: 0xECECE8),
                panel: .white,
                panelStroke: Color.black.opacity(0.08),
                control: Color(hex: 0xE3E3DE),
                controlStroke: Color.black.opacity(0.1),
                primaryText: Color(hex: 0x0B0B0D),
                secondaryText: Color(hex: 0x55595F),
                tertiaryText: Color(hex: 0x8C9097),
                clock: Color(hex: 0xB45A00),
                onClock: .white,
                alert: Color(hex: 0xD70015),
                live: Color(hex: 0x248A3D),
                glow: 0
            )
        }
    }
}

extension TeamColor {
    func color(for appearance: AppAppearance) -> Color {
        let dark = appearance != .daylight
        switch self {
        case .red: return Color(hex: dark ? 0xFF4D4F : 0xD62C2F)
        case .orange: return Color(hex: dark ? 0xFF8A1F : 0xE0670A)
        case .gold: return Color(hex: dark ? 0xFFC93C : 0xB98A00)
        case .green: return Color(hex: dark ? 0x34D37A : 0x1E9E55)
        case .teal: return Color(hex: dark ? 0x2FD3C6 : 0x0E9C92)
        case .blue: return Color(hex: dark ? 0x4A90FF : 0x1F63E0)
        case .purple: return Color(hex: dark ? 0xAC7BFF : 0x7A45E0)
        case .silver: return Color(hex: dark ? 0xD9DCE2 : 0x4A4F59)
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.make(.arena)
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension Font {
    /// Huge tabular digits for scores.
    static func score(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .default).monospacedDigit()
    }

    /// Monospaced clock face, so digits never jitter as they change.
    static func clockFace(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }

    /// Small uppercase scoreboard labels.
    static func boardLabel(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
}
