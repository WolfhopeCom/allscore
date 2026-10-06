import Foundation

/// Renders every app sound from scratch as mono PCM samples. All audio is original and
/// generated on-device, so there are no recordings and no licensing to worry about.
enum SoundSynth {
    static let sampleRate: Double = 44_100

    enum Wave {
        case sine, triangle, square, saw
    }

    struct Partial {
        let frequency: Double
        let wave: Wave
        let amplitude: Double
    }

    // MARK: - Catalog

    static func render(_ effect: SoundEffect) -> [Float] {
        switch effect {
        case .tap:
            return normalize(
                tone(1_400, 0.045, .sine, attack: 0.001, release: 0.035, decay: 0.018),
                peak: 0.32
            )

        case .score:
            let first = tone(1_046.5, 0.12, .triangle, attack: 0.002, release: 0.04, decay: 0.06)
            let second = tone(1_568.0, 0.24, .triangle, attack: 0.002, release: 0.08, decay: 0.09)
            return normalize(mix([(first, 0), (second, 0.065)]), peak: 0.55)

        case .bigScore:
            let notes: [Double] = [784, 1_046.5, 1_318.5, 1_568]
            var parts: [([Float], Double)] = []
            for (index, frequency) in notes.enumerated() {
                let body = tone(frequency, 0.34, .triangle, attack: 0.002, release: 0.08, decay: 0.13)
                let shimmer = tone(frequency * 2, 0.2, .sine, attack: 0.002, release: 0.06, decay: 0.06, amplitude: 0.25)
                parts.append((body, Double(index) * 0.055))
                parts.append((shimmer, Double(index) * 0.055))
            }
            return normalize(mix(parts), peak: 0.62)

        case .scoreRemoved:
            return normalize(
                tone(700, 0.15, .sine, to: 420, attack: 0.002, release: 0.05, decay: 0.08),
                peak: 0.36
            )

        case .denied:
            let thud = tone(170, 0.09, .sine, attack: 0.001, release: 0.04, decay: 0.035)
            let edge = tone(340, 0.05, .triangle, attack: 0.001, release: 0.03, decay: 0.02, amplitude: 0.4)
            return normalize(mix([(thud, 0), (edge, 0)]), peak: 0.42)

        case .timerStart:
            let rise = tone(520, 0.11, .triangle, to: 1_040, attack: 0.003, release: 0.02)
            let ping = tone(1_040, 0.12, .sine, attack: 0.002, release: 0.05, decay: 0.05)
            return normalize(mix([(rise, 0), (ping, 0.1)]), peak: 0.5)

        case .timerPause:
            let fall = tone(1_040, 0.11, .triangle, to: 520, attack: 0.003, release: 0.02)
            let thump = tone(520, 0.1, .sine, attack: 0.002, release: 0.05, decay: 0.04)
            return normalize(mix([(fall, 0), (thump, 0.1)]), peak: 0.46)

        case .warning:
            let beep = lowpass(tone(1_760, 0.075, .square, attack: 0.002, release: 0.012), cutoff: 4_500)
            return normalize(mix([(beep, 0), (beep, 0.13)]), peak: 0.5)

        case .periodChange:
            let low = tone(660, 0.13, .triangle, attack: 0.002, release: 0.05, decay: 0.08)
            let high = tone(990, 0.28, .triangle, attack: 0.002, release: 0.1, decay: 0.12)
            return normalize(mix([(low, 0), (high, 0.09)]), peak: 0.5)

        case .reset:
            let notes: [Double] = [784, 587.3, 392]
            let parts = notes.enumerated().map { index, frequency in
                (tone(frequency, 0.18, .triangle, attack: 0.002, release: 0.06, decay: 0.07), Double(index) * 0.09)
            }
            return normalize(mix(parts), peak: 0.5)

        case .buzzer(let style, let length):
            return buzzer(style, length)

        case .gameEnd(let style):
            let horn = buzzer(style, .long)
            let hornDuration = Double(horn.count) / sampleRate
            let chord: [Double] = [523.25, 659.25, 783.99]
            var parts: [([Float], Double)] = [(horn, 0)]
            for (index, frequency) in chord.enumerated() {
                let note = tone(frequency, 0.7, .triangle, attack: 0.004, release: 0.25, decay: 0.3, amplitude: 0.16)
                parts.append((note, hornDuration + 0.12 + Double(index) * 0.06))
            }
            return normalize(mix(parts), peak: 0.95)
        }
    }

    // MARK: - Buzzers

    static func buzzer(_ style: BuzzerStyle, _ length: BuzzerLength) -> [Float] {
        let long = length == .long
        switch style {
        case .arena:
            return normalize(buzz(arenaPartials, duration: long ? 1.6 : 0.85, drive: 2.6, cutoff: 3_800), peak: 0.95)

        case .classic:
            let partials = [
                Partial(frequency: 125, wave: .square, amplitude: 0.6),
                Partial(frequency: 250.6, wave: .square, amplitude: 0.25),
                Partial(frequency: 375.9, wave: .saw, amplitude: 0.12)
            ]
            return normalize(
                buzz(partials, duration: long ? 1.4 : 0.8, drive: 1.8, cutoff: 2_600, tremoloRate: 50, tremoloDepth: 0.12),
                peak: 0.92
            )

        case .horn:
            let partials = [
                Partial(frequency: 349.2, wave: .saw, amplitude: 0.4),
                Partial(frequency: 440.0, wave: .saw, amplitude: 0.4),
                Partial(frequency: 523.3, wave: .saw, amplitude: 0.3),
                Partial(frequency: 174.6, wave: .square, amplitude: 0.15)
            ]
            return normalize(
                buzz(partials, duration: long ? 1.3 : 0.7, drive: 1.4, cutoff: 3_000, attack: 0.03, release: 0.12),
                peak: 0.92
            )

        case .shortHorn:
            return normalize(buzz(arenaPartials, duration: long ? 0.55 : 0.35, drive: 2.6, cutoff: 3_800, release: 0.06), peak: 0.95)

        case .whistle:
            return normalize(whistle(duration: long ? 1.0 : 0.55), peak: 0.85)
        }
    }

