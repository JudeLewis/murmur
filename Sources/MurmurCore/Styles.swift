import Foundation

/// How dictations are written in each app on the Mac (SPEC.md 4.7), like Wispr Flow's styles.
public enum WritingStyle: String, CaseIterable, Sendable {
    /// Capitals and full stops, tidied by the AI.
    case normal
    /// No capital at the start, no full stop at the end: for chats.
    case casual
    /// All small letters ("I" and names kept), commas rather than full stops: for quick chats.
    case veryCasual
    /// No AI tidy-up and no "no wait" fix: your words as the speech model heard them, for notes.
    case asSaid

    public var title: String {
        switch self {
        case .normal: "Normal"
        case .casual: "Casual (no capital or full stop at the ends)"
        case .veryCasual: "Very casual (small letters, no full stops)"
        case .asSaid: "As said (no AI tidy-up)"
        }
    }

    /// For the menu item that holds the choice: "Style in Messages: Casual".
    public var shortName: String {
        switch self {
        case .normal: "Normal"
        case .casual: "Casual"
        case .veryCasual: "Very casual"
        case .asSaid: "As said"
        }
    }

    /// Whether Apple Intelligence may tidy or fix the words.
    public var usesAI: Bool { self != .asSaid }
}

/// The style for each app, by bundle id. Apps not listed are Normal.
public struct AppStyles: Equatable, Sendable {
    public private(set) var styles: [String: WritingStyle]

    /// Messages and WhatsApp start casual, as before styles (SPEC.md 4.7).
    public static let starting: [String: WritingStyle] = ["com.apple.MobileSMS": .casual, "net.whatsapp.WhatsApp": .casual]

    /// From saved settings; before 18 Nov 2026 only a list of casual apps was saved.
    public init(saved: [String: String]?, casualApps: [String]? = nil) {
        if let saved {
            styles = saved.compactMapValues(WritingStyle.init(rawValue:))
        } else if let casualApps {
            styles = Dictionary(uniqueKeysWithValues: casualApps.map { ($0, WritingStyle.casual) })
        } else {
            styles = Self.starting
        }
    }

    public func style(for app: String?) -> WritingStyle {
        app.flatMap { styles[$0] } ?? .normal
    }

    public mutating func set(_ style: WritingStyle, for app: String) {
        styles[app] = style == .normal ? nil : style
    }

    /// What to save.
    public var saved: [String: String] { styles.mapValues(\.rawValue) }
}

extension Tidy {
    /// Very casual style: casual, then every word in small letters except "I", words with
    /// capitals inside (iPhone, NHS) and names in the word list, and full stops inside
    /// become commas: "Sounds good. See you at 6" becomes "sounds good, see you at 6".
    public static func veryCasual(_ text: String, keeping words: [WordEntry] = []) -> String {
        let names = Set(words.map(\.written).filter { $0.first?.isUppercase == true }.flatMap { $0.split(separator: " ").map(String.init) })
        var result = ""
        var word = ""
        func flush() {
            let plain = word.replacingOccurrences(of: "\u{2019}", with: "'")
            let isI = plain == "I" || plain.hasPrefix("I'")
            let keep = isI || word.dropFirst().contains(where: \.isUppercase) || names.contains(word)
            result += keep ? word : word.lowercased()
            word = ""
        }
        for character in casual(text, keeping: words) {
            if character.isLetter || character == "'" || character == "\u{2019}" { word.append(character) } else { flush(); result.append(character) }
        }
        flush()
        return result.replacingOccurrences(of: "\\.(?= +\\p{Ll})", with: ",", options: .regularExpression)
    }
}
