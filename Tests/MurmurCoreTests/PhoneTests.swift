import Foundation
import Testing
@testable import MurmurCore

private let now = Date(timeIntervalSince1970: 1_800_000_000)

private func status(session: Bool = true, phase: DictationPhase = .idle, heartbeat: Date = now, preparing: Int? = nil) -> PhoneStatus {
    var status = PhoneStatus()
    status.session = session
    status.phase = phase
    status.heartbeat = heartbeat
    status.preparing = preparing
    return status
}

@Suite("9.2 The Murmur keyboard")
struct KeyboardStateTests {
    @Test func withoutFullAccessItCanOnlyExplain() {
        #expect(KeyboardLink.state(of: status(), now: now, fullAccess: false) == .needsFullAccess)
        #expect(KeyboardLink.tap(in: .needsFullAccess) == .nothing)
    }

    @Test func followsWhatTheAppIsDoing() {
        #expect(KeyboardLink.state(of: status(), now: now, fullAccess: true) == .ready(preparing: nil))
        #expect(KeyboardLink.state(of: status(phase: .recording), now: now, fullAccess: true) == .listening)
        #expect(KeyboardLink.state(of: status(phase: .transcribing), now: now, fullAccess: true) == .writing(preparing: nil))
    }

    @Test func showsTheModelGettingReady() {
        #expect(KeyboardLink.state(of: status(preparing: 42), now: now, fullAccess: true) == .ready(preparing: 42))
        #expect(KeyboardLink.state(of: status(phase: .transcribing, preparing: 42), now: now, fullAccess: true) == .writing(preparing: 42))
    }
}

@Suite("9.3 Keyboard sessions")
struct PhoneSessionTests {
    @Test func noSessionMeansOpeningTheApp() {
        #expect(KeyboardLink.state(of: nil, now: now, fullAccess: true) == .needsApp)
        #expect(KeyboardLink.state(of: status(session: false), now: now, fullAccess: true) == .needsApp)
        #expect(KeyboardLink.tap(in: .needsApp) == .openApp)
    }

    @Test func aQuietAppCountsAsClosed() {
        let recent = now.addingTimeInterval(-(KeyboardLink.aliveFor - 1))
        let stale = now.addingTimeInterval(-KeyboardLink.aliveFor)
        #expect(KeyboardLink.state(of: status(heartbeat: recent), now: now, fullAccess: true) == .ready(preparing: nil))
        #expect(KeyboardLink.state(of: status(heartbeat: stale), now: now, fullAccess: true) == .needsApp)
        // Even mid-dictation: if the app has gone, nothing more is coming.
        #expect(KeyboardLink.state(of: status(phase: .recording, heartbeat: stale), now: now, fullAccess: true) == .needsApp)
    }

    @Test func theHeartbeatIsWellInsideTheLimit() {
        #expect(KeyboardLink.heartbeatEvery * 2 < KeyboardLink.aliveFor)
    }

    @Test func theAppSpotsTheStartLink() {
        #expect(KeyboardLink.isStart(KeyboardLink.startURL))
        #expect(KeyboardLink.isStart(URL(string: "murmur://start?from=keyboard")!))
        #expect(!KeyboardLink.isStart(URL(string: "murmur://other")!))
        #expect(!KeyboardLink.isStart(URL(string: "https://start")!))
    }

    @Test func endsTenMinutesAfterTheLastDictation() {
        var session = PhoneSession()
        #expect(!session.isOn)
        #expect(!session.shouldEnd(at: now, phase: .idle))

        session.start(at: now)
        #expect(session.isOn)
        #expect(!session.shouldEnd(at: now.addingTimeInterval(599), phase: .idle))
        #expect(session.shouldEnd(at: now.addingTimeInterval(600), phase: .idle))

        session.used(at: now.addingTimeInterval(300))
        #expect(!session.shouldEnd(at: now.addingTimeInterval(600), phase: .idle))
        #expect(session.endsAt == now.addingTimeInterval(900))
    }

    @Test func neverEndsMidDictation() {
        var session = PhoneSession()
        session.start(at: now)
        let late = now.addingTimeInterval(3600)
        #expect(!session.shouldEnd(at: late, phase: .recording))
        #expect(!session.shouldEnd(at: late, phase: .transcribing))
        #expect(session.shouldEnd(at: late, phase: .idle))
    }

