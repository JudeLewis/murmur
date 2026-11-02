import Testing
@testable import MurmurCore

@Suite("2.1 Double tap Fn")
struct DoubleTapTests {
    /// Presses and releases Fn at the given times; returns whether the last release fired.
    private func taps(_ times: [(down: Double, up: Double)], detector: inout DoubleTapDetector) -> [Bool] {
        times.map { tap in
            detector.keyDown(at: tap.down)
            return detector.keyUp(at: tap.up)
        }
    }

    @Test func twoQuickTapsFire() {
        var detector = DoubleTapDetector()
        #expect(taps([(0, 0.1), (0.3, 0.4)], detector: &detector) == [false, true])
    }

    @Test func oneTapDoesNothing() {
        var detector = DoubleTapDetector()
        #expect(taps([(0, 0.1)], detector: &detector) == [false])
    }

    @Test func tapsTooFarApartDoNotFire() {
        var detector = DoubleTapDetector()
        #expect(taps([(0, 0.1), (0.8, 0.9)], detector: &detector) == [false, false])
    }

    @Test func aLongHoldIsNotATap() {
        var detector = DoubleTapDetector()
        #expect(taps([(0, 0.6), (0.7, 0.8)], detector: &detector) == [false, false])
    }

    @Test func fnWithAnotherKeyIsNotATap() {
        var detector = DoubleTapDetector()
        detector.keyDown(at: 0)
        detector.otherKey()  // Fn+arrow
        #expect(detector.keyUp(at: 0.1) == false)
        detector.keyDown(at: 0.2)
        #expect(detector.keyUp(at: 0.3) == false)
    }

    @Test func typingBetweenTapsBreaksTheDoubleTap() {
        var detector = DoubleTapDetector()
        detector.keyDown(at: 0)
        #expect(detector.keyUp(at: 0.1) == false)
        detector.otherKey()
        detector.keyDown(at: 0.2)
        #expect(detector.keyUp(at: 0.3) == false)
    }

    @Test func threeTapsFireOnceThenNeedTwoMore() {
        var detector = DoubleTapDetector()
        let results = taps([(0, 0.1), (0.2, 0.3), (0.4, 0.5), (0.6, 0.7)], detector: &detector)
        #expect(results == [false, true, false, true])
    }

    @Test func releaseWithoutPressIsIgnored() {
        var detector = DoubleTapDetector()
        #expect(detector.keyUp(at: 1) == false)
    }
}

@Suite("2.2 On and off")
struct DictationFlowTests {
    @Test func doubleTapStartsThenStops() {
        var flow = DictationFlow()
        #expect(flow.toggle() == .startRecording)
        #expect(flow.phase == .recording)
        #expect(flow.toggle() == .stopAndTranscribe)
        #expect(flow.phase == .transcribing)
        flow.finished()
        #expect(flow.phase == .idle)
    }

    @Test func doubleTapWhileWritingIsIgnored() {
        var flow = DictationFlow()
        _ = flow.toggle()
        _ = flow.toggle()
        #expect(flow.toggle() == .nothing)
        #expect(flow.phase == .transcribing)
    }

    @Test func escapeCancelsOnlyWhileListening() {
        var flow = DictationFlow()
        #expect(flow.cancel() == .nothing)
        _ = flow.toggle()
        #expect(flow.cancel() == .cancelRecording)
        #expect(flow.phase == .idle)
        _ = flow.toggle()
        _ = flow.toggle()
        #expect(flow.cancel() == .nothing)
    }

    @Test func retryOnlyWhenIdle() {
        var flow = DictationFlow()
        #expect(flow.retry() == true)
        #expect(flow.phase == .transcribing)
        #expect(flow.retry() == false)
        flow.finished()
        _ = flow.toggle()
        #expect(flow.retry() == false)
    }
}

@Suite("2.1 Double tap Fn: keyboard events")
struct FnWatcherTests {
    private func fn(_ held: Bool, code: Int64 = 63) -> KeyEvent { .modifiersChanged(keyCode: code, fnHeld: held) }

    /// The taps from Jude's MacBook Air log on 2 Nov 2026: about 60 ms held, 80 ms apart.
    @Test func realTapsFromTheLog() {
        var watcher = FnWatcher()
        #expect(watcher.handle(fn(true), at: 870547.282) == .nothing)
        #expect(watcher.handle(fn(false), at: 870547.338) == .nothing)
        #expect(watcher.handle(fn(true), at: 870547.424) == .nothing)
        #expect(watcher.handle(fn(false), at: 870547.483) == .doubleTap)
    }

    @Test func theGlobeKeysOwnKeyPressDoesNotBreakTheDoubleTap() {
        var watcher = FnWatcher()
        _ = watcher.handle(fn(true), at: 0)
        _ = watcher.handle(.keyDown(keyCode: 179), at: 0.01)
        _ = watcher.handle(fn(false), at: 0.06)
        _ = watcher.handle(fn(true), at: 0.15)
        _ = watcher.handle(.keyDown(keyCode: 179), at: 0.16)
        #expect(watcher.handle(fn(false), at: 0.2) == .doubleTap)
    }

    @Test func globeKeyCodeWorksAsFn() {
        var watcher = FnWatcher()
        _ = watcher.handle(fn(true, code: 179), at: 0)
        _ = watcher.handle(fn(false, code: 179), at: 0.05)
        _ = watcher.handle(fn(true, code: 179), at: 0.15)
        #expect(watcher.handle(fn(false, code: 179), at: 0.2) == .doubleTap)
    }

    @Test func fnWithALetterIsNotATap() {
        var watcher = FnWatcher()
        _ = watcher.handle(fn(true), at: 0)
        _ = watcher.handle(.keyDown(keyCode: 0), at: 0.02)
        _ = watcher.handle(fn(false), at: 0.05)
        _ = watcher.handle(fn(true), at: 0.15)
        #expect(watcher.handle(fn(false), at: 0.2) == .nothing)
    }

    @Test func fnWithShiftIsNotATap() {
        var watcher = FnWatcher()
        _ = watcher.handle(fn(true), at: 0)
        _ = watcher.handle(.modifiersChanged(keyCode: 56, fnHeld: true), at: 0.02)
        _ = watcher.handle(fn(false), at: 0.05)
        _ = watcher.handle(fn(true), at: 0.15)
        #expect(watcher.handle(fn(false), at: 0.2) == .nothing)
    }

    @Test func escapeIsReported() {
        var watcher = FnWatcher()
        #expect(watcher.handle(.keyDown(keyCode: 53), at: 0) == .escape)
    }
}
