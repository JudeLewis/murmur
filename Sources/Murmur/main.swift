import AppKit
import MurmurCore
import MurmurSpeech

// Test mode, for checking the model without speaking:
//   Murmur --transcribe recording.wav [--exact]
// prints the text that would have been pasted, then quits.
if let index = CommandLine.arguments.firstIndex(of: "--transcribe"), index + 1 < CommandLine.arguments.count {
    let url = URL(fileURLWithPath: CommandLine.arguments[index + 1])
    let model: SpeechModel = CommandLine.arguments.contains("--exact") ? .exact : .tidy
    Task {
        do {
            Settings.registerDefaults()
            let samples = try Transcriber.samples(fromFile: url)
            let raw = try await Transcriber().transcribe(samples, sampleRate: 16_000, model: model)
            print(Tidy.finish(raw, words: Settings.words(), british: Settings.british))
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
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
