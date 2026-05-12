import Foundation

enum SpeechProvider: String, CaseIterable, Codable, Identifiable {
    case nativeIOS = "Native iOS (On-Device)"
    case gemini = "Gemini Audio"
    case openai = "OpenAI Whisper"
    case groq = "Groq (Whisper)"
    case deepgram = "Deepgram"
    case assemblyai = "AssemblyAI"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .nativeIOS: "apple.logo"
        case .gemini: "sparkle"
        case .openai: "waveform"
        case .groq: "hare.fill"
        case .deepgram: "waveform.path.ecg"
        case .assemblyai: "text.bubble.fill"
        }
    }

    var requiresAPIKey: Bool { self != .nativeIOS }

    var apiKeyPlaceholder: String {
        switch self {
        case .nativeIOS: "Not needed"
        case .gemini: "AIza..."
        case .openai: "sk-..."
        case .groq: "gsk_..."
        case .deepgram: "Token your-deepgram-key"
        case .assemblyai: "Your AssemblyAI key"
        }
    }

    /// Default model name for the provider's STT API. Fixed per provider — user doesn't pick.
    var defaultModel: String {
        switch self {
        case .nativeIOS: ""
        case .gemini: "gemini-2.5-flash"
        case .openai: "whisper-1"
        case .groq: "whisper-large-v3"
        case .deepgram: "nova-3"
        case .assemblyai: "universal"
        }
    }

    var description: String {
        switch self {
        case .nativeIOS: "Apple's on-device speech recognition. Free, works offline on modern iPhones, real-time partial results. Recommended default."
        case .gemini: "Gemini API audio transcription. Uses batch audio understanding, not Google Cloud's real-time Speech-to-Text API."
        case .openai: "OpenAI Whisper API. High accuracy, 99+ languages, paid per minute."
        case .groq: "Groq-hosted Whisper Large v3. Very fast inference, has a free tier."
        case .deepgram: "Deepgram Nova. Real-time and batch modes, fast and accurate."
        case .assemblyai: "AssemblyAI Universal model. Strong accuracy, free tier available."
        }
    }
}

enum SpeechLanguage: String, CaseIterable, Codable, Identifiable {
    case automatic
    case device
    case english
    case german
    case spanish
    case french
    case italian
    case portuguese
    case dutch
    case hindi
    case japanese
    case chinese
    case korean

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: "Provider Auto"
        case .device: "Use iPhone Language"
        case .english: "English"
        case .german: "German"
        case .spanish: "Spanish"
        case .french: "French"
        case .italian: "Italian"
        case .portuguese: "Portuguese"
        case .dutch: "Dutch"
        case .hindi: "Hindi"
        case .japanese: "Japanese"
        case .chinese: "Chinese"
        case .korean: "Korean"
        }
    }

    var apiLanguageCode: String? {
        switch self {
        case .automatic:
            nil
        case .device:
            Locale.autoupdatingCurrent.language.languageCode?.identifier.lowercased()
        case .english:
            "en"
        case .german:
            "de"
        case .spanish:
            "es"
        case .french:
            "fr"
        case .italian:
            "it"
        case .portuguese:
            "pt"
        case .dutch:
            "nl"
        case .hindi:
            "hi"
        case .japanese:
            "ja"
        case .chinese:
            "zh"
        case .korean:
            "ko"
        }
    }

    var preferredNativeLocale: Locale {
        switch self {
        case .automatic, .device:
            Locale.autoupdatingCurrent
        case .english:
            Locale(identifier: "en-US")
        case .german:
            Locale(identifier: "de-DE")
        case .spanish:
            Locale(identifier: "es-ES")
        case .french:
            Locale(identifier: "fr-FR")
        case .italian:
            Locale(identifier: "it-IT")
        case .portuguese:
            Locale(identifier: "pt-BR")
        case .dutch:
            Locale(identifier: "nl-NL")
        case .hindi:
            Locale(identifier: "hi-IN")
        case .japanese:
            Locale(identifier: "ja-JP")
        case .chinese:
            Locale(identifier: "zh-Hans")
        case .korean:
            Locale(identifier: "ko-KR")
        }
    }
}

// MARK: - Settings Persistence

struct SpeechSettings {
    private static let providerKey = "selectedSpeechProvider"
    private static let languageKey = "selectedSpeechLanguage"
    private static let languageKeyPrefix = "selectedSpeechLanguage_"
    private static let apiKeyKeychainPrefix = "speechApiKey_"

    /// Bulk AI dropped Fud AI's paid STT providers (OpenAI Whisper, Groq, Deepgram,
    /// AssemblyAI) in the P5 strip. The only options now are Native iOS (free,
    /// on-device) and Gemini Audio (free via the user's own Gemini API key).
    /// Stored values for any of the dropped providers fall back to Native iOS.
    static var selectedProvider: SpeechProvider {
        get {
            guard let raw = UserDefaults.standard.string(forKey: providerKey),
                  let provider = SpeechProvider(rawValue: raw),
                  provider == .nativeIOS || provider == .gemini else {
                return .nativeIOS
            }
            return provider
        }
        set {
            guard newValue == .nativeIOS || newValue == .gemini else { return }
            UserDefaults.standard.set(newValue.rawValue, forKey: providerKey)
        }
    }

    static var selectedLanguage: SpeechLanguage {
        get {
            selectedLanguage(for: selectedProvider)
        }
        set {
            setLanguage(newValue, for: selectedProvider)
        }
    }

    static func selectedLanguage(for provider: SpeechProvider) -> SpeechLanguage {
        let key = languageKeyPrefix + provider.rawValue
        guard let raw = UserDefaults.standard.string(forKey: key),
              let language = SpeechLanguage(rawValue: raw) else {
            return defaultLanguage(for: provider)
        }
        return language
    }

    static func setLanguage(_ language: SpeechLanguage, for provider: SpeechProvider) {
        UserDefaults.standard.set(language.rawValue, forKey: languageKeyPrefix + provider.rawValue)
    }

    static func defaultLanguage(for provider: SpeechProvider) -> SpeechLanguage {
        switch provider {
        case .nativeIOS:
            .device
        case .gemini, .openai, .groq:
            .automatic
        case .deepgram:
            .device
        case .assemblyai:
            .automatic
        }
    }

    static func apiKey(for provider: SpeechProvider) -> String? {
        KeychainHelper.load(key: apiKeyKeychainPrefix + provider.rawValue)
    }

    static func setAPIKey(_ key: String?, for provider: SpeechProvider) {
        let keychainKey = apiKeyKeychainPrefix + provider.rawValue
        if let key, !key.isEmpty {
            KeychainHelper.save(key: keychainKey, value: key)
        } else {
            KeychainHelper.delete(key: keychainKey)
        }
    }

    static var currentAPIKey: String? {
        apiKey(for: selectedProvider)
    }

    static func deleteAllData() {
        for provider in SpeechProvider.allCases {
            setAPIKey(nil, for: provider)
        }
        UserDefaults.standard.removeObject(forKey: providerKey)
        UserDefaults.standard.removeObject(forKey: languageKey)
        for provider in SpeechProvider.allCases {
            UserDefaults.standard.removeObject(forKey: languageKeyPrefix + provider.rawValue)
        }
    }
}
