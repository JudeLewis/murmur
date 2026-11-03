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
            func heard(from start: Double, until: Double, silence: Double = 0) async throws -> [HeardWord] {
                let part = Array(samples[min(samples.count, Int(start * 16_000))..<min(samples.count, Int(until * 16_000))])
                    + [Float](repeating: 0, count: Int(silence * 16_000))
                return try await transcriber.words(part, sampleRate: 16_000, model: .tidy)
                    .map { HeardWord($0.text, start: $0.start + start, end: $0.end + start) }
            }
            _ = try await transcriber.words(Array(samples.prefix(16_000)), sampleRate: 16_000, model: .tidy)  // warm up
            var live = LiveTranscript()
            let length = Double(samples.count) / 16_000
            var now = 1.0
            while now < length {
                let started = Date.now
                let words = try await heard(from: live.windowStart, until: now)
                _ = live.heard(words, now: now)
                let took = Int(Date.now.timeIntervalSince(started) * 1000)
                print(String(format: "%5.1f s (read %d ms): ", now, took) + shape(live.text).text)
                now += 1
            }
            _ = live.finished(try await heard(from: live.windowStart, until: length, silence: LiveTranscript.endSilence))
            print("Finished: " + shape(live.text).text)
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
