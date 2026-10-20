import Foundation
import AVFoundation
import Speech
import Observation

/// A spoken conversation with Lithium: it listens, notices when you pause, answers out loud and listens again.
/// Your voice becomes text on the iPhone itself when the iPhone supports it, so the audio never leaves the phone.
/// Speaking and listening are free: only the text answer uses the plan, like a normal message.
@MainActor
@Observable
final class LiveVoiceSession {
    enum Phase: Equatable {
        case starting, listening, thinking, speaking, muted, ended
        case failed(String)
    }

    /// A pause this long after you speak sends what you said.
    static let pause: TimeInterval = 1.2
    /// After this long without hearing anything, the microphone pauses to save battery.
    static let idleLimit: TimeInterval = 90

    private(set) var phase: Phase = .starting
    /// What you are saying, live.
    private(set) var heard = ""
    /// Lithium's latest answer.
    private(set) var reply = ""
    /// How much of the answer has been spoken, in UTF-16 units, to highlight the captions.
    private(set) var spokenUpTo = 0
    /// 0…1, from the microphone while listening and from the words while speaking.
    private(set) var level: Double = 0
    private(set) var startedAt = Date()
    private(set) var turns = 0
    /// True when the transcription happens on the iPhone.
    private(set) var onDevice = false
    private(set) var micMuted = false
    var speed: VoiceSpeed = .normal

    /// Answers what you said. The screen connects it to the store.
    @ObservationIgnored var answer: (@MainActor (String) async -> VoiceAnswer)? = nil
    /// A short pause before demo answers, so they don't feel instant. Zero when the server answers.
    var thinkingDelay = 650

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private let speechEvents = SpeechEvents()
    @ObservationIgnored private let feed = AudioFeed()
    @ObservationIgnored private var recognizer: SFSpeechRecognizer? = nil
    @ObservationIgnored private var voice: AVSpeechSynthesisVoice? = nil
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest? = nil
    @ObservationIgnored private var recognition: SFSpeechRecognitionTask? = nil
    @ObservationIgnored private var silenceTask: Task<Void, Never>? = nil
    @ObservationIgnored private var replyTask: Task<Void, Never>? = nil
    @ObservationIgnored private var lastChange = Date()
    @ObservationIgnored private var lastWordAt = Date.distantPast
    @ObservationIgnored private var endAfterSpeaking = false
    @ObservationIgnored private var failures = 0
    @ObservationIgnored private var attempt = 0
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol? = nil
    /// True once the microphone tap is installed, so shutting down only undoes what was set up.
    @ObservationIgnored private var engineReady = false

    init() {}

    var isActive: Bool {
        switch phase {
        case .ended, .failed: return false
        default: return true
        }
    }

    // MARK: - Start and end

