import Foundation

/// The files the iPhone app and keyboard share, in their App Group folder.
/// The app writes status.json; the keyboard writes request.json. Each also
/// keeps a short trace of what it did, never the words.
public struct LinkStore: Sendable {
    public let folder: URL

    public init(folder: URL) {
        self.folder = folder
    }

    public func status() -> PhoneStatus? { read("status.json") }
    public func save(_ status: PhoneStatus) { write(status, to: "status.json") }

    public func request() -> KeyboardRequest? { read("request.json") }
    public func save(_ request: KeyboardRequest) { write(request, to: "request.json") }

    /// Adds a line to trace-<who>.txt, keeping the last `Trace.limit` lines.
    public func trace(_ event: String, from who: String, at date: Date = .now) {
        let url = folder.appending(path: "trace-\(who).txt")
        let old = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        try? Trace.adding(event, at: date, to: old).write(to: url, atomically: true, encoding: .utf8)
    }

    private func read<T: Decodable>(_ name: String) -> T? {
        guard let data = try? Data(contentsOf: folder.appending(path: name)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func write<T: Encodable>(_ value: T, to name: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: folder.appending(path: name), options: .atomic)
    }
}

/// A short diagnostic trace: one timed line per event, oldest first.
public enum Trace {
    public static let limit = 200

    public static func adding(_ event: String, at date: Date, to text: String) -> String {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        lines.append("\(date.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: true))) \(event)")
        return lines.suffix(limit).joined(separator: "\n") + "\n"
    }
}
