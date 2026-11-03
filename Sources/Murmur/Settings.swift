import AppKit
import MurmurCore
import MurmurSpeech

/// Choices from the menu, kept between launches.
@MainActor
enum Settings {
    private static let defaults = UserDefaults.standard

    static func registerDefaults() {
        defaults.register(defaults: [
            "model": SpeechModel.tidy.rawValue,
            "british": true,
            "sounds": true,
            "holdToTalk": true,
            "duckMusic": true,
            "commandMode": true,
            "fixCorrections": true,
            "typeAsISpeak": true,
            "whisperMode": false,
            // Messages and WhatsApp start in casual style (SPEC.md 4.7).
            "casualApps": ["com.apple.MobileSMS", "net.whatsapp.WhatsApp"],
        ])
    }

    static var model: SpeechModel {
        get { SpeechModel(rawValue: defaults.string(forKey: "model") ?? "") ?? .tidy }
        set { defaults.set(newValue.rawValue, forKey: "model") }
    }

    static var british: Bool {
        get { defaults.bool(forKey: "british") }
        set { defaults.set(newValue, forKey: "british") }
    }

    static var sounds: Bool {
        get { defaults.bool(forKey: "sounds") }
        set { defaults.set(newValue, forKey: "sounds") }
    }

    static var holdToTalk: Bool {
        get { defaults.bool(forKey: "holdToTalk") }
        set { defaults.set(newValue, forKey: "holdToTalk") }
    }

    static var commandMode: Bool {
        get { defaults.bool(forKey: "commandMode") }
        set { defaults.set(newValue, forKey: "commandMode") }
    }

    /// Fix "no wait, I mean" with the on-device AI (SPEC.md 4.8).
    static var fixCorrections: Bool {
        get { defaults.bool(forKey: "fixCorrections") }
        set { defaults.set(newValue, forKey: "fixCorrections") }
    }

    /// Type the words while you talk, not all at the end (SPEC.md 2.9).
    static var typeAsISpeak: Bool {
        get { defaults.bool(forKey: "typeAsISpeak") }
        set { defaults.set(newValue, forKey: "typeAsISpeak") }
    }

    /// Boost quiet recordings (SPEC.md 3.4).
    static var whisperMode: Bool {
        get { defaults.bool(forKey: "whisperMode") }
        set { defaults.set(newValue, forKey: "whisperMode") }
    }

    /// The chosen microphone's id; nil for Automatic (SPEC.md 3.3).
    static var microphoneUID: String? {
        get { defaults.string(forKey: "microphoneUID") }
        set { defaults.set(newValue, forKey: "microphoneUID") }
    }

    static var duckMusic: Bool {
        get { defaults.bool(forKey: "duckMusic") }
        set { defaults.set(newValue, forKey: "duckMusic") }
    }

    /// Set while the volume is turned down, so a quit or crash mid-dictation
    /// can be put right on the next launch: [original, lowered, device].
    static var duckedVolume: [Double]? {
        get { defaults.array(forKey: "duckedVolume") as? [Double] }
        set { defaults.set(newValue, forKey: "duckedVolume") }
    }

    /// Apps (by bundle id) where dictations use casual style.
    static var casualApps: Set<String> {
        get { Set(defaults.stringArray(forKey: "casualApps") ?? []) }
        set { defaults.set(newValue.sorted(), forKey: "casualApps") }
    }

    /// Set once, so the first launch can turn on Open at Login without overriding a later "off".
    static var setUpLoginItem: Bool {
        get { defaults.bool(forKey: "setUpLoginItem") }
        set { defaults.set(newValue, forKey: "setUpLoginItem") }
    }

    static var recent: RecentList {
        get { RecentList(items: defaults.stringArray(forKey: "recent") ?? []) }
        set { defaults.set(newValue.items, forKey: "recent") }
    }

    /// ~/Library/Application Support/Murmur
    static var folder: URL {
        let url = URL.applicationSupportDirectory.appending(path: "Murmur", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// The word list file, made from the template the first time it is needed.
    static var wordListURL: URL {
        let url = folder.appending(path: "words.txt")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? WordList.template.write(to: url, atomically: true, encoding: .utf8)
        }
        return url
    }

    /// Read fresh for every dictation, so edits work straight away.
    static func words() -> [WordEntry] {
        WordList.parse((try? String(contentsOf: wordListURL, encoding: .utf8)) ?? "")
    }

    static func saveWords(_ entries: [WordEntry]) {
        try? WordList.text(for: entries).write(to: wordListURL, atomically: true, encoding: .utf8)
    }

    /// ~/Library/Application Support/Murmur/snippets.json
    static var snippets: [Snippet] {
        get { Snippets.decode(try? Data(contentsOf: folder.appending(path: "snippets.json"))) }
        set { try? Snippets.encode(newValue).write(to: folder.appending(path: "snippets.json"), options: .atomic) }
    }
}