    @Test func usingItWhileOffDoesNotTurnItOn() {
        var session = PhoneSession()
        session.used(at: now)
        #expect(!session.isOn)
        session.start(at: now)
        session.end()
        #expect(!session.isOn)
        #expect(session.endsAt == nil)
    }
}

@Suite("9.4 Talking from the keyboard")
struct KeyboardTalkTests {
    @Test func talkStartsAndStops() {
        #expect(KeyboardLink.tap(in: .ready(preparing: nil)) == .send(.start))
        #expect(KeyboardLink.tap(in: .ready(preparing: 10)) == .send(.start))
        #expect(KeyboardLink.tap(in: .listening) == .send(.stop))
        #expect(KeyboardLink.tap(in: .writing(preparing: nil)) == .nothing)
    }

    @Test func theAppOnlyStartsWhenIdleAndOnlyStopsWhenListening() {
        var flow = DictationFlow()
        #expect(flow.handle(.stop) == .nothing)
        #expect(flow.handle(.start) == .startRecording)
        #expect(flow.handle(.start) == .nothing)
        #expect(flow.handle(.stop) == .stopAndTranscribe)
        #expect(flow.handle(.stop) == .nothing)
        #expect(flow.handle(.start) == .nothing)
        flow.finished()
        #expect(flow.handle(.start) == .startRecording)
        #expect(flow.handle(.cancel) == .cancelRecording)
        #expect(flow.phase == .idle)
        #expect(flow.handle(.cancel) == .nothing)
    }

    @Test func onlyTheKeyboardThatAskedTypesTheText() {
        let result = PhoneResult(id: 7, text: "Hello there.")
        #expect(KeyboardLink.delivery(of: result, waitingFor: 7) == .type("Hello there."))
        #expect(KeyboardLink.delivery(of: result, waitingFor: 8) == .nothing)
        #expect(KeyboardLink.delivery(of: result, waitingFor: nil) == .nothing)
        #expect(KeyboardLink.delivery(of: nil, waitingFor: 7) == .nothing)
    }

    @Test func silenceAndProblemsShowANote() {
        #expect(KeyboardLink.delivery(of: PhoneResult(id: 7, text: ""), waitingFor: 7) == .note("Didn't catch that."))
        let failed = PhoneResult(id: 7, text: "", problem: "Couldn't write that.")
        #expect(KeyboardLink.delivery(of: failed, waitingFor: 7) == .note("Couldn't write that."))
    }

    @Test func spacesAroundTheText() {
        #expect(Tidy.forInsertion("Hello.", after: nil) == "Hello. ")
        #expect(Tidy.forInsertion("Hello.", after: "") == "Hello. ")
        #expect(Tidy.forInsertion("Hello.", after: "Hi. ") == "Hello. ")
        #expect(Tidy.forInsertion("Hello.", after: "Line\n") == "Hello. ")
        #expect(Tidy.forInsertion("Hello.", after: "Hi.") == " Hello. ")
        #expect(Tidy.forInsertion("", after: "Hi.") == "")
        #expect(Tidy.forInsertion("Hello.", after: "word") == " Hello. ")
        #expect(Tidy.forInsertion("Hello.", after: "on 5") == " Hello. ")
        #expect(Tidy.forInsertion("Hello.", after: "(see)") == " Hello. ")
        #expect(Tidy.forInsertion("Hello.", after: "\u{201C}quoted\u{201D}") == " Hello. ")
    }

    @Test func noSpaceAfterSomethingThatOpens() {
        for opening in ["(", "[", "\u{201C}", "\u{2018}", "@", "#", "/", "\"", "-"] {
            #expect(Tidy.forInsertion("Hello.", after: "x " + opening) == "Hello. ", "after \(opening)")
        }
    }

    @Test func theKeyboardTypesWhatItAskedForOnce() {
        var wait = KeyboardWait()
        wait.sent(KeyboardRequest(id: 5, kind: .start), recording: nil)
        #expect(wait.deliver(PhoneResult(id: 4, text: "Old.")) == .nothing)
        #expect(wait.deliver(PhoneResult(id: 5, text: "New.")) == .type("New."))
        #expect(wait.deliver(PhoneResult(id: 5, text: "New.")) == .nothing)
    }

