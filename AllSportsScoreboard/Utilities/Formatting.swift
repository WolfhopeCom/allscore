import Foundation

enum Ordinal {
    static func string(_ number: Int) -> String {
        let lastTwo = number % 100
        let last = number % 10
        let suffix: String
        if (11...13).contains(lastTwo) {
            suffix = "th"
        } else {
            switch last {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(number)\(suffix)"
    }
}

enum TimeFormat {
    /// Guards against values like 9.4 * 10 = 94.000000001 rounding up to 9.5.
    private static let epsilon = 1e-6

    /// Scoreboard clock text such as "12:00", "4:07" or "9.4".
    ///
    /// Countdowns round *up* so "0:00" / "0.0" only appears when time has truly expired;
    /// count-up clocks round down like a stopwatch.
    static func clock(_ seconds: TimeInterval, roundingUp: Bool, showTenths: Bool) -> String {
        let value = max(0, seconds)

        if showTenths {
            let scaled = value * 10
            let tenths = Int(roundingUp ? (scaled - epsilon).rounded(.up) : (scaled + epsilon).rounded(.down))
            let whole = max(0, tenths) / 10
            if whole < 60 {
                return "\(whole).\(max(0, tenths) % 10)"
            }
        }

        let total = max(0, Int(roundingUp ? (value - epsilon).rounded(.up) : (value + epsilon).rounded(.down)))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    /// "12 min", "1 min 30 sec".
    static func shortDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let minutes = total / 60
        let secs = total % 60
        if secs == 0 { return "\(minutes) min" }
        if minutes == 0 { return "\(secs) sec" }
        return "\(minutes) min \(secs) sec"
    }

    /// VoiceOver-friendly: "4 minutes 7 seconds".
    static func spoken(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        let minutes = total / 60
        let secs = total % 60
        var parts: [String] = []
        if minutes > 0 { parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")") }
        if secs > 0 || minutes == 0 { parts.append("\(secs) second\(secs == 1 ? "" : "s")") }
        return parts.joined(separator: " ")
    }
}