    private static let arenaPartials = [
        Partial(frequency: 196.0, wave: .saw, amplitude: 0.5),
        Partial(frequency: 198.3, wave: .saw, amplitude: 0.45),
        Partial(frequency: 392.4, wave: .square, amplitude: 0.18),
        Partial(frequency: 98.1, wave: .square, amplitude: 0.22)
    ]

    /// Summed, saturated and filtered oscillators: the body of every buzzer and horn.
    private static func buzz(
        _ partials: [Partial],
        duration: Double,
        drive: Double,
        cutoff: Double,
        tremoloRate: Double = 0,
        tremoloDepth: Double = 0,
        attack: Double = 0.012,
        release: Double = 0.09
    ) -> [Float] {
        let count = Int(duration * sampleRate)
        var output = [Float](repeating: 0, count: count)
        var phases = [Double](repeating: 0, count: partials.count)
        for index in 0..<count {
            let time = Double(index) / sampleRate
            var value = 0.0
            for (k, partial) in partials.enumerated() {
                phases[k] += partial.frequency / sampleRate
                phases[k] -= floor(phases[k])
                value += oscillator(partial.wave, phases[k]) * partial.amplitude
            }
            value = tanh(value * drive)
            if tremoloDepth > 0 {
                value *= 1 - tremoloDepth * (0.5 + 0.5 * sin(2 * .pi * tremoloRate * time))
            }
            value *= envelope(time, duration: duration, attack: attack, release: release)
            output[index] = Float(value)
        }
        return lowpass(lowpass(output, cutoff: cutoff), cutoff: cutoff * 1.4)
    }

    /// A pea whistle: a high tone with a fast trill and a little breath noise.
    private static func whistle(duration: Double) -> [Float] {
        let count = Int(duration * sampleRate)
        var output = [Float](repeating: 0, count: count)
        var phase = 0.0
        var generator = SeededGenerator(seed: 0x5EED)
        for index in 0..<count {
            let time = Double(index) / sampleRate
            let trill = sin(2 * .pi * 26 * time)
            let frequency = 2_900 + 140 * trill
            phase += frequency / sampleRate
            phase -= floor(phase)
            var value = sin(2 * .pi * phase) * (0.78 + 0.22 * trill)
            value += Double.random(in: -1...1, using: &generator) * 0.05
            value *= envelope(time, duration: duration, attack: 0.015, release: 0.06)
            output[index] = Float(value)
        }
        return output
    }

    // MARK: - Building blocks

    static func tone(
        _ frequency: Double,
        _ duration: Double,
        _ wave: Wave,
        to endFrequency: Double? = nil,
        attack: Double = 0.005,
        release: Double = 0.03,
        decay: Double? = nil,
        amplitude: Double = 1
    ) -> [Float] {
        let count = Int(duration * sampleRate)
        var output = [Float](repeating: 0, count: count)
        var phase = 0.0
        for index in 0..<count {
            let time = Double(index) / sampleRate
            var current = frequency
            if let endFrequency {
                current = frequency * pow(endFrequency / frequency, time / duration)
            }
            phase += current / sampleRate
            phase -= floor(phase)
            var value = oscillator(wave, phase) * amplitude
            value *= envelope(time, duration: duration, attack: attack, release: release)
            if let decay { value *= exp(-time / decay) }
            output[index] = Float(value)
        }
        return output
    }

    private static func oscillator(_ wave: Wave, _ phase: Double) -> Double {
        switch wave {
        case .sine: return sin(2 * .pi * phase)
        case .triangle: return 1 - 4 * abs(phase - 0.5)
        case .square: return phase < 0.5 ? 1 : -1
        case .saw: return 2 * phase - 1
        }
    }

    private static func envelope(_ time: Double, duration: Double, attack: Double, release: Double) -> Double {
        if attack > 0, time < attack { return time / attack }
        if release > 0, time > duration - release { return max(0, (duration - time) / release) }
        return 1
    }

    static func mix(_ parts: [([Float], Double)]) -> [Float] {
        let length = parts.map { Int($0.1 * sampleRate) + $0.0.count }.max() ?? 0
        var output = [Float](repeating: 0, count: length)
        for (samples, offset) in parts {
            let start = Int(offset * sampleRate)
            for (index, sample) in samples.enumerated() {
                output[start + index] += sample
            }
        }
        return output
    }

    static func lowpass(_ input: [Float], cutoff: Double) -> [Float] {
        let rc = 1 / (2 * .pi * cutoff)
        let dt = 1 / sampleRate
        let alpha = Float(dt / (rc + dt))
        var output = [Float](repeating: 0, count: input.count)
        var previous: Float = 0
        for index in input.indices {
            previous += alpha * (input[index] - previous)
            output[index] = previous
        }
        return output
    }

    static func normalize(_ input: [Float], peak: Float) -> [Float] {
        let maximum = input.reduce(Float(0)) { max($0, abs($1)) }
        guard maximum > 0 else { return input }
        let gain = peak / maximum
        return input.map { $0 * gain }
    }
}

/// Deterministic noise so every launch renders identical sounds.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
