import AppKit
import FluidAudio
import MurmurCore

/// Which speech model turns speech into text.
enum SpeechModel: String, CaseIterable, Sendable {
    /// Bark 3.0 Clean: drops "um", "er", false starts and repeated words.
    case tidy
    /// Bark 3.0: everything exactly as said.
    case exact

    var version: AsrModelVersion {
        switch self {
        case .tidy: .bark3Clean
        case .exact: .bark3
        }
    }
}

/// Choices from the menu, kept between launches.
@MainActor
enum Settings {
    private static let defaults = UserDefaults.standard

    static func registerDefaults() {
        defaults.register(defaults: [
            "model": SpeechModel.tidy.rawValue,
            "british": true,
            "sounds": true,
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
}
