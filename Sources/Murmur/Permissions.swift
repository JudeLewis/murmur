import AppKit
import ApplicationServices
import AVFoundation

/// The three things macOS has to allow before Murmur works.
@MainActor
enum Permissions {
    static var microphoneAllowed: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    static func askForMicrophone() async {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }
    }

    /// Accessibility lets Murmur see the Fn key and press Command-V.
    static func askForAccessibility() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    /// macOS opens the emoji picker (or its own dictation) on Fn unless
    /// System Settings > Keyboard > "Press 🌐 key to" is set to Do Nothing (0).
    static var fnKeyDoesNothing: Bool {
        let domain = "com.apple.HIToolbox" as CFString
        CFPreferencesAppSynchronize(domain)
        return (CFPreferencesCopyAppValue("AppleFnUsageType" as CFString, domain) as? Int) == 0
    }

    static func openMicrophoneSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }

    static func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    static func openKeyboardSettings() {
        open("x-apple.systempreferences:com.apple.Keyboard-Settings.extension")
    }

    private static func open(_ address: String) {
        if let url = URL(string: address) { NSWorkspace.shared.open(url) }
    }
}
