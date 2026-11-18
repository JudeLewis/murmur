import Foundation

/// Recordings kept for testing (SPEC.md 3.5), off to start with: the last 20, for 7 days, on
/// this Mac only, so changes to Murmur can be checked against your real voice.
public enum KeptRecordings {
    public static let days = 7
    public static let most = 20

    /// The file name for a recording made at `date`, which sorts by time: "2026-11-18 14.05.03".
    public static func name(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter.string(from: date)
    }

    /// Which recordings to delete: older than 7 days, or beyond the newest 20.
    public static func toDelete(_ recordings: [(name: String, date: Date)], now: Date = .now) -> [String] {
        let newestFirst = recordings.sorted { $0.date > $1.date }
        let cutoff = now.addingTimeInterval(-Double(days) * 24 * 3600)
        return newestFirst.enumerated().filter { $0.offset >= most || $0.element.date < cutoff }.map(\.element.name)
    }

    /// Mono samples as a 16-bit WAV file.
    public static func wav(_ samples: [Float], sampleRate: Int) -> Data {
        var data = Data()
        func add<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        let bytes = samples.count * 2
        data.append(contentsOf: Array("RIFF".utf8)); add(UInt32(36 + bytes))
        data.append(contentsOf: Array("WAVEfmt ".utf8)); add(UInt32(16)); add(UInt16(1)); add(UInt16(1))
        add(UInt32(sampleRate)); add(UInt32(sampleRate * 2)); add(UInt16(2)); add(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); add(UInt32(bytes))
        data.reserveCapacity(data.count + bytes)
        for sample in samples { add(Int16(max(-1, min(1, sample)) * Float(Int16.max))) }
        return data
    }
}
