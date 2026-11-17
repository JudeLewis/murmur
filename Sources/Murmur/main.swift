import AppKit
import MurmurCore
import MurmurSpeech

// Test mode, for checking the model without speaking:
//   Murmur --transcribe recording.wav [--exact] [--whisper] [--email]
// prints the text that would have been pasted (quieter voices left out, as in
// the app's settings, and laid out as an email with --email), then quits.
if let index = CommandLine.arguments.firstIndex(of: "--transcribe"), index + 1 < CommandLine.arguments.count {
    let url = URL(fileURLWithPath: CommandLine.arguments[index + 1])
    let model: SpeechModel = CommandLine.arguments.contains("--exact") ? .exact : .tidy
    Task {
        do {
            Settings.registerDefaults()
            var samples = try Transcriber.samples(fromFile: url)
            if CommandLine.arguments.contains("--whisper") { samples = Loudness.boosted(samples, maxGain: Loudness.whisperGain) }
            let heard = try await Transcriber().heard(samples, sampleRate: 16_000, model: model)
            let kept = Settings.ignoreQuieterVoices ? QuietVoices.keep(heard.words) : heard.words
            let raw = kept.count == heard.words.count ? heard.text : kept.map(\.text).joined(separator: " ")
            if kept.count < heard.words.count {
                let left = heard.words.filter { word in !kept.contains { $0.start == word.start } }.map(\.text)
                FileHandle.standardError.write(Data("Left out: \(left.joined(separator: " "))\n".utf8))
            }
            let email = CommandLine.arguments.contains("--email")
            print(Tidy.dictation(raw, words: Settings.words(), snippets: Settings.snippets, british: Settings.british, email: email).text)
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
    dispatchMain()
}

// Test mode for Type as I speak (SPEC.md 2.9), without speaking or typing:
//   Murmur --live recording.wav
// plays the recording through it a second at a time and prints what would be
// on screen after each second, then the finished text and the text from reading it all at once.
if let index = CommandLine.arguments.firstIndex(of: "--live"), index + 1 < CommandLine.arguments.count {
    let url = URL(fileURLWithPath: CommandLine.arguments[index + 1])
    Task {
        do {
            Settings.registerDefaults()
            let samples = try Transcriber.samples(fromFile: url)
            let transcriber = Transcriber()
            let shape = { Tidy.dictation($0, words: Settings.words(), snippets: Settings.snippets, british: Settings.british) }
            func heard(until: Double, silence: Double = 0) async throws -> [HeardWord] {
                let part = Array(samples[0..<min(samples.count, Int(until * 16_000))])
                    + [Float](repeating: 0, count: Int(silence * 16_000))
                return try await transcriber.words(part, sampleRate: 16_000, model: .tidy)
            }
            _ = try await transcriber.words(Array(samples.prefix(16_000)), sampleRate: 16_000, model: .tidy)  // warm up
            var live = LiveTranscript()
            var onScreen = ""
            var deleted = 0
            func show(_ target: String) {
                deleted += LiveEdit.from(onScreen, to: target).delete
                onScreen = target
            }
            let length = Double(samples.count) / 16_000
            var now = 1.0
            while now < length {
                let started = Date.now
                let words = try await heard(until: now)
                live.heard(words, now: now)
                let took = Int(Date.now.timeIntervalSince(started) * 1000)
                show(shape(live.text).text)
                print(String(format: "%5.1f s (read %d ms): ", now, took) + onScreen)
                now += 1
            }
            live.finished(try await heard(until: length, silence: LiveTranscript.endSilence))
            show(shape(live.text).text)
            print("Corrected: \(deleted) characters deleted and typed again")
            print("Finished: " + onScreen)
            let whole = try await transcriber.transcribe(samples, sampleRate: 16_000, model: .tidy)
            print("All at once: " + shape(whole).text)
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
    dispatchMain()
}

// AI tidy-up test mode (SPEC.md 4.11): each line of a file, or one text, as if the
// speech model had just written it, through what the app does with the menu's settings
// (no casual style or email layout, which depend on the app in front), with timings.
//   Murmur --tidy "so i was thinking we could go to the park what do you think"
//   Murmur --tidy-file dictations.txt
if let index = CommandLine.arguments.firstIndex(where: { $0 == "--tidy" || $0 == "--tidy-file" }), index + 1 < CommandLine.arguments.count {
    let arguments = CommandLine.arguments
    Task { @MainActor in
        Settings.registerDefaults()
        let words = Settings.words(), snippets = Settings.snippets, british = Settings.british
        let triggers = snippets.map(\.trigger)
        let protected = AITidy.protected(snippets: snippets, words: words, british: british)
        let fixOn = Settings.fixCorrections
        let lines = arguments[index] == "--tidy" ? [arguments[index + 1]]
            : ((try? String(contentsOfFile: arguments[index + 1], encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
        for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            // As in the app: the model is woken when listening starts, a second or more before.
            OnDeviceAI.warmUpTidy(british: british)
            try? await Task.sleep(for: .seconds(1))
            let started = Date.now
            let note = Note()
            let dictation = await Tidy.dictation(
                line, words: words, snippets: snippets, british: british,
                fix: { fixOn ? try? await OnDeviceAI.fixSelfCorrection(in: $0, keeping: triggers) : nil },
                tidy: { text in
                    do {
                        let tidied = try await OnDeviceAI.tidy(text, keeping: protected, british: british)
                        await note.set(tidied == nil ? "kept" : "tidied")
                        return tidied
                    } catch {
                        await note.set(OnDeviceAI.message(for: error))
                        return nil
                    }
                })
            print(String(format: "IN  %@\nOUT %@\n    (%@, %.1f s)\n", line, dictation.text, await note.text, Date.now.timeIntervalSince(started)))
        }
        exit(0)
    }
    dispatchMain()
}

/// What happened to one line in --tidy, for printing.
actor Note {
    var text = "too short or long to ask"
    func set(_ value: String) { text = value }
}

// Test modes for the on-device AI, run the same way as in the app:
//   Murmur --rewrite "make this friendlier" "Send me the report."   (Command Mode)
//   Murmur --fix "Monday, no wait, I mean Tuesday."                 (self-corrections)
if let index = CommandLine.arguments.firstIndex(where: { $0 == "--rewrite" || $0 == "--fix" }), index + 1 < CommandLine.arguments.count {
    let arguments = CommandLine.arguments
    Task { @MainActor in
        Settings.registerDefaults()
        let words = Settings.words()
        do {
            if arguments[index] == "--rewrite" {
                let selection = index + 2 < arguments.count ? arguments[index + 2] : nil
                let reply = try await OnDeviceAI.respond(
                    instructions: CommandMode.instructions(british: Settings.british),
                    prompt: CommandMode.prompt(instruction: arguments[index + 1], selection: selection), within: 20)
                print(CommandMode.finish(reply: reply, words: words, british: Settings.british, replacingSelection: selection != nil))
            } else {
                let said = arguments[index + 1]
                let reply = try await OnDeviceAI.respond(
                    instructions: SelfCorrection.instructions, prompt: SelfCorrection.prompt(said), within: 3)
                print(SelfCorrection.accept(original: said, fixed: reply, keeping: Settings.snippets.map(\.trigger)) ?? said)
            }
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("\(OnDeviceAI.message(for: error))\n".utf8))
            exit(1)
        }
    }
    dispatchMain()
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
