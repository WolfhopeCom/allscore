import AVFoundation

/// Low-latency playback of synthesized sounds through AVAudioEngine.
///
/// Short effects rotate through a small pool of player nodes so rapid taps overlap
/// naturally; buzzers get a dedicated node so a tap never cuts off the horn.
@MainActor
final class SoundEngine {
    static let shared = SoundEngine()

    private let engine = AVAudioEngine()
    private let format: AVAudioFormat
    private var effectPlayers: [AVAudioPlayerNode] = []
    private let buzzerPlayer = AVAudioPlayerNode()
    private var nextPlayer = 0
    private var cache: [SoundEffect: AVAudioPCMBuffer] = [:]
    private var isSessionConfigured = false
    private var ignoresSilentSwitch = true

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: SoundSynth.sampleRate, channels: 1)!

        for _ in 0..<5 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            effectPlayers.append(player)
        }
        engine.attach(buzzerPlayer)
        engine.connect(buzzerPlayer, to: engine.mainMixerNode, format: format)
        engine.prepare()

        let center = NotificationCenter.default
        center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.restartIfNeeded() }
        }
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let rawType = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let ended = rawType == AVAudioSession.InterruptionType.ended.rawValue
            Task { @MainActor in
                if ended { self?.restartIfNeeded() }
            }
        }
    }

    /// `.playback` keeps the buzzer audible with the ringer switch on silent, which is what
    /// you want courtside. Both modes mix with music instead of stopping it.
    func configureSession(ignoresSilentSwitch: Bool) {
        guard !isSessionConfigured || ignoresSilentSwitch != self.ignoresSilentSwitch else { return }
        self.ignoresSilentSwitch = ignoresSilentSwitch
        isSessionConfigured = true
        let session = AVAudioSession.sharedInstance()
        if ignoresSilentSwitch {
            try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        } else {
            try? session.setCategory(.ambient, mode: .default, options: [])
        }
        try? session.setActive(true)
    }

    func setVolume(_ volume: Double) {
        engine.mainMixerNode.outputVolume = Float(min(1, max(0, volume)))
    }

    func play(_ effect: SoundEffect) {
        if !isSessionConfigured { configureSession(ignoresSilentSwitch: ignoresSilentSwitch) }
        guard startIfNeeded(), let buffer = buffer(for: effect) else { return }

        let player: AVAudioPlayerNode
        if effect.isBuzzer {
            player = buzzerPlayer
        } else {
            player = effectPlayers[nextPlayer]
            nextPlayer = (nextPlayer + 1) % effectPlayers.count
        }
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        player.play()
    }

    /// Renders sounds ahead of time so the first tap has no synthesis delay.
    func prewarm(_ effects: [SoundEffect]) {
        for effect in effects {
            _ = buffer(for: effect)
        }
    }

    private func startIfNeeded() -> Bool {
        if engine.isRunning { return true }
        try? AVAudioSession.sharedInstance().setActive(true)
        do {
            try engine.start()
            return true
        } catch {
            return false
        }
    }

    /// After a phone call, Siri or a route change the session must be re-activated before
    /// the engine will start again.
    private func restartIfNeeded() {
        if isSessionConfigured { try? AVAudioSession.sharedInstance().setActive(true) }
        if !engine.isRunning { try? engine.start() }
    }

    private func buffer(for effect: SoundEffect) -> AVAudioPCMBuffer? {
        if let cached = cache[effect] { return cached }
        let samples = SoundSynth.render(effect)
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            if let base = source.baseAddress {
                channel.update(from: base, count: samples.count)
            }
        }
        cache[effect] = buffer
        return buffer
    }
}