    @Test func closingTheKeyboardMeansTextIsNotTypedLater() {
        var wait = KeyboardWait()
        wait.sent(KeyboardRequest(id: 5, kind: .start), recording: nil)
        wait.keyboardClosed()
        #expect(wait.deliver(PhoneResult(id: 5, text: "Hello.")) == .nothing)
    }

    @Test func stopFromAReopenedKeyboardStillTypes() {
        var wait = KeyboardWait()
        wait.sent(KeyboardRequest(id: 9, kind: .stop), recording: 5)
        #expect(wait.deliver(PhoneResult(id: 5, text: "Hello.")) == .type("Hello."))

        // The app's own recordings (0) are never typed by the keyboard.
        wait.sent(KeyboardRequest(id: 10, kind: .stop), recording: 0)
        #expect(wait.deliver(PhoneResult(id: 0, text: "Mine.")) == .nothing)
    }

    @Test func cancelForgetsTheDictation() {
        var wait = KeyboardWait()
        wait.sent(KeyboardRequest(id: 5, kind: .start), recording: nil)
        wait.sent(KeyboardRequest(id: 6, kind: .cancel), recording: 5)
        #expect(wait.deliver(PhoneResult(id: 5, text: "")) == .nothing)
    }

    @Test func eachRequestIsAnsweredOnceEvenIfTheClockGoesBack() {
        #expect(!KeyboardLink.isNew(nil, lastAnswered: 0))
        #expect(KeyboardLink.isNew(KeyboardRequest(id: 100, kind: .start), lastAnswered: 0))
        #expect(!KeyboardLink.isNew(KeyboardRequest(id: 100, kind: .start), lastAnswered: 100))
        #expect(KeyboardLink.isNew(KeyboardRequest(id: 50, kind: .stop), lastAnswered: 100))
    }

    @Test func requestIDsRiseWithTime() {
        let first = KeyboardRequest.newID(at: now)
        #expect(KeyboardRequest.newID(at: now.addingTimeInterval(0.01)) > first)
    }
}

@Suite("9.6 The phone's trace")
struct LinkStoreTests {
    private func store() throws -> LinkStore {
        let folder = FileManager.default.temporaryDirectory.appending(path: "murmur-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return LinkStore(folder: folder)
    }

    @Test func statusAndRequestRoundTrip() throws {
        let store = try store()
        #expect(store.status() == nil)
        #expect(store.request() == nil)

        var sent = status(phase: .recording, preparing: 50)
        sent.recording = 12
        sent.result = PhoneResult(id: 11, text: "Hi.", problem: nil)
        store.save(sent)
        #expect(store.status() == sent)

        store.save(KeyboardRequest(id: 12, kind: .stop))
        #expect(store.request() == KeyboardRequest(id: 12, kind: .stop))
    }

    @Test func aBrokenFileReadsAsNothing() throws {
        let store = try store()
        try Data("not json".utf8).write(to: store.folder.appending(path: "status.json"))
        #expect(store.status() == nil)
    }

    @Test func traceKeepsTheLastLinesWithTimes() throws {
        var text = ""
        for number in 1...(Trace.limit + 5) {
            text = Trace.adding("event \(number)", at: now, to: text)
        }
        let lines = text.split(separator: "\n")
        #expect(lines.count == Trace.limit)
        #expect(lines.first?.hasSuffix(" event 6") == true)
        #expect(lines.last?.hasSuffix(" event \(Trace.limit + 5)") == true)
        #expect(lines.last?.hasPrefix("2027-01-15T") == true)
    }

    @Test func eachSideHasItsOwnTraceFile() throws {
        let store = try store()
        store.trace("sent start", from: "keyboard", at: now)
        store.trace("started listening", from: "app", at: now)
        let keyboard = try String(contentsOf: store.folder.appending(path: "trace-keyboard.txt"), encoding: .utf8)
        #expect(keyboard.contains("sent start"))
        #expect(!keyboard.contains("started listening"))
    }
}
