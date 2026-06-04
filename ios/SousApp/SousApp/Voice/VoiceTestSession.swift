import AVFoundation
import Combine
import Foundation

/// Minimal, self-contained Realtime session used only by the Voice Debug
/// "Test Voice" button. It opens a one-shot Realtime connection, has the model
/// speak a fixed test phrase using the selected persona, plays the audio back,
/// and tears everything down cleanly.
///
/// This deliberately does NOT reuse `VoiceModeCoordinator` (too stateful) and
/// does not touch the production voice pipeline. The PCM16 / 24kHz decode logic
/// mirrors `VoiceModeCoordinator.handleAudioDelta`.
@MainActor
final class VoiceTestSession: ObservableObject {
    @Published var isTesting: Bool = false
    @Published var status: String = ""

    private var webSocketTask: URLSessionWebSocketTask?
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var engineStarted = false
    private var scheduledBuffers = 0

    private var sessionCreatedContinuation: CheckedContinuation<Void, Error>?
    private var responseDoneContinuation: CheckedContinuation<Void, Error>?

    private enum TestError: Error { case timeout, socketClosed, setupFailed }

    private let testPhrase = "That could work. when in doubt, add more salt!"

    deinit {
        // Last-resort cleanup so a discarded session never leaks its socket
        // or audio engine. deinit is nonisolated but may touch stored state.
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        if engineStarted { audioEngine.stop() }
    }

    // MARK: - Public

    func test(settings: VoiceDebugSettings, accent: VoiceAccent, gender: VoiceGender, apiKey: String) async {
        guard !isTesting else { return }
        guard !apiKey.isEmpty else {
            status = "No API key"
            return
        }

        isTesting = true
        status = "Connecting..."

        // 1. Audio session — playback only; we never capture mic for the test.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            finish(status: "Audio error")
            return
        }

        // 2. Open the WebSocket.
        guard var components = URLComponents(string: "wss://api.openai.com/v1/realtime") else {
            finish(status: ""); return
        }
        components.queryItems = [URLQueryItem(name: "model", value: "gpt-realtime-mini")]
        guard let url = components.url else { finish(status: ""); return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.webSocketTask(with: request)
        webSocketTask = task
        task.resume()
        Task { await self.receiveLoop() }

        // 3. Wait for session.created (8s timeout).
        do {
            try await awaitSignal(timeout: 8,
                                  register: { self.sessionCreatedContinuation = $0 },
                                  onTimeout: {
                                      self.sessionCreatedContinuation?.resume(throwing: TestError.timeout)
                                      self.sessionCreatedContinuation = nil
                                  })
        } catch {
            finish(status: "")
            return
        }

        // Start the audio engine now that the session is live.
        do { try startEngine() } catch { finish(status: ""); return }

        // 4. session.update — persona-only instructions, selected voice, no tools.
        let pcm16 = AudioFormat(type: "audio/pcm", rate: 24000)
        let audioConfig = SessionAudioConfig(
            input: SessionAudioInputConfig(
                format: pcm16,
                turnDetection: TurnDetection(
                    type: "server_vad",
                    silenceDurationMs: 600,
                    threshold: 0.75,
                    prefixPaddingMs: 300
                ),
                transcription: nil
            ),
            output: SessionAudioOutputConfig(
                format: pcm16,
                voice: settings.voice.rawValue
            )
        )
        sendEvent(SessionUpdateEvent(session: SessionConfig(
            type: "realtime",
            instructions: buildVoicePersonaBlock(accent: accent, gender: gender),
            tools: [],
            toolChoice: "none",
            audio: audioConfig
        )))

        // 5 & 6. Inject a user message and trigger a response.
        status = "Speaking..."
        let item = ConversationItem(
            type: "message",
            role: "user",
            content: [ConversationItemContent(type: "input_text", text: testPhrase)],
            callId: nil,
            output: nil
        )
        sendEvent(ConversationItemCreateEvent(item: item))
        sendEvent(ResponseCreateEvent())

        // 8. Wait for response.done (10s timeout).
        try? await awaitSignal(timeout: 10,
                               register: { self.responseDoneContinuation = $0 },
                               onTimeout: {
                                   self.responseDoneContinuation?.resume(throwing: TestError.timeout)
                                   self.responseDoneContinuation = nil
                               })

        // Let any queued audio finish playing before tearing down (cap ~5s).
        var drainTicks = 0
        while scheduledBuffers > 0 && drainTicks < 50 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            drainTicks += 1
        }

