import Foundation
import MurmurCore

/// What the Murmur app and keyboard share on the phone.
enum Shared {
    static let appGroup = "group.com.judelewis.murmur"

    /// The shared folder. The keyboard can only read and write it with Full Access.
    /// It's inside Library because that's the only part the Mac can copy from.
    static let store: LinkStore? = {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else { return nil }
        let folder = container.appending(path: "Library/Murmur", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return LinkStore(folder: folder)
    }()
}

/// A ring with no message between the app and the keyboard, meaning
/// "the other side changed its file: read it". Uses Darwin notifications,
/// the one way two processes on iOS can nudge each other.
@MainActor
enum Bell {
    static let toApp = Notification.Name("com.judelewis.murmur.toApp")
    static let toKeyboard = Notification.Name("com.judelewis.murmur.toKeyboard")

    private static var listening: Set<Notification.Name> = []
    nonisolated(unsafe) private static let observer = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)

    /// From now on, a ring arrives as an ordinary notification on the main thread.
    static func listen(for name: Notification.Name) {
        guard listening.insert(name).inserted else { return }
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), observer,
            { _, _, cfName, _, _ in
                guard let raw = cfName?.rawValue as String? else { return }
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name(raw), object: nil)
                }
            },
            name.rawValue as CFString, nil, .deliverImmediately)
    }

    static func ring(_ name: Notification.Name) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(name.rawValue as CFString), nil, nil, true)
    }
}
