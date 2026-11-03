import FoundationModels
import MurmurCore

/// Apple's on-device AI model (Apple Intelligence): free, private, works
/// offline. Used for Command Mode and for fixing self-corrections, on the Mac
/// and in the iPhone app. The prompts and the checks on replies live in MurmurCore.
public enum OnDeviceAI {
    public enum Problem: Error {
        case unavailable
        case tooLong
        case refused
        case failed
        case tooSlow
        /// iOS limits how much an app in the background may ask the model.
        case busy
    }

    public static var isAvailable: Bool {
        if #available(macOS 26, iOS 26, *) { return SystemLanguageModel.default.isAvailable }
        return false
    }

    /// Command Mode (SPEC.md 2.7 and 9.7): the reply to a spoken instruction about
    /// the selected text, or new text when nothing is selected. Cleaned up, with
    /// British spelling (if on) and the word list; a space after it only if `addSpace`.
    public static func command(
        _ instruction: String, selection: String?, words: [WordEntry], british: Bool, addSpace: Bool
    ) async throws -> String {
        let reply = try await respond(
            instructions: CommandMode.instructions(british: british),
            prompt: CommandMode.prompt(instruction: instruction, selection: selection), within: 20)
        let text = CommandMode.finish(reply: reply, words: words, british: british, replacingSelection: !addSpace)
        guard !text.isEmpty else { throw Problem.failed }
        return text
    }

    /// "Monday, no wait, I mean Tuesday" (SPEC.md 4.8): the fixed text, or nil to
    /// keep what was said (no correction word, or the reply did more than take
    /// words out). Throws if the model is off, slow or won't answer.
    public static func fixSelfCorrection(in finished: String, keeping phrases: [String]) async throws -> String? {
        guard SelfCorrection.mightCorrect(finished) else { return nil }
        guard isAvailable else { throw Problem.unavailable }
        let reply = try await respond(
            instructions: SelfCorrection.instructions, prompt: SelfCorrection.prompt(finished), within: 3)
        guard let fixed = SelfCorrection.accept(original: finished, fixed: reply, keeping: phrases),
              fixed != finished else { return nil }
        return fixed
    }

    /// Gives up after `seconds`, so a slow or stuck model can't leave Murmur
    /// unable to start the next dictation. Not a task group: that would still
    /// wait for the model to notice it was cancelled.
    public static func respond(instructions: String, prompt: String, within seconds: Double) async throws -> String {
        let work = Task { try await respond(instructions: instructions, prompt: prompt) }
        return try await withCheckedThrowingContinuation { continuation in
            let first = FirstAnswer(continuation)
            Task { await first.resume(with: await work.result) }
            Task {
                try? await Task.sleep(for: .seconds(seconds))
                work.cancel()
                await first.resume(with: .failure(Problem.tooSlow))
            }
        }
    }

    /// Whichever comes first, the answer or the time limit, is the one used.
    private actor FirstAnswer {
        private var continuation: CheckedContinuation<String, Error>?

        init(_ continuation: CheckedContinuation<String, Error>) {
            self.continuation = continuation
        }

        func resume(with result: Result<String, Error>) {
            continuation?.resume(with: result)
            continuation = nil
        }
    }

    private static func respond(instructions: String, prompt: String) async throws -> String {
        guard #available(macOS 26, iOS 26, *), SystemLanguageModel.default.isAvailable else { throw Problem.unavailable }
        do {
            // The gentler safety setting Apple provides for rewriting the user's
            // own text; the default one blocked harmless shopping lists (2 Nov 2026).
            let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
            let session = LanguageModelSession(model: model, instructions: instructions)
            return try await session.respond(to: prompt).content
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize: throw Problem.tooLong
            case .guardrailViolation, .refusal: throw Problem.refused
            case .rateLimited, .concurrentRequests: throw Problem.busy
            default: throw Problem.failed
            }
        } catch {
            throw Problem.failed
        }
    }

    /// What to show (the Mac's pill, the iPhone keyboard) when it didn't work.
    public static func message(for error: Error) -> String {
        #if os(macOS)
        let settings = "System Settings"
        #else
        let settings = "Settings"
        #endif
        return switch error as? Problem {
        case .unavailable: "Command Mode needs Apple Intelligence: \(settings), Apple Intelligence & Siri."
        case .tooLong: "That's too much text for the on-device AI. Select less and try again."
        case .refused: "The on-device AI wouldn't do that one."
        case .tooSlow: "The on-device AI took too long. Try again."
        case .busy: "Apple Intelligence is busy. Try again in a moment."
        default: "The on-device AI couldn't do that. Try again."
        }
    }
}
