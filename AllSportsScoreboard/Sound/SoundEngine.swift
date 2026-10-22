import AVFoundation

/// Low-latency playback of synthesized sounds through AVAudioEngine.
///
/// Short effects rotate through a small pool of player nodes so rapid taps overlap
/// naturally; buzzers get a dedicated node so a tap never cuts off the horn.
@MainActor
final class SoundEngine {
    static let shared = SoundEngine()

    private var engine = AVAudioEngine()
    private let format: AVAudioFormat
    private var effectPlayers: [AVAudioPlayerNode] = []
    private var buzzerPlayer = AVAudioPlayerNode()
    /// Sounds being rendered in the background right now.
    private var rendering: Set<SoundEffect> = []
    private var nextPlayer = 0
    private var cache: [SoundEffect: AVAudioPCMBuffer] = [:]
    private var isSessionConfigured = false
    private var ignoresSilentSwitch = true

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: SoundSynth.sampleRate, channels: 1)!
        buildGraph()

        let center = NotificationCenter.default
        center.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.restartIfNeeded() }
        }
        // Rare, but after a media-services reset the old engine is dead: build a new one.
        center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.rebuildAfterReset() }
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

    /// A fresh engine with the effect pool and the buzzer player attached.
    private func buildGraph() {
        let volume = engine.mainMixerNode.outputVolume
        engine = AVAudioEngine()
        effectPlayers = (0..<5).map { _ in AVAudioPlayerNode() }
        buzzerPlayer = AVAudioPlayerNode()
        for player in effectPlayers + [buzzerPlayer] {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
        engine.mainMixerNode.outputVolume = volume
        engine.prepare()
    }

    private func rebuildAfterReset() {
        isSessionConfigured = false
        buildGraph()
        configureSession(ignoresSilentSwitch: ignoresSilentSwitch)
        _ = startIfNeeded()
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

    /// Gets everything ready before the first tap: the audio session and engine start now
    /// (that can take a moment), and the sounds are rendered in the background.
    func prewarm(_ effects: [SoundEffect]) {
        if !isSessionConfigured { configureSession(ignoresSilentSwitch: ignoresSilentSwitch) }
        _ = startIfNeeded()
        let missing = effects.filter { cache[$0] == nil && !rendering.contains($0) }
        guard !missing.isEmpty else { return }
        rendering.formUnion(missing)
        Task.detached(priority: .userInitiated) { [weak self] in
            let rendered = missing.map { ($0, SoundSynth.render($0)) }
            await self?.store(rendered)
        }
    }

    private func store(_ rendered: [(SoundEffect, [Float])]) {
        for (effect, samples) in rendered where cache[effect] == nil {
            if let buffer = makeBuffer(samples) { cache[effect] = buffer }
        }
        rendering.subtract(rendered.map(\.0))
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
        guard let buffer = makeBuffer(SoundSynth.render(effect)) else { return nil }
        cache[effect] = buffer
        return buffer
    }

    private func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
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
        return buffer
    }
}
