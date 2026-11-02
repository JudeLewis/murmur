import MurmurCore
import MurmurUI
import SwiftUI
import UIKit

/// The Murmur app's one screen (SPEC.md 9.1).
struct ContentView: View {
    @Bindable var murmur: PhoneMurmur

    var body: some View {
        NavigationStack {
            List {
                if let since = murmur.preparingSince, murmur.preparing != nil {
                    Section { GettingReady(since: since, fromKeyboard: murmur.openedFromKeyboard) }
                } else if murmur.openedFromKeyboard && murmur.sessionOn {
                    Section {
                        Label("Murmur is on. Tap ◀ at the top left to go back.", systemImage: "arrow.uturn.backward.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.tint)
                    }
                }

                Section {
                    Text(statusLine)
                    if murmur.sessionOn {
                        Button("Turn off now") { murmur.endSession("turned off in the app") }
                    }
                    if murmur.modelProblem != nil {
                        Button("Try again") { murmur.loadModel() }
                    }
                }

                Section {
                    talkButton
                    if let note = murmur.note {
                        Text(note).foregroundStyle(.secondary)
                    }
                    if let text = murmur.lastText {
                        Text(text).textSelection(.enabled)
                    }
                }

                if !murmur.recent.items.isEmpty {
                    Section("Recent (tap to copy)") {
                        ForEach(Array(murmur.recent.items.prefix(10).enumerated()), id: \.offset) { _, text in
                            Button { murmur.copy(text) } label: {
                                Text(text).lineLimit(2).foregroundStyle(.primary)
                            }
                        }
                    }
                }

                Section("Settings") {
                    Toggle("Tidy speech (drops um and er)", isOn: $murmur.tidy)
                    Toggle("British spelling", isOn: $murmur.british)
                    NavigationLink("Word list and snippets") {
                        WordsView(model: murmur.words)
                            .navigationTitle("Word list and snippets")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }

                Section("Setting up the keyboard") {
                    Text("1. Tap Open Settings below.\n2. Tap Keyboards.\n3. Turn on Murmur, then Allow Full Access.\n4. In any app, tap 🌐 under the keyboard to switch to Murmur.")
                    Text("Full Access lets the keyboard and this app share two small files. Murmur's keyboard sends nothing online.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
            }
            .navigationTitle("Murmur")
        }
    }

    private var statusLine: String {
        if let problem = murmur.micProblem { return problem }
        if let problem = murmur.modelProblem { return problem }
        if murmur.preparing != nil { return "Getting ready…" }
        if murmur.sessionOn { return "Keyboard on. Turns off 10 minutes after your last dictation." }
        return "Ready"
    }

    private var talkButton: some View {
        Button { murmur.talk() } label: {
            HStack(spacing: 12) {
                switch murmur.phase {
                case .idle:
                    Image(systemName: "mic.fill")
                    Text("Talk")
                case .recording:
                    Image(systemName: "stop.fill")
                    Text("Listening. Tap to stop.")
                case .transcribing:
                    ProgressView().tint(.white)
                    Text("Writing")
                }
            }
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(murmur.phase == .recording ? Color.red : Color.accentColor, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(murmur.phase == .transcribing)
        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
    }
}

/// The card shown while the speech model gets ready for this iPhone, which
/// takes minutes after every update (SPEC.md 9.1).
private struct GettingReady: View {
    let since: Date
    let fromKeyboard: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ProgressView()
                Text("Getting Murmur ready").font(.headline)
                Spacer()
                TimelineView(.periodic(from: since, by: 1)) { context in
                    let seconds = max(0, Int(context.date.timeIntervalSince(since)))
                    Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Text("After an update this takes a few minutes, once. Keep this screen open; it stays awake by itself.")
                .font(.subheadline)
            if fromKeyboard {
                Text("Once it says Ready, tap \u{25C0} at the top left to go back.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 6)
    }
}