        // 9. Clean teardown.
        finish(status: "")
    }

    // MARK: - WebSocket receive

    private func receiveLoop() async {
        while let task = webSocketTask {
            do {
                let message = try await task.receive()
                guard case .string(let text) = message,
                      let data = text.data(using: .utf8) else { continue }
                let event = try JSONDecoder().decode(RealtimeServerEvent.self, from: data)
                handle(event)
            } catch {
                sessionCreatedContinuation?.resume(throwing: TestError.socketClosed)
                sessionCreatedContinuation = nil
                responseDoneContinuation?.resume(throwing: TestError.socketClosed)
                responseDoneContinuation = nil
                break
            }
        }
    }

    private func handle(_ event: RealtimeServerEvent) {
        switch event {
        case .sessionCreated:
            sessionCreatedContinuation?.resume()
            sessionCreatedContinuation = nil
        case .responseAudioDelta(let payload):
            playChunk(payload.delta)
        case .responseDone:
            responseDoneContinuation?.resume()
            responseDoneContinuation = nil
        case .error(let payload):
            print("[VoiceTestSession] server error: \(payload.type) — \(payload.message)")
            sessionCreatedContinuation?.resume(throwing: TestError.socketClosed)
            sessionCreatedContinuation = nil
            responseDoneContinuation?.resume()
            responseDoneContinuation = nil
        default:
            break
        }
    }

    // MARK: - Audio

    private func startEngine() throws {
        audioEngine.attach(playerNode)
        guard let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                         sampleRate: 24000,
                                         channels: 1,
                                         interleaved: true) else {
            throw TestError.setupFailed
        }
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
        try audioEngine.start()
        playerNode.play()
        engineStarted = true
    }

    private func playChunk(_ base64Chunk: String) {
        guard engineStarted,
              let data = Data(base64Encoded: base64Chunk),
              let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                         sampleRate: 24000,
                                         channels: 1,
                                         interleaved: true) else { return }

        let frameCount = AVAudioFrameCount(data.count / 2)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }

        buffer.frameLength = frameCount
        data.withUnsafeBytes { rawBytes in
            guard let src = rawBytes.bindMemory(to: Int16.self).baseAddress,
                  let dst = buffer.int16ChannelData?[0] else { return }
            dst.update(from: src, count: Int(frameCount))
        }

        scheduledBuffers += 1
        playerNode.scheduleBuffer(buffer) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.scheduledBuffers = max(0, self.scheduledBuffers - 1)
            }
        }
    }

    // MARK: - Helpers

    private func sendEvent<T: Encodable>(_ event: T) {
        guard let task = webSocketTask else { return }
        Task {
            do {
                let message = try encodeWebSocketMessage(event)
                try await task.send(message)
            } catch {
                print("[VoiceTestSession] sendEvent error: \(error)")
            }
        }
    }

    /// Awaits a server signal registered via `register`, racing it against a
    /// timeout. Both the success and timeout paths nil out the stored
    /// continuation, so there is never a double-resume.
    private func awaitSignal(
        timeout seconds: Double,
        register: @escaping (CheckedContinuation<Void, Error>) -> Void,
        onTimeout: @escaping () -> Void
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    register(cont)
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                await MainActor.run { onTimeout() }
            }
            defer { group.cancelAll() }
            try await group.next()
        }
    }

    private func finish(status: String) {
        cleanup()
        self.status = status
        isTesting = false
    }

    private func cleanup() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        if engineStarted {
            playerNode.stop()
            audioEngine.stop()
            engineStarted = false
        }
        scheduledBuffers = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
