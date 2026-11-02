import MurmurCore
import SwiftUI
import UIKit

/// The Murmur app's one screen (SPEC.md 9.1).
struct ContentView: View {
    @Bindable var murmur: PhoneMurmur

    var body: some View {
        NavigationStack {
            List {
                if murmur.openedFromKeyboard && murmur.sessionOn {
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
                    NavigationLink("Word list") { WordListView(text: $murmur.wordList) }
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
        if let percent = murmur.preparing {
            return "Getting the speech model ready (\(percent)%). After an update this takes a few minutes. Keep Murmur open until it says Ready."
        }
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

/// The word list, edited in a text box (SPEC.md 4.2 for the rules).
struct WordListView: View {
    @Binding var text: String

    var body: some View {
        TextEditor(text: $text)
            .font(.body.monospaced())
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .padding(.horizontal, 8)
            .navigationTitle("Word list")
            .navigationBarTitleDisplayMode(.inline)
    }
}
