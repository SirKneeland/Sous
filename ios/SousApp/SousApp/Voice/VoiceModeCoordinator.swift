    import AVFoundation
    import Combine
    import SousCore
    import SwiftUI

    // MARK: - AudioError

    private enum AudioError: Error {
        case converterSetupFailed
    }

    private enum VoiceConnectionError: Error {
        case socketClosed
        case timeout
    }

    fileprivate struct MarkStepDoneArgs: Decodable { let stepId: String }

    // MARK: - VoiceModeState

    enum VoiceModeState: Equatable {
        case ready      // Mic live, waiting for speech
        case listening  // User is speaking (partial results arriving)
        case thinking   // Utterance captured; LLM call in flight
        case speaking   // TTS playback in progress
        case patchPending // LLM returned a patch requiring review
    }

    // MARK: - VoiceModeCoordinator

    /// Manages the microphone session and speech recognition lifecycle for voice mode.
    /// Owned by ContentView via @StateObject so it persists across the session.
    /// Call configure(store:) once on appear before activate().
    @MainActor
    final class VoiceModeCoordinator: NSObject, ObservableObject {
        @Published var state: VoiceModeState = .ready
        @Published var transcript: String = ""
        @Published var patchAnnouncementTranscript: String = ""
        @Published var isActive: Bool = false
        @Published var connectionFailed: Bool = false

        /// Called when the user says an exit phrase ("done", "exit", "stop listening").
        /// Wire in ContentView to store.send(.closeVoiceMode).
        var onExit: (() -> Void)?

        /// Called when the user says an accept keyword while a patch is pending.
        /// Wire in ContentView to store.send(.acceptPatch).
        var onVoiceAccept: (() -> Void)?

        /// Called when the user says a reject keyword while a patch is pending.
        /// Wire in ContentView to store.send(.rejectPatch(userText: "")).
        var onVoiceReject: (() -> Void)?

        // Weak reference to the store, set once via configure(store:)
        private weak var store: AppStore?

        // WebSocket
        private var webSocketTask: URLSessionWebSocketTask?

        // Audio engine — single instance for both mic capture and playback
        private let audioEngine = AVAudioEngine()
        private var playerNode = AVAudioPlayerNode()

        // AVAudioConverter held so the tap closure can reference it without recreation
        private var audioConverter: AVAudioConverter?

        // Accumulates model spoken transcript deltas
        private var modelTranscriptAccumulator: String = ""

        // Function call argument accumulator — keyed by call_id
        private var functionCallAccumulator: [String: String] = [:]

        // call_id of the most recently received propose_patch call, held so
        // tap-to-accept/reject can send the function output without a live
        // function call in flight
        private var pendingFunctionCallId: String?

        // Tracks how many audio buffers are currently scheduled but not yet played.
        // Used to defer the .ready transition until the player queue is truly empty.
        private var scheduledAudioBuffers: Int = 0
        private var pendingReadyTransition: Bool = false

        // Resolved when the server sends session.created during connect()
        private var sessionCreatedContinuation: CheckedContinuation<Void, Error>?

        private var reconnectAttempts: Int = 0
        private let maxReconnectAttempts: Int = 3

        // MARK: - Lifecycle

        func configure(store: AppStore) {
            self.store = store
        }

        func activate() async {
            isActive = true
            guard await requestMicrophonePermission() else { return }

            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP])
                try session.setActive(true)
            } catch {
                return
            }

            state = .ready

            guard let key = store?.keyProvider.currentKey() else { return }
            await connect(apiKey: key)
        }

        func deactivate() {
            disconnect()
            stopAudioEngine()
            state = .ready
            transcript = ""
            modelTranscriptAccumulator = ""
            patchAnnouncementTranscript = ""
            functionCallAccumulator = [:]
            pendingFunctionCallId = nil
            connectionFailed = false
            reconnectAttempts = 0
            scheduledAudioBuffers = 0
            pendingReadyTransition = false
            isActive = false
        }

        private func handleConnectionFailure() {
            guard isActive else { return }
            disconnect()
            stopAudioEngine()
            state = .ready

            if reconnectAttempts < maxReconnectAttempts {
                reconnectAttempts += 1
                let delay = Double(reconnectAttempts)
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(delay))
                    guard self.isActive else { return }
                    guard let key = self.store?.keyProvider.currentKey() else {
                        self.connectionFailed = true
                        return
                    }
                    do {
                        try self.startAudioEngine()
                        await self.connect(apiKey: key)
                        self.reconnectAttempts = 0
                    } catch {
                        self.handleConnectionFailure()
                    }
                }
            } else {
                connectionFailed = true
            }
        }

        // MARK: - Private: permissions

        func requestMicrophonePermission() async -> Bool {
            await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission(completionHandler: { granted in
                    continuation.resume(returning: granted)
                })
            }
        }

        // MARK: - WebSocket

        private func connect(apiKey: String) async {
            guard var components = URLComponents(string: "wss://api.openai.com/v1/realtime") else { return }
            components.queryItems = [URLQueryItem(name: "model", value: "gpt-realtime-mini")]
            guard let url = components.url else { return }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            webSocketTask = URLSession.shared.webSocketTask(with: request)
            webSocketTask?.resume()

            Task { await self.receiveLoop() }

            let didCreate = await withTaskGroup(of: Bool.self) { group in
                group.addTask { @MainActor in
                    do {
                        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                            self.sessionCreatedContinuation = cont
                        }
                        return true
                    } catch {
                        return false
                    }
                }
                group.addTask {
                    try? await Task.sleep(nanoseconds: 10_000_000_000)
                    await MainActor.run {
                        self.sessionCreatedContinuation?.resume(throwing: VoiceConnectionError.timeout)
                        self.sessionCreatedContinuation = nil
                    }
                    return false
                }
                let result = await group.next() ?? false
                group.cancelAll()
                return result
            }

            guard didCreate else {
                deactivate()
                onExit?()
                return
            }

            sendSessionUpdate()
            do {
                try startAudioEngine()
            } catch {
                print("[VoiceModeCoordinator] startAudioEngine failed: \(error)")
                deactivate()
                onExit?()
                return
            }
            state = .ready
        }

        private func disconnect() {
            webSocketTask?.cancel(with: .normalClosure, reason: nil)
            webSocketTask = nil
        }

        private func sendEvent<T: Encodable>(_ event: T) {
            Task {
                guard let task = webSocketTask else { return }
                do {
                    let message = try encodeWebSocketMessage(event)
                    try await task.send(message)
                } catch {
                    print("[VoiceModeCoordinator] sendEvent error: \(error)")
                }
            }
        }

        private func receiveLoop() async {
            while webSocketTask != nil {
                guard let task = webSocketTask else { break }
                do {
                    let message = try await task.receive()
                    guard case .string(let text) = message,
                          let data = text.data(using: .utf8) else { continue }
                    let event = try JSONDecoder().decode(RealtimeServerEvent.self, from: data)
                    handleServerEvent(event)
                } catch {
                    print("[VoiceModeCoordinator] receiveLoop error: \(error)")
                    sessionCreatedContinuation?.resume(throwing: VoiceConnectionError.socketClosed)
                    sessionCreatedContinuation = nil
                    handleConnectionFailure()
                    break
                }
            }
        }

        // MARK: - Session

        private func sendSessionUpdate() {
            guard let store = store else { return }
            let recipe = store.uiState.recipe
            let memories = store.memories
            let preferences = store.userPreferences
            let lastPatchDecision = store.lastPatchDecision
            let personality = preferences.personalityMode
            let instructions = buildVoiceSystemPrompt(
                recipe: recipe,
                memories: memories,
                preferences: preferences,
                lastPatchDecision: lastPatchDecision,
                personality: personality
            )

            let proposePatch = RealtimeTool(
                type: "function",
                name: "propose_patch",
                description: "Propose a structured change to the current recipe canvas. Call this immediately when the user requests a recipe change, then announce the change verbally in one sentence.",
                parameters: RealtimeToolParameters(
                    type: "object",
                    properties: [
                        "patchSetId": RealtimeToolProperty(type: "string", description: "A new UUID v4 string."),
                        "baseRecipeId": RealtimeToolProperty(type: "string", description: "Must be copied exactly from the recipe context. Never invent this value."),
                        "baseRecipeVersion": RealtimeToolProperty(type: "integer", description: "Must be copied exactly from the recipe context. Never invent this value."),
                        "status": RealtimeToolProperty(type: "string", description: "Always 'pending'."),
                        "summary": RealtimeToolProperty(type: "string", description: "One sentence plain English summary of the change."),
                        "patches": RealtimeToolProperty(type: "array", description: "Array of patch operation objects. Each patch has a 'type' field (camelCase, e.g. 'updateIngredient', 'addStep') plus the fields for that operation type as described in the system prompt.")
                    ],
                    required: ["patchSetId", "baseRecipeId", "baseRecipeVersion", "status", "patches", "summary"]
                )
            )
            let acceptRecipe = RealtimeTool(
                type: "function",
                name: "accept_recipe",
                description: "Called when the user accepts the proposed recipe change.",
                parameters: RealtimeToolParameters(type: "object", properties: [:], required: [])
            )
            let rejectRecipe = RealtimeTool(
                type: "function",
                name: "reject_recipe",
                description: "Called when the user rejects the proposed recipe change.",
                parameters: RealtimeToolParameters(type: "object", properties: [:], required: [])
            )
            let exitVoice = RealtimeTool(
                type: "function",
                name: "exit_voice",
                description: "Called when the user wants to exit voice mode.",
                parameters: RealtimeToolParameters(type: "object", properties: [:], required: [])
            )
            let markStepDone = RealtimeTool(
                type: "function",
                name: "mark_step_done",
                description: "Mark a recipe step as complete when the user says they have finished it or asks what is next. Use the exact step ID from the current recipe context.",
                parameters: RealtimeToolParameters(
                    type: "object",
                    properties: ["stepId": RealtimeToolProperty(type: "string", description: "The UUID string of the step to mark as done. Must match a step ID from the current recipe context.")],
                    required: ["stepId"]
                )
            )
            let pcm16Format = AudioFormat(type: "audio/pcm", rate: 24000)
            let audioConfig = SessionAudioConfig(
                input: SessionAudioInputConfig(
                    format: pcm16Format,
                    turnDetection: TurnDetection(
                        type: "server_vad",
                        silenceDurationMs: 600,
                        threshold: 0.75,
                        prefixPaddingMs: 300
                    ),
                    transcription: InputAudioTranscription(model: "whisper-1")
                ),
                output: SessionAudioOutputConfig(
                    format: pcm16Format,
                    voice: "shimmer"
                )
            )
            let event = SessionUpdateEvent(session: SessionConfig(
                type: "realtime",
                instructions: instructions,
                tools: [proposePatch, acceptRecipe, rejectRecipe, exitVoice, markStepDone],
                toolChoice: "auto",
                audio: audioConfig
            ))
            sendEvent(event)
        }

        // MARK: - Audio

        private func startAudioEngine() throws {
            // 1. Attach playerNode to engine
            audioEngine.attach(playerNode)

            // 2 & 3. Playback format and connect playerNode → mainMixerNode
            guard let playbackFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                                     sampleRate: 24000,
                                                     channels: 1,
                                                     interleaved: true) else {
                throw AudioError.converterSetupFailed
            }
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: playbackFormat)

            // Enable Voice Processing I/O on the input node so the engine uses playerNode
            // output as the AEC reference signal, cancelling assistant audio from the mic feed.
            try audioEngine.inputNode.setVoiceProcessingEnabled(true)

            // 4. Create converter before installing tap
            let tapFormat = audioEngine.inputNode.outputFormat(forBus: 0)
            guard let converter = AVAudioConverter(from: tapFormat, to: playbackFormat) else {
                throw AudioError.converterSetupFailed
            }
            audioConverter = converter

            // Capture locals so the tap closure avoids @MainActor access from background thread
            let capturedConverter = converter
            let capturedPlaybackFormat = playbackFormat
            let capturedTapSampleRate = tapFormat.sampleRate

            audioEngine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { [weak self] buffer, _ in
                let frameCapacity = UInt32(Double(buffer.frameLength) * 24000.0 / capturedTapSampleRate + 1)
                guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: capturedPlaybackFormat,
                                                          frameCapacity: frameCapacity) else { return }

                var convError: NSError?
                var consumed = false
                let status = capturedConverter.convert(to: outputBuffer, error: &convError) { _, outStatus in
                    if consumed {
                        outStatus.pointee = .noDataNow
                        return nil
                    }
                    consumed = true
                    outStatus.pointee = .haveData
                    return buffer
                }

                guard status != .error, outputBuffer.frameLength > 0,
                      let channelData = outputBuffer.int16ChannelData else { return }

                let frameCount = Int(outputBuffer.frameLength)
                let ptr = UnsafeBufferPointer(start: channelData[0], count: frameCount)
                let data = Data(buffer: ptr)
                let base64String = data.base64EncodedString()

                Task { @MainActor [weak self] in
                    self?.sendEvent(InputAudioBufferAppendEvent(audio: base64String))
                }
            }

            // 5 & 6. Start engine and player node
            try audioEngine.start()
            playerNode.play()
        }

        private func stopAudioEngine() {
            playerNode.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
            audioConverter = nil
        }

        private func handleAudioDelta(_ base64Chunk: String) {
            guard let data = Data(base64Encoded: base64Chunk) else { return }

            guard let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
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

            scheduledAudioBuffers += 1
            playerNode.scheduleBuffer(buffer) { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.scheduledAudioBuffers = max(0, self.scheduledAudioBuffers - 1)
                    self.checkReadyTransition()
                }
            }
        }

        private func drainPlayerQueue() {
            // Cancels all queued buffers; their completions won't drive a stale ready transition.
            pendingReadyTransition = false
            scheduledAudioBuffers = 0
            playerNode.stop()
            playerNode.play()
        }

        private func checkReadyTransition() {
            guard pendingReadyTransition, scheduledAudioBuffers == 0, state != .patchPending else { return }
            pendingReadyTransition = false
            state = .ready
        }

        // MARK: - Event handling

        private func handleServerEvent(_ event: RealtimeServerEvent) {
            switch event {
            case .sessionCreated:
                sessionCreatedContinuation?.resume()
                sessionCreatedContinuation = nil
            case .speechStarted:
                if state == .speaking { drainPlayerQueue() }
                if state != .patchPending { state = .listening }
                modelTranscriptAccumulator = ""
                transcript = ""
            case .speechStopped:
                break
            case .responseCreated:
                state = .thinking
            case .responseAudioDelta(let payload):
                print("[Voice] audioDelta: currentState=\(state)")
                if state != .speaking && state != .patchPending {
                    state = .speaking
                }
                handleAudioDelta(payload.delta)
            case .responseAudioDone:
                break
            case .responseAudioTranscriptDelta(let payload):
                modelTranscriptAccumulator += payload.delta
                transcript = modelTranscriptAccumulator
            case .responseAudioTranscriptDone:
                if state == .patchPending {
                    patchAnnouncementTranscript = modelTranscriptAccumulator
                }
                modelTranscriptAccumulator = ""
            case .functionCallArgumentsDelta(let payload):
                functionCallAccumulator[payload.callId, default: ""] += payload.delta
            case .functionCallArgumentsDone(let payload):
                handleFunctionCallDone(
                    callId: payload.callId,
                    name: payload.name,
                    arguments: functionCallAccumulator[payload.callId] ?? payload.arguments
                )
                functionCallAccumulator[payload.callId] = nil
            case .responseDone:
                if state != .patchPending {
                    pendingReadyTransition = true
                    checkReadyTransition()  // transitions immediately if audio queue already empty
                }
            case .error(let payload):
                print("[Voice] server error: \(payload.type) — \(payload.message)")
                handleConnectionFailure()
            case .inputAudioTranscriptionCompleted(let payload):
                print("[Voice][VAD transcript] \(payload.transcript.count) chars: \"\(payload.transcript)\"")
            case .sessionUpdated, .inputAudioBufferCommitted, .conversationItemCreated,
                 .responseOutputItemAdded, .responseOutputItemDone,
                 .responseContentPartAdded, .responseContentPartDone, .rateLimitsUpdated:
                break
            case .unknown(let typeString):
                print("[Voice] unhandled event type: \(typeString)")
            }
        }

        // MARK: - Function calls

        private func handleFunctionCallDone(callId: String, name: String, arguments: String) {
            print("[Voice] handleFunctionCallDone: name=\(name) callId=\(callId)")
            switch name {
            case "propose_patch":
                print("[Voice] propose_patch arguments: \(arguments)")
                do {
                    let argsData = Data(arguments.utf8)
                    let patchSet = try JSONDecoder().decode(PatchSet.self, from: argsData)
                    store?.send(.patchReceived(patchSet))
                    pendingFunctionCallId = callId
                    state = .patchPending
                    print("[Voice] state set to patchPending")
                    sendFunctionOutput(callId: callId, result: "patch_shown", sendResponseCreate: true)
                } catch {
                    print("[Voice] propose_patch decoding failed: \(error)")
                    sendFunctionOutput(callId: callId,
                                       result: "error: patch was invalid or incomplete. Please try again with a complete patches array.",
                                       sendResponseCreate: true)
                    state = .ready
                }

            case "accept_recipe":
                onVoiceAccept?()
                store?.send(.acceptPatch)
                sendFunctionOutput(callId: callId, result: "accepted", sendResponseCreate: true)
                pendingFunctionCallId = nil
                state = .ready

            case "reject_recipe":
                onVoiceReject?()
                store?.send(.rejectPatch(userText: ""))
                sendFunctionOutput(callId: callId, result: "rejected", sendResponseCreate: true)
                pendingFunctionCallId = nil
                state = .ready

            case "exit_voice":
                sendFunctionOutput(callId: callId, result: "ok")
                deactivate()
                onExit?()

            case "mark_step_done":
                guard let argsData = arguments.data(using: .utf8),
                      let args = try? JSONDecoder().decode(MarkStepDoneArgs.self, from: argsData)
                else {
                    print("[Voice] mark_step_done: failed to decode args")
                    state = .ready
                    return
                }
            print("[Voice] mark_step_done: decoded stepId=\(args.stepId)")
            print("[Voice] mark_step_done: uuid conversion \(UUID(uuidString: args.stepId) != nil ? "succeeded" : "FAILED")")
            guard let uuid = UUID(uuidString: args.stepId) else {
                print("[Voice] mark_step_done: invalid UUID: \(args.stepId)")
                state = .ready
                return
            }
            store?.send(.markStepDone(stepId: uuid))
            print("[Voice] mark_step_done: store action sent")
            sendFunctionOutput(callId: callId, result: "step_marked_done", sendResponseCreate: true)
            state = .ready

        default:
            print("[Voice] unknown function call: \(name)")
            state = .ready
        }
    }

    private func sendFunctionOutput(callId: String, result: String, sendResponseCreate: Bool = false) {
        let item = ConversationItem(
            type: "function_call_output",
            role: nil,
            content: nil,
            callId: callId,
            output: "{\"result\": \"\(result)\"}"
        )
        sendEvent(ConversationItemCreateEvent(item: item))
        if sendResponseCreate {
            sendEvent(ResponseCreateEvent())
        }
    }

    // MARK: - Tap-to-accept/reject (called from UI)

    func userTappedAccept() {
        store?.send(.acceptPatch)
        let event = ConversationItemCreateEvent(item: ConversationItem(
            type: "message",
            role: "user",
            content: [ConversationItemContent(type: "input_text", text: "I accepted the changes")],
            callId: nil,
            output: nil
        ))
        sendEvent(event)
        sendEvent(ResponseCreateEvent())
        state = .ready
    }

    func userTappedRejected() {
        store?.send(.rejectPatch(userText: ""))
        let event = ConversationItemCreateEvent(item: ConversationItem(
            type: "message",
            role: "user",
            content: [ConversationItemContent(type: "input_text", text: "I rejected the changes")],
            callId: nil,
            output: nil
        ))
        sendEvent(event)
        sendEvent(ResponseCreateEvent())
        state = .ready
    }
}