    func begin() async {
        guard phase == .starting else { return }
        guard await Self.microphoneAllowed() else {
            fail("Kuolki necesita el micrófono. Actívalo en Ajustes › Kuolki › Micrófono.")
            return
        }
        guard await Self.speechAllowed() else {
            fail("Para hablar con Lithium, permite el reconocimiento de voz en Ajustes › Kuolki.")
            return
        }
        guard phase == .starting else { return }
        guard let recognizer = Self.makeRecognizer(), recognizer.isAvailable else {
            fail("El reconocimiento de voz en español no está disponible ahora. Revisa tu conexión e intenta de nuevo.")
            return
        }
        self.recognizer = recognizer
        onDevice = recognizer.supportsOnDeviceRecognition
        voice = Self.bestVoice()

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .duckOthers])
            try session.setActive(true)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.channelCount > 0, format.sampleRate > 0 else {
                fail("No encontré un micrófono en este equipo.")
                return
            }
            Self.listen(to: input, format: format, feed: feed) { [weak self] value in
                guard let session = self else { return }
                Task { @MainActor in session.microphone(value) }
            }
            engineReady = true
            engine.prepare()
            try engine.start()
        } catch {
            fail("No se pudo usar el micrófono. Cierra otras apps que lo estén usando e intenta de nuevo.")
            return
        }

        speechEvents.onWord = { [weak self] range in
            guard let session = self else { return }
            Task { @MainActor in session.spoke(range) }
        }
        speechEvents.onFinish = { [weak self] in
            guard let session = self else { return }
            Task { @MainActor in session.finishedSpeaking() }
        }
        synthesizer.delegate = speechEvents
        observeInterruptions()
        LiveControls.endVoice = { [weak self] in self?.end() }
        LiveControls.toggleMute = { [weak self] in self?.toggleMute() }

        startedAt = Date()
        startListening()
        LiveActivityController.shared.start(.voice, chatID: nil, state: activityState)
    }

    func end() {
        guard isActive else { return }
        phase = .ended
        shutDown()
    }

    private func fail(_ message: String) {
        phase = .failed(message)
        shutDown()
    }

    private func shutDown() {
        silenceTask?.cancel()
        replyTask?.cancel()
        stopRecognition()
        synthesizer.stopSpeaking(at: .immediate)
        if engineReady {
            engine.inputNode.removeTap(onBus: 0)
            if engine.isRunning { engine.stop() }
            engineReady = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }
        LiveControls.endVoice = nil
        LiveControls.toggleMute = nil
        level = 0
        if LiveActivityController.shared.kind == .voice {
            LiveActivityController.shared.endNow()
        }
    }

    // MARK: - Controls

    /// Tapping the circle interrupts Lithium, or sends what you said without waiting for the pause.
    func tapOrb() {
        switch phase {
        case .speaking:
            endAfterSpeaking = false
            synthesizer.stopSpeaking(at: .immediate)
            startListening()
        case .listening:
            if !heard.trimmingCharacters(in: .whitespaces).isEmpty { finishTurn() }
        case .muted:
            toggleMute()
        default:
            break
        }
    }

    func toggleMute() {
        guard isActive else { return }
        micMuted.toggle()
        switch phase {
        case .listening where micMuted:
            stopRecognition()
            phase = .muted
            level = 0
        case .muted where !micMuted:
            startListening()
        default:
            break
        }
        updateActivity()
    }

    // MARK: - Listening

    private func startListening() {
        guard isActive, let recognizer else { return }
        stopRecognition()
        heard = ""
        if micMuted {
            phase = .muted
            updateActivity()
            return
        }
        attempt += 1
        let current = attempt
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.addsPunctuation = true
        request.requiresOnDeviceRecognition = onDevice
        self.request = request
        feed.set(request)
        recognition = Self.recognize(with: recognizer, request: request) { [weak self] text, isFinal, failed in
            guard let session = self else { return }
            Task { @MainActor in session.received(text, isFinal: isFinal, failed: failed, attempt: current) }
        }
        phase = .listening
        lastChange = Date()
        updateActivity()
        watchForPause()
    }

    private func stopRecognition() {
        attempt += 1
        silenceTask?.cancel()
        feed.set(nil)
        request?.endAudio()
        recognition?.cancel()
        request = nil
        recognition = nil
    }

    private func received(_ text: String?, isFinal: Bool, failed: Bool, attempt: Int) {
        guard attempt == self.attempt, phase == .listening else { return }
        if let text, !text.isEmpty, text != heard {
            heard = text
            lastChange = Date()
            failures = 0
        }
        guard isFinal || failed else { return }
        if !heard.trimmingCharacters(in: .whitespaces).isEmpty {
            finishTurn()
            return
        }
        guard failed else {
            startListening()
            return
        }
        failures += 1
        if failures == 2 && onDevice {
            // Try the online recognizer if the one on the iPhone keeps failing.
            onDevice = false
        }
        if failures >= 5 {
            fail("No logro escucharte. Revisa el micrófono y tu conexión, y vuelve a intentarlo.")
            return
        }
        replyTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled, self.phase == .listening else { return }
            self.startListening()
        }
    }

    private func watchForPause() {
        silenceTask?.cancel()
        silenceTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, !Task.isCancelled, self.phase == .listening else { return }
                let quiet = Date().timeIntervalSince(self.lastChange)
                if !self.heard.trimmingCharacters(in: .whitespaces).isEmpty, quiet >= Self.pause {
                    self.finishTurn()
                    return
                }
                if quiet >= Self.idleLimit {
                    self.micMuted = true
                    self.stopRecognition()
                    self.phase = .muted
                    self.level = 0
                    self.updateActivity()
                    return
                }
            }
        }
    }

    private func microphone(_ value: Double) {
        guard phase == .listening, abs(value - level) > 0.02 else { return }
        level = value
    }

    // MARK: - Answering

    private func finishTurn() {
        let said = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        stopRecognition()
        guard !said.isEmpty else {
            startListening()
            return
        }
        phase = .thinking
        level = 0
        turns += 1
        updateActivity()
        replyTask = Task { [weak self] in
            guard let delay = self?.thinkingDelay else { return }
            if delay > 0 { try? await Task.sleep(for: .milliseconds(delay)) }
            guard let self, !Task.isCancelled, self.phase == .thinking else { return }
            let result: VoiceAnswer
            if let answer = self.answer {
                result = await answer(said)
            } else {
                result = VoiceAnswer(text: "No pude responder. Intenta de nuevo.")
            }
            guard !Task.isCancelled, self.phase == .thinking else { return }
            self.endAfterSpeaking = result.ends
            self.speak(result.text)
        }
    }

    private func speak(_ text: String) {
        reply = text
        spokenUpTo = 0
        phase = .speaking
        updateActivity()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = speed.rate
        utterance.preUtteranceDelay = 0.05
        synthesizer.speak(utterance)
    }

    private func spoke(_ range: NSRange) {
        guard phase == .speaking else { return }
        spokenUpTo = range.location + range.length
        level = Double.random(in: 0.5...0.95)
        let stamp = Date()
        lastWordAt = stamp
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(170))
            guard let self, self.lastWordAt == stamp, self.phase == .speaking else { return }
            self.level = 0.2
        }
    }

    private func finishedSpeaking() {
        guard phase == .speaking else { return }
        spokenUpTo = reply.utf16.count
        level = 0
        if endAfterSpeaking {
            end()
        } else {
            startListening()
        }
    }

    // MARK: - Calls and other apps

    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let began = type == AVAudioSession.InterruptionType.began.rawValue
            Task { @MainActor in self?.interrupted(began: began) }
        }
    }

    /// A phone call pauses the conversation; it waits for you to tap to continue.
    private func interrupted(began: Bool) {
        guard isActive else { return }
        if began {
            synthesizer.stopSpeaking(at: .immediate)
            stopRecognition()
            micMuted = true
            phase = .muted
            level = 0
            updateActivity()
        } else if engineReady && !engine.isRunning {
            try? AVAudioSession.sharedInstance().setActive(true)
            try? engine.start()
        }
    }

    // MARK: - Dynamic Island

    var activityState: LiminalActivityAttributes.ContentState {
        typealias State = LiminalActivityAttributes.ContentState
        switch phase {
        case .listening:
            let detail = heard.isEmpty ? (reply.isEmpty ? "Habla cuando quieras" : reply) : heard
            return State(phase: .listening, title: "Te escucho", detail: detail.clipped(), startedAt: startedAt, endsAt: nil)
        case .thinking:
            return State(phase: .thinking, title: "Pensando…", detail: heard.clipped(), startedAt: startedAt, endsAt: nil)
        case .speaking:
            return State(phase: .speaking, title: "Lithium te responde", detail: reply.clipped(), startedAt: startedAt, endsAt: nil)
        case .muted:
            return State(phase: .muted, title: "Micrófono en pausa", detail: "Toca para seguir hablando", startedAt: startedAt, endsAt: nil)
        default:
            return State(phase: .listening, title: "Conversación en vivo", detail: "", startedAt: startedAt, endsAt: nil)
        }
    }

    private func updateActivity() {
        guard LiveActivityController.shared.kind == .voice else { return }
        LiveActivityController.shared.update(activityState)
    }

    // MARK: - System helpers (called off the main thread)

    nonisolated private static func microphoneAllowed() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    nonisolated private static func speechAllowed() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Latin American Spanish first, then Spain.
    nonisolated private static func makeRecognizer() -> SFSpeechRecognizer? {
        let supported = Set(SFSpeechRecognizer.supportedLocales().map { $0.identifier.replacingOccurrences(of: "_", with: "-") })
        for id in ["es-VE", "es-CO", "es-US", "es-MX", "es-419", "es-CL", "es-ES"] where supported.contains(id) {
            if let recognizer = SFSpeechRecognizer(locale: Locale(identifier: id)) { return recognizer }
        }
        return SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
    }

    /// The best-sounding Spanish voice on the iPhone, preferring Latin American accents.
    nonisolated private static func bestVoice() -> AVSpeechSynthesisVoice? {
        let spanish = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("es") }
        for language in ["es-VE", "es-CO", "es-US", "es-MX", "es-419", "es-AR", "es-CL", "es-ES"] {
            let matches = spanish.filter { $0.language == language }
            if let best = matches.max(by: { $0.quality.rawValue < $1.quality.rawValue }) { return best }
        }
        return spanish.first ?? AVSpeechSynthesisVoice(language: "es-MX")
    }

    nonisolated private static func listen(to input: AVAudioInputNode, format: AVAudioFormat, feed: AudioFeed,
                                           level: @escaping @Sendable (Double) -> Void) {
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            feed.append(buffer)
            level(Self.loudness(of: buffer))
        }
    }

    nonisolated private static func recognize(with recognizer: SFSpeechRecognizer, request: SFSpeechAudioBufferRecognitionRequest,
                                              handler: @escaping @Sendable (String?, Bool, Bool) -> Void) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            handler(result?.bestTranscription.formattedString, result?.isFinal ?? false, error != nil)
        }
    }

    nonisolated private static func loudness(of buffer: AVAudioPCMBuffer) -> Double {
        guard let samples = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var sum: Float = 0
        for index in 0..<count { sum += samples[index] * samples[index] }
        return loudness(rms: (sum / Float(count)).squareRoot())
    }

    /// Maps the microphone's volume to 0…1: −50 dB and quieter is 0, −5 dB and louder is 1.
    nonisolated static func loudness(rms: Float) -> Double {
        let decibels = 20 * log10(max(Double(rms), 0.000_01))
        return min(1, max(0, (decibels + 50) / 45))
    }
}

/// Hands microphone audio to the current recognition request. Used from the audio thread.
final class AudioFeed: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest? = nil

    func set(_ request: SFSpeechAudioBufferRecognitionRequest?) {
        lock.lock()
        self.request = request
        lock.unlock()
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        let current = request
        lock.unlock()
        current?.append(buffer)
    }
}

/// Passes on which word Lithium is saying and when it finishes.
final class SpeechEvents: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    var onWord: (@Sendable (NSRange) -> Void)? = nil
    var onFinish: (@Sendable () -> Void)? = nil

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange,
                           utterance: AVSpeechUtterance) {
        onWord?(characterRange)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish?()
    }
}
