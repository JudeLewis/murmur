import MurmurCore
import SwiftUI

/// The word list and snippets (SPEC.md 4.2 and 4.5), for the Mac window and the iPhone app.
public struct WordsView: View {
    @Bindable var model: WordsModel
    @State private var tab = Tab.words
    @State private var editingWord: WordRow?
    @State private var editingSnippet: Snippet?
    @State private var fixing = false

    enum Tab: String, CaseIterable {
        case words = "Word list"
        case snippets = "Snippets"
    }

    public init(model: WordsModel) {
        self.model = model
    }

    public var body: some View {
        List {
            Picker("Show", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .listRowBackground(Color.clear)

            switch tab {
            case .words: words
            case .snippets: snippetList
            }
        }
        .sheet(item: $editingWord) { row in
            WordForm(row: row, isNew: !model.rows.contains { $0.id == row.id }, save: model.save, delete: model.delete)
        }
        .sheet(item: $editingSnippet) { snippet in
            SnippetForm(snippet: snippet, isNew: !model.snippets.contains { $0.id == snippet.id }, save: model.save, delete: model.delete)
        }
        .sheet(isPresented: $fixing) {
            FixFromRecent(recent: model.recent(), add: model.add)
        }
    }

    @ViewBuilder private var words: some View {
        Section {
            Button { editingWord = WordRow() } label: { Label("Add a word", systemImage: "plus.circle.fill") }
            Button { fixing = true } label: { Label("Add a fix from a recent dictation", systemImage: "wand.and.stars") }
        } footer: {
            Text("Murmur always writes these exactly as you type them. Add what it hears wrongly to fix it.")
        }
        Section {
            if model.rows.isEmpty { Text("No words yet.").foregroundStyle(.secondary) }
            ForEach(model.rows) { row in
                Button { editingWord = row } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.written.isEmpty ? "Remove \u{201C}\(row.heard)\u{201D}" : row.written)
                            .font(.body.weight(.medium)).foregroundStyle(.primary)
                        if !row.heard.isEmpty, !row.written.isEmpty {
                            Text("when it hears \u{201C}\(row.heard)\u{201D}").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in offsets.map { model.rows[$0] }.forEach(model.delete) }
        }
    }

    @ViewBuilder private var snippetList: some View {
        Section {
            Button { editingSnippet = Snippet(trigger: "", text: "") } label: { Label("Add a snippet", systemImage: "plus.circle.fill") }
        } footer: {
            Text("Say the phrase and Murmur writes the saved text instead, exactly as saved.")
        }
        Section {
            if model.snippets.isEmpty { Text("No snippets yet. Try \u{201C}my email\u{201D}.").foregroundStyle(.secondary) }
            ForEach(model.snippets) { snippet in
                Button { editingSnippet = snippet } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\u{201C}\(snippet.trigger)\u{201D}").font(.body.weight(.medium)).foregroundStyle(.primary)
                        Text(snippet.text).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in offsets.map { model.snippets[$0] }.forEach(model.delete) }
        }
    }
}

/// Adding or changing one word list entry.
struct WordForm: View {
    @State var row: WordRow
    let isNew: Bool
    let save: (WordRow) -> Void
    let delete: (WordRow) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        FormSheet(title: isNew ? "Add a word" : "Change a word", canSave: row.entry != nil, isNew: isNew,
                  save: { save(row) }, delete: { delete(row) }) {
            Section {
                TextField("Write it as", text: $row.written, prompt: Text("Wispr Flow"))
                    .plainTyping()
            } header: { Text("Write it as") }
            Section {
                TextField("When it hears", text: $row.heard, prompt: Text("wisper flow (optional)"))
                    .plainTyping()
            } header: { Text("When it hears") } footer: {
                Text("Leave this empty to just fix the spelling and capitals. To remove a word, leave Write it as empty and put the word here.")
            }
        }
    }
}

/// Adding or changing one snippet.
struct SnippetForm: View {
    @State var snippet: Snippet
    let isNew: Bool
    let save: (Snippet) -> Void
    let delete: (Snippet) -> Void

    var body: some View {
        FormSheet(title: isNew ? "Add a snippet" : "Change a snippet",
                  canSave: !snippet.trigger.trimmingCharacters(in: .whitespaces).isEmpty && !snippet.text.isEmpty,
                  isNew: isNew, save: { save(snippet) }, delete: { delete(snippet) }) {
            Section {
                TextField("When you say", text: $snippet.trigger, prompt: Text("my email"))
                    .plainTyping()
            } header: { Text("When you say") }
            Section {
                TextEditor(text: $snippet.text)
                    .frame(minHeight: 120)
                    .plainTyping()
            } header: { Text("Write") }
        }
    }
}

/// Pick a recent dictation, correct it, and add the words that changed.
struct FixFromRecent: View {
    let recent: [String]
    let add: ([WordEntry]) -> Void
    @State private var original: String?
    @State private var edited = ""
    @State private var suggestions: [WordEntry]?
    @State private var chosen: Set<Int> = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if let suggestions {
                    Section {
                        if suggestions.isEmpty { Text("No changed words found. Change a word or name, then try again.") }
                        ForEach(Array(suggestions.enumerated()), id: \.offset) { index, entry in
                            Toggle(isOn: Binding(get: { chosen.contains(index) }, set: { on in
                                if on { chosen.insert(index) } else { chosen.remove(index) }
                            })) {
                                Text(entry.heard == entry.written ? "Always write \u{201C}\(entry.written)\u{201D}"
                                     : "\u{201C}\(entry.heard)\u{201D} becomes \u{201C}\(entry.written)\u{201D}")
                            }
                        }
                    } header: { Text("Add to the word list") }
                } else if original != nil {
                    Section {
                        TextEditor(text: $edited).frame(minHeight: 140).plainTyping()
                    } header: { Text("Correct the words Murmur got wrong") }
                } else {
                    Section {
                        if recent.isEmpty { Text("Nothing dictated yet.").foregroundStyle(.secondary) }
                        ForEach(Array(recent.prefix(20).enumerated()), id: \.offset) { _, text in
                            Button { original = text; edited = text } label: {
                                Text(text).lineLimit(3).foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: { Text("Pick a recent dictation") }
                }
            }
            .navigationTitle("Add a fix")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if let suggestions {
                        Button("Add") {
                            add(chosen.sorted().map { suggestions[$0] })
                            dismiss()
                        }
                        .disabled(chosen.isEmpty)
                    } else if let original {
                        Button("Next") {
                            let found = WordFix.suggest(original: original, edited: edited)
                            suggestions = found
                            chosen = Set(found.indices)
                        }
                    }
                }
            }
        }
        .sheetSize()
    }
}

/// A form in a sheet with Cancel, Save and (for an existing entry) Delete.
struct FormSheet<Content: View>: View {
    let title: String
    let canSave: Bool
    let isNew: Bool
    let save: () -> Void
    let delete: () -> Void
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                content
                if !isNew {
                    Section {
                        Button("Delete", role: .destructive) {
                            delete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .sheetSize()
    }
}

extension View {
    /// Names and email addresses: no autocorrect or automatic capitals on iPhone.
    func plainTyping() -> some View {
        #if os(iOS)
        self.autocorrectionDisabled().textInputAutocapitalization(.never)
        #else
        self.autocorrectionDisabled()
        #endif
    }

    /// Mac sheets need a size; iPhone sheets fill the screen.
    func sheetSize() -> some View {
        #if os(macOS)
        self.frame(minWidth: 420, minHeight: 380)
        #else
        self
        #endif
    }
}
