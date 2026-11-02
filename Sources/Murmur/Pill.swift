import AppKit
import SwiftUI

/// The small black pill at the bottom of the screen: moving bars while
/// listening, dots while writing, or a short message.
@MainActor
final class Pill {
    enum Mode: Equatable {
        case listening
        case working(String)
        case message(String)
    }

    @Observable
    @MainActor
    final class Model {
        var mode: Mode = .listening
        var levels: [Float] = Array(repeating: 0, count: Pill.barCount)
    }

    static let barCount = 12

    private let model = Model()
    private let panel: NSPanel
    private var hideTask: Task<Void, Never>?

    init() {
        panel = NonActivatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: PillView(model: model))
    }

    func show(_ mode: Mode) {
        hideTask?.cancel()
        model.mode = mode
        if mode == .listening { model.levels = Array(repeating: 0, count: Self.barCount) }
        place()
        panel.orderFrontRegardless()
    }

    /// Shows a message, then hides after a few seconds.
    func flash(_ message: String, seconds: Double = 3) {
        show(.message(message))
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    func hide() {
        hideTask?.cancel()
        panel.orderOut(nil)
    }

    func push(level: Float) {
        model.levels.removeFirst()
        model.levels.append(level)
    }

    /// Bottom middle of the screen the user is working on.
    private func place() {
        guard let hosting = panel.contentView, let screen = NSScreen.main else { return }
        let size = hosting.fittingSize
        let area = screen.visibleFrame
        panel.setFrame(
            NSRect(x: area.midX - size.width / 2, y: area.minY + 28, width: size.width, height: size.height),
            display: true)
    }
}

/// A panel that never takes focus away from the app being typed into.
private final class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct PillView: View {
    let model: Pill.Model

    var body: some View {
        HStack(spacing: 8) {
            switch model.mode {
            case .listening:
                Circle().fill(.red).frame(width: 8, height: 8)
                HStack(spacing: 3) {
                    ForEach(Array(model.levels.enumerated()), id: \.offset) { _, level in
                        Capsule()
                            .fill(.white)
                            .frame(width: 3, height: 4 + CGFloat(level) * 18)
                    }
                }
                .frame(height: 22)
                .animation(.linear(duration: 0.08), value: model.levels)
            case .working(let text):
                ProgressView().controlSize(.small).tint(.white)
                Text(text).foregroundStyle(.white)
            case .message(let text):
                Text(text).foregroundStyle(.white)
            }
        }
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(Capsule().fill(.black.opacity(0.85)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
        .padding(4)
        .fixedSize()
    }
}
