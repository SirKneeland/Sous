import Combine
import Foundation

// MARK: - Voice persona options

enum VoiceOption: String, CaseIterable {
    case shimmer, cedar, marin
    var displayName: String { rawValue.capitalized }
}

enum VoiceAccent: String, CaseIterable, Codable {
    case american = "American"
    case australian = "Australian"
    case british = "British"
}

enum VoiceGender: String, CaseIterable, Codable {
    case feminine = "Female"
    case masculine = "Male"
}

// MARK: - VoiceDebugSettings

/// Debug-only voice-model override, persisted in UserDefaults.
///
/// This is developer-only infrastructure used by the Voice Debug "Test Voice"
/// button. Production voice mode no longer reads from here: accent and gender
/// are owned by `UserPreferences`, and the production voice model is derived
/// from `UserPreferences.voiceGender`. `voice` defaults to cedar.
final class VoiceDebugSettings: ObservableObject {
    static let shared = VoiceDebugSettings()

    @Published var voice: VoiceOption { didSet { defaults.set(voice.rawValue, forKey: Keys.voice) } }

    private let defaults: UserDefaults

    private enum Keys {
        static let voice = "voiceDebug_voice"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Load persisted value; fall back to the documented default.
        // didSet does not fire for assignments inside init, so this does not
        // re-write UserDefaults on launch.
        voice = VoiceOption(rawValue: defaults.string(forKey: Keys.voice) ?? "") ?? .cedar
    }
}
