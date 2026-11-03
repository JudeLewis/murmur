import MurmurCore
import SwiftUI

/// The keyboard's look, after Wispr Flow's (SPEC.md 9.2): a bar along the top
/// with the mic (or ✕, moving bars and ✓ while listening), and below it
/// numbers, punctuation, undo, delete, space and return.
struct KeyboardView: View {
    let talker: KeyboardTalker
    /// Resets by itself if the touch is cancelled (a banner, a swipe), so
    /// delete can never keep going on its own.
    @GestureState private var deleteHeld = false

    private let rows: [[String]] = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", ";", "(", ")", "£", "&", "@", "\""],
    ]

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .frame(height: 56)
                .padding(.horizontal, 8)
            VStack(spacing: 10) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(row, id: \.self) { key in
                            Button(key) { talker.type(key) }.buttonStyle(KeyStyle())
                        }
                    }
                }
                HStack(spacing: 6) {
                    Button { talker.undo() } label: { Label("undo", systemImage: "arrow.uturn.backward").labelStyle(.iconOnly) }
                        .buttonStyle(KeyStyle(special: true))
                        .frame(width: 52)
                        .accessibilityLabel("Undo the last dictation")
                    ForEach([".", ",", "?", "!", "'"], id: \.self) { key in
                        Button(key) { talker.type(key) }.buttonStyle(KeyStyle())
                    }
                    deleteKey.frame(width: 52)
                }
                HStack(spacing: 6) {
                    if talker.showsGlobe {
                        Button { talker.nextKeyboard() } label: { Image(systemName: "globe") }
                            .buttonStyle(KeyStyle(special: true))
                            .frame(width: 46)
                    }
                    Button { talker.typeAgain() } label: { Label("again", systemImage: "arrow.clockwise").font(.system(size: 15)) }
                        .buttonStyle(KeyStyle(special: true))
                        .frame(width: 84)
                        .accessibilityLabel("Type the last dictation again")
                    Button("space") { talker.space() }.buttonStyle(KeyStyle())
                    Button("return") { talker.newLine() }.buttonStyle(KeyStyle(special: true)).frame(width: 92)
                }
            }
            .padding(.horizontal, 3)
            .padding(.bottom, 4)
        }
    }

    // MARK: The top bar

    @ViewBuilder private var topBar: some View {
        switch talker.state {
        case .listening:
            HStack(spacing: 12) {
                roundButton("xmark", colour: Color(.systemGray3), label: "Throw away") { talker.cancel() }
                if talker.isCommand {
                    Label("Say what to do", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                        .fixedSize()
                }
                Bars(levels: talker.levels.levels)
                roundButton("checkmark", colour: .accentColor, label: "Finish") { talker.talk() }
            }
        case .writing:
            HStack(spacing: 10) {
                ProgressView()
                Text(talker.note ?? (talker.isCommand ? "Thinking" : writingLine)).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                Spacer()
            }
            .padding(.leading, 6)
        default:
            HStack(spacing: 10) {
                if talker.state != .needsFullAccess {
                    Button { talker.casual.toggle() } label: {
                        Text(talker.casual ? "aa" : "Aa")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 40, height: 32)
                            .background(talker.casual ? Color.accentColor.opacity(0.2) : Color(.systemGray4).opacity(0.6), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(talker.casual ? "Casual style on" : "Casual style off")
                }
                Text(talker.note ?? statusLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if KeyboardLink.canTurnOff(in: talker.state) {
                    Button { talker.turnMicOff() } label: {
                        Image(systemName: "mic.slash")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                            .background(Color(.systemGray4).opacity(0.6), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Turn the microphone off")
                }
                if talker.showsCommand {
                    Button { talker.command() } label: {
                        Image(systemName: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tint)
                            .frame(width: 40, height: 40)
                            .background(Color.accentColor.opacity(0.15), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Command Mode: say what to do with the selected text")
                }
                if talker.state != .needsFullAccess { micButton }
            }
        }
    }

    private var statusLine: String {
        switch talker.state {
        case .needsFullAccess: "Murmur needs Full Access: open the Murmur app and follow Setting up."
        case .needsApp: "Tap the mic to turn Murmur on"
        case .ready(nil): "Tap the mic to talk"
        case .ready(_?): "The speech model is getting ready. Open Murmur and keep it on screen until it says Ready."
        case .listening, .writing: ""
        }
    }

    private var writingLine: String {
        if case .writing(_?) = talker.state { return "Writing once the speech model is ready. Open Murmur and keep it on screen." }
        return "Writing"
    }

    private var micButton: some View {
        Button { talker.talk() } label: {
            HStack(spacing: 6) {
                Image(systemName: "mic.fill")
                if talker.state == .needsApp { Text("Start").font(.subheadline.weight(.semibold)) }
            }
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(height: 40)
            .background(Color.accentColor, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(talker.state == .needsApp ? "Turn Murmur on" : "Talk")
    }

    private func roundButton(_ symbol: String, colour: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(colour, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var deleteKey: some View {
        Image(systemName: "delete.left")
            .modifier(KeyLook(special: true, pressed: deleteHeld))
            .gesture(DragGesture(minimumDistance: 0).updating($deleteHeld) { _, held, _ in held = true })
            .onChange(of: deleteHeld) { _, held in
                if held { talker.startDeleting() } else { talker.stopDeleting() }
            }
            .accessibilityLabel("Delete")
            .accessibilityAddTraits(.isButton)
    }
}

/// The moving bars while listening, like the pill on the Mac.
private struct Bars: View {
    let levels: [Float]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                Capsule()
                    .fill(Color.red)
                    .frame(width: 4, height: 4 + CGFloat(level) * 30)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.1), value: levels)
        .accessibilityLabel("Listening")
    }
}

/// Keys that look like the iPhone's own: white letters keys, grey special keys.
private struct KeyStyle: ButtonStyle {
    var special = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.modifier(KeyLook(special: special, pressed: configuration.isPressed))
    }
}

private struct KeyLook: ViewModifier {
    let special: Bool
    let pressed: Bool

    func body(content: Content) -> some View {
        content
            .font(.system(size: special ? 16 : 21))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(background, in: .rect(cornerRadius: 6))
            .shadow(color: .black.opacity(0.3), radius: 0, y: 1)
            .contentShape(.rect)
    }

    private var background: Color {
        if pressed { return Color(.systemGray3) }
        return special ? Color(.systemGray4).opacity(0.9) : Color(.systemBackground).opacity(0.95)
    }
}
