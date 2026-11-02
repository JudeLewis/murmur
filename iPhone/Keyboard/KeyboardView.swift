import MurmurCore
import SwiftUI

/// The keyboard's look: a status line, a big Talk button, and a row of
/// space, delete and return (SPEC.md 9.2).
struct KeyboardView: View {
    let talker: KeyboardTalker
    /// Resets by itself if the touch is cancelled (a banner, a swipe), so
    /// delete can never keep going on its own.
    @GestureState private var deleteHeld = false

    var body: some View {
        VStack(spacing: 14) {
            Text(talker.note ?? statusLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(minHeight: 36)

            ZStack {
                talkButton
                if talker.state == .listening {
                    Button { talker.cancel() } label: {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.semibold))
                            .frame(width: 48, height: 48)
                            .background(Color(.secondarySystemFill), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Throw away")
                    .offset(x: 110)
                }
            }

            HStack(spacing: 8) {
                if talker.showsGlobe {
                    key(Image(systemName: "globe")) { talker.nextKeyboard() }
                        .frame(width: 52)
                }
                key(Text("space")) { talker.space() }
                deleteKey.frame(width: 64)
                key(Image(systemName: "return")) { talker.newLine() }
                    .frame(width: 64)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusLine: String {
        switch talker.state {
        case .needsFullAccess: "Murmur needs Full Access: open the Murmur app and follow Setting up."
        case .needsApp: "Tap to turn Murmur on"
        case .ready(nil): "Tap to talk"
        case .ready(_?): "The speech model is getting ready. Open Murmur and keep it on screen until it says Ready."
        case .listening: "Listening. Tap to stop."
        case .writing(nil): "Writing"
        case .writing(_?): "Writing once the speech model is ready. Open Murmur and keep it on screen."
        }
    }

    private var talkButton: some View {
        Button { talker.talk() } label: {
            ZStack {
                Circle().fill(talkColour)
                switch talker.state {
                case .listening: Image(systemName: "stop.fill")
                case .writing: ProgressView().tint(.white)
                default: Image(systemName: "mic.fill")
                }
            }
            .font(.system(size: 30, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 84, height: 84)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(talker.state == .listening ? "Stop" : "Talk")
    }

    private var talkColour: Color {
        switch talker.state {
        case .listening: .red
        case .ready: .accentColor
        default: .gray
        }
    }

    private func key(_ label: some View, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            label
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(.systemBackground).opacity(0.9), in: .rect(cornerRadius: 6))
                .shadow(color: .black.opacity(0.25), radius: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private var deleteKey: some View {
        Image(systemName: "delete.left")
            .font(.body)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color(.systemBackground).opacity(0.9), in: .rect(cornerRadius: 6))
            .shadow(color: .black.opacity(0.25), radius: 0, y: 1)
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0).updating($deleteHeld) { _, held, _ in held = true })
            .onChange(of: deleteHeld) { _, held in
                if held { talker.startDeleting() } else { talker.stopDeleting() }
            }
            .accessibilityLabel("Delete")
            .accessibilityAddTraits(.isButton)
    }
}
